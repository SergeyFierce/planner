import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../screens/calendar/models.dart';

class LocalDatabase {
  LocalDatabase();

  Database? _db;

  Future<void> init() async {
    if (_db != null) {
      return;
    }

    final basePath = await getDatabasesPath();
    final path = p.join(basePath, 'planner.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            start INTEGER NOT NULL,
            duration_minutes INTEGER NOT NULL,
            description TEXT,
            comment TEXT,
            is_done INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
  }

  Future<List<CalendarEvent>> loadEventsForDay(DateTime day) async {
    final database = _db;
    if (database == null) {
      throw StateError('Database is not initialized');
    }

    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final rows = await database.query(
      'events',
      where: 'start >= ? AND start < ? ',
      whereArgs: <int>[
        startOfDay.millisecondsSinceEpoch,
        endOfDay.millisecondsSinceEpoch,
      ],
      orderBy: 'start ASC',
    );

    return rows.map(CalendarEvent.fromDatabase).toList();
  }

  Future<List<CalendarEvent>> loadAllEvents() async {
    final database = _db;
    if (database == null) {
      throw StateError('Database is not initialized');
    }

    final rows = await database.query(
      'events',
      orderBy: 'start ASC',
    );

    return rows.map(CalendarEvent.fromDatabase).toList();
  }

  Future<int> insertEvent(CalendarEvent event) async {
    final database = _db;
    if (database == null) {
      throw StateError('Database is not initialized');
    }

    final data = event.toDatabaseMap()
      ..remove('id');
    return database.insert('events', data);
  }

  Future<void> updateEvent(CalendarEvent event) async {
    final database = _db;
    if (database == null) {
      throw StateError('Database is not initialized');
    }
    if (event.id == null) {
      return;
    }

    final data = event.toDatabaseMap()
      ..remove('id');
    await database.update(
      'events',
      data,
      where: 'id = ?',
      whereArgs: <int>[event.id!],
    );
  }
}
