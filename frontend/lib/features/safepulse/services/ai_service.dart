// lib/features/safepulse/services/ai_service.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
// TFLite inference engine — crash detection model (assets/crash_model.tflite)
import 'package:tflite_flutter/tflite_flutter.dart';
import '../../../core/services/api_service.dart';

class AIService {
  Interpreter? _interpreter;
  final List<List<double>> _sensorBuffer = [];

  Function(double probability)? onCrashDetected;
  Function(String message)? onLog;
  Function()? onInferenceAttempt;
  Function()? onInferenceCompleted;
  double currentSpeedKmh = 0.0;

  bool _isProcessing = false;
  bool _resetting = false;
  bool _isModelLoaded = false;

  bool get isModelLoaded => _isModelLoaded;
  String get modelStatus => _isModelLoaded ? 'loaded' : 'fallback';

  Future<void> initialize() async {
    try {
      final options = InterpreterOptions()..addDelegate(XNNPackDelegate());
      _interpreter = await Interpreter.fromAsset('assets/crash_model.tflite', options: options);
      _isModelLoaded = true;
      onLog?.call("🧠 TFLite AI Crash Model Loaded!");
      debugPrint("AIService: TFLite Model Loaded!");
      debugPrint('[AIService] TFLite status: $modelStatus');

      // Warm-up inference to confirm the model executes (not just loaded).
      final inputShape = _interpreter!.getInputTensor(0).shape;
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      final timesteps = inputShape.length >= 2 ? inputShape[1] : 250;
      final features = inputShape.length >= 3 ? inputShape[2] : 6;
      final warmInput = [List.generate(timesteps, (_) => List.filled(features, 0.0))];
      final warmOutput = List.filled(1, 0.0).reshape([1, 1]);
      _interpreter!.run(warmInput, warmOutput);
      debugPrint('[AI] warm-up output shape: $outputShape → ${warmOutput[0][0]}');
    } catch (e) {
      _isModelLoaded = false;
      onLog?.call("❌ ERROR: Failed to load AI model. Check assets folder.");
      debugPrint("AIService: TFLite Model FAILED TO LOAD! Error: $e");
      rethrow;
    }
  }

  void addData(List<double> data) {
    if (_resetting) return;

    _sensorBuffer.add(data);

    if (_sensorBuffer.length > 250) {
      _sensorBuffer.removeAt(0); // Keep exactly 5 seconds
    }

    double ax = data[0], ay = data[1], az = data[2];
    double gForce = sqrt(pow(ax, 2) + pow(ay, 2) + pow(az, 2)) / 9.81;

    if (gForce > 4.5 && _sensorBuffer.length == 250) {
      if (!_isProcessing) {
        onLog?.call("⚠️ IMPACT: ${gForce.toStringAsFixed(1)} Gs. AI Analyzing...");
        debugPrint("AIService: IMPACT DETECTED! G-Force: ${gForce.toStringAsFixed(1)}");
        unawaited(_runAIAnalysis(List.from(_sensorBuffer), gForce));
        if (!_resetting) {
          _sensorBuffer.clear();
        }
      }
    }
  }

  void resetProcessingState() {
    _resetting = true;
    _isProcessing = false;
    _sensorBuffer.clear();
    _resetting = false;
  }

  // Fix 8: rolling timestamp buffer — 2 spikes within 500 ms trigger fallback SOS
  final List<DateTime> _recentSpikes = [];

  Future<void> _runAIAnalysis(List<List<double>> windowToAnalyze, double maxGForce) async {
    _isProcessing = true;
    onInferenceAttempt?.call();

    final serverHandled = await _runServerAIAnalysis(windowToAnalyze);
    if (serverHandled) {
      _isProcessing = false;
      onInferenceCompleted?.call();
      return;
    }

    if (_interpreter == null) {
      if (maxGForce > 3.5) {
        final now = DateTime.now();
        _recentSpikes.removeWhere((t) => now.difference(t).inMilliseconds > 500);
        _recentSpikes.add(now);
        debugPrint("AIService: INTERPRETER NULL. Spikes in 500ms window: ${_recentSpikes.length} / 2");
        if (_recentSpikes.length >= 2) {
          _recentSpikes.clear();
          debugPrint("AIService: FALLBACK CRASH TRIGGERED!");
          onLog?.call("⚠️ Basic Threshold Crash Detected! (AI offline)");
          onCrashDetected?.call(1.0);
        } else {
          onLog?.call("⚠️ Spike detected. Awaiting temporal confirmation...");
        }
      } else {
        onLog?.call("⚠️ Impact filtered by Basic Threshold (AI offline)");
      }
      _isProcessing = false;
      onInferenceCompleted?.call();
      return;
    }

    try {
      var input = [windowToAnalyze];
      var output = List.filled(1, 0.0).reshape([1, 1]);

      _interpreter!.run(input, output);
      double crashProbability = output[0][0];

      if (crashProbability > 0.25) {
        debugPrint("AIService: AI CONFIRMED CRASH ($crashProbability)");
        onCrashDetected?.call(crashProbability);
      } else {
        debugPrint("AIService: AI FILTERED FALSE ALARM ($crashProbability)");
        onLog?.call("✅ AI Filtered: Just a drop/bump. (${(crashProbability * 100).toStringAsFixed(1)}%)");
      }
    } catch (e) {
      debugPrint("AIService: AI ERROR EXCEPTION: $e");
      onLog?.call("❌ AI Error: $e. Falling back to basic threshold.");
      if (maxGForce > 3.5) { // Lowered to 3.5 for manual testing
        debugPrint("AIService: FALLBACK THRESHOLD MET! Triggering SOS.");
        onCrashDetected?.call(1.0);
      } else {
        debugPrint("AIService: FALLBACK THRESHOLD NOT MET. ($maxGForce <= 3.5)");
      }
    } finally {
      _isProcessing = false;
      onInferenceCompleted?.call();
    }
  }

  /// Public inference entry point for integration tests and diagnostics.
  /// Returns the raw crash probability from the TFLite model, or null if
  /// the model is not loaded or inference fails.
  Future<double?> runInference(List<List<double>> sensorWindow) async {
    if (_interpreter == null) return null;
    try {
      var input = [sensorWindow];
      var output = List.filled(1, 0.0).reshape([1, 1]);
      _interpreter!.run(input, output);
      return output[0][0] as double;
    } catch (e) {
      debugPrint('[AI] runInference error: $e');
      return null;
    }
  }

  void dispose() {
    _interpreter?.close();
  }

  Future<bool> _runServerAIAnalysis(List<List<double>> windowToAnalyze) async {
    try {
      final samples = windowToAnalyze.map((data) {
        return {
          'ax': data[0],
          'ay': data[1],
          'az': data[2],
          'gx': data.length > 3 ? data[3] : 0.0,
          'gy': data.length > 4 ? data[4] : 0.0,
          'gz': data.length > 5 ? data[5] : 0.0,
          'speedKmh': currentSpeedKmh,
        };
      }).toList();

      final response = await ApiService.analyzeAccidentWindow(samples: samples);
      if (response['success'] != true || response['analysis'] is! Map) {
        onLog?.call("AI service unavailable. Falling back to local crash model.");
        return false;
      }

      final analysis = Map<String, dynamic>.from(response['analysis'] as Map);
      final probability = (analysis['crashProbability'] as num?)?.toDouble() ?? 0.0;
      final detected = analysis['crashDetected'] == true;
      final modelUsed = analysis['modelUsed'] ?? 'server-ai';

      if (detected) {
        onLog?.call("Server AI confirmed crash via $modelUsed (${(probability * 100).toStringAsFixed(1)}%).");
        onCrashDetected?.call(probability);
      } else {
        onLog?.call("Server AI filtered impact (${(probability * 100).toStringAsFixed(1)}%).");
      }
      return true;
    } catch (e) {
      onLog?.call("AI service error: $e. Falling back to local crash model.");
      return false;
    }
  }
}
