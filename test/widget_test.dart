// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:moksharide_user/features/ride/data/ride_repository.dart';
// import 'package:moksharide_user/services/fcm_service.dart';
// import '../../../../core/utils/app_routes.dart';
// import '../../../auth/data/auth_service.dart';

// class HomePage extends StatefulWidget {
//   const HomePage({super.key});

//   @override
//   State<HomePage> createState() => _HomePageState();
// }

// class _HomePageState extends State<HomePage> {
//   final AuthService _authService = AuthService();
//   final RideRepository _rideRepository = RideRepository();
//   final FCMService _fcmService = FCMService();
//   final TextEditingController _pickupController = TextEditingController();
//   final TextEditingController _dropController = TextEditingController();
//   bool _showPickupInput = false;
//   String? _dropLocation;

//   @override
//   void initState() {
//     super.initState();
//     _fcmService.initFCM();
//   }
// Future<void> _setCurrentPickupLocation() async {
//   try {
//     // Check if location services ON
//     bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) {
//       _showSnack('Please enable GPS/location services');
//       return;
//     }

//     // Check permission
//     LocationPermission permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//       if (permission == LocationPermission.denied) {
//         _showSnack('Location permission required');
//         return;
//       }
//     }

//     if (permission == LocationPermission.deniedForever) {
//       _showSnack('Location permissions denied. Enable in Settings');
//       return;
//     }

//     // Get location with TIMEOUT & lower accuracy
//     final position = await Geolocator.getCurrentPosition(
//       desiredAccuracy: LocationAccuracy.medium,  // Changed from high
//       timeLimit: Duration(seconds: 10),         // Add timeout
//     ).timeout(Duration(seconds: 15));

//     setState(() {
//       _pickupController.text = 'Chintamani (${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)})';
//       _showPickupInput = true;
//     });

//     _showSnack('Location set: ${position.latitude.toStringAsFixed(2)}, ${position.longitude.toStringAsFixed(2)}');
//   } catch (e) {
//     print('Location error: $e');  // Debug
//     _showSnack('GPS signal weak. Try again or enter manually');
//   }
// }


//   Future<void> _showDropoffLocations(BuildContext context) async {
//     final locations = [
//       {'name': 'Tempo Stand, Chintamani', 'distance': '2.5 km', 'fare': '₹35'},
//       {'name': 'Hospital Road', 'distance': '3.8 km', 'fare': '₹55'},
//       {'name': 'College Gate', 'distance': '4.2 km', 'fare': '₹65'},
//       {'name': 'Railway Station', 'distance': '1.8 km', 'fare': '₹25'},
//       {'name': 'KGF Road Junction', 'distance': '12 km', 'fare': '₹180'},
//     ];

//     final selectedLocation = await showDialog<Map<String, String>?>(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Select Drop-off'),
//         content: SizedBox(
//           width: double.maxFinite,
//           height: 300,
//           child: ListView.builder(
//             itemCount: locations.length,
//             itemBuilder: (context, index) {
//               final loc = locations[index];
//               return ListTile(
//                 dense: true,
//                 leading: CircleAvatar(
//                   radius: 16,
//                   backgroundColor: Colors.orange,
//                   child: Icon(Icons.flag, color: Colors.white, size: 18),
//                 ),
//                 title: Text(loc['name']!),
//                 subtitle: Text('${loc['distance']} • ${loc['fare']}'),
//                 onTap: () => Navigator.pop(context, loc),
//               );
//             },
//           ),
//         ),
//       ),
//     );

//     if (selectedLocation != null) {
//       setState(() {
//         _dropLocation = selectedLocation['name'];
//         _dropController.text = '${selectedLocation['name']} (${selectedLocation['fare']})';
//       });
//     }
//   }

//   Future<void> _bookRide() async {
//     if (_pickupController.text.isEmpty || _dropController.text.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Please select pickup and drop locations'),
//           backgroundColor: Colors.orange,
//         ),
//       );
//       return;
//     }

//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(
//         content: Text('Searching for nearby drivers...'),
//         backgroundColor: Colors.orange,
//         duration: Duration(seconds: 2),
//       ),
//     );

//     try {
//       final rideId = await _rideRepository.bookRide(
//         pickup: _pickupController.text,
//         drop: _dropController.text,
//         dropoff: _dropController.text,
//       );
      
//       _pickupController.clear();
//       _dropController.clear();
//       setState(() {
//         _showPickupInput = false;
//         _dropLocation = null;
//       });

//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Ride booked successfully! ID: $rideId'),
//             backgroundColor: Colors.green,
//             duration: const Duration(seconds: 2),
//           ),
//         );
//         Navigator.pushNamed(context, AppRoutes.rideStatus, arguments: rideId);
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Failed to book ride: $e'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     }
//   }

//   void _showSnack(String message) {
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(message),
//           duration: const Duration(seconds: 2),
//           behavior: SnackBarBehavior.floating,
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//         ),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final User? user = _authService.currentUser;
//     final String userEmail = user?.email ?? 'Unknown';

//     return Scaffold(
//       body: Stack(
//         children: [
//           /// Gradient Background
//           Container(
//             width: double.infinity,
//             height: double.infinity,
//             decoration: BoxDecoration(
//               gradient: LinearGradient(
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//                 colors: [
//                   Colors.green.shade400,
//                   Colors.green.shade700,
//                   Colors.blue.shade600,
//                 ],
//               ),
//             ),
//             child: Center(
//               child: Icon(
//                 Icons.location_on,
//                 size: 80,
//                 color: Colors.white70,
//               ),
//             ),
//           ),

//           /// TOP LOCATION SEARCH
//           Positioned(
//             top: MediaQuery.of(context).padding.top + 60,
//             left: 16,
//             right: 16,
//             child: Column(
//               children: [
//                 Row(
//                   children: [
//                     Expanded(
//                       child: Column(
//                         children: [
//                           // Pickup - Direct TextField or placeholder
//                           _pickupLocationField(),
//                           const SizedBox(height: 8),
//                           GestureDetector(
//                             onTap: () => _showDropoffLocations(context),
//                             child: _locationField(
//                               icon: Icons.flag,
//                               iconColor: Colors.red,
//                               hint: _dropLocation ?? "Select drop-off (fare shown)",
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(width: 12),
//                     GestureDetector(
//                       onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
//                       child: CircleAvatar(
//                         radius: 24,
//                         backgroundImage: user?.photoURL != null 
//                             ? NetworkImage(user!.photoURL!) 
//                             : null,
//                         child: user?.photoURL == null 
//                             ? const Icon(Icons.person, size: 28)
//                             : null,
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),

//           /// CURRENT LOCATION BUTTON
//           Positioned(
//             bottom: 240,
//             right: 16,
//             child: FloatingActionButton(
//               mini: true,
//               backgroundColor: Colors.white,
//               onPressed: _setCurrentPickupLocation,
//               child: const Icon(Icons.my_location, color: Colors.green),
//             ),
//           ),

//           /// BOTTOM SHEET
//           DraggableScrollableSheet(
//             initialChildSize: 0.38,
//             minChildSize: 0.25,
//             maxChildSize: 0.7,
//             builder: (context, scrollController) {
//               return Container(
//                 padding: const EdgeInsets.all(20),
//                 decoration: const BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
//                   boxShadow: [
//                     BoxShadow(blurRadius: 20, color: Colors.black26),
//                   ],
//                 ),
//                 child: ListView(
//                   controller: scrollController,
//                   children: [
//                     /// Welcome Card
//                     Container(
//                       width: double.infinity,
//                       padding: const EdgeInsets.all(20),
//                       decoration: BoxDecoration(
//                         color: Colors.green.shade50,
//                         borderRadius: BorderRadius.circular(16),
//                         border: Border.all(color: Colors.green.shade200),
//                       ),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             'Welcome back!',
//                             style: TextStyle(
//                               fontSize: 20,
//                               fontWeight: FontWeight.bold,
//                               color: Colors.green.shade800,
//                             ),
//                           ),
//                           const SizedBox(height: 8),
//                           Row(
//                             children: [
//                               Icon(Icons.email, size: 18, color: Colors.green.shade600),
//                               const SizedBox(width: 8),
//                               Expanded(
//                                 child: Text(
//                                   userEmail,
//                                   style: TextStyle(
//                                     fontSize: 14,
//                                     color: Colors.green.shade700,
//                                   ),
//                                   overflow: TextOverflow.ellipsis,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(height: 24),

//                     /// BOOK RIDE BUTTON
//                     FilledButton(
//                       onPressed: _bookRide,
//                       style: FilledButton.styleFrom(
//                         padding: const EdgeInsets.symmetric(vertical: 18),
//                         backgroundColor: Colors.green.shade600,
//                         foregroundColor: Colors.white,
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(16),
//                         ),
//                         elevation: 4,
//                       ),
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           const Icon(Icons.directions_car, size: 20),
//                           const SizedBox(width: 12),
//                           const Text(
//                             'BOOK RIDE NOW',
//                             style: TextStyle(
//                               fontSize: 18,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(height: 24),

//                     /// Services
//                     Row(
//                       children: [
//                         Expanded(
//                           child: _serviceItem(
//                             icon: Icons.electric_rickshaw,
//                             label: "Auto",
//                             color: Colors.green,
//                           ),
//                         ),
//                         const SizedBox(width: 16),
//                         Expanded(
//                           child: _serviceItem(
//                             icon: Icons.local_taxi,
//                             label: "Cab",
//                             color: Colors.blue,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               );
//             },
//           ),
//         ],
//       ),
//     );
//   }

//   // 🚕 Direct Pickup TextField
// Widget _pickupLocationField() {
//   return Container(
//     height: 56,
//     padding: const EdgeInsets.symmetric(horizontal: 16),
//     decoration: BoxDecoration(
//       color: Colors.white,
//       borderRadius: BorderRadius.circular(28),
//       boxShadow: [
//         BoxShadow(
//           color: Colors.black.withOpacity(0.08),
//           blurRadius: 12,
//           offset: const Offset(0, 4),
//         ),
//       ],
//     ),
//     child: Row(
//       children: [
//         // Location indicator (OLA style)
//         Container(
//           width: 10,
//           height: 10,
//           decoration: const BoxDecoration(
//             color: Colors.green,
//             shape: BoxShape.circle,
//           ),
//         ),

//         const SizedBox(width: 12),

//         // Search field (ALWAYS TextField)
//         Expanded(
//           child: TextField(
//             controller: _pickupController,
//             autofocus: _showPickupInput,
//             style: const TextStyle(
//               fontSize: 15,
//               fontWeight: FontWeight.w500,
//               color: Colors.black87,
//             ),
//             decoration: InputDecoration(
//               hintText: 'Search pickup location',
//               hintStyle: TextStyle(
//                 color: Colors.grey.shade500,
//                 fontSize: 15,
//               ),
//               border: InputBorder.none,
//               isDense: true,
//             ),
//           ),
//         ),

//         // Clear icon (optional, clean)
//         if (_pickupController.text.isNotEmpty)
//           GestureDetector(
//             onTap: () {
//               setState(() {
//                 _pickupController.clear();
//               });
//             },
//             child: const Icon(
//               Icons.close,
//               size: 18,
//               color: Colors.grey,
//             ),
//           ),
//       ],
//     ),
//   );
// }


//   Widget _locationField({
//     required IconData icon,
//     required Color iconColor,
//     required String hint,
//   }) {
//     return Container(
//       constraints: const BoxConstraints(minHeight: 56),
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 2)),
//         ],
//       ),
//       child: Row(
//         children: [
//           Container(
//             padding: const EdgeInsets.all(8),
//             decoration: BoxDecoration(
//               color: iconColor.withOpacity(0.1),
//               shape: BoxShape.circle,
//             ),
//             child: Icon(icon, color: iconColor, size: 20),
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Text(
//               hint,
//               style: TextStyle(
//                 color: Colors.black87,
//                 fontSize: 15,
//                 fontWeight: FontWeight.w500,
//               ),
//               overflow: TextOverflow.ellipsis,
//             ),
//           ),
//           const Icon(Icons.arrow_drop_down, color: Colors.grey),
//         ],
//       ),
//     );
//   }

//   Widget _serviceItem({
//     required IconData icon,
//     required String label,
//     required Color color,
//   }) {
//     return GestureDetector(
//       onTap: () {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('$label service selected'),
//             backgroundColor: color.withOpacity(0.2),
//             duration: const Duration(seconds: 1),
//           ),
//         );
//       },
//       child: Container(
//         padding: const EdgeInsets.all(16),
//         decoration: BoxDecoration(
//           color: color.withOpacity(0.1),
//           borderRadius: BorderRadius.circular(16),
//           border: Border.all(color: color.withOpacity(0.3)),
//         ),
//         child: Column(
//           children: [
//             Icon(icon, size: 32, color: color),
//             const SizedBox(height: 8),
//             Text(
//               label,
//               style: TextStyle(
//                 color: color,
//                 fontWeight: FontWeight.w600,
//                 fontSize: 14,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _pickupController.dispose();
//     _dropController.dispose();
//     super.dispose();
//   }
// }
