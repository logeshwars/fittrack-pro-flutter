import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Matches the React Native app: dark is the first-launch default.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);
