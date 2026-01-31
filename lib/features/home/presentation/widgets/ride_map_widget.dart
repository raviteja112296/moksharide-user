import 'dart:math' as math;
import 'dart:ui' as ui; // 👈 Required for image resizing
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 👈 Required for loading assets
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:moksharide_user/features/home/data/routing_service.dart';
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
  
  // 🏎️ Smooth Position Getter
  LatLng get _animatedDriverLoc {
    if (_prevDriverLoc == null || _currentDriverLoc == null) {
      return widget.driverLatLng ?? widget.initialCenter;
    }
    return LatLng(
      _prevDriverLoc!.latitude + (_currentDriverLoc!.latitude - _prevDriverLoc!.latitude) * _animController.value,
      _prevDriverLoc!.longitude + (_currentDriverLoc!.longitude - _prevDriverLoc!.longitude) * _animController.value,
    );
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
    _loadAutoIcon(); // 🔥 Load the custom Auto symbol

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), 
    )..addListener(() {
      setState(() {}); // Rebuild map frame-by-frame
    });
  }

  @override
  void didUpdateWidget(covariant RideMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 1. Fetch Route Logic (UPDATED for your requirements)
    if (widget.pickupLatLng != oldWidget.pickupLatLng || 
        widget.dropLatLng != oldWidget.dropLatLng ||
        widget.driverLatLng != oldWidget.driverLatLng || // Re-fetch if driver moves significantly off-route? No, usually handled by polyline trimming.
        widget.isRideStarted != oldWidget.isRideStarted) {
      
      // If the status changed (e.g., Ride Started), force a re-fetch immediately
      if (widget.isRideStarted != oldWidget.isRideStarted) {
         _fetchRoute();
      } else if (_routePoints.isEmpty) {
         _fetchRoute();
      }
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

  // 🌍 ROUTE LOGIC
  Future<void> _fetchRoute() async {
    List<LatLng> points = [];

    // CASE 1: Ride Started -> Show Driver to Drop
    if (widget.isRideStarted) {
      if (widget.driverLatLng != null && widget.dropLatLng != null) {
        points = await _routingService.getRoute(widget.driverLatLng!, widget.dropLatLng!);
      } else if (widget.pickupLatLng != null && widget.dropLatLng != null) {
         // Fallback if driver loc is missing temporarily
         points = await _routingService.getRoute(widget.pickupLatLng!, widget.dropLatLng!);
      }
    } 
    // CASE 2: Before Ride Start -> Show Driver to Pickup
    else {
      if (widget.driverLatLng != null && widget.pickupLatLng != null) {
        points = await _routingService.getRoute(widget.driverLatLng!, widget.pickupLatLng!);
      }
    }

    if (mounted) {
      setState(() {
        _routePoints = points;
      });
    }
  }

  // 🖼️ Load and Resize Auto Icon
  Future<void> _loadAutoIcon() async {
    try {
      // 100 width is perfect for an "Icon/Symbol" look
      final Uint8List markerIcon = await getBytesFromAsset('assets/images/auto_icon.png', 100);
      
      setState(() {
        _autoIcon = BitmapDescriptor.fromBytes(markerIcon);
      });
    } catch (e) {
      print("⚠️ Auto icon error: $e");
    }
  }

  // 🛠️ Image Resizer Helper
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

  // 🔗 THE BLUE LINE LOGIC
  Set<Polyline> _buildDynamicPolyline() {
    if (_routePoints.isEmpty) return {};
    List<LatLng> displayPoints = List.from(_routePoints);

    // Trim logic: Only trim if we have a driver position
    if (widget.driverLatLng != null) {
      LatLng currentPos = _animatedDriverLoc;
      
      // Calculate closest point on the route
      int closestIndex = -1;
      double minDistance = 10000;
      int searchLimit = math.min(_routePoints.length, 20); // Optimization

      for (int i = 0; i < searchLimit; i++) {
        double d = Geolocator.distanceBetween(
          currentPos.latitude, currentPos.longitude,
          _routePoints[i].latitude, _routePoints[i].longitude
        );
        if (d < minDistance) {
          minDistance = d;
          closestIndex = i;
        }
      }

      // If close to route, trim previous points and attach to Driver
      if (closestIndex != -1 && minDistance < 100) {
        displayPoints = _routePoints.sublist(closestIndex);
        displayPoints.insert(0, currentPos); // Attach line to Auto Symbol
      }
      else if (minDistance >= 100) {
        // Driver is far away! Force a new route calculation.
        // We use Future.microtask to avoid calling setState during build
        Future.microtask(() => _fetchRoute());
      }
    }

    return {
      Polyline(
        polylineId: const PolylineId('active_route'),
        points: displayPoints,
        color: Colors.blue, // 🔵 YOU WANTED BLUE
        width: 5,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    };
  }

  Set<Marker> _buildMarkers() {
    Set<Marker> markers = {};

    // 1. Pickup Marker (Always show, or hide after ride starts depending on preference)
    // Most apps keep it to show where the ride started.
    if (widget.pickupLatLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: widget.pickupLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));
    }

    // 2. Drop Marker
    if (widget.dropLatLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('drop'),
        position: widget.dropLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
    }

    // 3. 🛺 AUTO SYMBOL (Driver)
    if (widget.driverLatLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: _animatedDriverLoc,
        rotation: _animatedHeading,
        flat: true,
        anchor: const Offset(0.5, 0.5),
        zIndex: 10,
        // Uses the resized icon
        icon: _autoIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
      ));
    }
    return markers;
  }
}