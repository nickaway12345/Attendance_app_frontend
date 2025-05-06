import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LocationSitesService {
  static const double _radiusInYards = 150.0;
  static final double _radiusInMeters = _radiusInYards * 0.9144;

  // Fetch site coordinates from the backend
static Future<LatLng?> fetchSiteCoordinates(String siteId) async {
  try {
    String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://default-url.com';
    final url = Uri.parse('$baseUrl/api/sites/$siteId/coordinates');

    // Print the payload (API request URL)
    print('Fetching site coordinates. Payload: GET $url');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return LatLng(data['latitude'], data['longitude']);
    } else {
      throw Exception('Failed to fetch site coordinates. Status code: ${response.statusCode}');
    }
  } catch (e) {
    print('Error fetching site coordinates: $e');
    return null;
  }
}

  // Check user proximity to a specific site
  static Future<String> checkUserProximity(String siteId) async {
    try {
      // Fetch site coordinates
      final LatLng? siteLocation = await fetchSiteCoordinates(siteId);
      if (siteLocation == null) {
        return 'Error: Could not fetch site coordinates.';
      }

      // Check location permissions
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return 'Location services are disabled.';
      }

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

      // Get current user location
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      LatLng userLocation = LatLng(position.latitude, position.longitude);

      // Calculate distance between user and site
      final Distance distance = Distance();
      double distanceInMeters = distance(siteLocation, userLocation);

      if (distanceInMeters <= _radiusInMeters) {
        return 'office';
      } else {
        return 'outside';
      }
    } catch (e) {
      return 'Error: $e';
    }
  }
}