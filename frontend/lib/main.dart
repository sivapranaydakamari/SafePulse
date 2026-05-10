import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:telephony/telephony.dart';
import 'core/repositories/user_repository.dart';
import 'core/repositories/sos_repository.dart';
import 'core/repositories/circle_repository.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/sos_provider.dart';
import 'core/providers/circle_provider.dart';
import 'core/services/api_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/safepulse/services/background_service.dart';
import 'features/home/screens/home_page.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FCM] Background message: ${message.notification?.title}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BackgroundServiceHelper.initializeService();
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      ApiService.updateStatus(lat: 0, lng: 0, fcmToken: token);
    });
  } catch (e) {
    debugPrint('Firebase init failed: $e');
  }
  runApp(const SafePulseApp());
}

class SafePulseApp extends StatelessWidget {
  const SafePulseApp({super.key});

  @override
  State<SafePulseApp> createState() => _SafePulseAppState();
}

class _SafePulseAppState extends State<SafePulseApp> {

  @override
  void initState() {
    super.initState();
    _setupEmergencyListener();
  }

  void _setupEmergencyListener() {
    FlutterBackgroundService().on('executeEmergencySOS').listen((event) async {
      if (event != null) {
        final contacts = List<String>.from(event['contacts']);
        final payload = event['payload'] as String;
        
        debugPrint("UI Isolate: Received emergencySOS trigger for ${contacts.length} contacts.");
        
        final telephony = Telephony.instance;
        for (String number in contacts) {
          try {
            telephony.sendSms(to: number, message: payload);
            debugPrint("UI Isolate: SMS triggered to $number");
          } catch (e) {
            debugPrint("UI Isolate: SMS Failed: $e");
          }
          await Future.delayed(const Duration(milliseconds: 500));
        }

        if (contacts.isNotEmpty) {
          debugPrint("UI Isolate: Triggering call to ${contacts.first}");
          try {
            await FlutterPhoneDirectCaller.callNumber(contacts.first);
          } catch (e) {
            debugPrint("UI Isolate: Call Failed: $e");
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 1. Create repositories
    final userRepo   = UserRepository();
    final sosRepo    = SOSRepository();
    final circleRepo = CircleRepository();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(userRepo)..initialize()),
        ChangeNotifierProvider(create: (_) => SOSProvider(sosRepo)),
        ChangeNotifierProvider(create: (_) => CircleProvider(circleRepo)),
      ],
      child: MaterialApp(
        title: 'SafePulse',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const AppGate(),
      ),
    );
  }
}

// AppGate watches AuthProvider and routes accordingly
class AppGate extends StatelessWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authStatus = context.watch<AuthProvider>().status;

    return switch (authStatus) {
      AuthStatus.unknown         => const Scaffold(body: Center(child: CircularProgressIndicator())),
      AuthStatus.authenticated   => const HomePage(),
      AuthStatus.unauthenticated => const SplashScreen(),
    };
  }
}
