import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class RideMapWidget extends StatefulWidget {
  final LatLng initialCenter;
  final LatLng? pickupLatLng;
  final LatLng? dropLatLng;
  final LatLng? driverLatLng;
  final double driverHeading;

  const RideMapWidget({
    super.key,
    required this.initialCenter,
    this.pickupLatLng,
    this.dropLatLng,
    this.driverLatLng,
    this.driverHeading = 0.0,
  });

  @override
  State<RideMapWidget> createState() => _RideMapWidgetState();
}

class _RideMapWidgetState extends State<RideMapWidget> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void didUpdateWidget(covariant RideMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 1. Move camera to driver if they move
    if (widget.driverLatLng != null && widget.driverLatLng != oldWidget.driverLatLng) {
      _mapController.move(widget.driverLatLng!, _mapController.camera.zoom);
    } 
    // 2. Move camera to pickup when first set
    else if (widget.pickupLatLng != null && widget.pickupLatLng != oldWidget.pickupLatLng) {
      _mapController.move(widget.pickupLatLng!, 15.0);
    }
    // 3. Move camera to drop location when selected
    else if (widget.dropLatLng != null && widget.dropLatLng != oldWidget.dropLatLng) {
       _mapController.move(widget.dropLatLng!, 15.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: widget.initialCenter,
        initialZoom: 14,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        /// 🌍 Map Background Tiles
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.moksharide.user',
        ),

        /// 📍 Markers Layer
        MarkerLayer(
          markers: [
            /// PICKUP MARKER
            if (widget.pickupLatLng != null)
              Marker(
                point: widget.pickupLatLng!,
                width: 80,
                height: 80,
                alignment: Alignment.topCenter, // Ensures the pin tip touches the spot
                child: const Icon(
                  Icons.location_on,
                  color: Colors.green,
                  size: 45,
                ),
              ),

            /// DROP MARKER
            if (widget.dropLatLng != null)
              Marker(
                point: widget.dropLatLng!,
                width: 80,
                height: 80,
                alignment: Alignment.topCenter,
                child: const Icon(
                  Icons.flag_rounded,
                  color: Colors.red,
                  size: 45,
                ),
              ),

            /// DRIVER LIVE LOCATION MARKER
            if (widget.driverLatLng != null)
              Marker(
                point: widget.driverLatLng!,
                width: 60,
                height: 60,
                child: Transform.rotate(
                  angle: widget.driverHeading * (math.pi / 180),
                  child: const Icon(
                    Icons.navigation_rounded, // Better "car/pointer" icon
                    color: Colors.blue,
                    size: 40,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}