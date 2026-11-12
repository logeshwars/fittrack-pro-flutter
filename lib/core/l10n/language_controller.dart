import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'translations.dart';

const languagePrefsKey = 'fittrack_language';

/// Selected UI language; defaults to the device language when supported.
final languageProvider =
    NotifierProvider<LanguageController, String>(LanguageController.new);

/// Bundled strings for [languageProvider].
final translationsProvider = FutureProvider<Translations>((ref) {
  return loadTranslations(ref.watch(languageProvider));
});

class LanguageController extends Notifier<String> {
  @override
  String build() {
    Future<void>.microtask(_restore);
    return resolveLanguage(PlatformDispatcher.instance.locale.languageCode);
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(languagePrefsKey);
    if (saved != null) {
      state = resolveLanguage(saved);
    }
  }

  Future<void> select(String code) async {
    final resolved = resolveLanguage(code);
    state = resolved;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(languagePrefsKey, resolved);
  }
}

/// Makes the active [Translations] available as `context.t(...)`.
class TranslationsScope extends InheritedWidget {
  const TranslationsScope({
    required this.translations,
    required super.child,
    super.key,
  });

  final Translations translations;

  static Translations of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<TranslationsScope>();
    return scope?.translations ?? Translations.empty;
  }

  @override
  bool updateShouldNotify(TranslationsScope old) =>
      old.translations != translations;
}

extension TranslationContext on BuildContext {
  /// Translates [key] ("ns:path") in the active language.
  String t(
    String key, {
    Map<String, Object?> args = const {},
    int? count,
  }) =>
      TranslationsScope.of(this).t(key, args: args, count: count);
}
