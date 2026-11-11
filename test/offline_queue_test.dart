import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fittrack_pro/core/offline/offline_operation.dart';
import 'package:fittrack_pro/core/offline/offline_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('queue persists operations, deduplicates IDs and isolates users', () async {
    final prefs = await SharedPreferences.getInstance();
    final queue = OfflineQueue(prefs);
    final op = OfflineOperation(
      id: 'stable-id', userId: 'user-a', type: OfflineOperationType.logWeight,
      payload: {'weight_kg': 75.5}, createdAt: DateTime.utc(2026, 1, 1),
    );
    await queue.enqueue(op);
    await queue.enqueue(op);
    expect(queue.pending, hasLength(1));
    expect(queue.forUser('user-b'), isEmpty);
    expect(queue.forUser('user-a').single.payload['weight_kg'], 75.5);
    await queue.incrementAttempts('stable-id', userId: 'user-a');
    expect(queue.pending.single.attempts, 1);
    await queue.remove('stable-id', userId: 'user-b');
    expect(queue.pending, hasLength(1));
    await queue.remove('stable-id', userId: 'user-a');
    expect(queue.pending, isEmpty);
  });

  test('offline operation serialization retains stable identity', () {
    final operation = OfflineOperation(
      id: 'id', userId: 'user', type: OfflineOperationType.logSet,
      payload: {'reps': 8}, createdAt: DateTime.utc(2026, 2, 1),
    );
    final restored = OfflineOperation.decode(operation.encode());
    expect(restored.id, operation.id);
    expect(restored.type, OfflineOperationType.logSet);
    expect(restored.createdAt, operation.createdAt);
  });
}
