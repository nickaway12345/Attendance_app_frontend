import 'package:flutter/material.dart';
import 'package:location_checker/screens/location_checker_screen.dart';
import 'package:location_checker/screens/history_screen.dart';

class MainScreen extends StatefulWidget {
  final String empId;
  const MainScreen({super.key, required this.empId});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0; // Default to Home tab
  final PageController _pageController = PageController(initialPage: 0);

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    double barHeight = 60.0;
    double tabWidth = MediaQuery.of(context).size.width / 2;

    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: [
          LocationCheckerScreen(empId: widget.empId),
          HistoryScreen(empId: widget.empId),
        ],
      ),
      bottomNavigationBar: Container(
        height: barHeight + 10,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFF7043),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Sliding box (darker shade)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              left: _selectedIndex == 0 ? 0 : tabWidth,
              top: 0,
              bottom: 0,
              child: Container(
                width: tabWidth,
                height: barHeight,
                decoration: BoxDecoration(
                  color: const Color(0xFFB84542).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            // Tab items (Home and History)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Home Tab
                Expanded(
                  child: GestureDetector(
                    onTap: () => _onItemTapped(0),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.home, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'HOME',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // History Tab
                Expanded(
                  child: GestureDetector(
                    onTap: () => _onItemTapped(1),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'HISTORY',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
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
      ),
    );
  }
}