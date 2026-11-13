import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/fittrack_tokens.dart';
import '../../../core/widgets/fittrack_components.dart';
import '../application/subscription_controller.dart';
import '../data/purchase_gateway.dart';
import '../domain/subscription_state.dart';

const _benefits = <String>[
  'common:payBenefitScans',
  'common:payBenefitAnalytics',
  'common:payBenefitLeaderboards',
  'common:payBenefitFree',
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
    Future<void> Function() action,
    String successMessage,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final noActive = context.t('common:payNoActive');
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
        messenger.showSnackBar(SnackBar(content: Text(noActive)));
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
    final offers = plans.valueOrNull ?? const <PlanOffer>[];
    final selected = offers.isEmpty
        ? null
        : offers.firstWhere(
            (o) => o.id == _selectedId,
            orElse: () => offers.first,
          );
    final trialDays = selected?.trialDays ?? 0;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(
                  top: FitTrackSpacing.sm,
                  right: FitTrackSpacing.sm,
                ),
                child: FitTrackIconButton(
                  icon: Icons.close,
                  semanticLabel: context.t('common:close'),
                  onPressed: () => context.pop(),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  FitTrackSpacing.xxl,
                  0,
                  FitTrackSpacing.xxl,
                  FitTrackSpacing.xxl,
                ),
                children: [
                  Text(
                    context.t('common:payEyebrow'),
                    style: FitTrackText.caption.copyWith(
                      color: colors.accent,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: FitTrackSpacing.sm),
                  Text(
                    trialDays > 0
                        ? context.t(
                            'common:payTitleTrial',
                            args: {'days': trialDays},
                          )
                        : context.t('common:payTitle'),
                    style: FitTrackText.screenTitle.copyWith(
                      color: colors.ink,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: FitTrackSpacing.sm),
                  Text(
                    context.t('common:paySubtitle'),
                    style: FitTrackText.body.copyWith(color: colors.muted),
                  ),
                  const SizedBox(height: FitTrackSpacing.lg),
                  for (final key in _benefits)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: FitTrackSpacing.sm,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Icon(
                              Icons.check,
                              size: 18,
                              color: colors.ok,
                            ),
                          ),
                          const SizedBox(width: FitTrackSpacing.md),
                          Expanded(
                            child: Text(
                              context.t(key),
                              style: FitTrackText.body
                                  .copyWith(color: colors.ink),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: FitTrackSpacing.lg),
                  if (isPro)
                    _Notice(text: context.t('common:payAlreadyPro'))
                  else
                    plans.when(
                      loading: () => Padding(
                        padding: const EdgeInsets.all(FitTrackSpacing.xxl),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: colors.accent,
                          ),
                        ),
                      ),
                      error: (_, __) => _Retry(
                        onRetry: () => ref.invalidate(planOffersProvider),
                      ),
                      data: (offers) => offers.isEmpty
                          ? _Notice(text: context.t('common:payUnavailable'))
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
                                context.t('common:payWelcome'),
                              ),
                            ),
                    ),
                  const SizedBox(height: FitTrackSpacing.xs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FitTrackButton(
                        label: context.t('common:payRestore'),
                        variant: FitTrackButtonVariant.ghost,
                        size: FitTrackButtonSize.sm,
                        onPressed: _busy
                            ? null
                            : () => _run(
                                  () => ref
                                      .read(subscriptionProvider.notifier)
                                      .restore(),
                                  context.t('common:payRestored'),
                                ),
                      ),
                      const SizedBox(width: FitTrackSpacing.lg),
                      FitTrackButton(
                        label: context.t('common:payNotNow'),
                        variant: FitTrackButtonVariant.ghost,
                        size: FitTrackButtonSize.sm,
                        onPressed: () => context.pop(),
                      ),
                    ],
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
    final selected = offers.firstWhere(
      (o) => o.id == selectedId,
      orElse: () => offers.first,
    );
    final monthly =
        offers.where((o) => o.period == PlanPeriod.monthly).firstOrNull;
    final radius = BorderRadius.circular(FitTrackRadius.md);

    String? caption(PlanOffer offer) {
      switch (offer.period) {
        case PlanPeriod.yearly:
          final pct = monthly == null
              ? 0
              : yearlySavingsPercent(
                  monthly: monthly.price,
                  yearly: offer.price,
                );
          return pct > 0
              ? context.t('common:paySaveBilled', args: {'pct': pct})
              : context.t('common:payBilledYearly');
        case PlanPeriod.monthly:
          return context.t('common:payCancelAny');
        case PlanPeriod.other:
          return null;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final offer in offers)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Semantics(
              button: true,
              selected: offer.id == selected.id,
              inMutuallyExclusiveGroup: true,
              label: '${offer.title}, ${offer.priceString}',
              child: ExcludeSemantics(
                child: InkWell(
                  onTap: busy ? null : () => onSelect(offer.id),
                  borderRadius: radius,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 72),
                    padding: EdgeInsets.symmetric(
                      horizontal: offer.id == selected.id ? 13 : 14,
                    ),
                    decoration: BoxDecoration(
                      color: offer.id == selected.id
                          ? colors.accentTint
                          : colors.surface,
                      borderRadius: radius,
                      border: Border.all(
                        color: offer.id == selected.id
                            ? colors.accent
                            : colors.lineStrong,
                        width: offer.id == selected.id ? 2 : 1,
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
                              color: offer.id == selected.id
                                  ? colors.accent
                                  : colors.faint,
                              width: offer.id == selected.id ? 6 : 2,
                            ),
                          ),
                        ),
                        const SizedBox(width: FitTrackSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                offer.title,
                                style: FitTrackText.title.copyWith(
                                  color: colors.ink,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (caption(offer) != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    caption(offer)!,
                                    style: FitTrackText.caption.copyWith(
                                      color: colors.muted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          offer.priceString,
                          style: FitTrackText.titleLg.copyWith(
                            color: colors.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: FitTrackSpacing.sm),
        FitTrackButton(
          label: selected.trialDays > 0
              ? context.t(
                  'common:payStartTrial',
                  args: {'days': selected.trialDays},
                )
              : context.t('common:paySubscribe'),
          size: FitTrackButtonSize.lg,
          fullWidth: true,
          loading: busy,
          onPressed: busy ? null : () => onBuy(selected),
        ),
        if (selected.trialDays > 0)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              context.t(
                selected.period == PlanPeriod.yearly
                    ? 'common:payThenYear'
                    : 'common:payThenMonth',
                args: {'price': selected.priceString},
              ),
              textAlign: TextAlign.center,
              style: FitTrackText.caption.copyWith(
                color: colors.muted,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
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
    final restored = context.t('common:payRestored');
    final noActive = context.t('common:payNoActive');
    setState(() => _busy = true);
    try {
      await ref.read(subscriptionProvider.notifier).restore();
      messenger.showSnackBar(
        SnackBar(
          content: Text(ref.read(isProProvider) ? restored : noActive),
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
    final failed = context.t('common:subStoreFail');
    final ok =
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok) {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final sub = ref.watch(subscriptionProvider);
    final offers = ref.watch(planOffersProvider).valueOrNull ?? const [];
    final date = DateFormat.yMMMd();
    final now = DateTime.now();

    final product = (sub.productId ?? '').toLowerCase();
    final period = product.contains('year') || product.contains('annual')
        ? PlanPeriod.yearly
        : product.contains('month')
            ? PlanPeriod.monthly
            : PlanPeriod.other;
    final offer = offers.where((o) => o.period == period).firstOrNull;

    final planName = !sub.isPro
        ? context.t('common:subPlanFree')
        : switch (period) {
            PlanPeriod.yearly => context.t('common:subPlanYearly'),
            PlanPeriod.monthly => context.t('common:subPlanMonthly'),
            PlanPeriod.other => context.t('common:subPlanPro'),
          };
    final priceLine = offer == null || period == PlanPeriod.other
        ? null
        : context.t(
            period == PlanPeriod.yearly
                ? 'common:subPriceYear'
                : 'common:subPriceMonth',
            args: {'price': offer.priceString},
          );
    final detail = !sub.isPro
        ? context.t('common:subFreeDetail')
        : sub.expiresAt == null
            ? context.t('common:subActive')
            : sub.willRenew
                ? context.t(
                    'common:subRenews',
                    args: {'date': date.format(sub.expiresAt!.toLocal())},
                  )
                : context.t(
                    'common:subEnds',
                    args: {'date': date.format(sub.expiresAt!.toLocal())},
                  );
    final subtitle = [
      if (priceLine != null) priceLine,
      if (sub.isTrial) context.t('common:subTrialActive') else detail,
    ].join(' · ');
    final trialLeft = sub.trialDaysLeft(now);
    final trialTotal = [
      offer?.trialDays ?? 0,
      14,
    ].firstWhere((d) => d > 0);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: FitTrackSpacing.xxl),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FitTrackSpacing.xl,
                FitTrackSpacing.sm,
                FitTrackSpacing.sm,
                FitTrackSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.t('common:subTitle'),
                      style: FitTrackText.screenTitle.copyWith(
                        color: colors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  FitTrackIconButton(
                    icon: Icons.close,
                    semanticLabel: context.t('common:close'),
                    onPressed: () => context.pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FitTrackSpacing.lg,
                FitTrackSpacing.sm,
                FitTrackSpacing.lg,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FitTrackCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              context.t('common:subCurrentPlan').toUpperCase(),
                              style: FitTrackText.caption.copyWith(
                                color: colors.muted,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                            FitTrackBadge(
                              label: context.t(
                                sub.isPro
                                    ? 'common:subBadgePro'
                                    : 'common:subBadgeFree',
                              ),
                              tone: sub.isPro
                                  ? FitTrackBadgeTone.ok
                                  : FitTrackBadgeTone.neutral,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          planName,
                          style: FitTrackText.stat.copyWith(
                            color: colors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: FitTrackText.caption.copyWith(
                            color: colors.muted,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                        if (sub.isTrial) ...[
                          const SizedBox(height: 14),
                          FitTrackProgressBar(
                            progress: (trialLeft / trialTotal).clamp(0.0, 1.0),
                            color: colors.accent,
                            semanticLabel: context.t(
                              'common:subTrialLeft',
                              args: {'left': trialLeft, 'total': trialTotal},
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            context.t(
                              'common:subTrialLeft',
                              args: {'left': trialLeft, 'total': trialTotal},
                            ),
                            style: FitTrackText.caption.copyWith(
                              color: colors.muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: FitTrackSpacing.md),
                  FitTrackCard(
                    padding: EdgeInsets.zero,
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(FitTrackRadius.lg - 1),
                      child: Column(
                        children: [
                          if (!sub.isPro)
                            _ActionRow(
                              first: true,
                              title: context.t('common:subSeePlans'),
                              caption: context.t('common:subSeePlansDesc'),
                              onTap: () => context.push('/paywall'),
                            ),
                          _ActionRow(
                            first: sub.isPro,
                            title: context.t('common:payRestore'),
                            caption: context.t('common:subRestoreDesc'),
                            onTap: _busy ? null : _restore,
                          ),
                          if (sub.isPro && sub.managementUrl != null)
                            _ActionRow(
                              first: false,
                              title: context.t('common:subManage'),
                              caption: context.t('common:subManageDesc'),
                              onTap: () => _manage(sub.managementUrl!),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: FitTrackSpacing.lg,
                      vertical: FitTrackSpacing.md,
                    ),
                    child: Text(
                      context.t('common:paySubtitle'),
                      textAlign: TextAlign.center,
                      style: FitTrackText.caption.copyWith(
                        color: colors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  FitTrackButton(
                    label: context.t('common:close'),
                    variant: FitTrackButtonVariant.secondary,
                    size: FitTrackButtonSize.lg,
                    fullWidth: true,
                    onPressed: () => context.pop(),
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

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.first,
    required this.title,
    required this.caption,
    required this.onTap,
  });

  final bool first;
  final String title;
  final String caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: '$title, $caption',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(
              horizontal: FitTrackSpacing.lg,
              vertical: FitTrackSpacing.sm,
            ),
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
                        title,
                        style: FitTrackText.title.copyWith(
                          color: onTap == null ? colors.muted : colors.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        caption,
                        style: FitTrackText.caption.copyWith(
                          color: colors.muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 20, color: colors.muted),
              ],
            ),
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
    return FitTrackCard(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: FitTrackText.body.copyWith(color: colors.muted),
      ),
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
        Text(
          context.t('common:payLoadFailed'),
          style: FitTrackText.body.copyWith(color: colors.muted),
        ),
        const SizedBox(height: FitTrackSpacing.sm),
        FitTrackButton(
          label: context.t('common:retry'),
          icon: Icons.refresh,
          variant: FitTrackButtonVariant.secondary,
          onPressed: onRetry,
        ),
      ],
    );
  }
}
