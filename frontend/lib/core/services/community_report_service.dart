/// FUTURE SCOPE: Community Safety Reporting
/// Planned: crowd-sourced hazard pins (potholes, flooding, accidents).
/// Extension point: implement submitReport(), fetchNearbyReports().
/// Current state: abstract stub — no network implementation.
/// Tracked in: GitHub Issues label "future-community"
abstract class CommunityReportService {
  /// TODO: Submit a hazard report at the given location.
  Future<bool> submitReport({
    required double latitude,
    required double longitude,
    required String hazardType,
    String? description,
  });

  /// TODO: Fetch recent community reports near a location.
  Future<List<Map<String, dynamic>>> getNearbyReports({
    required double latitude,
    required double longitude,
    double radiusKm = 5.0,
  });
}

/// Stub — returns safe no-ops until community reporting is implemented.
class CommunityReportServiceStub implements CommunityReportService {
  @override
  Future<bool> submitReport({
    required double latitude,
    required double longitude,
    required String hazardType,
    String? description,
  }) async =>
      false;

  @override
  Future<List<Map<String, dynamic>>> getNearbyReports({
    required double latitude,
    required double longitude,
    double radiusKm = 5.0,
  }) async =>
      [];
}
