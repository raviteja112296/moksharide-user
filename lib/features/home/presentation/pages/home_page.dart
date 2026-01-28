import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart'; 
import 'package:geocoding/geocoding.dart';

// INTERNAL IMPORTS (Ensure these exist in your project)
import 'package:moksharide_user/features/home/presentation/widgets/ride_map_widget.dart';
import 'package:moksharide_user/features/home/presentation/widgets/ride_otp_sheet.dart';
import 'package:moksharide_user/features/home/presentation/widgets/ride_waiting_sheet.dart';
import 'package:moksharide_user/features/ride/data/ride_repository.dart';
import 'package:moksharide_user/services/fcm_service.dart';
import '../../../../core/utils/app_routes.dart';
import '../../../auth/data/auth_service.dart';
import '../widgets/ride_completion_sheet.dart';

// 🔑 REPLACE WITH YOUR REAL GOOGLE MAPS API KEY
const String googleMapApiKey = "AIzaSyCfAr6OUiTokdQnsJZS7nCoTRxhvWOVuV8";

class RideService {
  final String id;
  final String name;
  final String image;
  double distanceKm;
  int durationMin;
  double price;

  RideService({
    required this.id,
    required this.name,
    required this.image,
    required this.distanceKm,
    required this.durationMin,
    required this.price,
  });
}

enum UserRideUIState {
  idle,
  waiting,
  showOtp,
}

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
  
  // 🔥 Live Tracking Variables
  bool _isRideOngoing = false;
  GoogleMapController? _mapController; // Required for Camera Animation
  
  LatLng? pickupLatLng;
  LatLng? dropLatLng;
  LatLng? _driverLocation;
  LatLng? _currentUserLocation;
  
  StreamSubscription<DocumentSnapshot>? _driverSubscription;
  double _driverHeading = 0.0;
  String _selectedServiceId = 'auto';
  String? _dropLocation;
  UserRideUIState _rideUIState = UserRideUIState.idle;

  String? _activeRideId;
  String? _rideOtp;
  StreamSubscription<DocumentSnapshot>? _rideSubscription;

  @override
  void initState() {
    super.initState();
    _fcmService.initFCM();
    // ✅ Automatically get current location when app opens
    _setCurrentPickupLocation();
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _dropController.dispose();
    _driverSubscription?.cancel();
    _rideSubscription?.cancel();
    super.dispose();
  }

  // --- 📍 LOCATION & FARE LOGIC ---

  // 1. Get Current Location
  Future<void> _setCurrentPickupLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return; 

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (!mounted) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      
      Placemark place = placemarks[0];
      String address = "${place.name ?? ''}, ${place.subLocality ?? ''}, ${place.locality ?? ''}".trim();
      if (address.startsWith(',')) address = address.substring(1).trim();

      setState(() {
        _currentUserLocation = LatLng(position.latitude, position.longitude);
        pickupLatLng = _currentUserLocation;
        _pickupController.text = address.isNotEmpty ? address : "Current Location";
        _showPickupInput = true;
      });

      if (dropLatLng != null) {
        _calculateDistanceAndFare();
      }

    } catch (e) {
      debugPrint('Location error: $e');
    }
  }

  // 2. Open Dynamic Search for Drop Location
  Future<void> _openDropoffSearch() async {
    final sessionToken = const Uuid().v4();
    
    final Suggestion? result = await showSearch<Suggestion?>(
      context: context,
      delegate: PlaceSearchDelegate(sessionToken),
    );

    if (result != null) {
      _getPlaceDetails(result.placeId, result.description);
    }
  }

  // 🛑 STOP TRACKING HELPER
  void _stopDriverTracking() {
    _driverSubscription?.cancel();
    setState(() {
      _isRideOngoing = false;
      // We keep _driverLocation to show where they dropped us, 
      // or set it to null if you want the car to disappear:
      // _driverLocation = null; 
    });
  }

  // 📡 START TRACKING (Includes Camera Animation)
  void _startTrackingDriver(String driverId) {
    _driverSubscription?.cancel();

    _driverSubscription = FirebaseFirestore.instance
        .collection('drivers')
        .doc(driverId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        final loc = data['location']; // Ensure Firestore has 'location' map or GeoPoint
        
        // Handle GeoPoint or Map structure
        double lat, lng;
        if (loc is GeoPoint) {
          lat = loc.latitude;
          lng = loc.longitude;
        } else {
          lat = loc['lat'];
          lng = loc['lng'];
        }

        double heading = (data['heading'] ?? 0.0).toDouble();

        // 1. Update Marker Data
        setState(() {
          _driverLocation = LatLng(lat, lng);
          _driverHeading = heading;
        });

        // 2. 🔥 LIVE CAMERA FOLLOW (The "Uber" Effect)
        if (_isRideOngoing && _mapController != null && _driverLocation != null) {
            _animateCameraToNavigationMode(_driverLocation!, heading);
        }
      }
    });
  }

  Future<void> _animateCameraToNavigationMode(LatLng pos, double heading) async {
    // This creates the smooth "flying" effect
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: pos,       // Center on the Car
          zoom: 17.5,        // Close zoom (Street level)
          tilt: 50.0,        // 3D Tilt (Key for "Uber" look)
          bearing: 0,        // Keep North up for passenger (More stable)
        ),
      ),
    );
  }
  
  
  // // 🚧 MOCK DETAILS: Generates a fake GPS coordinate for the drop
  Future<void> _getPlaceDetails(String placeId, String address) async {
    // Fake coordinates near Chintamani
    double fakeLat = 13.4000 + (double.parse(placeId) * 0.001); 
    double fakeLng = 78.0500 + (double.parse(placeId) * 0.001);

    setState(() {
      _dropLocation = address;
      _dropController.text = address;
      dropLatLng = LatLng(fakeLat, fakeLng);
    });

    _calculateDistanceAndFare(); 
  }

  // 4. Calculate Dynamic Fare
  void _calculateDistanceAndFare() {
    if (pickupLatLng == null || dropLatLng == null) return;

    double distanceInMeters = Geolocator.distanceBetween(
      pickupLatLng!.latitude,
      pickupLatLng!.longitude,
      dropLatLng!.latitude,
      dropLatLng!.longitude,
    );

    double distanceKm = (distanceInMeters / 1000) * 1.3;
    int durationMin = (distanceKm / 30 * 60).round(); 

    setState(() {
      for (var service in _services) {
        service.distanceKm = distanceKm;
        service.durationMin = durationMin;
        
        if (service.id == 'auto') {
          double calc = 30 + (distanceKm * 15);
          service.price = calc < 40 ? 40 : calc; 
        } else if (service.id == 'cab') {
          double calc = 50 + (distanceKm * 22);
          service.price = calc < 80 ? 80 : calc; 
        }
      }
    });
  }

  // --- 🚀 BOOKING & UI LOGIC ---

  void _listenToRideStatus(String rideId) {
    _rideSubscription?.cancel();
    _rideSubscription = FirebaseFirestore.instance
        .collection('ride_requests')
        .doc(rideId)
        .snapshots()
        .listen((doc) {
      if (!doc.exists || !mounted) return;

      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'];
      final otp = data['rideOtp'];
      
      final assignedDriverId = data['assignedDriverId'];
      
      // ✅ Start tracking driver when assigned
      if (assignedDriverId != null && _driverSubscription == null) {
          _startTrackingDriver(assignedDriverId);
      }

      if (status == 'accepted') {
        setState(() {
          _rideUIState = UserRideUIState.showOtp;
          _rideOtp = otp?.toString() ?? '----';
        });
      }
      
      // 🔥 RIDE STARTED (Enable Camera Follow)
      else if (status == 'started') {
        setState(() {
          _isRideOngoing = true; // This triggers the 3D camera effect in _startTrackingDriver
          // _rideUIState = UserRideUIState.idle; // Hide OTP sheet
          _rideUIState = UserRideUIState.showOtp; 
        });
      }

      // 🔥 RIDE COMPLETED
      else if (status == 'completed') {
        _stopDriverTracking();
        setState(() {
          pickupLatLng = null;
           dropLatLng = null;
           _isRideOngoing = false;
           _rideUIState = UserRideUIState.idle;
        });
        showModalBottomSheet(
          context: context,
          isDismissible: false, 
          enableDrag: false,
          isScrollControlled: true, 
          builder: (context) => RideCompletionSheet(
            rideId: rideId,
            amount: (data['price'] ?? 0.0).toDouble(),
          ),
        );
      }
    });
  }

  Future<void> _bookRide() async {
    if (pickupLatLng == null || dropLatLng == null) {
      _showSnack("Please select pickup and drop locations");
      return;
    }

    _showSnack('Searching for nearby drivers...');

    try {
      final rideId = await _rideRepository.bookRide(
        pickup: _pickupController.text,
        pickupLat: pickupLatLng!.latitude,
        pickupLng: pickupLatLng!.longitude,
        drop: _dropController.text,
        dropLat: dropLatLng!.latitude,
        dropLng: dropLatLng!.longitude,
        serviceType: _selectedServiceId,
        estimatedPrice: _services.firstWhere((s) => s.id == _selectedServiceId).price,
      );

      // _pickupController.clear();
      // _dropController.clear();
      setState(() {
        _showPickupInput = false;
        // _dropLocation = null;
        // pickupLatLng = null;
        // dropLatLng = null;
        _activeRideId = rideId;
        _rideUIState = UserRideUIState.waiting;
      });
      _listenToRideStatus(rideId);
      _showSnack('Ride booked! ID: $rideId');
    } catch (e) {
      _showSnack('Booking failed: $e');
    }
  }

  void _showSnack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
    }
  }

  // --- WIDGETS ---

  final List<RideService> _services = [
    RideService(id: 'auto', name: 'Auto', image: 'assets/images/auto.png', distanceKm: 0, durationMin: 0, price: 0),
    RideService(id: 'cab', name: 'Cab', image: 'assets/images/car.png', distanceKm: 0, durationMin: 0, price: 0),
  ];

  Widget _serviceCard(RideService service) {
    final bool isSelected = _selectedServiceId == service.id;
    return GestureDetector(
      onTap: () => setState(() => _selectedServiceId = service.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? Colors.blue : Colors.grey.shade300, width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            Image.asset(service.image, width: 48, height: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(service.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text("${service.distanceKm.toStringAsFixed(1)} km • ${service.durationMin} mins", style: const TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            ),
            Text("₹${service.price.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          RideMapWidget(
            initialCenter: pickupLatLng ?? _currentUserLocation ?? const LatLng(13.4000, 78.0500),
            pickupLatLng: pickupLatLng,
            dropLatLng: dropLatLng,
            driverLatLng: _driverLocation,
            driverHeading: _driverHeading,
            isRideStarted: _isRideOngoing,
            // 🔥 IMPORTANT: Capture Controller for Animations
            onMapCreated: (GoogleMapController controller) {
               _mapController = controller;
            },
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16, right: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Pickup Search Bar
                      _searchContainer(
                          child: TextField(
                            controller: _pickupController,
                            decoration: const InputDecoration(hintText: "Pickup location", border: InputBorder.none),
                            readOnly: true, 
                            onTap: _setCurrentPickupLocation, 
                          ),
                          leadingColor: Colors.green
                      ),
                      const SizedBox(height: 10),
                      // Drop Search Bar
                      GestureDetector(
                        onTap: _openDropoffSearch,
                        child: _searchContainer(
                          child: Text(_dropLocation ?? "Where to?", style: TextStyle(color: _dropLocation == null ? Colors.grey : Colors.black, fontSize: 16)),
                          leadingColor: Colors.red,
                          trailing: Icons.search,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
                  child: CircleAvatar(
                    radius: 25, backgroundColor: Colors.white,
                    backgroundImage: _authService.currentUser?.photoURL != null ? NetworkImage(_authService.currentUser!.photoURL!) : null,
                    child: _authService.currentUser?.photoURL == null ? const Icon(Icons.person, size: 26, color: Colors.black87) : null,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 16, bottom: 260,
            child: FloatingActionButton(
              mini: true, backgroundColor: Colors.white, elevation: 4,
              onPressed: _setCurrentPickupLocation,
              child: const Icon(Icons.my_location, color: Colors.green),
            ),
          ),
          // Draggable Sheet Logic
          DraggableScrollableSheet(
            initialChildSize: 0.38, minChildSize: 0.20, maxChildSize: 0.55,
            builder: (_, controller) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -2))],
                ),
                child: Builder(
                  builder: (_) {
                    if (_rideUIState == UserRideUIState.waiting) return const RideWaitingSheet();
                    if (_rideUIState == UserRideUIState.showOtp) return RideOtpSheet(otp: _rideOtp ?? '----', driverName: 'Ravi', driverRating: 4.5);
                    
                    // Idle State (Booking)
                    return ListView(
                      controller: controller, padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        const SizedBox(height: 10),
                        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                        const SizedBox(height: 16),
                        const Text("Available Services", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 16),
                        Column(children: _services.map((s) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _serviceCard(s))).toList()),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _bookRide,
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                            child: Text("BOOK ${_selectedServiceId.toUpperCase()}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _searchContainer({required Widget child, required Color leadingColor, IconData? trailing}) {
    return Container(
      height: 56, padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 14, offset: const Offset(0, 6))]),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: leadingColor, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(child: child),
          if (trailing != null) Icon(trailing, color: Colors.grey),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------
// 🔎 PLACE SEARCH DELEGATE (Mock Version)
// -----------------------------------------------------------

class PlaceSearchDelegate extends SearchDelegate<Suggestion?> {
  final String sessionToken;
  
  PlaceSearchDelegate(this.sessionToken);

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back), 
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return Container();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) return Container();

    return FutureBuilder(
      future: _fetchSuggestions(query),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final suggestions = snapshot.data as List<Suggestion>;
        return ListView.builder(
          itemCount: suggestions.length,
          itemBuilder: (context, index) {
            final suggestion = suggestions[index];
            return ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text(suggestion.description),
              onTap: () {
                close(context, suggestion); 
              },
            );
          },
        );
      },
    );
  }
  
  Future<List<Suggestion>> _fetchSuggestions(String input) async {
    await Future.delayed(const Duration(milliseconds: 300));

    return [
      Suggestion("1", "Chintamani Bus Stand"),
      Suggestion("2", "Chelur Road Junction"),
      Suggestion("3", "Moksha Office"),
      Suggestion("4", "Railway Station"),
      Suggestion("5", "Kolar Circle"),
    ].where((s) => s.description.toLowerCase().contains(input.toLowerCase())).toList();
  }
}

class Suggestion {
  final String placeId;
  final String description;
  Suggestion(this.placeId, this.description);
}