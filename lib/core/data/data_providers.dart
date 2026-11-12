import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_providers.dart';
import '../config/app_config.dart';
import 'data_gateway.dart';
import 'local_database.dart';
import 'outbox.dart';
import 'sync_engine.dart';

/// Opened in `main()` and injected through `ProviderScope.overrides`.
final localDatabaseProvider = Provider<LocalDatabase>(
  (ref) => throw UnimplementedError(
    'localDatabaseProvider must be overridden in main()',
  ),
);

final supabaseClientProvider = Provider<SupabaseClient?>(
  (ref) => AppConfig.hasSupabase ? Supabase.instance.client : null,
);

/// `auth.uid()` of the signed-in user, or null. Rebuilds on auth changes.
final currentUserIdProvider = Provider<String?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(supabaseClientProvider)?.auth.currentUser?.id;
});

final outboxStoreProvider = Provider<OutboxStore>(
  (ref) => OutboxStore(ref.watch(localDatabaseProvider)),
);

final syncEngineProvider = Provider<SyncEngine?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return null;
  final engine = SyncEngine(client, ref.watch(outboxStoreProvider));
  ref.onDispose(() => unawaited(engine.dispose()));
  unawaited(engine.refresh());
  return engine;
});

final syncStateProvider = StreamProvider<SyncState>((ref) async* {
  final engine = ref.watch(syncEngineProvider);
  if (engine == null) {
    yield const SyncState();
    return;
  }
  yield engine.state;
  yield* engine.states;
});

/// Non-null only when Supabase is configured and a user is signed in.
final dataGatewayProvider = Provider<DataGateway?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  final engine = ref.watch(syncEngineProvider);
  if (client == null || userId == null || engine == null) return null;
  return DataGateway(
    client: client,
    userId: userId,
    engine: engine,
    local: ref.watch(localDatabaseProvider),
    outbox: ref.watch(outboxStoreProvider),
  );
});
