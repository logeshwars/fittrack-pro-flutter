import 'dart:convert';

import 'package:flutter/services.dart';

/// Language codes the app ships, with the name each language uses for itself.
const supportedLanguages = <({String code, String label, String nativeLabel})>[
  (code: 'en', label: 'English', nativeLabel: 'English'),
  (code: 'hi', label: 'Hindi', nativeLabel: 'हिन्दी'),
  (code: 'ta', label: 'Tamil', nativeLabel: 'தமிழ்'),
  (code: 'ar', label: 'Arabic', nativeLabel: 'العربية'),
  (code: 'es', label: 'Spanish', nativeLabel: 'Español'),
  (code: 'de', label: 'German', nativeLabel: 'Deutsch'),
  (code: 'ja', label: 'Japanese', nativeLabel: '日本語'),
  (code: 'pt', label: 'Portuguese', nativeLabel: 'Português'),
  (code: 'fr', label: 'French', nativeLabel: 'Français'),
];

/// Namespaces, one JSON file per language each (same layout as the RN app).
const translationNamespaces = [
  'common',
  'home',
  'workout',
  'nutrition',
  'profile',
  'settings',
  'progress',
];

const defaultLanguage = 'en';

/// Language to use for a stored or device code; English when unsupported.
String resolveLanguage(String? code) =>
    supportedLanguages.any((l) => l.code == code) ? code! : defaultLanguage;

/// CLDR plural category for [n] in [language] (the forms the app ships).
String pluralCategory(String language, int n) {
  switch (language) {
    case 'ja':
      return 'other';
    case 'fr':
    case 'pt':
      return n == 0 || n == 1 ? 'one' : 'other';
    case 'hi':
      return n == 0 || n == 1 ? 'one' : 'other';
    case 'ar':
      if (n == 0) {
        return 'zero';
      }
      if (n == 1) {
        return 'one';
      }
      if (n == 2) {
        return 'two';
      }
      final mod = n % 100;
      if (mod >= 3 && mod <= 10) {
        return 'few';
      }
      if (mod >= 11) {
        return 'many';
      }
      return 'other';
    default:
      return n == 1 ? 'one' : 'other';
  }
}

Map<String, String> _flatten(Map<String, dynamic> json, [String prefix = '']) {
  final out = <String, String>{};
  json.forEach((key, value) {
    if (value is Map<String, dynamic>) {
      out.addAll(_flatten(value, '$prefix$key.'));
    } else if (value is String) {
      out['$prefix$key'] = value;
    }
  });
  return out;
}

/// Looks up translated strings: `t('settings:appSettings')`, with i18next-style
/// `{{name}}` interpolation and `_one`/`_other` plural suffixes. A key missing
/// from the active language falls back to English, then to the key itself.
class Translations {
  const Translations({
    required this.language,
    required Map<String, Map<String, String>> strings,
    Map<String, Map<String, String>> fallback = const {},
  })  : _strings = strings,
        _fallback = fallback;

  /// Nothing loaded: every lookup returns its key.
  static const empty = Translations(language: defaultLanguage, strings: {});

  /// Builds from decoded JSON per namespace (test and loader entry point).
  factory Translations.fromJson({
    required String language,
    required Map<String, Map<String, dynamic>> namespaces,
    Map<String, Map<String, dynamic>> fallback = const {},
  }) =>
      Translations(
        language: language,
        strings: {for (final e in namespaces.entries) e.key: _flatten(e.value)},
        fallback: {for (final e in fallback.entries) e.key: _flatten(e.value)},
      );

  final String language;
  final Map<String, Map<String, String>> _strings;
  final Map<String, Map<String, String>> _fallback;

  /// Whether [key] resolves in the active language (not only via fallback).
  bool has(String key, {String namespace = 'common'}) {
    final (ns, path) = _split(key, namespace);
    return _strings[ns]?.containsKey(path) ?? false;
  }

  (String, String) _split(String key, String namespace) {
    final i = key.indexOf(':');
    return i < 0 ? (namespace, key) : (key.substring(0, i), key.substring(i + 1));
  }

  String? _lookup(String ns, String path) =>
      _strings[ns]?[path] ?? _fallback[ns]?[path];

  /// Translates [key] ("ns:path" or a plain key in [namespace]).
  String t(
    String key, {
    String namespace = 'common',
    Map<String, Object?> args = const {},
    int? count,
  }) {
    final (ns, path) = _split(key, namespace);
    String? raw;
    if (count != null) {
      raw = _lookup(ns, '${path}_${pluralCategory(language, count)}') ??
          _lookup(ns, '${path}_other');
    }
    raw ??= _lookup(ns, path);
    if (raw == null) {
      return key;
    }
    final values = {...args, if (count != null) 'count': count};
    return raw.replaceAllMapped(
      RegExp(r'\{\{\s*(\w+)\s*\}\}'),
      (m) => '${values[m.group(1)] ?? m.group(0)}',
    );
  }
}

/// Reads the bundled JSON for [language] (plus English as the fallback).
Future<Translations> loadTranslations(
  String language, {
  AssetBundle? bundle,
}) async {
  final assets = bundle ?? rootBundle;

  Future<Map<String, Map<String, dynamic>>> read(String lang) async {
    final out = <String, Map<String, dynamic>>{};
    for (final ns in translationNamespaces) {
      try {
        final raw = await assets.loadString('assets/translations/$lang/$ns.json');
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          out[ns] = decoded;
        }
      } on Object {
        // A missing namespace falls back to English.
      }
    }
    return out;
  }

  final english = await read(defaultLanguage);
  return Translations.fromJson(
    language: language,
    namespaces: language == defaultLanguage ? english : await read(language),
    fallback: english,
  );
}
