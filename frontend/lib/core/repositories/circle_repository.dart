import '../services/api_service.dart';

class CircleRepository {
  Future<Map<String, dynamic>> getMyCircles() {
    return ApiService.getUserCircles();
  }

  Future<Map<String, dynamic>> createCircle(String name) {
    return ApiService.createCircle(name);
  }

  Future<Map<String, dynamic>> joinCircle(String inviteCode) {
    return ApiService.joinCircle(inviteCode);
  }
}
