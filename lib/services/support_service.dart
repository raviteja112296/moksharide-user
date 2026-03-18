import 'dart:convert';
import 'package:http/http.dart' as http;

class SupportService {
  // Change this to your Render URL after deployment
  // static const String _baseUrl = 'http://192.168.29.167:5001';   //----> this for local
  static const String _baseUrl = 'https://moksharide-support.onrender.com';

  static Future<String> sendMessage({
    required String userId,
    required String message,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/support'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'message': message,
        }),
      ).timeout(
        const Duration(seconds: 60), // ← wait up to 60 seconds
  onTimeout: () {
    throw Exception('timeout');
  },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['reply'];
      } else {
        return 'Something went wrong. Please try again.';
      }
    } catch (e) {
      return 'Cannot connect to support. Check your internet.';
    }
  }
}