import 'package:fittrack_pro/core/theme/app_theme.dart';
import 'package:fittrack_pro/core/widgets/fittrack_components.dart';
import 'package:fittrack_pro/core/widgets/fittrack_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {ThemeData? theme}) => MaterialApp(
      theme: theme ?? AppTheme.dark,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  for (final entry in {'night': AppTheme.dark, 'pearl': AppTheme.light}.entries) {
    group(entry.key, () {
      testWidgets('button heights are 36 / 44 / 48', (tester) async {
        for (final (size, height) in [
          (FitTrackButtonSize.sm, 36.0),
          (FitTrackButtonSize.md, 44.0),
          (FitTrackButtonSize.lg, 48.0),
        ]) {
          await tester.pumpWidget(_host(
            FitTrackButton(label: 'Go', size: size, onPressed: () {}),
            theme: entry.value,
          ));
          final box = tester.getSize(find.byType(Material).last);
          expect(box.height, height);
        }
      });

      testWidgets('small button keeps a 44px tap area', (tester) async {
        await tester.pumpWidget(_host(
          FitTrackButton(
            label: 'Go',
            size: FitTrackButtonSize.sm,
            onPressed: () {},
          ),
          theme: entry.value,
        ));
        final area = tester.getSize(find.byType(FitTrackButton));
        expect(area.height, greaterThanOrEqualTo(44));
      });

      testWidgets('icon button is 44 x 44', (tester) async {
        await tester.pumpWidget(_host(
          FitTrackIconButton(
            icon: FitIcons.add,
            semanticLabel: 'Add',
            onPressed: () {},
          ),
          theme: entry.value,
        ));
        expect(tester.getSize(find.byType(FitTrackIconButton)),
            const Size(44, 44));
      });

      testWidgets('badge is 26px tall', (tester) async {
        await tester.pumpWidget(_host(
          const FitTrackBadge(label: 'Done', tone: FitTrackBadgeTone.ok),
          theme: entry.value,
        ));
        expect(tester.getSize(find.byType(FitTrackBadge)).height, 26);
      });

      testWidgets('tab bar is 64px with keyed tabs and fires onSelected',
          (tester) async {
        int? tapped;
        await tester.pumpWidget(MaterialApp(
          theme: entry.value,
          home: Scaffold(
            bottomNavigationBar: FitTrackTabBar(
              selectedIndex: 0,
              labels: const ['A', 'B', 'C', 'D', 'E'],
              iconBuilder: (tab, color, {required focused}) =>
                  Icon(FitIcons.dot, color: color, size: 22),
              onSelected: (i) => tapped = i,
            ),
          ),
        ));
        for (var i = 0; i < 5; i++) {
          expect(find.byKey(Key('fittrack-tab-$i')), findsOneWidget);
        }
        expect(tester.getSize(find.byType(FitTrackTabBar)).height,
            greaterThanOrEqualTo(FitTrackTabBar.height));
        await tester.tap(find.byKey(const Key('fittrack-tab-3')));
        expect(tapped, 3);
      });
    });
  }

  testWidgets('confirm dialog resolves false when dismissed', (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result = await showFitTrackConfirm(
              context: context,
              title: 'Delete?',
              confirmLabel: 'Delete',
              cancelLabel: 'Cancel',
              destructive: true,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(2, 2)); // scrim
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('confirm dialog returns true on confirm', (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result = await showFitTrackConfirm(
              context: context,
              title: 'Sure?',
              confirmLabel: 'Yes',
              cancelLabel: 'No',
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
