import '../services/api_service.dart';

class SOSRepository {
  Future<Map<String, dynamic>?> startSOS({
    required double lat,
    required double lng,
    String? address,
  }) {
    return ApiService.startSOS(lat: lat, lng: lng, address: address);
  }

  Future<bool> cancelSOS(String sosId) {
    return ApiService.cancelSOS(sosId);
  }

  Future<Map<String, dynamic>?> getStatus(String sosId) {
    return ApiService.getSOSStatus(sosId);
  }

  Future<Map<String, dynamic>> getNearbyServices({
    required double lat,
    required double lon,
  }) {
    return ApiService.getNearbyServices(lat: lat, lon: lon);
  }
}
