import 'dart:convert';
import 'package:http/http.dart' as http;

class RideNotificationApi {
  static const String _url =
      "https://ff1056dc-24d6-44c5-9558-d57df1c7ae22-00-2j25go0ss7084.picard.replit.dev/send-ride-notification";

  static Future<void> sendRideNotification({
    required String rideId,
    required double pickupLat,
    required double pickupLng,
    required double fare,
    required String driverToken, // 🔥 REQUIRED
  }) async {
    final response = await http.post(
      Uri.parse(_url),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "rideId": rideId,
        "pickupLat": pickupLat,
        "pickupLng": pickupLng,
        "fare": fare,
        "driverToken": driverToken,
      }),
    );

    print("📡 Notification API status: ${response.statusCode}");
    print("📡 Response body: ${response.body}");
  }
}
