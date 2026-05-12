// Tests for AIService that do NOT require a physical device or TFLite runtime.
// All crash-detection logic covered here uses the @visibleForTesting surface.
import 'package:flutter_test/flutter_test.dart';
import 'package:safepulse/features/safepulse/services/ai_service.dart';

void main() {
  group('AIService — no device required', () {
    late AIService service;

    setUp(() {
      service = AIService();
    });

    tearDown(() {
      service.dispose();
    });

    test('initial state: model not loaded, spike count 0', () {
      expect(service.isModelLoaded, isFalse);
      expect(service.recentSpikeCount, 0);
      expect(service.modelStatus, 'fallback');
    });

    test('isSpikeCountAboveThreshold returns false when no spikes', () {
      expect(service.isSpikeCountAboveThreshold(1), isFalse);
    });

    test('simulateCrashTrigger fires onCrashDetected callback', () {
      double? received;
      service.onCrashDetected = (p) => received = p;
      service.simulateCrashTrigger(0.95);
      expect(received, closeTo(0.95, 0.001));
    });

    test('simulateCrashTrigger clears spike buffer', () {
      service.simulateCrashTrigger(1.0);
      expect(service.recentSpikeCount, 0);
    });

    test('runInference returns null when model is not loaded', () async {
      final window = List.generate(250, (_) => List.filled(6, 0.0));
      final result = await service.runInference(window);
      expect(result, isNull);
    });

    test('resetProcessingState clears internal buffer', () {
      for (int i = 0; i < 10; i++) {
        service.addData([1.0, 2.0, 3.0, 0.0, 0.0, 0.0]);
      }
      service.resetProcessingState();
      // After reset, no crash should be triggered for low-G data
      double? crashed;
      service.onCrashDetected = (p) => crashed = p;
      service.addData([0.1, 0.1, 9.8, 0.0, 0.0, 0.0]);
      expect(crashed, isNull);
    });
  });
}
