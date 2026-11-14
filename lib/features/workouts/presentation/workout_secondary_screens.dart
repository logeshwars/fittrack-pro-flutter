import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/data/service_providers.dart';
import '../../../core/l10n/language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/fittrack_tokens.dart';
import '../../../core/widgets/fittrack_components.dart';
import '../../../core/widgets/fittrack_ui.dart';
import '../data/preset_service.dart';
import '../domain/workout_models.dart';
import 'workout_screen.dart' show allExercisesProvider, workoutHistoryProvider;
import 'workout_template_screens.dart' show startSessionFor;
import '../../../core/widgets/fittrack_icons.dart';

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
        top: false,
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

/// Bottom-sheet body that renames a workout; owns its text controller.
class _RenameSheet extends StatefulWidget {
  const _RenameSheet({required this.initial});
  final String initial;

  @override
  State<_RenameSheet> createState() => _RenameSheetState();
}

class _RenameSheetState extends State<_RenameSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              context.t('workout:sdRenameTitle'),
              style: FitTrackText.titleLg.copyWith(
                color: c.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: FitTrackSpacing.md),
          FitTrackTextField(
            label: context.t('workout:sdNameLabel'),
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
          ),
          const SizedBox(height: FitTrackSpacing.lg),
          FitTrackButton(
            label: context.t('common:save'),
            fullWidth: true,
            onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          ),
          const SizedBox(height: FitTrackSpacing.sm),
          FitTrackButton(
            label: context.t('common:cancel'),
            variant: FitTrackButtonVariant.ghost,
            fullWidth: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _WorkoutDetail extends ConsumerWidget {
  const _WorkoutDetail({required this.workout});
  final Workout workout;

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final name = await showFitTrackSheet<String>(
      context: context,
      builder: (_) => _RenameSheet(initial: workout.name),
    );
    if (name == null || name.isEmpty) {
      return;
    }
    await ref.read(workoutServiceProvider)?.renameWorkout(workout.id, name);
    ref.invalidate(_workoutDetailProvider(workout.id));
    ref.invalidate(workoutHistoryProvider);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final router = GoRouter.of(context);
    final ok = await showFitTrackConfirm(
      context: context,
      title: context.t('workout:sdDeleteTitle'),
      message: context.t('workout:sdDeleteMsg'),
      confirmLabel: context.t('common:delete'),
      cancelLabel: context.t('common:cancel'),
      icon: FitIcons.delete,
      destructive: true,
    );
    if (!ok) {
      return;
    }
    await ref.read(workoutServiceProvider)?.deleteWorkout(workout.id);
    ref.invalidate(workoutHistoryProvider);
    router.pop();
  }

  Future<void> _repeat(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final noMatch = context.t('workout:sdRepeatNoMatch');
    final all = await ref.read(allExercisesProvider.future);
    if (!context.mounted) {
      return;
    }
    final known = {for (final e in all) e.id};
    final order = <String>[];
    final counts = <String, int>{};
    final names = <String, String>{};
    final groups = <String, String>{};
    for (final s in workout.sets) {
      if (!known.contains(s.exerciseId)) {
        continue;
      }
      if (!counts.containsKey(s.exerciseId)) {
        order.add(s.exerciseId);
      }
      counts[s.exerciseId] = (counts[s.exerciseId] ?? 0) + 1;
      names[s.exerciseId] = s.exerciseName ?? '';
      groups[s.exerciseId] = s.muscleGroup ?? '';
    }
    if (order.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(noMatch)));
      return;
    }
    final preset = [
      for (final id in order)
        PresetExercise(
          exerciseId: id,
          exerciseName: names[id]!,
          muscleGroup: groups[id]!,
          defaultSets: counts[id]!,
        ),
    ];
    await startSessionFor(
      context,
      ref,
      workout.name,
      preset,
      [
        for (final e in all)
          if (counts.containsKey(e.id)) e,
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppPalette.of(context);
    final minutes = workout.finishedAt?.difference(workout.startedAt).inMinutes;
    final exercises = <String, List<WorkoutSet>>{};
    for (final set in workout.sets) {
      exercises
          .putIfAbsent(
            set.exerciseName ?? context.t('workout:sdExerciseFallback'),
            () => [],
          )
          .add(set);
    }
    final prCount = workout.sets.where((s) => s.isPersonalRecord).length;
    final allRpe =
        workout.sets.isNotEmpty && workout.sets.every((s) => s.rpe != null);
    const xpComplete = 50;
    final xpRpe = allRpe ? 10 : 0;
    final xpPr = prCount * 100;
    final xp = xpComplete + xpRpe + xpPr;
    final kg = context.t('workout:kgUnit');

    return ListView(
      padding: const EdgeInsets.only(bottom: FitTrackSpacing.xxl),
      children: [
        DetailHeader(
          title: workout.name,
          subtitle:
              DateFormat("EEE d MMM '·' h:mm a").format(workout.startedAt),
          onBack: () => context.pop(),
          trailing: PopupMenuButton<String>(
            tooltip: context.t('workout:sdMore'),
            icon: Icon(FitIcons.more, color: c.ink),
            color: c.surface,
            onSelected: (value) {
              if (value == 'rename') {
                unawaited(_rename(context, ref));
              } else {
                unawaited(_delete(context, ref));
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'rename',
                child: Text(context.t('workout:sdRename')),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  context.t('common:delete'),
                  style: TextStyle(color: c.textBad),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            FitTrackSpacing.lg,
            FitTrackSpacing.md,
            FitTrackSpacing.lg,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (workout.isFinished) ...[
                _CompleteCard(xp: xp),
                const SizedBox(height: FitTrackSpacing.md),
              ],
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.3,
                children: [
                  _Metric(
                    label: context.t('workout:sdDuration'),
                    value: minutes == null ? '—' : '$minutes',
                    unit: context.t('workout:minUnit'),
                  ),
                  _Metric(
                    label: context.t('workout:volumeLabel'),
                    value: NumberFormat('#,##0')
                        .format(workout.totalVolumeKg.round()),
                    unit: kg,
                  ),
                  _Metric(
                    label: context.t('workout:sdSets'),
                    value: '${workout.sets.length}',
                  ),
                  _Metric(
                    label: context.t('workout:sdRecords'),
                    value: '$prCount',
                    unit: context.t('workout:prBadge'),
                  ),
                ],
              ),
              if (workout.isFinished) ...[
                const SizedBox(height: FitTrackSpacing.md),
                _XpCard(
                  complete: xpComplete,
                  rpe: xpRpe,
                  pr: xpPr,
                  prCount: prCount,
                ),
              ],
              const SizedBox(height: FitTrackSpacing.md),
              FitTrackCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _CardTitle(
                      title: context.t('workout:exercisesLabel'),
                      trailing: '${exercises.length}',
                    ),
                    for (final entry in exercises.entries)
                      _ExerciseHistory(name: entry.key, sets: entry.value),
                  ],
                ),
              ),
              const SizedBox(height: FitTrackSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: FitTrackButton(
                      label: context.t('workout:sdRepeat'),
                      variant: FitTrackButtonVariant.secondary,
                      fullWidth: true,
                      onPressed: () => unawaited(_repeat(context, ref)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FitTrackButton(
                      label: context.t('workout:sdDone'),
                      fullWidth: true,
                      onPressed: () => context.pop(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shared back-arrow header used by the workout detail screens.
/// Pushed-screen header. Kept as a name so older call sites compile; the
/// look comes from [FitTrackTopBar].
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
  Widget build(BuildContext context) => FitTrackTopBar(
        title: title,
        subtitle: subtitle.isEmpty ? null : subtitle,
        backLabel: context.t('settings:backLabel'),
        onBack: onBack,
        trailing: trailing,
      );
}

class _CompleteCard extends StatelessWidget {
  const _CompleteCard({required this.xp});
  final int xp;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return Semantics(
      container: true,
      label: '${context.t('workout:sdComplete')}, '
          '+$xp ${context.t('workout:sdXpEarned')}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(FitTrackSpacing.md + 2),
          decoration: BoxDecoration(
            color: c.ok,
            borderRadius: BorderRadius.circular(FitTrackRadius.card),
            border: Border.all(color: c.ok),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.t('workout:sdComplete'),
                style: FitTrackText.caption.copyWith(
                  color: c.bg,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: FitTrackSpacing.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '+$xp',
                    style: FitTrackText.hero.copyWith(
                      color: c.bg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: FitTrackSpacing.sm),
                  Text(
                    context.t('workout:sdXpEarned'),
                    style: FitTrackText.body.copyWith(color: c.bg),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _XpCard extends StatelessWidget {
  const _XpCard({
    required this.complete,
    required this.rpe,
    required this.pr,
    required this.prCount,
  });
  final int complete;
  final int rpe;
  final int pr;
  final int prCount;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);

    Widget row(String label, int value) => Container(
          constraints: const BoxConstraints(minHeight: FitTrackSpacing.touchMin),
          padding: const EdgeInsets.symmetric(horizontal: FitTrackSpacing.md + 2),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.line)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: FitTrackText.body.copyWith(color: c.ink),
                ),
              ),
              Text(
                '+$value',
                style: FitTrackText.body.copyWith(
                  color: c.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );

    return FitTrackCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _CardTitle(title: context.t('workout:sdXpBreakdown')),
          row(context.t('workout:sdXpComplete'), complete),
          if (rpe > 0) row(context.t('workout:sdXpRpe'), rpe),
          if (pr > 0)
            row(
              prCount > 1
                  ? context.t('workout:sdXpPrMany', args: {'count': prCount})
                  : context.t('workout:sdXpPr'),
              pr,
            ),
        ],
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.title, this.trailing});
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return SizedBox(
      height: FitTrackSpacing.touchMin,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: FitTrackSpacing.md + 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Semantics(
              header: true,
              child: Text(
                title,
                style: FitTrackText.title.copyWith(
                  color: c.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: FitTrackText.caption.copyWith(color: c.muted),
              ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.unit});

  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return Semantics(
      container: true,
      label: '$label, $value${unit == null ? '' : ' $unit'}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(FitTrackSpacing.md),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(FitTrackRadius.md),
            border: Border.all(color: c.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: FitTrackText.caption.copyWith(
                  color: c.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: FitTrackSpacing.xs),
              Text.rich(
                TextSpan(
                  text: value,
                  style: FitTrackText.stat.copyWith(
                    color: c.ink,
                    fontWeight: FontWeight.w600,
                  ),
                  children: [
                    if (unit != null)
                      TextSpan(
                        text: ' $unit',
                        style: FitTrackText.caption.copyWith(color: c.muted),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseHistory extends StatelessWidget {
  const _ExerciseHistory({required this.name, required this.sets});
  final String name;
  final List<WorkoutSet> sets;

  String _setText(WorkoutSet s) {
    if (s.reps == null && s.durationSeconds != null) {
      return '${s.durationSeconds}s';
    }
    final w = s.weightKg;
    final weight = w == null
        ? '—'
        : (w == w.roundToDouble() ? w.round().toString() : w.toStringAsFixed(1));
    return '$weight × ${s.reps ?? '—'}';
  }

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final kg = context.t('workout:kgUnit');
    final hasPr = sets.any((s) => s.isPersonalRecord);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: FitTrackSpacing.md + 2,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: FitTrackText.body.copyWith(
                    color: c.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (hasPr)
                FitTrackBadge(
                  label: context.t('workout:prBadge'),
                  tone: FitTrackBadgeTone.ok,
                  icon: FitIcons.trophy,
                ),
            ],
          ),
          const SizedBox(height: FitTrackSpacing.xs),
          Semantics(
            label: [
              for (final s in sets) '${_setText(s)} $kg',
            ].join(', '),
            child: ExcludeSemantics(
              child: Text(
                [for (final s in sets) _setText(s)].join(' · '),
                style: FitTrackText.caption.copyWith(color: c.muted),
              ),
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
    final c = AppPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FitTrackSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(FitIcons.workout, size: 48, color: c.lineStrong),
            const SizedBox(height: FitTrackSpacing.md),
            Text(
              context.t('workout:sdNotFound'),
              style: FitTrackText.body.copyWith(
                color: c.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: FitTrackSpacing.lg),
            FitTrackButton(
              label: context.t('workout:sdGoBack'),
              variant: FitTrackButtonVariant.secondary,
              onPressed: onBack,
            ),
          ],
        ),
      ),
    );
  }
}
