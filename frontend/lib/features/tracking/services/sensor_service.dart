import 'dart:async';
import 'package:geolocator/geolocator.dart';
// import 'package:sensors_plus/sensors_plus.dart'; // Add this to pubspec later for braking detection

class SensorService {
  StreamSubscription<Position>? _positionSubscription;

  /// Starts monitoring user behavior (Speed, Acceleration).
  /// In a real app, this would stream data to the backend.
  void startMonitoring({
    required Function(double speed) onSpeedChanged,
    required Function() onSuddenBraking,
  }) {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        // Convert m/s to km/h
        double speedKmH = position.speed * 3.6;
        onSpeedChanged(speedKmH);

        // Simple mock for sudden braking logic
        // In real app: use accelerometer data (sensors_plus)
      },
    );
  }

  void stopMonitoring() {
    _positionSubscription?.cancel();
  }
}
