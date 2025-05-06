import 'dart:async'; // For StreamSubscription
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart'; // For formatting date and time
import 'package:http/http.dart' as http;
import 'package:location_checker/screens/history_screen.dart';
import 'package:location_checker/screens/login_screen.dart';
import 'package:location_checker/screens/mediclaim_screen.dart';
import 'package:location_checker/screens/profile_screen.dart';
import 'package:location_checker/services/fetchAndSetTime.dart';
import 'dart:convert';
import 'package:location_checker/services/location_service.dart';
import 'package:location_checker/services/local_database_servie.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:location_checker/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart'; // To track internet connectivity
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';

class LocationCheckerScreen extends StatefulWidget {
  final String empId;
  const LocationCheckerScreen({super.key, required this.empId});

  @override
  _LocationCheckerScreenState createState() => _LocationCheckerScreenState();
}

class _LocationCheckerScreenState extends State<LocationCheckerScreen> {
  Map<String, String> _userDetails = {'firstName': 'Unknown', 'email': 'Unknown'};
  final int _selectedIndex = 0;
  DateTime currentTime = TimeService.appTime;
  String _statusMessage = 'Check your location';
  bool _isMarkInEnabled = false;
  bool _isMarkOutEnabled = false;
  String _inTime = '';
  String _outTime = '';
  String _location = 'Outside Office';
  final String _day = 'H'; // Default to 'H' for half-day
  late String emp_id;
  final String _currentDate = DateFormat('yyyy-MM-dd').format(TimeService.appTime);
  double _totalHours = 0.0;
  bool _isLoading = false; // Track loading state

  bool _isAdmin = false;
  // Subscription for connectivity changes
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;

  late Timer _timer;

  void _onItemTapped(int index) {
    if (index == 0) {
      // Navigate to LocationCheckerScreen (Home)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LocationCheckerScreen(empId: emp_id)),
      );
    } else if (index == 1) {
      // Navigate to HistoryScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HistoryScreen(empId: emp_id)),
      );
    }
  }

  // Function to delete entries for the current date
Future<void> _deleteEntriesForCurrentDate() async {
  await LocalDatabaseService.deleteEntriesForDate('HRCPL116', '2025-03-11');
}

  @override
  void initState() {
    super.initState();
    emp_id = widget.empId;
    _fetchHolidays();
    _fetchUserDetails();
    _fetchLocations();
    _checkAdminStatus(); 
    _checkAndRequestLocationPermissions();

   //_deleteEntriesForCurrentDate();

    // Start the timer to update the current time every second
    _timer = Timer.periodic(Duration(seconds: 1), (Timer t) {
      _getCurrentTime();
    });

    // Check user location and existing entries
    _checkUserLocation();
    _checkExistingEntries();
    _fetchAttendanceData();

    // Declare _connectivitySubscription as StreamSubscription<List<ConnectivityResult>>
    late StreamSubscription<List<ConnectivityResult>> connectivitySubscription;

    // Monitor internet connectivity changes
    connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      for (var result in results) {
        if (result == ConnectivityResult.mobile || result == ConnectivityResult.wifi) {
          // Trigger sync when connectivity is regained
          _syncAttendanceData();
          _syncRegularizationData();
          break;  // Exit loop once connectivity is regained
        }
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  void _getCurrentTime() {
    setState(() {
      currentTime = TimeService.appTime;
    });
  }

  Future<void> _fetchUserDetails() async {
    final userDetails = await getUserDetails();
    setState(() {
      _userDetails = userDetails;
    });
  }

  Future<void> _checkAndRequestLocationPermissions() async {
  // Check if location services are enabled
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    print('Location services are disabled.');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Location services are disabled. Please enable them.')),
    );
    return;
  }

  // Check location permissions
  PermissionStatus status = await Permission.location.status;
  if (status.isDenied) {
    // Request location permissions
    status = await Permission.location.request();
    if (status.isDenied) {
      print('Location permissions are denied.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location permissions are denied.')),
      );
      return;
    }
  }

  if (status.isPermanentlyDenied) {
    print('Location permissions are permanently denied.');
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Location permissions are permanently denied. Please enable them in settings.'),
      action: SnackBarAction(
        label: 'Open Settings',
        onPressed: _openAppSettings,
      ),
    ),
  );
  return;
  }

  print('Location permissions are granted.');
}

Future<void> _openAppSettings() async {
  await openAppSettings();
}

  Future<Map<String, String>> getUserDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final firstName = prefs.getString('firstName') ?? "Unknown";
    final email = prefs.getString('email') ?? "Unknown";

    return {
      'firstName': firstName,
      'email': email,
    };
  }

  List<DateTime> _holidays = [];

  Future<void> _fetchHolidays() async {
    String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://default-url.com';
    final response = await http.get(Uri.parse('$baseUrl/holidays'));
    if (response.statusCode == 200) {
      final List<dynamic> holidaysData = jsonDecode(response.body);
      setState(() {
        _holidays = holidaysData.map((item) => DateTime.parse(item['date'])).toList();
      });
    } else {
      throw Exception('Failed to load holidays');
    }
  }

  Future<void> _fetchAttendanceData() async {
    final db = await LocalDatabaseService.database;

    // First, get the latest attendance entry, sorted by both in_time and out_time
    final List<Map<String, dynamic>> attendanceData = await db.query(
      'attendance',
      where: 'emp_id = ? AND date = ?',
      whereArgs: [emp_id, _currentDate],
      orderBy: 'in_time DESC, out_time DESC',
      limit: 1,
    );

    // Then, get the latest regularization entry, sorted by both in_time and out_time
    final List<Map<String, dynamic>> regularizationData = await db.query(
      'regularization',
      where: 'emp_id = ? AND date = ?',
      whereArgs: [emp_id, _currentDate],
      orderBy: 'in_time DESC, out_time DESC',
      limit: 1,
    );

    setState(() {
      if (attendanceData.isNotEmpty) {
        // Get punch-in from attendance
        _inTime = attendanceData.first['in_time'] ?? '';

        // For punch-out, first check attendance
        if (attendanceData.first['out_time'] != null) {
          _outTime = attendanceData.first['out_time'];
          _totalHours = attendanceData.first['total_hours'] ?? 0.0;
        }
        // If no punch-out in attendance, check regularization
        else if (regularizationData.isNotEmpty && regularizationData.first['out_time'] != null) {
          _outTime = regularizationData.first['out_time'];
          // Keep total hours blank when mixing data from different tables
          _totalHours = 0.0;
        } else {
          _outTime = '';
          _totalHours = 0.0;
        }
      }
      // If no attendance entry, check regularization
      else if (regularizationData.isNotEmpty) {
        _inTime = regularizationData.first['in_time'] ?? '';
        _outTime = regularizationData.first['out_time'] ?? '';
        // Only show total hours if both in and out times are from regularization
        _totalHours = (regularizationData.first['in_time'] != null &&
                regularizationData.first['out_time'] != null)
            ? regularizationData.first['total_hours'] ?? 0.0
            : 0.0;
      } else {
        _inTime = '';
        _outTime = '';
        _totalHours = 0.0;
      }
    });
  }

  // Check if mark-in or mark-out is already done for the current date
  Future<void> _checkExistingEntries() async {
    final hasMarkIn = await LocalDatabaseService.hasMarkInForDate(emp_id, _currentDate);
    final hasMarkOut = await LocalDatabaseService.hasMarkOutForDate(emp_id, _currentDate);

    setState(() {
      _isMarkInEnabled = !hasMarkIn;
      _isMarkOutEnabled = hasMarkIn && !hasMarkOut;
    });
  }

  // Call the function from LocationService to check proximity
  Future<void> _checkUserLocation() async {
  try {
    print('Checking user location...');
    String result = await LocationService.checkUserProximity();
    setState(() {
      _statusMessage = result;
      _location = result == 'office' ? 'Office' : 'Outside Office';
    });
    print('User location: $_location');
  } catch (e) {
    print('Error checking user location: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to check location. Please try again.')),
    );
  }
}

  // Refresh Button Functionality
  Future<void> _refreshLocation() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 100); // Vibrate for 100ms
    }
    _checkUserLocation(); // Recheck the location
    setState(() {
      print("Refresh pressed");
    });
  }

  bool _isSundayOrHoliday(DateTime date) {
    // Check if the date is a Sunday
    if (date.weekday == DateTime.sunday) {
      return true;
    }

    // Check if the date is a holiday
    for (var holiday in _holidays) {
      if (date.year == holiday.year && date.month == holiday.month && date.day == holiday.day) {
        return true;
      }
    }

    return false;
  }

  // Mark-in logic
Future<void> _markIn() async {
  try {
    print('Starting mark-in process...');

    // Show confirmation dialog
    bool confirm = await _showConfirmationDialog('Punch In');
    if (!confirm) {
      print('User canceled mark-in.');
      return; // User canceled the action
    }
    print('User confirmed mark-in.');

    // Check and request location permissions
    await _checkAndRequestLocationPermissions();

    // Check user location
    print('Checking user location...');
    await _checkUserLocation(); // Ensure this method updates `_location`

    // Check if user is inside the office
    if (_location != 'Office') {
      print('User is outside the office. Showing alert...');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You must be inside the office to punch in.')),
      );
      return; // Exit the function if the user is outside the office
    }

    // Check if today is Sunday or a holiday
    if (_isSundayOrHoliday(TimeService.appTime)) {
      print('Today is a Sunday or holiday. Mark-in not allowed.');
      _showSundayOrHolidayAlert();
      return;
    }

    // Trigger vibration feedback
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 100); // Vibrate for 100ms
    }

    // Fetch current location coordinates
    print('Fetching current location...');
    Position? position;
    try {
      // Try to get the last known position first
      position = await Geolocator.getLastKnownPosition();
      if (position == null) {
        print('No last known position. Fetching new location...');
        position = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        ).timeout(Duration(seconds: 10)); // Add a 10-second timeout
      }
      print('Location fetched: ${position.latitude}, ${position.longitude}');
    } on TimeoutException catch (e) {
      print('Location fetch timed out: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch location. Please check your GPS signal.')),
      );
      return;
    } catch (e) {
      print('Error fetching location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch location. Please try again.')),
      );
      return;
    }

    // Prepare attendance data
    Map<String, dynamic> attendanceData = {
      'emp_id': emp_id,
      'date': _currentDate,
      'in_time': DateFormat('HH:mm:ss').format(TimeService.appTime),
      'out_time': null,
      'total_hours': 0,
      'location_in': _location,
      'location_out': null,
      'day': 'H',
      'punch_in_lat': position.latitude,
      'punch_in_long': position.longitude,
      'punch_out_lat': null,
      'punch_out_long': null,
      'synced': 0, // Mark as unsynced
    };

    // Save attendance data to the database
    print('Saving attendance data to local DB...');
    final db = await LocalDatabaseService.database;
    try {
      await db.transaction((txn) async {
        await txn.insert('attendance', attendanceData);
        print('Attendance data saved to attendance table.');
      });
      await schedulePunchOutReminder();
    } catch (e) {
      print('Error saving data to database: $e');
    }

    // Verify that the data was saved
    print('Verifying saved data...');
    List<Map<String, dynamic>> savedData;
    try {
      savedData = await db.query(
        'attendance',
        where: 'emp_id = ? AND date = ?',
        whereArgs: [emp_id, _currentDate],
      );
      if (savedData.isEmpty) {
        print('Error: Data was not saved to the database.');
      }
      print('Saved data: $savedData');
    } catch (e) {
      print('Error verifying saved data: $e');
    }

    // Update UI state
    print('Updating UI state...');
    setState(() {
      _inTime = attendanceData['in_time'];
      _isMarkInEnabled = false;
      _isMarkOutEnabled = true;
    });

    // Try syncing if connected to the internet
    print('Syncing data with backend...');
    try {
      await _syncAttendanceData();
      print('Data synced successfully.');
    } catch (e) {
      print('Error syncing data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to sync data. Please check your internet connection.')),
      );
    }

    print('Mark-in process completed successfully.');
  } catch (e) {
    print('Unexpected error in _markIn: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('An unexpected error occurred. Please try again.')),
    );
  }
}

Future<void> _markOut() async {
  try {
    // Show confirmation dialog
    bool confirm = await _showConfirmationDialog('Punch Out');
    if (!confirm) return; // User canceled the action

    // Check and request location permissions
    await _checkAndRequestLocationPermissions();

    // Check user location
    print('Checking user location...');
    await _checkUserLocation(); // Ensure this method updates `_location`

    // Check if user is inside the office
    if (_location != 'Office') {
      print('User is outside the office. Showing alert...');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You must be inside the office to punch out.')),
      );
      return; // Exit the function if the user is outside the office
    }

    // Check if today is Sunday or a holiday
    if (_isSundayOrHoliday(TimeService.appTime)) {
      _showSundayOrHolidayAlert();
      return;
    }

    // Fetch punch-in data (check if in attendance or regularization)
    Map<String, dynamic>? punchInData = await LocalDatabaseService.getPunchInDataForDate(emp_id, _currentDate);
    bool entryInAttendance = await LocalDatabaseService.isInAttendance(emp_id, _currentDate);
    String locationIn = 'Unknown';
    String day = '';

    // Trigger vibration feedback
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 100); // Vibrate for 100ms
    }

    // Get current location coordinates for punch-out
    print('Fetching current location...');
    Position? currentPosition;
    try {
      // Try to get the last known position first
      currentPosition = await Geolocator.getLastKnownPosition();
      if (currentPosition == null) {
        print('No last known position. Fetching new location...');
        currentPosition = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        ).timeout(Duration(seconds: 10)); // Add a 10-second timeout
      }
      print('Location fetched: ${currentPosition.latitude}, ${currentPosition.longitude}');
    } on TimeoutException catch (e) {
      print('Location fetch timed out: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch location. Please check your GPS signal.')),
      );
      return;
    } catch (e) {
      print('Error fetching location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch location. Please try again.')),
      );
      return;
    }
    double punchOutLat = currentPosition.latitude;
    double punchOutLong = currentPosition.longitude;

    if (punchInData != null) {
      if (entryInAttendance) {
        // Case 1: Entry found in attendance table
        locationIn = 'Office';

        // Case 1a: Mark-out inside office
        setState(() {
          _inTime = punchInData['in_time']; // Take inTime from attendance entry
          _outTime = DateFormat('HH:mm:ss').format(TimeService.appTime);
          _totalHours = _calculateTotalHours().inMinutes / 60; // Calculate totalHours
          if (_totalHours >= 8) {
            day = 'F';
          } else {
            day = 'H';
          }
          _isMarkOutEnabled = false; // Disable mark-out after pressing
        });

        final db = await LocalDatabaseService.database;
        await db.transaction((txn) async {
          await txn.update(
            'attendance',
            {
              'out_time': _outTime,
              'total_hours': _totalHours,
              'location_out': 'Office',
              'day': day,
              'punch_out_lat': punchOutLat,
              'punch_out_long': punchOutLong,
              'synced': 0, // Mark as unsynced
            },
            where: 'emp_id = ? AND date = ?',
            whereArgs: [emp_id, _currentDate],
          );
        });
      } else {
        // Case 2: Entry found in regularization table
        locationIn = 'Outside Office';

        // Case 2a: Mark-out inside office
        setState(() {
          _inTime = punchInData['in_time'] ?? ''; // Take inTime from regularization entry
          _outTime = DateFormat('HH:mm:ss').format(TimeService.appTime);
          _totalHours = _calculateTotalHours().inMinutes / 60; // Calculate totalHours
          if (_totalHours >= 8) {
            day = 'F';
          } else {
            day = 'H';
          }
          _isMarkOutEnabled = false; // Disable mark-out after pressing
        });

        final db = await LocalDatabaseService.database;
        await db.transaction((txn) async {
          await txn.insert('attendance', {
            'emp_id': emp_id,
            'date': _currentDate,
            'in_time': _inTime,
            'out_time': _outTime,
            'total_hours': _totalHours,
            'day': day,
            'location_in': 'Outside Office',
            'location_out': 'Office',
            'punch_in_lat': punchInData['punch_in_lat'],
            'punch_in_long': punchInData['punch_in_long'],
            'punch_out_lat': punchOutLat,
            'punch_out_long': punchOutLong,
            'synced': 0, // Mark as unsynced
          });
        });
      }
    }
    await cancelPunchOutReminder();

    // Try syncing if connected to the internet
    await _syncAttendanceData();
    await _syncRegularizationData();
  } catch (e) {
    print('Error in _markOut: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('An unexpected error occurred. Please try again.')),
    );
  }
}

  // Show confirmation dialog
  Future<bool> _showConfirmationDialog(String action) async {
  return await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Confirm $action'),
      content: Text('Do you want to mark attendance?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('Proceed'),
        ),
      ],
    ),
  ) ?? false;
}

  void _showSundayOrHolidayAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Not Allowed'),
        content: Text('Punching is not allowed on Sundays and holidays.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  // Show regularization alert
  Future<bool> _showRegularizationAlert(String action) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Regularization Required'),
        content: Text('You are outside the office. Do you want to proceed with $action?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Proceed'),
          ),
        ],
      ),
    ) ?? false;
  }

  // Calculate total hours worked between in-time and out-time
  Duration _calculateTotalHours() {
    DateTime inDateTime = DateFormat('HH:mm:ss').parse(_inTime);
    DateTime outDateTime = DateFormat('HH:mm:ss').parse(_outTime);
    return outDateTime.difference(inDateTime);
  }

  // Sync attendance data with the backend
  Future<void> _syncAttendanceData() async {
    try {
      // Check if device has internet connection
      final hasInternet = await _hasNetworkConnection();
      if (!hasInternet) return;

      // Get unsynced attendance data from local database
      List<Map<String, dynamic>> unsyncedAttendance = await LocalDatabaseService.getUnsyncedAttendance();

      // Sync each record with backend
      for (var attendance in unsyncedAttendance) {
        final payload = {
          'id': {
            'empId': attendance['emp_id'],
            'date': attendance['date'],
          },
          'inTime': attendance['in_time'],
          'outTime': attendance['out_time'],
          'totalHours': attendance['total_hours'],
          'location_in': attendance['location_in'],
          'location_out': attendance['location_out'],
          'day': attendance['day'],
          'punch_in_lat': attendance['punch_in_lat'],
          'punch_in_long': attendance['punch_in_long'],
          'punch_out_lat': attendance['punch_out_lat'],
          'punch_out_long': attendance['punch_out_long'],
        };

        // Log the payload before sending it to the backend
        print('Sending payload to backend: ${jsonEncode(payload)}');

        try {
          String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://default-url.com';
          final response = await http.post(
            Uri.parse('$baseUrl/api/attendance/sync'),
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode(payload),
          );

          // Log the response from the server
          print('Response from server: ${response.body}');

          if (response.statusCode == 200) {
            // Mark this attendance record as synced
            await LocalDatabaseService.markAttendanceAsSynced(attendance['emp_id'], attendance['date']);
          }
        } catch (e) {
          print('Error syncing data: $e');
        }
      }
    } catch (e) {
      print('Sync error: $e');
    }
  }

  Future<void> _syncRegularizationData() async {
    try {
      final hasInternet = await _hasNetworkConnection();
      if (!hasInternet) return;

      List<Map<String, dynamic>> unsyncedRegularization = await LocalDatabaseService.getUnsyncedRegularization();

      for (var record in unsyncedRegularization) {
        final payload = {
          'id': {
            'empId': record['emp_id'],
            'date': record['date'],
          },
          'inTime': record['in_time'],
          'outTime': record['out_time'],
          'totalHours': record['total_hours'],
          'location_in': record['location_in'],
          'location_out': record['location_out'],
          'day': record['day'],
          'punch_in_lat': record['punch_in_lat'],
          'punch_in_long': record['punch_in_long'],
          'punch_out_lat': record['punch_out_lat'],
          'punch_out_long': record['punch_out_long'],
          'approval': record['approval'],
          'approvedBy': record['approved_by'],
        };

        // Log the payload before sending it to the backend
        print('Sending payload to backend: ${jsonEncode(payload)}');

        try {
          String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://default-url.com';
          final response = await http.post(
            Uri.parse('$baseUrl/api/regularization/sync'),
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode(payload),
          );

          if (response.statusCode == 200) {
            await LocalDatabaseService.markRegularizationAsSynced(record['emp_id'], record['date']);
          }
        } catch (e) {
          print('Error syncing regularization: $e');
        }
      }
    } catch (e) {
      print('Sync error: $e');
    }
  }

//   Future<void> _showAddLocationDialog() async {
//   final latController = TextEditingController();
//   final lngController = TextEditingController();

//   return showDialog(
//     context: context,
//     builder: (context) {
//       return AlertDialog(
//         title: Text('Add location coordinates for office'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             TextField(
//               controller: latController,
//               decoration: InputDecoration(
//                 labelText: 'Latitude',
//                 hintText: 'Enter latitude',
//               ),
//               keyboardType: TextInputType.numberWithOptions(decimal: true),
//             ),
//             TextField(
//               controller: lngController,
//               decoration: InputDecoration(
//                 labelText: 'Longitude',
//                 hintText: 'Enter longitude',
//               ),
//               keyboardType: TextInputType.numberWithOptions(decimal: true),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () async {
//               if (latController.text.isEmpty || lngController.text.isEmpty) {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(content: Text('Please enter both latitude and longitude')),
//                 );
//                 return;
//               }

//               try {
//                 final lat = double.parse(latController.text);
//                 final lng = double.parse(lngController.text);
//                 await _submitLocationCoordinates(lat, lng);
//                 Navigator.pop(context);
//               } catch (e) {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(content: Text('Invalid coordinates. Please enter valid numbers')),
//                 );
//               }
//             },
//             child: Text('Submit'),
//           ),
//         ],
//       );
//     },
//   );
// }

Future<void> _showAddLocationDialog() async {
  final latController = TextEditingController();
  final lngController = TextEditingController();
  final nameController = TextEditingController();

  return showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('Add location coordinates for office'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Location Name',
                hintText: 'Enter location name',
              ),
            ),
            TextField(
              controller: latController,
              decoration: InputDecoration(
                labelText: 'Latitude',
                hintText: 'Enter latitude',
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            TextField(
              controller: lngController,
              decoration: InputDecoration(
                labelText: 'Longitude',
                hintText: 'Enter longitude',
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (latController.text.isEmpty || 
                  lngController.text.isEmpty || 
                  nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please enter all fields')),
                );
                return;
              }

              try {
                final lat = double.parse(latController.text);
                final lng = double.parse(lngController.text);
                final name = nameController.text;
                await _submitLocationCoordinates(lat, lng, name);
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Invalid coordinates. Please enter valid numbers')),
                );
              }
            },
            child: Text('Submit'),
          ),
        ],
      );
    },
  );
}

// Future<void> _submitLocationCoordinates(double latitude, double longitude) async {
//   setState(() {
//     _isLoading = true;
//   });

//   try {
//     String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://default-url.com';
//     final response = await http.post(
//       Uri.parse('$baseUrl/api/locations/office-coordinates'),
//       headers: {'Content-Type': 'application/json'},
//       body: jsonEncode({
//         'latitude': latitude,
//         'longitude': longitude,
//         'empId': emp_id,
//       }),
//     );

//     if (response.statusCode == 200) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('New office location added successfully')),
//       );
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error adding new location: ${response.body}')),
//       );
//     }
//   } catch (e) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Failed to connect to server: $e')),
//     );
//   } finally {
//     setState(() {
//       _isLoading = false;
//     });
//   }
// }

Future<void> _submitLocationCoordinates(double latitude, double longitude, String locationName) async {
  setState(() {
    _isLoading = true;
  });

  try {
    String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://default-url.com';
    final response = await http.post(
      Uri.parse('$baseUrl/api/locations/office-coordinates'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
        'locationName': locationName,
        'empId': emp_id,
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('New office location added successfully')),
      );
      // Refresh the locations list after adding a new one
      _fetchLocations();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding new location: ${response.body}')),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to connect to server: $e')),
    );
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

List<Map<String, dynamic>> _locations = [];

Future<void> _fetchLocations() async {
  setState(() {
    _isLoading = true;
  });

  try {
    String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://default-url.com';
    final response = await http.get(
      Uri.parse('$baseUrl/api/locations/office-coordinates'),
    );

    if (response.statusCode == 200) {
      setState(() {
        _locations = List<Map<String, dynamic>>.from(jsonDecode(response.body));
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch locations')),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to connect to server: $e')),
    );
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

Future<void> _deleteLocation(String locationId) async {
  setState(() {
    _isLoading = true;
  });

  try {
    String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://default-url.com';
    final response = await http.post(
      Uri.parse('$baseUrl/api/locations/delete/$locationId'),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location deleted successfully')),
      );
      // Refresh the locations list after deletion
      await _fetchLocations();
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting location: ${response.body}')),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to connect to server: $e')),
    );
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

// Future<void> _showLocationsList() async {
//   await _fetchLocations(); // Refresh the list before showing

//   return showDialog(
//     context: context,
//     builder: (context) {
//       return AlertDialog(
//         title: Text('Office Locations'),
//         content: Container(
//           width: double.maxFinite,
//           child: ListView.builder(
//             shrinkWrap: true,
//             itemCount: _locations.length,
//             itemBuilder: (context, index) {
//               final location = _locations[index];
//               return ListTile(
//                 title: Text(location['locationName'] ?? 'Unnamed Location'),
//                 subtitle: Text(
//                   'Lat: ${location['latitude']}, Lng: ${location['longitude']}',
//                 ),
//                 trailing: IconButton(
//                   icon: Icon(Icons.delete, color: Colors.red),
//                  onPressed: () async {
//                               await _deleteLocation(location['id'].toString());
//                  }
//                 ),
//               );
//             },
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Close'),
//           ),
//         ],
//       );
//     },
//   );
// }

Future<void> _showLocationsList() async {
  await _fetchLocations();

  return showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('Office Locations'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _locations.length,
            itemBuilder: (context, index) {
              final location = _locations[index];
              return ListTile(
                title: Text(location['locationName'] ?? 'Unnamed Location'),
                subtitle: Text(
                  'Lat: ${location['latitude']}, Lng: ${location['longitude']}',
                ),
                trailing: _isAdmin ? IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    await _deleteLocation(location['id'].toString());
                  },
                ) : null,
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      );
    },
  );
}

Future<void> _checkAdminStatus() async {
  if (emp_id.isEmpty) {
    print('Employee ID is empty');
    return;
  }

  setState(() {
    _isLoading = true;
  });

  try {
    String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://default-url.com';
    final uri = Uri.parse('$baseUrl/api/locations/getadmin').replace(
      queryParameters: {'empId': emp_id},
    );

    print('Checking admin status with URL: ${uri.toString()}'); // Debug print

    final response = await http.get(
      uri,
      headers: {'Content-Type': 'application/json'},
    ).timeout(Duration(seconds: 10));

    print('Admin status response: ${response.statusCode}, ${response.body}'); // Debug print

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);
      if (result is Map<String, dynamic> && result.containsKey('isAdmin')) {
        setState(() {
          _isAdmin = result['isAdmin'] as bool;
        });
      } else {
        print('Invalid admin status response format');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid admin status response format')),
        );
      }
    } else {
      print('Failed to check admin status: ${response.statusCode}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to check admin status: ${response.statusCode}')),
      );
    }
  } on TimeoutException catch (e) {
    print('Admin status check timeout: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Request timeout. Please try again')),
    );
  } catch (e) {
    print('Error checking admin status: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error checking admin status: $e')),
    );
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

  // Check for internet connection
  Future<bool> _hasNetworkConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

@override
Widget build(BuildContext context) {
  bool isSundayOrHoliday = _isSundayOrHoliday(TimeService.appTime);
  final bottomPadding = MediaQuery.of(context).padding.bottom; // Get system bottom padding
  double barHeight = 60;
  double barWidth = MediaQuery.of(context).size.width;
  double tabWidth = barWidth / 2;

  return Scaffold(
    resizeToAvoidBottomInset: false,
    backgroundColor: Colors.black, // Set scaffold background to black
    body: Stack(
      children: [
        // Black background layer
        Container(color: Colors.black),
        
        // Background Image covering entire screen
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/background.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),

        Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 45.0),
                  child: Column(
                    children: [
                      // Header (Lowered a bit)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            // PopupMenuButton<String>(
                            //   onSelected: (String value) async {
                            //     if (value == 'logout') {
                            //       final prefs = await SharedPreferences.getInstance();
                            //       await prefs.setBool('isLoggedIn', false);
                            //       await prefs.remove('empId');
                            //       await prefs.remove('role');
                            //       Navigator.pushReplacement(
                            //         context,
                            //         MaterialPageRoute(
                            //           builder: (context) => LoginScreen(),
                            //         ),
                            //       );
                            //     }
                            //   },
                            //   itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                            //     const PopupMenuItem<String>(
                            //       value: 'logout',
                            //       child: Text('Logout'),
                            //     ),
                            //   ],
                            //   child: CircleAvatar(
                            //     backgroundColor: Colors.grey[800],
                            //     radius: 24,
                            //     child: Icon(
                            //       Icons.person,
                            //       color: Colors.white,
                            //     ),
                            //   ),
                            // ),
                            // SizedBox(width: 16),
                            PopupMenuButton<String>(
                              onSelected: (String value) async {
                                if (value == 'logout') {
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setBool('isLoggedIn', false);
                                  await prefs.remove('empId');
                                  await prefs.remove('role');
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => LoginScreen(),
                                    ),
                                  );
                                } else if (value == 'profile') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ProfileScreen(empId: widget.empId),
                                    ),
                                  );
                                }
                              },
                              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                const PopupMenuItem<String>(
                                  value: 'profile',
                                  child: Text('Profile'),
                                ),
                                const PopupMenuItem<String>(
                                  value: 'logout',
                                  child: Text('Logout'),
                                ),
                              ],
                              child: CircleAvatar(
                                backgroundColor: Colors.grey[800],
                                radius: 24,
                                child: Icon(
                                  Icons.person,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'HEY ${_userDetails['firstName']}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFB84542),
                                  ),
                                ),
                                Text(
                                  _userDetails['email']!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFB84542),
                                  ),
                                ),
                              ],
                            ),
                            Spacer(),
                            IconButton(
                              icon: Icon(Icons.local_hospital, size: 24, color: Color(0xFFB84542)),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MediclaimScreen(empId: emp_id),
                                  ),
                                );
                              },
                            ),
    //                         IconButton(
    //   icon: Icon(Icons.add, size: 24, color: Color(0xFFB84542)),
    //   onPressed: _showAddLocationDialog,
    // ),
   if(_isAdmin) IconButton(
  icon: Icon(Icons.add, size: 24, color: Color(0xFFB84542)),
  onPressed: () {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  'Location Options',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB84542),
                  ),
                ),
              ),
              SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(0xFFB84542).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.add_location, color: Color(0xFFB84542)),
                ),
                title: Text('Add New Location'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddLocationDialog();
                },
              ),
              Divider(indent: 16, endIndent: 16),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(0xFFB84542).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.list, color: Color(0xFFB84542)),
                ),
                title: Text('View Locations'),
                onTap: () {
                  Navigator.pop(context);
                  _showLocationsList();
                },
              ),
              SizedBox(height: 16),
              TextButton(
                child: Text(
                  'CLOSE',
                  style: TextStyle(
                    color: Color(0xFFB84542),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  },
),
                            IconButton(
                              icon: Icon(Icons.refresh, size: 24, color: Color(0xFFB84542)),
                              onPressed: _refreshLocation,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 40),

                      // Main Content
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Current Time
                          Text(
                            DateFormat('hh:mm a').format(currentTime),
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFB84542),
                            ),
                          ),
                          SizedBox(height: 16),

                          // Date
                          Text(
                            _currentDate,
                            style: TextStyle(
                              fontSize: 18,
                              color: Color(0xFFB84542),
                            ),
                          ),
                          SizedBox(height: 16),

                          // Location
                          Text(
                            'LOCATION - $_location',
                            style: TextStyle(
                              fontSize: 18,
                              color: Color(0xFFB84542),
                            ),
                          ),
                          SizedBox(height: 32),

                          // Punch In/Out Button with PNG Images
                          GestureDetector(
                            onTap: isSundayOrHoliday
                                ? null
                                : (_isMarkInEnabled ? _markIn : _isMarkOutEnabled ? _markOut : null),
                            child: Container(
                              width: 180,
                              height: 180,
                              decoration: BoxDecoration(
                                color: isSundayOrHoliday
                                    ? Colors.grey
                                    : Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.2),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.asset(
                                      _isMarkInEnabled
                                          ? 'assets/images/presson.png'
                                          : 'assets/images/pressout.png',
                                      width: 60,
                                      height: 60,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      isSundayOrHoliday
                                          ? 'DISABLED'
                                          : (_isMarkInEnabled ? 'PUNCH IN' : _isMarkOutEnabled ? 'PUNCH OUT' : 'DISABLED'),
                                      style: TextStyle(
                                        color: isSundayOrHoliday
                                            ? Colors.black54
                                            : Colors.black,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 40),

                          // Punch In, Punch Out, and Total Hours in a Row
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                // Punch In with image above
                                Column(
                                  children: [
                                    Image.asset(
                                      'assets/images/punchin.png',
                                      width: 40,
                                      height: 40,
                                    ),
                                    SizedBox(height: 8),
                                    TimeDisplay(
                                      label: 'Punch In',
                                      time: _inTime.isNotEmpty ? _inTime : '--:--',
                                    ),
                                  ],
                                ),

                                // Punch Out with image above
                                Column(
                                  children: [
                                    Image.asset(
                                      'assets/images/punchout.png',
                                      width: 40,
                                      height: 40,
                                    ),
                                    SizedBox(height: 8),
                                    TimeDisplay(
                                      label: 'Punch Out',
                                      time: _outTime.isNotEmpty ? _outTime : '--:--',
                                    ),
                                  ],
                                ),

                                // Total Hours with image above
                                Column(
                                  children: [
                                    Image.asset(
                                      'assets/images/totalhours.png',
                                      width: 40,
                                      height: 40,
                                    ),
                                    SizedBox(height: 8),
                                    TimeDisplay(
                                      label: 'Total Hours',
                                      time: _totalHours.toStringAsFixed(2),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        // Loading Overlay
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.7),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/loading.gif',
                    width: 100,
                    height: 100,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Loading...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
    bottomNavigationBar: Padding(
      padding: EdgeInsets.only(bottom: bottomPadding), // Apply safe area padding
      child: Container(
        color: Colors.black,
        margin: EdgeInsets.only(bottom: 10),
        child: Container(
          height: barHeight,
          padding: EdgeInsets.symmetric(vertical: 10, horizontal: 24),
          decoration: BoxDecoration(
            color: Color(0xFFFF7043),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: Duration(milliseconds: 300),
                left: _selectedIndex == 0 ? 0 : tabWidth,
                top: 0,
                bottom: 0,
                child: Container(
                  width: tabWidth,
                  height: barHeight,
                  decoration: BoxDecoration(
                    color: Color(0xFFB84542).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _onItemTapped(0),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.home, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'HOME',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _onItemTapped(1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'HISTORY',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}

class TimeDisplay extends StatelessWidget {
  final String label;
  final String time;

  const TimeDisplay({super.key, required this.label, required this.time});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.access_time, size: 24),
        SizedBox(height: 8),
        Text(time, style: TextStyle(fontSize: 18, color: Color(0xFFB84542),)),
        Text(label, style: TextStyle(fontSize: 14, color: Color(0xFFB84542),)),
      ],
    );
  }
}