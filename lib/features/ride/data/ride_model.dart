// import 'package:cloud_firestore/cloud_firestore.dart';

// class RideRequest {
//   final String rideId; // ✅ added
//   final String userId;
//   final String pickup;
//   final String dropoff;
//   final double distance;
//   final double price;
//   final String status;
//   final DateTime createdAt;
//   final double pickupLat;
//   final double pickupLng;

//   RideRequest({
//     required this.rideId,
//     required this.userId,
//     required this.pickup,
//     required this.dropoff,
//     required this.distance,
//     required this.price,
//     required this.status,
//     required this.createdAt,
//     required this.pickupLat,
//     required this.pickupLng,
//   });

//   factory RideRequest.fromFirestore(DocumentSnapshot doc) {
//     final data = doc.data() as Map<String, dynamic>;
//     return RideRequest(
//       rideId: doc.id, // ✅ Firestore document ID
//       userId: data['userId'] ?? '',
//       pickup: data['pickup'] ?? '',
//       dropoff: data['dropoff'] ?? '',
//       distance: (data['distance'] ?? 0).toDouble(),
//       price: (data['price'] ?? 0).toDouble(),
//       status: data['status'] ?? 'pending',
//       pickupLat: data['pickupLat'] ?? '',
//       pickupLng: data['pickupLng'] ?? '',
//       createdAt:
//           (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
//     );
//   }

//   Map<String, dynamic> toFirestore() {
//     return {
//       'userId': userId,
//       'pickup': pickup,
//       'dropoff': dropoff,
//       'distance': distance,
//       'price': price,
//       'status': status,
//       'createdAt': FieldValue.serverTimestamp(),
//     };
//   }
// }
