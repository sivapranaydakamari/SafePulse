import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../config/feature_flags.dart';

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
  }) async {
    if (!FeatureFlags.communityReportsEnabled) {
      if (kDebugMode) debugPrint('[CommunityReport] COMMUNITY_REPORTS_ENABLED flag is false — skipping');
      return false;
    }
    if (kDebugMode) debugPrint('[CommunityReport] Stub: submitReport() — not yet implemented');
    return false;
  }

  @override
  Future<List<Map<String, dynamic>>> getNearbyReports({
    required double latitude,
    required double longitude,
    double radiusKm = 5.0,
  }) async {
    if (!FeatureFlags.communityReportsEnabled) return [];
    return [];
  }
}

/// Partial implementation — posts hazard reports to the SafePulse backend.
/// Requires `/api/community/reports` endpoint (future scope on server).
class CommunityReportServiceImpl implements CommunityReportService {
  static Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    return {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
  }

  @override
  Future<bool> submitReport({
    required double latitude,
    required double longitude,
    required String hazardType,
    String? description,
  }) async {
    try {
      final headers = await _authHeaders();
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/community/reports'),
        headers: headers,
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          'hazardType': hazardType,
          if (description != null) 'description': description,
        }),
      ).timeout(const Duration(seconds: 10));
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getNearbyReports({
    required double latitude,
    required double longitude,
    double radiusKm = 5.0,
  }) async {
    try {
      final headers = await _authHeaders();
      final uri = Uri.parse(
        '${AppConfig.baseUrl}/api/community/reports?lat=$latitude&lng=$longitude&radiusKm=$radiusKm',
      );
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return (body['reports'] as List? ?? []).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }
}
