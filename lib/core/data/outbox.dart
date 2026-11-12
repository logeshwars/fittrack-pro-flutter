import 'dart:convert';
import 'dart:math';

import 'package:sqflite/sqflite.dart';

import 'local_database.dart';

enum OutboxKind { upsert, update, delete }

/// One durable remote mutation.
///
/// Idempotency: rows use client-generated UUID primary keys and are sent with
/// `upsert(onConflict: ...)`, so delivering the same operation twice is a
/// harmless overwrite. The operation is deleted only after the server confirms.
class OutboxOp {
  const OutboxOp({
    required this.id,
    required this.userId,
    required this.table,
    required this.kind,
    required this.payload,
    required this.createdAt,
    this.onConflict,
    this.attempts = 0,
    this.nextRetryAt = 0,
    this.dead = false,
    this.lastError,
  });

  final String id;
  final String userId;
  final String table;
  final OutboxKind kind;

  /// Upsert: the full row. Update: the match column plus the changed columns.
  /// Delete: the match columns, e.g. {'id': x}. For updates, [onConflict]
  /// names the match column (default `id`).
  final Map<String, dynamic> payload;
  final String? onConflict;
  final int attempts;
  final int nextRetryAt;
  final bool dead;
  final String? lastError;
  final int createdAt;

  factory OutboxOp.fromRow(Map<String, Object?> row) => OutboxOp(
        id: row['id']! as String,
        userId: row['user_id']! as String,
        table: row['table_name']! as String,
        kind: OutboxKind.values.byName(row['kind']! as String),
        payload: Map<String, dynamic>.from(
          jsonDecode(row['payload']! as String) as Map,
        ),
        onConflict: row['on_conflict'] as String?,
        attempts: (row['attempts'] as int?) ?? 0,
        nextRetryAt: (row['next_retry_at'] as int?) ?? 0,
        dead: row['status'] == 'dead',
        lastError: row['last_error'] as String?,
        createdAt: row['created_at']! as int,
      );
}

/// Pure retry scheduling so it can be unit tested without a database.
class RetryPolicy {
  const RetryPolicy({
    this.maxAttempts = 8,
    this.baseDelay = const Duration(seconds: 5),
    this.maxDelay = const Duration(minutes: 30),
  });

  final int maxAttempts;
  final Duration baseDelay;
  final Duration maxDelay;

  bool isExhausted(int attemptsAfterFailure) =>
      attemptsAfterFailure >= maxAttempts;

  /// Exponential backoff with up to 25% jitter.
  Duration delayFor(int attempts, {Random? random}) {
    final exponent = attempts.clamp(0, 20);
    final raw = baseDelay.inMilliseconds * pow(2, exponent).toInt();
    final capped = min(raw, maxDelay.inMilliseconds);
    final jitter = ((random ?? Random()).nextDouble() * 0.25 * capped).round();
    return Duration(milliseconds: capped + jitter);
  }
}

/// Transactional outbox stored in SQLite.
class OutboxStore {
  OutboxStore(this._local);

  final LocalDatabase _local;
  Database get _db => _local.db;

  Future<void> enqueue(OutboxOp op) async {
    if (op.id.isEmpty || op.userId.isEmpty) {
      throw ArgumentError('Outbox operations need an id and a user id');
    }
    await _db.insert(
      'outbox',
      {
        'id': op.id,
        'user_id': op.userId,
        'table_name': op.table,
        'kind': op.kind.name,
        'payload': jsonEncode(op.payload),
        'on_conflict': op.onConflict,
        'attempts': 0,
        'next_retry_at': 0,
        'status': 'pending',
        'created_at': op.createdAt,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Pending operations for [userId] in creation order (FIFO preserves
  /// parent-before-child ordering, e.g. workout before its sets).
  Future<List<OutboxOp>> pending(String userId) async {
    final rows = await _db.query(
      'outbox',
      where: "user_id = ? AND status = 'pending'",
      whereArgs: [userId],
      orderBy: 'created_at ASC, rowid ASC',
    );
    return rows.map(OutboxOp.fromRow).toList();
  }

  Future<List<OutboxOp>> dead(String userId) async {
    final rows = await _db.query(
      'outbox',
      where: "user_id = ? AND status = 'dead'",
      whereArgs: [userId],
      orderBy: 'created_at ASC',
    );
    return rows.map(OutboxOp.fromRow).toList();
  }

  Future<int> pendingCount(String userId) async {
    final result = await _db.rawQuery(
      "SELECT COUNT(*) AS c FROM outbox WHERE user_id = ? AND status = 'pending'",
      [userId],
    );
    return (result.first['c'] as int?) ?? 0;
  }

  /// Pending upsert rows for [table], so reads can show offline writes.
  Future<List<Map<String, dynamic>>> pendingUpserts(
    String userId,
    String table,
  ) async {
    final rows = await _db.query(
      'outbox',
      where: "user_id = ? AND table_name = ? AND kind = 'upsert' "
          "AND status = 'pending'",
      whereArgs: [userId, table],
      orderBy: 'created_at ASC',
    );
    return rows.map((r) => OutboxOp.fromRow(r).payload).toList();
  }

  /// Pending partial updates for [table] (`id` plus changed columns).
  Future<List<Map<String, dynamic>>> pendingUpdates(
    String userId,
    String table,
  ) async {
    final rows = await _db.query(
      'outbox',
      where: "user_id = ? AND table_name = ? AND kind = 'update' "
          "AND status = 'pending'",
      whereArgs: [userId, table],
      orderBy: 'created_at ASC',
    );
    return rows.map((r) => OutboxOp.fromRow(r).payload).toList();
  }

  /// Ids of rows with a pending delete, so reads can hide them.
  Future<Set<String>> pendingDeleteIds(String userId, String table) async {
    final rows = await _db.query(
      'outbox',
      where: "user_id = ? AND table_name = ? AND kind = 'delete' "
          "AND status = 'pending'",
      whereArgs: [userId, table],
    );
    return rows
        .map((r) => OutboxOp.fromRow(r).payload['id']?.toString())
        .whereType<String>()
        .toSet();
  }

  /// Removes an operation after the server acknowledged it.
  Future<void> acknowledge(String id) async {
    await _db.delete('outbox', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> recordFailure(
    OutboxOp op, {
    required String error,
    required Duration retryIn,
    required bool dead,
  }) async {
    await _db.update(
      'outbox',
      {
        'attempts': op.attempts + 1,
        'next_retry_at': DateTime.now().add(retryIn).millisecondsSinceEpoch,
        'status': dead ? 'dead' : 'pending',
        'last_error': error.length > 500 ? error.substring(0, 500) : error,
      },
      where: 'id = ?',
      whereArgs: [op.id],
    );
  }

  /// Puts a dead-lettered operation back in the queue (manual retry).
  Future<void> revive(String id) async {
    await _db.update(
      'outbox',
      {'status': 'pending', 'attempts': 0, 'next_retry_at': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Drops every operation of [userId] (explicit user action only).
  Future<void> discardAll(String userId) async {
    await _db.delete('outbox', where: 'user_id = ?', whereArgs: [userId]);
  }
}
