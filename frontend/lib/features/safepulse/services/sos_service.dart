// SafePulse Problem Gap #3: autonomous SOS — SMS + direct call + server event,
// queued for offline retry.  No user interaction required after a crash is confirmed.
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:telephony/telephony.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/repositories/sos_repository.dart';
import '../../../core/services/local_queue_service.dart';
import 'package:url_launcher/url_launcher.dart';

class SosService {
  final SOSRepository _sosRepo;
  final Telephony telephony = Telephony.instance;

  SosService(this._sosRepo);

  List<String> emergencyContacts = [];

  /// Public read-only view of loaded emergency contacts (for testing and diagnostics).
  List<String> get contacts => emergencyContacts;

  // Emergency contacts must be configured by the user in Settings.
  // No hardcoded fallback — sending SOS to unknown numbers is a production safety risk.
  Future<void> _loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    // Try JSON-encoded list first, then fall back to legacy pipe-delimited strings.
    List<String> entries;
    final rawJson = prefs.getString('emergency_contacts');
    if (rawJson != null && rawJson.trim().startsWith('[')) {
      try {
        entries = (jsonDecode(rawJson) as List).map((e) => e.toString()).toList();
      } catch (_) {
        entries = prefs.getStringList('emergency_contacts') ?? [];
      }
    } else {
      entries = prefs.getStringList('emergency_contacts') ?? [];
    }
    final rawPhones = entries.map((c) {
      final parts = c.split('|');
      return parts.length > 1 ? parts[1] : parts[0];
    }).where((phone) => phone.isNotEmpty).toList();

    // E.164 validation: must be +<country code><7-14 digits>
    final e164 = RegExp(r'^\+[1-9]\d{7,14}$');
    final List<String> valid = [];
    final List<String> invalid = [];
    for (final phone in rawPhones) {
      if (e164.hasMatch(phone)) {
        valid.add(phone);
      } else {
        invalid.add(phone);
      }
    }

    if (invalid.isNotEmpty) {
      developer.log(
        'Invalid emergency contact numbers detected: $invalid — '
        'numbers must be in E.164 format (+<country code><digits>). '
        'Please update in Settings before an emergency.',
        name: 'SosService',
        level: 900, // Level.SEVERE
      );
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'safepulse_alerts_v1',
        'System Alerts',
        channelDescription: 'Warnings for GPS and Battery Saver.',
        importance: Importance.high,
        priority: Priority.high,
      );
      await FlutterLocalNotificationsPlugin().show(
        997,
        'Invalid Emergency Contact',
        'Saved number${invalid.length > 1 ? 's' : ''} '
        '${invalid.join(", ")} '
        '${invalid.length > 1 ? 'are' : 'is'} not in E.164 format. '
        'Please update in Settings.',
        const NotificationDetails(android: androidDetails),
      );
    }

    emergencyContacts = valid;
  }

  Function(String message)? onLog;
  Function()? onCallReturned;
  Function(List<String> contacts, String payload)? onEmergencySOS;
  bool _isAwaitingCallReturn = false;

  /// Public wrapper for use in tests and diagnostics. Production code calls
  /// _loadContacts() internally via triggerOfflineSOS.
  Future<void> loadContacts() => _loadContacts();

  Future<void> triggerHybridSOS({
    required double lat,
    required double lng,
    required bool hasLocation,
    required int? locationAgeSec,
    double speedMs = 0.0,
  }) async {
    // Fire online in background
    debugPrint("SosService: Firing ONLINE SOS...");
    unawaited(
      _sosRepo.sendSafePulseSOS(
        lat,
        lng,
        "HIGH",
        hasLocation: hasLocation,
        locationAgeSec: locationAgeSec,
      ),
    );

    // ALWAYS execute offline emergency actions
    debugPrint("SosService: Proceeding to OFFLINE SOS...");
    await triggerOfflineSOS(
      lat,
      lng,
      hasLocation: hasLocation,
      locationAgeSec: locationAgeSec,
      speedMs: speedMs,
    );
  }

  Future<void> triggerOfflineSOS(
    double lat,
    double lng, {
    bool hasLocation = true,
    int? locationAgeSec,
    double speedMs = 0.0,
  }) async {
    await _loadContacts();

    if (emergencyContacts.isEmpty) {
      onLog?.call(
        "⚠️ No emergency contacts configured. Please add contacts in Settings before using SOS.",
      );
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'safepulse_alerts_v1',
        'System Alerts',
        channelDescription: 'Warnings for GPS and Battery Saver.',
        importance: Importance.high,
        priority: Priority.high,
      );
      await FlutterLocalNotificationsPlugin().show(
        999,
        'SOS Warning',
        'No emergency contacts found. Add contacts before starting a journey.',
        const NotificationDetails(android: androidDetails),
      );
      return;
    }

    final now = DateTime.now();
    String timestamp =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    // URL is built first and is never truncated (Fix 4)
    final String locPart;
    if (hasLocation) {
      final int staleThreshold = speedMs > 10.0 ? 10 : 30;
      final bool stale = locationAgeSec != null && locationAgeSec > staleThreshold;
      final String mapUrl = "https://maps.google.com/?q=$lat,$lng";
      locPart = stale ? "Loc(stale): $mapUrl" : "Loc: $mapUrl";
    } else {
      locPart = "Loc: UNAVAILABLE. Call immediately.";
    }

    final String trailing = "SOS! Crash detected.\nTime: $timestamp";
    final String payload;
    if (locPart.length >= 150) {
      // Edge case: URL alone fills the limit — send it without truncation
      payload = locPart;
    } else {
      final int remaining = 150 - locPart.length - 1; // -1 for the separating \n
      if (remaining <= 0) {
        payload = locPart;
      } else if (trailing.length <= remaining) {
        payload = "$locPart\n$trailing";
      } else {
        payload = "$locPart\n${trailing.substring(0, remaining)}";
      }
    }

    debugPrint("SosService: Delegating SMS and Call to UI Isolate to bypass restrictions.");
    onEmergencySOS?.call(emergencyContacts, payload);

    debugPrint("SosService: Executing fallback SOS directly from background isolate.");
    _executeEmergencySOSLocal(emergencyContacts, payload);
  }

  Future<void> _executeEmergencySOSLocal(List<String> contacts, String payload) async {
    // Escalate to foreground so Android 14+ permits the SMS send.
    // Wait up to 3 s for the OS to confirm promotion before proceeding.
    bool promotionSucceeded = false;
    final promoted = Completer<void>();
    final sub = FlutterBackgroundService().on('foregroundPromoted').listen((_) {
      if (!promoted.isCompleted) {
        promotionSucceeded = true;
        promoted.complete();
      }
    });
    FlutterBackgroundService().invoke('setAsForeground');
    await Future.any([promoted.future, Future.delayed(const Duration(seconds: 3))]);
    unawaited(sub.cancel());

    if (!promotionSucceeded) {
      // Android 14+ denied foreground promotion — direct SMS would be silently
      // dropped. Queue every number for retry and surface a notification.
      for (final number in contacts) {
        await LocalQueueService.instance.enqueue({
          'type': 'sms',
          'to': number,
          'message': payload,
          'timestamp': DateTime.now().toIso8601String(),
        });
        debugPrint('[SosService] Foreground promotion failed — SOS queued for $number');
      }
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'safepulse_alerts_v1',
        'System Alerts',
        channelDescription: 'Warnings for GPS and Battery Saver.',
        importance: Importance.high,
        priority: Priority.high,
      );
      await FlutterLocalNotificationsPlugin().show(
        998,
        'SOS Queued',
        'Could not send SOS immediately — queued for retry when conditions allow.',
        const NotificationDetails(android: androidDetails),
      );
      return;
    }

    for (String number in contacts) {
      try {
        await telephony.sendSms(to: number, message: payload, isMultipart: true);
        debugPrint("[SosService Background] SMS sent to $number");
      } catch (e) {
        await LocalQueueService.instance.enqueue({
          'type': 'sms',
          'to': number,
          'message': payload,
          'timestamp': DateTime.now().toIso8601String(),
        });
        debugPrint('[SosService Background] SMS queued for retry: $number — $e');
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (contacts.isNotEmpty) {
      debugPrint("[SosService Background] Triggering call to: ${contacts.first}");
      try {
        await FlutterPhoneDirectCaller.callNumber(contacts.first);
      } catch (e) {
        debugPrint("[SosService Background] Call Failed with direct caller: $e, falling back to url_launcher...");
        try {
          final Uri url = Uri.parse("tel:${contacts.first}");
          if (await canLaunchUrl(url)) {
            await launchUrl(url);
          }
        } catch (e2) {
          debugPrint("[SosService Background] url_launcher also failed: $e2");
        }
      }
    }
  }

  void checkCallReturn() {
    if (_isAwaitingCallReturn) {
      _isAwaitingCallReturn = false;
      onCallReturned?.call();
    }
  }
}
