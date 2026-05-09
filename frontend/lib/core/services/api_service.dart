import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  // Change to your server IP/domain.
  // For emulator use 10.0.2.2; for physical device use your machine's LAN IP.
  static const String baseUrl = 'http://10.102.19.239:5000/api';

  // Alerts: send overspeed or risk alerts to circle members
  static Future<void> sendSpeedAlert({
    required double speed,
    required double lat,
    required double lon,
    required double limit,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      if (userId == null) return;

      final headers = await authHeaders();
      await http.post(
        Uri.parse('$baseUrl/alerts/speed'),
        headers: headers,
        body: jsonEncode({
          'userId': userId,
          'speed': speed,
          'lat': lat,
          'lon': lon,
          'speedLimit': limit
        }),
      );
    } catch (_) {}
  }

  static Future<void> sendRiskAlert({
    required double lat,
    required double lon,
    required String reason,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      if (userId == null) return;

      final headers = await authHeaders();
      await http.post(
        Uri.parse('$baseUrl/alerts/risk'),
        headers: headers,
        body: jsonEncode({
          'userId': userId,
          'lat': lat,
          'lon': lon,
          'reason': reason
        }),
      );
    } catch (_) {}
  }

  // Token management
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<Map<String, String>> authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Auth
  static Future<Map<String, dynamic>> sendOtp(String phone) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/send-otp'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}),
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': 'Failed to send OTP. Check connection.'};
    }
  }

  static Future<Map<String, dynamic>> sendEmailOtp(String email, {String? name, String? phone}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/send-email-otp'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          if (name != null) 'name': name,
          if (phone != null) 'phone': phone,
        }),
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint('[API] sendEmailOtp error: $e');
      return {'success': false, 'error': 'Cannot reach server at $baseUrl. Ensure your phone and PC are on the same Wi-Fi. Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> verifyOtp(String? phone, String otp, {String? email}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-otp'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          if (phone != null) 'phone': phone,
          if (email != null) 'email': email,
          'otp': otp,
        }),
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': 'Verification failed. Check connection.'};
    }
  }

  static Future<Map<String, dynamic>> getMyProfile() async {
    try {
      final headers = await authHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Status update — called periodically while app is open to keep
  // locationPoint in MongoDB current (needed for SOS nearby user query).
  static Future<void> updateStatus({
    required double lat,
    required double lng,
    String? batteryLevel,
    bool? isDriving,
    double? currentSpeed,
    String? fcmToken,
  }) async {
    try {
      final headers = await authHeaders();
      await http.post(
        Uri.parse('$baseUrl/auth/update-status'),
        headers: headers,
        body: jsonEncode({
          'location': {'lat': lat, 'lng': lng},
          if (batteryLevel != null) 'batteryLevel': batteryLevel,
          if (isDriving    != null) 'isDriving':    isDriving,
          if (currentSpeed != null) 'currentSpeed': currentSpeed,
          if (fcmToken     != null) 'fcmToken':     fcmToken,
        }),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('[API] updateStatus failed: $e');
    }
  }

  // Route suggestion
  static Future<Map<String, dynamic>> suggestRoutes({
    required double startLat,
    required double startLng,
    required double destLat,
    required double destLng,
  }) async {
    try {
      final headers = await authHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/routes/suggest'),
        headers: headers,
        body: jsonEncode({
          'start':       {'lat': startLat, 'lng': startLng},
          'destination': {'lat': destLat,  'lng': destLng},
        }),
      ).timeout(const Duration(seconds: 20));
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': 'Failed to get routes: $e'};
    }
  }

  // SOS — FIXED: correct endpoint is /sos/start, not /circle/trigger-sos
  static Future<Map<String, dynamic>?> startSOS({
    required double lat,
    required double lng,
    String? address,
  }) async {
    try {
      final headers = await authHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/sos/start'),
        headers: headers,
        body: jsonEncode({
          'lat': lat,
          'lng': lng,
          'address': address ?? 'Emergency Location',
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 201) return jsonDecode(response.body);
      debugPrint('[SOS] start failed: ${response.body}');
    } catch (e) {
      debugPrint('[SOS] startSOS error: $e');
    }
    return null;
  }

  static Future<bool> cancelSOS(String sosId) async {
    try {
      final headers = await authHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/sos/cancel'),
        headers: headers,
        body: jsonEncode({'sosId': sosId}),
      ).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getSOSStatus(String sosId) async {
    try {
      final headers = await authHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/sos/$sosId'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('[SOS] getSOSStatus error: $e');
    }
    return null;
  }

  // Services: fetch real nearby hospitals and police stations (combined)
  static Future<Map<String, dynamic>> getNearbyServices({
    required double lat,
    required double lon,
    int radius = 3000,
  }) async {
    try {
      final headers = await authHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/services/nearby?lat=$lat&lon=$lon&radius=$radius'),
        headers: headers,
      ).timeout(const Duration(seconds: 25));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          return data;
        }
      }
    } catch (e) {
      debugPrint('[SERVICES] error: $e');
    }
    return {
      'success': false, 
      'counts': {'hospitals': 0, 'police': 0},
      'services': {'hospitals': [], 'police': []}
    };
  }

  // Services: fetch all services inside visible map bounds (bbox search)
  static Future<Map<String, dynamic>> getServicesInBBox({
    required double south,
    required double west,
    required double north,
    required double east,
    required String type, // 'hospital', 'police', or 'all'
  }) async {
    try {
      final headers = await authHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/services/bbox?south=$south&west=$west&north=$north&east=$east&type=$type'),
        headers: headers,
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint('[SERVICES BBOX] error: $e');
    }
    return {'success': false, 'services': [], 'count': 0};
  }

  // Geocoding: address search → lat/lng (Nominatim, free, no key needed)
  static Future<List<Map<String, dynamic>>> geocodeAddress(String query) async {
    try {
      final headers = await authHeaders();
      final encoded = Uri.encodeComponent(query);
      final response = await http.get(
        Uri.parse('$baseUrl/places/search?q=$encoded'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> results = jsonDecode(response.body);
        return results.map((r) => {
          'displayName': r['displayName'] as String,
          'lat':  (r['lat'] as num).toDouble(),
          'lng':  (r['lng'] as num).toDouble(),
        }).toList();
      }
    } catch (e) {
      debugPrint('[GEOCODE] error: $e');
    }
    return [];
  }

  // Emergency contacts sync
  static Future<void> syncEmergencyContacts(
    List<Map<String, String>> contacts,
  ) async {
    try {
      final headers = await authHeaders();
      await http.post(
        Uri.parse('$baseUrl/auth/emergency-contacts'),
        headers: headers,
        body: jsonEncode({'contacts': contacts}),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('[API] syncContacts failed: $e');
    }
  }

  // Circles
  static Future<Map<String, dynamic>> createCircle(String name) async {
    try {
      final headers = await authHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/circle/create'),
        headers: headers,
        body: jsonEncode({'name': name}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> joinCircle(String inviteCode) async {
    try {
      final headers = await authHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/circle/join'),
        headers: headers,
        body: jsonEncode({'inviteCode': inviteCode}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getUserCircles() async {
    try {
      final headers = await authHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/circle/my'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
