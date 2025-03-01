import 'dart:convert'; // For JSON decoding
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http; // For loading assets

class LoginService {
  Future<Map<String, dynamic>?> validateCredentials(String username, String password) async {
    String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://default-url.com';
    final String apiUrl = '$baseUrl/auth/login'; // Replace with your actual backend URL

    try {
      // Prepare the request payload
      final Map<String, String> requestBody = {
        "username": username,
        "password": password,
      };

      // Print the request payload being sent to the backend
      print('Sending request to backend:');
      print('URL: $apiUrl');
      print('Body: ${json.encode(requestBody)}');

      // Send the POST request
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          "Content-Type": "application/json", // Ensure the correct Content-Type header
        },
        body: json.encode(requestBody), // Encode the payload as JSON
      );

      // Print the response status code and body
      print('Response from backend:');
      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');

      if (response.statusCode == 200) {
        // Parse the response body
        final Map<String, dynamic> responseData = json.decode(response.body);

        // Return the relevant user data
        return {
          'username': responseData['username'],
          'first_name': responseData['first_name'],
          'email': responseData['email'],
        };
      } else {
        print('Invalid credentials');
      }
    } catch (e) {
      print('Error validating credentials: $e');
    }
    return null;
  }
}
