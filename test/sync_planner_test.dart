import 'package:flutter_test/flutter_test.dart';
import 'package:fittrack_pro/core/offline/offline_operation.dart';
import 'package:fittrack_pro/core/offline/sync_planner.dart';

OfflineOperation operation(String id, String user, {int attempts = 0}) =>
    OfflineOperation(
      id: id,
      userId: user,
      type: OfflineOperationType.logFood,
      payload: const {'food_name': 'Rice'},
      createdAt: DateTime.utc(2026, 1, 1),
      attempts: attempts,
    );

void main() {
  test('replay stays disabled by default', () {
    final plan = const SyncPlanner().plan(
      pending: [operation('1', 'alice')],
      authenticatedUserId: 'alice',
    );
    expect(plan.ready, isEmpty);
    expect(plan.reason, SyncBlockReason.writesNotApproved);
  });

  test('rejects mixed-user batches even with approval', () {
    final plan = const SyncPlanner().plan(
      pending: [operation('1', 'alice'), operation('2', 'bob')],
      authenticatedUserId: 'alice',
      writesApproved: true,
    );
    expect(plan.ready, isEmpty);
    expect(plan.reason, SyncBlockReason.identityMismatch);
  });

  test('requires sign-in and quarantines exhausted retries', () {
    final pending = [
      operation('1', 'alice'),
      operation('2', 'alice', attempts: 5)
    ];
    final signedOut = const SyncPlanner().plan(
      pending: pending,
      authenticatedUserId: null,
      writesApproved: true,
    );
    expect(signedOut.reason, SyncBlockReason.signedOut);
    final plan = const SyncPlanner().plan(
      pending: pending,
      authenticatedUserId: 'alice',
      writesApproved: true,
    );
    expect(plan.ready.single.id, '1');
    expect(plan.blocked.single.id, '2');
    expect(plan.reason, SyncBlockReason.retryLimit);
  });
}
