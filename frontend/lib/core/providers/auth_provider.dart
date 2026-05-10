import 'package:flutter/foundation.dart';
import '../repositories/user_repository.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final UserRepository _repo;

  AuthProvider(this._repo);

  AuthStatus _status = AuthStatus.unknown;
  String? _userId;
  Map<String, dynamic>? _profile;

  AuthStatus get status => _status;
  String? get userId => _userId;
  Map<String, dynamic>? get profile => _profile;
  bool get isLoggedIn => _status == AuthStatus.authenticated;

  // Called once at app startup
  Future<void> initialize() async {
    final loggedIn = await _repo.isLoggedIn();
    _userId = await _repo.getUserId();
    _status = loggedIn ? AuthStatus.authenticated : AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> saveSession({
    required String userId,
    required String token,
  }) async {
    await _repo.saveSession(userId: userId, token: token);
    _userId = userId;
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> logout() async {
    await _repo.clearSession();
    _userId = null;
    _profile = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> loadProfile() async {
    final result = await _repo.getProfile();
    if (result['success'] == true) {
      _profile = result['user'];
      notifyListeners();
    }
  }
}
