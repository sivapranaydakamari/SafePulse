// Integration test — requires a real device/emulator with the TFLite model asset.
// Run with: flutter test test/ai_service_tflite_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:safepulse/features/safepulse/services/ai_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AIService TFLite', () {
    test('initialize() loads the model — interpreter is not null', () async {
      final service = AIService();
      await service.initialize();
      expect(service.isModelLoaded, isTrue);
    });

    test('runInference() returns a non-null, non-NaN double', () async {
      final service = AIService();
      await service.initialize();

      // Zeroed 250-frame sensor window matching the model's expected input shape.
      final window = List.generate(250, (_) => List.filled(6, 0.0));
      final result = await service.runInference(window);

      expect(result, isNotNull);
      expect(result, isA<double>());
      expect(result!.isNaN, isFalse);
    });
  });
}
