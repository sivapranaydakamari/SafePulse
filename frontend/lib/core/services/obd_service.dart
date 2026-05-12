import 'package:flutter/foundation.dart';
import '../config/feature_flags.dart';

/// FUTURE SCOPE: OBD-II Vehicle Hardware Integration
/// Planned: BLE connection to ELM327 adapters for direct speed/RPM telemetry.
/// Extension point: implement connect(), getSpeed(), getFuelLevel().
/// Current state: abstract stub — no BLE or serial implementation.
/// Tracked in: GitHub Issues label "future-obd"
abstract class OBDService {
  /// TODO: Connect to paired OBD-II Bluetooth adapter.
  Future connect();

  /// TODO: Stream real-time vehicle speed in km/h from PID 010D.
  Stream get speedStream;

  /// TODO: Disconnect from adapter.
  Future disconnect();
}

/// Stub — safe no-op until OBD-II is implemented.
class OBDServiceStub implements OBDService {
  @override Future connect() async {
    if (!FeatureFlags.obdEnabled) {
      if (kDebugMode) debugPrint('[OBD] Stub: OBD_ENABLED flag is false — skipping connect()');
      return false;
    }
    if (kDebugMode) debugPrint('[OBD] Stub: connect() — OBD-II hardware not implemented');
    return false;
  }
  @override Stream get speedStream => const Stream.empty();
  @override Future disconnect() async {}
}
