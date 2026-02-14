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
const String googleMapApiKey = "AIzaSyBKbBQiebZr8_wWTwfhfqzln5VHijLb7cc";

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
  intro,   // Shows Draggable Sheet + Search Bars
  booking, // Shows Static Sheet + Vehicle List (Search Bars Hidden)
  waiting, // Shows Static Sheet (Search Bars Hidden)
  showOtp, // Shows Static Sheet (Search Bars Hidden)
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
  GoogleMapController? _mapController; 
  
  LatLng? pickupLatLng;
  LatLng? dropLatLng;
  LatLng? _driverLocation;
  LatLng? _currentUserLocation;
  
  StreamSubscription<DocumentSnapshot>? _driverSubscription;
  double _driverHeading = 0.0;
  String _selectedServiceId = 'auto';
  String? _dropLocation;
  
  UserRideUIState _rideUIState = UserRideUIState.intro;

  String? _activeRideId;
  String? _rideOtp;
  StreamSubscription<DocumentSnapshot>? _rideSubscription;

  @override
  void initState() {
    super.initState();
    _fcmService.initFCM();
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

  void _stopDriverTracking() {
    _driverSubscription?.cancel();
    setState(() {
      _isRideOngoing = false;

    });
  }

  void _startTrackingDriver(String driverId) {
    _driverSubscription?.cancel();

    _driverSubscription = FirebaseFirestore.instance
        .collection('drivers')
        .doc(driverId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        final loc = data['location']; 
        
        double lat, lng;
        if (loc is GeoPoint) {
          lat = loc.latitude;
          lng = loc.longitude;
        } else {
          lat = loc['lat'];
          lng = loc['lng'];
        }

        double heading = (data['heading'] ?? 0.0).toDouble();

        setState(() {
          _driverLocation = LatLng(lat, lng);
          _driverHeading = heading;
        });

        if (_isRideOngoing && _mapController != null && _driverLocation != null) {
            _animateCameraToNavigationMode(_driverLocation!, heading);
        }
      }
    });
  }

  Future<void> _animateCameraToNavigationMode(LatLng pos, double heading) async {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: pos,       
          zoom: 17.5,        
          tilt: 50.0,        
          bearing: 0,        
        ),
      ),
    );
  }
  
  Future<void> _getPlaceDetails(String placeId, String address) async {
    final url = 'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=geometry&key=$googleMapApiKey';
    
    try {
      final response = await http.get(Uri.parse(url));
      final json = jsonDecode(response.body);

      if (json['status'] == 'OK') {
        final location = json['result']['geometry']['location'];
        final lat = location['lat'];
        final lng = location['lng'];

        setState(() {
          _dropLocation = address;
          _dropController.text = address;
          dropLatLng = LatLng(lat, lng);
          //🔥 IMPORTANT: Automatically switch UI to BOOKING mode
          // This will Hide search bars and show the Static Booking Sheet
          _rideUIState = UserRideUIState.booking; 
        });

        _calculateDistanceAndFare();
      }
    } catch (e) {
      _showSnack("Failed to fetch location details");
    }
  }

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
        }else if (service.id == 'bike') {
          double calc = 40 + (distanceKm * 20);
          service.price = calc < 80 ? 80 : calc; 
        }
      }
    });
  }

  // --- 🚀 BOOKING & UI LOGIC ---

  void _resetToIntro() {
    setState(() {
      _dropLocation = null;
      dropLatLng = null;
      _dropController.clear();
      _rideUIState = UserRideUIState.intro;
    });
  }

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
      
      if (assignedDriverId != null && _driverSubscription == null) {
          _startTrackingDriver(assignedDriverId);
      }

      if (status == 'accepted') {
        setState(() {
          _rideUIState = UserRideUIState.showOtp;
          _rideOtp = otp?.toString() ?? '----';
        });
      }
      else if (status == 'started') {
        setState(() {
          _isRideOngoing = true; 
          _rideUIState = UserRideUIState.showOtp; 
        });
      }
      else if(status == 'cancelled'){
        setState(() {
           pickupLatLng = null;
           dropLatLng = null;
           _isRideOngoing = false;
           _rideUIState = UserRideUIState.intro;
        });
      }
      else if (status == 'completed') {
        _stopDriverTracking();
        setState(() {
           pickupLatLng = null;
           dropLatLng = null;
           _isRideOngoing = false;
           _rideUIState = UserRideUIState.intro; 
        });
        showModalBottomSheet(
          context: context,
          isDismissible: false, 
          enableDrag: false,
          isScrollControlled: true, 
          builder: (context) => RideCompletionSheet(
            rideId: rideId,
            amount: (data['estimatedPrice'] ?? 0.0),
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

      setState(() {
        _showPickupInput = false;
        _activeRideId = rideId;
        _rideUIState = UserRideUIState.waiting;
      });
      _listenToRideStatus(rideId);
      _showSnack('Ride booked! ID: $rideId');
    } catch (e, stackTrace) {
      // 🔥 PRINT THE REAL ERROR TO CONSOLE
      debugPrint("❌ ERROR REASON: $e");
      debugPrint("📜 STACK TRACE: $stackTrace");

      _showSnack('Booking failed. Check console for details.');
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
    RideService(id: 'bike ', name: 'Bike', image: 'assets/images/bike.jpg', distanceKm: 0, durationMin: 0, price: 40),
  ];

  Widget _serviceCard(RideService service) {
    final bool isSelected = _selectedServiceId == service.id;
    return GestureDetector(
      onTap: () => setState(() => _selectedServiceId = service.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // Reduced Padding
        margin: const EdgeInsets.only(bottom: 8), // Small Margin
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? Colors.blue.withOpacity(0.05) : Colors.white,
          border: Border.all(color: isSelected ? Colors.blue : Colors.grey.shade200, width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            Image.asset(service.image, width: 40, height: 40), // Smaller Image
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(service.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  Text("${service.distanceKm.toStringAsFixed(1)} km • ${service.durationMin} mins", 
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            Text("₹${service.price.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  // 1. Draggable Intro Sheet
  Widget _buildIntroSheet(ScrollController controller) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: ListView(
        controller: controller,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 20),
          
          const Text("Welcome to Moksha Ride 🛺", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          const Text("Safe • Reliable • Fast", style: TextStyle(fontSize: 13, color: Colors.blue, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text("Affordable transportation for Chintamani.", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          
          const SizedBox(height: 20),
          
          const Text("Services", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _miniServiceIcon("Auto", 'assets/images/auto.png'),
              _miniServiceIcon("Cab", 'assets/images/car.png'),
              _miniServiceIcon("Bike", 'assets/images/bike.jpg'),
            ],
          ),
          const SizedBox(height: 100), // Extra space for scrolling
        ],
      ),
    );
  }

  Widget _miniServiceIcon(String name, String asset) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
          child: Image.asset(asset, width: 35, height: 35, errorBuilder: (c,o,s) => const Icon(Icons.directions_car, size: 35, color: Colors.grey)),
        ),
        const SizedBox(height: 4),
        Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  // 2. Static Booking Sheet (Compact, No Scroll)
  Widget _buildBookingSheet() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // 🔥 Compact Size
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 15),
          
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Select Ride", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text("Distance: ${(_services[0].distanceKm).toStringAsFixed(1)} km", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: _resetToIntro, 
              ),
            ],
          ),
          
          const SizedBox(height: 10),
          
          // Service List (Using Column, not ListView)
          Column(
            children: _services.map((s) => _serviceCard(s)).toList(),
          ),
          
          const SizedBox(height: 15),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _bookRide,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black, 
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16), 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ),
              child: Text("BOOK ${_selectedServiceId.toUpperCase()}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. MAP LAYER
          RideMapWidget(
            initialCenter: pickupLatLng ?? _currentUserLocation ?? const LatLng(13.4000, 78.0500),
            pickupLatLng: pickupLatLng,
            dropLatLng: dropLatLng,
            driverLatLng: _driverLocation,
            driverHeading: _driverHeading,
            isRideStarted: _isRideOngoing,
            onMapCreated: (GoogleMapController controller) {
               _mapController = controller;
            },
          ),
          
          // 2. TOP UI LAYER (Search & Profile) - ONLY visible in INTRO state
          if (_rideUIState == UserRideUIState.intro) ...[
            // Pickup Search
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16, right: 16, 
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   _searchContainer(
                     child: TextField(
                       controller: _pickupController,
                       decoration: const InputDecoration(hintText: "Pickup location", border: InputBorder.none, contentPadding: EdgeInsets.only(bottom: 5)),
                       readOnly: true, 
                       onTap: _setCurrentPickupLocation, 
                       style: const TextStyle(fontSize: 14),
                     ),
                     leadingColor: Colors.green
                   ),
                   const SizedBox(height: 10),
                   
                   // Drop Search
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
            
            // Profile Button
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: GestureDetector(
                 onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
                 child: CircleAvatar(
                   radius: 20, backgroundColor: Colors.white,
                   backgroundImage: _authService.currentUser?.photoURL != null ? NetworkImage(_authService.currentUser!.photoURL!) : null,
                   child: _authService.currentUser?.photoURL == null ? const Icon(Icons.person, size: 20, color: Colors.black87) : null,
                 ),
              ),
            ),
          ],
          
          // 3. GPS BUTTON (Adjust position based on state)
          Positioned(
            right: 16, 
            bottom: (_rideUIState == UserRideUIState.intro) ? 320 : 380, // Move up if static sheet is open
            child: FloatingActionButton(
              mini: true, backgroundColor: Colors.white, elevation: 4,
              onPressed: _setCurrentPickupLocation,
              child: const Icon(Icons.my_location, color: Colors.green),
            ),
          ),
          
          // 4. BOTTOM SHEET LAYER
          // A. INTRO: Draggable Sheet
          if (_rideUIState == UserRideUIState.intro)
            DraggableScrollableSheet(
              initialChildSize: 0.35, 
              minChildSize: 0.35, 
              maxChildSize: 0.70,
              builder: (_, controller) {
                return _buildIntroSheet(controller);
              },
            ),

          // B. BOOKING: Static Sheet (Bottom Docked)
          if (_rideUIState == UserRideUIState.booking)
             Positioned(
               bottom: 0, left: 0, right: 0,height: 400,
               child: _buildBookingSheet(),
             ),

          // C. WAITING: Static Sheet
          if (_rideUIState == UserRideUIState.waiting)
             Positioned(
               bottom: 0, left: 0, right: 0,height: 350,
               child: RideWaitingSheet(
                  onCancel: () {
                    if (_activeRideId != null) _rideRepository.cancelRide(_activeRideId!);
                    setState(() => _rideUIState = UserRideUIState.booking);
                  },
               ),
             ),

          // D. OTP: Static Sheet
          if (_rideUIState == UserRideUIState.showOtp)
             Positioned(
               bottom: 0, left: 0, right: 0,height: 365,
               child: RideOtpSheet(otp: _rideOtp ?? '----', driverName: 'Ravi', driverRating: 4.5),
             ),
        ],
      ),
    );
  }

  Widget _searchContainer({required Widget child, required Color leadingColor, IconData? trailing}) {
    return Container(
      height: 48, padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: leadingColor, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(child: child),
          if (trailing != null) Icon(trailing, color: Colors.grey, size: 20),
        ],
      ),
    );
  }
}

// 🔎 PLACE SEARCH DELEGATE
class PlaceSearchDelegate extends SearchDelegate<Suggestion?> {
  final String sessionToken;
  PlaceSearchDelegate(this.sessionToken);

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));
  }

  @override
  Widget buildResults(BuildContext context) => Container();

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
              onTap: () => close(context, suggestion),
            );
          },
        );
      },
    );
  }
  
  Future<List<Suggestion>> _fetchSuggestions(String input) async {
    final request = 'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$googleMapApiKey&sessiontoken=$sessionToken&components=country:in';
    try {
      final response = await http.get(Uri.parse(request));
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['status'] == 'OK') {
          return (result['predictions'] as List).map<Suggestion>((p) => Suggestion(p['place_id'], p['description'])).toList();
        }
      } 
    } catch (e) {
      print("❌ Network Error: $e");
    }
    return [];
  }
}

class Suggestion {
  final String placeId;
  final String description;
  Suggestion(this.placeId, this.description); 
}