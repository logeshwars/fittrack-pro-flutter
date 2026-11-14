import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/config/app_config.dart';
import '../../../core/data/service_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/fittrack_tokens.dart';
import '../../../core/widgets/fittrack_components.dart';
import '../../../core/widgets/fittrack_ui.dart';
import '../../../core/theme/theme_controller.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../reminders/application/reminders_controller.dart';
import '../../reminders/domain/reminder_catalog.dart';
import '../../reminders/domain/reminder_schedule.dart';
import '../../subscription/application/subscription_controller.dart';
import '../../workouts/domain/workout_metrics.dart';
import '../data/goal_targets.dart';
import '../../../core/l10n/language_controller.dart';
import '../../../core/l10n/translations.dart';
import '../../../core/widgets/fittrack_icons.dart';

class PersonalSettingsScreen extends ConsumerStatefulWidget {
  const PersonalSettingsScreen({super.key});

  @override
  ConsumerState<PersonalSettingsScreen> createState() =>
      _PersonalSettingsScreenState();
}

class _PersonalSettingsScreenState
    extends ConsumerState<PersonalSettingsScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _age = TextEditingController();
  final _weight = TextEditingController();
  final _height = TextEditingController();
  String _goal = 'maintain';
  bool _loading = true;
  bool _saving = false;
  String? _message;
  String? _nameError;
  String? _ageError;
  String? _weightError;
  String? _heightError;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final email = AppConfig.hasSupabase
        ? Supabase.instance.client.auth.currentUser?.email
        : null;
    setState(() {
      _email.text = email ?? context.t('profile:emailLinked');
      _name.text = prefs.getString('fittrack_personal_name') ?? '';
      _age.text = prefs.getString('fittrack_personal_age') ?? '';
      _weight.text = prefs.getString('fittrack_personal_weight') ?? '';
      _height.text = prefs.getString('fittrack_personal_height') ?? '';
      _goal = prefs.getString('fittrack_personal_goal') ?? 'maintain';
      _loading = false;
    });
    // The profile row is the source of truth when signed in; the device copy
    // above keeps the form usable offline.
    final service = ref.read(profileServiceProvider);
    if (service == null) return;
    try {
      final profile = await service.profile();
      if (profile == null || !mounted) return;
      setState(() {
        final name = profile['display_name'] as String?;
        final weight = profile['bodyweight_kg'] as num?;
        final height = profile['height_cm'] as num?;
        final goal = profile['goal'] as String?;
        if (name != null && name.isNotEmpty) _name.text = name;
        if (weight != null) _weight.text = weight.toString();
        if (height != null) _height.text = height.toString();
        if (goal != null && goal.isNotEmpty) _goal = goal;
      });
    } catch (_) {
      // Offline with no cached profile: keep the device values.
    }
  }

  Future<void> _save() async {
    final weight = double.tryParse(_weight.text);
    final height =
        _height.text.trim().isEmpty ? null : double.tryParse(_height.text);
    final ageText = _age.text.trim();
    final age = ageText.isEmpty ? null : int.tryParse(ageText);
    final nameBad = _name.text.trim().isEmpty;
    final weightBad = weight == null || weight < 30 || weight > 300;
    final heightBad = _height.text.trim().isNotEmpty &&
        (height == null || height < 50 || height > 250);
    final ageBad =
        ageText.isNotEmpty && (age == null || age < 10 || age > 100);
    setState(() {
      _message = null;
      _nameError = nameBad ? context.t('profile:errName') : null;
      _weightError = weightBad ? context.t('profile:errWeight') : null;
      _heightError = heightBad ? context.t('profile:errHeight') : null;
      _ageError = ageBad ? context.t('profile:errAge') : null;
    });
    if (weight == null || nameBad || weightBad || heightBad || ageBad) return;

    setState(() => _saving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fittrack_personal_name', _name.text.trim());
    await prefs.setString('fittrack_personal_age', ageText);
    await prefs.setString('fittrack_personal_weight', _weight.text.trim());
    await prefs.setString('fittrack_personal_height', _height.text.trim());
    await prefs.setString('fittrack_personal_goal', _goal);

    final service = ref.read(profileServiceProvider);
    var message = 'profile:personalSavedDevice';
    if (service != null) {
      try {
        await service.updateProfile({
          'display_name': _name.text.trim(),
          'bodyweight_kg': weight,
          if (height != null) 'height_cm': height,
          'goal': _goal,
          'protein_goal_g': calculateProteinGoal(
            bodyweightKg: weight,
            goal: _goal,
            heightCm: height,
          ),
        });
        message = 'profile:personalSavedSynced';
      } catch (_) {
        message = 'profile:personalSavedRetry';
      }
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _message = context.t(message);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _age.dispose();
    _weight.dispose();
    _height.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final title = context.t('profile:personalInfoTitle');
    if (_loading) return _LoadingScreen(title: title, colors: colors);

    final weight = double.tryParse(_weight.text);
    final height = double.tryParse(_height.text);
    final protein = weight == null || weight < 30 || weight > 300
        ? null
        : calculateProteinGoal(
            bodyweightKg: weight,
            goal: _goal,
            heightCm: height != null && height >= 50 && height <= 250
                ? height
                : null,
          );
    const goals = [
      ('bulk', 'common:bulkLabel', 'common:onbDescBulk'),
      ('maintain', 'common:maintainLabel', 'common:onbDescMaintain'),
      ('cut', 'common:cutLabel', 'common:onbDescCut'),
    ];

    return Scaffold(
      backgroundColor: colors.bg,
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(
          FitTrackSpacing.lg,
          FitTrackSpacing.md,
          FitTrackSpacing.lg,
          FitTrackSpacing.xxl,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(top: BorderSide(color: colors.line)),
        ),
        child: SafeArea(
          top: false,
          child: FitTrackButton(
            label: context.t('profile:saveChanges'),
            size: FitTrackButtonSize.lg,
            fullWidth: true,
            loading: _saving,
            onPressed: _saving ? null : () => unawaited(_save()),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            _Header(title: title),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  FitTrackSpacing.lg,
                  FitTrackSpacing.lg,
                  FitTrackSpacing.lg,
                  FitTrackSpacing.xl,
                ),
                children: [
                  FitTrackTextField(
                    label: context.t('profile:displayName'),
                    controller: _name,
                    hint: context.t('profile:displayNamePlaceholder'),
                    errorText: _nameError,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),
                  FitTrackTextField(
                    label: context.t('profile:emailLabel'),
                    controller: _email,
                    enabled: false,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: FitTrackTextField(
                          label: context.t('profile:ageLabel'),
                          controller: _age,
                          errorText: _ageError,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FitTrackTextField(
                          label: context.t('profile:heightCmLabel'),
                          controller: _height,
                          errorText: _heightError,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  FitTrackTextField(
                    label: context.t('profile:weightKgLabel'),
                    controller: _weight,
                    errorText: _weightError,
                    helper: context.t('profile:weightHelper'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
                  ),
                  if (protein != null) ...[
                    const SizedBox(height: FitTrackSpacing.sm),
                    Text(
                      '${context.t('profile:suggestedProtein')}: '
                      '${context.t('profile:perDay', args: {
                            'amount': protein
                          })}',
                      style: FitTrackText.caption.copyWith(
                        color: colors.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: FitTrackSpacing.xl),
                  Semantics(
                    header: true,
                    child: Text(
                      context.t('profile:fitnessGoal'),
                      style: FitTrackText.caption.copyWith(
                        color: colors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final g in goals) ...[
                    _GoalOption(
                      label: context.t(g.$2),
                      description: context.t(g.$3),
                      selected: _goal == g.$1,
                      onTap: () => setState(() {
                        _goal = g.$1;
                        _message = null;
                      }),
                    ),
                    const SizedBox(height: FitTrackSpacing.sm),
                  ],
                  if (_message != null) ...[
                    const SizedBox(height: FitTrackSpacing.xs),
                    Semantics(
                      liveRegion: true,
                      child: Container(
                        padding: const EdgeInsets.all(FitTrackSpacing.md),
                        decoration: BoxDecoration(
                          color: colors.accentTint,
                          borderRadius:
                              BorderRadius.circular(FitTrackRadius.sm),
                        ),
                        child: Text(
                          _message!,
                          style: FitTrackText.label
                              .copyWith(color: colors.ink, height: 1.45),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A radio-style goal card used by the personal info form.
class _GoalOption extends StatelessWidget {
  const _GoalOption({
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final radius = BorderRadius.circular(FitTrackRadius.md);
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: '$label, $description',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: EdgeInsets.symmetric(horizontal: selected ? 13 : 14),
            decoration: BoxDecoration(
              color: selected ? colors.accentTint : colors.surface,
              borderRadius: radius,
              border: Border.all(
                color: selected ? colors.accent : colors.line,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? colors.accent : colors.faint,
                      width: selected ? 6 : 2,
                    ),
                  ),
                ),
                const SizedBox(width: FitTrackSpacing.md),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: FitTrackSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: FitTrackText.title.copyWith(
                            color: colors.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: FitTrackText.caption.copyWith(
                            color: colors.muted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GoalsSettingsScreen extends ConsumerStatefulWidget {
  const GoalsSettingsScreen({super.key});

  @override
  ConsumerState<GoalsSettingsScreen> createState() =>
      _GoalsSettingsScreenState();
}

/// One stepper row on the Goals screen.
class _GoalSpec {
  const _GoalSpec({
    required this.key,
    required this.label,
    required this.initial,
    required this.step,
    required this.min,
    required this.max,
    this.decimals = 0,
    this.unit = '',
    this.editScale = 1,
    this.subtitle,
  });

  /// Preference key suffix (`fittrack_goal_<key>`).
  final String key;

  /// Translation key of the row title.
  final String label;
  final double initial;
  final double step;
  final double min;
  final double max;
  final int decimals;
  final String unit;

  /// Divides the stored value for the edit sheet (sleep is stored in minutes
  /// and edited in hours).
  final double editScale;

  /// Translation key of the optional caption under the title.
  final String? subtitle;
}

const _goalSpecs = <_GoalSpec>[
  _GoalSpec(
    key: 'protein',
    label: 'settings:protein',
    subtitle: 'settings:goalOwnTarget',
    initial: 150,
    step: 5,
    min: 20,
    max: 500,
    unit: 'g',
  ),
  _GoalSpec(
    key: 'calories',
    label: 'settings:calories',
    initial: 2000,
    step: 50,
    min: 800,
    max: 8000,
  ),
  _GoalSpec(
    key: 'carbs',
    label: 'settings:carbs',
    initial: 250,
    step: 5,
    min: 10,
    max: 1000,
    unit: 'g',
  ),
  _GoalSpec(
    key: 'fat',
    label: 'nutrition:fat',
    initial: 65,
    step: 5,
    min: 10,
    max: 500,
    unit: 'g',
  ),
  _GoalSpec(
    key: 'fiber',
    label: 'settings:fiber',
    initial: 25,
    step: 1,
    min: 5,
    max: 150,
    unit: 'g',
  ),
  _GoalSpec(
    key: 'target_weight',
    label: 'settings:goalTargetWeight',
    initial: 70,
    step: 0.5,
    min: 30,
    max: 300,
    decimals: 1,
    unit: 'kg',
  ),
  _GoalSpec(
    key: 'water',
    label: 'settings:goalWater',
    initial: 2.5,
    step: 0.25,
    min: 0.5,
    max: 10,
    decimals: 1,
    unit: 'L',
  ),
  _GoalSpec(
    key: 'sleep',
    label: 'settings:goalSleep',
    initial: 480,
    step: 15,
    min: 180,
    max: 840,
    unit: 'h',
    editScale: 60,
  ),
  _GoalSpec(
    key: 'steps',
    label: 'settings:goalSteps',
    initial: 10000,
    step: 500,
    min: 500,
    max: 100000,
  ),
  _GoalSpec(
    key: 'workouts',
    label: 'settings:goalWorkouts',
    initial: 4,
    step: 1,
    min: 1,
    max: 14,
  ),
];

class _GoalsSettingsScreenState extends ConsumerState<GoalsSettingsScreen> {
  final _values = <String, double>{
    for (final g in _goalSpecs) g.key: g.initial,
  };
  String _goal = 'maintain';
  double? _bodyweightKg;
  double? _heightCm;
  bool _loading = true;
  bool _saving = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      for (final g in _goalSpecs) {
        final saved = double.tryParse(
          prefs.getString('fittrack_goal_${g.key}') ?? '',
        );
        if (saved != null && saved.isFinite && saved > 0) {
          _values[g.key] = saved;
        }
      }
      _goal = prefs.getString('fittrack_personal_goal') ?? 'maintain';
      _bodyweightKg =
          double.tryParse(prefs.getString('fittrack_personal_weight') ?? '');
      _heightCm =
          double.tryParse(prefs.getString('fittrack_personal_height') ?? '');
      _loading = false;
    });
    final service = ref.read(profileServiceProvider);
    if (service == null) return;
    try {
      final profile = await service.profile();
      if (profile == null || !mounted) return;
      setState(() {
        final protein = profile['protein_goal_g'] as num?;
        if (protein != null) _values['protein'] = protein.round().toDouble();
        final goal = profile['goal'] as String?;
        if (goal != null && goal.isNotEmpty) _goal = goal;
        final weight = profile['bodyweight_kg'] as num?;
        if (weight != null) _bodyweightKg = weight.toDouble();
        final height = profile['height_cm'] as num?;
        if (height != null) _heightCm = height.toDouble();
      });
    } catch (_) {
      // Offline with no cached profile: keep the device value.
    }
  }

  String _raw(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();

  Future<void> _save() async {
    final invalid = context.t('settings:goalsError');
    final savedDevice = context.t('settings:goalSavedDevice');
    final savedSynced = context.t('settings:goalSavedSynced');
    final savedRetry = context.t('settings:goalSavedRetry');
    if (_values.values.any((v) => !v.isFinite || v <= 0)) {
      setState(() => _message = invalid);
      return;
    }
    setState(() => _saving = true);
    final prefs = await SharedPreferences.getInstance();
    for (final entry in _values.entries) {
      await prefs.setString('fittrack_goal_${entry.key}', _raw(entry.value));
    }
    await prefs.setString('fittrack_personal_goal', _goal);
    var message = savedDevice;
    final service = ref.read(profileServiceProvider);
    final protein = _values['protein'];
    if (service != null && protein != null) {
      try {
        await service.updateProfile({
          'protein_goal_g': protein.round(),
          'goal': _goal,
        });
        message = savedSynced;
      } catch (_) {
        message = savedRetry;
      }
    }
    if (mounted) {
      setState(() {
        _message = message;
        _saving = false;
      });
    }
  }

  void _set(_GoalSpec g, double value) {
    setState(() {
      _values[g.key] = value.clamp(g.min, g.max).toDouble();
      _message = null;
    });
  }

  String _format(_GoalSpec g, double v) {
    final nf = NumberFormat.decimalPattern()
      ..minimumFractionDigits = g.decimals
      ..maximumFractionDigits = g.decimals;
    if (g.key == 'sleep') {
      final m = v.round();
      return context.t(
        'settings:goalSleepValue',
        args: {'h': m ~/ 60, 'm': m % 60},
      );
    }
    final number = nf.format(v);
    return g.unit.isEmpty || g.unit == 'h' ? number : '$number ${g.unit}';
  }

  Future<void> _edit(_GoalSpec g) async {
    final name = context.t(g.label);
    final current = _values[g.key] ?? g.initial;
    final result = await showFitTrackSheet<double>(
      context: context,
      builder: (ctx) => _GoalEditSheet(
        title: context.t('settings:goalEditTitle', args: {'name': name}),
        label: context.t('settings:goalValueLabel'),
        applyLabel: context.t('common:save'),
        invalidText: context.t('settings:goalInvalidValue'),
        unit: g.unit,
        initial: current / g.editScale,
      ),
    );
    if (result != null) _set(g, result * g.editScale);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final title = context.t('settings:goalsTitle');
    if (_loading) return _LoadingScreen(title: title, colors: colors);

    final weight = _bodyweightKg;
    final calculated = weight == null || weight < 30
        ? null
        : calculateProteinGoal(
            bodyweightKg: weight,
            goal: _goal,
            heightCm: _heightCm,
          );
    const goals = ['bulk', 'cut', 'maintain'];

    return Scaffold(
      backgroundColor: colors.bg,
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          FitTrackSpacing.lg,
          FitTrackSpacing.md,
          FitTrackSpacing.lg,
          FitTrackSpacing.xxl,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(top: BorderSide(color: colors.line)),
        ),
        child: SafeArea(
          top: false,
          child: FitTrackButton(
            label: context.t('settings:saveGoals'),
            size: FitTrackButtonSize.lg,
            fullWidth: true,
            loading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            _Header(title: title),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  FitTrackSpacing.lg,
                  FitTrackSpacing.md,
                  FitTrackSpacing.lg,
                  FitTrackSpacing.xl,
                ),
                children: [
                  Semantics(
                    label: context.t('settings:goalTraining'),
                    child: FitTrackSegmentedTabs(
                      labels: [
                        context.t('settings:goalBulk'),
                        context.t('settings:goalCut'),
                        context.t('settings:goalMaintain'),
                      ],
                      selectedIndex: goals.indexOf(_goal).clamp(0, 2),
                      onSelected: (i) => setState(() {
                        _goal = goals[i];
                        _message = null;
                      }),
                    ),
                  ),
                  const SizedBox(height: FitTrackSpacing.md),
                  FitTrackCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.t('settings:goalCalcLabel'),
                          style: FitTrackText.caption.copyWith(
                            color: colors.muted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: FitTrackSpacing.xs),
                        if (calculated == null)
                          Text(
                            context.t('settings:goalCalcMissing'),
                            style: FitTrackText.label
                                .copyWith(color: colors.muted),
                          )
                        else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '$calculated',
                                style: FitTrackText.stat.copyWith(
                                  color: colors.ink,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  context.t(
                                    'settings:goalCalcUnit',
                                    args: {
                                      'kg': weight!.toStringAsFixed(1),
                                    },
                                  ),
                                  style: FitTrackText.label
                                      .copyWith(color: colors.muted),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: FitTrackSpacing.md),
                  if (_message != null) ...[
                    Semantics(
                      liveRegion: true,
                      child: Container(
                        padding: const EdgeInsets.all(FitTrackSpacing.md),
                        decoration: BoxDecoration(
                          color: colors.accentTint,
                          borderRadius:
                              BorderRadius.circular(FitTrackRadius.sm),
                        ),
                        child: Text(
                          _message!,
                          style: FitTrackText.label
                              .copyWith(color: colors.ink, height: 1.45),
                        ),
                      ),
                    ),
                    const SizedBox(height: FitTrackSpacing.md),
                  ],
                  FitTrackCard(
                    padding: EdgeInsets.zero,
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(FitTrackRadius.card - 1),
                      child: Column(
                        children: [
                          for (var i = 0; i < _goalSpecs.length; i++)
                            _GoalStepper(
                              first: i == 0,
                              name: context.t(_goalSpecs[i].label),
                              subtitle: _goalSpecs[i].subtitle == null
                                  ? null
                                  : context.t(_goalSpecs[i].subtitle!),
                              value: _format(
                                _goalSpecs[i],
                                _values[_goalSpecs[i].key] ??
                                    _goalSpecs[i].initial,
                              ),
                              decreaseLabel: context.t(
                                'settings:goalDecrease',
                                args: {'name': context.t(_goalSpecs[i].label)},
                              ),
                              increaseLabel: context.t(
                                'settings:goalIncrease',
                                args: {'name': context.t(_goalSpecs[i].label)},
                              ),
                              onDecrease: () => _set(
                                _goalSpecs[i],
                                (_values[_goalSpecs[i].key] ??
                                        _goalSpecs[i].initial) -
                                    _goalSpecs[i].step,
                              ),
                              onIncrease: () => _set(
                                _goalSpecs[i],
                                (_values[_goalSpecs[i].key] ??
                                        _goalSpecs[i].initial) +
                                    _goalSpecs[i].step,
                              ),
                              onEdit: () => _edit(_goalSpecs[i]),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalStepper extends StatelessWidget {
  const _GoalStepper({
    required this.first,
    required this.name,
    required this.value,
    required this.decreaseLabel,
    required this.increaseLabel,
    required this.onDecrease,
    required this.onIncrease,
    required this.onEdit,
    this.subtitle,
  });

  final bool first;
  final String name;
  final String? subtitle;
  final String value;
  final String decreaseLabel;
  final String increaseLabel;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.fromLTRB(14, 0, 10, 0),
      decoration: BoxDecoration(
        border: first ? null : Border(top: BorderSide(color: colors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: FitTrackText.body.copyWith(
                    color: colors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: FitTrackText.caption.copyWith(
                        color: colors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          FitTrackIconButton(
            icon: FitIcons.remove,
            semanticLabel: decreaseLabel,
            style: FitTrackIconButtonStyle.outlined,
            onPressed: onDecrease,
          ),
          Semantics(
            button: true,
            label: '$name $value',
            child: ExcludeSemantics(
              child: InkWell(
                borderRadius: BorderRadius.circular(FitTrackRadius.sm),
                onTap: onEdit,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 76,
                    minHeight: FitTrackSpacing.touchMin,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    value,
                    textAlign: TextAlign.center,
                    style: FitTrackText.body.copyWith(
                      color: colors.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          FitTrackIconButton(
            icon: FitIcons.add,
            semanticLabel: increaseLabel,
            style: FitTrackIconButtonStyle.outlined,
            onPressed: onIncrease,
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet for typing an exact goal value instead of stepping.
class _GoalEditSheet extends StatefulWidget {
  const _GoalEditSheet({
    required this.title,
    required this.label,
    required this.applyLabel,
    required this.invalidText,
    required this.unit,
    required this.initial,
  });

  final String title;
  final String label;
  final String applyLabel;
  final String invalidText;
  final String unit;
  final double initial;

  @override
  State<_GoalEditSheet> createState() => _GoalEditSheetState();
}

class _GoalEditSheetState extends State<_GoalEditSheet> {
  late final _controller = TextEditingController(
    text: widget.initial == widget.initial.roundToDouble()
        ? widget.initial.round().toString()
        : widget.initial.toString(),
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _apply() {
    final v = double.tryParse(_controller.text.trim().replaceAll(',', '.'));
    if (v == null || !v.isFinite || v <= 0) {
      setState(() => _error = widget.invalidText);
      return;
    }
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            style: FitTrackText.titleLg.copyWith(
              color: colors.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: FitTrackSpacing.lg),
          FitTrackTextField(
            label: widget.label,
            controller: _controller,
            autofocus: true,
            errorText: _error,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _apply(),
            suffix: widget.unit.isEmpty
                ? null
                : Padding(
                    padding: const EdgeInsets.all(FitTrackSpacing.md),
                    child: Text(
                      widget.unit,
                      style: FitTrackText.body.copyWith(color: colors.muted),
                    ),
                  ),
          ),
          const SizedBox(height: FitTrackSpacing.lg),
          FitTrackButton(
            label: widget.applyLabel,
            size: FitTrackButtonSize.lg,
            fullWidth: true,
            onPressed: _apply,
          ),
        ],
      ),
    );
  }
}

class AlertsSettingsScreen extends ConsumerWidget {
  const AlertsSettingsScreen({super.key});

  static Color _color(AppPalette c, ReminderCategory category) =>
      switch (category) {
        ReminderCategory.morning => c.xpColor,
        ReminderCategory.nutrition => c.nutritionColor,
        ReminderCategory.hydration => c.waterColor,
        ReminderCategory.fitness => c.workoutColor,
        ReminderCategory.sleep => c.sleepColor,
        ReminderCategory.supplement => c.cardioColor,
      };

  static IconData _icon(ReminderCategory c) => switch (c) {
        ReminderCategory.morning => FitIcons.sun,
        ReminderCategory.nutrition => FitIcons.nutrition,
        ReminderCategory.hydration => FitIcons.water,
        ReminderCategory.fitness => FitIcons.workout,
        ReminderCategory.sleep => FitIcons.sleep,
        ReminderCategory.supplement => FitIcons.supplement,
      };

  static String _categoryLabel(BuildContext context, ReminderCategory c) =>
      context.t('settings:cat_${c.name}');

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    ReminderDef def,
    bool enabled,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final deniedMessage = context.t('settings:enableNotificationsNote');
    final result = await ref
        .read(remindersProvider.notifier)
        .setEnabled(def.id, enabled: enabled);
    if (result == ToggleResult.permissionDenied) {
      messenger.showSnackBar(SnackBar(content: Text(deniedMessage)));
    }
  }

  Future<void> _pickTime(
    BuildContext context,
    WidgetRef ref,
    ReminderDef def,
    String current,
  ) async {
    final t = parseTime(current) ?? parseTime(def.defaultTime)!;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: t.hour, minute: t.minute),
    );
    if (picked == null) {
      return;
    }
    await ref
        .read(remindersProvider.notifier)
        .setTime(def.id, formatTime24(picked.hour, picked.minute));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppPalette.of(context);
    final settings = ref.watch(remindersProvider);

    return settings.when(
      loading: () => _LoadingScreen(
          title: context.t('settings:notifications'), colors: colors),
      error: (_, __) => Scaffold(
        backgroundColor: colors.bg,
        body: SafeArea(
          child: Column(
            children: [
              _Header(title: context.t('settings:notifications')),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(FitTrackSpacing.xxl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.t('settings:loadRemindersFailed'),
                          textAlign: TextAlign.center,
                          style: FitTrackText.body.copyWith(color: colors.muted),
                        ),
                        const SizedBox(height: FitTrackSpacing.lg),
                        FitTrackButton(
                          label: context.t('settings:retry'),
                          icon: FitIcons.refresh,
                          variant: FitTrackButtonVariant.secondary,
                          onPressed: () => ref.invalidate(remindersProvider),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      data: (value) => Scaffold(
        backgroundColor: colors.bg,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 44),
            children: [
              _Header(
                title: context.t('settings:notifications'),
                subtitle: value.enabledCount == 0
                    ? context.t('settings:allRemindersOff')
                    : context.t(
                        value.enabledCount == 1
                            ? 'settings:activeReminder'
                            : 'settings:activeReminders',
                        args: {'count': value.enabledCount},
                      ),
              ),
              for (final category in ReminderCategory.values) ...[
                _SectionTitle(_categoryLabel(context, category).toUpperCase()),
                _Surface(
                  children: [
                    for (final def
                        in reminderCatalog.where((d) => d.category == category))
                      _ReminderRow(
                        def: def,
                        pref: value.of(def),
                        color: _color(colors, category),
                        icon: _icon(category),
                        first: def ==
                            reminderCatalog
                                .where((d) => d.category == category)
                                .first,
                        onToggle: (on) => _toggle(context, ref, def, on),
                        onTime: () =>
                            _pickTime(context, ref, def, value.of(def).time),
                      ),
                  ],
                ),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  FitTrackSpacing.lg + 2,
                  FitTrackSpacing.lg,
                  FitTrackSpacing.lg,
                  0,
                ),
                child: Text(
                  context.t('settings:remindersNote'),
                  style: FitTrackText.caption.copyWith(color: colors.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({
    required this.def,
    required this.pref,
    required this.color,
    required this.icon,
    required this.onToggle,
    required this.onTime,
    required this.first,
  });

  final ReminderDef def;
  final ReminderPref pref;
  final Color color;
  final IconData icon;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTime;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final time = formatTime12(pref.time);
    final schedule = context.t('settings:everyDayAt', args: {'time': time});
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.only(left: 14, right: 6),
      decoration: BoxDecoration(
        border: first ? null : Border(top: BorderSide(color: colors.line)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: FitTrackSpacing.md),
          Expanded(
            child: Semantics(
              button: true,
              label: '${def.label}, $schedule',
              hint: context.t('settings:changeTime'),
              child: ExcludeSemantics(
                child: InkWell(
                  onTap: onTime,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          def.label,
                          style: FitTrackText.title.copyWith(
                            color: colors.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text.rich(
                          TextSpan(
                            text: context.t('settings:everyDay'),
                            children: [
                              TextSpan(
                                text: ' · $time',
                                style: TextStyle(
                                  color: pref.enabled
                                      ? colors.ink
                                      : colors.muted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          style: FitTrackText.caption
                              .copyWith(color: colors.muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Semantics(
            label: def.label,
            child: Switch(value: pref.enabled, onChanged: onToggle),
          ),
        ],
      ),
    );
  }
}

class ThemeSettingsScreen extends ConsumerStatefulWidget {
  const ThemeSettingsScreen({super.key});

  @override
  ConsumerState<ThemeSettingsScreen> createState() =>
      _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends ConsumerState<ThemeSettingsScreen> {
  static const _modes = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];
  String _units = 'metric';

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  Future<void> _loadUnits() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _units = prefs.getString('fittrack_units') ?? 'metric');
  }

  Future<void> _setUnits(String value) async {
    setState(() => _units = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fittrack_units', value);
  }

  String _modeName(ThemeMode mode) => switch (mode) {
        ThemeMode.dark => context.t('settings:dark'),
        ThemeMode.light => context.t('settings:light'),
        ThemeMode.system => context.t('settings:system'),
      };

  String _modeDesc(ThemeMode mode) => switch (mode) {
        ThemeMode.dark => context.t('settings:darkDesc'),
        ThemeMode.light => context.t('settings:lightDesc'),
        ThemeMode.system => context.t('settings:systemDesc'),
      };

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final selected = ref.watch(themeModeProvider);
    final language = ref.watch(languageProvider);
    final caption = FitTrackText.caption.copyWith(color: colors.muted);
    const pad = EdgeInsets.symmetric(horizontal: FitTrackSpacing.lg);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 44),
          children: [
            _Header(
              title: context.t('settings:appearanceAndLanguage'),
              subtitle: context.t(
                'settings:currentTheme',
                args: {'theme': _modeName(selected)},
              ),
            ),
            _SectionTitle(context.t('settings:theme').toUpperCase()),
            Padding(
              padding: pad,
              child: FitTrackSegmentedTabs(
                labels: [for (final m in _modes) _modeName(m)],
                selectedIndex: _modes.indexOf(selected),
                onSelected: (i) => _setTheme(ref, _modes[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FitTrackSpacing.lg + 2,
                6,
                FitTrackSpacing.lg,
                0,
              ),
              child: Text(_modeDesc(selected), style: caption),
            ),
            _SectionTitle(context.t('settings:unitsTitle').toUpperCase()),
            Padding(
              padding: pad,
              child: FitTrackSegmentedTabs(
                labels: [
                  context.t('settings:metric'),
                  context.t('settings:imperial'),
                ],
                selectedIndex: _units == 'imperial' ? 1 : 0,
                onSelected: (i) => _setUnits(i == 1 ? 'imperial' : 'metric'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FitTrackSpacing.lg + 2,
                6,
                FitTrackSpacing.lg,
                0,
              ),
              child: Text(
                context.t(
                  _units == 'imperial'
                      ? 'settings:imperialDesc'
                      : 'settings:metricDesc',
                ),
                style: caption,
              ),
            ),
            _SectionTitle(context.t('settings:language').toUpperCase()),
            _Surface(
              children: [
                for (var i = 0; i < supportedLanguages.length; i++)
                  _LanguageRow(
                    native: supportedLanguages[i].nativeLabel,
                    english: supportedLanguages[i].label,
                    active: language == supportedLanguages[i].code,
                    first: i == 0,
                    onTap: () => ref
                        .read(languageProvider.notifier)
                        .select(supportedLanguages[i].code),
                  ),
              ],
            ),
            _SectionTitle(context.t('settings:preview').toUpperCase()),
            Padding(
              padding: pad,
              child: FitTrackCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.t('settings:sampleCard'),
                            style: FitTrackText.title.copyWith(
                              color: colors.ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        FitTrackBadge(
                          label: context.t('settings:previewActive'),
                          tone: FitTrackBadgeTone.ok,
                          icon: FitIcons.check,
                        ),
                      ],
                    ),
                    const SizedBox(height: FitTrackSpacing.md),
                    Text(context.t('settings:previewNote'), style: caption),
                    const SizedBox(height: FitTrackSpacing.md),
                    FitTrackProgressBar(
                      progress: .65,
                      color: colors.accent,
                      semanticLabel: context.t('settings:sampleCard'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _setTheme(WidgetRef ref, ThemeMode mode) async {
    ref.read(themeModeProvider.notifier).state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fittrack_theme_preference', mode.name);
  }
}

/// Radio row for one language: native name, English name, 20px radio.
class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.native,
    required this.english,
    required this.active,
    required this.first,
    required this.onTap,
  });
  final String native;
  final String english;
  final bool active;
  final bool first;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: active,
      button: true,
      label: '$native, $english',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              border:
                  first ? null : Border(top: BorderSide(color: colors.line)),
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: active ? colors.accent : colors.lineStrong,
                      width: active ? 6 : 2,
                    ),
                  ),
                ),
                const SizedBox(width: FitTrackSpacing.md),
                Expanded(
                  child: Text(
                    native,
                    style: FitTrackText.title.copyWith(
                      color: colors.ink,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  english,
                  style: FitTrackText.caption.copyWith(color: colors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Device-held values the settings hub shows next to its rows.
final _hubPrefsProvider = FutureProvider.autoDispose<
    ({String goal, String units, int rest})>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return (
    goal: prefs.getString('fittrack_personal_goal') ?? 'maintain',
    units: prefs.getString('fittrack_units') ?? 'metric',
    rest: prefs.getInt('fittrack_default_rest') ?? 90,
  );
});

/// App version shown at the foot of the hub. Pass `--dart-define=APP_VERSION=`
/// from CI so it follows pubspec.yaml.
const _appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppPalette.of(context);
    final prefs = ref.watch(_hubPrefsProvider).valueOrNull;
    final name = ref.watch(dashboardProvider).valueOrNull?.displayName;
    final goals = ref.watch(goalTargetsProvider).valueOrNull;
    final sub = ref.watch(subscriptionProvider);
    final reminders = ref.watch(remindersProvider).valueOrNull;
    final themeMode = ref.watch(themeModeProvider);
    final language = ref.watch(languageProvider);

    String goalName(String goal) => switch (goal) {
          'bulk' => context.t('settings:goalBulk'),
          'cut' => context.t('settings:goalCut'),
          _ => context.t('settings:goalMaintain'),
        };
    final languageName = supportedLanguages
        .where((l) => l.code == language)
        .map((l) => l.nativeLabel)
        .firstOrNull;
    final themeName = switch (themeMode) {
      ThemeMode.light => context.t('settings:light'),
      ThemeMode.system => context.t('settings:system'),
      ThemeMode.dark => context.t('settings:dark'),
    };

    Future<void> open(String route) async {
      await context.push(route);
      ref.invalidate(_hubPrefsProvider);
      ref.invalidate(goalTargetsProvider);
    }

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _Header(title: context.t('settings:hubTitle')),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  FitTrackSpacing.lg,
                  FitTrackSpacing.sm,
                  FitTrackSpacing.lg,
                  FitTrackSpacing.xxl,
                ),
                children: [
                  _HubGroup(
                    title: context.t('settings:hubAccount'),
                    rows: [
                      _HubRow(
                        title: context.t('profile:personalInfoTitle'),
                        value: name,
                        onTap: () => open('/settings/personal'),
                      ),
                      _HubRow(
                        title: context.t('settings:goalsTitle'),
                        value: goals == null || prefs == null
                            ? null
                            : context.t(
                                'settings:hubGoalValue',
                                args: {
                                  'goal': goalName(prefs.goal),
                                  'g': goals.protein.round(),
                                },
                              ),
                        onTap: () => open('/settings/goals'),
                      ),
                      _HubRow(
                        title: context.t('settings:hubSubscription'),
                        value: sub.isTrial
                            ? context.t(
                                'settings:hubTrial',
                                args: {
                                  'days': sub.trialDaysLeft(DateTime.now()),
                                },
                              )
                            : sub.isPro
                                ? context.t('common:subPlanPro')
                                : context.t('common:subPlanFree'),
                        onTap: () => open('/subscription'),
                      ),
                    ],
                  ),
                  _HubGroup(
                    title: context.t('settings:hubPreferences'),
                    rows: [
                      _HubRow(
                        title: context.t('settings:appearanceAndLanguage'),
                        value: [themeName, if (languageName != null) languageName]
                            .join(' · '),
                        onTap: () => open('/settings/theme'),
                      ),
                      _HubRow(
                        title: context.t('settings:unitsTitle'),
                        value: prefs == null
                            ? null
                            : context.t(
                                prefs.units == 'imperial'
                                    ? 'settings:imperial'
                                    : 'settings:metric',
                              ),
                        onTap: () => open('/settings/app-settings'),
                      ),
                      _HubRow(
                        title: context.t('settings:workoutRestTimer'),
                        value: prefs == null
                            ? null
                            : _restLabel(prefs.rest),
                        onTap: () => open('/settings/app-settings'),
                      ),
                      _HubRow(
                        title: context.t('settings:hubReminders'),
                        value: reminders == null
                            ? null
                            : reminders.enabledCount == 0
                                ? context.t('settings:allRemindersOff')
                                : context.t(
                                    'settings:hubRemindersOn',
                                    args: {'count': reminders.enabledCount},
                                  ),
                        onTap: () => open('/settings/alerts'),
                      ),
                    ],
                  ),
                  const SizedBox(height: FitTrackSpacing.lg),
                  FitTrackCard(
                    padding: EdgeInsets.zero,
                    child: _HubRow(
                      title: context.t('common:signOut'),
                      danger: true,
                      showChevron: false,
                      first: true,
                      onTap: () async {
                        final auth = ref.read(authRepositoryProvider);
                        if (auth != null) {
                          await auth.signOut();
                          if (context.mounted) context.go('/account');
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: FitTrackSpacing.md),
                  Text(
                    context.t(
                      'settings:hubVersion',
                      args: {'version': _appVersion},
                    ),
                    textAlign: TextAlign.center,
                    style: FitTrackText.caption.copyWith(
                      color: c.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _restLabel(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  if (m == 0) return '${s}s';
  return s == 0 ? '${m}m' : '${m}m ${s}s';
}

class _HubGroup extends StatelessWidget {
  const _HubGroup({required this.title, required this.rows});

  final String title;
  final List<_HubRow> rows;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: FitTrackSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, FitTrackSpacing.sm, 2, 6),
            child: Semantics(
              header: true,
              child: Text(
                title.toUpperCase(),
                style: FitTrackText.caption.copyWith(
                  color: c.muted,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          FitTrackCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++)
                  rows[i].copyWith(first: i == 0),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HubRow extends StatelessWidget {
  const _HubRow({
    required this.title,
    required this.onTap,
    this.value,
    this.danger = false,
    this.showChevron = true,
    this.first = false,
  });

  final String title;
  final String? value;
  final VoidCallback onTap;
  final bool danger;
  final bool showChevron;
  final bool first;

  _HubRow copyWith({bool? first}) => _HubRow(
        title: title,
        value: value,
        onTap: onTap,
        danger: danger,
        showChevron: showChevron,
        first: first ?? this.first,
      );

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return Semantics(
      button: true,
      label: [title, if (value != null) value!].join(', '),
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(
              horizontal: FitTrackSpacing.lg - 2,
            ),
            decoration: BoxDecoration(
              border: first ? null : Border(top: BorderSide(color: c.line)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: FitTrackText.body.copyWith(
                      color: danger ? c.textBad : c.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (value != null) ...[
                  const SizedBox(width: FitTrackSpacing.md),
                  Flexible(
                    child: Text(
                      value!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: FitTrackText.label.copyWith(
                        color: c.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                if (showChevron) ...[
                  const SizedBox(width: FitTrackSpacing.sm),
                  Icon(FitIcons.chevronRight, size: 20, color: c.faint),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  String _units = 'metric';
  int _rest = 90;
  bool _loading = true;

  static const _rests = <(int, String)>[
    (30, '30s'),
    (60, '1m'),
    (90, '1m 30s'),
    (120, '2m'),
    (180, '3m'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _units = prefs.getString('fittrack_units') ?? 'metric';
      _rest = prefs.getInt('fittrack_default_rest') ?? 90;
      _loading = false;
    });
  }

  Future<void> _setUnits(String value) async {
    setState(() => _units = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fittrack_units', value);
  }

  Future<void> _setRest(int value) async {
    setState(() => _rest = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('fittrack_default_rest', value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    if (_loading) {
      return _LoadingScreen(
          title: context.t('settings:appSettings'), colors: colors);
    }

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 44),
          children: [
            _Header(
              title: context.t('settings:appSettings'),
              subtitle: context.t('settings:personalSettingsSubtitle'),
            ),
            _SectionTitle(context.t('settings:unitMetrics')),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ChoiceCard(
                children: [
                  _ChoiceRow(
                    title: context.t('settings:metric'),
                    subtitle: context.t('settings:metricDesc'),
                    active: _units == 'metric',
                    onTap: () => _setUnits('metric'),
                  ),
                  _ChoiceRow(
                    title: context.t('settings:imperial'),
                    subtitle: context.t('settings:imperialDesc'),
                    active: _units == 'imperial',
                    last: true,
                    onTap: () => _setUnits('imperial'),
                  ),
                ],
              ),
            ),
            _SectionTitle(context.t('settings:defaultRestTimer')),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ChoiceCard(
                children: [
                  for (var i = 0; i < _rests.length; i++)
                    _ChoiceRow(
                      title: _rests[i].$2,
                      active: _rest == _rests[i].$1,
                      last: i == _rests.length - 1,
                      onTap: () => _setRest(_rests[i].$1),
                    ),
                ],
              ),
            ),
            _SectionTitle(context.t('settings:language')),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Consumer(
                builder: (context, ref, _) {
                  final current = ref.watch(languageProvider);
                  return _ChoiceCard(
                    children: [
                      for (var i = 0; i < supportedLanguages.length; i++)
                        _ChoiceRow(
                          title: supportedLanguages[i].nativeLabel,
                          subtitle: supportedLanguages[i].label,
                          active: current == supportedLanguages[i].code,
                          last: i == supportedLanguages.length - 1,
                          onTap: () => ref
                              .read(languageProvider.notifier)
                              .select(supportedLanguages[i].code),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Settings screens share one header; the look comes from [FitTrackTopBar].
class _Header extends StatelessWidget {
  const _Header({required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => FitTrackTopBar(
        title: title,
        subtitle: subtitle,
        backLabel: context.t('settings:backLabel'),
        onBack: () => context.pop(),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FitTrackSpacing.lg + 2,
        FitTrackSpacing.lg + FitTrackSpacing.xs,
        FitTrackSpacing.lg,
        6,
      ),
      child: Text(
        text,
        style: FitTrackText.caption.copyWith(
          color: colors.muted,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: FitTrackSpacing.lg),
      child: FitTrackCard(
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(FitTrackRadius.card - 1),
          child: Column(children: children),
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return FitTrackCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(FitTrackRadius.card - 1),
        child: Column(children: children),
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.title,
    required this.active,
    required this.onTap,
    this.subtitle,
    this.last = false,
  });

  final String title;
  final String? subtitle;
  final bool active;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Semantics(
      button: true,
      selected: active,
      inMutuallyExclusiveGroup: true,
      label: [title, if (subtitle != null) subtitle!].join(', '),
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(
              horizontal: FitTrackSpacing.lg - 2,
              vertical: FitTrackSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: active ? colors.accentTint : Colors.transparent,
              border: last ? null : Border(bottom: BorderSide(color: colors.line)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: FitTrackText.body.copyWith(
                          color: colors.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            subtitle!,
                            style: FitTrackText.caption.copyWith(
                              color: colors.muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (active)
                  Icon(FitIcons.check, size: 20, color: colors.accentText),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen({required this.title, required this.colors});
  final String title;
  final AppPalette colors;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _Header(title: title),
            Expanded(
              child: Center(
                child: CircularProgressIndicator(color: colors.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
