import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme/theme_controller.dart';
import '../features/subscription/application/subscription_controller.dart';
import 'router.dart';

class FitTrackApp extends ConsumerWidget {
  const FitTrackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'FitTrack Pro',
      debugShowCheckedModeBanner: false,
      supportedLocales: AppStrings.supported.map((code) => Locale(code)).toList(),
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: appRouter,
      builder: (context, child) =>
          SubscriptionLifecycle(child: child ?? const SizedBox.shrink()),
    );
  }
}
