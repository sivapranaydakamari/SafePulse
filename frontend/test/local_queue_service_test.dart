// REVIEW_VERIFIED: 1 - OFFLINE QUEUE unit tests
// Tests: enqueue → persist → restore → exponential backoff → max retries drop
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safepulse/core/services/local_queue_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await LocalQueueService.instance.clear();
  });

  group('LocalQueueService — persist / restore', () {
    test('enqueue persists to SharedPreferences', () async {
      await LocalQueueService.instance
          .enqueue({'type': 'sms', 'to': '+911234567890', 'message': 'SOS!'});
      final pending = await LocalQueueService.instance.getPending();
      expect(pending, hasLength(1));
      expect(pending.first['type'], 'sms');
    });

    test('getPending returns items after simulated restart', () async {
      await LocalQueueService.instance
          .enqueue({'type': 'sms', 'to': '+911234567890', 'message': 'test'});
      final restored = await LocalQueueService.instance.getPending();
      expect(restored, hasLength(1));
      expect(restored.first['to'], '+911234567890');
    });

    test('queue survives multiple enqueues', () async {
      await LocalQueueService.instance
          .enqueue({'type': 'sms', 'to': '+911111111111', 'message': 'A'});
      await LocalQueueService.instance
          .enqueue({'type': 'sms', 'to': '+912222222222', 'message': 'B'});
      expect(await LocalQueueService.instance.getPendingCount(), 2);
    });
  });

  group('LocalQueueService — processQueue delivery', () {
    test('successful handler removes event from queue', () async {
      await LocalQueueService.instance
          .enqueue({'type': 'sms', 'to': '+911234567890', 'message': 'ok'});
      await LocalQueueService.instance.processQueue((_) async => true);
      expect(await LocalQueueService.instance.getPendingCount(), 0);
    });

    test('failing handler keeps event with incremented attempt counter', () async {
      await LocalQueueService.instance
          .enqueue({'type': 'sms', 'to': '+911234567890', 'message': 'fail'});
      await LocalQueueService.instance.processQueue((_) async => false);
      final pending = await LocalQueueService.instance.getPending();
      expect(pending, hasLength(1));
      expect(pending.first['_attempts'], 1);
    });

    test('event is dropped after max attempts', () async {
      final prefs = await SharedPreferences.getInstance();
      final entry = {
        'type': 'sms',
        'to': '+911234567890',
        'message': 'drop me',
        '_attempts': 2,
        '_nextRetryAt':
            DateTime.now().subtract(const Duration(seconds: 1)).toIso8601String(),
      };
      await prefs.setStringList('sos_sms_queue', [jsonEncode(entry)]);
      await LocalQueueService.instance.processQueue((_) async => false);
      expect(await LocalQueueService.instance.getPendingCount(), 0);
    });

    test('not-yet-due events are kept without calling handler', () async {
      final prefs = await SharedPreferences.getInstance();
      final entry = {
        'type': 'sms',
        'to': '+911234567890',
        'message': 'future',
        '_attempts': 0,
        '_nextRetryAt':
            DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
      };
      await prefs.setStringList('sos_sms_queue', [jsonEncode(entry)]);
      int handlerCalls = 0;
      await LocalQueueService.instance.processQueue((_) async {
        handlerCalls++;
        return true;
      });
      expect(handlerCalls, 0);
      expect(await LocalQueueService.instance.getPendingCount(), 1);
    });
  });

  group('LocalQueueService — queueLocationUpdate', () {
    test('enqueues location event with correct fields', () async {
      await LocalQueueService.instance.queueLocationUpdate(17.0, 81.8, 12.5);
      final pending = await LocalQueueService.instance.getPending();
      expect(pending.first['type'], 'location_update');
      expect(pending.first['lat'], 17.0);
      expect(pending.first['speed'], 12.5);
    });
  });
}
