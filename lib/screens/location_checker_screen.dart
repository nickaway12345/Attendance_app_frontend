import 'dart:async'; // For StreamSubscription
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart'; // For formatting date and time
import 'package:http/http.dart' as http;
import 'package:location_checker/screens/history_screen.dart';
import 'package:location_checker/screens/login_screen.dart';
import 'dart:convert';
import 'package:location_checker/services/location_service.dart';
import 'package:location_checker/services/local_database_servie.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // To track internet connectivity

class LocationCheckerScreen extends StatefulWidget {
  final String empId;
  const LocationCheckerScreen({super.key, required this.empId});

  @override
  _LocationCheckerScreenState createState() => _LocationCheckerScreenState();
}

class _LocationCheckerScreenState extends State<LocationCheckerScreen> {
  int _selectedIndex = 0;
  DateTime currentTime = DateTime.now();
  String _statusMessage = 'Check your location';
  bool _isMarkInEnabled = false;
  bool _isMarkOutEnabled = false;
  String _inTime = '';
  String _outTime = '';
  String _location = 'Outside Office';
  String _day = 'H'; // Default to 'H' for half-day
  late String emp_id;
  String _currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  double _totalHours = 0.0;

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

  @override
  void initState() {
    super.initState();
    emp_id = widget.empId;
    _fetchHolidays();

    // Start the timer to update the current time every second
    _timer = Timer.periodic(Duration(seconds: 1), (Timer t) {
      _getCurrentTime();
    });

    // Check user location and existing entries
    _checkUserLocation();
    _checkExistingEntries();
    _fetchAttendanceData();

    // Declare _connectivitySubscription as StreamSubscription<List<ConnectivityResult>>
late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

// Monitor internet connectivity changes
_connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
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
      currentTime = DateTime.now();
    });
  }

    List<DateTime> _holidays = [];

Future<void> _fetchHolidays() async {
  String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://default-url.com';
  final response = await http.get(Uri.parse('$baseUrl:8000/holidays'));
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
    String result = await LocationService.checkUserProximity();
    setState(() {
      _statusMessage = result;
      _location = result == 'office' ? 'Office' : 'Outside Office';
    });
  }

  // Refresh Button Functionality
  void _refreshLocation() {
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
    // Check if today is Sunday
    if (_isSundayOrHoliday(DateTime.now())) {
       _showSundayOrHolidayAlert();
      return;
    }

    bool isInsideOffice = _location == 'Office';

    if (!isInsideOffice) {
      // Show alert for regularization
      bool confirm = await _showRegularizationAlert('mark-in');
      if (!confirm) return; // User canceled the action
    }

    setState(() {
      _inTime = DateFormat('HH:mm:ss').format(DateTime.now());
      _isMarkInEnabled = false; // Disable mark-in after pressing
      _isMarkOutEnabled = true; // Enable mark-out button
    });

    // Get current location coordinates
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    double latitude = position.latitude;
    double longitude = position.longitude;

    Map<String, dynamic> attendanceData = {
      'emp_id': emp_id,
      'date': _currentDate,
      'in_time': _inTime,
      'out_time': null,
      'total_hours': 0,
      'location_in': _location,
      'location_out': null,
      'day': 'H',
      'punch_in_lat': latitude,
      'punch_in_long': longitude,
      'punch_out_lat': null,
      'punch_out_long': null,
    };

    if (isInsideOffice) {
      // Save to attendance table
      await LocalDatabaseService.saveAttendanceLocally(attendanceData);
    } else {
      // Save to regularize table
      await LocalDatabaseService.saveRegularizationLocally({
        ...attendanceData,
        'approval': 'Pending',
        'approved_by': null,
      });
    }

    // Try syncing if connected to internet
    _syncAttendanceData();
    _syncRegularizationData();
  }

  Future<void> _markOut() async {
  // Check if today is Sunday
  if (_isSundayOrHoliday(DateTime.now())) {
    _showSundayOrHolidayAlert();
    return;
  }

  // Check if current location is inside the office
  bool isInsideOffice = _location == 'Office';

  // Fetch punch-in data (check if in attendance or regularization)
  Map<String, dynamic>? punchInData = await LocalDatabaseService.getPunchInDataForDate(emp_id, _currentDate);
  bool entryInAttendance = await LocalDatabaseService.isInAttendance(emp_id, _currentDate);
  String locationIn = 'Unknown';
  String day ='';

  if (punchInData != null) {
    if (entryInAttendance) {
      // Case 1: Entry found in attendance table
      locationIn = 'Office';

      if (isInsideOffice) {
        // Case 1a: Mark-out inside office
        setState(() {
          _inTime = punchInData['in_time']; // Take inTime from attendance entry
          _outTime = DateFormat('HH:mm:ss').format(DateTime.now());
          _totalHours = _calculateTotalHours().inMinutes / 60; // Calculate totalHours
          if(_totalHours >= 9) day='F';
          else day = 'H';
          _isMarkOutEnabled = false; // Disable mark-out after pressing
        });
        await LocalDatabaseService.saveAttendanceLocally({
          'emp_id': emp_id,
          'date': _currentDate,
          'in_time': _inTime,
          'out_time': _outTime,
          'total_hours': _totalHours,
          'location_in': locationIn,
          'location_out': 'Office', // Both locationIn and locationOut are 'Office'
          'day': day,
        });
      } else {
        // Case 1b: Mark-out outside office
        setState(() {
          _inTime = punchInData['in_time']; // Take inTime from attendance entry
          _outTime = DateFormat('HH:mm:ss').format(DateTime.now());
          _totalHours = _calculateTotalHours().inMinutes / 60; // Calculate totalHours
           if(_totalHours >= 9) day='F';
          else day = 'H';
          _isMarkOutEnabled = false; // Disable mark-out after pressing
        });
        await LocalDatabaseService.saveRegularizationLocally({
          'emp_id': emp_id,
          'date': _currentDate,
          'in_time': _inTime,
          'out_time': _outTime,
          'total_hours': _totalHours,
          'location_in': locationIn,
          'day': day,
          'location_out': 'Outside Office', // Mark-out location is outside office
          'approval': 'Pending',
          'approved_by': null,
        });
      }

    } else {
      // Case 2: Entry found in regularization table
      locationIn = 'Outside Office';

      if (isInsideOffice) {
        // Case 2a: Mark-out inside office
        setState(() {
          _inTime = ""; // Set inTime to null
          _outTime = DateFormat('HH:mm:ss').format(DateTime.now());
          _totalHours = 0; // Set totalHours to 0
           if(_totalHours >= 9) day='F';
          else day = 'H';
          _isMarkOutEnabled = false; // Disable mark-out after pressing
        });
        await LocalDatabaseService.saveAttendanceLocally({
          'emp_id': emp_id,
          'date': _currentDate,
          'in_time': _inTime,
          'out_time': _outTime,
          'total_hours': _totalHours,
          'day': day,
          'location_in': 'Outside Office', // Found in regularization
          'location_out': 'Office', // Mark-out is inside office
        });
      } else {
        // Case 2b: Mark-out outside office
        setState(() {
          _inTime = punchInData['in_time']; // Take inTime from regularization entry
          _outTime = DateFormat('HH:mm:ss').format(DateTime.now());
          _totalHours = _calculateTotalHours().inMinutes / 60; // Calculate totalHours
           if(_totalHours >= 9) day='F';
          else day = 'H';
          _isMarkOutEnabled = false; // Disable mark-out after pressing
        });
        await LocalDatabaseService.saveRegularizationLocally({
          'emp_id': emp_id,
          'date': _currentDate,
          'in_time': _inTime,
          'out_time': _outTime,
          'total_hours': _totalHours,
          'day': day,
          'location_in': 'Outside Office', // Both locationIn and locationOut are 'Outside Office'
          'location_out': 'Outside Office',
          'approval': 'Pending',
          'approved_by': null,
        });
      }
    }
  }

  // Try syncing if connected to the internet
  _syncAttendanceData();
  _syncRegularizationData();
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

  // Show Sunday alert
  void _showSundayAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sunday Alert'),
        content: Text('Punching is not allowed on Sundays.'),
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
            Uri.parse('$baseUrl:8000/api/attendance/sync'),
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
            Uri.parse('$baseUrl:8000/api/regularization/sync'),
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
    bool isSundayOrHoliday = _isSundayOrHoliday(DateTime.now());
    double barHeight = 60; // Height of the bottom bar and sliding box
    double barWidth = MediaQuery.of(context).size.width;
    double tabWidth = barWidth / 2;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
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
                             PopupMenuButton<String>(
  onSelected: (String value) {
    if (value == 'logout') {
      // Navigate to LoginScreen when logout is selected
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LoginScreen(),
        ),
      );
    }
  },
  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
    const PopupMenuItem<String>(
      value: 'logout',
      child: Text('Logout'),
    ),
  ],
  child: CircleAvatar(
    backgroundColor: Colors.grey[800],
    radius: 24,
  ),
),
                              SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'HEY NIKHIL', // Replace with dynamic name if available
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFB84542),
                                    ),
                                  ),
                                  Text(
                                    emp_id,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFB84542),
                                    ),
                                  ),
                                ],
                              ),
                              Spacer(),
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

                    GestureDetector(
  onTap: _isSundayOrHoliday(DateTime.now()) // Check if today is Sunday or a holiday
      ? null // Disable onTap if it's Sunday or a holiday
      : (_isMarkInEnabled ? _markIn : _isMarkOutEnabled ? _markOut : null), // Enable onTap otherwise
  child: Container(
    width: 180,
    height: 180,
    decoration: BoxDecoration(
      color: _isSundayOrHoliday(DateTime.now()) // Change color if it's Sunday or a holiday
          ? Colors.grey // Grey color for disabled state
          : Colors.white, // White color for enabled state
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
      child: Text(
        _isSundayOrHoliday(DateTime.now()) // Check if today is Sunday or a holiday
            ? 'DISABLED' // Show "DISABLED" if it's Sunday or a holiday
            : (_isMarkInEnabled ? 'PUNCH IN' : _isMarkOutEnabled ? 'PUNCH OUT' : 'DISABLED'), // Otherwise, show appropriate text
        style: TextStyle(
          color: _isSundayOrHoliday(DateTime.now()) // Change text color if it's Sunday or a holiday
              ? Colors.black54 // Greyish color for disabled state
              : Colors.black, // Black color for enabled state
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  ),
),
                            SizedBox(height: 40), // Reduced space between punch button and icons

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
                                        'assets/images/punchin.png', // Update with correct asset path
                                        width: 40,
                                        height: 40,
                                      ),
                                      SizedBox(height: 8), // Reduced space between image and text
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
                                        'assets/images/punchout.png', // Update with correct asset path
                                        width: 40,
                                        height: 40,
                                      ),
                                      SizedBox(height: 8), // Reduced space between image and text
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
                                        'assets/images/totalhours.png', // Update with correct asset path
                                        width: 40,
                                        height: 40,
                                      ),
                                      SizedBox(height: 8), // Reduced space between image and text
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
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.black, // Outer container with black margin effect
        margin: EdgeInsets.only(bottom: 10), // This creates the margin
        child: Container(
          height: barHeight,
          padding: EdgeInsets.symmetric(vertical: 10, horizontal: 24),
          decoration: BoxDecoration(
            color: Color(0xFFFF7043), // Actual bottom bar color
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
              // Sliding box (darker shade)
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
              // Tab items (Home and History)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Home Tab
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
                  // History Tab
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
    );
  }
}

class TimeDisplay extends StatelessWidget {
  final String label;
  final String time;

  const TimeDisplay({Key? key, required this.label, required this.time}) : super(key: key);

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