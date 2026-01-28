import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class RoutingService {
  // Free OSRM Server
  final String _baseUrl = 'https://router.project-osrm.org/route/v1/driving';

  Future<List<LatLng>> getRoute(LatLng start, LatLng end) async {
    // OSRM requires coordinates in (Longitude, Latitude) order
    final String url = '$_baseUrl/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=polyline';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['routes'].isNotEmpty) {
          // OSRM returns an encoded polyline string
          String encodedPolyline = data['routes'][0]['geometry'];
          
          // 🔥 FIX: Use the class name directly. No 'apiKey' needed for decoding.
          List<PointLatLng> result = PolylinePoints.decodePolyline(encodedPolyline);
          
          // Convert to Google Maps LatLng
          return result.map((p) => LatLng(p.latitude, p.longitude)).toList();
        }
      }
    } catch (e) {
      print("❌ Routing Error: $e");
    }
    // Fallback: If internet fails, return a straight line
    return [start, end]; 
  }
}