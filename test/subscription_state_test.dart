import 'package:fittrack_pro/features/subscription/domain/subscription_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('null or inactive entitlement is the free tier', () {
    expect(SubscriptionState.fromSnapshot(null).isPro, isFalse);
    final inactive = SubscriptionState.fromSnapshot(
      const EntitlementSnapshot(isActive: false, isTrial: false, willRenew: false),
    );
    expect(inactive.isPro, isFalse);
  });

  test('active trial reports whole days left, rounding up', () {
    final now = DateTime(2026, 11, 12, 12);
    final state = SubscriptionState.fromSnapshot(EntitlementSnapshot(
      isActive: true,
      isTrial: true,
      willRenew: true,
      expiresAt: now.add(const Duration(days: 13, hours: 2)),
    ));
    expect(state.isPro, isTrue);
    expect(state.trialDaysLeft(now), 14);
    expect(state.trialDaysLeft(now.add(const Duration(days: 30))), 0);
  });

  test('paid subscriptions have no trial days', () {
    final state = SubscriptionState.fromSnapshot(EntitlementSnapshot(
      isActive: true,
      isTrial: false,
      willRenew: true,
      expiresAt: DateTime(2027),
    ));
    expect(state.trialDaysLeft(DateTime(2026)), 0);
  });

  test('yearlySavingsPercent', () {
    expect(yearlySavingsPercent(monthly: 10, yearly: 60), 50);
    expect(yearlySavingsPercent(monthly: 10, yearly: 120), 0);
    expect(yearlySavingsPercent(monthly: 0, yearly: 60), 0);
  });

  test('sortPlans puts yearly first', () {
    PlanOffer p(String id, PlanPeriod period) => PlanOffer(
          id: id,
          title: id,
          priceString: '',
          price: 1,
          period: period,
          handle: id,
        );
    final sorted = sortPlans([
      p('o', PlanPeriod.other),
      p('m', PlanPeriod.monthly),
      p('y', PlanPeriod.yearly),
    ]);
    expect([for (final x in sorted) x.id], ['y', 'm', 'o']);
  });

  test('trialDaysFromPeriod', () {
    expect(trialDaysFromPeriod(unit: 'day', count: 14), 14);
    expect(trialDaysFromPeriod(unit: 'week', count: 2), 14);
    expect(trialDaysFromPeriod(unit: 'unknown', count: 3), 0);
  });
}
