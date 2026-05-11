/// OBD-II Vehicle Integration — Future Scope
///
/// Planned: Direct vehicle speed and diagnostics via Bluetooth OBD-II adapter.
/// TODO: Integrate flutter_blue_plus or obd2_plugin.
///
/// When implemented, replaces GPS speed estimation with PID 010D vehicle speed,
/// and provides RPM, fuel level, and fault codes to SafePulseEngine.
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
  @override Future connect() async => false;
  @override Stream get speedStream => const Stream.empty();
  @override Future disconnect() async {}
}
