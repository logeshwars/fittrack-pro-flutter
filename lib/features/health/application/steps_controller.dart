import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/data/service_providers.dart';
import '../../settings/data/goal_targets.dart';
import '../data/health_steps_gateway.dart';
import '../domain/health_steps.dart';

/// Seam for the platform health store; override in tests.
final healthStepsGatewayProvider = Provider<HealthStepsGateway>(
  (ref) => PackageHealthStepsGateway(),
);

/// Today's steps, refreshed on creation, every five minutes and on resume.
final stepsProvider =
    NotifierProvider<StepsController, StepsState>(StepsController.new);

class StepsController extends Notifier<StepsState> {
  @override
  StepsState build() {
    final timer = Timer.periodic(const Duration(minutes: 5), (_) => refresh());
    final lifecycle = AppLifecycleListener(onResume: refresh);
    ref.onDispose(() {
      timer.cancel();
      lifecycle.dispose();
    });
    Future<void>.microtask(refresh);
    return const StepsState();
  }

  /// Re-reads availability and today's steps.
  Future<void> refresh() async {
    final gateway = ref.read(healthStepsGatewayProvider);
    final availability = await gateway.availability();
    if (availability != StepsAvailability.ready) {
      state = StepsState(availability: availability);
      return;
    }
    final steps = await gateway.stepsToday(DateTime.now());
    state = StepsState(
      steps: steps ?? state.steps,
      availability:
          steps == null ? StepsAvailability.needsPermission : availability,
    );
    await _awardGoalXp();
  }

  /// Asks for access (or sends the user to install Health Connect).
  Future<void> connect() async {
    final availability =
        await ref.read(healthStepsGatewayProvider).requestPermission();
    state = state.copyWith(availability: availability);
    if (availability == StepsAvailability.ready) {
      await refresh();
    }
  }

  /// +20 XP once per day when the step goal is reached.
  Future<void> _awardGoalXp() async {
    try {
      final goal = (await ref.read(goalTargetsProvider.future)).steps;
      if (goal <= 0 || state.steps < goal) {
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final key =
          'fittrack_steps_xp_${DateFormat('yyyy-MM-dd').format(DateTime.now())}';
      if (prefs.getBool(key) == true) {
        return;
      }
      await prefs.setBool(key, true);
      await ref.read(gamificationServiceProvider)?.awardXp(20);
    } on Object {
      // XP is a bonus; never let it break step tracking.
    }
  }
}
