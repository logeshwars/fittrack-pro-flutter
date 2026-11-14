import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/data/service_providers.dart';
import '../../../core/l10n/language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/fittrack_tokens.dart';
import '../../../core/widgets/fittrack_components.dart';
import '../../workouts/domain/workout_metrics.dart';
import '../../../core/widgets/fittrack_icons.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _weight = TextEditingController();
  String _goal = 'maintain';
  bool _saving = false;
  String? _error;

  static const _goals = <_Goal>[
    _Goal('bulk', 'common:bulkLabel', 'common:onbMetaBulk', 'common:onbDescBulk'),
    _Goal('cut', 'common:cutLabel', 'common:onbMetaCut', 'common:onbDescCut'),
    _Goal(
      'maintain',
      'common:maintainLabel',
      'common:onbMetaMaintain',
      'common:onbDescMaintain',
    ),
  ];

  @override
  void dispose() {
    _weight.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final weight = double.tryParse(_weight.text);
    if (weight == null || !weight.isFinite || weight < 30 || weight > 300) {
      setState(() => _error = context.t('common:onbWeightError'));
      return;
    }

    final repository = ref.read(authRepositoryProvider);
    final userId = repository?.currentUser?.id;
    if (userId == null) {
      context.go('/account');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fittrack_onboarding_complete_$userId', true);
    await prefs.setString('fittrack_personal_weight', _weight.text.trim());
    await prefs.setString('fittrack_personal_goal', _goal);

    // Store the choices and the derived protein goal on the profile. The write
    // is queued, so onboarding never blocks on the network.
    final service = ref.read(profileServiceProvider);
    if (service != null) {
      try {
        await service.completeOnboarding(goal: _goal, bodyweightKg: weight);
      } catch (_) {
        // Keep going: the device copy above already holds the answers.
      }
    }
    if (!mounted) return;
    context.go('/today');
  }

  double? get _weightKg {
    final w = double.tryParse(_weight.text.trim());
    return w == null || !w.isFinite || w < 30 || w > 300 ? null : w;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final repository = ref.watch(authRepositoryProvider);
    final metadata =
        repository?.currentUser?.userMetadata ?? const <String, dynamic>{};
    final rawName = (metadata['full_name'] ??
            metadata['name'] ??
            repository?.currentUser?.email?.split('@').first ??
            'Athlete')
        .toString();
    final firstName = rawName.trim().split(' ').first;
    final weight = _weightKg;
    final weightText = weight == null
        ? ''
        : weight == weight.roundToDouble()
            ? weight.round().toString()
            : weight.toStringAsFixed(1);

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
            label: context.t('common:getStarted'),
            size: FitTrackButtonSize.lg,
            fullWidth: true,
            loading: _saving,
            loadingLabel: context.t('common:settingUp'),
            onPressed: _saving ? null : _finish,
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(
                FitTrackSpacing.xs,
                FitTrackSpacing.sm,
                FitTrackSpacing.sm,
                FitTrackSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(bottom: BorderSide(color: colors.line)),
              ),
              child: Row(
                children: [
                  FitTrackIconButton(
                    icon: FitIcons.back,
                    semanticLabel: context.t('settings:backLabel'),
                    onPressed: () =>
                        context.canPop() ? context.pop() : context.go('/today'),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    context.t('common:setupLabel'),
                    style: FitTrackText.caption.copyWith(
                      color: colors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                  FitTrackSpacing.lg,
                  FitTrackSpacing.xl,
                  FitTrackSpacing.lg,
                  FitTrackSpacing.xxl,
                ),
                children: [
                  Text(
                    context.t('common:onbWelcome', args: {'name': firstName}),
                    style: FitTrackText.label.copyWith(
                      color: colors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.t('common:onbTitle'),
                    style: FitTrackText.titleXl.copyWith(color: colors.ink),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    weight == null
                        ? context.t('common:onbSubtitleNoWeight')
                        : context.t(
                            'common:onbSubtitleWeight',
                            args: {'kg': weightText},
                          ),
                    style: FitTrackText.body.copyWith(
                      color: colors.muted,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: FitTrackSpacing.xl),
                  FitTrackTextField(
                    label: context.t('common:bodyweightLabel'),
                    controller: _weight,
                    hint: context.t('profile:bodyweightPlaceholder'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.done,
                    errorText: _error,
                    onChanged: (_) => setState(() => _error = null),
                    suffix: Padding(
                      padding: const EdgeInsets.all(FitTrackSpacing.md),
                      child: Text(
                        'kg',
                        style: FitTrackText.body.copyWith(color: colors.muted),
                      ),
                    ),
                  ),
                  const SizedBox(height: FitTrackSpacing.xl),
                  Text(
                    context.t('common:mainGoalLabel'),
                    style: FitTrackText.caption.copyWith(
                      color: colors.muted,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: FitTrackSpacing.sm),
                  for (final goal in _goals) ...[
                    _GoalCard(
                      goal: goal,
                      selected: _goal == goal.id,
                      proteinGoal: weight == null
                          ? null
                          : calculateProteinGoal(
                              bodyweightKg: weight,
                              goal: goal.id,
                            ),
                      onTap: () => setState(() => _goal = goal.id),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: FitTrackSpacing.md),
                  Text(
                    context.t('common:onbNote'),
                    textAlign: TextAlign.center,
                    style: FitTrackText.overline.copyWith(
                      color: colors.muted,
                      height: 1.5,
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

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.selected,
    required this.proteinGoal,
    required this.onTap,
  });

  final _Goal goal;
  final bool selected;
  final int? proteinGoal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final radius = BorderRadius.circular(FitTrackRadius.md);
    final label = context.t(goal.label);
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: '$label, ${context.t(goal.meta)}'
          '${proteinGoal == null ? '' : ', ${context.t('common:onbPerDay', args: {
                'g': proteinGoal
              })}'}',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            constraints: const BoxConstraints(minHeight: 76),
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
                          context.t(goal.meta),
                          style: FitTrackText.caption.copyWith(
                            color: colors.muted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.t(goal.description),
                          style: FitTrackText.caption.copyWith(
                            color: colors.muted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: FitTrackSpacing.sm),
                Text(
                  proteinGoal == null
                      ? '—'
                      : context.t('common:onbPerDay', args: {'g': proteinGoal}),
                  style: FitTrackText.title.copyWith(
                    color: colors.ink,
                    fontWeight: FontWeight.w600,
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

class _Goal {
  const _Goal(this.id, this.label, this.meta, this.description);
  final String id;

  /// Translation keys.
  final String label;
  final String meta;
  final String description;
}
