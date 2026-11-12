import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../domain/subscription_state.dart';
import 'purchase_gateway.dart';

/// RevenueCat implementation of [PurchaseGateway].
class RevenueCatGateway implements PurchaseGateway {
  RevenueCatGateway({required this.apiKey});

  final String apiKey;
  String? _configuredFor;

  Future<void> _ensureConfigured(String userId) async {
    if (_configuredFor == userId) {
      return;
    }
    if (_configuredFor == null) {
      await Purchases.setLogLevel(LogLevel.warn);
      await Purchases.configure(
          PurchasesConfiguration(apiKey)..appUserID = userId);
    } else {
      await Purchases.logIn(userId);
    }
    _configuredFor = userId;
  }

  @override
  Future<void> logIn(String userId) => _ensureConfigured(userId);

  @override
  Future<void> logOut() async {
    if (_configuredFor == null) {
      return;
    }
    _configuredFor = null;
    try {
      await Purchases.logOut();
    } on PlatformException {
      // Already anonymous; nothing to detach.
    }
  }

  SubscriptionState _map(CustomerInfo info) {
    final entitlement = info.entitlements.all[proEntitlementId];
    if (entitlement == null) {
      return SubscriptionState(managementUrl: info.managementURL);
    }
    return SubscriptionState.fromSnapshot(
      EntitlementSnapshot(
        isActive: entitlement.isActive,
        isTrial: entitlement.periodType == PeriodType.trial,
        willRenew: entitlement.willRenew,
        expiresAt: entitlement.expirationDate == null
            ? null
            : DateTime.tryParse(entitlement.expirationDate!),
        productId: entitlement.productIdentifier,
      ),
      managementUrl: info.managementURL,
    );
  }

  @override
  Future<SubscriptionState> refresh() async =>
      _map(await Purchases.getCustomerInfo());

  PlanPeriod _period(PackageType type) => switch (type) {
        PackageType.monthly => PlanPeriod.monthly,
        PackageType.annual => PlanPeriod.yearly,
        _ => PlanPeriod.other,
      };

  @override
  Future<List<PlanOffer>> plans() async {
    final offerings = await Purchases.getOfferings();
    final packages = offerings.current?.availablePackages ?? const <Package>[];
    return sortPlans([
      for (final p in packages)
        PlanOffer(
          id: p.identifier,
          title: switch (_period(p.packageType)) {
            PlanPeriod.yearly => 'Yearly',
            PlanPeriod.monthly => 'Monthly',
            PlanPeriod.other => p.storeProduct.title,
          },
          priceString: p.storeProduct.priceString,
          price: p.storeProduct.price,
          period: _period(p.packageType),
          trialDays: _trialDays(p.storeProduct),
          handle: p,
        ),
    ]);
  }

  int _trialDays(StoreProduct product) {
    final intro = product.introductoryPrice;
    if (intro == null || intro.price > 0) {
      return 0;
    }
    return trialDaysFromPeriod(
      unit: intro.periodUnit.name,
      count: intro.periodNumberOfUnits,
    );
  }

  @override
  Future<SubscriptionState> purchase(PlanOffer plan) async {
    try {
      // purchases_flutter 9 returns a PurchaseResult, not CustomerInfo.
      final result = await Purchases.purchasePackage(plan.handle as Package);
      return _map(result.customerInfo);
    } on PlatformException catch (e) {
      throw _translate(e);
    }
  }

  @override
  Future<SubscriptionState> restore() async {
    try {
      return _map(await Purchases.restorePurchases());
    } on PlatformException catch (e) {
      throw _translate(e);
    }
  }

  Exception _translate(PlatformException e) {
    final code = PurchasesErrorHelper.getErrorCode(e);
    if (code == PurchasesErrorCode.purchaseCancelledError) {
      return const PurchaseCancelled();
    }
    return PurchaseFailure(e.message ?? 'The purchase could not be completed.');
  }
}
