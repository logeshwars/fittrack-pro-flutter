import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fittrack_pro/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('five custom navigation tabs are visible', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FitTrackApp()));
    await tester.pumpAndSettle();

    for (var index = 0; index < 5; index++) {
      expect(find.byKey(Key('fittrack-tab-$index')), findsOneWidget);
    }
// Shown on the Today screen in both Night and Pearl.
    expect(find.text('This week'), findsOneWidget);
  });
}
