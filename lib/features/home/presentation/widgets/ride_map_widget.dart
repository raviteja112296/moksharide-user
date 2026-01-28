import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:moksharide_user/features/home/data/routing_service.dart'; // Import the service
import 'package:geolocator/geolocator.dart'; // Add this for distance calculations
class RideMapWidget extends StatefulWidget {
  final LatLng initialCenter;
  final LatLng? pickupLatLng;
  final LatLng? dropLatLng;
  final LatLng? driverLatLng;
  final double driverHeading;
  final bool isRideStarted; // true = Driver -> Drop, false = Pickup -> Drop
  
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

  // 🎥 Animation Variables
  late AnimationController _animController;
  LatLng? _prevDriverLoc;
  LatLng? _currentDriverLoc;
  double _prevHeading = 0.0;
  double _currentHeading = 0.0;
  
  // Gets the animated value (Smooth Position)
  LatLng get _animatedDriverLoc {
    if (_prevDriverLoc == null || _currentDriverLoc == null) {
      return widget.driverLatLng!;
    }
    // Linear Interpolation (Lerp)
    return LatLng(
      _prevDriverLoc!.latitude + (_currentDriverLoc!.latitude - _prevDriverLoc!.latitude) * _animController.value,
      _prevDriverLoc!.longitude + (_currentDriverLoc!.longitude - _prevDriverLoc!.longitude) * _animController.value,
    );
  }

  // Gets the animated Rotation (Smooth Turn)
  double get _animatedHeading {
     return _prevHeading + (_currentHeading - _prevHeading) * _animController.value;
  }

  @override
  void initState() {
    super.initState();
    _loadMarkerIcon();

    // Initialize Animation (2 seconds duration matches location update speed)
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), 
    )..addListener(() {
      setState(() {}); // Rebuild map on every frame of animation
    });
  }
 @override
  void didUpdateWidget(covariant RideMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 1. Fetch Route Logic (Keep your existing logic here)
    if (widget.pickupLatLng != oldWidget.pickupLatLng || 
        widget.dropLatLng != oldWidget.dropLatLng ||
        widget.isRideStarted != oldWidget.isRideStarted) {
      _fetchRoute();
    }

    // 2. 🔥 TRIGGER SMOOTH ANIMATION
    if (widget.driverLatLng != oldWidget.driverLatLng && widget.driverLatLng != null) {
      _prevDriverLoc = _currentDriverLoc ?? widget.driverLatLng;
      _currentDriverLoc = widget.driverLatLng;
      
      _prevHeading = _currentHeading;
      _currentHeading = widget.driverHeading;

      _animController.forward(from: 0.0); // Restart animation from 0 to 1
      
      // Also trim the route
      _updatePolylineProgress();
    }
  }
  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }
  // 🌍 1. Fetch Full Route from Server (Only done once or on big changes)
  Future<void> _fetchRoute() async {
    List<LatLng> points = [];

    if (widget.isRideStarted && widget.driverLatLng != null && widget.dropLatLng != null) {
      points = await _routingService.getRoute(widget.driverLatLng!, widget.dropLatLng!);
    } 
    else if (!widget.isRideStarted && widget.driverLatLng != null && widget.pickupLatLng != null) {
      points = await _routingService.getRoute(widget.driverLatLng!, widget.pickupLatLng!);
    }
    // Fallback: Pickup -> Drop (Booking screen)
    else if (widget.pickupLatLng != null && widget.dropLatLng != null) {
      points = await _routingService.getRoute(widget.pickupLatLng!, widget.dropLatLng!);
    }

    if (mounted) {
      setState(() {
        _routePoints = points;
      });
    }
  }

  // ✂️ 2. Smart Trim: Cut the line as driver moves (Instant update)
  void _updatePolylineProgress() {
    if (_routePoints.isEmpty || widget.driverLatLng == null) return;

    // Find the point on the route closest to the driver
    int closestIndex = -1;
    double minDistance = 100000; // Start with a huge number

    for (int i = 0; i < _routePoints.length; i++) {
      double d = Geolocator.distanceBetween(
        widget.driverLatLng!.latitude, widget.driverLatLng!.longitude,
        _routePoints[i].latitude, _routePoints[i].longitude
      );
      if (d < minDistance) {
        minDistance = d;
        closestIndex = i;
      }
    }

    // If driver is near the route (within 50m), trim the past points
    if (minDistance < 50 && closestIndex != -1) {
      List<LatLng> newPoints = _routePoints.sublist(closestIndex);
      // Add driver's EXACT current position as the start of the line
      newPoints.insert(0, widget.driverLatLng!);
      
      setState(() {
        _routePoints = newPoints;
      });
    } else {
      // Driver went off-road or too far? Re-fetch the whole route.
      _fetchRoute();
    }
  }
  Future<void> _loadMarkerIcon() async {
    final icon = await getMarkerFromIcon(Icons.local_taxi, Colors.blue, 100);

    setState(() {
      _autoIcon = icon;
    });
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
        if (widget.onMapCreated != null) {
          widget.onMapCreated!(controller);
        }
        _fetchRoute();
      },

      markers: _buildMarkers(),
      polylines: _buildPolylines(),
    );
  }

  Set<Polyline> _buildPolylines() {
    if (_routePoints.isEmpty) return {};

    return {
      Polyline(
        polylineId: const PolylineId('active_route'),
        points: _routePoints,
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

    // 🚗 ANIMATED DRIVER MARKER
    if (widget.driverLatLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('driver'),
        
        // 🔥 Use the Animated Getter, NOT the raw widget data
        position: _animatedDriverLoc, 
        rotation: _animatedHeading,
        
        flat: true,
        anchor: const Offset(0.5, 0.5),
        zIndex: 10,
        icon: _autoIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ));
    }
    return markers;
  }
  Future<BitmapDescriptor> getMarkerFromIcon(IconData iconData, Color color, double size) async {
  final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(pictureRecorder);
  
  final Paint paint = Paint()..color = color;
  final double iconSize = size; // Size of the icon

  // Draw the Icon
  final TextPainter textPainter = TextPainter(
    textDirection: TextDirection.ltr,
  );
  
  textPainter.text = TextSpan(
    text: String.fromCharCode(iconData.codePoint),
    style: TextStyle(
      fontSize: iconSize,
      fontFamily: iconData.fontFamily,
      color: color,
    ),
  );
  
  textPainter.layout();
  textPainter.paint(canvas, const Offset(0, 0));
  
  final ui.Image image = await pictureRecorder.endRecording().toImage(iconSize.toInt(), iconSize.toInt());
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
  
  return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
}
}