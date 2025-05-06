import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:location_checker/screens/login_screen.dart';
import 'package:location_checker/services/fetchAndSetTime.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    enableVibration: true,
    playSound: true,
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

Future<void> scheduleShiftNotifications(List<Map<String, dynamic>> shiftTimings) async {
  final prefs = await SharedPreferences.getInstance();
  final firstName = prefs.getString('firstName') ?? 'User';
  
  // Cancel any existing notifications
  await flutterLocalNotificationsPlugin.cancelAll();

  final now = tz.TZDateTime.now(tz.local);

  // Schedule for each shift
  for (var shift in shiftTimings) {
    try {
      final shiftNumber = shift['shiftNumber'];
      final shiftName = _getShiftName(shiftNumber);
      final startTime = DateTime.parse(shift['startTime']);
      final endTime = DateTime.parse(shift['endTime']);

      // Convert to timezone-aware datetime
      final tzStartTime = tz.TZDateTime.from(startTime, tz.local);
      final tzEndTime = tz.TZDateTime.from(endTime, tz.local);

      // Schedule reminder 5 minutes before shift start (only if in future)
      if (tzStartTime.subtract(Duration(minutes: 5)).isAfter(now)) {
        await _scheduleNotification(
          id: shiftNumber * 10 + 1,
          title: 'Shift Starting Soon',
          body: 'Hey $firstName, your $shiftName shift starts in 5 minutes!',
          scheduledTime: tzStartTime.subtract(Duration(minutes: 5)),
        );
      }

      // Schedule shift end notification (only if in future)
      if (tzEndTime.isAfter(now)) {
        await _scheduleNotification(
          id: shiftNumber * 10 + 2,
          title: 'Shift Ended',
          body: 'Hey $firstName, please punch out for your $shiftName shift!',
          scheduledTime: tzEndTime,
        );
      }
    } catch (e) {
      print('Error scheduling notifications for shift ${shift['shiftNumber']}: $e');
    }
  }
  
  print('Scheduled notifications for ${shiftTimings.length} shifts');
}

Future<void> _scheduleNotification({
  required int id,
  required String title,
  required String body,
  required DateTime scheduledTime,
}) async {
  try {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'shift_reminders_channel',
      'Shift Reminders',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      showWhen: false,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);
    final now = tz.TZDateTime.now(tz.local);

    if (tzTime.isAfter(now)) {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzTime,
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      print('✅ Scheduled notification: $title at $tzTime');
    } else {
      print('⏩ Skipping past notification: $title at $tzTime');
    }
  } catch (e) {
    print('❌ Error scheduling notification: $e');
  }
}

String _getShiftName(int shiftNumber) {
  switch (shiftNumber) {
    case 1: return 'Morning';
    case 2: return 'Afternoon';
    case 3: return 'Night';
    case 4: return 'General';
    default: return shiftNumber.toString();
  }
}

Future<void> cancelAllNotifications() async {
  await flutterLocalNotificationsPlugin.cancelAll();
  print('All notifications canceled.');
}



