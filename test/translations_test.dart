import 'dart:convert';
import 'dart:io';

import 'package:fittrack_pro/core/l10n/translations.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Map<String, dynamic>> readLanguage(String lang) => {
      for (final ns in translationNamespaces)
        ns: jsonDecode(
                File('assets/translations/$lang/$ns.json').readAsStringSync())
            as Map<String, dynamic>,
    };

Map<String, String> flat(Map<String, dynamic> json, [String prefix = '']) {
  final out = <String, String>{};
  json.forEach((k, v) {
    if (v is Map<String, dynamic>) {
      out.addAll(flat(v, '$prefix$k.'));
    } else if (v is String) {
      out['$prefix$k'] = v;
    }
  });
  return out;
}

Set<String> placeholders(String value) => RegExp(r'\{\{\s*(\w+)\s*\}\}')
    .allMatches(value)
    .map((m) => m.group(1)!)
    .toSet();

void main() {
  final english = readLanguage('en');

  test('every shipped language has all namespaces as valid JSON', () {
    for (final lang in supportedLanguages) {
      expect(readLanguage(lang.code).length, translationNamespaces.length,
          reason: lang.code);
    }
  });

  test('translated strings keep the placeholders of the English source', () {
    for (final lang in supportedLanguages.where((l) => l.code != 'en')) {
      final translated = readLanguage(lang.code);
      for (final ns in translationNamespaces) {
        final en = flat(english[ns]!);
        final tr = flat(translated[ns]!);
        for (final entry in tr.entries) {
          final source = en[entry.key];
          if (source == null) {
            continue;
          }
          expect(
            placeholders(entry.value),
            placeholders(source),
            reason: '${lang.code}/$ns/${entry.key}',
          );
        }
      }
    }
  });

  test('lookup, namespace prefix, fallback and interpolation', () {
    final de = Translations.fromJson(
      language: 'de',
      namespaces: readLanguage('de'),
      fallback: english,
    );
    expect(de.t('workout:title'), 'Training');
    expect(de.t('title', namespace: 'progress'), 'Fortschritt');
    expect(de.t('nope:key'), 'nope:key');
    final fallbackOnly = Translations.fromJson(
      language: 'de',
      namespaces: {'common': {}},
      fallback: english,
    );
    expect(fallbackOnly.t('common:save'), 'Save');
    expect(fallbackOnly.has('save'), isFalse);
    expect(
      Translations.fromJson(language: 'en', namespaces: english)
          .t('common:earnXPFor', args: {'xp': 35}),
      "You'll earn +35 XP for this session",
    );
  });

  test('plural suffixes pick the right form', () {
    final t = Translations.fromJson(language: 'en', namespaces: english);
    expect(t.t('settings:activeReminder', args: {'count': 1}),
        '1 active reminder');
    final plural = Translations.fromJson(
      language: 'en',
      namespaces: {
        'common': {
          'item_one': '{{count}} item',
          'item_other': '{{count}} items'
        },
      },
    );
    expect(plural.t('item', count: 1), '1 item');
    expect(plural.t('item', count: 3), '3 items');
    expect(plural.t('item', count: 0), '0 items');
  });

  test('pluralCategory follows CLDR for shipped languages', () {
    expect(pluralCategory('en', 1), 'one');
    expect(pluralCategory('fr', 0), 'one');
    expect(pluralCategory('ja', 1), 'other');
    expect(pluralCategory('ar', 0), 'zero');
    expect(pluralCategory('ar', 2), 'two');
    expect(pluralCategory('ar', 5), 'few');
    expect(pluralCategory('ar', 11), 'many');
    expect(pluralCategory('ar', 100), 'other');
  });

  test('resolveLanguage falls back to English', () {
    expect(resolveLanguage('ta'), 'ta');
    expect(resolveLanguage('zz'), 'en');
    expect(resolveLanguage(null), 'en');
  });
}
