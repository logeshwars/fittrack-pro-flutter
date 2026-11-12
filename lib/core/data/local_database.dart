import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// On-device SQLite database: the offline outbox plus a read-through JSON cache.
///
/// Every row carries the owning `user_id` so an account switch can never read
/// or replay another account's data.
class LocalDatabase {
  LocalDatabase._(this.db);

  final Database db;

  static const _version = 1;

  static Future<LocalDatabase> open({String? pathOverride}) async {
    final path =
        pathOverride ?? p.join(await getDatabasesPath(), 'fittrack.db');
    final db = await openDatabase(
      path,
      version: _version,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE outbox (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            table_name TEXT NOT NULL,
            kind TEXT NOT NULL CHECK (kind IN ('upsert','update','delete')),
            payload TEXT NOT NULL,
            on_conflict TEXT,
            attempts INTEGER NOT NULL DEFAULT 0,
            next_retry_at INTEGER NOT NULL DEFAULT 0,
            status TEXT NOT NULL DEFAULT 'pending'
              CHECK (status IN ('pending','dead')),
            last_error TEXT,
            created_at INTEGER NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_outbox_user ON outbox(user_id, status, created_at)',
        );
        await db.execute('''
          CREATE TABLE row_cache (
            user_id TEXT NOT NULL,
            cache_key TEXT NOT NULL,
            json TEXT NOT NULL,
            updated_at INTEGER NOT NULL,
            PRIMARY KEY (user_id, cache_key)
          )
        ''');
      },
    );
    return LocalDatabase._(db);
  }

  /// Stores a JSON-encodable value for [key].
  Future<void> putCache(String userId, String key, Object value) async {
    await db.insert(
      'row_cache',
      {
        'user_id': userId,
        'cache_key': key,
        'json': jsonEncode(value),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns the decoded cached value, or null when absent or corrupt.
  Future<Object?> getCache(String userId, String key) async {
    final rows = await db.query(
      'row_cache',
      columns: ['json'],
      where: 'user_id = ? AND cache_key = ?',
      whereArgs: [userId, key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    try {
      return jsonDecode(rows.first['json']! as String);
    } catch (_) {
      return null;
    }
  }

  /// Removes everything stored for [userId] (used on sign-out).
  Future<void> clearUser(String userId) async {
    await db.transaction((txn) async {
      await txn.delete('row_cache', where: 'user_id = ?', whereArgs: [userId]);
    });
  }

  Future<void> close() => db.close();
}
