import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Relative import resolves correctly regardless of the outer project's
// package graph — avoids "package:telephony_example" resolution failures.
import '../lib/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Stub the telephony foreground channel so requestPhoneAndSmsPermissions
    // returns null instead of throwing MissingPluginException.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.shounakmulay.com/foreground_sms_channel'),
      (MethodCall methodCall) async => null,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.shounakmulay.com/foreground_sms_channel'),
      null,
    );
  });

  testWidgets('MyApp builds and shows plugin example UI',
      (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());

    // Flush the async initPlatformState() call (mocked channel returns null,
    // so no SMS listener is registered and the widget stays mounted).
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Plugin example app'), findsOneWidget);
  });
}
