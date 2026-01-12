import 'package:cloud_firestore/cloud_firestore.dart';

class RideRequest {
  final String id;
  final String userId;
  final String pickup;
  final String dropoff;
  final double distance;
  final double price;
  final String status;
  final DateTime? createdAt;

  RideRequest({
    required this.id,
    required this.userId,
    required this.pickup,
    required this.dropoff,
    required this.distance,
    required this.price,
    required this.status,
    this.createdAt,
  });

  factory RideRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RideRequest(
      id: doc.id,
      userId: data['userId'] ?? '',
      pickup: data['pickup'] ?? '',
      dropoff: data['dropoff'] ?? '',
      distance: (data['distance'] ?? 0).toDouble(),
      price: (data['price'] ?? 0).toDouble(),
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
