import 'offline_queue.dart';
import 'sync_planner.dart';

/// Safe diagnostic summary for the account that is currently authenticated.
class SyncStatus {
  const SyncStatus({required this.pendingCount, required this.blockReason});
  final int pendingCount;
  final SyncBlockReason? blockReason;

  static SyncStatus inspect({
    required OfflineQueue queue,
    required String? authenticatedUserId,
  }) {
    if (authenticatedUserId == null || authenticatedUserId.isEmpty) {
      return const SyncStatus(
          pendingCount: 0, blockReason: SyncBlockReason.signedOut);
    }
    final pending = queue.forUser(authenticatedUserId);
    final plan = const SyncPlanner().plan(
      pending: pending,
      authenticatedUserId: authenticatedUserId,
    );
    return SyncStatus(pendingCount: pending.length, blockReason: plan.reason);
  }
}
