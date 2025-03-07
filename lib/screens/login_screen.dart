import 'package:flutter/material.dart';
import 'package:location_checker/screens/choose_role_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'location_checker_screen.dart';
import 'service_home_screen.dart';
import 'package:location_checker/services/login_service.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _loginService = LoginService();
  bool _isLoading = false; // Track loading state

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  void _login() async {
    setState(() {
      _isLoading = true; // Start loading
    });

    // Wait for 4 seconds
    await Future.delayed(Duration(seconds: 2));

    final username = _usernameController.text;
    final password = _passwordController.text;

    try {
      final userDetails = await _loginService.validateCredentials(username, password);

      if (userDetails != null) {
        // Debugging: Print the userDetails to verify its contents
        print('User Details: $userDetails');

        // Check if required fields are present and not null
        if (userDetails['username'] == null || userDetails['first_name'] == null || userDetails['email'] == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invalid user details received from the server')),
          );
          setState(() {
            _isLoading = false; // Stop loading
          });
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('empId', userDetails['username']!); // Store username as empId
        await prefs.setString('firstName', userDetails['first_name']!); // Use 'first_name'
        await prefs.setString('email', userDetails['email']!);

        // Check the role and navigate accordingly
        final role = prefs.getString('role');
        if (role == 'core') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => LocationCheckerScreen(empId: userDetails['username']!),
            ),
          );
        } else if (role == 'service') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ServiceHomePage(empId: userDetails['username']!),
            ),
          );
        } else {
          // If no role is set, navigate to the role selection screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ChooseRoleScreen(),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid username or password')),
        );
        setState(() {
          _isLoading = false; // Stop loading
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
      setState(() {
        _isLoading = false; // Stop loading
      });
    }
  }

  void _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final empId = prefs.getString('empId');
    final role = prefs.getString('role');

    if (isLoggedIn && empId != null) {
      if (role == 'core') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LocationCheckerScreen(empId: empId),
          ),
        );
      } else if (role == 'service') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ServiceHomePage(empId: empId),
          ),
        );
      } else {
        // If no role is set, navigate to the role selection screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChooseRoleScreen(),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // Prevents resizing of the scaffold when the keyboard appears
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
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(top: 80.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Image.asset(
                          'assets/images/upscalemedia-transformed.png',
                          height: 100, // Further increased logo size
                        ),
                      ),
                      SizedBox(width: 20), // Increased spacing between logo and text
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome,',
                            style: TextStyle(
                              color: Color(0xFFB84542),
                              fontSize: 36, // Further increased font size
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Hashrate',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26, // Further increased font size
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Communications',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26, // Further increased font size
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 100), // Increased space between logo/text and fields
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Username', // Added label for username field
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 10),
                        TextField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Color(0xFFFDEEEE),
                            hintText: 'Enter your username',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        SizedBox(height: 30),
                        Text(
                          'Password', // Added label for password field
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 10),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Color(0xFFFDEEEE),
                            hintText: 'Enter your password',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        SizedBox(height: 50), // Increased space between fields and button
                        Center(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login, // Disable button when loading
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isLoading ? Colors.grey : Color(0xFFB84542), // Change button color when loading
                              padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              _isLoading ? 'LOGGING IN...' : 'LOGIN', // Change button text when loading
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Buffer Screen (Overlay)
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.7), // Semi-transparent background
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Display GIF
                    Image.asset(
                      'assets/images/loading.gif', // Path to your GIF file
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
    );
  }
}