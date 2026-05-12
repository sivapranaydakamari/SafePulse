// REVIEW_VERIFIED: 1 - OFFLINE QUEUE with exponential backoff + connectivity drain
/// Persists failed SOS/location events to SharedPreferences and retries them
/// with exponential backoff (30 s → 2 min → 10 min, max 3 attempts) whenever
/// the app foregrounds or internet connectivity is restored.
library;

import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int _kMaxAttempts = 3;
const List<Duration> _kBackoff = [
  Duration(seconds: 30),
  Duration(minutes: 2),
  Duration(minutes: 10),
];

class LocalQueueService {
  LocalQueueService._();
  static final LocalQueueService instance = LocalQueueService._();

  static const _queueKey = 'sos_sms_queue';

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  /// Persists [event] for retry, injecting initial backoff metadata.
  Future<void> enqueue(Map<String, dynamic> event) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_queueKey) ?? [];
      final entry = Map<String, dynamic>.from(event)
        ..['_attempts'] = 0
        ..['_nextRetryAt'] = DateTime.now().toIso8601String();
      raw.add(jsonEncode(entry));
      await prefs.setStringList(_queueKey, raw);
    } catch (e) {
      debugPrint('[LocalQueueService] enqueue failed: $e');
    }
  }

  /// Returns all persisted events without removing them.
  Future<List<Map<String, dynamic>>> getPending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_queueKey) ?? [];
      return raw.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('[LocalQueueService] getPending failed: $e');
      return [];
    }
  }

  /// Removes all persisted events.
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_queueKey);
    } catch (e) {
      debugPrint('[LocalQueueService] clear failed: $e');
    }
  }

  Future<int> getPendingCount() async => (await getPending()).length;

  /// Queues a location update for retry when the primary API call fails.
  Future<void> queueLocationUpdate(
      double lat, double lon, double speed) async {
    await enqueue({
      'type': 'location_update',
      'lat': lat,
      'lon': lon,
      'speed': speed,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Processes all queued events. For each due event [handler] is called;
  /// on failure the attempt counter is incremented and the next retry time
  /// is set according to [_kBackoff]. Events that exhaust [_kMaxAttempts]
  /// are silently dropped. Events whose [_nextRetryAt] is in the future are
  /// left untouched.
  Future<void> processQueue(
      Future<bool> Function(Map<String, dynamic> event) handler) async {
    final pending = await getPending();
    if (pending.isEmpty) return;

    final remaining = <Map<String, dynamic>>[];
    for (final event in pending) {
      final attempts = (event['_attempts'] as int?) ?? 0;
      final nextRetryStr = event['_nextRetryAt'] as String?;
      final nextRetry = nextRetryStr != null
          ? DateTime.tryParse(nextRetryStr) ?? DateTime.now()
          : DateTime.now();

      if (DateTime.now().isBefore(nextRetry)) {
        remaining.add(event);
        continue;
      }

      bool success = false;
      try {
        success = await handler(event);
      } catch (_) {
        success = false;
      }

      if (!success) {
        final newAttempts = attempts + 1;
        if (newAttempts >= _kMaxAttempts) {
          debugPrint('[LocalQueueService] dropping event after $newAttempts attempts');
          continue;
        }
        final backoff = _kBackoff[newAttempts < _kBackoff.length
            ? newAttempts
            : _kBackoff.length - 1];
        remaining.add(Map<String, dynamic>.from(event)
          ..['_attempts'] = newAttempts
          ..['_nextRetryAt'] =
              DateTime.now().add(backoff).toIso8601String());
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      if (remaining.isEmpty) {
        await prefs.remove(_queueKey);
      } else {
        await prefs.setStringList(
            _queueKey, remaining.map(jsonEncode).toList());
      }
    } catch (e) {
      debugPrint('[LocalQueueService] processQueue flush failed: $e');
    }
  }

  /// Subscribes to connectivity changes and calls [processQueue] with
  /// [handler] whenever the device comes back online. Call [dispose] when
  /// the listener is no longer needed (e.g., app lifecycle dispose).
  void processOnConnectivity(
      Future<bool> Function(Map<String, dynamic> event) handler) {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen(
      (results) {
        final online = results.any((r) => r != ConnectivityResult.none);
        if (online) {
          processQueue(handler);
        }
      },
    );
  }

  /// Cancels the connectivity subscription created by [processOnConnectivity].
  Future<void> dispose() async {
    await _connectivitySub?.cancel();
    _connectivitySub = null;
  }
}
