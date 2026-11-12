import 'package:flutter_test/flutter_test.dart';
import 'package:fittrack_pro/core/l10n/app_strings.dart';

void main() {
  test('all original app languages have navigation labels', () {
    const keys = [
      'today',
      'workout',
      'nutrition',
      'cardio',
      'progress',
      'account',
      'achievements'
    ];
    for (final language in AppStrings.supported) {
      final strings = AppStrings(language);
      for (final key in keys) {
        expect(strings.get(key).trim(), isNotEmpty);
      }
    }
  });
  test('unknown keys fall back to the key', () {
    expect(const AppStrings('en').get('missing'), 'missing');
  });
}
