import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:location_checker/services/local_database_servie.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends StatefulWidget {
  final String empId;

  const ProfileScreen({super.key, required this.empId});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic> _userData = {};
  bool _isLoading = true;
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _loadProfileImage();
  }

  Future<void> _fetchUserData() async {
    try {
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

  Future<void> _loadProfileImage() async {
    final db = await LocalDatabaseService.database;
    final result = await db.query(
      'profile_images',
      where: 'emp_id = ?',
      whereArgs: [widget.empId],
      limit: 1,
    );

    if (result.isNotEmpty) {
      setState(() {
        _profileImage = File(result.first['file_path'] as String);
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      // First try to pick the image with basic settings
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        preferredCameraDevice: CameraDevice.rear,
        requestFullMetadata: false, // This helps avoid color space issues
      );
      
      if (pickedFile != null) {
        // Convert to PNG to avoid color space issues
        final bytes = await pickedFile.readAsBytes();
        final image = await decodeImageFromList(bytes);
        
        final directory = await getApplicationDocumentsDirectory();
        final pngPath = '${directory.path}/profile_${widget.empId}_${DateTime.now().millisecondsSinceEpoch}.png';
        
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(pngPath).writeAsBytes(byteData!.buffer.asUint8List());
        
        final db = await LocalDatabaseService.database;
        await db.insert(
          'profile_images',
          {
            'emp_id': widget.empId,
            'file_path': pngPath,
            'uploaded_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        setState(() {
          _profileImage = File(pngPath);
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image. Please try another image.')),
      );
    }
  }

  String _formatDate(String dateString) {
    if (dateString == 'unknown') return 'Unknown';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildHexagonImage() {
  return GestureDetector(
    onTap: _pickImage,
    child: Container(
      width: 200,
      height: 220,
      margin: EdgeInsets.only(top: 80),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer dark orange border
          ClipPath(
            clipper: HexagonClipper(),
            child: Container(
              width: 200,
              height: 220,
              decoration: BoxDecoration(
                color: Color(0xFFB84542), // Dark orange color
              ),
            ),
          ),
          // Middle white border
          ClipPath(
            clipper: HexagonClipper(),
            child: Container(
              width: 200 - 12, // Subtracting total border width (6*2)
              height: 220 - 12,
              decoration: BoxDecoration(
                color: Colors.white,
              ),
            ),
          ),
          // Inner content with image
          ClipPath(
            clipper: HexagonClipper(),
            child: Container(
              width: 200 - 24, // Subtracting total padding (12*2)
              height: 220 - 24,
              decoration: BoxDecoration(
                color: Colors.grey[300],
              ),
              child: _profileImage != null
                  ? Image.file(
                      _profileImage!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.person,
                          size: 100,
                          color: Colors.grey[800],
                        );
                      },
                    )
                  : Center(
                      child: Icon(
                        Icons.person,
                        size: 100,
                        color: Colors.grey[800],
                      ),
                    ),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildNameText() {
    return Container(
      margin: EdgeInsets.only(top: 40),
      child: Text(
        '${_userData['firstName'] ?? ''} ${_userData['lastName'] ?? ''}',
        style: TextStyle(
          fontSize: 27,
          fontWeight: FontWeight.bold,
          color: Color(0xFF0D1A33),
        ),
      ),
    );
  }

  Widget _buildDepartmentBox() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: 10),
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: Color(0xFFB84542),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        _userData['department'] ?? 'Unknown',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildContactPage() {
  return Stack(
    children: [
      // Background frame for contact page - starts from top
      Positioned.fill(
        child: Image.asset(
          'assets/images/Hash_id_black_contact.png',
          fit: BoxFit.fill,
        ),
      ),
      
      Padding(
        padding: EdgeInsets.only(top: 40, left: 20, right: 20, bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SizedBox(height: 155), // Space to push content down
            
            // Header aligned to right with two lines
            Container(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CONTACT',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: ui.Color.fromARGB(255, 10, 33, 76),
                    ),
                  ),
                  Text(
                    '& ADDRESS',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: ui.Color.fromARGB(255, 10, 33, 76),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 72),
            
            
            
            // Emergency Contacts
            Container(
              alignment: Alignment.center,
              child: Text(
                'Emergency Contact Numbers',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFB84542),
                ),
              ),
            ),
            SizedBox(height: 15),
            
            // Contact buttons with maroon border and icons
            _buildContactButton('+91 91374 55975'),
            SizedBox(height: 15),
            _buildContactButton('+91 98673 12349'),
            SizedBox(height: 28),
            
            // Address Box
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Color(0xFFB84542),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Hashrate Communications Pvt. Ltd',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '# 215, Building No 1, Sector 02,\n'
                    'MBP, Navi Mumbai - 400710',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

  Widget _buildContactButton(String number) {
    return Align(
      alignment: Alignment.center,
      child: InkWell(
        onTap: () => _makePhoneCall(number),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10, horizontal: 13),
          width: MediaQuery.of(context).size.width * 0.7,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Color(0xFFB84542), width: 2),
          ),
          child: Row(
            children: [
              Icon(Icons.phone, color: Color(0xFFB84542)),
              SizedBox(width: 10),
              Text(
                number,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFFB84542),
                  fontWeight: FontWeight.bold,
                ),
              ),
              Spacer(),
              Icon(Icons.call, color: Color(0xFFB84542)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      throw 'Could not launch $phoneNumber';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Employee ID Card',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFB84542),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: Colors.white,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: PageView(
          controller: _pageController,
          children: [
            // First Page - Profile
            Stack(
              children: [
                // Background frame for profile - starts from top
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/Hash_id_black.png',
                    fit: BoxFit.fill,
                  ),
                ),
                
                SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 40, left: 20, right: 20, bottom: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Hexagon profile picture
                      _buildHexagonImage(),
                      
                      // Name above department box
                      _buildNameText(),
                      
                      // Department box
                      _buildDepartmentBox(),
                      SizedBox(height: 20),
                      
                      // User details
                      _buildDetailRow('Emp ID:', widget.empId),
                      _buildDetailRow('Email:', _userData['email'] ?? 'Not provided'),
                      // _buildDetailRow('Joined:', _formatDate(_userData['doj'] ?? 'unknown')),
                      _buildDetailRow('Contact:', _userData['phone'] ?? 'Unknown'),
                      
                      SizedBox(height: 15),
                      
                      // Company logo and QR code at the bottom
                     

// Update the QR code row to center it
Row(
  mainAxisAlignment: MainAxisAlignment.center, // Changed from spaceBetween
  children: [
    Column(
      children: [
        QrImageView(
          data: 'MECARD:N:${_userData['firstName'] ?? ''} ${_userData['lastName'] ?? ''};TEL:${_userData['phone'] ?? ''};EMAIL:${_userData['email'] ?? ''};;',
          version: QrVersions.auto,
          size: 90,
          backgroundColor: Colors.white,
        ),
        const Text(
          'Scan to save contact',
          style: TextStyle(
            fontSize: 12,
            color: Colors.black,
          ),
        ),
      ],
    ),
    // Removed the Image.asset widget that was here
  ],
),

                    ],
                  ),
                ),
              ],
            ),
            
            // Second Page - Contact
            _buildContactPage(),
          ],
        ),
      ),
      // floatingActionButton: FloatingActionButton(
      //   backgroundColor: Color(0xFFB84542),
      //   child: Icon(Icons.swap_horiz),
      //   onPressed: () {
      //     _pageController.nextPage(
      //       duration: Duration(milliseconds: 300),
      //       curve: Curves.easeInOut,
      //     );
      //   },
      // ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 20),
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120, // Fixed width for all labels
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: ui.Color.fromARGB(255, 10, 33, 76),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: 1),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFFB84542),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}

class HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final borderOffset = 3.0; // Accounts for the border width
    
    path.moveTo(size.width * 0.5, borderOffset);
    path.lineTo(size.width - borderOffset, size.height * 0.25);
    path.lineTo(size.width - borderOffset, size.height * 0.75);
    path.lineTo(size.width * 0.5, size.height - borderOffset);
    path.lineTo(borderOffset, size.height * 0.75);
    path.lineTo(borderOffset, size.height * 0.25);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}