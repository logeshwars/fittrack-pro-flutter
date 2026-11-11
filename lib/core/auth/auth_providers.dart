import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import 'auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository?>((ref) {
  if (!AppConfig.hasSupabase) return null;
  return AuthRepository(Supabase.instance.client);
});

final authStateProvider = StreamProvider<AuthState?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository?.changes ?? Stream<AuthState?>.value(null);
});
