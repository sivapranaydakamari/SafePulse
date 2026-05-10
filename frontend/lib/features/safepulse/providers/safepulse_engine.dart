// MOVED FROM: lib/features/safepulse/engine/safepulse_engine.dart
import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../services/ai_service.dart';
import '../services/alert_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/sensor_service.dart';
import '../services/sos_service.dart';
import '../services/warning_service.dart';
import '../../../core/enums.dart';

enum EngineState { idle, monitoring, processingSos }
enum EngineHealthState { active, recoveringSensors, recoveringAI, degraded, emergency }
enum EngineSeverity { normal, warning, critical }

class SafePulseEngine {
  final ServiceInstance? serviceInstance;
  SafePulseEngine({this.serviceInstance}) {
    _initializeServices();
  }

  final AIService aiService = AIService();
  final SensorService sensorService = SensorService();
  final LocationService locationService = LocationService();
  final AlertService alertService = AlertService();
  late final WarningService warningService;
  final SosService sosService = SosService();

  final logStream = StreamController<LogMessage>.broadcast();
  final speedStream = StreamController<double>.broadcast();
  final distractionStream = StreamController<int>.broadcast();
  final stateStream = StreamController<EngineState>.broadcast();
  final callReturnedStream = StreamController<void>.broadcast();

  bool _isRunning = false;
  DateTime? _lastEmergencyTrigger;
  EngineHealthState healthState = EngineHealthState.active;
  Timer? _watchdogTimer;
  bool _stopping = false;

  void _initializeServices() {
    warningService = WarningService(alertService);
    aiService.onLog = (msg) => log(msg, level: LogLevel.info);
    sensorService.onLog = (msg) => log(msg, level: LogLevel.info);
    locationService.onLog = (msg) => log(msg, level: msg.contains("⚠️") ? LogLevel.warning : LogLevel.info);
    warningService.onLog = (msg) => log(msg, level: LogLevel.warning);
    sosService.onLog = (msg) => log(msg, level: LogLevel.info);

    locationService.onSpeedUpdate = (speedMs) {
      speedStream.add(speedMs);
      serviceInstance?.invoke('speed', {'speed': speedMs});
      warningService.handleSpeed(speedMs);
    };

    sensorService.onRawData = (data) {
      if (healthState != EngineHealthState.degraded) aiService.addData(data);
    };

    aiService.onCrashDetected = (prob) => _handleCrash();
    sosService.onCallReturned = () {
      callReturnedStream.add(null);
      serviceInstance?.invoke('callReturned');
    };

    sosService.onEmergencySOS = (contacts, payload) {
      serviceInstance?.invoke('executeEmergencySOS', {'contacts': contacts, 'payload': payload});
    };

    aiService.initialize();
    alertService.initialize();
  }

  void log(String message, {LogLevel level = LogLevel.info}) {
    logStream.add(LogMessage(message, level: level));
    serviceInstance?.invoke('log', {'message': message, 'level': level.index});
  }

  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;
    _updateState(EngineState.monitoring);
    sensorService.start();
    locationService.startSpeedMonitoring();
  }

  void _updateState(EngineState state) {
    stateStream.add(state);
    serviceInstance?.invoke('state', {'state': state.index});
  }

  Future<void> stop() async {
    _isRunning = false;
    _updateState(EngineState.idle);
    await sensorService.stop();
    locationService.stop();
  }

  Future<void> _handleCrash() async {
    log("🚀 CRASH DETECTED!", level: LogLevel.critical);
    _updateState(EngineState.processingSos);
    final pos = await locationService.getCurrentPositionSafe();
    await sosService.triggerHybridSOS(
      lat: pos?.latitude ?? 0.0,
      lng: pos?.longitude ?? 0.0,
      hasLocation: pos != null,
      speedMs: locationService.currentSpeedMs ?? 0.0,
    );
    _updateState(EngineState.idle);
  }

  void dispose() {
    logStream.close();
    speedStream.close();
    distractionStream.close();
    stateStream.close();
    callReturnedStream.close();
    aiService.dispose();
  }
}
