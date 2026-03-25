// import 'package:url_launcher/url_launcher.dart';
// Old ❌
// 👉 You → call Twilio → blocked
// class VoiceSupportService {
//   // Your Twilio phone number
//   static const String supportNumber = '+15077282325';

//   static Future<void> callSupport() async {
//     final Uri callUri = Uri(
//       scheme: 'tel',
//       path: supportNumber,
//     );

//     if (await canLaunchUrl(callUri)) {
//       await launchUrl(callUri);
//     }
//   }
// } 
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
//New ✅
// 👉 You → tell server → Twilio calls you
class VoiceSupportService {
  static const String backendUrl = 'https://moksharide-voice-support.onrender.com';

  static Future<void> callSupport(String phoneNumber) async {
    final response = await http.post(
      Uri.parse('$backendUrl/make-call'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "phone": phoneNumber,
      }),
    );
print("STATUS: ${response.statusCode}");
      print("BODY: ${response.body}");
    if (response.statusCode == 200) {
      print("Call triggered successfully");
    } else {
      SnackBar(
  content: Text("Connecting... please wait"),
);
      print("Failed to trigger call");
    }
  }
}