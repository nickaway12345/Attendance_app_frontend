import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart'; // Import the LoginScreen for navigation
import 'package:intl/intl.dart'; // For date and time formatting

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
  DateTime currentTime = DateTime.now(); // Current time
  String _currentDate = ''; // Current date
  String _location = 'Unknown'; // Location placeholder

  @override
  void initState() {
    super.initState();
    _fetchUserDetails(); // Fetch user details when the page loads
    _updateTimeAndDate(); // Initialize time and date
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

  // Update time and date periodically
  void _updateTimeAndDate() {
    setState(() {
      currentTime = DateTime.now();
      _currentDate = DateFormat('MMMM dd, yyyy').format(currentTime);
    });

    // Update every minute
    Future.delayed(Duration(seconds: 2), _updateTimeAndDate);
  }

  // Refresh location (placeholder function)
  void _refreshLocation() {
    // Add logic to refresh location here
    setState(() {
      _location = 'Refreshing...';
    });

    // Simulate a delay for refreshing
    Future.delayed(Duration(seconds: 2), () {
      setState(() {
        _location = 'New Location'; // Replace with actual location logic
      });
    });
  }

  @override
  Widget build(BuildContext context) {
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
                        // Header (Lowered a bit)
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
    );
  }
}