import 'offline_operation.dart';

/// Pure, read-only planning layer. It never executes mutations.
enum SyncBlockReason {
  signedOut,
  identityMismatch,
  writesNotApproved,
  retryLimit
}

class SyncPlan {
  const SyncPlan(
      {required this.ready, required this.blocked, required this.reason});
  final List<OfflineOperation> ready;
  final List<OfflineOperation> blocked;
  final SyncBlockReason? reason;
}

/// Prevents cross-account replay and refuses all writes by default.
///
/// The caller must only set writesApproved after deployed RLS, authenticated
/// identity mapping, and server-side idempotency have been verified.
class SyncPlanner {
  const SyncPlanner({this.maxAttempts = 5});
  final int maxAttempts;

  SyncPlan plan({
    required List<OfflineOperation> pending,
    required String? authenticatedUserId,
    bool writesApproved = false,
  }) {
    if (authenticatedUserId == null || authenticatedUserId.isEmpty) {
      return SyncPlan(
          ready: const [],
          blocked: List.unmodifiable(pending),
          reason: SyncBlockReason.signedOut);
    }
    if (pending.any((operation) => operation.userId != authenticatedUserId)) {
      return SyncPlan(
          ready: const [],
          blocked: List.unmodifiable(pending),
          reason: SyncBlockReason.identityMismatch);
    }
    if (!writesApproved) {
      return SyncPlan(
          ready: const [],
          blocked: List.unmodifiable(pending),
          reason: SyncBlockReason.writesNotApproved);
    }
    final ready = <OfflineOperation>[];
    final blocked = <OfflineOperation>[];
    for (final operation in pending) {
      if (operation.attempts >= maxAttempts) {
        blocked.add(operation);
      } else {
        ready.add(operation);
      }
    }
    return SyncPlan(
      ready: List.unmodifiable(ready),
      blocked: List.unmodifiable(blocked),
      reason: blocked.isEmpty ? null : SyncBlockReason.retryLimit,
    );
  }
}
