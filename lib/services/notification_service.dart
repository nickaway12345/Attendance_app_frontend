import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:location_checker/screens/login_screen.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:location_checker/services/fetchAndSetTime.dart';
import 'package:path/path.dart';
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> initializeNotifications() async {
  // Android-specific settings
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher'); // Use your app's launcher icon

  // iOS-specific settings
  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  // Combined initialization settings
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  // Initialize the plugin
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      // Handle notification tap
       Navigator.push(context as BuildContext, MaterialPageRoute(builder: (context) => LoginScreen()));
       print('Notification tapped!');
    },
  );

  print('Notifications initialized successfully.');
}

Future<void> schedulePunchOutReminder() async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'punch_out_reminder_channel', // Channel ID
    'Punch Out Reminder', // Channel name
    importance: Importance.high,
    priority: Priority.high,
    showWhen: false,
  );

  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);

  // Schedule the notification 6 hours later
  final scheduledTime = tz.TZDateTime.from(
    TimeService.appTime.add(Duration(hours: 6)), // Add 6 hours to the current app time
    tz.local, // Use the local time zone
  );
  await flutterLocalNotificationsPlugin.zonedSchedule(
    0, // Notification ID
    'Punch Out Reminder', // Title
    'Don\'t forget to punch out!', // Body
    scheduledTime, // Schedule time
    platformChannelSpecifics,
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // Ensure delivery in Doze mode
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
  );

  print('Punch-out reminder scheduled for 6 hours later at $scheduledTime.');
}

Future<void> cancelPunchOutReminder() async {
  await flutterLocalNotificationsPlugin.cancel(0); // Cancel the notification with ID 0
  print('Punch-out reminder canceled.');
}



