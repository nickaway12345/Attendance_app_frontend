import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:location_checker/services/local_database_servie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:photo_view/photo_view.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

class MediclaimScreen extends StatefulWidget {
  final String empId;
  const MediclaimScreen({super.key, required this.empId});

  @override
  _MediclaimScreenState createState() => _MediclaimScreenState();
}

class _MediclaimScreenState extends State<MediclaimScreen> {
  Map<String, String> _userDetails = {'firstName': 'Unknown', 'email': 'Unknown'};
  Map<String, dynamic> _userData = {};
  bool _isLoading = false;
  File? _mediclaimCard;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchUserDetails();
    _fetchUserData();
    _loadSavedMediclaimCard();
  }

  Future<void> _fetchUserDetails() async {
    final userDetails = await getUserDetails();
    setState(() {
      _userDetails = userDetails;
    });
  }

  Future<void> _fetchUserData() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://default-url.com';
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/userdata/${widget.empId}'),
      );

      if (response.statusCode == 200) {
        setState(() {
          _userData = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load user data');
      }
    } catch (e) {
      print('Error fetching user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSavedMediclaimCard() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final filePath = await LocalDatabaseService.getMediclaimCardPath(widget.empId);
      if (filePath != null && await File(filePath).exists()) {
        setState(() {
          _mediclaimCard = File(filePath);
        });
      }
    } catch (e) {
      print('Error loading mediclaim card: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Map<String, String>> getUserDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final firstName = prefs.getString('firstName') ?? "Unknown";
    final email = prefs.getString('email') ?? "Unknown";

    return {
      'firstName': firstName,
      'email': email,
    };
  }

  Future<void> _uploadMediclaimCard() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _isLoading = true;
          _mediclaimCard = File(image.path);
        });

        await LocalDatabaseService.saveMediclaimCard(widget.empId, image.path);
        
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mediclaim card uploaded successfully!')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload mediclaim card: $e')),
      );
    }
  }


//   Future<void> _launchMediclaimWebsite() async {
//   String url = dotenv.env['MEDICLAIM_WEBSITE_URL'] ?? 
//               'https://www.kotakgeneral.com/network-locator/cashless-hospitals';
  
//   // Ensure proper URL format for Android
//   if (Platform.isAndroid && !url.startsWith('http')) {
//     url = 'https://$url';
//   }

//   try {
//     final uri = Uri.parse(url);
    
//     if (await canLaunchUrl(uri)) {
//       await launchUrl(
//         uri,
//         mode: LaunchMode.externalApplication,
//         webOnlyWindowName: '_blank', // For web compatibility
//       );
//     } else {
//       // Fallback for devices without browser
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('No browser available to open the link')),
//       );
//     }
//   } catch (e) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Failed to open link: ${e.toString()}')),
//     );
//   }
// }

Future<void> _launchMediclaimWebsite() async {
  String url = dotenv.env['MEDICLAIM_WEBSITE_URL'] ?? 
              'https://www.kotakgeneral.com/network-locator/cashless-hospitals';
  
  try {
    final uri = Uri.parse(url);
    
    // First try launching with external application
    if (await canLaunchUrl(uri)) {
      bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      
      if (!launched) {
        // If external launch failed, try in-app browser
        await launchUrl(
          uri,
          mode: LaunchMode.inAppWebView,
        );
      }
    } else {
      // Fallback: Try to force open with package manager
      if (Platform.isAndroid) {
        try {
          await launchUrl(
            uri,
            mode: LaunchMode.externalNonBrowserApplication,
          );
        } catch (e) {
          // Final fallback - show dialog with URL
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text("Could not open browser"),
              content: Text("Please manually visit: $url"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("OK"),
                ),
              ],
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No browser available to open the link')),
        );
      }
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to open link: ${e.toString()}')),
    );
  }
}

  // Future<void> _makePhoneCall(String phoneNumber) async {
  //   final Uri launchUri = Uri(
  //     scheme: 'tel',
  //     path: phoneNumber,
  //   );
  //   if (await canLaunch(launchUri.toString())) {
  //     await launch(launchUri.toString());
  //   } else {
  //     throw 'Could not launch $launchUri';
  //   }
  // }

  // Future<void> _sendEmail(String email) async {
  //   final Uri launchUri = Uri(
  //     scheme: 'mailto',
  //     path: email,
  //   );
  //   if (await canLaunch(launchUri.toString())) {
  //     await launch(launchUri.toString());
  //   } else {
  //     throw 'Could not launch $launchUri';
  //   }
  // }

  Future<void> _makePhoneCall(String phoneNumber) async {
  final Uri launchUri = Uri(
    scheme: 'tel',
    path: phoneNumber,
  );
  
  try {
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(
        launchUri,
        mode: Platform.isAndroid 
            ? LaunchMode.externalNonBrowserApplication
            : LaunchMode.externalApplication,
      );
    } else {
      // Fallback for devices without phone capability
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not make phone call')),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error making phone call: ${e.toString()}')),
    );
  }
}

Future<void> _sendEmail(String email) async {
  final Uri launchUri = Uri(
    scheme: 'mailto',
    path: email,
  );

  try {
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(
        launchUri,
        mode: Platform.isAndroid 
            ? LaunchMode.externalNonBrowserApplication
            : LaunchMode.externalApplication,
      );
    } else {
      // Fallback for devices without email capability
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No email app found')),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error sending email: ${e.toString()}')),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Black background layer
          Container(color: Colors.black),
          
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
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 45.0, 16.0, 16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Color(0xFFB84542)),
                      onPressed: () => Navigator.pop(context),
                    ),
                    SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HEY ${_userDetails['firstName']}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB84542),
                          ),
                        ),
                        Text(
                          _userDetails['email']!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFB84542),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Mediclaim website link
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: GestureDetector(
                  onTap: _launchMediclaimWebsite,
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFFB84542),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Go to Network Hospital list',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                          ),
                        SizedBox(width: 8),
                        Icon(Icons.open_in_new, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Main Content
              Expanded(
                child: Container(
                  margin: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // User and Mediclaim Information
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_userData['firstName'] ?? ''} ${_userData['lastName'] ?? ''}',
                                style: TextStyle(
                                  color: Color(0xFFB84542),
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold),
                                ),
                              SizedBox(height: 10),
                              
                              Text(
                                'Mediclaim No: ${_userData['mediclaim'] ?? 'N/A'}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16),
                                ),
                              
                              // SizedBox(height: 5),
                              
                              // Text(
                              //   'Policy No: ${dotenv.env['POLICY_NUMBER'] ?? 'N/A'}',
                              //   style: TextStyle(
                              //     color: Colors.white,
                              //     fontSize: 16),
                              //   ),
                              
                              SizedBox(height: 20),
                              
                              // FAQ Section
                              Text(
                                'Cashless Claim Process – FAQs',
                                style: TextStyle(
                                  color: Color(0xFFB84542),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                                ),
                              
                              SizedBox(height: 15),
                              
                              _buildFAQItem(
                                '1. What should I do in case of an emergency hospital admission?',
                                '• Get admitted as per hospital norms.\n• Immediately contact the TPA desk at the hospital.\n• The hospital must apply for pre-authorization to the TPA within 24 hours of admission.'
                              ),
                              
                              SizedBox(height: 15),
                              
                              _buildFAQItem(
                                '2. What is the process for a planned hospital admission?',
                                '• Approach the hospital\'s TPA desk at least 48 hours before your planned admission.\n• The hospital will send a pre-authorization request to the TPA in advance.'
                              ),
                              
                              SizedBox(height: 15),
                              
                              _buildFAQItem(
                                '3. What does the TPA do after receiving the pre-authorization request?',
                                '• The TPA verifies your policy coverage and checks the details.\n• They respond to the hospital via fax or email.'
                              ),
                              
                              SizedBox(height: 15),
                              
                              _buildFAQItem(
                                '4. What happens if the TPA raises a query?',
                                '• The TPA sends the query to the hospital via fax/email.\n• The hospital responds to the query with the required information.'
                              ),
                              
                              SizedBox(height: 15),
                              
                              _buildFAQItem(
                                '5. How do I know if my cashless claim is approved?',
                                '• If approved, an initial approval letter is sent by the TPA to the hospital via fax/email.\n• Four hours before discharge, you or the hospital must contact the TPA desk again to complete final approval formalities.'
                              ),
                              
                              SizedBox(height: 15),
                              
                              _buildFAQItem(
                                '6. What if my cashless claim is denied?',
                                '• A denial letter is sent by the TPA to the hospital.\n• You will need to pay the bill yourself and then submit the necessary documents for reimbursement.'
                              ),
                              
                              SizedBox(height: 20),
                              
                              Text(
                                'Emergency Contacts:',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                                ),
                              
                              SizedBox(height: 10),
                              
                              // HR Contact
                              GestureDetector(
                                onTap: () => _makePhoneCall(dotenv.env['HR_PHONE'] ?? '9137455975'),
                                child: Row(
                                  children: [
                                    Icon(Icons.phone, color: Color(0xFFB84542)),
                                    SizedBox(width: 10),
                                    Text(
                                      'HR: ${dotenv.env['HR_PHONE'] ?? '9137455975'}',
                                      style: TextStyle(
                                        color: Color(0xFFB84542),
                                        fontSize: 16),
                                      ),
                                  ],
                                ),
                              ),
                              
                              SizedBox(height: 8),
                              
                              // Manager Contact
                              GestureDetector(
                                onTap: () => _makePhoneCall(dotenv.env['MANAGER_PHONE'] ?? '9867312349'),
                                child: Row(
                                  children: [
                                    Icon(Icons.phone, color: Color(0xFFB84542)),
                                    SizedBox(width: 10),
                                    Text(
                                      'Manager: ${dotenv.env['MANAGER_PHONE'] ?? '9867312349'}',
                                      style: TextStyle(
                                        color: Color(0xFFB84542),
                                        fontSize: 16),
                                      ),
                                  ],
                                ),
                              ),
                              
                              SizedBox(height: 8),
                              
                              // Customer Care
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onTap: () => _makePhoneCall(dotenv.env['CUSTOMER_CARE_PHONE'] ?? '18002664545'),
                                    child: Row(
                                      children: [
                                        Icon(Icons.phone, color: Color(0xFFB84542)),
                                        SizedBox(width: 10),
                                        Text(
                                          'Customer Care: ${dotenv.env['CUSTOMER_CARE_PHONE'] ?? '1800 266 45 45'}',
                                          style: TextStyle(
                                            color: Color(0xFFB84542),
                                            fontSize: 16),
                                          ),
                                      ],
                                    ),
                                  ),
                                  
                                  SizedBox(height: 8),
                                  
                                  GestureDetector(
                                    onTap: () => _sendEmail(dotenv.env['CUSTOMER_CARE_EMAIL'] ?? 'care@zurichkotak.com'),
                                    child: Row(
                                      children: [
                                        Icon(Icons.email, color: Color(0xFFB84542)),
                                        SizedBox(width: 10),
                                        Text(
                                          'Email: ${dotenv.env['CUSTOMER_CARE_EMAIL'] ?? 'care@zurichkotak.com'}',
                                          style: TextStyle(
                                            color: Color(0xFFB84542),
                                            fontSize: 16),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        // Upload Section
                        // Upload Section
Padding(
  padding: const EdgeInsets.all(16.0),
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(
        'Your Mediclaim Card',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold),
        ),
      SizedBox(height: 20),
      
      // Display area for uploaded card (zoomable)
      if (_mediclaimCard != null)
        GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (context) => Scaffold(
                appBar: AppBar(
                  backgroundColor: Colors.black,
                  leading: IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                body: Center(
                  child: PhotoView(
                    imageProvider: FileImage(_mediclaimCard!),
                    minScale: PhotoViewComputedScale.contained,
                    maxScale: PhotoViewComputedScale.covered * 2,
                  ),
                ),
              ),
            ));
          },
          child: Container(
            width: MediaQuery.of(context).size.width - 32,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                _mediclaimCard!,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      
      SizedBox(height: 20),
      
      // Updated Upload/Update button (now rectangular)
      SizedBox(
        width: 150, // Set a fixed width for the button
        child: ElevatedButton(
          onPressed: _uploadMediclaimCard,
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFFB84542), // Button color
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8), // Slightly rounded corners
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _mediclaimCard != null ? Icons.update : Icons.upload,
                color: Colors.white,
              ),
              SizedBox(width: 8),
              Text(
                _mediclaimCard != null ? 'UPDATE' : 'UPLOAD',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
      SizedBox(height: 10),
      
      // Delete button if card exists
      if (_mediclaimCard != null)
        TextButton(
          onPressed: () async {
            await LocalDatabaseService.deleteMediclaimCard(widget.empId);
            setState(() {
              _mediclaimCard = null;
            });
          },
          child: Text(
            'Delete Card',
            style: TextStyle(
              color: Color(0xFFB84542),
              fontSize: 16,
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
              ),
            ],
          ),

          // Loading Overlay
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

  Widget _buildFAQItem(String question, String answer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold),
          ),
        SizedBox(height: 5),
        Text(
          answer,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14),
          ),
      ],
    );
  }
}