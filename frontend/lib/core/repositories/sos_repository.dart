// MOVED FROM: lib/core/repositories/sos_repository.dart
import '../services/api_service.dart';
import '../models/sos_event.dart';

class SOSRepository {
  Future<SOSEvent?> startSOS({
    required double lat,
    required double lng,
    String? address,
  }) async {
    final result = await ApiService.startSOS(lat: lat, lng: lng, address: address);
    if (result != null) {
      return SOSEvent.fromJson(result);
    }
    return null;
  }

  Future<bool> cancelSOS(String sosId) {
    return ApiService.cancelSOS(sosId);
  }

  Future<SOSEvent?> getStatus(String sosId) async {
    final result = await ApiService.getSOSStatus(sosId);
    if (result != null) {
      return SOSEvent.fromJson(result);
    }
    return null;
  }

  Future<Map<String, dynamic>> getNearbyServices({
    required double lat,
    required double lon,
  }) {
    return ApiService.getNearbyServices(lat: lat, lon: lon);
  }

  Future<bool> sendSafePulseSOS(
    double lat,
    double lng,
    String severity, {
    bool hasLocation = true,
    int? locationAgeSec,
  }) {
    return ApiService.sendSafePulseSOS(
      lat,
      lng,
      severity,
      hasLocation: hasLocation,
      locationAgeSec: locationAgeSec,
    );
  }
}
