import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/data/service_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_controller.dart';
import '../../reminders/application/reminders_controller.dart';
import '../../reminders/domain/reminder_catalog.dart';
import '../../reminders/domain/reminder_schedule.dart';
import '../../workouts/domain/workout_metrics.dart';
import '../../../core/l10n/language_controller.dart';
import '../../../core/l10n/translations.dart';

class PersonalSettingsScreen extends ConsumerStatefulWidget {
  const PersonalSettingsScreen({super.key});

  @override
  ConsumerState<PersonalSettingsScreen> createState() =>
      _PersonalSettingsScreenState();
}

class _PersonalSettingsScreenState
    extends ConsumerState<PersonalSettingsScreen> {
  final _name = TextEditingController();
  final _weight = TextEditingController();
  final _height = TextEditingController();
  String _goal = 'maintain';
  bool _loading = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _name.text = prefs.getString('fittrack_personal_name') ?? '';
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
    if (_name.text.trim().isEmpty ||
        weight == null ||
        weight < 30 ||
        weight > 300 ||
        (height != null && (height < 50 || height > 250))) {
      setState(() => _message = 'Enter a valid name, weight and height.');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fittrack_personal_name', _name.text.trim());
    await prefs.setString('fittrack_personal_weight', _weight.text.trim());
    await prefs.setString('fittrack_personal_height', _height.text.trim());
    await prefs.setString('fittrack_personal_goal', _goal);

    final service = ref.read(profileServiceProvider);
    String message = 'Saved on this device. Sign in to sync your profile.';
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
        message = 'Saved. Your profile syncs automatically.';
      } catch (_) {
        message = 'Saved on this device. Profile sync will retry.';
      }
    }
    if (!mounted) return;
    setState(() => _message = message);
  }

  @override
  void dispose() {
    _name.dispose();
    _weight.dispose();
    _height.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    if (_loading) {
      return _LoadingScreen(title: 'Personal Settings', colors: colors);
    }

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 44),
          children: [
            const _Header(
              title: 'Personal Settings',
              subtitle: 'Profile, body metrics & goal',
            ),
            const _SectionTitle('PROFILE'),
            _Surface(
              children: [
                _TextFieldRow(
                  controller: _name,
                  icon: Icons.person_outline,
                  label: 'DISPLAY NAME',
                  hint: 'Your name',
                ),
                _TextFieldRow(
                  controller: _weight,
                  icon: Icons.monitor_weight_outlined,
                  label: 'BODY WEIGHT',
                  hint: 'kg',
                  numeric: true,
                ),
                _TextFieldRow(
                  controller: _height,
                  icon: Icons.height,
                  label: 'HEIGHT',
                  hint: 'cm',
                  numeric: true,
                  last: true,
                ),
              ],
            ),
            const _SectionTitle('FITNESS GOAL'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _GoalChoice(
                    label: 'Build Muscle',
                    description: 'Gain size and strength',
                    icon: Icons.fitness_center,
                    color: AppColors.workout,
                    selected: _goal == 'bulk',
                    onTap: () => setState(() => _goal = 'bulk'),
                  ),
                  const SizedBox(height: 8),
                  _GoalChoice(
                    label: 'Maintain',
                    description: 'Stay strong and consistent',
                    icon: Icons.balance,
                    color: AppColors.water,
                    selected: _goal == 'maintain',
                    onTap: () => setState(() => _goal = 'maintain'),
                  ),
                  const SizedBox(height: 8),
                  _GoalChoice(
                    label: 'Lose Fat',
                    description: 'Reduce fat while preserving muscle',
                    icon: Icons.local_fire_department,
                    color: AppColors.cardio,
                    selected: _goal == 'cut',
                    onTap: () => setState(() => _goal = 'cut'),
                  ),
                ],
              ),
            ),
            if (_message != null) _Message(text: _message!),
            _SaveButton(label: 'SAVE PERSONAL SETTINGS', onTap: _save),
          ],
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

class _GoalsSettingsScreenState extends ConsumerState<GoalsSettingsScreen> {
  final _steps = TextEditingController(text: '10000');
  final _protein = TextEditingController(text: '150');
  final _calories = TextEditingController(text: '2000');
  final _carbs = TextEditingController(text: '250');
  final _fat = TextEditingController(text: '65');
  final _fiber = TextEditingController(text: '25');
  bool _loading = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final pairs = <String, TextEditingController>{
      'steps': _steps,
      'protein': _protein,
      'calories': _calories,
      'carbs': _carbs,
      'fat': _fat,
      'fiber': _fiber,
    };
    for (final entry in pairs.entries) {
      entry.value.text =
          prefs.getString('fittrack_goal_${entry.key}') ?? entry.value.text;
    }
    if (mounted) setState(() => _loading = false);
    final service = ref.read(profileServiceProvider);
    if (service == null) return;
    try {
      final profile = await service.profile();
      final protein = profile?['protein_goal_g'] as num?;
      if (protein != null && mounted) {
        setState(() => _protein.text = protein.round().toString());
      }
    } catch (_) {
      // Offline with no cached profile: keep the device value.
    }
  }

  Future<void> _save() async {
    final pairs = <String, TextEditingController>{
      'steps': _steps,
      'protein': _protein,
      'calories': _calories,
      'carbs': _carbs,
      'fat': _fat,
      'fiber': _fiber,
    };
    final values = pairs.values.map((c) => double.tryParse(c.text)).toList();
    if (values.any((v) => v == null || !v.isFinite || v <= 0)) {
      setState(() => _message = 'All goals must be positive numbers.');
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    for (final entry in pairs.entries) {
      await prefs.setString(
        'fittrack_goal_${entry.key}',
        entry.value.text.trim(),
      );
    }
    var message = 'Daily goals saved on this device.';
    final service = ref.read(profileServiceProvider);
    final protein = double.tryParse(_protein.text);
    if (service != null && protein != null) {
      try {
        await service.updateProfile({'protein_goal_g': protein.round()});
        message = 'Daily goals saved. Your protein goal syncs automatically.';
      } catch (_) {
        message = 'Daily goals saved on this device. Sync will retry.';
      }
    }
    if (mounted) setState(() => _message = message);
  }

  @override
  void dispose() {
    for (final c in [_steps, _protein, _calories, _carbs, _fat, _fiber]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    if (_loading) return _LoadingScreen(title: 'Daily Goals', colors: colors);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 44),
          children: [
            const _Header(
              title: 'Daily Goals',
              subtitle: 'Targets used across your dashboard',
            ),
            const _SectionTitle('ACTIVITY'),
            _Surface(
              children: [
                _GoalField(
                  icon: Icons.directions_walk,
                  color: AppColors.water,
                  label: 'Daily steps',
                  controller: _steps,
                  suffix: 'steps',
                ),
                _GoalField(
                  icon: Icons.local_fire_department,
                  color: AppColors.workout,
                  label: 'Daily calories',
                  controller: _calories,
                  suffix: 'kcal',
                  last: true,
                ),
              ],
            ),
            const _SectionTitle('NUTRITION'),
            _Surface(
              children: [
                _GoalField(
                  icon: Icons.water_drop_outlined,
                  color: AppColors.nutrition,
                  label: 'Protein',
                  controller: _protein,
                  suffix: 'g',
                ),
                _GoalField(
                  icon: Icons.grain,
                  color: AppColors.water,
                  label: 'Carbohydrates',
                  controller: _carbs,
                  suffix: 'g',
                ),
                _GoalField(
                  icon: Icons.opacity,
                  color: AppColors.xp,
                  label: 'Fat',
                  controller: _fat,
                  suffix: 'g',
                ),
                _GoalField(
                  icon: Icons.eco_outlined,
                  color: AppColors.recovery,
                  label: 'Fiber',
                  controller: _fiber,
                  suffix: 'g',
                  last: true,
                ),
              ],
            ),
            if (_message != null) _Message(text: _message!),
            _SaveButton(label: 'SAVE DAILY GOALS', onTap: _save),
          ],
        ),
      ),
    );
  }
}

class AlertsSettingsScreen extends ConsumerWidget {
  const AlertsSettingsScreen({super.key});

  static Color _color(ReminderCategory c) => switch (c) {
        ReminderCategory.morning => AppColors.xp,
        ReminderCategory.nutrition => AppColors.nutrition,
        ReminderCategory.hydration => AppColors.water,
        ReminderCategory.fitness => AppColors.workout,
        ReminderCategory.sleep => AppColors.sleep,
        ReminderCategory.supplement => AppColors.recovery,
      };

  static IconData _icon(ReminderCategory c) => switch (c) {
        ReminderCategory.morning => Icons.wb_sunny_outlined,
        ReminderCategory.nutrition => Icons.restaurant,
        ReminderCategory.hydration => Icons.water_drop_outlined,
        ReminderCategory.fitness => Icons.fitness_center,
        ReminderCategory.sleep => Icons.bedtime_outlined,
        ReminderCategory.supplement => Icons.medication_outlined,
      };

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
      loading: () => _LoadingScreen(title: context.t('settings:notifications'), colors: colors),
      error: (_, __) => Scaffold(
        backgroundColor: colors.bg,
        body: SafeArea(
          child: Column(
            children: [
              _Header(title: context.t('settings:notifications')),
              Expanded(
                child: Center(
                  child: TextButton(
                    onPressed: () => ref.invalidate(remindersProvider),
                    child: const Text('Could not load reminders. Retry'),
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
                _SectionTitle(category.label.toUpperCase()),
                _Surface(
                  children: [
                    for (final def in reminderCatalog.where((d) => d.category == category))
                      _ReminderRow(
                        def: def,
                        pref: value.of(def),
                        color: _color(category),
                        icon: _icon(category),
                        last: def == reminderCatalog.where((d) => d.category == category).last,
                        onToggle: (on) => _toggle(context, ref, def, on),
                        onTime: () => _pickTime(context, ref, def, value.of(def).time),
                      ),
                  ],
                ),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: Text(
                  'Reminders repeat daily at the time you choose and work offline.',
                  style: TextStyle(fontSize: 11, height: 1.5, color: colors.faint),
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
    required this.last,
  });

  final ReminderDef def;
  final ReminderPref pref;
  final Color color;
  final IconData icon;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTime;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: colors.border2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              def.label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: colors.text),
            ),
          ),
          InkWell(
            onTap: onTime,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Text(
                formatTime12(pref.time),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: pref.enabled ? colors.accent : colors.faint,
                ),
              ),
            ),
          ),
          Switch(value: pref.enabled, onChanged: onToggle),
        ],
      ),
    );
  }
}

class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppPalette.of(context);
    final selected = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 44),
          children: [
            _Header(
              title: 'Appearance',
              subtitle: 'Currently: ${_themeName(selected)}',
            ),
            const _SectionTitle('THEME'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(4),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _ThemeChoice(
                      icon: Icons.bedtime,
                      title: 'Dark',
                      subtitle: 'Always dark interface',
                      active: selected == ThemeMode.dark,
                      onTap: () => _setTheme(ref, ThemeMode.dark),
                    ),
                    _ThemeChoice(
                      icon: Icons.wb_sunny_outlined,
                      title: 'Light',
                      subtitle: 'Always light interface',
                      active: selected == ThemeMode.light,
                      onTap: () => _setTheme(ref, ThemeMode.light),
                    ),
                    _ThemeChoice(
                      icon: Icons.phone_android,
                      title: 'System',
                      subtitle: 'Follows your device theme setting',
                      active: selected == ThemeMode.system,
                      last: true,
                      onTap: () => _setTheme(ref, ThemeMode.system),
                    ),
                  ],
                ),
              ),
            ),
            const _SectionTitle('PREVIEW'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Sample Card',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: colors.text,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colors.accent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'ACTIVE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: colors.accentText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Luminous Dark keeps chrome neutral and reserves color for data.',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.5,
                        color: colors.muted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: .65,
                        minHeight: 6,
                        backgroundColor: colors.border2,
                        valueColor: AlwaysStoppedAnimation(colors.accent),
                      ),
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
    await prefs.setString(
      'fittrack_theme_preference',
      _themeName(mode).toLowerCase(),
    );
  }

  static String _themeName(ThemeMode mode) => switch (mode) {
        ThemeMode.dark => 'Dark',
        ThemeMode.light => 'Light',
        ThemeMode.system => 'System',
      };
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
      return _LoadingScreen(title: context.t('settings:appSettings'), colors: colors);
    }

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
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

class _Header extends StatelessWidget {
  const _Header({required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: colors.header,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => context.pop(),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.card,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(Icons.arrow_back, size: 18, color: colors.text),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colors.text,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: TextStyle(fontSize: 11, color: colors.muted),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: colors.muted,
          letterSpacing: 2,
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
    final colors = AppPalette.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _TextFieldRow extends StatelessWidget {
  const _TextFieldRow({
    required this.controller,
    required this.icon,
    required this.label,
    required this.hint,
    this.numeric = false,
    this.last = false,
  });

  final TextEditingController controller;
  final IconData icon;
  final String label;
  final String hint;
  final bool numeric;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: colors.border2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.muted),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: numeric
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: colors.text,
              ),
              decoration: InputDecoration(
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                labelText: label,
                hintText: hint,
                labelStyle: TextStyle(
                  fontSize: 9,
                  color: colors.faint,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalChoice extends StatelessWidget {
  const _GoalChoice({
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: .10) : colors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : colors.border2),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: selected ? color : colors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(fontSize: 11, color: colors.muted),
                  ),
                ],
              ),
            ),
            if (selected)
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.check,
                  size: 13,
                  color: Color(0xFF060609),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GoalField extends StatelessWidget {
  const _GoalField({
    required this.icon,
    required this.color,
    required this.label,
    required this.controller,
    required this.suffix,
    this.last = false,
  });

  final IconData icon;
  final Color color;
  final String label;
  final TextEditingController controller;
  final String suffix;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: colors.border2)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: colors.text,
              ),
            ),
          ),
          SizedBox(
            width: 105,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.right,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: colors.text,
              ),
              decoration: InputDecoration(
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                suffixText: ' $suffix',
                suffixStyle: TextStyle(fontSize: 10, color: colors.faint),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.last = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: colors.border2)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
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
          Switch(
            value: value,
            onChanged: onChanged,
            thumbColor: WidgetStateProperty.resolveWith<Color?>(
              (states) =>
                  states.contains(WidgetState.selected) ? colors.accent : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.onTap,
    this.last = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool active;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: active ? colors.accentTint : Colors.transparent,
          border:
              last ? null : Border(bottom: BorderSide(color: colors.border)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: active ? colors.accentTint : colors.border2,
                borderRadius: BorderRadius.circular(4),
                border: active ? Border.all(color: colors.accent) : null,
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 20,
                color: active ? colors.accent : colors.muted,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: active ? colors.accent : colors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: colors.muted),
                  ),
                ],
              ),
            ),
            if (active)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.check, size: 13, color: colors.accentText),
              ),
          ],
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
    final colors = AppPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
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
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: active ? colors.accentTint : Colors.transparent,
          border:
              last ? null : Border(bottom: BorderSide(color: colors.border2)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: active ? colors.accent : colors.text,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        style: TextStyle(fontSize: 11, color: colors.faint),
                      ),
                    ),
                ],
              ),
            ),
            if (active)
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: colors.accent,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(Icons.check, size: 11, color: colors.accentText),
              ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.accentTint,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border2),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, color: colors.subtext),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: colors.accent,
            foregroundColor: colors.accentText,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: .8,
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
