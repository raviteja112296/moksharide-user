import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:moksharide_user/features/home/data/routing_service.dart';

class RideMapWidget extends StatefulWidget {
  final LatLng initialCenter;
  final LatLng? pickupLatLng;
  final LatLng? dropLatLng;
  final LatLng? driverLatLng;
  final double driverHeading;
  final bool isRideStarted; // false = Driver -> Pickup, true = Driver -> Drop
  
  // 🆕 NEW: Optional callback if you want the parent widget to know about the re-route
  final VoidCallback? onOffRoute; 
  final void Function(GoogleMapController)? onMapCreated;

  const RideMapWidget({
    super.key,
    required this.initialCenter,
    this.pickupLatLng,
    this.dropLatLng,
    this.driverLatLng,
    this.driverHeading = 0.0,
    this.isRideStarted = false,
    this.onOffRoute,
    this.onMapCreated,
  });

  @override
  State<RideMapWidget> createState() => _RideMapWidgetState();
}

class _RideMapWidgetState extends State<RideMapWidget> with SingleTickerProviderStateMixin {
  final RoutingService _routingService = RoutingService();
  
  // 🗺️ Map State
  GoogleMapController? _mapController;
  List<LatLng> _routePoints = []; 
  BitmapDescriptor? _autoIcon;
  bool _isFirstRouteLoad = true;
  bool _isFetchingRoute = false; // 🆕 Prevents API spamming during re-route
  
  // 🎥 Animation Engine
  late AnimationController _animController;
  LatLng _prevDriverLoc = const LatLng(0, 0); 
  LatLng _targetDriverLoc = const LatLng(0, 0);
  double _prevHeading = 0.0;
  double _targetHeading = 0.0;
  
  // 📍 Navigation Logic (The "Brain")
  int _lastClosestIndex = 0; 
  int _offRouteCounter = 0; // 🆕 Debounce counter for off-route

  // ⚙️ Constants
  static const double kNavZoomLevel = 19.0; 
  static const double kNavTilt = 55.0; 

  @override
  void initState() {
    super.initState();
    _loadAutoIcon();

    // Initialize positions
    _prevDriverLoc = widget.driverLatLng ?? widget.initialCenter;
    _targetDriverLoc = _prevDriverLoc;
    _prevHeading = widget.driverHeading;
    _targetHeading = widget.driverHeading;

    // Setup Animation (Smooth 2s interpolation for network lag)
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000), 
    )..addListener(() {
        setState(() {}); // Rebuild marker
        _moveCameraFrame(); // Sync camera
    });
  }

  // ---------------------------------------------------------------------------
  // 🧠 STEP 1: HYBRID BEARING, SNAPPING & OFF-ROUTE LOGIC
  // ---------------------------------------------------------------------------
  void _calculateNavigationState() {
    if (_routePoints.isEmpty || widget.driverLatLng == null) {
      _targetDriverLoc = widget.driverLatLng ?? widget.initialCenter;
      _targetHeading = widget.driverHeading;
      return;
    }

    // A. Bidirectional Snap Search
    final snapResult = _calculateSnapToRoute(
      widget.driverLatLng!,
      _routePoints,
      _lastClosestIndex,
    );

    _targetDriverLoc = snapResult.snappedPoint;
    _lastClosestIndex = snapResult.index;

    // 🆕 B. OFF-ROUTE DETECTION & AUTO RE-ROUTE
    if (!snapResult.isOnRoute) {
      _offRouteCounter++;
      // Wait for 3 consecutive updates (approx 3-5 seconds) to confirm off-route
      if (_offRouteCounter > 3 && !_isFetchingRoute) {
        _offRouteCounter = 0; // Reset counter
        if (widget.onOffRoute != null) widget.onOffRoute!();
        _recalculateRoute(); // Fetch new route!
      }
    } else {
      _offRouteCounter = 0; // Reset if driver comes back to the line
    }

    // C. Calculate "Road Bearing"
    double roadBearing = widget.driverHeading;
    if (_lastClosestIndex < _routePoints.length - 1) {
      roadBearing = Geolocator.bearingBetween(
        _routePoints[_lastClosestIndex].latitude, 
        _routePoints[_lastClosestIndex].longitude,
        _routePoints[_lastClosestIndex + 1].latitude, 
        _routePoints[_lastClosestIndex + 1].longitude,
      );
    }

    // D. Hybrid Bearing Logic
    double diff = (widget.driverHeading - roadBearing).abs();
    if (diff > 180) diff = 360 - diff;

    // If aligned (< 60° diff), use Road Bearing (Smooth). Else use GPS (Reverse).
    if (diff < 60) {
      _targetHeading = roadBearing;
    } else {
      _targetHeading = widget.driverHeading;
    }
  }

  // ---------------------------------------------------------------------------
  // 🏎️ STEP 2: ANIMATION INTERPOLATION
  // ---------------------------------------------------------------------------
  LatLng get _animatedDriverPos {
    if (_routePoints.isEmpty) return _lerpPosition(_animController.value);
    
    final rawPos = _lerpPosition(_animController.value);
    return _getProjectedPointOnPolyline(rawPos, _routePoints);
  }

  LatLng _lerpPosition(double t) {
    return LatLng(
      _prevDriverLoc.latitude + (_targetDriverLoc.latitude - _prevDriverLoc.latitude) * t,
      _prevDriverLoc.longitude + (_targetDriverLoc.longitude - _prevDriverLoc.longitude) * t,
    );
  }

  double get _animatedHeading {
    double rotDiff = _targetHeading - _prevHeading;
    if (rotDiff > 180) rotDiff -= 360;
    if (rotDiff < -180) rotDiff += 360;
    return _prevHeading + (rotDiff * _animController.value);
  }

  @override
  void didUpdateWidget(covariant RideMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.pickupLatLng != oldWidget.pickupLatLng || 
        widget.dropLatLng != oldWidget.dropLatLng ||
        widget.isRideStarted != oldWidget.isRideStarted) {
       _fetchRoute();
    }

    if (widget.driverLatLng != null && widget.driverLatLng != oldWidget.driverLatLng) {
      _prevDriverLoc = _animatedDriverPos; 
      _prevHeading = _animatedHeading;
      
      _calculateNavigationState();

      _animController.forward(from: 0.0);
    }
  }

  // ---------------------------------------------------------------------------
  // 🎥 STEP 3: CAMERA CONTROL (3D Navigation Mode)
  // ---------------------------------------------------------------------------
  void _moveCameraFrame() {
    if (_mapController == null || widget.driverLatLng == null) return;
    
    if (widget.isRideStarted) {
      _mapController!.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _animatedDriverPos,
            bearing: _animatedHeading, 
            tilt: kNavTilt,            
            zoom: kNavZoomLevel,       
          ),
        ),
      );
    } else {
      _mapController!.moveCamera(
        CameraUpdate.newLatLng(_animatedDriverPos),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 🧮 STEP 4: MATH & SNAPPING UTILS
  // ---------------------------------------------------------------------------
  _SnapResult _calculateSnapToRoute(LatLng rawPos, List<LatLng> route, int startIndex) {
    double minDistance = double.infinity;
    LatLng bestSnap = rawPos;
    int bestIndex = startIndex;

    int startSearch = math.max(0, startIndex - 10);
    int endSearch = math.min(route.length - 1, startIndex + 20);

    for (int i = startSearch; i < endSearch; i++) {
      LatLng p1 = route[i];
      LatLng p2 = route[i + 1];
      LatLng projection = _projectPointOnSegment(rawPos, p1, p2);
      double dist = Geolocator.distanceBetween(
        rawPos.latitude, rawPos.longitude, 
        projection.latitude, projection.longitude
      );

      if (dist < minDistance) {
        minDistance = dist;
        bestSnap = projection;
        bestIndex = i;
      }
    }
    
    // ⚠️ OFF-ROUTE LOGIC (If > 40m off route, return isOnRoute = false)
    if (minDistance > 40) {
      return _SnapResult(rawPos, startIndex, false);
    }

    return _SnapResult(bestSnap, bestIndex, true);
  }

  LatLng _getProjectedPointOnPolyline(LatLng pos, List<LatLng> polyline) {
    if (polyline.isEmpty) return pos;
    return _calculateSnapToRoute(pos, polyline, _lastClosestIndex).snappedPoint;
  }

  LatLng _projectPointOnSegment(LatLng p, LatLng a, LatLng b) {
    double apX = p.latitude - a.latitude;
    double apY = p.longitude - a.longitude;
    double abX = b.latitude - a.latitude;
    double abY = b.longitude - a.longitude;
    double ab2 = abX * abX + abY * abY;
    double apAb = apX * abX + apY * abY;
    double t = (ab2 == 0) ? 0 : apAb / ab2;
    if (t < 0) return a; 
    if (t > 1) return b; 
    return LatLng(a.latitude + abX * t, a.longitude + abY * t);
  }

  // ---------------------------------------------------------------------------
  // 🌍 ROUTE FETCHING & AUTO RE-ROUTE
  // ---------------------------------------------------------------------------
  
  // 🆕 Safe Wrapper to prevent spamming the Google API
  Future<void> _recalculateRoute() async {
    if (_isFetchingRoute) return;
    setState(() => _isFetchingRoute = true);
    
    debugPrint("🔄 Driver off route! Recalculating...");
    await _fetchRoute();
    
    if (mounted) setState(() => _isFetchingRoute = false);
  }

  Future<void> _fetchRoute() async {
    List<LatLng> points = [];
    LatLng? start, end;

    if (widget.isRideStarted) {
      start = widget.driverLatLng ?? widget.pickupLatLng;
      end = widget.dropLatLng;
    } else {
      start = widget.driverLatLng;
      end = widget.pickupLatLng;
    }

    if (start != null && end != null) {
      points = await _routingService.getRoute(start, end);
    }

    if (mounted) {
      setState(() {
        _routePoints = points;
        _lastClosestIndex = 0; // Reset tracking for the new path
      });

      if (_isFirstRouteLoad && points.isNotEmpty) {
        _fitBoundsToRoute(points);
        _isFirstRouteLoad = false;
      }
    }
  }

  void _fitBoundsToRoute(List<LatLng> points) {
    if (_mapController == null || points.isEmpty) return;
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)),
        100.0,
      ),
    );
  }

  // ✂️ DYNAMIC POLYLINE (The "Pacman" Line)
  Set<Polyline> _buildDynamicPolyline() {
    if (_routePoints.isEmpty) return {};
    List<LatLng> displayPoints = [];
    
    if (_lastClosestIndex < _routePoints.length) {
      displayPoints = _routePoints.sublist(_lastClosestIndex);
      if (widget.driverLatLng != null) displayPoints.insert(0, _animatedDriverPos);
    }

    return {
      Polyline(
        polylineId: const PolylineId('active_route'),
        points: displayPoints,
        color: const Color(0xFF4285F4),
        width: 6,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    };
  }

  // 🎨 ASSETS
  Future<void> _loadAutoIcon() async {
    try {
      final Uint8List markerIcon = await getBytesFromAsset('assets/images/auto_icon.png', 120);
      setState(() => _autoIcon = BitmapDescriptor.fromBytes(markerIcon));
    } catch (e) {
      debugPrint("⚠️ Icon Load Error: $e");
    }
  }

  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: widget.initialCenter,
        zoom: 15,
      ),
      myLocationEnabled: true, 
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      rotateGesturesEnabled: true,
      
      padding: const EdgeInsets.only(
        bottom: 200, 
      ),

      onMapCreated: (controller) {
        _mapController = controller;
        if (widget.onMapCreated != null) widget.onMapCreated!(controller);
        _fetchRoute();
      },
      
      markers: {
        if (widget.pickupLatLng != null)
          Marker(
            markerId: const MarkerId('pickup'),
            position: widget.pickupLatLng!,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          ),
        if (widget.dropLatLng != null)
          Marker(
            markerId: const MarkerId('drop'),
            position: widget.dropLatLng!,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          ),
        // 🚗 ANIMATED CAR
        if (widget.driverLatLng != null)
          Marker(
            markerId: const MarkerId('driver'),
            position: _animatedDriverPos,
            rotation: _animatedHeading,
            icon: _autoIcon ?? BitmapDescriptor.defaultMarker,
            anchor: const Offset(0.5, 0.5),
            flat: true,
            zIndex: 100, 
          ),
      },
      polylines: _buildDynamicPolyline(),
    );
  }
}

// 🆕 Added 'isOnRoute' boolean to easily check if driver drifted
class _SnapResult {
  final LatLng snappedPoint;
  final int index;
  final bool isOnRoute;
  _SnapResult(this.snappedPoint, this.index, this.isOnRoute);
}