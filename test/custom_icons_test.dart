import 'package:fittrack_pro/core/widgets/custom_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final focused in [false, true]) {
    testWidgets('all 35 custom icons render (focused: $focused)',
        (tester) async {
      final icons =
          buildAllCustomIcons(const Color(0xFF38BDF8), focused: focused);
      expect(icons.length, 35);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Wrap(children: icons),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
