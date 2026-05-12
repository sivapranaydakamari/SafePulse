// SafePulse Problem Gap #5: Safety Circle gets real-time location via WebSocket + Firestore mirror.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import 'api_service.dart';

enum TrackingStatus { connected, failedNoToken, failedNetworkError }

class RealtimeTrackingService {
  WebSocket? _socket;
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  bool _disposed = false;
  String? _userId;
  String? _mongoUserId;
  // Circle IDs the current user belongs to — written to Firestore so Safety Circle
  // map queries can filter with .where('circleIds', arrayContains: circleId).
  List<String> _circleIds = [];

  Stream<Map<String, dynamic>> get events => _events.stream;

  bool get isConnected => _socket?.readyState == WebSocket.open;

  Future<TrackingStatus> connect() async {
    final token = await ApiService.getToken();
    if (token == null || token.isEmpty) {
      return TrackingStatus.failedNoToken;
    }

    // Cache both IDs for Firestore location mirroring.
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId');
    _mongoUserId = prefs.getString('mongoUserId') ?? prefs.getString('_id');

    try {
      var wsUri = Uri.parse(AppConfig.realtimeUrl);
      // Normalise http/https → ws/wss
      if (wsUri.scheme == 'https') {
        wsUri = wsUri.replace(scheme: 'wss');
      } else if (wsUri.scheme == 'http') {
        wsUri = wsUri.replace(scheme: 'ws');
      }
      // Enforce wss:// for any non-localhost host in production
      if (wsUri.scheme == 'ws' &&
          wsUri.host != 'localhost' &&
          wsUri.host != '127.0.0.1') {
        wsUri = wsUri.replace(scheme: 'wss');
      }
      final uri = wsUri.replace(queryParameters: {'token': token});
      _socket = await WebSocket.connect(uri.toString());
      _socket!.listen(
        (raw) {
          if (!_disposed) _events.add(jsonDecode(raw as String) as Map<String, dynamic>);
        },
        onError: (error) {
          if (!_disposed) _events.add({'type': 'connection:error', 'error': '$error'});
        },
        onDone: () {
          if (!_disposed) _events.add({'type': 'connection:closed'});
        },
        cancelOnError: true,
      );
      return TrackingStatus.connected;
    } catch (e) {
      return TrackingStatus.failedNetworkError;
    }
  }

  /// Call this whenever the set of circles the user belongs to changes so that
  /// subsequent Firestore location writes include the correct circleIds array.
  void setCircleIds(List<String> ids) {
    _circleIds = List<String>.from(ids);
  }

  void sendTrackingUpdate({
    required double speed,
    required bool isPhoneOn,
    double? lat,
    double? lng,
    List<String> circleMemberIds = const [],
  }) {
    _send({
      'type': 'tracking:update',
      'speed': speed,
      'isPhoneOn': isPhoneOn,
      if (lat != null && lng != null) 'location': {'lat': lat, 'lng': lng},
      'circleMemberIds': circleMemberIds,
    });

    // Mirror to Firestore as a supplementary real-time channel.
    // Failures are silently swallowed so the primary WebSocket path is never blocked.
    if (lat != null && lng != null) {
      _mirrorLocationToFirestore(lat, lng);
    }
  }

  // SafePulse Problem Gap #5: Firestore is the primary channel for Safety Circle visibility.
  void updateLocation(Position position) {
    if (position.latitude == 0.0 && position.longitude == 0.0) return;
    _mirrorLocationToFirestore(position.latitude, position.longitude);
    _send({
      'type': 'tracking:update',
      'speed': position.speed,
      'isPhoneOn': false,
      'location': {'lat': position.latitude, 'lng': position.longitude},
    });
  }

  void sendSosStarted({
    required String sosId,
    required double lat,
    required double lng,
    List<String> circleMemberIds = const [],
  }) {
    _send({
      'type': 'sos:started',
      'sosId': sosId,
      'location': {'lat': lat, 'lng': lng},
      'circleMemberIds': circleMemberIds,
    });
  }

  void _mirrorLocationToFirestore(double lat, double lng) {
    final uid = _userId;
    if (uid == null || uid.isEmpty) return;
    FirebaseFirestore.instance
        .collection('live_locations')
        .doc(uid)
        .set({
          'lat': lat,
          'lng': lng,
          'ts': FieldValue.serverTimestamp(),
          'userId': uid,
          'mongoId': _mongoUserId ?? '',
          // circleIds is an array so circle_map_page.dart can query with
          // .where('circleIds', arrayContains: widget.circleId).
          'circleIds': _circleIds,
        }, SetOptions(merge: true))
        .catchError((e) {
          debugPrint('[Firestore] Location sync failed: $e');
        });
  }

  void _send(Map<String, dynamic> message) {
    if (!isConnected) return;
    _socket!.add(jsonEncode(message));
  }

  Future<void> dispose() async {
    _disposed = true;
    await _socket?.close();
    await _events.close();
  }

  Future<void> disconnect() async {
    await _socket?.close();
    _socket = null;
  }
}
