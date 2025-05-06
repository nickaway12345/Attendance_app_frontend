import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:location_checker/services/local_database_servie.dart';
// For SQL database
import 'dart:io';
import 'package:http/http.dart' as http;

class LocationService {
  final double longitude = double.tryParse(dotenv.env['STATIC_LONG'] ?? '') ?? 20.0360637;
  final double latitude = double.tryParse(dotenv.env['STATIC_LAT'] ?? '') ?? 73.7945010;
  
  final LatLng hardcodedLocation;
  final String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://default-url.com';

  LocationService() : hardcodedLocation = LatLng(
    double.tryParse(dotenv.env['STATIC_LAT'] ?? '') ?? 73.7945010,
    double.tryParse(dotenv.env['STATIC_LONG'] ?? '') ?? 20.0360637
  );

  static const double _radiusInYards = 27.3;
  static final double _radiusInMeters = _radiusInYards * 0.9144;

  Future<List<LatLng>> _getOfficeLocations() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/locations/office-coordinates'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        // Convert API response to list of LatLng
        return data.map((coord) => LatLng(
          coord['latitude'] as double, 
          coord['longitude'] as double
        )).toList();
      }
      // If API fails, fall back to the hardcoded location
      return [hardcodedLocation];
    } catch (e) {
      // If any error occurs, fall back to the hardcoded location
      return [hardcodedLocation];
    }
  }

  static Future<String> checkUserProximity() async {
    try {
      LocationService locationService = LocationService();
      List<LatLng> officeLocations = await locationService._getOfficeLocations();
      
      // Debug print office locations
      print('Office locations to check against:');
      for (var loc in officeLocations) {
        print('${loc.latitude}, ${loc.longitude}');
      }

      // Check location services
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return 'Location services are disabled.';
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return 'Location permissions are denied.';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return 'Location permissions are permanently denied.';
      }

      // Get current position
      Position? position = await Geolocator.getLastKnownPosition();
      position ??= await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.best,
          ),
        );

      LatLng userLocation = LatLng(position.latitude, position.longitude);
      print('User location: ${userLocation.latitude}, ${userLocation.longitude}');

      final Distance distance = Distance();
      
      // Check against all office locations
      for (LatLng officeLocation in officeLocations) {
        double distanceInMeters = distance(officeLocation, userLocation);
        print('Distance to office (${officeLocation.latitude}, ${officeLocation.longitude}): $distanceInMeters meters');
        
        if (distanceInMeters <= _radiusInMeters) {
          print('User is within office radius');
          return 'office';
        }
      }

      print('User is outside all office locations');
      return 'outside';
    } catch (e) {
      print('Error in checkUserProximity: $e');
      return 'Error: $e';
    }
  }
}

class AttendanceForm extends StatefulWidget {
  const AttendanceForm({super.key});

  @override
  _AttendanceFormState createState() => _AttendanceFormState();
}

class _AttendanceFormState extends State<AttendanceForm> {
  String empId = '111'; // Fixed emp_id
  String currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now()); // Today's date
  String? inTime;
  String? outTime;
  double? totalTime;
  String locationStatus = 'outside';
  String workDay = '';
  bool isMarkInEnabled = false;
  bool isMarkOutEnabled = false;

  @override
  void initState() {
    super.initState();
    checkLocationForMarkIn();
  }

  void checkLocationForMarkIn() async {
    String status = await LocationService.checkUserProximity();
    setState(() {
      locationStatus = status;
      isMarkInEnabled = status == 'office';
    });
  }

  void checkLocationForMarkOut() async {
    String status = await LocationService.checkUserProximity();
    setState(() {
      locationStatus = status;
      isMarkOutEnabled = (status == 'office' && inTime != null);
    });
  }



Future<void> markIn() async {
  setState(() {
    inTime = DateFormat('HH:mm:ss').format(DateTime.now());
    isMarkOutEnabled = true;
  });

  // Get current location coordinates
  Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  double latitude = position.latitude;
  double longitude = position.longitude;

  Map<String, dynamic> attendanceData = {
    'emp_id': empId,
    'date': currentDate,
    'in_time': inTime,
    'out_time': null,
    'total_hours': null,
    'location': locationStatus,
    'day': null,
    'latitude': latitude,
    'longitude': longitude
  };

  // Save locally to SQLite
  await LocalDatabaseService.saveAttendanceLocally(attendanceData);

  // Try syncing if connected to internet
  syncAttendanceData();
}

Future<void> markOut() async {
  setState(() {
    outTime = DateFormat('HH:mm:ss').format(DateTime.now());
    calculateTotalTime();
  });

  // Get current location coordinates
  Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  double latitude = position.latitude;
  double longitude = position.longitude;

  Map<String, dynamic> attendanceData = {
    'emp_id': empId,
    'date': currentDate,
    'in_time': inTime,
    'out_time': outTime,
    'total_hours': totalTime,
    'location': locationStatus,
    'day': workDay,
    'latitude': latitude,
    'longitude': longitude
  };

  // Save locally to SQLite
  await LocalDatabaseService.saveAttendanceLocally(attendanceData);

  // Try syncing if connected to internet
  syncAttendanceData();
}

Future<void> syncAttendanceData() async {
  try {
    // Check if device has internet connection
    final hasInternet = await hasNetworkConnection();
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
        'location': attendance['location'],
        'day': attendance['day'],
        'latitude': attendance['latitude'],
        'longitude': attendance['longitude'],
      };

      try {
        String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://default-url.com';
        final response = await http.post(
          Uri.parse('$baseUrl/api/attendance/sync'),
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode(payload),
        );

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

// Check for internet connection
Future<bool> hasNetworkConnection() async {
  try {
    final result = await InternetAddress.lookup('example.com');
    return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
  } on SocketException catch (_) {
    return false;
  }
}


  void calculateTotalTime() {
    if (inTime != null && outTime != null) {
      DateTime inDateTime = DateFormat('HH:mm:ss').parse(inTime!);
      DateTime outDateTime = DateFormat('HH:mm:ss').parse(outTime!);
      totalTime = outDateTime.difference(inDateTime).inHours.toDouble();
      workDay = totalTime! >= 8 ? 'F' : 'H';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Attendance Tracker')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Emp ID: $empId'),
            Text('Date: $currentDate'),
            Text('In Time: ${inTime ?? '-'}'),
            Text('Out Time: ${outTime ?? '-'}'),
            Text('Total Time: ${totalTime != null ? totalTime!.toStringAsFixed(2) : '-'} hrs'),
            Text('Location: $locationStatus'),
            Text('Work Day: $workDay'),
            Row(
              children: [
                ElevatedButton(
                  onPressed: isMarkInEnabled ? markIn : null,
                  child: Text('Mark In'),
                ),
                SizedBox(width: 16),
                ElevatedButton(
                  onPressed: isMarkOutEnabled ? markOut : null,
                  child: Text('Mark Out'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

