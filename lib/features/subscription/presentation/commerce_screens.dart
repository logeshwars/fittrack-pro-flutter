import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _CommerceScreen(
      icon: Icons.lock_outline,
      title: 'FitTrack Pro',
      subtitle:
          'This feature is part of FitTrack Pro. Subscription checkout will be connected after the store integration gate.',
      action: 'NOT NOW',
    );
  }
}

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _CommerceScreen(
      icon: Icons.workspace_premium_outlined,
      title: 'Manage Subscription',
      subtitle:
          'Review or manage your FitTrack Pro membership. Store billing is not enabled in this migration build yet.',
      action: 'CLOSE',
    );
  }
}

class _CommerceScreen extends StatelessWidget {
  const _CommerceScreen({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String action;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: colors.accent),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: colors.muted,
                ),
              ),
              const SizedBox(height: 26),
              TextButton(
                onPressed: () => context.pop(),
                child: Text(
                  action,
                  style: TextStyle(
                    color: colors.accent,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
