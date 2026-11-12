import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// React Native defaults to dark and hydrates the saved preference at startup.
ThemeMode initialThemeMode = ThemeMode.dark;

ThemeMode themeModeFromPreference(String? value) => switch (value) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };

final themeModeProvider = StateProvider<ThemeMode>((ref) => initialThemeMode);
