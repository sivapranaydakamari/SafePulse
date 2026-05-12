// lib/features/safepulse/services/sos_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:telephony/telephony.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/repositories/sos_repository.dart';
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
    final contactsJson = prefs.getStringList('emergency_contacts') ?? [];
    emergencyContacts = contactsJson.map((c) {
      final parts = c.split('|');
      return parts.length > 1 ? parts[1] : parts[0];
    }).where((phone) => phone.isNotEmpty).toList();
    
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

  // TODO (future scope): replace direct SMS with LocalQueueService.enqueueSOSEvent()
  // for reliable offline delivery with persistence and retry. See local_queue_service.dart.
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
    String locText;

    if (hasLocation) {
      int staleThreshold = speedMs > 10.0 ? 10 : 30;
      if (locationAgeSec != null && locationAgeSec > staleThreshold) {
        locText = "Loc(stale): https://maps.google.com/?q=$lat,$lng";
      } else {
        locText = "Loc: https://maps.google.com/?q=$lat,$lng";
      }
    } else {
      locText = "Loc: UNAVAILABLE. Call immediately.";
    }

    String payload = "SOS! Crash detected.\nTime: $timestamp\n$locText";
    if (payload.length > 150) {
      payload = payload.substring(0, 150);
    }

    debugPrint("SosService: Delegating SMS and Call to UI Isolate to bypass restrictions.");
    onEmergencySOS?.call(emergencyContacts, payload);

    debugPrint("SosService: Executing fallback SOS directly from background isolate.");
    _executeEmergencySOSLocal(emergencyContacts, payload);
  }

  Future<void> _executeEmergencySOSLocal(List<String> contacts, String payload) async {
    for (String number in contacts) {
      try {
        await telephony.sendSms(to: number, message: payload);
        debugPrint("[SosService Background] SMS sent to $number");
      } catch (e) {
        debugPrint("[SosService Background] SMS Failed to $number: $e");
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
