import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fittrack_pro/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('five navigation destinations are visible', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FitTrackApp()));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(find.text('Today'), findsWidgets);
  });
}
