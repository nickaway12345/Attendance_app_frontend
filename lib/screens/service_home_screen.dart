import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:location_checker/screens/login_screen.dart';
import 'package:location_checker/screens/service_history_screen.dart';
import 'package:location_checker/services/LocationSitesService.dart';
import 'package:location_checker/services/fetchAndSetTime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; // For date and time formatting
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // Import connectivity_plus
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:location_checker/services/local_database_servie.dart'; // Import LocalDatabaseService

class ServiceHomePage extends StatefulWidget {
  final String empId;

  // Constructor to accept empId
  ServiceHomePage({
    required this.empId,
  });

  @override
  _ServiceHomePageState createState() => _ServiceHomePageState();
}

class _ServiceHomePageState extends State<ServiceHomePage> {
  Map<String, String> _userDetails = {}; // Store user details
  DateTime currentTime = TimeService.appTime; // Current time
  String _currentDate = ''; // Current date
  String _location = 'Unknown'; // Location placeholder
  List<Map<String, dynamic>> _shiftTimings = []; // Shift timings for the user
  bool _isPunchInEnabled = false; // Enable/disable punch-in
  bool _isPunchOutEnabled = false; // Enable/disable punch-out
  bool _isPunchInPressed = false; // Track if punch-in has been pressed
  Timer? _timer; // Timer for updating time and shift logic
  String _userSite = 'Unknown Site'; // User's site
  Timer? _syncTimer; // Timer for syncing data
  String _punchInDate = ''; // Store the date of the punch-in
  int _currentShiftNumber = 1; // Default to shift 1
  int _selectedIndex = 0; 

  // Declare _connectivitySubscription as StreamSubscription<List<ConnectivityResult>>
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _fetchUserDetails(); // Fetch user details when the page loads
    _fetchUserSite();
    _updateTimeAndDate(); // Initialize time and date
    _startTimer(); // Start the timer for periodic updates
    _checkUserLocation(); // Check user location on init
    _startSyncTimer();
    _syncAttendanceData(); // Start the sync timer

    // Monitor internet connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      for (var result in results) {
        if (result == ConnectivityResult.mobile || result == ConnectivityResult.wifi) {
          // Trigger sync when connectivity is regained
          _syncAttendanceData();
          break; // Exit loop once connectivity is regained
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancel the timer when the widget is disposed
    _syncTimer?.cancel(); // Cancel the sync timer
    _connectivitySubscription.cancel(); // Cancel the connectivity subscription
    super.dispose();
  }

  // Fetch user details from SharedPreferences
  Future<void> _fetchUserDetails() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userDetails = {
        'firstName': prefs.getString('firstName') ?? 'User',
        'email': prefs.getString('email') ?? 'No email',
      };
    });
  }

  void _refreshLocation() async {
    print("Refresh pressed");
    await _fetchUserSite(); // Fetch the user site first
    await _checkUserLocation();
    _syncAttendanceData(); // Recheck the location
  }

 double _calculateTotalHours(String inTime, String outTime) {
  DateTime inDateTime = DateFormat('HH:mm:ss').parse(inTime);
  DateTime outDateTime = DateFormat('HH:mm:ss').parse(outTime);
  Duration duration = outDateTime.difference(inDateTime);
  return duration.inMinutes / 60.0; // Convert minutes to hours as a double
}

  // Fetch shift timings and user site from the backend
  Future<void> _fetchShiftTimings() async {
    try {
      final data = await fetchUserSiteAndShiftTimings(widget.empId);
      setState(() {
        _shiftTimings = data['shiftTimings'];
        // _userSite = data['site'] ?? 'Unknown Site'; // Fetch user site
      });
      print('Fetched shift timings: $_shiftTimings'); // Debug log
      _updatePunchInOutState(); // Update punch-in/out state after fetching shifts
    } catch (e) {
      print('Error fetching shift timings: $e');
    }
  }

  // Fetch user site and shift timings from the backend
  Future<Map<String, dynamic>> fetchUserSiteAndShiftTimings(String empId) async {
    String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://default-url.com';
    final response = await http.get(
      Uri.parse('$baseUrl/api/shifts/$empId?date=${DateFormat('yyyy-MM-dd').format(TimeService.appTime)}'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> shiftTimingsData = jsonDecode(response.body);

      // Extract site (assuming it's the same for all shifts)
      // final String site = shiftTimingsData.isNotEmpty ? shiftTimingsData[0]['site'] : 'Unknown Site';

      // Extract shift timings
      final List<Map<String, dynamic>> shiftTimings = shiftTimingsData.map((shift) {
        return {
          'startTime': shift['startTime'],
          'endTime': shift['endTime'],
          'shiftNumber': shift['shiftNumber'], // Include shift number
        };
      }).toList();

      return {
        'site': _userSite,
        'shiftTimings': shiftTimings,
      };
    } else {
      throw Exception('Failed to load shift timings');
    }
  }

  // Update time and date periodically
  void _updateTimeAndDate() {
    setState(() {
      currentTime = TimeService.appTime;
      _currentDate = DateFormat('MMMM dd, yyyy').format(currentTime);
    });
  }

  // Start a timer to update time and shift logic every minute
  void _startTimer() {
    _timer = Timer.periodic(Duration(minutes: 1), (Timer t) {
      _updateTimeAndDate();
      _updatePunchInOutState();
    });
  }

  // Start a timer to sync data every 5-10 minutes
  void _startSyncTimer() {
    _syncTimer = Timer.periodic(Duration(minutes: 5), (Timer t) async {
      await _syncAttendanceData();
    });
  }

  // Check if shifts are continuous
  bool _areShiftsContinuous(List<Map<String, dynamic>> shifts) {
    if (shifts.length < 2) return false;

    for (int i = 1; i < shifts.length; i++) {
      final previousShiftEnd = DateTime.parse(shifts[i - 1]['endTime']);
      final currentShiftStart = DateTime.parse(shifts[i]['startTime']);

      if (currentShiftStart.isAfter(previousShiftEnd)) {
        return false;
      }
    }

    return true;
  }

  void _updatePunchInOutState() async {
  final now = TimeService.appTime;
  bool punchInEnabled = false;
  bool punchOutEnabled = false;

  // Sort shifts by start time
  _shiftTimings.sort((a, b) => DateTime.parse(a['startTime']).compareTo(DateTime.parse(b['startTime'])));

  // Determine the current shift number dynamically
  _currentShiftNumber = _getCurrentShiftNumber();
  print('Current shift number: $_currentShiftNumber'); // Debug log

  // Check if shifts are continuous
  bool areShiftsContinuous = _areShiftsContinuous(_shiftTimings);

  if (areShiftsContinuous) {
    // Handle continuous shifts
    final firstShiftStart = DateTime.parse(_shiftTimings.first['startTime']);
    final lastShiftEnd = DateTime.parse(_shiftTimings.last['endTime']);

    // Enable punch-in from one hour before the first shift starts until one hour after the last shift ends
    if (now.isAfter(firstShiftStart.subtract(Duration(hours: 1))) && now.isBefore(lastShiftEnd.add(Duration(hours: 1)))) {
      punchInEnabled = true;
    }

    // Enable punch-out if punch-in has been pressed and until one hour after the last shift ends
    if (_isPunchInPressed && now.isBefore(lastShiftEnd.add(Duration(hours: 1)))) {
      punchOutEnabled = true;
    }
  } else {
    // Handle alternate shifts
    for (var shift in _shiftTimings) {
      final shiftStart = DateTime.parse(shift['startTime']);
      final shiftEnd = DateTime.parse(shift['endTime']);
      final shiftNumber = shift['shiftNumber']; // Get shift number

      // Enable punch-in one hour before the shift starts and until one hour after the shift ends
      if (now.isAfter(shiftStart.subtract(Duration(hours: 1))) && now.isBefore(shiftEnd.add(Duration(hours: 1)))) {
        punchInEnabled = true;
      }

      // Enable punch-out if punch-in has been pressed and until one hour after the shift ends
      if (_isPunchInPressed && now.isBefore(shiftEnd.add(Duration(hours: 1)))) {
        punchOutEnabled = true;
      }
    }
  }

  // Check if punch-in or punch-out already exists for the current shift
  final hasPunchInForCurrentShift = await _hasPunchForCurrentShift(checkIn: true);
  final hasPunchOutForCurrentShift = await _hasPunchForCurrentShift(checkIn: false);

  // Debug logs
  print('Punch-in date: $_punchInDate'); // Debug log
  print('Has punch-in for current shift: $hasPunchInForCurrentShift');
  print('Has punch-out for current shift: $hasPunchOutForCurrentShift');

  // Disable punch-in if already punched in for the current shift
  if (hasPunchInForCurrentShift) {
    punchInEnabled = false;
  }

  // Disable punch-out if already punched out for the current shift
  if (hasPunchOutForCurrentShift) {
    punchOutEnabled = false;
  }

  // Disable punch-in if there are no further shifts and an entry already exists
  if (!areShiftsContinuous && hasPunchInForCurrentShift && hasPunchOutForCurrentShift) {
    punchInEnabled = false;
  }

  setState(() {
    _isPunchInEnabled = punchInEnabled;
    _isPunchOutEnabled = punchOutEnabled;
  });
}

int _getCurrentShiftNumber() {
  final now = TimeService.appTime;

  for (var shift in _shiftTimings) {
    final shiftStart = DateTime.parse(shift['startTime']);
    final shiftEnd = DateTime.parse(shift['endTime']);

    // Check if the current time falls within this shift
    if (now.isAfter(shiftStart.subtract(Duration(hours: 1))) && now.isBefore(shiftEnd.add(Duration(hours: 1)))) {
      return shift['shiftNumber']; // Return the shift number
    }
  }

  // If no shift is found, return the default shift number (e.g., 1)
  return 0;
}

  Future<bool> _hasPunchForCurrentShift({required bool checkIn}) async {
  final db = await LocalDatabaseService.database;
  final columnToCheck = checkIn ? 'in_time' : 'out_time';
  final currentDate = DateFormat('yyyy-MM-dd').format(TimeService.appTime);

  try {
    final result = await db.query(
      'attendance_service',
      where: 'emp_id = ? AND date = ? AND shift_number = ? AND $columnToCheck IS NOT NULL',
      whereArgs: [widget.empId, currentDate, _currentShiftNumber],
      orderBy: 'in_time DESC',
      limit: 1,
    );
    print('Punch query for empId: ${widget.empId}, date: $currentDate, shift: $_currentShiftNumber, result: $result');
    return result.isNotEmpty;
  } catch (e) {
    print('Error querying database: $e');
    return false;
  }
}

  // Fetch user site from the backend
  Future<String> fetchUserSite(String empId) async {
    String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://default-url.com';
    final response = await http.get(
      Uri.parse('$baseUrl/api/site-users/$empId'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['site'];
    } else {
      throw Exception('Failed to load user site');
    }
  }

  Future<void> _fetchUserSite() async {
    try {
      final site = await fetchUserSite(widget.empId);
      print('Fetched site: $site'); // Debug log
      setState(() {
        _userSite = site;
      });

      // After fetching the site, check the user's location
      await _checkUserLocation();

      // After checking the location, fetch the shift timings
      await _fetchShiftTimings();
    } catch (e) {
      print('Error fetching user site: $e');
      setState(() {
        _userSite = 'Unknown Site'; // Fallback to 'Unknown Site' if there's an error
      });
    }
  }

  // Check user location
  Future<void> _checkUserLocation() async {
    try {
      print('Checking user location...');
      print('User site: $_userSite'); // Debug log
      String result = await LocationSitesService.checkUserProximity(_userSite);
      setState(() {
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

  // Punch-in logic
  Future<void> _markIn() async {
  try {
    // Check if user is inside the office
    await _checkUserLocation();
    if (_location != 'Office') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You must be inside the office to punch in.')),
      );
      return;
    }

    // Fetch current location coordinates
    Position? position;
    try {
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

    // Store the punch-in date in the correct format (MMMM d, yyyy)
    setState(() {
      _punchInDate = DateFormat('yyyy-MM-dd').format(TimeService.appTime); // Use 'MMMM d, yyyy' format
    });

    // Prepare attendance data
    Map<String, dynamic> attendanceData = {
      'emp_id': widget.empId,
      'date': _punchInDate,
      'in_time': DateFormat('HH:mm:ss').format(TimeService.appTime),
      'out_time': null,
      'total_hours': 0,
      'location_in': _location,
      'location_out': null,
      'punch_in_lat': position.latitude,
      'punch_in_long': position.longitude,
      'punch_out_lat': null,
      'punch_out_long': null,
      'shift_number': _currentShiftNumber, // Include shift number
      'synced': 0, // Mark as unsynced
    };

    // Save attendance data locally
    await LocalDatabaseService.saveAttendanceServiceLocally(attendanceData);

    // Set punch-in pressed to true
    setState(() {
      _isPunchInPressed = true;
      _isPunchInEnabled = false; // Disable punch-in after pressing
      _isPunchOutEnabled = true; // Enable punch-out
    });

    // Add your punch-in logic here
    print('Punch-in clicked');
  } catch (e) {
    print('Error in _markIn: $e');
  }
}

  // Punch-out logic
  Future<void> _markOut() async {
  try {
    // Check if user is inside the office
    await _checkUserLocation();
    if (_location != 'Office') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You must be inside the office to punch out.')),
      );
      return;
    }

    // Fetch current location coordinates
    Position? position;
    try {
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

    // Fetch the punch-in record for the current employee, date, and shift
    final db = await LocalDatabaseService.database;
    final punchInRecord = await db.query(
      'attendance_service',
      where: 'emp_id = ? AND date = ? AND shift_number = ? AND in_time IS NOT NULL AND out_time IS NULL',
      whereArgs: [widget.empId, _punchInDate, _currentShiftNumber],
      orderBy: 'in_time DESC', // Fetch the most recent punch-in record
      limit: 1, // Limit to one record
    );

    if (punchInRecord.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No punch-in record found for today.')),
      );
      return;
    }

    // Get the punch-in time
    final inTimeStr = punchInRecord.first['in_time'] as String;
    final outTimeStr = DateFormat('HH:mm:ss').format(TimeService.appTime);

    // Calculate total hours worked as a double
    final double totalHours = _calculateTotalHours(inTimeStr, outTimeStr);

    // Prepare attendance data
    Map<String, dynamic> attendanceData = {
      'emp_id': widget.empId,
      'date': _punchInDate, // Use the punch-in date
      'in_time': inTimeStr, // Punch-in time from the record
      'out_time': outTimeStr,
      'total_hours': totalHours, // Calculated total hours as double
      'location_in': punchInRecord.first['location_in'], // Punch-in location from the record
      'location_out': _location,
      'punch_in_lat': punchInRecord.first['punch_in_lat'], // Punch-in coordinates from the record
      'punch_in_long': punchInRecord.first['punch_in_long'],
      'punch_out_lat': position.latitude,
      'punch_out_long': position.longitude,
      'shift_number': _currentShiftNumber, // Include shift number
      'synced': 0, // Mark as unsynced
    };

    // Save attendance data locally
    await LocalDatabaseService.saveAttendanceServiceLocally(attendanceData);

    // Set punch-in pressed to false
    setState(() {
      _isPunchInPressed = false;
      _isPunchOutEnabled = false; // Disable punch-out after pressing
    });

    // Add your punch-out logic here
    print('Punch-out clicked');
  } catch (e) {
    print('Error in _markOut: $e');
  }
}

  // Sync attendance data with the backend
  Future<void> _syncAttendanceData() async {
  try {
    // Check if device has internet connection
    final hasInternet = await _hasNetworkConnection();
    if (!hasInternet) return;

    // Get unsynced attendance data from local database
    List<Map<String, dynamic>> unsyncedAttendance = await LocalDatabaseService.getUnsyncedAttendanceService();

    // Sync each record with backend
    for (var attendance in unsyncedAttendance) {

      final payload = {
        'id': {
          'empId': attendance['emp_id'],
          'date': attendance['date'], // Use the formatted date
          'shift_number': attendance['shift_number'],
        },
        'inTime': attendance['in_time'],
        'outTime': attendance['out_time'],
        'totalHours': attendance['total_hours'].toDouble(),
        'location_in': attendance['location_in'],
        'location_out': attendance['location_out'],
        'punch_in_lat': attendance['punch_in_lat'],
        'punch_in_long': attendance['punch_in_long'],
        'punch_out_lat': attendance['punch_out_lat'],
        'punch_out_long': attendance['punch_out_long'],
      };

      // Print the payload for debugging
      print('Payload being sent to backend:');
      print(jsonEncode(payload));

      try {
        String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://default-url.com';
        final response = await http.post(
          Uri.parse('$baseUrl/api/attendance/service/sync'),
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode(payload),
        );

        if (response.statusCode == 200) {
          // Mark this attendance record as synced
          await LocalDatabaseService.markAttendanceServiceAsSynced(
            attendance['emp_id'],
            attendance['date'],
            attendance['shift_number'], // Include shift number
          );
        } else {
          print('Failed to sync data. Status code: ${response.statusCode}');
          print('Response body: ${response.body}');
        }
      } catch (e) {
        print('Error syncing data: $e');
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

  void _onItemTapped(int index) {
    if (index == 0) {
      // Navigate to LocationCheckerScreen (Home)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ServiceHomePage(empId: widget.empId)),
      );
    } else if (index == 1) {
      // Navigate to HistoryScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ServiceHistoryScreen(empId: widget.empId)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    double barHeight = 60; // Height of the bottom bar and sliding box
  double barWidth = MediaQuery.of(context).size.width;
  double tabWidth = barWidth / 2;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/background.png'),
                fit: BoxFit.cover,
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
                        // Header
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            children: [
                              PopupMenuButton<String>(
                                onSelected: (String value) async {
                                  if (value == 'logout') {
                                    // Clear the session data
                                    final prefs = await SharedPreferences.getInstance();
                                    await prefs.setBool('isLoggedIn', false);
                                    await prefs.remove('empId');
                                    await prefs.remove('role');

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
                                  child: Icon(
                                    Icons.person, // You can change this icon to something else if needed
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'HEY ${_userDetails['firstName']}', // Display the fetched first name
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFB84542),
                                    ),
                                  ),
                                  Text(
                                    _userDetails['email']!, // Display the fetched email
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFB84542),
                                    ),
                                  ),
                                  Text(
                                    'Site: $_userSite', // Display user site
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

                            // Punch In/Out Button
                            GestureDetector(
                              onTap: _isPunchInEnabled ? _markIn : _isPunchOutEnabled ? _markOut : null,
                              child: Container(
                                width: 180,
                                height: 180,
                                decoration: BoxDecoration(
                                  color: _isPunchInEnabled || _isPunchOutEnabled ? Colors.white : Colors.grey,
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
                                        _isPunchInEnabled
                                            ? 'assets/images/presson.png'
                                            : 'assets/images/pressout.png',
                                        width: 60,
                                        height: 60,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        _isPunchInEnabled ? 'PUNCH IN' : _isPunchOutEnabled ? 'PUNCH OUT' : 'DISABLED',
                                        style: TextStyle(
                                          color: _isPunchInEnabled || _isPunchOutEnabled ? Colors.black : Colors.black54,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
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