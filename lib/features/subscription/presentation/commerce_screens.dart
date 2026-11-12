import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../application/subscription_controller.dart';
import '../data/purchase_gateway.dart';
import '../domain/subscription_state.dart';

const _benefits = <(IconData, String)>[
  (Icons.photo_camera_outlined, 'Unlimited AI food photo scans'),
  (Icons.insights_outlined, 'Full analytics and consistency tracking'),
  (Icons.emoji_events_outlined, 'Leaderboards and achievements'),
  (Icons.lock_open_outlined, 'Everything you already logged stays free'),
];

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  String? _selectedId;
  bool _busy = false;

  Future<void> _run(
      Future<void> Function() action, String successMessage) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) {
        return;
      }
      if (ref.read(isProProvider)) {
        messenger.showSnackBar(SnackBar(content: Text(successMessage)));
        router.pop();
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('No active subscription was found.')),
        );
      }
    } on PurchaseCancelled {
      // The user closed the store sheet.
    } on PurchaseFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final plans = ref.watch(planOffersProvider);
    final isPro = ref.watch(isProProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: () => context.pop(),
                icon: Icon(Icons.close, color: colors.muted),
                tooltip: 'Close',
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                children: [
                  Icon(Icons.workspace_premium_outlined,
                      size: 52, color: AppColors.xp),
                  const SizedBox(height: 14),
                  Text(
                    'FitTrack Pro',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: colors.text),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Train smarter with everything unlocked.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: colors.muted),
                  ),
                  const SizedBox(height: 22),
                  for (final (icon, text) in _benefits)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(icon, size: 20, color: colors.accent),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(text,
                                style: TextStyle(
                                    fontSize: 14, color: colors.text)),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (isPro)
                    _Notice(text: "You're already on FitTrack Pro.")
                  else
                    plans.when(
                      loading: () => Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                            child: CircularProgressIndicator(
                                color: colors.accent)),
                      ),
                      error: (_, __) => _Retry(
                          onRetry: () => ref.invalidate(planOffersProvider)),
                      data: (offers) => offers.isEmpty
                          ? const _Notice(
                              text:
                                  'Subscriptions are not available in this build yet.',
                            )
                          : _Plans(
                              offers: offers,
                              selectedId: _selectedId ?? offers.first.id,
                              onSelect: (id) =>
                                  setState(() => _selectedId = id),
                              busy: _busy,
                              onBuy: (plan) => _run(
                                () => ref
                                    .read(subscriptionProvider.notifier)
                                    .purchase(plan),
                                'Welcome to FitTrack Pro!',
                              ),
                            ),
                    ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: _busy
                          ? null
                          : () => _run(
                                () => ref
                                    .read(subscriptionProvider.notifier)
                                    .restore(),
                                'Purchases restored.',
                              ),
                      child: Text('Restore purchases',
                          style: TextStyle(color: colors.muted)),
                    ),
                  ),
                  Center(
                    child: TextButton(
                      onPressed: () => context.pop(),
                      child: Text(
                        'NOT NOW',
                        style: TextStyle(
                          color: colors.accent,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
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

class _Plans extends StatelessWidget {
  const _Plans({
    required this.offers,
    required this.selectedId,
    required this.onSelect,
    required this.busy,
    required this.onBuy,
  });

  final List<PlanOffer> offers;
  final String selectedId;
  final ValueChanged<String> onSelect;
  final bool busy;
  final ValueChanged<PlanOffer> onBuy;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final selected = offers.firstWhere((o) => o.id == selectedId,
        orElse: () => offers.first);
    final monthly =
        offers.where((o) => o.period == PlanPeriod.monthly).firstOrNull;
    return Column(
      children: [
        for (final offer in offers)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: busy ? null : () => onSelect(offer.id),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: offer.id == selected.id
                        ? colors.accent
                        : colors.border2,
                    width: offer.id == selected.id ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      offer.id == selected.id
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: offer.id == selected.id
                          ? colors.accent
                          : colors.faint,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            offer.title,
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: colors.text),
                          ),
                          if (offer.period == PlanPeriod.yearly &&
                              monthly != null)
                            Builder(builder: (_) {
                              final pct = yearlySavingsPercent(
                                monthly: monthly.price,
                                yearly: offer.price,
                              );
                              return pct > 0
                                  ? Text(
                                      'Save $pct%',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.recovery,
                                      ),
                                    )
                                  : const SizedBox.shrink();
                            }),
                        ],
                      ),
                    ),
                    Text(
                      offer.priceString,
                      style: TextStyle(
                          fontWeight: FontWeight.w900, color: colors.text),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: busy ? null : () => onBuy(selected),
            style: FilledButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: colors.accentText,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    selected.trialDays > 0
                        ? 'START ${selected.trialDays}-DAY FREE TRIAL'
                        : 'SUBSCRIBE',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, letterSpacing: 1),
                  ),
          ),
        ),
        if (selected.trialDays > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Then ${selected.priceString} per ${selected.period == PlanPeriod.yearly ? 'year' : 'month'}. Cancel anytime in your store settings.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: colors.muted),
            ),
          ),
      ],
    );
  }
}

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _busy = false;

  Future<void> _restore() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(subscriptionProvider.notifier).restore();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ref.read(isProProvider)
                ? 'Purchases restored.'
                : 'No active subscription was found.',
          ),
        ),
      );
    } on PurchaseFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } on PurchaseCancelled {
      // Nothing to report.
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _manage(String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok =
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the store.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final sub = ref.watch(subscriptionProvider);
    final date = DateFormat.yMMMd();
    final now = DateTime.now();

    final status = !sub.isPro
        ? 'Free plan'
        : sub.isTrial
            ? 'Free trial · ${sub.trialDaysLeft(now)} days left'
            : 'FitTrack Pro';
    final detail = !sub.isPro
        ? 'Upgrade to unlock every Pro feature. Everything you have logged stays available.'
        : sub.expiresAt == null
            ? 'Your membership is active.'
            : sub.willRenew
                ? 'Renews on ${date.format(sub.expiresAt!.toLocal())}.'
                : 'Ends on ${date.format(sub.expiresAt!.toLocal())}. It will not renew.';

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.workspace_premium_outlined,
                  size: 48, color: sub.isPro ? AppColors.xp : colors.accent),
              const SizedBox(height: 18),
              Text(
                status,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: colors.text),
              ),
              const SizedBox(height: 8),
              Text(
                detail,
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 14, height: 1.5, color: colors.muted),
              ),
              const SizedBox(height: 26),
              if (!sub.isPro)
                FilledButton(
                  onPressed: () => context.push('/paywall'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: colors.accentText,
                  ),
                  child: const Text('SEE PLANS',
                      style: TextStyle(
                          fontWeight: FontWeight.w900, letterSpacing: 1)),
                ),
              if (sub.isPro && sub.managementUrl != null)
                OutlinedButton(
                  onPressed: () => _manage(sub.managementUrl!),
                  child: const Text('MANAGE IN STORE'),
                ),
              TextButton(
                onPressed: _busy ? null : _restore,
                child: Text('Restore purchases',
                    style: TextStyle(color: colors.muted)),
              ),
              TextButton(
                onPressed: () => context.pop(),
                child: Text(
                  'CLOSE',
                  style: TextStyle(
                      color: colors.accent,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: colors.card, borderRadius: BorderRadius.circular(12)),
      child: Text(text,
          textAlign: TextAlign.center, style: TextStyle(color: colors.muted)),
    );
  }
}

class _Retry extends StatelessWidget {
  const _Retry({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Column(
      children: [
        Text('Could not load plans.', style: TextStyle(color: colors.muted)),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}
