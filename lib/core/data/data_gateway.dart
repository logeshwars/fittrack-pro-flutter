import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'local_database.dart';
import 'outbox.dart';
import 'sync_engine.dart';

typedef Json = Map<String, dynamic>;

/// Merges server rows with not-yet-synced local writes.
///
/// Pending upserts replace server rows with the same `id` (or are appended),
/// and rows with a pending delete are hidden. Pure so it can be unit tested.
List<Json> mergeRows(
  List<Json> server,
  List<Json> pendingUpserts,
  Set<String> pendingDeletes, {
  List<Json> pendingUpdates = const [],
  String idKey = 'id',
}) {
  final byId = <String, Json>{};
  final order = <String>[];
  for (final row in server) {
    final id = row[idKey]?.toString();
    if (id == null) continue;
    byId[id] = row;
    order.add(id);
  }
  for (final row in pendingUpserts) {
    final id = row[idKey]?.toString();
    if (id == null) continue;
    if (!byId.containsKey(id)) order.insert(0, id);
    byId[id] = {...?byId[id], ...row};
  }
  for (final row in pendingUpdates) {
    final id = row[idKey]?.toString();
    if (id == null || !byId.containsKey(id)) continue;
    byId[id] = {...byId[id]!, ...row};
  }
  return [
    for (final id in order)
      if (!pendingDeletes.contains(id)) byId[id]!,
  ];
}

/// Single entry point for repositories: reads fall back to the on-device cache
/// when offline, and writes go through the durable outbox.
class DataGateway {
  DataGateway({
    required this.client,
    required this.userId,
    required this.engine,
    required this.local,
    required this.outbox,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final SupabaseClient client;

  /// `auth.uid()` of the signed-in user. Stored in the legacy-named
  /// `google_user_id` column of every table.
  final String userId;
  final SyncEngine engine;
  final LocalDatabase local;
  final OutboxStore outbox;
  final Uuid _uuid;

  String newId() => _uuid.v4();

  /// Runs [fetch]; on success refreshes the cache, on failure serves the cache.
  Future<List<Json>> cachedList(
    String cacheKey,
    Future<List<Json>> Function() fetch,
  ) async {
    try {
      final rows = await fetch();
      await local.putCache(userId, cacheKey, rows);
      return rows;
    } catch (_) {
      final cached = await local.getCache(userId, cacheKey);
      if (cached is List) {
        return [
          for (final item in cached) Json.from(item as Map),
        ];
      }
      rethrow;
    }
  }

  Future<Json?> cachedRow(
    String cacheKey,
    Future<Json?> Function() fetch,
  ) async {
    try {
      final row = await fetch();
      if (row != null) await local.putCache(userId, cacheKey, row);
      return row;
    } catch (_) {
      final cached = await local.getCache(userId, cacheKey);
      if (cached is Map) return Json.from(cached);
      rethrow;
    }
  }

  /// Cached list merged with pending local writes for [table].
  Future<List<Json>> mergedList(
    String table,
    String cacheKey,
    Future<List<Json>> Function() fetch, {
    bool Function(Json row)? keep,
  }) async {
    final server = await cachedList(cacheKey, fetch);
    final pending = await outbox.pendingUpserts(userId, table);
    final deleted = await outbox.pendingDeleteIds(userId, table);
    final updates = await outbox.pendingUpdates(userId, table);
    final merged = mergeRows(
      server,
      pending,
      deleted,
      pendingUpdates: updates,
    );
    return keep == null ? merged : merged.where(keep).toList();
  }

  /// Queues an insert-or-update. The row is stamped with the owner.
  Future<void> upsert(String table, Json row, {String? onConflict}) {
    return engine.enqueue(
      OutboxOp(
        id: newId(),
        userId: userId,
        table: table,
        kind: OutboxKind.upsert,
        payload: {...row, 'google_user_id': userId},
        onConflict: onConflict,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  /// Queues a partial update of the row whose `id` is [id].
  ///
  /// [matchColumn] is the column identifying the row (`id` for most tables,
  /// `google_user_id` for `profiles` and `user_gamification`).
  Future<void> update(
    String table,
    String id,
    Json fields, {
    String matchColumn = 'id',
  }) {
    return engine.enqueue(
      OutboxOp(
        id: newId(),
        userId: userId,
        table: table,
        kind: OutboxKind.update,
        payload: {...fields, matchColumn: id},
        onConflict: matchColumn,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  /// Queues a delete of the row whose `id` is [id] (owner-scoped on replay).
  Future<void> delete(String table, String id) {
    return engine.enqueue(
      OutboxOp(
        id: newId(),
        userId: userId,
        table: table,
        kind: OutboxKind.delete,
        payload: {'id': id},
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}
