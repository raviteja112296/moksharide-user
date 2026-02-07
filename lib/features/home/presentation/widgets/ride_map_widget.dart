import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:moksharide_user/features/home/data/routing_service.dart'; // Ensure path is correct
import 'package:geolocator/geolocator.dart';

class RideMapWidget extends StatefulWidget {
  final LatLng initialCenter;
  final LatLng? pickupLatLng;
  final LatLng? dropLatLng;
  final LatLng? driverLatLng;
  final double driverHeading;
  final bool isRideStarted; // false = Driver -> Pickup, true = Driver -> Drop
  
  final void Function(GoogleMapController)? onMapCreated;

  const RideMapWidget({
    super.key,
    required this.initialCenter,
    this.pickupLatLng,
    this.dropLatLng,
    this.driverLatLng,
    this.driverHeading = 0.0,
    this.isRideStarted = false,
    this.onMapCreated,
  });

  @override
  State<RideMapWidget> createState() => _RideMapWidgetState();
}

class _RideMapWidgetState extends State<RideMapWidget> with TickerProviderStateMixin {
  final RoutingService _routingService = RoutingService();
  List<LatLng> _routePoints = []; 
  BitmapDescriptor? _autoIcon;
  GoogleMapController? _mapController;

  // 🎥 Animation Variables
  late AnimationController _animController;
  LatLng? _prevDriverLoc;
  LatLng? _currentDriverLoc;
  double _prevHeading = 0.0;
  double _currentHeading = 0.0;
  
  bool _isFirstRouteLoad = true; // Prevents auto-zoom loop
  int _progressIndex = 0; // 🆕 THE FIX: Tracks where the driver is on the route

  // 🏎️ Smooth Position Getter (With Snap-to-Road Magic)
  LatLng get _animatedDriverLoc {
    LatLng rawPos;
    if (_prevDriverLoc == null || _currentDriverLoc == null) {
      rawPos = widget.driverLatLng ?? widget.initialCenter;
    } else {
      rawPos = LatLng(
        _prevDriverLoc!.latitude + (_currentDriverLoc!.latitude - _prevDriverLoc!.latitude) * _animController.value,
        _prevDriverLoc!.longitude + (_currentDriverLoc!.longitude - _prevDriverLoc!.longitude) * _animController.value,
      );
    }

    // Snap to route if available
    if (_routePoints.isNotEmpty) {
      return _getProjectedPointOnPolyline(rawPos, _routePoints);
    }
    return rawPos;
  }

  // 🔄 Smooth Rotation Getter
  double get _animatedHeading {
    double diff = _currentHeading - _prevHeading;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return _prevHeading + (diff * _animController.value);
  }

  @override
  void initState() {
    super.initState();
    _loadAutoIcon();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), 
    )..addListener(() {
      setState(() {
        if (_mapController != null && widget.driverLatLng != null) {
          _updateCameraSmoothly(_animatedDriverLoc);
        }
      }); 
    });
  }

  @override
  void didUpdateWidget(covariant RideMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 1. Fetch Route Logic
    if (widget.pickupLatLng != oldWidget.pickupLatLng || 
        widget.dropLatLng != oldWidget.dropLatLng ||
        widget.isRideStarted != oldWidget.isRideStarted) {
      
       _fetchRoute();
    }

    // 2. Animation Trigger
    if (widget.driverLatLng != oldWidget.driverLatLng && widget.driverLatLng != null) {
      _prevDriverLoc = _animatedDriverLoc; 
      _currentDriverLoc = widget.driverLatLng;
      _prevHeading = _animatedHeading;
      _currentHeading = widget.driverHeading;
      _animController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // 📷 Camera Follow Logic (Fixes Zoom Out)
  void _updateCameraSmoothly(LatLng target) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(target), // Keeps Zoom Level!
    );
  }

  // 🧮 Snap-to-Road Math
  LatLng _getProjectedPointOnPolyline(LatLng pos, List<LatLng> polyline) {
    if (polyline.length < 2) return pos;

    double minDist = double.infinity;
    LatLng snappedPos = pos;

    // Search around our last known progress index (Sliding Window for Snapping too)
    int startSearch = math.max(0, _progressIndex - 5);
    int endSearch = math.min(polyline.length - 1, _progressIndex + 30);

    for (int i = startSearch; i < endSearch; i++) {
      LatLng p1 = polyline[i];
      LatLng p2 = polyline[i + 1];
      
      LatLng projection = _projectPointOnSegment(pos, p1, p2);
      double distance = Geolocator.distanceBetween(
        pos.latitude, pos.longitude, 
        projection.latitude, projection.longitude
      );

      if (distance < minDist) {
        minDist = distance;
        snappedPos = projection;
      }
    }

    if (minDist > 40) return pos; // Too far? Show real location
    return snappedPos;
  }

  LatLng _projectPointOnSegment(LatLng p, LatLng a, LatLng b) {
    double apX = p.latitude - a.latitude;
    double apY = p.longitude - a.longitude;
    double abX = b.latitude - a.latitude;
    double abY = b.longitude - a.longitude;

    double ab2 = abX * abX + abY * abY;
    double apAb = apX * abX + apY * abY;
    double t = apAb / ab2;

    if (t < 0) return a; 
    if (t > 1) return b; 
    return LatLng(a.latitude + abX * t, a.longitude + abY * t);
  }

  // 🌍 ROUTE LOGIC
  Future<void> _fetchRoute() async {
    List<LatLng> points = [];

    if (widget.isRideStarted) {
      if (widget.driverLatLng != null && widget.dropLatLng != null) {
        points = await _routingService.getRoute(widget.driverLatLng!, widget.dropLatLng!);
      } else if (widget.pickupLatLng != null && widget.dropLatLng != null) {
         points = await _routingService.getRoute(widget.pickupLatLng!, widget.dropLatLng!);
      }
    } else {
      if (widget.driverLatLng != null && widget.pickupLatLng != null) {
        points = await _routingService.getRoute(widget.driverLatLng!, widget.pickupLatLng!);
      }
    }

    if (mounted) {
      setState(() {
        _routePoints = points;
        _progressIndex = 0; // 🆕 Reset progress on new route
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
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80.0, 
      ),
    );
  }

  Future<void> _loadAutoIcon() async {
    try {
      final Uint8List markerIcon = await getBytesFromAsset('assets/images/auto_icon.png', 100);
      setState(() {
        _autoIcon = BitmapDescriptor.fromBytes(markerIcon);
      });
    } catch (e) {
      print("⚠️ Auto icon error: $e");
    }
  }

  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
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
      onMapCreated: (controller) {
        _mapController = controller;
        if (widget.onMapCreated != null) widget.onMapCreated!(controller);
        _fetchRoute();
      },
      markers: _buildMarkers(),
      polylines: _buildDynamicPolyline(),
    );
  }

  // 🔗 THE BLUE LINE LOGIC (FIXED with Sliding Window)
  Set<Polyline> _buildDynamicPolyline() {
    if (_routePoints.isEmpty) return {};
    List<LatLng> displayPoints = List.from(_routePoints);

    if (widget.driverLatLng != null) {
      LatLng currentPos = _animatedDriverLoc;
      
      int closestIndex = -1;
      double minDistance = 10000;

      // 🆕 NEW LOGIC: Search 30 points ahead of our last known spot
      int startSearch = _progressIndex;
      int endSearch = math.min(_routePoints.length, _progressIndex + 30);

      for (int i = startSearch; i < endSearch; i++) {
        double d = Geolocator.distanceBetween(
          currentPos.latitude, currentPos.longitude,
          _routePoints[i].latitude, _routePoints[i].longitude
        );
        if (d < minDistance) {
          minDistance = d;
          closestIndex = i;
        }
      }

      // If we found a match, update progress and trim line
      if (closestIndex != -1 && minDistance < 100) {
        _progressIndex = closestIndex; // Update tracker
        
        if (closestIndex + 1 < _routePoints.length) {
          displayPoints = _routePoints.sublist(closestIndex + 1);
          displayPoints.insert(0, currentPos); 
        } else {
          displayPoints = []; // End of route
        }
      }
      else if (minDistance >= 100) {
        // Drifting? Re-fetch route
        if (_routePoints.length > 5) {
             Future.microtask(() => _fetchRoute());
        }
      }
      // If no new point found, stay at last known progress
      else if (_progressIndex > 0 && _progressIndex < _routePoints.length) {
         displayPoints = _routePoints.sublist(_progressIndex);
         displayPoints.insert(0, currentPos);
      }
    }

    return {
      Polyline(
        polylineId: const PolylineId('active_route'),
        points: displayPoints,
        color: Colors.blue, 
        width: 5,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    };
  }

  Set<Marker> _buildMarkers() {
    Set<Marker> markers = {};

    if (widget.pickupLatLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: widget.pickupLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));
    }

    if (widget.dropLatLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('drop'),
        position: widget.dropLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
    }

    if (widget.driverLatLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: _animatedDriverLoc, // Snapped Position
        rotation: _animatedHeading,
        flat: true,
        anchor: const Offset(0.5, 0.5),
        zIndex: 10,
        icon: _autoIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
      ));
    }
    return markers;
  }
}