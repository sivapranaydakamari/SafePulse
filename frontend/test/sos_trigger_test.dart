import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safepulse/features/safepulse/services/sos_service.dart';
import 'package:safepulse/core/repositories/sos_repository.dart';

/// Minimal SOSRepository stub — no network calls. Extends the concrete class
/// so the type hierarchy is satisfied without reimplementing every method.
class _StubSOSRepository extends SOSRepository {
  @override
  Future<bool> sendSafePulseSOS(
    double lat,
    double lng,
    String severity, {
    bool hasLocation = true,
    int? locationAgeSec,
  }) async =>
      false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SosService — no contacts configured', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('contacts list is empty when SharedPreferences has no entries', () async {
      final sos = SosService(_StubSOSRepository());
      await sos.loadContacts();
      expect(sos.contacts.isEmpty, isTrue);
    });

    test('triggerOfflineSOS returns early without throwing when contacts are empty',
        () async {
      final sos = SosService(_StubSOSRepository());
      // triggerOfflineSOS calls _loadContacts() internally; empty prefs → early return
      await sos.triggerOfflineSOS(0.0, 0.0);
      // If we reach here the method completed without throwing
      expect(sos.contacts.isEmpty, isTrue);
    });
  });

  group('SosService — contacts configured', () {
    setUp(() {
      // Pipe-separated format: 'name|phone' or just 'phone' — matches _loadContacts() parsing.
      SharedPreferences.setMockInitialValues({
        'emergency_contacts': ['Test|+910000000000'],
      });
    });

    test('contacts load correctly from SharedPreferences', () async {
      final sos = SosService(_StubSOSRepository());
      await sos.loadContacts();
      expect(sos.contacts.isNotEmpty, isTrue);
      expect(sos.contacts.first, '+910000000000');
    });
  });
}
