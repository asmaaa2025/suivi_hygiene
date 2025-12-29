import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/releve_temperature.dart';

class DBService {
  static Future<Database> initDB() async {
    final path = join(await getDatabasesPath(), 'temp_boucherie.db');
    return openDatabase(
      path,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE releves(
            id TEXT PRIMARY KEY,
            appareil TEXT,
            temperature REAL,
            date TEXT,
            remarque TEXT
          )
        ''');
      },
      version: 1,
    );
  }

  static Future<void> insertReleve(ReleveTemperature r) async {
    final db = await initDB();
    await db.insert('releves', r.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<ReleveTemperature>> getReleves() async {
    final db = await initDB();
    final List<Map<String, dynamic>> maps =
        await db.query('releves', orderBy: 'date DESC');
    return List.generate(
        maps.length, (i) => ReleveTemperature.fromMap(maps[i]));
  }
}
