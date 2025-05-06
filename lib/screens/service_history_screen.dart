import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:location_checker/screens/service_home_screen.dart';
import 'package:location_checker/services/fetchAndSetTime.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ServiceHistoryScreen extends StatefulWidget {
  final String empId;
  const ServiceHistoryScreen({super.key, required this.empId});

  @override
  _ServiceHistoryScreenState createState() => _ServiceHistoryScreenState();
}

class _ServiceHistoryScreenState extends State<ServiceHistoryScreen> {
  final Map<int, Map<DateTime, double>> _shiftAttendanceData = {};
  final Map<int, List<DateTime>> _shiftDays = {};
  List<Map<String, dynamic>> _shiftTimings = [];
  bool _isLoading = true;
  int _selectedIndex = 1;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://default-url.com';

      final attendanceResponse = await http.get(
        Uri.parse('$baseUrl/api/attendance/service/attendancedata?empId=${widget.empId}'),
      );

      final shiftResponse = await http.get(
        Uri.parse('$baseUrl/api/shifts/shift_timings?empId=${widget.empId}'),
      );

      if (attendanceResponse.statusCode == 200 && shiftResponse.statusCode == 200) {
        final attendanceData = json.decode(attendanceResponse.body) as List;
        final shiftData = json.decode(shiftResponse.body) as List;

        for (var shift in shiftData) {
          final shiftNumber = shift['shiftNumber'] as int;
          final startDate = DateTime.parse(shift['startTime']).toLocal();
          final endDate = DateTime.parse(shift['endTime']).toLocal();

          _shiftAttendanceData[shiftNumber] ??= {};
          _shiftDays[shiftNumber] ??= [];

          final startDateOnly = DateTime(startDate.year, startDate.month, startDate.day);
          if (!_shiftDays[shiftNumber]!.contains(startDateOnly)) {
            _shiftDays[shiftNumber]!.add(startDateOnly);
          }
        }

        _shiftTimings = shiftData.cast<Map<String, dynamic>>();

        for (var entry in attendanceData) {
          final date = DateTime.parse(entry['id']['date']).toLocal();
          final shiftNumber = entry['id']['shift_number'] as int;
          final totalHours = entry['totalHours'] as double;

          if (_shiftAttendanceData.containsKey(shiftNumber)) {
            _shiftAttendanceData[shiftNumber]![date] = totalHours;
          }
        }

        setState(() {
          _isLoading = false;
        });
      } else {
        print('Failed to fetch data.');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  double _calculateShiftDuration(Map<String, dynamic> shift) {
    final startTime = DateTime.parse(shift['startTime']).toLocal();
    final endTime = DateTime.parse(shift['endTime']).toLocal();
    return endTime.difference(startTime).inHours.toDouble();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ServiceHomePage(empId: widget.empId),
        ),
      );
    }
  }

  String _getShiftLetter(int shiftNumber) {
    switch (shiftNumber) {
      case 1: return 'Morning';
      case 2: return 'Afternoon';
      case 3: return 'Night';
      case 4: return 'General';
      default: return shiftNumber.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    double barHeight = 60.0;
    double tabWidth = MediaQuery.of(context).size.width / 2;

    return Scaffold(
      backgroundColor: Colors.black, // Set scaffold background to black
      body: Stack(
        children: [
          // Black background layer
          Container(color: Colors.black),
          
          // Background Image
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/background.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          
          // Main Content
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : ListView(
                  children: _shiftDays.entries.map((entry) {
                    final shiftNumber = entry.key;
                    final daysWithShifts = entry.value;
                    DateTime focusedDay = TimeService.appTime;
                    
                    if (focusedDay.isBefore(daysWithShifts.first)) {
                      focusedDay = daysWithShifts.first;
                    } else if (focusedDay.isAfter(daysWithShifts.last)) {
                      focusedDay = daysWithShifts.last;
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Shift ${_getShiftLetter(shiftNumber)}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                        TableCalendar(
                          firstDay: daysWithShifts.first,
                          lastDay: daysWithShifts.last,
                          focusedDay: focusedDay,
                          calendarFormat: CalendarFormat.month,
                          headerStyle: HeaderStyle(
                            titleTextStyle: TextStyle(color: Colors.blue),
                            formatButtonTextStyle: TextStyle(  // This controls the "2 weeks" text
      color: Colors.blue,      // Set to same color as arrows
      fontSize: 14,
    ),
                            leftChevronIcon: Icon(Icons.chevron_left, color: Colors.blue),
                            rightChevronIcon: Icon(Icons.chevron_right, color: Colors.blue),
                          ),
                          daysOfWeekStyle: DaysOfWeekStyle(
                            weekdayStyle: TextStyle(color: Colors.white),
                            weekendStyle: TextStyle(color: Colors.white),
                          ),
                          calendarStyle: CalendarStyle(
                            defaultTextStyle: TextStyle(color: Colors.white),
                            weekendTextStyle: TextStyle(color: Colors.white),
                            selectedTextStyle: TextStyle(color: Colors.white),
                            todayTextStyle: TextStyle(color: Colors.white),
                            selectedDecoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            todayDecoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                          ),
                          calendarBuilders: CalendarBuilders(
                            defaultBuilder: (context, day, focusedDay) {
                              final date = DateTime(day.year, day.month, day.day);
                              final totalHours = _shiftAttendanceData[shiftNumber]?[date] ?? 0;

                              if (daysWithShifts.any((shiftDay) =>
                                  shiftDay.year == date.year &&
                                  shiftDay.month == date.month &&
                                  shiftDay.day == date.day)) {
                                final shift = _shiftTimings.firstWhere(
                                  (s) => s['shiftNumber'] == shiftNumber,
                                  orElse: () => {},
                                );

                                if (shift.isNotEmpty) {
                                  final shiftDuration = _calculateShiftDuration(shift);
                                  final color = totalHours >= shiftDuration ? Colors.green : Colors.red;

                                  if (color == Colors.red) {
                                    return GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => RegularizeScreen(
                                              date: date,
                                              empId: widget.empId,
                                              shiftNumber: shiftNumber,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${day.day}',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  return Container(
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${day.day}',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              }
                              return null;
                            },
                          ),
                        ),
                        SizedBox(height: 20),
                      ],
                    );
                  }).toList(),
                ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding), // Add safe area padding
        child: Container(
          color: Colors.black,
          margin: EdgeInsets.only(bottom: 10),
          child: Container(
            height: barHeight,
            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 24),
            decoration: BoxDecoration(
              color: Color(0xFFFF7043),
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
                AnimatedPositioned(
                  duration: Duration(milliseconds: 300),
                  left: _selectedIndex == 0 ? 0 : tabWidth,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: tabWidth,
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: Color(0xFFB84542).withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _onItemTapped(0),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10.0),
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
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _onItemTapped(1),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10.0),
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
        ),
      ),
    );
  }
}



class RegularizeScreen extends StatefulWidget {
  final DateTime date;
  final String empId;
  final int shiftNumber;

  const RegularizeScreen({
    super.key,
    required this.date,
    required this.empId,
    required this.shiftNumber,
  });

  @override
  _RegularizeScreenState createState() => _RegularizeScreenState();
}

class _RegularizeScreenState extends State<RegularizeScreen> {
  final TextEditingController _reasonController = TextEditingController();
  String _oldInTime = '--:--';
  String _oldOutTime = '--:--';
  double _oldTotalHours = 0.0;
  String _newInTime = '--:--';
  String _newOutTime = '--:--';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAttendanceData();
    _fetchShiftTimings();
  }

  Future<void> _fetchAttendanceData() async {
    try {
      String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://default-url.com';
      final response = await http.get(
        Uri.parse('$baseUrl/api/attendance/service/attendancedata_date?empId=${widget.empId}&date=${DateFormat('yyyy-MM-dd').format(widget.date)}&shiftNumber=${widget.shiftNumber}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _oldInTime = data['inTime'] ?? '--:--';
          _oldOutTime = data['outTime'] ?? '--:--';
          _oldTotalHours = data['totalHours'] ?? 0.0;
        });
      } else {
        print('Failed to fetch attendance data. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching attendance data: $e');
    }
  }

  Future<void> _fetchShiftTimings() async {
    try {
      String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://default-url.com';
      final response = await http.get(
        Uri.parse('$baseUrl/api/shifts/shift_timings?empId=${widget.empId}&date=${DateFormat('yyyy-MM-dd').format(widget.date)}'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> shiftData = json.decode(response.body);

        final shift = shiftData.firstWhere(
          (shift) =>
              shift['shiftNumber'] == widget.shiftNumber &&
              DateTime.parse(shift['startTime']).toLocal().day == widget.date.day,
          orElse: () => null,
        );

        if (shift != null) {
          setState(() {
            _newInTime = DateFormat('HH:mm').format(DateTime.parse(shift['startTime']).toLocal());
            _newOutTime = DateFormat('HH:mm').format(DateTime.parse(shift['endTime']).toLocal());
            _isLoading = false;
          });
        } else {
          print('No shift found for the selected date and shift number.');
        }
      } else {
        print('Failed to fetch shift timings. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching shift timings: $e');
    }
  }

  Future<void> _submitRegularization() async {
    try {
      String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://default-url.com';

      if (_reasonController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter a reason.')),
        );
        return;
      }

      final Map<String, dynamic> data = {
        'id': {
          'empId': widget.empId,
          'date': DateFormat('yyyy-MM-dd').format(widget.date),
          'shiftNumber': widget.shiftNumber,
        },
        'oldInTime': _oldInTime,
        'oldOutTime': _oldOutTime,
        'oldTotalHours': _oldTotalHours,
        'newInTime': _newInTime,
        'newOutTime': _newOutTime,
        'reason': _reasonController.text.trim(),
        'status': 'Pending',
      };

      final response = await http.post(
        Uri.parse('$baseUrl/api/regularization/service'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Regularization submitted successfully!')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit regularization.')),
        );
      }
    } catch (e) {
      print('Error submitting regularization: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred. Please try again.')),
      );
    }
  }

  @override
Widget build(BuildContext context) {
  final cardWidth = MediaQuery.of(context).size.width - 40; // Subtracting horizontal padding

  return Scaffold(
    appBar: AppBar(
      title: Text('Regularize Attendance'),
      backgroundColor: Color(0xFFB84542),
      foregroundColor: Colors.white,
    ),
    body: Stack(
      children: [
        // Background Image
        Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/background.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        
        // Content
        _isLoading
            ? Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Old Timings Card - now using the calculated cardWidth
                    SizedBox(
                      width: cardWidth,
                      child: Card(
                        color: Color(0xFFFDEEEE).withOpacity(0.9),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Old Timings',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFB84542),
                                ),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Date: ${DateFormat('yyyy-MM-dd').format(widget.date)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFFB84542),
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Punch In: $_oldInTime',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFFB84542),
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Punch Out: $_oldOutTime',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFFB84542),
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Total Hours: ${_oldTotalHours.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFFB84542),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Regularization Form - now using the same calculated cardWidth
                    SizedBox(
                      width: cardWidth,
                      child: Card(
                        color: Color(0xFFFDEEEE).withOpacity(0.9),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Regularization',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFB84542),
                                ),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'New Punch In: $_newInTime',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFFB84542),
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'New Punch Out: $_newOutTime',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFFB84542),
                                ),
                              ),
                              SizedBox(height: 16),
                              TextFormField(
                                decoration: InputDecoration(
                                  labelText: 'Reason',
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(),
                                  labelStyle: TextStyle(color: Color(0xFFB84542)),
                                ),
                                controller: _reasonController,
                                maxLines: 3,
                                style: TextStyle(color: Colors.black),
                              ),
                              SizedBox(height: 20),
                              Center(
                                child: ElevatedButton(
                                  onPressed: _submitRegularization,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFFB84542),
                                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                                  ),
                                  child: Text(
                                    'Submit',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ],
    ),
  );
}
}