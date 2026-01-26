import 'package:geolocator/geolocator.dart';
Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      // if (!serviceEnabled) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     const SnackBar(content: Text("Please enable GPS")),
      //   );
      //   return;
      // }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        // if (permission == LocationPermission.denied) {
        //   ScaffoldMessenger.of(context).showSnackBar(
        //     const SnackBar(content: Text("Location permission needed")),
        //   );
        //   return;
        // }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // setState(() {
      //   currentPosition = position;
      //   _pickupController.text = "Chintamani (${position.latitude.toStringAsFixed(2)}, ${position.longitude.toStringAsFixed(2)})";
      // });
      var pickupLat=position.latitude.toStringAsFixed(2);
      var pickupLng=position.longitude.toStringAsFixed(2);
    } catch (e) {
      print("Location error: $e");
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text("Location error: $e")),
      // );
    }
  }