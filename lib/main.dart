import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:location_checker/services/notification_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_10y.dart' as tz;
import 'screens/login_screen.dart';
import 'package:location_checker/services/local_database_servie.dart';
import 'services/fetchAndSetTime.dart'; // Import the fetchAndSetAppTime function

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await LocalDatabaseService.database;
  await initializeNotifications();
  tz.initializeTimeZones();

  // Request location permission
  final status = await Permission.location.request();
  if (!status.isGranted) {
    // If location permission is denied, show a warning but proceed
    print('Location permission denied. Proceeding with limited functionality.');
  }

  // Initialize the TimeService
  try {
    await TimeService.initialize();
  } catch (e) {
    print('Error initializing app: $e');
    // Show a warning but proceed
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Login App',
      theme: ThemeData(
        primarySwatch: Colors.red,
      ),
      home: LoginScreen(),
    );
  }
}