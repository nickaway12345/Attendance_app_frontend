import 'package:flutter/material.dart';
import 'package:location_checker/screens/choose_role_screen.dart';
import 'package:location_checker/services/local_database_servie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'location_checker_screen.dart';
import 'service_home_screen.dart';
import 'package:location_checker/services/login_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

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
    _checkDatabase();
  }

  Future<void> _checkDatabase() async {
    final db = await LocalDatabaseService.database;
    print("Database is ready: $db");
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

  bool _obscurePassword = true; // Track password visibility

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
                        'assets/images/red-logo-removebg-preview.png',
                        height: 100,
                      ),
                    ),
                    SizedBox(width: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome,',
                          style: TextStyle(
                            color: Color(0xFFB84542),
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Hashrate',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Communications',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 100),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Username',
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
                        'Password',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 10),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword, // Toggle password visibility
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Color(0xFFFDEEEE),
                          hintText: 'Enter your password',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility : Icons.visibility_off,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword; // Toggle visibility
                              });
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: 50),
                      Center(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isLoading ? Colors.grey : Color(0xFFB84542),
                            padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            _isLoading ? 'LOGGING IN...' : 'LOGIN',
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
  );
}
}