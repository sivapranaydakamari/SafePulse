/// CommunityReportService — Future Scope
///
/// Planned: Community-based safety reporting and live risk zone updates.
/// TODO: Integrate with backend/services/risk_incident_repository.js to allow
/// users to submit and view crowd-sourced hazard reports on the route map.
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
