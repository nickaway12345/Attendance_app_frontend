import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
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
  // static Future<Database> _initDatabase() async {
  //   Directory documentsDirectory = await getApplicationDocumentsDirectory();
  //   String path = join(documentsDirectory.path, 'attendance_new.db');

  //   return openDatabase(
  //     path,
  //     version: 7, // Incremented version to 7 for mediclaim card table
  //     onCreate: (db, version) async {
  //       // Create the attendance table
  //       await db.execute('''
  //         CREATE TABLE attendance (
  //           emp_id TEXT,
  //           date TEXT,
  //           in_time TEXT,
  //           out_time TEXT,
  //           total_hours REAL,
  //           location_in TEXT,
  //           location_out TEXT,
  //           day TEXT,
  //           punch_in_lat REAL,
  //           punch_in_long REAL,
  //           punch_out_lat REAL,
  //           punch_out_long REAL,
  //           synced INTEGER DEFAULT 0
  //         )
  //       ''');

  //       // Create the regularization table
  //       await db.execute('''
  //         CREATE TABLE regularization (
  //           emp_id TEXT,
  //           date TEXT,
  //           in_time TEXT,
  //           out_time TEXT,
  //           total_hours REAL,
  //           location_in TEXT,
  //           location_out TEXT,
  //           day TEXT,
  //           punch_in_lat REAL,
  //           punch_in_long REAL,
  //           punch_out_lat REAL,
  //           punch_out_long REAL,
  //           approval TEXT,
  //           approved_by TEXT,
  //           synced INTEGER DEFAULT 0
  //         )
  //       ''');

  //       // Create the attendance_service table with shift_number
  //       await db.execute('''
  //         CREATE TABLE attendance_service (
  //           emp_id TEXT,
  //           date TEXT,
  //           in_time TEXT,
  //           out_time TEXT,
  //           total_hours REAL,
  //           location_in TEXT,
  //           location_out TEXT,
  //           punch_in_lat REAL,
  //           punch_in_long REAL,
  //           punch_out_lat REAL,
  //           punch_out_long REAL,
  //           shift_number INTEGER,
  //           synced INTEGER DEFAULT 0
  //         )
  //       ''');

  //       // Create the mediclaim_cards table
  //       await db.execute('''
  //         CREATE TABLE mediclaim_cards (
  //           emp_id TEXT PRIMARY KEY,
  //           file_path TEXT NOT NULL,
  //           uploaded_at TEXT NOT NULL
  //         )
  //       ''');
  //     },
  //     onUpgrade: (db, oldVersion, newVersion) async {
  //       if (oldVersion < 6) {
  //         await db.execute('''
  //           CREATE TABLE attendance_service (
  //             emp_id TEXT,
  //             date TEXT,
  //             in_time TEXT,
  //             out_time TEXT,
  //             total_hours REAL,
  //             location_in TEXT,
  //             location_out TEXT,
  //             punch_in_lat REAL,
  //             punch_in_long REAL,
  //             punch_out_lat REAL,
  //             punch_out_long REAL,
  //             shift_number INTEGER,
  //             synced INTEGER DEFAULT 0
  //           )
  //         ''');
  //       }
  //       if (oldVersion < 7) {
  //         await db.execute('''
  //           CREATE TABLE mediclaim_cards (
  //             emp_id TEXT PRIMARY KEY,
  //             file_path TEXT NOT NULL,
  //             uploaded_at TEXT NOT NULL
  //           )
  //         ''');
  //       }
  //     },
  //   );
  // }
  static Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String dbPath = path.join(documentsDirectory.path, 'attendance_new.db');

    return openDatabase(
      dbPath,
      version: 8, // Incremented version to add profile_images table
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE attendance (
            emp_id TEXT,
            date TEXT,
            in_time TEXT,
            out_time TEXT,
            total_hours REAL,
            location_in TEXT,
            location_out TEXT,
            day TEXT,
            punch_in_lat REAL,
            punch_in_long REAL,
            punch_out_lat REAL,
            punch_out_long REAL,
            synced INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE regularization (
            emp_id TEXT,
            date TEXT,
            in_time TEXT,
            out_time TEXT,
            total_hours REAL,
            location_in TEXT,
            location_out TEXT,
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
        await db.execute('''
          CREATE TABLE attendance_service (
            emp_id TEXT,
            date TEXT,
            in_time TEXT,
            out_time TEXT,
            total_hours REAL,
            location_in TEXT,
            location_out TEXT,
            punch_in_lat REAL,
            punch_in_long REAL,
            punch_out_lat REAL,
            punch_out_long REAL,
            shift_number INTEGER,
            synced INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE mediclaim_cards (
            emp_id TEXT PRIMARY KEY,
            file_path TEXT NOT NULL,
            uploaded_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE profile_images (
            emp_id TEXT PRIMARY KEY,
            file_path TEXT NOT NULL,
            uploaded_at TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 8) {
          await db.execute('''
            CREATE TABLE profile_images (
              emp_id TEXT PRIMARY KEY,
              file_path TEXT NOT NULL,
              uploaded_at TEXT NOT NULL
            )
          ''');
        }
      },
    );
  }

  static Future<void> saveProfileImage(String empId, String imagePath) async {
    final db = await database;
    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'profile_$empId.jpg';
    final newPath = '${directory.path}/$fileName';
    
    await File(imagePath).copy(newPath);
    
    await db.insert(
      'profile_images',
      {
        'emp_id': empId,
        'file_path': newPath,
        'uploaded_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<String?> getProfileImagePath(String empId) async {
    final db = await database;
    final result = await db.query(
      'profile_images',
      where: 'emp_id = ?',
      whereArgs: [empId],
      limit: 1,
    );
    
    if (result.isNotEmpty) {
      return result.first['file_path'] as String?;
    }
    return null;
  }

  static Future<void> saveMediclaimCard(String empId, String imagePath) async {
    final db = await database;
    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'mediclaim_$empId.jpg';
    final newPath = '${directory.path}/$fileName';
    
    // Copy the file to app's documents directory
    await File(imagePath).copy(newPath);
    
    // Save the path in database
    await db.insert(
      'mediclaim_cards',
      {
        'emp_id': empId,
        'file_path': newPath,
        'uploaded_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<String?> getMediclaimCardPath(String empId) async {
    final db = await database;
    final result = await db.query(
      'mediclaim_cards',
      where: 'emp_id = ?',
      whereArgs: [empId],
      limit: 1,
    );
    
    if (result.isNotEmpty) {
      return result.first['file_path'] as String?;
    }
    return null;
  }

  static Future<void> deleteMediclaimCard(String empId) async {
    final db = await database;
    // First get the file path to delete the actual file
    final path = await getMediclaimCardPath(empId);
    if (path != null) {
      try {
        await File(path).delete();
      } catch (e) {
        print('Error deleting mediclaim card file: $e');
      }
    }
    // Then delete the database record
    await db.delete(
      'mediclaim_cards',
      where: 'emp_id = ?',
      whereArgs: [empId],
    );
  }

  static Future<bool> hasMediclaimCard(String empId) async {
    final db = await database;
    final result = await db.query(
      'mediclaim_cards',
      where: 'emp_id = ?',
      whereArgs: [empId],
      limit: 1,
    );
    return result.isNotEmpty;
  }


  // Save attendance_service data locally
  static Future<void> saveAttendanceServiceLocally(Map<String, dynamic> attendanceData) async {
  final db = await database;
  await db.insert(
    'attendance_service',
    attendanceData,
    conflictAlgorithm: ConflictAlgorithm.replace, // Update existing record if conflict occurs
  );
}

  // Get unsynced attendance_service records
  static Future<List<Map<String, dynamic>>> getUnsyncedAttendanceService() async {
    final db = await database;
    return await db.query('attendance_service', where: 'synced = ?', whereArgs: [0]);
  }

  // Mark attendance_service record as synced
 static Future<void> markAttendanceServiceAsSynced(String empId, String date, int shiftNumber) async {
  final db = await database;
  await db.update(
    'attendance_service',
    {'synced': 1},
    where: 'emp_id = ? AND date = ? AND shift_number = ?',
    whereArgs: [empId, date, shiftNumber],
  );
}

  // Check if a mark-in entry exists for the given date in attendance_service
static Future<bool> hasMarkInForDateInService(String empId, String date, int shiftNumber) async {
  final db = await database;
  final result = await db.query(
    'attendance_service',
    where: 'emp_id = ? AND date = ? AND shift_number = ? AND in_time IS NOT NULL',
    whereArgs: [empId, date, shiftNumber],
  );
  return result.isNotEmpty;
}

  // Check if a mark-out entry exists for the given date in attendance_service
static Future<bool> hasMarkOutForDateInService(String empId, String date, int shiftNumber) async {
  final db = await database;
  final result = await db.query(
    'attendance_service',
    where: 'emp_id = ? AND date = ? AND shift_number = ? AND out_time IS NOT NULL',
    whereArgs: [empId, date, shiftNumber],
  );
  return result.isNotEmpty;
}

  // Delete attendance_service records for a specific date
  static Future<void> deleteAttendanceServiceByDate(String empId, String date) async {
    final db = await database;
    await db.delete(
      'attendance_service',
      where: 'emp_id = ? AND date = ?',
      whereArgs: [empId, date],
    );
  }

  // Fetch punch-in data for a specific employee and date from attendance_service
  static Future<Map<String, dynamic>?> getPunchInDataForDateInService(String empId, String date) async {
    final db = await database;
    final result = await db.query(
      'attendance_service',
      columns: ['in_time', 'punch_in_lat', 'punch_in_long'],
      where: 'emp_id = ? AND date = ? AND in_time IS NOT NULL',
      whereArgs: [empId, date],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  // Check if a record exists in attendance_service for the given date
  static Future<bool> isInAttendanceService(String empId, String date) async {
    final db = await database;
    final result = await db.query(
      'attendance_service',
      where: 'emp_id = ? AND date = ?',
      whereArgs: [empId, date],
      limit: 1,
    );
    return result.isNotEmpty;
  }
  static Future<void> deleteEntriesForDate(String empId, String date) async {
  final db = await database;

  // Delete entries from the attendance table
  await db.delete(
    'attendance',
    where: 'emp_id = ? AND date = ?',
    whereArgs: [empId, date],
  );

  // Delete entries from the regularization table
  await db.delete(
    'regularization',
    where: 'emp_id = ? AND date = ?',
    whereArgs: [empId, date],
  );
}

static Future<void> saveAttendanceLocally(Map<String, dynamic> attendance) async {
  final db = await database;
  attendance['synced'] = 0; // Mark as unsynced by default
  await db.insert('attendance', attendance);
}

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

static Future<void> markAttendanceAsSynced(String empId, String date) async {
  final db = await database;
  await db.update(
    'attendance',
    {'synced': 1},
    where: 'emp_id = ? AND date = ?',
    whereArgs: [empId, date],
  );
}

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