import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:telephony/telephony.dart';
import 'dart:async';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/api_service.dart';

class EmergencyCountdown extends StatefulWidget {
  const EmergencyCountdown({super.key});

  @override
  State<EmergencyCountdown> createState() => _EmergencyCountdownState();
}

class _EmergencyCountdownState extends State<EmergencyCountdown> {
  int _secondsLeft = 10;
  Timer? _timer;

  Position? _preFetchedPosition;
  final Telephony _telephony = Telephony.instance;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _preFetchLocation();
    _requestSmsPermission();
  }

  Future<void> _requestSmsPermission() async {
    await _telephony.requestSmsPermissions;
  }

  Future<void> _preFetchLocation() async {
    try {
      _preFetchedPosition = await LocationService.getCurrentLocation();
    } catch (e) {
      debugPrint("Pre-fetch location error: $e");
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        _timer?.cancel();
        _triggerAlert();
      }
    });
  }

  Future<void> _triggerAlert() async {
    _timer?.cancel();
    
    // 1. Finalize location (use pre-fetched if available, otherwise get now)
    Position? currentPos = _preFetchedPosition;
    if (currentPos == null) {
      try {
        currentPos = await LocationService.getCurrentLocation();
      } catch (e) {
        debugPrint("Location error: $e");
      }
    }

    String locationUrl = currentPos != null 
      ? "https://www.google.com/maps/search/?api=1&query=${currentPos.latitude},${currentPos.longitude}"
      : "Location unavailable";

    // 2. Notify Backend and Send Alerts in parallel for maximum speed
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    final contactsJson = prefs.getStringList('emergency_contacts') ?? [];
    
    final contacts = contactsJson.map((c) {
      final parts = c.split('|');
      return {'name': parts[0], 'phone': parts[1]};
    }).toList();

    // Trigger all alerts concurrently
    Future.wait([
      // Backend update
      if (userId != null && currentPos != null)
        ApiService.startSOS(
          lat: currentPos.latitude,
          lng: currentPos.longitude,
          address: "SOS Countdown Triggered",
        ),
      
      // Background SMS to all contacts
      ...contacts.map((contact) => _sendBackgroundSMS(
        contact['phone']!, 
        "EMERGENCY! I need help. My live location: $locationUrl"
      )),
    ]).then((_) {
      debugPrint("All background alerts initiated.");
    });

    // 3. Initiate Phone Call (most important, show immediately)
    if (contacts.isNotEmpty) {
      _makeCall(contacts.first['phone']!);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("🚨 SOS ALERT BROADCASTED IMMEDIATELY"),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
      ),
    );
    
    // Return to home after a delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  Future<void> _sendBackgroundSMS(String phone, String message) async {
    try {
      await _telephony.sendSms(
        to: phone,
        message: message,
      );
      debugPrint("Background SMS sent to $phone");
    } catch (e) {
      debugPrint("Error sending background SMS to $phone: $e");
      _sendManualSMS(phone, message);
    }
  }

  Future<void> _sendManualSMS(String phone, String message) async {
    final Uri smsUri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: <String, String>{'body': message},
    );
    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    }
  }

  Future<void> _makeCall(String phone) async {
    final Uri telUri = Uri(
      scheme: 'tel',
      path: phone,
    );
    if (await canLaunchUrl(telUri)) {
      await launchUrl(telUri);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.9),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.risk, size: 80),
            const SizedBox(height: 24),
            const Text(
              "SOS Hub Triggered",
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Alerting circle in:",
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
            const SizedBox(height: 40),
            
            // Large Countdown Circle
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: CircularProgressIndicator(
                    value: _secondsLeft / 10,
                    strokeWidth: 10,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.risk),
                    backgroundColor: Colors.white10,
                  ),
                ),
                Text(
                  "$_secondsLeft",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 60),
            
            // Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                   ElevatedButton(
                    onPressed: () {
                      _timer?.cancel();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 64),
                    ),
                    child: const Text("I AM SAFE (CANCEL)", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      _timer?.cancel();
                      _triggerAlert();
                    },
                    child: const Text(
                      "TRIGGER SOS NOW",
                      style: TextStyle(color: AppColors.risk, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
