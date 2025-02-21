import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:location_checker/screens/location_checker_screen.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class HistoryScreen extends StatefulWidget {
  final String empId;
  const HistoryScreen({super.key, required this.empId});

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _selectedIndex = 1; // Default to History tab
  final double barHeight = 60.0;
  final double tabWidth = 180.0;
  Map<DateTime, String> _attendanceData = {};
  late String empId;
  Set<DateTime> _holidays = {};

  @override
  void initState() {
    super.initState();
    empId = widget.empId;
    _fetchAttendanceData();
  }

  Future<void> _fetchAttendanceData() async {
    try {
      // Fetch attendance data
      final attendanceResponse =
          await http.get(Uri.parse('http://192.168.10.5:8000/attendance?empId=${widget.empId}'));
      // Fetch holidays data
      final holidaysResponse = await http.get(Uri.parse('http://192.168.10.5:8000/holidays'));

      if (attendanceResponse.statusCode == 200 && holidaysResponse.statusCode == 200) {
        final attendanceData = json.decode(attendanceResponse.body) as List;
        final holidaysData = json.decode(holidaysResponse.body) as List;

        // Debugging logs
        print('Attendance Data: $attendanceData');
        print('Holidays Data: $holidaysData');

        setState(() {
          // Correctly mapping attendance data
          _attendanceData = {
            for (var item in attendanceData)
              DateTime.parse(item['id']['date']): item['day'] ?? 'H' // Accessing the date and day correctly
          };

          // Parse holidays data
          _holidays = {
            for (var item in holidaysData)
              if (item.containsKey('date')) DateTime.parse(item['date']) // Only parse if 'date' exists
          };
        });
      } else {
        print('Failed to fetch attendance or holidays data.');
      }
    } catch (e) {
      print('Error fetching attendance data: $e');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index; // Update the selected index for the slider
    });

    if (index == 0) {
      // Navigate to LocationCheckerScreen (Home)
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => LocationCheckerScreen(empId: widget.empId)),
      );
    } else if (index == 1) {
      // Stay on HistoryScreen (no navigation needed)
    }
  }

  void _navigateToRegularizeScreen(DateTime date) {
    // Navigate to the regularize screen for the selected date
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RegularizeScreen(date: date, empId: widget.empId),
      ),
    );
  }

  void _navigateToApprovalPage() {
    // Navigate to the ApprovalPage
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ApprovalPage(empId: widget.empId),
      ),
    );
  }

@override
Widget build(BuildContext context) {
  DateTime? firstAttendanceDate;
  
  if (_attendanceData.isNotEmpty) {
    // Find the first (earliest) attendance date
    firstAttendanceDate = _attendanceData.keys.reduce((a, b) => a.isBefore(b) ? a : b);
  }

  return Scaffold(
    appBar: AppBar(
      title: const Text('Attendance History'),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          // Navigate back to LocationCheckerScreen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LocationCheckerScreen(empId: empId)),
          );
        },
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.approval, color: Colors.black),
          onPressed: _navigateToApprovalPage,
        ),
      ],
    ),
    body: Container(
      width: double.infinity, // Ensures the container takes full width
      height: double.infinity, // Ensures the container takes full height
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/background.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 60, 20, 20),
            child: Text(
              'Attendance History',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF7043),
              ),
            ),
          ),
          Expanded(
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: DateTime.now(),
              // Customize the header style
              headerStyle: const HeaderStyle(
                titleTextStyle: TextStyle(color: Color(0xFFB84542)), // Month and year text color
                leftChevronIcon: Icon(Icons.chevron_left, color: Color(0xFFB84542)), // Left arrow color
                rightChevronIcon: Icon(Icons.chevron_right, color: Color(0xFFB84542)), // Right arrow color
              ),
              // Customize the days of the week style
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(color: Colors.white), // Weekday text color
                weekendStyle: TextStyle(color: Colors.white), // Weekend text color
              ),
              // Customize the calendar style
              calendarStyle: const CalendarStyle(
                defaultTextStyle: TextStyle(color: Colors.white, fontSize: 18), // Default date text color and size
                weekendTextStyle: TextStyle(color: Colors.white, fontSize: 18), // Weekend date text color and size
                selectedTextStyle: TextStyle(color: Colors.white, fontSize: 18), // Selected date text color and size
                todayTextStyle: TextStyle(color: Colors.white, fontSize: 18), // Today's date text color and size
                cellPadding: EdgeInsets.all(10), // Increase cell padding for more space
                cellMargin: EdgeInsets.all(5), // Increase cell margin for more space
              ),
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) {
                  final DateTime date = DateTime(day.year, day.month, day.day);

                  // Check if the date is a holiday
                  if (_holidays.contains(date)) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${day.day}',
                          style: const TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ),
                    );
                  }

                  // Check if the date is a Sunday
                  if (day.weekday == DateTime.sunday) {
                    return Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${day.day}',
                          style: const TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ),
                    );
                  }

                  // Check if the date is in the future
                  if (day.isAfter(DateTime.now())) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.grey,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${day.day}',
                          style: const TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ),
                    );
                  }

                  // Check if the date has attendance data
                  if (_attendanceData.containsKey(date)) {
                    switch (_attendanceData[date]) {
                      case 'F':
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${day.day}',
                              style: const TextStyle(color: Colors.white, fontSize: 18),
                            ),
                          ),
                        );
                      case 'H':
                        return GestureDetector(
                          onTap: () => _navigateToRegularizeScreen(date),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${day.day}',
                                style: const TextStyle(color: Colors.white, fontSize: 18),
                              ),
                            ),
                          ),
                        );
                    }
                  }

                  // If no attendance data is found for the date, mark it as red only after the first attendance date
                  if (firstAttendanceDate != null && date.isAfter(firstAttendanceDate)) {
                    return GestureDetector(
                          onTap: () => _navigateToRegularizeScreen(date),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${day.day}',
                                style: const TextStyle(color: Colors.white, fontSize: 18),
                              ),
                            ),
                          ),
                        );
                  }

                  return null;
                },
              ),
            ),
          ),
        ],
      ),
    ),
      bottomNavigationBar: Container(
  color: Colors.black, // Outer container with black margin effect
  margin: EdgeInsets.only(bottom: 10), // This creates the margin
  child: Container(
    height: barHeight,
    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 24),
    decoration: BoxDecoration(
      color: Color(0xFFFF7043), // Actual bottom bar color
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
        // Tab items (Home and History)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Home Tab
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
            // History Tab
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
    );
  }
}


class RegularizeScreen extends StatefulWidget {
  final DateTime date;
  final String empId;

  const RegularizeScreen({super.key, required this.date, required this.empId});

  @override
  _RegularizeScreenState createState() => _RegularizeScreenState();
}

class _RegularizeScreenState extends State<RegularizeScreen> {
  String _inTime = '';
  String _outTime = '';
  String _getinTime = '';
  String _getoutTime = '';
  double _gettotalHours = 0.0;
  double _totalHours = 0.0;
  final TextEditingController _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchAttendanceData();
  }

  Future<void> _selectTime(BuildContext context, bool isInTime) async {
  final TimeOfDay? picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.now(),
  );
  if (picked != null) {
    setState(() {
      final formattedTime = picked.format(context);
      if (isInTime) {
        _inTime = formattedTime;
      } else {
        _outTime = formattedTime;
      }
    });
  }
}

  Future<void> _fetchAttendanceData() async {
  try {
    final response = await http.get(
      Uri.parse('http://192.168.10.5:8000/attendanceByDate?empId=${widget.empId}&date=${DateFormat('yyyy-MM-dd').format(widget.date)}'),
    );

    if (response.statusCode == 200) {
      // Debug: Print the raw response
      print('Backend Response: ${response.body}');

      // Parse the response as a Map
      final data = json.decode(response.body) as Map<String, dynamic>;

      // Debug: Print the parsed data
      print('Parsed Data: $data');

      setState(() {
        // Extract values from the map
        _getinTime = data['inTime'] ?? '--:--';
        _getoutTime = data['outTime'] ?? '--:--';
        _gettotalHours = data['totalHours'] ?? 0.0;
      });
    } else {
      print('Failed to fetch attendance data. Status Code: ${response.statusCode}');
    }
  } catch (e) {
    print('Error fetching attendance data: $e');
  }
}

String formatTimeTo24Hour(String time) {
  try {
    // Remove all whitespace and non-breaking spaces
    final cleanedTime = time.replaceAll(RegExp(r'\s+'), '').replaceAll(String.fromCharCode(160), '');

    // Check if the time contains AM or PM
    final isPM = cleanedTime.toUpperCase().endsWith('PM');
    final isAM = cleanedTime.toUpperCase().endsWith('AM');

    if (!isPM && !isAM) {
      throw FormatException('Invalid time format: $time');
    }

    // Extract the time part (e.g., "9:42" from "9:42AM")
    final timeValue = cleanedTime.substring(0, cleanedTime.length - 2);

    // Split hours and minutes
    final timeComponents = timeValue.split(':');
    if (timeComponents.length != 2) {
      throw FormatException('Invalid time format: $time');
    }

    int hour = int.parse(timeComponents[0]);
    final int minute = int.parse(timeComponents[1]);

    // Convert to 24-hour format
    if (isPM && hour != 12) {
      hour += 12; // Add 12 hours for PM times (except 12 PM)
    } else if (isAM && hour == 12) {
      hour = 0; // Handle 12 AM (midnight)
    }

    // Format as HH:mm:ss
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00';
  } catch (e) {
    print('Error formatting time: $e');
    return '00:00:00'; // Fallback value
  }
}

double calculateTotalHours(DateTime inTime, DateTime outTime) {
  // If outTime is earlier than inTime, assume it's the next day
  if (outTime.isBefore(inTime)) {
    outTime = outTime.add(Duration(days: 1)); // Add 1 day to outTime
  }

  // Calculate the difference in hours and minutes
  final duration = outTime.difference(inTime);
  final totalHours = duration.inHours + (duration.inMinutes % 60) / 60.0;

  return totalHours;
}

Future<void> _submitRegularization() async {
  try {
    // Validate time inputs
    if (_inTime.isEmpty || _outTime.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select both In Time and Out Time.')),
      );
      return;
    }

    // Debugging logs
    print('In Time (12-hour format): $_inTime');
    print('Out Time (12-hour format): $_outTime');

    // Convert 12-hour time to 24-hour format (HH:mm:ss)
    final inTime24Hour = formatTimeTo24Hour(_inTime);
    final outTime24Hour = formatTimeTo24Hour(_outTime);

    // Debugging logs for formatted times
    print('In Time (24-hour format): $inTime24Hour');
    print('Out Time (24-hour format): $outTime24Hour');

    // Debugging logs for old timings
    print('Old In Time: $_getinTime');
    print('Old Out Time: $_getoutTime');

    // Fetch attendance data for the given empId and date
    final attendanceResponse = await http.get(
      Uri.parse('http://192.168.10.5:8000/attendanceByDate?empId=${widget.empId}&date=${DateFormat('yyyy-MM-dd').format(widget.date)}'),
    );

    String locationIn = 'Outside Office'; // Default value
    String locationOut = 'Outside Office'; // Default value

    if (attendanceResponse.statusCode == 200) {
      final attendanceData = json.decode(attendanceResponse.body);
      if (attendanceData != null) {
        // Use location_in and location_out from the backend if available
        locationIn = attendanceData['location_in'] ?? 'Outside Office';
        locationOut = attendanceData['location_out'] ?? 'Outside Office';
      }
    }

    // Calculate total hours
    final inTime = DateFormat('HH:mm:ss').parse(inTime24Hour);
    final outTime = DateFormat('HH:mm:ss').parse(outTime24Hour);
    final totalHours = calculateTotalHours(inTime, outTime);


    // Determine the day status based on total hours
    final dayStatus = totalHours >= 9 ? 'F' : 'H';

    // Add a timestamp to force update
    final timestamp = DateTime.now().toIso8601String();

    // Submit regularization data
    final response = await http.post(
      Uri.parse('http://192.168.10.5:8000/api/regularization/sync'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({
        'id': {
          'empId': widget.empId,
          'date': DateFormat('yyyy-MM-dd').format(widget.date),
        },
        'inTime': inTime24Hour, // Send in 24-hour format
        'outTime': outTime24Hour, // Send in 24-hour format
        'oldinTime': _getinTime, // Send old in time
        'oldoutTime': _getoutTime, // Send old out time
        'totalHours': totalHours,
        'location_in': locationIn, 
        'location_out': locationOut, 
        'day': dayStatus,
        'punch_in_lat': null,
        'punch_in_long': null,
        'punch_out_lat': null,
        'punch_out_long': null,
        'approval': 'Pending',
        'approvedBy': null,
        'reason': _reasonController.text,
        'timestamp': timestamp, // Add timestamp to force update
      }),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Regularize Attendance'),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current Punch Card
              Card(
                color: Color(0xFFFDEEEE),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                DateFormat('d').format(widget.date),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Current Punch',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFB84542),
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Punch In: $_getinTime',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFFB84542),
                                  ),
                                ),
                                Text(
                                  'Punch Out: $_getoutTime',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFFB84542),
                                  ),
                                ),
                                Text(
                                  'Total Hours: ${_gettotalHours.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFFB84542),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),

              // Regularization Form
              Card(
                color: Color(0xFFFDEEEE),
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
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Date',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(),
                        ),
                        initialValue: DateFormat('yyyy-MM-dd').format(widget.date),
                        readOnly: true,
                      ),
                      SizedBox(height: 16),
                      TextFormField(
  decoration: InputDecoration(
    labelText: 'Punch In Time',
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(),
  ),
  controller: TextEditingController(text: _inTime),
  readOnly: true,
  onTap: () => _selectTime(context, true),
),
SizedBox(height: 16),
TextFormField(
  decoration: InputDecoration(
    labelText: 'Punch Out Time',
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(),
  ),
  controller: TextEditingController(text: _outTime),
  readOnly: true,
  onTap: () => _selectTime(context, false),
),
                      SizedBox(height: 16),
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Reason',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(),
                        ),
                        controller: _reasonController,
                        maxLines: 3,
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
            ],
          ),
        ),
      ),
    );
  }
}


class ApprovalPage extends StatefulWidget {
  final String empId;

  const ApprovalPage({Key? key, required this.empId}) : super(key: key);

  @override
  _ApprovalPageState createState() => _ApprovalPageState();
}

class _ApprovalPageState extends State<ApprovalPage> {
  List<dynamic> pendingEntries = [];
  late String emp_id;

  @override
  void initState() {
    super.initState();
    emp_id = widget.empId;
    fetchPendingEntries();
  }

Future<void> fetchPendingEntries() async {
  final response = await http.get(Uri.parse('http://192.168.10.5:8000/approvals/${widget.empId}/pending'));

  if (response.statusCode == 200) {
    setState(() {
      print('Backend Response: ${response.body}');
      pendingEntries = List<Map<String, dynamic>>.from(jsonDecode(response.body));
    });
  } else {
    // Handle error
    print('Failed to load pending entries');
  }
}


 Future<void> updateApproval(String empId, String date, String newStatus) async {
  final response = await http.post(
    Uri.parse(
      'http://192.168.10.5:8000/approvals/update?empId=$empId&date=$date&approval=$newStatus&approvedBy=${widget.empId}'
    ),
    headers: {'Content-Type': 'application/json'},
  );

  if (response.statusCode == 200) {
    // Update the UI after success
    setState(() {
      pendingEntries.removeWhere((entry) => entry['empId'] == empId && entry['date'] == date);
    });
  } else {
    // Handle error
    print('Failed to update approval');
  }
}



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Approvals'),
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
        child: ListView.builder(
  itemCount: pendingEntries.length,
  itemBuilder: (context, index) {
    var entry = pendingEntries[index];
    return ListTile(
      title: Text('${entry['empId']} - ${entry['date']}'),
      subtitle: Text('${entry['locationIn']} to ${entry['locationOut']} (${entry['totalHours']} hrs)'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.check, color: Colors.green),
            onPressed: () {
              updateApproval(entry['empId'], entry['date'], 'Approved');
            },
          ),
          IconButton(
            icon: Icon(Icons.close, color: Colors.red),
            onPressed: () {
              updateApproval(entry['empId'], entry['date'], 'Rejected');
            },
          ),
        ],
      ),
    );
  },
),

      ),
      bottomNavigationBar: Container(
        color: Colors.black, // Outer container with black margin effect
        margin: EdgeInsets.only(bottom: 10), // This creates the margin
        child: Container(
          height: 60,
          padding: EdgeInsets.symmetric(vertical: 10, horizontal: 24),
          decoration: BoxDecoration(
            color: Color(0xFFFF7043), // Actual bottom bar color
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Home Tab
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LocationCheckerScreen(empId:widget.empId),
                      ),
                    );
                  },
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
              // History Tab
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HistoryScreen(empId: widget.empId),
                      ),
                    );
                  },
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
        ),
      ),
    );
  }
}