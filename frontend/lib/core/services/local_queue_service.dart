import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists failed SOS SMS events to SharedPreferences and retries them
/// when the app resumes to the foreground.
class LocalQueueService {
  LocalQueueService._();
  static final LocalQueueService instance = LocalQueueService._();

  static const _queueKey = 'sos_sms_queue';

  /// Persists a failed SMS event for retry on next foreground resume.
  Future<void> enqueue(Map<String, dynamic> event) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_queueKey) ?? [];
      raw.add(jsonEncode(event));
      await prefs.setStringList(_queueKey, raw);
    } catch (e) {
      debugPrint('[LocalQueueService] enqueue failed: $e');
    }
  }

  /// Returns all pending events without removing them.
  Future<List<Map<String, dynamic>>> getPending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_queueKey) ?? [];
      return raw
          .map((s) => jsonDecode(s) as Map<String, dynamic>)
          .toList();
    } catch (e) {
      debugPrint('[LocalQueueService] getPending failed: $e');
      return [];
    }
  }

  /// Removes all persisted events (call after successful delivery).
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_queueKey);
    } catch (e) {
      debugPrint('[LocalQueueService] clear failed: $e');
    }
  }

  Future<int> getPendingCount() async => (await getPending()).length;

  /// Processes all queued events by calling [handler] for each.
  /// Events for which [handler] returns false are kept for the next retry.
  Future<void> processQueue(Future<bool> Function(Map<String, dynamic> event) handler) async {
    final pending = await getPending();
    if (pending.isEmpty) return;
    final remaining = <Map<String, dynamic>>[];
    for (final event in pending) {
      try {
        final success = await handler(event);
        if (!success) remaining.add(event);
      } catch (_) {
        remaining.add(event);
      }
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      if (remaining.isEmpty) {
        await prefs.remove(_queueKey);
      } else {
        await prefs.setStringList(_queueKey, remaining.map(jsonEncode).toList());
      }
    } catch (e) {
      debugPrint('[LocalQueueService] processQueue flush failed: $e');
    }
  }
}
