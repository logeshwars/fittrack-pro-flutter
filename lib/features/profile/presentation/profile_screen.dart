import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/fittrack_ui.dart';
import '../../dashboard/providers/dashboard_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppPalette.of(context);
    final dashboard = ref.watch(dashboardProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: dashboard.when(
          loading: () =>
              Center(child: CircularProgressIndicator(color: colors.accent)),
          error: (_, __) =>
              _ProfileError(onRetry: () => ref.invalidate(dashboardProvider)),
          data: (data) => ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              FitTrackScreenHeader(
                title: 'Profile',
                subtitle: 'Your stats & settings',
                trailing: IconButton(
                  onPressed: () => context.pop(),
                  icon: Icon(Icons.close, color: colors.muted),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                child: Column(
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: colors.card,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.accent, width: 3),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _initials(data.displayName),
                        style: TextStyle(
                          color: colors.text,
                          fontWeight: FontWeight.w900,
                          fontSize: 30,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      data.displayName,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: colors.accent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'LEVEL ${data.level}',
                        style: TextStyle(
                          color: colors.accentText,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.local_fire_department,
                        iconColor: AppColors.cardio,
                        value: '${data.currentStreak}',
                        label: 'DAY STREAK',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.bolt,
                        iconColor: colors.accent,
                        value: _compact(data.totalXp),
                        label: 'TOTAL XP',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.monitor_weight_outlined,
                        iconColor: AppColors.weight,
                        value: data.latestWeightKg == null
                            ? '—'
                            : data.latestWeightKg!.toStringAsFixed(1),
                        label: 'BODY KG',
                      ),
                    ),
                  ],
                ),
              ),
              _XpCard(level: data.level, totalXp: data.totalXp),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: InkWell(
                  onTap: () => context.push('/subscription'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.xp.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.xp.withValues(alpha: .22),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.xp.withValues(alpha: .12),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.workspace_premium_outlined,
                            color: AppColors.xp,
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'FitTrack Pro',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: colors.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Manage subscription',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 13,
                          color: colors.faint,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'SETTINGS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: colors.muted,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      _SettingsRow(
                        icon: Icons.monitor_heart_outlined,
                        label: 'Personal Settings',
                        onTap: () => context.push('/settings/personal'),
                      ),
                      _SettingsRow(
                        icon: Icons.notifications_none,
                        label: 'Supplement Alerts',
                        onTap: () => context.push('/settings/alerts'),
                      ),
                      _SettingsRow(
                        icon: Icons.local_fire_department_outlined,
                        label: 'Daily Goals',
                        onTap: () => context.push('/settings/goals'),
                      ),
                      _SettingsRow(
                        icon: Icons.palette_outlined,
                        label: 'Appearance',
                        onTap: () => context.push('/settings/theme'),
                      ),
                      _SettingsRow(
                        icon: Icons.settings_outlined,
                        label: 'App Settings',
                        onTap: () => context.push('/settings/app-settings'),
                      ),
                      _SettingsRow(
                        icon: Icons.emoji_events_outlined,
                        label: 'Achievements',
                        onTap: () => context.push('/achievements'),
                        last: true,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: OutlinedButton(
                  onPressed: () async {
                    final auth = ref.read(authRepositoryProvider);
                    if (auth != null) {
                      await auth.signOut();
                      if (context.mounted) context.go('/account');
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.muted,
                    side: BorderSide(color: colors.border2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'SIGN OUT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final result = parts.take(2).map((p) => p[0].toUpperCase()).join();
    return result.isEmpty ? 'U' : result;
  }

  static String _compact(int value) {
    if (value >= 1000) return '${(value / 1000).round()}K';
    return '$value';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: iconColor),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 8,
              color: colors.muted,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _XpCard extends StatelessWidget {
  const _XpCard({required this.level, required this.totalXp});
  final int level;
  final int totalXp;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final base = (level - 1) * 500;
    final cap = level * 500;
    final progress = ((totalXp - base) / 500).clamp(0, 1).toDouble();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.bolt, size: 16, color: colors.accent),
              const SizedBox(width: 8),
              Text(
                'Level $level Progress',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: colors.text,
                ),
              ),
              const Spacer(),
              Text(
                '$totalXp / $cap XP',
                style: TextStyle(fontSize: 11, color: colors.muted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: colors.border2,
              valueColor: AlwaysStoppedAnimation(colors.accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    this.onTap,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border:
              last ? null : Border(bottom: BorderSide(color: colors.border2)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colors.border2,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 15, color: colors.muted),
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
            Icon(Icons.arrow_forward_ios, size: 13, color: colors.faint),
          ],
        ),
      ),
    );
  }
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton(
        onPressed: onRetry,
        child: const Text('Retry profile'),
      ),
    );
  }
}
