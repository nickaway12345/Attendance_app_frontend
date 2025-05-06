// import 'package:flutter/material.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:location_checker/services/notification_service.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:timezone/data/latest_10y.dart' as tz;
// import 'screens/login_screen.dart';
// import 'package:location_checker/services/local_database_servie.dart';
// import 'services/fetchAndSetTime.dart'; // Import the fetchAndSetAppTime function

// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await dotenv.load(fileName: ".env");
//   await LocalDatabaseService.database;
//   await initializeNotifications();
//   tz.initializeTimeZones();

//   // Request location permission
//   final status = await Permission.location.request();
//   if (!status.isGranted) {
//     // If location permission is denied, show a warning but proceed
//     print('Location permission denied. Proceeding with limited functionality.');
//   }

//   // Initialize the TimeService
//   try {
//     await TimeService.initialize();
//   } catch (e) {
//     print('Error initializing app: $e');
//     // Show a warning but proceed
//   }

//   runApp(MyApp());
// }

// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Login App',
//       theme: ThemeData(
//         primarySwatch: Colors.red,
//       ),
//       home: LoginScreen(),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:location_checker/services/notification_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_10y.dart' as tz;
import 'screens/login_screen.dart';
import 'package:location_checker/services/local_database_servie.dart';
import 'services/fetchAndSetTime.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Global navigator key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Background notification handler (must be top-level)
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  print('Background notification tapped!');
  navigatorKey.currentState?.push(
    MaterialPageRoute(builder: (context) => LoginScreen()),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await LocalDatabaseService.database;
  tz.initializeTimeZones();

  // Notification initialization
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
      
  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      // Foreground notification handler
      print('Foreground notification tapped!');
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    },
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
  );

  // Request location permission
  final status = await Permission.location.request();
  if (!status.isGranted) {
    print('Location permission denied');
  }

  // Initialize TimeService
  try {
    await TimeService.initialize();
  } catch (e) {
    print('Error initializing TimeService: $e');
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Login App',
      theme: ThemeData(primarySwatch: Colors.red),
      home: LoginScreen(),
      navigatorKey: navigatorKey, // Assign the global navigator key
    );
  }
}