import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:moksharide_user/features/home/presentation/widgets/ride_map_widget.dart';
import 'package:moksharide_user/features/home/presentation/widgets/ride_otp_sheet.dart';
import 'package:moksharide_user/features/home/presentation/widgets/ride_waiting_sheet.dart';
import 'package:moksharide_user/features/ride/data/ride_repository.dart';
import 'package:moksharide_user/services/fcm_service.dart';
import '../../../../core/utils/app_routes.dart';
import '../../../auth/data/auth_service.dart';
import 'package:geocoding/geocoding.dart';

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
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _dropController.dispose();
    _driverSubscription?.cancel();
    _rideSubscription?.cancel();
    super.dispose();
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

    if (status == 'accepted') {
      setState(() {
        _rideUIState = UserRideUIState.showOtp;
        _rideOtp = otp?.toString() ?? '----';
      });
    }
  });
}


  void stopDriverTracking() {
    _driverSubscription?.cancel();
    _driverSubscription = null;
    if (!mounted) return;
    setState(() {
      _driverLocation = null;
      _driverHeading = 0.0;
    });
  }

  Future<LatLng?> _getLatLngFromAddress(String address) async {
    try {
      final locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        return LatLng(locations.first.latitude, locations.first.longitude);
      }
    } catch (e) {
      debugPrint("❌ Geocoding failed: $e");
    }
    return null;
  }

  final List<RideService> _services = [
    RideService(
      id: 'auto',
      name: 'Auto',
      image: 'assets/images/auto.png',
      distanceKm: 2.5,
      durationMin: 15,
      price: 40,
    ),
    RideService(
      id: 'cab',
      name: 'Cab',
      image: 'assets/images/car.png',
      distanceKm: 0,
      durationMin: 0,
      price: 0,
    ),
  ];

  void updateRideEstimates(double distanceKm, int durationMin) {
    setState(() {
      for (var service in _services) {
        service.distanceKm = distanceKm;
        service.durationMin = durationMin;
        if (service.id == 'auto') {
          service.price = 30 + (distanceKm * 12);
        } else if (service.id == 'cab') {
          service.price = 50 + (distanceKm * 20);
        }
      }
    });
  }

Future<void> _setCurrentPickupLocation() async {
  try {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnack('Please enable GPS/location services');
      return;
    }

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

    // ✅ SHOW LOADING
    _showSnack('Getting your location...');

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
      timeLimit: const Duration(seconds: 10), // Add timeout
    );

    // ✅ REVERSE GEOCODE to get address
    List<Placemark> placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );
    
    Placemark place = placemarks[0];
    String address = "${place.name ?? ''}, ${place.street ?? ''}, ${place.locality ?? ''}, ${place.administrativeArea ?? ''}".trim();

    setState(() {
      _currentUserLocation = LatLng(position.latitude, position.longitude);
      pickupLatLng = _currentUserLocation;
      _pickupController.text = address.isNotEmpty ? address : "Current Location";
      _showPickupInput = true;
    });

    _showSnack('Location set successfully!');
  } catch (e) {
    debugPrint('Location error: $e');
    _showSnack('Failed to get location. Try again.');
  }
}


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
      final latLng = await _getLatLngFromAddress(selectedLocation['name']!);
      setState(() {
        _dropLocation = selectedLocation['name'];
        _dropController.text = selectedLocation['name']!;
        dropLatLng = latLng;
      });
    }
  }

Future<void> _bookRide() async {
  if (_pickupController.text.isEmpty || _dropController.text.isEmpty) {
    _showSnack('Please select pickup and drop locations');
    return;
  }
  if (pickupLatLng == null || dropLatLng == null) {
    _showSnack("Please set valid pickup & drop locations on map");
    return;
  }

  _showSnack('Searching for nearby drivers...');

  try {
    final rideId = await _rideRepository.bookRide(
  pickup: _pickupController.text,
  pickupLat: pickupLatLng!.latitude,    // ✅ Passes lat
  pickupLng: pickupLatLng!.longitude,  // ✅ Passes lng
  drop: _dropController.text,
  dropLat: dropLatLng!.latitude,       // ✅ Passes lat
  dropLng: dropLatLng!.longitude,     // ✅ Passes lng
  serviceType: _selectedServiceId,
  estimatedPrice: _services.firstWhere((s) => s.id == _selectedServiceId).price,
);


    // Clear form
    _pickupController.clear();
    _dropController.clear();
    setState(() {
      _showPickupInput = false;
      _dropLocation = null;
      pickupLatLng = null;
      dropLatLng = null;
      _activeRideId = rideId;
  _rideUIState = UserRideUIState.waiting;
    });
    _listenToRideStatus(rideId);

    _showSnack('Ride booked! ID: $rideId');
    // Navigator.pushNamed(context, AppRoutes.rideStatus, arguments: rideId);
  } catch (e) {
    _showSnack('Booking failed: $e');
  }
}


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

  void listenToDriver(String driverId) {
    _driverSubscription?.cancel();
    _driverSubscription = null;

    _driverSubscription = FirebaseFirestore.instance
        .collection('drivers')
        .doc(driverId)
        .snapshots()
        .listen(
      (DocumentSnapshot doc) {
        if (!doc.exists || !mounted) return;

        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) return;

        final location = data['location'];
        if (location == null || location['lat'] == null || location['lng'] == null) {
          return;
        }

        final double lat = (location['lat'] as num).toDouble();
        final double lng = (location['lng'] as num).toDouble();
        final double heading = data['heading'] != null ? (data['heading'] as num).toDouble() : 0.0;

        setState(() {
          _driverLocation = LatLng(lat, lng);
          _driverHeading = heading;
        });
      },
      onError: (error) {
        debugPrint('❌ Driver tracking error: $error');
      },
    );
  }

  Widget _serviceCard(RideService service) {
    final bool isSelected = _selectedServiceId == service.id;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedServiceId = service.id;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? Colors.blue : Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Image.asset(service.image, width: 48, height: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    "${service.distanceKm.toStringAsFixed(1)} km • ${service.durationMin} mins",
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Text(
              "₹${service.price.toStringAsFixed(0)}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
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
            initialCenter: pickupLatLng ??
                _currentUserLocation ??
                const LatLng(13.9716, 77.5946),
            pickupLatLng: pickupLatLng,
            dropLatLng: dropLatLng,
            driverLatLng: _driverLocation,
            driverHeading: _driverHeading,
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
                  child: CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.white,
                    backgroundImage: _authService.currentUser?.photoURL != null
                        ? NetworkImage(_authService.currentUser!.photoURL!)
                        : null,
                    child: _authService.currentUser?.photoURL == null
                        ? const Icon(Icons.person, size: 26, color: Colors.black87)
                        : null,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 16,
            bottom: 260,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              elevation: 4,
              onPressed: _setCurrentPickupLocation,
              child: const Icon(Icons.my_location, color: Colors.green),
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.38,
minChildSize: 0.20,
maxChildSize: 0.75,


            builder: (_, controller) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Builder(
  builder: (_) {
    switch (_rideUIState) {
      case UserRideUIState.waiting:
        return const RideWaitingSheet();

      case UserRideUIState.showOtp:
        return RideOtpSheet(
          otp: _rideOtp ?? '----', driverName: 'Ravi', driverRating: 4.5,
        );

      case UserRideUIState.idle:
      default:
        return ListView(
          controller: controller,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                "Available Services",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 16),
            Column(
              children: _services.map((service) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _serviceCard(service),
              )).toList(),
            ),
            const SizedBox(height: 20),
            Row(
              children: const [
                Text(
                  "Payment",
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                SizedBox(width: 8),
                Icon(Icons.payments, size: 18),
                SizedBox(width: 6),
                Text(
                  "Cash",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _bookRide,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  "BOOK ${_selectedServiceId.toUpperCase()}",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
    }
  },
),

              );
            },
          ),
        ],
      ),
    );
  }

Widget _pickupSearchBar() {
  return _searchContainer(
    child: TextField(
      controller: _pickupController,
      autofocus: _showPickupInput,
      decoration: const InputDecoration(
        hintText: "Pickup location",
        border: InputBorder.none,
      ),

      // 🔥 CORE FIX
      onSubmitted: (value) async {
        if (value.isEmpty) return;

        final latLng = await _getLatLngFromAddress(value);

        if (latLng == null) {
          _showSnack("Pickup location not found on map");
          return;
        }

        setState(() {
          pickupLatLng = latLng;
        });
      },
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
            decoration: BoxDecoration(color: leadingColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(child: child),
          if (trailing != null) Icon(trailing, color: Colors.grey),
        ],
      ),
    );
  }
}
