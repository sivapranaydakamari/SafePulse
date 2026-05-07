import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/dnd_service.dart';
import '../../../core/services/safety_ai_service.dart';
import '../../sos/screens/sos_active_page.dart';
import '../../tracking/services/motion_service.dart';
import 'route_suggestion_page.dart';

class DrivingModePage extends StatefulWidget {
  final Map<String, dynamic> selectedRoute;
  final LatLng? initialLocation;

  const DrivingModePage({
    super.key, 
    required this.selectedRoute,
    this.initialLocation,
  });

  @override
  State<DrivingModePage> createState() => _DrivingModePageState();
}

class _DrivingModePageState extends State<DrivingModePage> {
  final MotionService _motionService = MotionService();
  final MapController _mapController = MapController();

  StreamSubscription<Position>? _positionSub;
  StreamSubscription? _brakingSub;
  StreamSubscription? _crashSub;

  LatLng _currentPos = const LatLng(0, 0);
  double _currentSpeed = 0;
  double _heading = 0;
  bool _isLocationLoaded = false;
  String? _locationError;
  bool _isRetrying = false;

  // Speed monitoring
  DateTime? _lastPosTime;
  LatLng? _lastPos;
  final List<double> _speedBuffer = [];
  Timer? _overspeedTimer;
  int _overspeedSeconds = 0;
  bool _dndActive = false;

  // Journey stats
  double _distanceRemaining = 0;
  String _eta = '--:--';
  int _closestPointIndex = 0;

  bool _isOverSpeeding = false;
  bool _isOffRoute = false;
  bool _isRerouting = false;
  final List<Map<String, dynamic>> _alerts = [];
  String _aiSafetyMessage = "Analyzing safety...";
  SafetyStatus _safetyStatus = SafetyStatus.normal;

  late List<LatLng> _polylinePoints;
  late Color _routeColor;
  Timer? _statusTimer;
  bool _isOpeningSOS = false;

  @override
  void initState() {
    super.initState();
    _polylinePoints = (widget.selectedRoute['polyline'] as List)
        .map((p) => LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()))
        .toList();
    _distanceRemaining = (widget.selectedRoute['distance'] as num).toDouble();
    _routeColor = _colorFromString(widget.selectedRoute['color']);
    
    // Use initial location if provided
    if (widget.initialLocation != null && widget.initialLocation!.latitude != 0) {
      _currentPos = widget.initialLocation!;
      _isLocationLoaded = true;
    }

    _loadCurrentLocation();
    _startStatusUpdates();
    _checkDndPermission();
  }

  Future<void> _loadCurrentLocation() async {
    setState(() {
      _locationError = null;
      _isRetrying = true;
    });

    try {
      // 1. Try last known location first (very fast)
      if (!_isLocationLoaded) {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null && mounted) {
          setState(() {
            _currentPos = LatLng(lastKnown.latitude, lastKnown.longitude);
            _isLocationLoaded = true;
          });
        }
      }

      // 2. Fetch fresh GPS with timeout
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 8));

      if (mounted) {
        setState(() {
          _currentPos = LatLng(pos.latitude, pos.longitude);
          _isLocationLoaded = true;
          _isRetrying = false;
        });
        _startTracking(); // Start streaming after getting initial fix
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRetrying = false;
          // Only show error if we still don't have ANY location
          if (!_isLocationLoaded) {
            _locationError = "Unable to get GPS location. Please check your settings and try again.";
          } else {
            // We have a position (from initial or lastKnown), so just start streaming
            _startTracking();
          }
        });
      }
    }
  }

  Future<void> _checkDndPermission() async {
    if (!await DndService.isPermissionGranted()) {
      debugPrint('[DND] Prompting for permission');
      // In a real app, show a snackbar or dialog asking user to enable DND access
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _brakingSub?.cancel();
    _crashSub?.cancel();
    _statusTimer?.cancel();
    _overspeedTimer?.cancel();
    DndService.setDndOff(); // Ensure DND is off when leaving
    super.dispose();
  }

  void _startTracking() {
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 2),
    ).listen((pos) {
      if (mounted) _onPosition(pos);
    });

    _brakingSub = _motionService.monitorSuddenBraking().listen((braking) {
      if (braking) _addAlert(Icons.warning, 'Sudden braking', 'Rapid deceleration detected', Colors.orange);
    });

    _crashSub = _motionService.monitorCrash().listen((crash) {
      if (crash) _addAlert(Icons.car_crash, 'CRASH DETECTED', 'High-impact event. Triggering SOS.', Colors.red);
    });
  }

  void _startStatusUpdates() {
    _statusTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_currentPos.latitude != 0) {
        ApiService.updateStatus(
          lat: _currentPos.latitude,
          lng: _currentPos.longitude,
          isDriving: true,
          currentSpeed: _currentSpeed,
        );
      }
    });
  }

  void _onPosition(Position pos) {
    if (pos.accuracy > 30) return; // Ignore inaccurate points

    final newPos = LatLng(pos.latitude, pos.longitude);
    final now = DateTime.now();

    // 1. Accurate Speed Calculation
    double speedKmh = pos.speed * 3.6;
    if (pos.speed <= 0 && _lastPos != null && _lastPosTime != null) {
      // Fallback: Distance / Time
      final dist = Geolocator.distanceBetween(_lastPos!.latitude, _lastPos!.longitude, newPos.latitude, newPos.longitude);
      final timeSec = now.difference(_lastPosTime!).inMilliseconds / 1000.0;
      if (timeSec > 0.5) {
        speedKmh = (dist / timeSec) * 3.6;
      }
    }

    // Smoothing (Moving Average of last 3 points)
    _speedBuffer.add(speedKmh);
    if (_speedBuffer.length > 3) _speedBuffer.removeAt(0);
    final smoothedSpeed = _speedBuffer.reduce((a, b) => a + b) / _speedBuffer.length;

    // 2. Overspeed Monitoring (Limit: 80 km/h)
    if (smoothedSpeed > 80) {
      _overspeedSeconds++;
      if (_overspeedSeconds >= 10 && !_dndActive) {
        _triggerOverspeedResponse(smoothedSpeed, newPos);
      }
    } else {
      if (_overspeedSeconds > 0) {
        _overspeedSeconds--; // Gradual cool down
      }
      if (_overspeedSeconds == 0 && _dndActive) {
        _stopOverspeedResponse();
      }
    }

    // 3. AI Safety Analysis
    final aiResult = SafetyAiMonitorService.analyzeRisk(
      speed: smoothedSpeed,
      riskZoneScore: widget.selectedRoute['riskScore'] ?? 0,
      isOffRoute: _isOffRoute,
      time: now,
    );

    // Update state
    setState(() {
      _currentPos = newPos;
      _currentSpeed = smoothedSpeed;
      _heading = pos.heading;
      _isLocationLoaded = true;
      _lastPos = newPos;
      _lastPosTime = now;
      _aiSafetyMessage = aiResult['message'];
      _safetyStatus = aiResult['status'];
      _isOverSpeeding = smoothedSpeed > 65;
    });

    _mapController.move(_currentPos, 17);
    _mapController.rotate(-_heading);

    // Route specific logic (if journey active)
    if (_polylinePoints.isNotEmpty) {
      _processRouteLogic(newPos, smoothedSpeed);
    }
  }

  void _processRouteLogic(LatLng newPos, double speed) {
    double minDist = double.infinity;
    int closest = _closestPointIndex;
    final start = (_closestPointIndex - 5).clamp(0, _polylinePoints.length - 1);
    for (int i = start; i < _polylinePoints.length; i++) {
      final d = Geolocator.distanceBetween(newPos.latitude, newPos.longitude, _polylinePoints[i].latitude, _polylinePoints[i].longitude);
      if (d < minDist) {
        minDist = d;
        closest = i;
      }
    }
    _closestPointIndex = closest;

    double remaining = 0;
    for (int i = closest; i < _polylinePoints.length - 1; i++) {
      remaining += Geolocator.distanceBetween(_polylinePoints[i].latitude, _polylinePoints[i].longitude, _polylinePoints[i+1].latitude, _polylinePoints[i+1].longitude);
    }

    String eta = '--:--';
    if (speed > 5) {
      final hoursLeft = (remaining / 1000) / speed;
      final etaTime = DateTime.now().add(Duration(seconds: (hoursLeft * 3600).round()));
      eta = DateFormat('hh:mm a').format(etaTime);
    }

    final offRoute = minDist > 65;
    if (offRoute && !_isOffRoute) {
      _addAlert(Icons.alt_route, 'Off route', 'Rerouting to safe path...', Colors.redAccent);
      _reroute(newPos);
    }

    setState(() {
      _distanceRemaining = remaining;
      _eta = eta;
      _isOffRoute = offRoute;
    });
  }

  void _triggerOverspeedResponse(double speed, LatLng pos) {
    _dndActive = true;
    DndService.setDndOn();
    _addAlert(Icons.do_not_disturb_on, 'DND Active', 'High speed detected. Focus on road.', Colors.red);
    
    // Alert Circle Members (with backend cooldown)
    ApiService.sendSpeedAlert(
      speed: speed,
      lat: pos.latitude,
      lon: pos.longitude,
      limit: 80,
    );
  }

  void _stopOverspeedResponse() {
    _dndActive = false;
    DndService.setDndOff();
    _addAlert(Icons.check_circle, 'Safe speed', 'DND Mode disabled', Colors.green);
  }

  Future<void> _reroute(LatLng from) async {
    if (_isRerouting || _polylinePoints.isEmpty) return;
    setState(() => _isRerouting = true);
    final dest = _polylinePoints.last;
    final data = await ApiService.suggestRoutes(
      startLat: from.latitude, startLng: from.longitude,
      destLat: dest.latitude, destLng: dest.longitude,
    );
    if (!mounted) return;
    if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
      final bestRoute = (data['routes'] as List).first;
      final newPoints = (bestRoute['polyline'] as List).map((p) => LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble())).toList();
      setState(() {
        _polylinePoints = newPoints;
        _closestPointIndex = 0;
        _isRerouting = false;
        _isOffRoute = false;
      });
    } else {
      setState(() => _isRerouting = false);
    }
  }

  void _addAlert(IconData icon, String title, String sub, Color color) {
    if (_alerts.isNotEmpty && _alerts.first['title'] == title && DateTime.now().difference(_alerts.first['time'] as DateTime).inSeconds < 15) return;
    setState(() {
      _alerts.insert(0, {'icon': icon, 'title': title, 'sub': sub, 'color': color, 'time': DateTime.now()});
      if (_alerts.length > 3) _alerts.removeLast();
    });
  }

  Color _colorFromString(String? c) {
    switch (c) {
      case 'green': return AppColors.safe;
      case 'yellow': return AppColors.idle;
      case 'red': return AppColors.risk;
      default: return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: !_isLocationLoaded
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_locationError == null) ...[
                      const CircularProgressIndicator(color: AppColors.primary),
                      const SizedBox(height: 24),
                      const Text('Getting your location...', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Using GPS for high precision tracking', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                    ] else ...[
                      const Icon(Icons.location_off_outlined, color: Colors.redAccent, size: 64),
                      const SizedBox(height: 24),
                      const Text('Location Unavailable', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Text(_locationError!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: _isRetrying ? null : _loadCurrentLocation,
                        icon: _isRetrying ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.refresh),
                        label: Text(_isRetrying ? 'Retrying...' : 'Retry Now'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          minimumSize: const Size(200, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Go Back', style: TextStyle(color: Colors.grey)),
                      ),
                    ],
                  ],
                ),
              ),
            )
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(initialCenter: _currentPos, initialZoom: 17),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.safepulse.app',
                    ),
                    if (_polylinePoints.isNotEmpty)
                      PolylineLayer(polylines: [
                        Polyline(points: _polylinePoints, color: _routeColor, strokeWidth: 8),
                      ]),
                    MarkerLayer(markers: [
                      Marker(
                        point: _currentPos,
                        width: 50, height: 50,
                        child: Transform.rotate(
                          angle: _heading * (3.14159 / 180),
                          child: const Icon(Icons.navigation, color: AppColors.primary, size: 38),
                        ),
                      ),
                    ]),
                  ],
                ),

                // Top HUD
                SafeArea(
                  child: Column(
                    children: [
                      // AI Safety Monitor Card
                      FadeInDown(
                        child: Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: _safetyStatus == SafetyStatus.danger ? Colors.red.withOpacity(0.9) : AppColors.cardBg.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _safetyStatus == SafetyStatus.danger ? Colors.white : AppColors.surface),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _safetyStatus == SafetyStatus.danger ? Icons.gpp_bad : Icons.gpp_good,
                                color: _safetyStatus == SafetyStatus.danger ? Colors.white : AppColors.safe,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _aiSafetyMessage,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Stats bar
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.cardBg.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _statItem('Speed', '${_currentSpeed.toStringAsFixed(0)} km/h', _currentSpeed > 80 ? Colors.red : (_currentSpeed > 65 ? Colors.orange : Colors.white)),
                            _statItem('ETA', _eta, Colors.white),
                            _statItem('Remaining', _polylinePoints.isEmpty ? '--' : (_distanceRemaining < 1000 ? '${_distanceRemaining.round()} m' : '${(_distanceRemaining / 1000).toStringAsFixed(1)} km'), Colors.white),
                            _statItem('Risk', _polylinePoints.isEmpty ? 'N/A' : '${widget.selectedRoute['riskScore']}', _routeColor),
                          ],
                        ),
                      ),

                      // Alerts
                      const SizedBox(height: 8),
                      ..._alerts.take(2).map((a) => _buildAlert(a)),
                    ],
                  ),
                ),

                // SOS + Stop
                Positioned(
                  right: 16,
                  bottom: 30,
                  child: Column(
                    children: [
                      FloatingActionButton(
                        heroTag: 'sos', 
                        backgroundColor: _isOpeningSOS ? Colors.grey : Colors.red, 
                        onPressed: _isOpeningSOS ? null : _triggerSOS, 
                        child: _isOpeningSOS 
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('SOS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12))
                      ),
                      const SizedBox(height: 12),
                      FloatingActionButton(heroTag: 'stop', backgroundColor: AppColors.cardBg, onPressed: () => Navigator.pop(context), mini: true, child: const Icon(Icons.stop, color: Colors.white)),
                    ],
                  ),
                ),

                // No journey tracking card
                if (_polylinePoints.isEmpty)
                  Positioned(
                    bottom: 30, left: 16, right: 80,
                    child: FadeInUp(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: AppColors.cardBg.withOpacity(0.95), borderRadius: BorderRadius.circular(24)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Active Speed Monitoring', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RouteSuggestionPage())),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, minimumSize: const Size(double.infinity, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              child: const Text('Start Full Journey', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
    ]);
  }

  Widget _buildAlert(Map<String, dynamic> a) {
    return FadeInLeft(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: (a['color'] as Color).withOpacity(0.9), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Icon(a['icon'] as IconData, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            Text(a['sub'], style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ])),
        ]),
      ),
    );
  }

  Future<void> _triggerSOS() async {
    if (_isOpeningSOS) return;
    setState(() => _isOpeningSOS = true);

    try {
      final result = await ApiService.startSOS(
        lat: _currentPos.latitude, 
        lng: _currentPos.longitude, 
        address: 'Emergency during tracking'
      );
      if (result != null && mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => SOSActivePage(sosId: result['sosId'], initialLocation: _currentPos)));
      }
    } finally {
      if (mounted) setState(() => _isOpeningSOS = false);
    }
  }
}
