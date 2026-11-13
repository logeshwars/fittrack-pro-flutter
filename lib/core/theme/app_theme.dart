import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'fittrack_tokens.dart';

/// Night (dark) and Pearl (light) Material themes built from [AppPalette].
///
/// Flat with hairlines: depth is `bg` then `surface`, separated by a 1px
/// `line` border. No elevation, no tinted shadows.
abstract final class AppTheme {
  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        palette: AppPalette.dark,
      );

  static ThemeData get light => _build(
        brightness: Brightness.light,
        palette: AppPalette.light,
      );

  /// 50% black scrim behind sheets and dialogs.
  static const scrim = Color(0x80000000);

  static ThemeData _build({
    required Brightness brightness,
    required AppPalette palette,
  }) {
    final isDark = brightness == Brightness.dark;
    final scheme = isDark
        ? ColorScheme.dark(
            primary: palette.accent,
            onPrimary: palette.onAccent,
            surface: palette.bg,
            onSurface: palette.ink,
            error: palette.bad,
            onError: palette.onAccent,
            outline: palette.lineStrong,
            outlineVariant: palette.line,
          )
        : ColorScheme.light(
            primary: palette.accent,
            onPrimary: palette.onAccent,
            surface: palette.bg,
            onSurface: palette.ink,
            error: palette.bad,
            onError: palette.onAccent,
            outline: palette.lineStrong,
            outlineVariant: palette.line,
          );

    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(FitTrackRadius.md),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.bg,
      cardColor: palette.surface,
      dividerColor: palette.line,
      dividerTheme: DividerThemeData(color: palette.line, thickness: 1),
      splashColor: palette.accent.withValues(alpha: 0.06),
      highlightColor: palette.accent.withValues(alpha: 0.04),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.bg,
        foregroundColor: palette.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FitTrackRadius.lg),
          side: BorderSide(color: palette.line),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalBarrierColor: scrim,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(FitTrackRadius.xl),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FitTrackRadius.xl),
        ),
      ),
      // C2: 52 x 32 switch, accent track with an on-accent thumb; off is a
      // line-strong track with a bg thumb.
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? palette.accent
              : palette.lineStrong,
        ),
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? palette.onAccent
              : palette.bg,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? palette.accent
              : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(palette.onAccent),
        side: BorderSide(color: palette.lineStrong, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? palette.accent
              : palette.lineStrong,
        ),
      ),
      textTheme: TextTheme(
        headlineSmall: FitTrackText.screenTitle.copyWith(color: palette.ink),
        titleLarge: FitTrackText.titleLg.copyWith(color: palette.ink),
        titleMedium: FitTrackText.title.copyWith(color: palette.ink),
        bodyMedium: FitTrackText.body.copyWith(color: palette.ink),
        bodySmall: FitTrackText.caption.copyWith(color: palette.muted),
        labelLarge: FitTrackText.label.copyWith(color: palette.ink),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: FitTrackSpacing.md,
          vertical: 13,
        ),
        hintStyle: FitTrackText.body.copyWith(color: palette.muted),
        helperStyle: FitTrackText.caption.copyWith(color: palette.muted),
        errorStyle: FitTrackText.caption.copyWith(color: palette.textBad),
        border: inputBorder(palette.lineStrong),
        enabledBorder: inputBorder(palette.lineStrong),
        focusedBorder: inputBorder(palette.accent, 2),
        errorBorder: inputBorder(palette.bad),
        focusedErrorBorder: inputBorder(palette.bad, 2),
      ),
    );
  }
}
