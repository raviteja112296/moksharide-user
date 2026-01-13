import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:moksharide_user/features/ride/data/ride_repository.dart';
import 'package:moksharide_user/services/fcm_service.dart';
import '../../../../core/utils/app_routes.dart';
import '../../../auth/data/auth_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();
  final RideRepository _rideRepository = RideRepository();
  final FCMService _fcmService = FCMService();

  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropController = TextEditingController();

  bool _showPickupInput = false;
  String? _dropLocation;

  @override
  void initState() {
    super.initState();
    _fcmService.initFCM();
  }

  /* ---------------- LOGIC METHODS (UNCHANGED) ---------------- */
  // ALL YOUR EXISTING METHODS ARE KEPT AS-IS
  // _setCurrentPickupLocation()
  Future<void> _setCurrentPickupLocation() async {
  try {
    // Check if location services ON
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnack('Please enable GPS/location services');
      return;
    }

    // Check permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnack('Location permission required');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnack('Location permissions denied. Enable in Settings');
      return;
    }

    // Get location with TIMEOUT & lower accuracy
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,  // Changed from high
      timeLimit: Duration(seconds: 10),         // Add timeout
    ).timeout(Duration(seconds: 15));

    setState(() {
      _pickupController.text = 'Chintamani (${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)})';
      _showPickupInput = true;
    });

    _showSnack('Location set: ${position.latitude.toStringAsFixed(2)}, ${position.longitude.toStringAsFixed(2)}');
  } catch (e) {
    print('Location error: $e');  // Debug
    _showSnack('GPS signal weak. Try again or enter manually');
  }
}
  // _showDropoffLocations()
    Future<void> _showDropoffLocations(BuildContext context) async {
    final locations = [
      {'name': 'Tempo Stand, Chintamani', 'distance': '2.5 km', 'fare': '₹35'},
      {'name': 'Hospital Road', 'distance': '3.8 km', 'fare': '₹55'},
      {'name': 'College Gate', 'distance': '4.2 km', 'fare': '₹65'},
      {'name': 'Railway Station', 'distance': '1.8 km', 'fare': '₹25'},
      {'name': 'KGF Road Junction', 'distance': '12 km', 'fare': '₹180'},
    ];

    final selectedLocation = await showDialog<Map<String, String>?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Drop-off'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: locations.length,
            itemBuilder: (context, index) {
              final loc = locations[index];
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.orange,
                  child: Icon(Icons.flag, color: Colors.white, size: 18),
                ),
                title: Text(loc['name']!),
                subtitle: Text('${loc['distance']} • ${loc['fare']}'),
                onTap: () => Navigator.pop(context, loc),
              );
            },
          ),
        ),
      ),
    );

    if (selectedLocation != null) {
      setState(() {
        _dropLocation = selectedLocation['name'];
        _dropController.text = '${selectedLocation['name']} (${selectedLocation['fare']})';
      });
    }
  }
  // _bookRide()
    Future<void> _bookRide() async {
    if (_pickupController.text.isEmpty || _dropController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select pickup and drop locations'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Searching for nearby drivers...'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final rideId = await _rideRepository.bookRide(
        pickup: _pickupController.text,
        drop: _dropController.text,
        dropoff: _dropController.text,
      );
      
      _pickupController.clear();
      _dropController.clear();
      setState(() {
        _showPickupInput = false;
        _dropLocation = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ride booked successfully! ID: $rideId'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pushNamed(context, AppRoutes.rideStatus, arguments: rideId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to book ride: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  // _showSnack()
  void _showSnack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  /* ---------------- UI ---------------- */

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final userEmail = user?.email ?? 'Unknown';

    return Scaffold(
      body: Stack(
        children: [
          /// 🗺️ MAP BACKGROUND (OSM-like look)
          /// /// 🗺️ MAP BACKGROUND (OpenStreetMap)
FlutterMap(
  options: const MapOptions(
    initialCenter: LatLng(12.9716, 77.5946), // default center
    initialZoom: 14,
    interactionOptions: InteractionOptions(
      flags: InteractiveFlag.drag |
          InteractiveFlag.pinchZoom |
          InteractiveFlag.doubleTapZoom,
    ),
  ),
  children: [
    /// OSM tiles
    TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.moksharide.user',
    ),

    /// Center marker (pickup)
    MarkerLayer(
      markers: [
        Marker(
          point: LatLng(12.9716, 77.5946),
          width: 50,
          height: 50,
          child: const Icon(
            Icons.location_pin,
            size: 48,
            color: Colors.green,
          ),
        ),
      ],
    ),
  ],
),

          /// 🔍 SEARCH CARD
          /// 🔍 SEARCH + PROFILE
/// 🔍 SEARCH + PROFILE (CENTER-RIGHT)
Positioned(
  top: MediaQuery.of(context).padding.top + 16,
  left: 16,
  right: 16,
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.center, // 🔥 IMPORTANT
    children: [
      /// SEARCH FIELDS
      Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _pickupSearchBar(),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _showDropoffLocations(context),
              child: _dropSearchBar(),
            ),
          ],
        ),
      ),

      const SizedBox(width: 12),

      /// 👤 PROFILE ICON — CENTERED
      Align(
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.profile),
          child: CircleAvatar(
            radius: 25,
            backgroundColor: Colors.white,
            backgroundImage: _authService.currentUser?.photoURL != null
                ? NetworkImage(
                    _authService.currentUser!.photoURL!,
                  )
                : null,
            child: _authService.currentUser?.photoURL == null
                ? const Icon(
                    Icons.person,
                    size: 26,
                    color: Colors.black87,
                  )
                : null,
          ),
        ),
      ),
    ],
  ),
),



          /// 📍 MY LOCATION BUTTON
          Positioned(
            right: 16,
            bottom: 260,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: _setCurrentPickupLocation,
              child: const Icon(Icons.my_location, color: Colors.green),
            ),
          ),

          /// ⬆️ BOTTOM SHEET
          DraggableScrollableSheet(
            initialChildSize: 0.38,
            minChildSize: 0.25,
            maxChildSize: 0.7,
            builder: (_, controller) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: ListView(
                  controller: controller,
                  children: [
                    /// WELCOME
                    Text(
                      "Welcome back 👋",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      userEmail,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 24),

                    /// BOOK BUTTON
                    ElevatedButton(
                      onPressed: _bookRide,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        backgroundColor: Colors.green.shade600,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_car),
                          SizedBox(width: 10),
                          Text(
                            "BOOK RIDE",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    /// SERVICES
                    Row(
                      children: [
                        Expanded(
                          child: _serviceItem(
                            icon: Icons.electric_rickshaw,
                            label: "Auto",
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _serviceItem(
                            icon: Icons.local_taxi,
                            label: "Cab",
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /* ---------------- SEARCH BARS ---------------- */

  Widget _pickupSearchBar() {
    return _searchContainer(
      child: TextField(
        controller: _pickupController,
        autofocus: _showPickupInput,
        decoration: const InputDecoration(
          hintText: "Pickup location",
          border: InputBorder.none,
        ),
      ),
      leadingColor: Colors.green,
    );
  }

  Widget _dropSearchBar() {
    return _searchContainer(
      child: Text(
        _dropLocation ?? "Drop location",
        style: TextStyle(
          color: _dropLocation == null ? Colors.grey : Colors.black,
          fontSize: 15,
        ),
      ),
      leadingColor: Colors.red,
      trailing: Icons.arrow_drop_down,
    );
  }

  Widget _searchContainer({
    required Widget child,
    required Color leadingColor,
    IconData? trailing,
  }) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: leadingColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: child),
          if (trailing != null)
            Icon(trailing, color: Colors.grey),
        ],
      ),
    );
  }

  /* ---------------- SERVICES ---------------- */

  Widget _serviceItem({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _dropController.dispose();
    super.dispose();
  }
}
