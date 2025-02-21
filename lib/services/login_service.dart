import 'dart:convert'; // For JSON decoding
import 'package:flutter/services.dart'; // For loading assets

class LoginService {
  Future<String?> validateCredentials(String username, String password) async {
    try {
      final String jsonString = await rootBundle.loadString('assets/data/credentials.json');
      final Map<String, dynamic> credentialsData = json.decode(jsonString);

      final List<dynamic> users = credentialsData['users'];
      for (var user in users) {
        if (user['username'] == username && user['password'] == password) {
          return username;
        }
      }
    } catch (e) {
      print('Error reading credentials: $e');
    }
    return null; 
  }
}
