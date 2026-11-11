import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// System theme by default; persistent preference will be added in Batch 2.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
