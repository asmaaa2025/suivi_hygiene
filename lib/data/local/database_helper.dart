// STUB: Replace with real implementation
// TODO: Implement full database schema in onCreate
// TODO: Add proper table definitions (releves, appareils, receptions, etc.)
// TODO: Add migration logic in onUpgrade
// TODO: Implement proper error handling
// TODO: Add transaction support for batch operations
// TODO: Consider if this is still needed (app may be Supabase-only now)

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Database helper stub for local SQLite database
/// This is a minimal implementation to satisfy compilation
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'app.db';
  static const _dbVersion = 1;

  Database? _db;

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        // TODO: if you have real schema, move it here.
        // Keep empty for now to compile safely.
      },
    );
    return _db!;
  }

  // Stub methods for compatibility
  Future<List<Map<String, dynamic>>> getReleves() async {
    final db = await database;
    return db.query('releves', orderBy: 'date DESC');
  }

  Future<List<Map<String, dynamic>>> getAppareils() async {
    final db = await database;
    return db.query('appareils', orderBy: 'nom');
  }

  Future<List<Map<String, dynamic>>> getReceptions() async {
    final db = await database;
    return db.query('receptions', orderBy: 'date DESC');
  }
}
