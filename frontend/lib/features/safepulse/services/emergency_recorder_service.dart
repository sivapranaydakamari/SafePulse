import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records emergency events to local storage so they can be reviewed after
/// the fact (e.g. in a journey history screen) and synced to the server when
/// connectivity is restored.
///
/// Each record includes the trigger type, timestamp, location, and outcome.
class EmergencyRecorderService {
  EmergencyRecorderService._();
  static final EmergencyRecorderService instance = EmergencyRecorderService._();

  static const _key = 'emergency_event_log';

  /// Persist a new emergency event.
  Future<void> record({
    required String triggerType, // 'crash_detected' | 'manual_sos' | 'speed_critical'
    required double lat,
    required double lng,
    String? severity,
    String? outcome,
    Map<String, dynamic>? extra,
  }) async {
    final event = {
      'triggerType': triggerType,
      'lat': lat,
      'lng': lng,
      'severity': severity ?? 'UNKNOWN',
      'outcome': outcome ?? 'pending',
      'timestamp': DateTime.now().toIso8601String(),
      if (extra != null) ...extra,
    };
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? [];
      raw.add(jsonEncode(event));
      // Keep at most 100 records on device.
      final trimmed = raw.length > 100 ? raw.sublist(raw.length - 100) : raw;
      await prefs.setStringList(_key, trimmed);
      debugPrint('[EmergencyRecorder] recorded $triggerType at $lat,$lng');
    } catch (e) {
      debugPrint('[EmergencyRecorder] failed to record event: $e');
    }
  }

  /// Returns all locally stored emergency events, newest first.
  Future<List<Map<String, dynamic>>> getHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? [];
      return raw
          .map((s) => jsonDecode(s) as Map<String, dynamic>)
          .toList()
          .reversed
          .toList();
    } catch (e) {
      debugPrint('[EmergencyRecorder] failed to load history: $e');
      return [];
    }
  }

  /// Clear all locally stored records.
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (e) {
      debugPrint('[EmergencyRecorder] failed to clear history: $e');
    }
  }
}
