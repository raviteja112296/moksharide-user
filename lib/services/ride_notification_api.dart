import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class RideNotificationApi {
  // ✅ Keep your IP as is https://moksha-api.onrender.com/send-ride-notification
  // static const String _baseUrl = "http://192.168.29.167:5000"; 
  static const String _baseUrl = "https://moksha-api.onrender.com"; 
  static const String _endpoint = "/send-ride-notification";

  static Future<bool> sendRideNotification({
    required String rideId,
    required double pickupLat,
    required double pickupLng,
    required double fare, required String serviceType,
  }) async {
    final url = Uri.parse("$_baseUrl$_endpoint");

    try {
      debugPrint("📡 Sending to: $url");

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "rideId": rideId,
          "pickupLat": pickupLat,
          "pickupLng": pickupLng,
          "fare": fare,
          "serviceType":serviceType,

        }),
      );

      debugPrint("📡 Status Code: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // 🔥 THIS IS WHERE YOU SEE THE DRIVERS
        final List<dynamic> drivers = data['notifiedDrivers'] ?? [];
        debugPrint("✅ ------------------------------------------");
        debugPrint("✅ NOTIFICATION SENT TO ${drivers.length} DRIVERS:");
        for (var driverId in drivers) {
          debugPrint("   👤 Driver ID: $driverId");
        }
        debugPrint("✅ ------------------------------------------");
        
        return true;
      } else {
        debugPrint("❌ Failed: ${response.body}");
        return false;
      }
    } catch (e) {
      debugPrint("❌ Error: $e");
      return false;
    }
  }
}