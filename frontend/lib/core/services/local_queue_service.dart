/// LocalQueueService — Future Scope
///
/// Planned: Full offline SOS event queueing with local persistence and retry sync.
/// TODO: Implement using sqflite or hive for local storage, with connectivity_plus
/// for network state monitoring and automatic retry on reconnect.
///
/// This converts the current fire-and-forget offline SMS (triggerOfflineSOS) into
/// a reliable queued delivery system that retries until the server acknowledges.
abstract class LocalQueueService {
  /// TODO: Enqueue an SOS event for delivery when network is restored.
  Future<void> enqueueSOSEvent(Map<String, dynamic> sosPayload);

  /// TODO: Retry all pending SOS events against the backend API.
  Future<void> flushQueue();

  /// TODO: Return count of pending undelivered events.
  Future<int> getPendingCount();
}

/// Stub — no-op until LocalQueueService is implemented.
class LocalQueueServiceStub implements LocalQueueService {
  @override
  Future<void> enqueueSOSEvent(Map<String, dynamic> sosPayload) async {
    // TODO: persist to local DB
  }

  @override
  Future<void> flushQueue() async {
    // TODO: retry pending events via ApiService
  }

  @override
  Future<int> getPendingCount() async => 0;
}
