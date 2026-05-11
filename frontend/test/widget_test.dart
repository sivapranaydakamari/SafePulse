import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:safepulse/features/auth/screens/splash_screen.dart';

class _MockAuthProvider extends ChangeNotifier {
  bool get isLoggedIn => false;
  bool get isLoading => false;
}

void main() {
  testWidgets('SplashScreen renders without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<_MockAuthProvider>(
        create: (_) => _MockAuthProvider(),
        child: const MaterialApp(home: SplashScreen()),
      ),
    );
    await tester.pump();
    expect(find.byType(SplashScreen), findsOneWidget);
  });
}
