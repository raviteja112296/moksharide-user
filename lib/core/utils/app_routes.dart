import 'package:flutter/material.dart';
import 'package:moksharide_user/features/ride/presentation/ride_history_screen.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/signin_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/map/presentation/pages/map_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/ride/presentation/pages/ride_status_screen.dart';

class AppRoutes {
  AppRoutes._();
  // Route names
  static const String splash = '/';
  static const String signIn = '/signin';
  static const String home = '/home';
  static const String map = '/map';
  static const String rideStatus = '/rideStatus';
  static const String profile = '/profile';
  static const String rideHistory = '/rideHistory';



  // Routes map for MaterialApp
  static Map<String, WidgetBuilder> get routes => {
        splash: (context) => const SplashPage(),
        signIn: (context) => const SignInPage(),
        home: (context) => const HomePage(),
        map: (context) => MapPage(),
        profile: (context) => const ProfilePage(),
        rideHistory: (context) => const RideHistoryScreen(),

      };
      
}
