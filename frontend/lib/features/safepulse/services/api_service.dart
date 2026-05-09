import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class ApiService {
  final String baseUrl = "http://10.34.186.36:8080";

  Future<bool> sendSOS(
    double lat,
    double lng,
    String severity, {
    bool hasLocation = true,
    int? locationAgeSec,
  }) async {
    final eventId = const Uuid().v4();

    final payload = {
      "eventId": eventId,
      "latitude": lat,
      "longitude": lng,
      "locationStatus": hasLocation ? "OK" : "UNAVAILABLE",
      "locationAgeSec": locationAgeSec,
      "severity": severity,
      "timestamp": DateTime.now().toIso8601String(),
    };

    try {
      if (kDebugMode) {
        print("===== ONLINE SOS =====");
        print(jsonEncode(payload));
      }

      final response = await http
          .post(
            Uri.parse("$baseUrl/api/sos"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 5));

      if (kDebugMode) {
        print("STATUS: ${response.statusCode}");

        print("BODY: ${response.body}");
      }

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      if (kDebugMode) {
        print("HTTP ERROR: $e");
      }

      return false;
    }
  }
}
