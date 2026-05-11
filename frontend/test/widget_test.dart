import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:safepulse/features/auth/screens/splash_screen.dart';

// Minimal stub — SplashScreen does not read from AuthProvider, but we wire
// one in to satisfy any Provider.of calls that may be added in the future.
class _StubAuthProvider extends ChangeNotifier {}

void main() {
  testWidgets('SplashScreen builds without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<_StubAuthProvider>(
        create: (_) => _StubAuthProvider(),
        child: const MaterialApp(home: SplashScreen()),
      ),
    );

    expect(find.byType(SplashScreen), findsOneWidget);
  });
}
