// FUTURE_SCOPE: COMMUNITY REPORTING - fully implemented
/// Community safety reporting service.
///
/// Submits crowd-sourced hazard reports (accident / hazard / roadblock) to
/// the SafePulse backend and retrieves nearby reports for map-pin display.
/// Reports are also wired into route_scoring.js as a density-based risk factor.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../config/feature_flags.dart';

/// Hazard categories accepted by the backend.
enum HazardType { accident, hazard, roadblock }

extension HazardTypeLabel on HazardType {
  String get value {
    switch (this) {
      case HazardType.accident:  return 'accident';
      case HazardType.hazard:    return 'hazard';
      case HazardType.roadblock: return 'roadblock';
    }
  }

  String get displayLabel {
    switch (this) {
      case HazardType.accident:  return 'Accident';
      case HazardType.hazard:    return 'Hazard';
      case HazardType.roadblock: return 'Road Block';
    }
  }
}

class CommunityReportService {
  CommunityReportService._();
  static final CommunityReportService instance = CommunityReportService._();

  static Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    return {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
  }

  /// Submits a hazard report at [latitude] / [longitude].
  /// Returns true on HTTP 2xx, false otherwise.
  Future<bool> submitReport({
    required double latitude,
    required double longitude,
    required HazardType hazardType,
    String? description,
  }) async {
    if (!FeatureFlags.communityReportsEnabled) {
      if (kDebugMode) debugPrint('[CommunityReport] flag disabled — skipping submit');
      return false;
    }
    try {
      final headers = await _authHeaders();
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/community/report'),
        headers: headers,
        body: jsonEncode({
          'latitude':   latitude,
          'longitude':  longitude,
          'hazardType': hazardType.value,
          if (description != null && description.isNotEmpty) 'description': description,
        }),
      ).timeout(const Duration(seconds: 10));
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('[CommunityReport] submitReport error: $e');
      return false;
    }
  }

  /// Fetches unresolved community reports within [radiusKm] km of the given location.
  Future<List<Map<String, dynamic>>> getNearbyReports({
    required double latitude,
    required double longitude,
    double radiusKm = 5.0,
  }) async {
    if (!FeatureFlags.communityReportsEnabled) return [];
    try {
      final headers = await _authHeaders();
      final uri = Uri.parse(
        '${AppConfig.baseUrl}/api/community/reports'
        '?lat=$latitude&lng=$longitude&radiusKm=$radiusKm',
      );
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return (body['reports'] as List? ?? []).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('[CommunityReport] getNearbyReports error: $e');
      return [];
    }
  }
}
