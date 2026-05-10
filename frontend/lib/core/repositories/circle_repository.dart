// MOVED FROM: lib/core/repositories/circle_repository.dart
import '../services/api_service.dart';
import '../models/circle.dart';

class CircleRepository {
  Future<List<Circle>> getMyCircles() async {
    final result = await ApiService.getUserCircles();
    if (result['success'] == true && result['circles'] != null) {
      return (result['circles'] as List)
          .map((e) => Circle.fromJson(e))
          .toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> createCircle(String name) {
    return ApiService.createCircle(name);
  }

  Future<Map<String, dynamic>> joinCircle(String inviteCode) {
    return ApiService.joinCircle(inviteCode);
  }
}
