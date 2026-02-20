import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier {
  // Global notifier that the whole app can listen to
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.light);

  // Load the saved preference when the app starts
  static Future<void> initTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDarkMode') ?? false;
    themeMode.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  // Toggle and save the preference
  static Future<void> toggleTheme(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDark);
    themeMode.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }
}