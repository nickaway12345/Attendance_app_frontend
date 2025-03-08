import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:worldtime/worldtime.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TimeService {
  static DateTime _appTime = DateTime.now(); // App's internal clock
  static Timer? _clockTimer; // Timer for the app's clock
  static Timer? _syncTimer; // Timer for hourly sync
  static bool _isLocationPermissionGranted = false;
  static bool _isFallbackTime = false;

  // Initialize the app's clock
  static Future<void> initialize() async {
    // Fetch the initial time from WorldTime
    await fetchAndSetAppTime();

    // Start the app's internal clock
    startAppClock();

    // Start the hourly sync timer
    startHourlySync();
  }

  // Fetch time from WorldTime and set the app's internal clock
  static Future<void> fetchAndSetAppTime() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled. Please enable them.');
      }

      // Get user's location
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // Fetch time for the user's location
      final _worldtimePlugin = Worldtime();
      DateTime userTime = await _worldtimePlugin.timeByLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      // Set the app's internal clock
      setAppTime(userTime);

      // Save the fetched time to local storage
      await _saveTimeToLocalStorage(userTime);
    } catch (e) {
      print('Error fetching time: $e');
      // Fallback to fetching time using a default timezone (e.g., UTC)
      DateTime fallbackTime = await getTimeForTimezone('Asia/Kolkata');
      setAppTime(fallbackTime);

      // Save the fallback time to local storage
      await _saveTimeToLocalStorage(fallbackTime);
    }
  }

  // Fetch time for a specific timezone
  static Future<DateTime> getTimeForTimezone(String timezone) async {
    final _worldtimePlugin = Worldtime();
    return await _worldtimePlugin.timeByCity(timezone);
  }

  // Set the app's internal clock
  static void setAppTime(DateTime newTime) {
    _appTime = newTime;
  }

  // Start the app's internal clock
  static void startAppClock() {
    _clockTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      _appTime = _appTime.add(Duration(seconds: 1)); // Increment app time by 1 second
    });
  }

  // Start the hourly sync timer
  static void startHourlySync() {
    _syncTimer = Timer.periodic(Duration(hours: 1), (timer) async {
      await fetchAndSetAppTime(); // Sync with WorldTime every hour
    });
  }

  // Save the fetched time to local storage
  static Future<void> _saveTimeToLocalStorage(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastFetchedTime', time.toIso8601String());
  }

  // Load the last fetched time from local storage
  static Future<void> loadTimeFromLocalStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final lastFetchedTime = prefs.getString('lastFetchedTime');
    if (lastFetchedTime != null) {
      _appTime = DateTime.parse(lastFetchedTime);
    }
  }

  // Get the current app time
  static DateTime get appTime => _appTime;

  // Check if location permission is granted
  static bool get isLocationPermissionGranted => _isLocationPermissionGranted;

  // Check if fallback time is being used
  static bool get isFallbackTime => _isFallbackTime;

  // Dispose timers
  static void dispose() {
    _clockTimer?.cancel();
    _syncTimer?.cancel();
  }
}