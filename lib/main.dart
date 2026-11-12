import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/app.dart';
import 'core/config/app_config.dart';
import 'core/data/data_providers.dart';
import 'core/data/local_database.dart';
import 'core/data/sync_lifecycle.dart';
import 'core/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  initialThemeMode = themeModeFromPreference(
    preferences.getString('fittrack_theme_preference'),
  );
  if (AppConfig.hasSupabase) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
  }
  final localDatabase = await LocalDatabase.open();
  runApp(
    ProviderScope(
      overrides: [localDatabaseProvider.overrideWithValue(localDatabase)],
      child: const SyncLifecycle(child: FitTrackApp()),
    ),
  );
}
