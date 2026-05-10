import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class UserRepository {
  // Single source of truth for session data
  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId');
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('userId') && prefs.containsKey('auth_token');
  }

  Future<void> saveSession({
    required String userId,
    required String token,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', userId);
    await prefs.setString('auth_token', token);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    await prefs.remove('auth_token');
  }

  Future<Map<String, dynamic>> getProfile() {
    return ApiService.getMyProfile();
  }
}
