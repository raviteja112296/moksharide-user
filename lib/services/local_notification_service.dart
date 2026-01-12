import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings =
        InitializationSettings(android: androidSettings);

    await _notifications.initialize(settings);

    // 🔔 CREATE CHANNEL WITH SOUND (ONCE)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'ride_channel',
      'Ride Requests',
      description: 'Incoming ride alerts',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('ride_alert'),
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static Future<void> showRideAlert() async {
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'ride_channel',
      'Ride Requests',
      channelDescription: 'Incoming ride alerts',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('ride_alert'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList(const [0, 500, 1000, 500]),
      fullScreenIntent: true,
    );

    final NotificationDetails details =
        NotificationDetails(android: androidDetails);

    await _notifications.show(
      0,
      '🚕 New Ride Request',
      'Tap to accept the ride',
      details,
    );
  }
}
