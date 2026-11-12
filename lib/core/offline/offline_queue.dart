import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'offline_operation.dart';

/// Prototype persistent FIFO queue. Replay is intentionally NOT wired to
/// Supabase until identity mapping and idempotent write semantics are audited.
/// SharedPreferences is temporary; move to transactional SQLite before release.
class OfflineQueue {
  OfflineQueue(this._preferences);
  final SharedPreferences _preferences;
  static const storageKey = 'fittrack_offline_queue_v1';

  List<OfflineOperation> get pending {
    final raw = _preferences.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((item) => OfflineOperation.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<void> enqueue(OfflineOperation operation) async {
    if (operation.id.isEmpty || operation.userId.isEmpty) {
      throw ArgumentError('Operation and user IDs are required');
    }
    final items = pending;
    if (items.any((item) => item.id == operation.id)) {
      return;
    }
    items.add(operation);
    await _save(items);
  }

  Future<void> remove(String operationId, {required String userId}) async {
    final items = pending;
    if (!items.any((item) => item.id == operationId && item.userId == userId)) {
      return;
    }
    items.removeWhere((item) => item.id == operationId && item.userId == userId);
    await _save(items);
  }

  Future<void> incrementAttempts(String operationId, {required String userId}) async {
    final items = pending;
    final index = items.indexWhere((item) => item.id == operationId && item.userId == userId);
    if (index < 0) {
      return;
    }
    items[index] = items[index].withAttempts(items[index].attempts + 1);
    await _save(items);
  }

  List<OfflineOperation> forUser(String userId) =>
      pending.where((operation) => operation.userId == userId).toList();

  Future<void> _save(List<OfflineOperation> operations) async {
    final success = await _preferences.setString(storageKey, jsonEncode(operations.map((op) => op.toJson()).toList()));
    if (!success) {
      throw StateError('Failed to persist offline queue');
    }
  }
}
