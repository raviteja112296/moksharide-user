import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/fare_calculator.dart';
import '../../../services/ride_notification_api.dart';
class RideRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  

  

  Future<String> bookRide({
    required String pickup,
    required String dropoff,
    required String drop,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // 🔹 Mock distance
      final double distance = 4.5;
      final double price = FareCalculator.calculateFare(distance);
      Position pickupPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 🔹 Create Firestore ride
      final docRef = _firestore.collection('ride_requests').doc();

      final rideData = {
        'rideId': docRef.id,
        'userId': user.uid,
        'pickup': pickup,
        'dropoff': dropoff,
        'distance': distance,
        'price': price,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(rideData);

      print('✅ Ride booked successfully: ${docRef.id}');
      final driverDoc = await FirebaseFirestore.instance
    .collection('drivers')
    .limit(1)
    .get();

final driverToken = driverDoc.docs.first['fcmToken'];


      // 🔔 SEND PUSH NOTIFICATION (IMPORTANT PART)
      await RideNotificationApi.sendRideNotification(
  rideId: docRef.id,
  pickupLat: pickupPosition.latitude,
  pickupLng: pickupPosition.longitude,

  fare: price, driverToken: driverToken,
);


      return docRef.id;
    } catch (e) {
      print('❌ Book ride error: $e');
      throw Exception('Failed to book ride: $e');
    }
  }
 Future<void> cancelRide(String rideId) async {
    await _firestore.collection('ride_requests').doc(rideId).update({
      'status': 'cancel',
      'cancelledAt': FieldValue.serverTimestamp(),
    });
  }

}
