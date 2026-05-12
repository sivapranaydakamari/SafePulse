/// FUTURE SCOPE: Offline Emergency Queueing
/// Planned: persist SOS events locally (Hive/SQLite) and retry on reconnect.
/// Extension point: implement enqueue(), flush(), retryAll().
/// Current state: stub — no local persistence implemented.
/// Builds on: frontend/packages/telephony_fix offline SMS foundation.
/// Tracked in: GitHub Issues label "future-offline-queue"
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
