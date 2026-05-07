import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/api_service.dart';
import 'driving_mode_page.dart';
import 'full_route_map_screen.dart';

class RouteSuggestionPage extends StatefulWidget {
  const RouteSuggestionPage({super.key});

  @override
  State<RouteSuggestionPage> createState() => _RouteSuggestionPageState();
}

class _RouteSuggestionPageState extends State<RouteSuggestionPage> {
  final MapController _mapController = MapController();
  final TextEditingController _destinationController = TextEditingController();
  final LayerLink _overlayLink = LayerLink();
  OverlayEntry? _suggestionOverlay;
  final DraggableScrollableController _sheetController = DraggableScrollableController();

  LatLng _userPos = const LatLng(17.38, 78.49); // safe default
  LatLng? _destinationPos;
  String? _destinationName;

  bool _isLocationLoading = true;
  bool _isSearching = false;
  bool _isFetchingRoutes = false;

  List<dynamic> _routes = [];
  List<Map<String, dynamic>> _geocodeSuggestions = [];
  int _selectedRouteIndex = 0;
  List<Polyline> _polylines = [];
  bool _hasRoutes = false;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeSuggestions();
    _destinationController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    try {
      final pos = await LocationService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _userPos = LatLng(pos.latitude, pos.longitude);
          _isLocationLoading = false;
        });
        _mapController.move(_userPos, 15.0);
      }
    } catch (e) {
      if (mounted) setState(() => _isLocationLoading = false);
    }
  }

  void _onDestinationChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 3) {
      _removeSuggestions();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _isSearching = true);
      final results = await ApiService.geocodeAddress(query);
      if (mounted) {
        setState(() {
          _geocodeSuggestions = results;
          _isSearching = false;
        });
        if (results.isNotEmpty) _showSuggestions();
      }
    });
  }

  void _showSuggestions() {
    _removeSuggestions();
    _suggestionOverlay = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width - 32,
        child: CompositedTransformFollower(
          link: _overlayLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 56),
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 250),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _geocodeSuggestions.length,
                itemBuilder: (_, i) {
                  final s = _geocodeSuggestions[i];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.location_on, color: AppColors.primary, size: 20),
                    title: Text(
                      s['displayName'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    onTap: () => _selectDestination(s),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_suggestionOverlay!);
  }

  void _removeSuggestions() {
    _suggestionOverlay?.remove();
    _suggestionOverlay = null;
  }

  void _selectDestination(Map<String, dynamic> place) {
    _removeSuggestions();
    setState(() {
      _destinationPos  = LatLng(place['lat'], place['lng']);
      _destinationName = place['displayName'];
      _destinationController.text = place['displayName'];
      _routes = [];
      _polylines = [];
      _hasRoutes = false;
    });

    // Auto-trigger route fetch after selection
    _fetchRoutes();
  }

  void _clearDestination() {
    setState(() {
      _destinationController.clear();
      _destinationPos = null;
      _destinationName = null;
      _geocodeSuggestions = [];
      _routes = [];
      _polylines = [];
      _hasRoutes = false;
    });
    _removeSuggestions();
    // Reset map view to user position
    _mapController.move(_userPos, 15.0);
  }

  Future<void> _fetchRoutes() async {
    if (_destinationPos == null) {
      if (_destinationController.text.length >= 3) {
        // If user typed but didn't select, try one last time with current text
        final results = await ApiService.geocodeAddress(_destinationController.text);
        if (results.isNotEmpty) {
          _selectDestination(results.first);
          return;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a destination in India')),
      );
      return;
    }

    setState(() {
      _isFetchingRoutes = true;
      _hasRoutes = false;
    });

    final data = await ApiService.suggestRoutes(
      startLat: _userPos.latitude,
      startLng: _userPos.longitude,
      destLat:  _destinationPos!.latitude,
      destLng:  _destinationPos!.longitude,
    );

    if (!mounted) return;
    if (data['routes'] != null) {
      final routesData = data['routes'] as List<dynamic>;
      
      // Default to safest route (which is already first due to backend sorting)
      setState(() {
        _routes = routesData;
        _isFetchingRoutes = false;
        _hasRoutes = true;
        _selectedRouteIndex = 0;
      });

      // Zoom map to show both points with enough padding for the sheet
      final bounds = LatLngBounds.fromPoints([_userPos, _destinationPos!]);
      _mapController.fitCamera(CameraFit.bounds(
        bounds: bounds, 
        padding: const EdgeInsets.fromLTRB(50, 150, 50, 300)
      ));
    } else {
      setState(() => _isFetchingRoutes = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['error'] ?? 'Could not find routes in this area.')),
      );
    }
  }

  Color _colorFromString(String? c) {
    switch (c) {
      case 'green':  return AppColors.safe;
      case 'yellow': return AppColors.idle;
      case 'red':    return AppColors.risk;
      default:       return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 1. Map (Base Layer)
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _userPos,
                initialZoom: 15.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.safepulse.app',
                ),
                if (_hasRoutes && _routes.isNotEmpty)
                  PolylineLayer(
                    polylines: _routes.asMap().entries.map<Polyline>((e) {
                      final idx = e.key;
                      final r = e.value;
                      final selected = idx == _selectedRouteIndex;
                      final polyData = r['polyline'] as List?;
                      if (polyData == null) return Polyline(points: [], color: Colors.transparent);
                      
                      final pts = polyData
                          .map((p) => LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()))
                          .toList();
                      return Polyline(
                        points: pts,
                        color: selected ? _colorFromString(r['color']) : _colorFromString(r['color']).withOpacity(0.3),
                        strokeWidth: selected ? 8 : 4,
                      );
                    }).toList(),
                  ),
                MarkerLayer(markers: [
                  Marker(
                    point: _userPos,
                    width: 40, height: 40,
                    child: const Icon(Icons.my_location, color: Colors.blue, size: 30),
                  ),
                  if (_destinationPos != null)
                    Marker(
                      point: _destinationPos!,
                      width: 40, height: 40,
                      child: const Icon(Icons.location_on, color: Colors.red, size: 36),
                    ),
                ]),
              ],
            ),
          ),

          // 2. Top Search Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  FadeInDown(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        children: [
                          _buildInputTile(
                            icon: Icons.my_location,
                            color: Colors.blue,
                            text: _isLocationLoading ? 'Getting location...' : 'Your Location',
                            isReadOnly: true,
                          ),
                          const Divider(height: 1, color: Colors.white10, indent: 40),
                          CompositedTransformTarget(
                            link: _overlayLink,
                            child: TextField(
                              controller: _destinationController,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              onChanged: _onDestinationChanged,
                              decoration: InputDecoration(
                                hintText: 'Search destination in India...',
                                hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                                prefixIcon: const Icon(Icons.location_on, color: Colors.redAccent, size: 20),
                                suffixIcon: _destinationController.text.isNotEmpty 
                                    ? IconButton(
                                        icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                                        onPressed: _clearDestination,
                                      )
                                    : (_isSearching
                                        ? const Padding(
                                            padding: EdgeInsets.all(14),
                                            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                          )
                                        : IconButton(
                                            icon: const Icon(Icons.search, color: AppColors.primary),
                                            onPressed: _fetchRoutes,
                                          )),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Draggable Route Panel (Bottom Sheet)
          if (_hasRoutes && _routes.isNotEmpty)
            DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: 0.4,
              minChildSize: 0.15,
              maxChildSize: 0.8,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                    boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 20)],
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Column(
                      children: [
                        // Drag handle
                        Container(
                          width: 40, height: 4,
                          margin: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
                        ),
                        _buildRouteList(),
                      ],
                    ),
                  ),
                );
              },
            ),

          // 4. Loading Overlay
          if (_isFetchingRoutes)
            Container(
              color: Colors.black45,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 16),
                    Text('Analyzing safety for India routes...', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInputTile({required IconData icon, required Color color, required String text, bool isReadOnly = false}) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: color, size: 20),
      title: Text(text, style: TextStyle(color: isReadOnly ? Colors.grey : Colors.white, fontSize: 14)),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildRouteList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Suggested Safe Routes', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              TextButton.icon(
                icon: const Icon(Icons.fullscreen, size: 18),
                label: const Text('Full Map', style: TextStyle(fontSize: 13)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FullRouteMapScreen(
                        currentLocation: _userPos,
                        destination: _destinationPos!,
                        routes: _routes,
                        selectedRouteIndex: _selectedRouteIndex,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._routes.asMap().entries.map((e) => _buildRouteCard(e.key, e.value)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _startJourney,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Start Safe Journey', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildRouteCard(int index, dynamic route) {
    final selected = index == _selectedRouteIndex;
    final color = _colorFromString(route['color']);
    
    return GestureDetector(
      onTap: () {
        setState(() => _selectedRouteIndex = index);
        // Center map on selected route
        final pts = (route['polyline'] as List)
            .map((p) => LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()))
            .toList();
        _mapController.fitCamera(CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(pts),
          padding: const EdgeInsets.all(100)
        ));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.1) : AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? color : Colors.white10, width: 2),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fmtDuration(route['duration'].toDouble()),
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  _fmtDist(route['distance'].toDouble()),
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                  child: Text(route['type'], style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 4),
                Text('Risk: ${route['riskScore']}', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedRouteSummary() {
    final route = _routes[_selectedRouteIndex];
    final color = _colorFromString(route['color']);
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.directions_car, color: Colors.white70),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_fmtDuration(route['duration'].toDouble()), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('${_fmtDist(route['distance'].toDouble())} • Safe Path', style: const TextStyle(color: Colors.grey)),
                ],
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _startJourney,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Start', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  void _startJourney() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DrivingModePage(
          initialLocation: _userPos,
          selectedRoute: Map<String, dynamic>.from(_routes[_selectedRouteIndex]),
        ),
      ),
    );
  }

  String _fmtDuration(double s) {
    final m = (s / 60).round();
    if (m < 60) return '$m min';
    return '${m ~/ 60}h ${m % 60}m';
  }

  String _fmtDist(double m) {
    if (m < 1000) return '${m.round()} m';
    return '${(m / 1000).toStringAsFixed(1)} km';
  }
}
