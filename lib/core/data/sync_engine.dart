import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'outbox.dart';

enum FailureKind {
  /// Offline, expired session, server unreachable: stop and retry later.
  transient,

  /// This operation failed but may succeed later (parent row not synced yet).
  retryable,

  /// Will never succeed (RLS denial, constraint or type violation).
  permanent,
}

/// Maps a thrown error to a retry decision. Pure, so it can be unit tested.
FailureKind classifyFailure(Object error) {
  if (error is PostgrestException) {
    final code = error.code ?? '';
    if (code == 'PGRST301' || code == 'PGRST302' || code == '401') {
      return FailureKind.transient;
    }
    if (code.startsWith('08')) return FailureKind.transient;
    if (code == '23503') return FailureKind.retryable;
    if (code == '40001' || code == '40P01' || code == '57014') {
      return FailureKind.retryable;
    }
    if (code.startsWith('53')) return FailureKind.retryable;
    if (code == '42501' ||
        code == '23502' ||
        code == '23505' ||
        code == '23514' ||
        code.startsWith('22') ||
        code.startsWith('42')) {
      return FailureKind.permanent;
    }
    return FailureKind.retryable;
  }
  if (error is AuthException) return FailureKind.transient;
  return FailureKind.transient;
}

class SyncState {
  const SyncState({
    this.pending = 0,
    this.dead = 0,
    this.syncing = false,
    this.lastError,
  });

  final int pending;
  final int dead;
  final bool syncing;
  final String? lastError;

  SyncState copyWith({
    int? pending,
    int? dead,
    bool? syncing,
    String? lastError,
    bool clearError = false,
  }) =>
      SyncState(
        pending: pending ?? this.pending,
        dead: dead ?? this.dead,
        syncing: syncing ?? this.syncing,
        lastError: clearError ? null : (lastError ?? this.lastError),
      );
}

/// Replays the outbox against Supabase.
///
/// Safety rules (see docs/OFFLINE_SYNC_DESIGN.md):
///  * only the signed-in user's operations are replayed;
///  * an operation whose row names a different user is dead-lettered;
///  * operations are removed only after the server acknowledges them;
///  * a transient failure stops the run so ordering is preserved.
class SyncEngine {
  SyncEngine(
    this._client,
    this._store, {
    RetryPolicy policy = const RetryPolicy(),
  }) : _policy = policy;

  final SupabaseClient _client;
  final OutboxStore _store;
  final RetryPolicy _policy;

  final _controller = StreamController<SyncState>.broadcast();
  SyncState _state = const SyncState();
  bool _flushing = false;

  SyncState get state => _state;
  Stream<SyncState> get states => _controller.stream;

  void _emit(SyncState next) {
    _state = next;
    if (!_controller.isClosed) _controller.add(next);
  }

  /// Refreshes the counters without replaying anything.
  Future<void> refresh() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      _emit(const SyncState());
      return;
    }
    _emit(_state.copyWith(
      pending: await _store.pendingCount(userId),
      dead: (await _store.dead(userId)).length,
    ));
  }

  /// Queues a mutation and tries to deliver it immediately.
  Future<void> enqueue(OutboxOp op) async {
    await _store.enqueue(op);
    await refresh();
    unawaited(flush());
  }

  /// Replays due operations. Safe to call at any time and from anywhere.
  Future<void> flush() async {
    if (_flushing) return;
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    _flushing = true;
    _emit(_state.copyWith(syncing: true, clearError: true));
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final op in await _store.pending(userId)) {
        if (op.userId != userId) continue;
        if (op.nextRetryAt > now) {
          // Keep FIFO order: a child must not overtake a waiting parent.
          break;
        }
        if (!_ownsRow(op, userId)) {
          await _store.recordFailure(
            op,
            error: 'Row belongs to a different user',
            retryIn: Duration.zero,
            dead: true,
          );
          continue;
        }
        try {
          await _execute(op);
          await _store.acknowledge(op.id);
        } catch (error) {
          final kind = classifyFailure(error);
          final message = error.toString();
          if (kind == FailureKind.transient) {
            await _store.recordFailure(
              op,
              error: message,
              retryIn: _policy.delayFor(op.attempts),
              dead: false,
            );
            _emit(_state.copyWith(lastError: message));
            break;
          }
          final exhausted =
              kind == FailureKind.permanent || _policy.isExhausted(op.attempts + 1);
          await _store.recordFailure(
            op,
            error: message,
            retryIn: _policy.delayFor(op.attempts),
            dead: exhausted,
          );
          _emit(_state.copyWith(lastError: message));
          if (!exhausted) break;
        }
      }
    } finally {
      _flushing = false;
      await refresh();
      _emit(_state.copyWith(syncing: false));
    }
  }

  bool _ownsRow(OutboxOp op, String userId) {
    final owner = op.payload['google_user_id'];
    return owner == null || owner == userId;
  }

  Future<void> _execute(OutboxOp op) async {
    switch (op.kind) {
      case OutboxKind.upsert:
        await _client
            .from(op.table)
            .upsert(op.payload, onConflict: op.onConflict ?? 'id');
      case OutboxKind.update:
        final matchColumn = op.onConflict ?? 'id';
        final fields = Map<String, dynamic>.from(op.payload);
        final match = fields.remove(matchColumn);
        if (match == null) {
          throw ArgumentError('update operation without $matchColumn');
        }
        await _client
            .from(op.table)
            .update(fields)
            .eq(matchColumn, match as Object)
            .eq('google_user_id', op.userId);
      case OutboxKind.delete:
        var query = _client.from(op.table).delete();
        for (final entry in op.payload.entries) {
          query = query.eq(entry.key, entry.value as Object);
        }
        // Always scope deletes to the owner as a second line of defence.
        await query.eq('google_user_id', op.userId);
    }
  }

  Future<void> dispose() => _controller.close();
}
