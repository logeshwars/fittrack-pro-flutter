/// RevenueCat entitlement identifier that unlocks FitTrack Pro.
const proEntitlementId = 'pro';

/// Billing period of a purchasable plan.
enum PlanPeriod { monthly, yearly, other }

/// Neutral view of a RevenueCat entitlement so the rules stay SDK-free.
class EntitlementSnapshot {
  const EntitlementSnapshot({
    required this.isActive,
    required this.isTrial,
    required this.willRenew,
    this.expiresAt,
    this.productId,
  });

  final bool isActive;
  final bool isTrial;
  final bool willRenew;
  final DateTime? expiresAt;
  final String? productId;
}

/// What the user currently has.
class SubscriptionState {
  const SubscriptionState({
    this.isPro = false,
    this.isTrial = false,
    this.willRenew = false,
    this.expiresAt,
    this.productId,
    this.managementUrl,
  });

  /// Free tier. Logged data always stays accessible on it.
  static const free = SubscriptionState();

  final bool isPro;
  final bool isTrial;
  final bool willRenew;
  final DateTime? expiresAt;
  final String? productId;
  final String? managementUrl;

  factory SubscriptionState.fromSnapshot(
    EntitlementSnapshot? snapshot, {
    String? managementUrl,
  }) {
    if (snapshot == null || !snapshot.isActive) {
      return SubscriptionState(managementUrl: managementUrl);
    }
    return SubscriptionState(
      isPro: true,
      isTrial: snapshot.isTrial,
      willRenew: snapshot.willRenew,
      expiresAt: snapshot.expiresAt,
      productId: snapshot.productId,
      managementUrl: managementUrl,
    );
  }

  /// Whole days left in a free trial (0 when not on a trial or already over).
  int trialDaysLeft(DateTime now) {
    final end = expiresAt;
    if (!isTrial || end == null) {
      return 0;
    }
    final left = end.difference(now);
    if (left.isNegative) {
      return 0;
    }
    return (left.inHours / 24).ceil();
  }
}

/// A purchasable plan. [handle] is the SDK object handed back to the gateway.
class PlanOffer {
  const PlanOffer({
    required this.id,
    required this.title,
    required this.priceString,
    required this.price,
    required this.period,
    required this.handle,
    this.trialDays = 0,
  });

  final String id;
  final String title;
  final String priceString;
  final double price;
  final PlanPeriod period;
  final int trialDays;
  final Object handle;
}

/// Percentage saved by paying yearly instead of twelve monthly payments.
int yearlySavingsPercent({required double monthly, required double yearly}) {
  if (monthly <= 0 || yearly <= 0) {
    return 0;
  }
  final saved = (1 - yearly / (monthly * 12)) * 100;
  return saved <= 0 ? 0 : saved.round();
}

/// Orders plans yearly first (best value), then monthly, then the rest.
List<PlanOffer> sortPlans(Iterable<PlanOffer> plans) {
  int rank(PlanPeriod p) => switch (p) {
        PlanPeriod.yearly => 0,
        PlanPeriod.monthly => 1,
        PlanPeriod.other => 2,
      };
  return [...plans]..sort((a, b) => rank(a.period).compareTo(rank(b.period)));
}

/// Free-trial length in days from a store intro-price period.
int trialDaysFromPeriod({required String unit, required int count}) =>
    switch (unit) {
      'day' => count,
      'week' => count * 7,
      'month' => count * 30,
      'year' => count * 365,
      _ => 0,
    };
