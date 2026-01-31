import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/ride_notification_api.dart';

class RideRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
String generateRideOtp() {
  final random = Random();
  return (1000 + random.nextInt(9000)).toString(); // 4-digit OTP
}

  /// BOOK RIDE + SEND NOTIFICATION
  Future<String> bookRide({
    required String pickup,
    required double pickupLat,
    required double pickupLng,
    required String drop,
    required double dropLat,
    required double dropLng,
    required String serviceType,
    required double estimatedPrice,
    // required double distanceKm,
  }) async {
    // 🔐 AUTH CHECK
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    // 📝 CREATE RIDE DOCUMENT REFERENCE FIRST
    final rideRef = _firestore.collection('ride_requests').doc();
    final String rideOtp = generateRideOtp();


    // 📦 SAVE RIDE DATA
await rideRef.set({
  'rideId': rideRef.id,
  'userId': user.uid,

  'pickupAddress': pickup,
  'pickupLat': pickupLat,
  'pickupLng': pickupLng,

  'dropAddress': drop,
  'dropLat': dropLat,
  'dropLng': dropLng,

  'serviceType': serviceType,
  'estimatedPrice': estimatedPrice,
  // 'distanceKm':distanceKm,
  /// 🔐 OTP (IMPORTANT)
  'rideOtp': rideOtp,
  'otpVerified': false,

  'status': 'requested',
  'assignedDriverId': null,

  'createdAt': FieldValue.serverTimestamp(),
  'updatedAt': FieldValue.serverTimestamp(),
});


    print('✅ Ride booked successfully: ${rideRef.id}');

    // 🚕 GET ONE ONLINE DRIVER (TEMPORARY LOGIC)
    final driverSnapshot = await _firestore
        .collection('drivers')
        .where('isOnline', isEqualTo: true)
        .limit(1)
        .get();

    if (driverSnapshot.docs.isEmpty) {
      print('⚠️ No online drivers found');
      return rideRef.id;
    }

    final driverToken = driverSnapshot.docs.first['fcmToken'];

    if (driverToken == null || driverToken.toString().isEmpty) {
      print('⚠️ Driver token missing');
      return rideRef.id;
    }

    // 🔔 CALL YOUR NOTIFICATION API (THIS IS WHAT YOU ASKED)
    await RideNotificationApi.sendRideNotification(
      rideId: rideRef.id,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      fare: estimatedPrice,
      // driverToken: driverToken,
    );

    print('📡 Notification sent to driver');

    return rideRef.id;
  }

  /// ❌ CANCEL RIDE
  Future<void> cancelRide(String rideId) async {
    await _firestore.collection('ride_requests').doc(rideId).update({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
    });
  }
}
