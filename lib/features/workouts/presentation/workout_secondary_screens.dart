import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/data/service_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/workout_models.dart';
import 'workout_screen.dart' show workoutHistoryProvider;

final _workoutDetailProvider =
    FutureProvider.autoDispose.family<Workout?, String>((ref, id) async {
  final service = ref.watch(workoutServiceProvider);
  if (service == null) {
    return null;
  }
  return service.byId(id);
});

class WorkoutHistoryDetailScreen extends ConsumerWidget {
  const WorkoutHistoryDetailScreen({required this.workoutId, super.key});
  final String workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppPalette.of(context);
    final detail = ref.watch(_workoutDetailProvider(workoutId));

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: detail.when(
          loading: () => Center(
            child: CircularProgressIndicator(color: colors.accent),
          ),
          error: (_, __) => _Missing(onBack: () => context.pop()),
          data: (workout) => workout == null
              ? _Missing(onBack: () => context.pop())
              : _WorkoutDetail(workout: workout),
        ),
      ),
    );
  }
}

class _WorkoutDetail extends ConsumerWidget {
  const _WorkoutDetail({required this.workout});
  final Workout workout;

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: workout.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename workout'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) {
      return;
    }
    await ref.read(workoutServiceProvider)?.renameWorkout(workout.id, name);
    ref.invalidate(_workoutDetailProvider(workout.id));
    ref.invalidate(workoutHistoryProvider);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final router = GoRouter.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete workout?'),
        content: const Text('This removes the workout and all its sets.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    await ref.read(workoutServiceProvider)?.deleteWorkout(workout.id);
    ref.invalidate(workoutHistoryProvider);
    router.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duration = workout.finishedAt == null
        ? 0
        : workout.finishedAt!.difference(workout.startedAt).inMinutes;
    final exercises = <String, List<WorkoutSet>>{};
    for (final set in workout.sets) {
      exercises.putIfAbsent(set.exerciseName ?? 'Exercise', () => []).add(set);
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 44),
      children: [
        DetailHeader(
          title: workout.name,
          subtitle: DateFormat('EEEE, MMM d').format(workout.startedAt),
          onBack: () => context.pop(),
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'rename') {
                _rename(context, ref);
              } else {
                _delete(context, ref);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: _Metric(
                  value: '${workout.sets.length}',
                  label: 'SETS',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Metric(
                  value: '$duration',
                  label: 'MIN',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Metric(
                  value: '${workout.totalVolumeKg.round()}',
                  label: 'KG VOL',
                  color: AppColors.workout,
                ),
              ),
            ],
          ),
        ),
        for (final entry in exercises.entries)
          _ExerciseHistory(name: entry.key, sets: entry.value),
      ],
    );
  }
}

/// Shared back-arrow header used by the workout detail screens.
class DetailHeader extends StatelessWidget {
  const DetailHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
    this.trailing,
    super.key,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 20, 14),
      decoration: BoxDecoration(
        color: colors.header,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              width: 36,
              height: 36,
              child: Icon(Icons.arrow_back, color: colors.text, size: 19),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 10, color: colors.muted),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.value,
    required this.label,
    this.color,
  });

  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color ?? colors.text,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: colors.faint,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseHistory extends StatelessWidget {
  const _ExerciseHistory({required this.name, required this.sets});
  final String name;
  final List<WorkoutSet> sets;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: colors.text,
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            color: colors.cardAlt,
            child: Row(
              children: [
                SizedBox(
                  width: 42,
                  child: Text(
                    'SET',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9, color: colors.faint),
                  ),
                ),
                Expanded(
                  child: Text(
                    'WEIGHT',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9, color: colors.faint),
                  ),
                ),
                Expanded(
                  child: Text(
                    'REPS',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9, color: colors.faint),
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < sets.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : Border(top: BorderSide(color: colors.border)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 42,
                    child: Text(
                      '${i + 1}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${sets[i].weightKg?.toStringAsFixed(1) ?? '—'} kg',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${sets[i].reps ?? '—'}${sets[i].isPersonalRecord ? '  PR' : ''}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Missing extends StatelessWidget {
  const _Missing({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fitness_center, size: 48, color: colors.border2),
            const SizedBox(height: 12),
            Text(
              'Workout not found',
              style: TextStyle(
                color: colors.muted,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: onBack, child: const Text('Go back')),
          ],
        ),
      ),
    );
  }
}
