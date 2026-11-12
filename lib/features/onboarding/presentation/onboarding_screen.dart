import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/data/service_providers.dart';
import '../../../core/theme/app_colors.dart';

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
    _Goal(
      'bulk',
      'Build Muscle',
      'Gain size and strength with a controlled calorie surplus.',
      Icons.fitness_center,
      AppColors.workout,
    ),
    _Goal(
      'maintain',
      'Maintain',
      'Stay strong, consistent and balanced.',
      Icons.balance,
      AppColors.water,
    ),
    _Goal(
      'cut',
      'Lose Fat',
      'Reduce body fat while preserving muscle.',
      Icons.local_fire_department,
      AppColors.cardio,
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
      setState(() => _error = 'Enter a valid weight in kg.');
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

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final repository = ref.watch(authRepositoryProvider);
    final metadata = repository?.currentUser?.userMetadata ?? const <String, dynamic>{};
    final rawName = (
      metadata['full_name'] ??
      metadata['name'] ??
      repository?.currentUser?.email?.split('@').first ??
      'Athlete'
    ).toString();
    final firstName = rawName.trim().split(' ').first;

    return Scaffold(
      backgroundColor: colors.header,
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 40),
          children: [
            Text(
              'SET UP YOUR PROFILE',
              style: TextStyle(
                color: colors.accent,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Welcome, $firstName',
              style: TextStyle(
                color: colors.text,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: -.5,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Choose your training goal so FitTrack Pro can shape your dashboard around it.',
              style: TextStyle(
                color: colors.muted,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 36),
            Text(
              'MAIN GOAL',
              style: TextStyle(
                color: colors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            for (final goal in _goals) ...[
              _GoalCard(
                goal: goal,
                selected: _goal == goal.id,
                onTap: () => setState(() => _goal = goal.id),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 20),
            Text(
              'BODYWEIGHT',
              style: TextStyle(
                color: colors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: colors.cardAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _weight,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText: '75',
                        hintStyle: TextStyle(color: colors.faint),
                      ),
                    ),
                  ),
                  Text(
                    'kg',
                    style: TextStyle(
                      color: colors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: colors.danger, fontSize: 12),
                ),
              ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _saving ? null : _finish,
              style: FilledButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: colors.accentText,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _saving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.accentText,
                      ),
                    )
                  : const Text(
                      'GET STARTED',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .8,
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            Text(
              'This onboarding selection is stored locally while legacy profile-write compatibility is being verified.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.faint,
                fontSize: 10,
                height: 1.5,
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
    required this.onTap,
  });

  final _Goal goal;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? colors.accentTint : colors.cardAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? colors.accent : colors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: goal.color.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(goal.icon, size: 20, color: goal.color),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal.label,
                    style: TextStyle(
                      color: selected ? colors.accent : colors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    goal.description,
                    style: TextStyle(
                      color: colors.muted,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: colors.accent, size: 20),
          ],
        ),
      ),
    );
  }
}

class _Goal {
  const _Goal(this.id, this.label, this.description, this.icon, this.color);
  final String id;
  final String label;
  final String description;
  final IconData icon;
  final Color color;
}
