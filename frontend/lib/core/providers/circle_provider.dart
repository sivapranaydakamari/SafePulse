import 'package:flutter/foundation.dart';
import '../repositories/circle_repository.dart';

class CircleProvider extends ChangeNotifier {
  final CircleRepository _repo;

  CircleProvider(this._repo);

  List<dynamic> _circles = [];
  bool _isLoading = false;
  String? _error;

  List<dynamic> get circles => _circles;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadCircles() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _repo.getMyCircles();
      if (result['success'] == true) {
        _circles = result['circles'] ?? [];
      } else {
        _error = result['error'] ?? 'Failed to load circles';
      }
    } catch (e) {
      _error = 'Unexpected error loading circles';
      debugPrint('[CircleProvider] error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createCircle(String name) async {
    final result = await _repo.createCircle(name);
    if (result['success'] == true) {
      await loadCircles(); // refresh the list
      return true;
    }
    return false;
  }

  Future<bool> joinCircle(String inviteCode) async {
    final result = await _repo.joinCircle(inviteCode);
    if (result['success'] == true) {
      await loadCircles();
      return true;
    }
    return false;
  }
}
