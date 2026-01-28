import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:latlong2/latlong.dart';

class RideLocation {
  final String address;
  final LatLng latLng;

  RideLocation({
    required this.address,
    required this.latLng,
  });

  Map<String, dynamic> toMap() {
    return {
      'address': address,
      'lat': latLng.latitude,
      'lng': latLng.longitude,
    };
  }

  factory RideLocation.fromMap(Map<String, dynamic> map) {
    return RideLocation(
      address: map['address'],
      latLng: LatLng(map['lat'], map['lng']),
    );
  }
}
