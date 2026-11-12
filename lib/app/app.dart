import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../core/l10n/language_controller.dart';
import '../core/l10n/translations.dart';
import '../core/theme/theme_controller.dart';
import '../features/reminders/application/reminders_controller.dart';
import '../features/subscription/application/subscription_controller.dart';
import 'router.dart';

class FitTrackApp extends ConsumerWidget {
  const FitTrackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    // Loads saved reminders and re-registers them with the OS on every launch.
    ref.listen(remindersProvider, (_, __) {});
    return MaterialApp.router(
      title: 'FitTrack Pro',
      debugShowCheckedModeBanner: false,
      locale: Locale(ref.watch(languageProvider)),
      supportedLocales: [for (final l in supportedLanguages) Locale(l.code)],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: appRouter,
      builder: (context, child) => Consumer(
        builder: (context, ref, _) {
          final translations = ref.watch(translationsProvider).valueOrNull;
          // English strings are bundled; wait the few ms it takes to read them.
          if (translations == null) {
            return const SizedBox.shrink();
          }
          return TranslationsScope(
            translations: translations,
            child:
                SubscriptionLifecycle(child: child ?? const SizedBox.shrink()),
          );
        },
      ),
    );
  }
}
