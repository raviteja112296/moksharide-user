import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:moksharide_user/features/home/presentation/pages/home_page.dart';
import 'package:moksharide_user/features/ride/presentation/pages/ride_status_screen.dart';
import 'package:moksharide_user/firebase_options.dart';
import 'package:moksharide_user/services/fcm_service.dart';
import 'core/utils/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}


class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    @override
void initState() {
  super.initState();
  FCMService().initFCM(); 
}

  }
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AmbaniYatri',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,

      // ✅ static routes (NO arguments)
      routes: AppRoutes.routes,

      // ✅ dynamic routes (WITH arguments)
      onGenerateRoute: (settings) {
        if (settings.name == AppRoutes.rideStatus) {
          final rideId = settings.arguments as String;

          return MaterialPageRoute(
            builder: (_) => RideStatusScreen(rideId: rideId),
          );
        }
        return null;
      },

      initialRoute: AppRoutes.splash,
      // home: HomePage(),
    );
    
  }
}
