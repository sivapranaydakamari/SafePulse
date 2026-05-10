import 'package:flutter/foundation.dart';
import '../repositories/sos_repository.dart';

enum SOSStatus { idle, active, cancelled }

class SOSProvider extends ChangeNotifier {
  final SOSRepository _repo;

  SOSProvider(this._repo);

  SOSStatus _status = SOSStatus.idle;
  String? _activeSosId;
  bool _isLoading = false;
  Map<String, dynamic>? _nearbyData;

  SOSStatus get status => _status;
  String? get activeSosId => _activeSosId;
  bool get isLoading => _isLoading;
  bool get isActive => _status == SOSStatus.active;
  Map<String, dynamic>? get nearbyData => _nearbyData;

  Future<bool> startSOS({
    required double lat,
    required double lng,
    String? address,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _repo.startSOS(lat: lat, lng: lng, address: address);
      if (result != null) {
        _activeSosId = result['sosId'] as String?;
        _status = SOSStatus.active;
        return true;
      }
    } catch (e) {
      debugPrint('[SOSProvider] startSOS error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  Future<void> cancelSOS() async {
    if (_activeSosId == null) return;
    final success = await _repo.cancelSOS(_activeSosId!);
    if (success) {
      _status = SOSStatus.cancelled;
      _activeSosId = null;
      notifyListeners();
    }
  }

  Future<void> loadNearbyServices({
    required double lat,
    required double lon,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      _nearbyData = await _repo.getNearbyServices(lat: lat, lon: lon);
    } catch (e) {
      debugPrint('[SOSProvider] loadNearbyServices error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void reset() {
    _status = SOSStatus.idle;
    _activeSosId = null;
    notifyListeners();
  }
}
