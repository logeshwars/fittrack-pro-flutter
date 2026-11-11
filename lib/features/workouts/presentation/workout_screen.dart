import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/fittrack_ui.dart';
import '../data/workout_repository.dart';
import '../domain/workout_models.dart';

final workoutHistoryProvider = FutureProvider.autoDispose<List<Workout>>((ref) async {
  if (!AppConfig.hasSupabase) return const [];
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return const [];
  return WorkoutRepository(client).getHistory(authenticatedUserId: user.id);
});

class WorkoutScreen extends ConsumerStatefulWidget {
  const WorkoutScreen({super.key});
  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen> {
  int tab = 0;
  DateTime selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final history = ref.watch(workoutHistoryProvider);
    final workouts = history.valueOrNull ?? const <Workout>[];
    final weeklyVolume = workouts
        .where((w) => w.startedAt.isAfter(DateTime.now().subtract(const Duration(days: 7))))
        .fold<double>(0, (sum, w) => sum + w.totalVolumeKg);

    return RefreshIndicator(
      color: colors.accent,
      backgroundColor: colors.card,
      onRefresh: () async {
        ref.invalidate(workoutHistoryProvider);
        await ref.read(workoutHistoryProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 44),
        children: [
          FitTrackScreenHeader(
            title: 'Workout',
            subtitle: DateFormat('EEEE, MMM d').format(selectedDate),
            icon: Icons.fitness_center,
            trailing: weeklyVolume > 0
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: colors.accentTint,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.accent),
                    ),
                    child: Column(
                      children: [
                        Text(
                          NumberFormat.decimalPattern().format(weeklyVolume.round()),
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: colors.accent),
                        ),
                        Text('KG / WEEK', style: TextStyle(fontSize: 8, color: colors.muted, letterSpacing: 1)),
                      ],
                    ),
                  )
                : null,
          ),
          _DateStrip(
            selected: selectedDate,
            workouts: workouts,
            onSelected: (value) => setState(() => selectedDate = value),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: FitTrackSegmentedTabs(
              labels: const ['My Routines', 'Exercises', 'History'],
              selectedIndex: tab,
              onSelected: (value) => setState(() => tab = value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: _QuickStart(onTap: () => context.push('/workout/draft')),
          ),
          if (tab == 0) _Routines(onCreate: () => context.push('/workout/draft')),
          if (tab == 1) _Exercises(onOpen: () => context.push('/workout/draft')),
          if (tab == 2)
            history.when(
              loading: () => Padding(
                padding: const EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator(color: colors.accent)),
              ),
              error: (_, __) => const _Info(text: 'Unable to load workout history.'),
              data: (items) => _History(items: items),
            ),
        ],
      ),
    );
  }
}

class _DateStrip extends StatelessWidget {
  const _DateStrip({required this.selected, required this.workouts, required this.onSelected});
  final DateTime selected;
  final List<Workout> workouts;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day).subtract(const Duration(days: 3));
    final activeDays = workouts.map((w) => DateTime(w.startedAt.year, w.startedAt.month, w.startedAt.day)).toSet();
    return SizedBox(
      height: 72,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final date = start.add(Duration(days: index));
          final active = date.year == selected.year && date.month == selected.month && date.day == selected.day;
          final hit = activeDays.contains(date);
          return InkWell(
            onTap: () => onSelected(date),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 54,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: active ? colors.accent : colors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: active ? colors.accent : colors.border2),
              ),
              child: Column(
                children: [
                  Text(DateFormat('EEE').format(date).toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: active ? colors.accentText : colors.muted)),
                  const SizedBox(height: 4),
                  Text('${date.day}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: active ? colors.accentText : colors.text)),
                  const SizedBox(height: 3),
                  Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: hit ? AppColors.workout : Colors.transparent)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QuickStart extends StatelessWidget {
  const _QuickStart({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: colors.accentTint, borderRadius: BorderRadius.circular(8), border: Border.all(color: colors.border2)), alignment: Alignment.center, child: Icon(Icons.bolt, size: 18, color: colors.accent)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Quick Start', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: colors.text)),
                const SizedBox(height: 1),
                Text('Empty workout · +50 XP', style: TextStyle(fontSize: 11, color: colors.muted)),
              ])),
              Icon(Icons.arrow_forward, size: 16, color: colors.faint),
            ],
          ),
        ),
      ),
    );
  }
}

class _Routines extends StatelessWidget {
  const _Routines({required this.onCreate});
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        children: [
          FitTrackSectionLabel(title: 'My Routines', action: 'New', onAction: onCreate),
          InkWell(
            onTap: onCreate,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: colors.border2)),
              child: Column(children: [
                Container(width: 44, height: 44, decoration: BoxDecoration(color: colors.accentTint, shape: BoxShape.circle), alignment: Alignment.center, child: Icon(Icons.add, color: colors.accent)),
                const SizedBox(height: 8),
                Text('Create your first routine', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: colors.text)),
                const SizedBox(height: 3),
                Text('Saved-routine data migration comes next.', style: TextStyle(fontSize: 12, color: colors.faint)),
              ]),
            ),
          ),
          const SizedBox(height: 28),
          const FitTrackSectionLabel(title: 'Workout Splits'),
          _Split(id: 'ppl', title: 'Push / Pull / Legs', subtitle: '3 days · Balanced strength split'),
          _Split(id: 'upper-lower', title: 'Upper / Lower', subtitle: '4 days · Strength and hypertrophy'),
          _Split(id: 'full-body', title: 'Full Body', subtitle: '3 days · Efficient total-body training'),
        ],
      ),
    );
  }
}

class _Split extends StatelessWidget {
  const _Split({
    required this.id,
    required this.title,
    required this.subtitle,
  });
  final String id;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return InkWell(
      onTap: () => context.push('/workout/split/$id'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(color: colors.accentTint, shape: BoxShape.circle), alignment: Alignment.center, child: Icon(Icons.fitness_center, color: colors.accent, size: 20)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: colors.text)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 11, color: colors.muted)),
        ])),
        Icon(Icons.arrow_forward, size: 14, color: colors.faint),
      ]),
      ),
    );
  }
}

class _Exercises extends StatelessWidget {
  const _Exercises({required this.onOpen});
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Container(width: 56, height: 56, decoration: BoxDecoration(color: colors.accentTint, shape: BoxShape.circle), alignment: Alignment.center, child: Icon(Icons.fitness_center, size: 28, color: colors.accent)),
            const SizedBox(height: 10),
            Text('Browse exercises', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: colors.text)),
            const SizedBox(height: 6),
            Text('The React Native exercise library will be migrated into this slot.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: colors.muted)),
          ]),
        ),
      ),
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.items});
  final List<Workout> items;
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _Info(text: 'No workout history yet.');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(children: items.map((w) => _HistoryCard(workout: w)).toList()),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.workout});
  final Workout workout;
  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final duration = workout.finishedAt == null ? '—' : '${workout.finishedAt!.difference(workout.startedAt).inMinutes} Min';
    return InkWell(
      onTap: () => context.push('/workout/history/${workout.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        SizedBox(width: 60, child: Center(child: Container(width: 46, height: 46, decoration: BoxDecoration(color: AppColors.workout.withValues(alpha: .12), shape: BoxShape.circle), alignment: Alignment.center, child: const Icon(Icons.fitness_center, color: AppColors.workout, size: 24)))),
        Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(DateFormat('EEE · MMM d').format(workout.startedAt).toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: colors.muted, letterSpacing: 1.8)),
          const SizedBox(height: 5),
          Text(workout.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: colors.text)),
          const SizedBox(height: 7),
          Wrap(spacing: 6, children: [
            _Pill('${workout.sets.length} sets'),
            _Pill(duration),
            if (workout.totalVolumeKg > 0) _Pill('${workout.totalVolumeKg.round()} kg'),
          ]),
        ]))),
      ]),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: colors.cardAlt, borderRadius: BorderRadius.circular(6)), child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.subtext)));
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Container(margin: const EdgeInsets.fromLTRB(16, 20, 16, 0), padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(12)), child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: colors.muted)));
  }
}
