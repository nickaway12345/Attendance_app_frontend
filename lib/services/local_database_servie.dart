import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class LocalDatabaseService {
  static Database? _database;

  // Getter for database instance
  static Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  // Initialize the database and handle version upgrades
  static Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'attendance_new.db');

    return openDatabase(
      path,
      version: 5, // Incremented version to 5 for new changes
      onCreate: (db, version) async {
        // Create the attendance table
        await db.execute('''
          CREATE TABLE attendance (
            emp_id TEXT,
            date TEXT,
            in_time TEXT,
            out_time TEXT,
            total_hours REAL,
            location_in TEXT, -- Changed from location to location_in
            location_out TEXT, -- Added location_out
            day TEXT,
            punch_in_lat REAL,
            punch_in_long REAL,
            punch_out_lat REAL,
            punch_out_long REAL,
            synced INTEGER DEFAULT 0
          )
        ''');

        // Create the regularization table
        await db.execute('''
          CREATE TABLE regularization (
            emp_id TEXT,
            date TEXT,
            in_time TEXT,
            out_time TEXT,
            total_hours REAL,
            location_in TEXT, -- Changed from location to location_in
            location_out TEXT, -- Added location_out
            day TEXT,
            punch_in_lat REAL,
            punch_in_long REAL,
            punch_out_lat REAL,
            punch_out_long REAL,
            approval TEXT,
            approved_by TEXT,
            synced INTEGER DEFAULT 0
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 5) {
          // Rename location to location_in and add location_out in the attendance table
          await db.execute('ALTER TABLE attendance RENAME COLUMN location TO location_in');
          await db.execute('ALTER TABLE attendance ADD COLUMN location_out TEXT');

          // Rename location to location_in and add location_out in the regularization table
          await db.execute('ALTER TABLE regularization RENAME COLUMN location TO location_in');
          await db.execute('ALTER TABLE regularization ADD COLUMN location_out TEXT');
        }
      },
    );
  }

  // Save attendance to SQLite
  static Future<void> saveAttendanceLocally(Map<String, dynamic> attendance) async {
    final db = await database;
    await db.insert('attendance', attendance);
  }

  // Save regularization to SQLite
  static Future<void> saveRegularizationLocally(Map<String, dynamic> regularization) async {
    final db = await database;
    regularization['synced'] = 0; // Mark as unsynced by default
    await db.insert('regularization', regularization);
  }

  // Fetch punch-in data for a specific employee and date from both attendance and regularization tables
static Future<Map<String, dynamic>?> getPunchInDataForDate(String empId, String date) async {
  final db = await database;

  // Check in the attendance table first
  final List<Map<String, dynamic>> attendanceResult = await db.query(
    'attendance',
    columns: ['in_time', 'punch_in_lat', 'punch_in_long'],
    where: 'emp_id = ? AND date = ? AND in_time IS NOT NULL',
    whereArgs: [empId, date],
    limit: 1,
  );

  // If found in attendance, return the result
  if (attendanceResult.isNotEmpty) {
    return attendanceResult.first;
  }

  // Otherwise, check in the regularization table
  final List<Map<String, dynamic>> regularizationResult = await db.query(
    'regularization',
    columns: ['in_time', 'punch_in_lat', 'punch_in_long'],
    where: 'emp_id = ? AND date = ? AND in_time IS NOT NULL',
    whereArgs: [empId, date],
    limit: 1,
  );

  // Return the result from regularization if found, or null if not found in either table
  return regularizationResult.isNotEmpty ? regularizationResult.first : null;
}

// New helper function to check if punch-in data is in the attendance table
static Future<bool> isInAttendance(String empId, String date) async {
  final db = await database;

  final List<Map<String, dynamic>> attendanceResult = await db.query(
    'attendance',
    where: 'emp_id = ? AND date = ?',
    whereArgs: [empId, date],
    limit: 1,
  );

  return attendanceResult.isNotEmpty;
}


  // Get unsynced attendance records
  static Future<List<Map<String, dynamic>>> getUnsyncedAttendance() async {
    final db = await database;
    return await db.query('attendance', where: 'synced = ?', whereArgs: [0]);
  }

  // Get unsynced regularization records
  static Future<List<Map<String, dynamic>>> getUnsyncedRegularization() async {
    final db = await database;
    return await db.query('regularization', where: 'synced = ?', whereArgs: [0]);
  }

  // Mark attendance as synced
  static Future<void> markAttendanceAsSynced(String empId, String date) async {
    final db = await database;
    await db.update(
      'attendance',
      {'synced': 1},
      where: 'emp_id = ? AND date = ?',
      whereArgs: [empId, date],
    );
  }

  // Mark regularization as synced
  static Future<void> markRegularizationAsSynced(String empId, String date) async {
    final db = await database;
    await db.update(
      'regularization',
      {'synced': 1},
      where: 'emp_id = ? AND date = ?',
      whereArgs: [empId, date],
    );
  }

  // Check if a mark-in entry exists for the given date in both attendance and regularization
  static Future<bool> hasMarkInForDate(String empId, String date) async {
    final db = await database;

    // Check in attendance table
    final attendanceResult = await db.query(
      'attendance',
      where: 'emp_id = ? AND date = ? AND in_time IS NOT NULL',
      whereArgs: [empId, date],
    );

    // Check in regularization table
    final regularizationResult = await db.query(
      'regularization',
      where: 'emp_id = ? AND date = ? AND in_time IS NOT NULL',
      whereArgs: [empId, date],
    );

    // Return true if a record is found in either table
    return attendanceResult.isNotEmpty || regularizationResult.isNotEmpty;
  }

  // Check if a mark-out entry exists for the given date in both attendance and regularization
  static Future<bool> hasMarkOutForDate(String empId, String date) async {
    final db = await database;

    // Check in attendance table
    final attendanceResult = await db.query(
      'attendance',
      where: 'emp_id = ? AND date = ? AND out_time IS NOT NULL',
      whereArgs: [empId, date],
    );

    // Check in regularization table
    final regularizationResult = await db.query(
      'regularization',
      where: 'emp_id = ? AND date = ? AND out_time IS NOT NULL',
      whereArgs: [empId, date],
    );

    // Return true if a record is found in either table
    return attendanceResult.isNotEmpty || regularizationResult.isNotEmpty;
  }

  // Delete attendance by date
  static Future<void> deleteAttendanceByDate(String date) async {
    final db = await database;
    await db.delete(
      'attendance',
      where: 'date = ?',
      whereArgs: [date],
    );
  }

  // Delete regularization by date
  static Future<void> deleteRegularizationByDate(String date) async {
    final db = await database;
    await db.delete(
      'regularization',
      where: 'date = ?',
      whereArgs: [date],
    );
  }
}