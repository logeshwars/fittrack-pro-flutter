import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/config/app_config.dart';
import '../data/purchase_gateway.dart';
import '../data/revenuecat_gateway.dart';
import '../domain/subscription_state.dart';

/// Null when no store key is configured for this platform.
final purchaseGatewayProvider = Provider<PurchaseGateway?>((ref) {
  final key = Platform.isIOS
      ? AppConfig.revenueCatIosKey
      : AppConfig.revenueCatAndroidKey;
  return key.isEmpty ? null : RevenueCatGateway(apiKey: key);
});

/// Signed-in user id used as the store customer id (`auth.uid()`).
final subscriptionUserIdProvider = Provider<String?>((ref) {
  ref.watch(authStateProvider);
  if (!AppConfig.hasSupabase) {
    return null;
  }
  return Supabase.instance.client.auth.currentUser?.id;
});

/// Entitlement state; refreshed on login and on every app foreground.
final subscriptionProvider =
    NotifierProvider<SubscriptionController, SubscriptionState>(
  SubscriptionController.new,
);

/// Whether the user has FitTrack Pro. Never use this to hide logged data.
final isProProvider = Provider<bool>(
  (ref) => ref.watch(subscriptionProvider).isPro,
);

final planOffersProvider =
    FutureProvider.autoDispose<List<PlanOffer>>((ref) async {
  final gateway = ref.watch(purchaseGatewayProvider);
  return gateway == null ? const [] : gateway.plans();
});

class SubscriptionController extends Notifier<SubscriptionState> {
  @override
  SubscriptionState build() {
    final userId = ref.watch(subscriptionUserIdProvider);
    final gateway = ref.watch(purchaseGatewayProvider);
    if (gateway != null) {
      Future<void>.microtask(() => _sync(gateway, userId));
    }
    return SubscriptionState.free;
  }

  Future<void> _sync(PurchaseGateway gateway, String? userId) async {
    try {
      if (userId == null) {
        await gateway.logOut();
        state = SubscriptionState.free;
        return;
      }
      await gateway.logIn(userId);
      state = await gateway.refresh();
    } on Object {
      // Keep the last known entitlement when the store is unreachable.
    }
  }

  /// Re-checks the entitlement; call whenever the app returns to foreground.
  Future<void> refresh() async {
    final gateway = ref.read(purchaseGatewayProvider);
    final userId = ref.read(subscriptionUserIdProvider);
    if (gateway == null || userId == null) {
      return;
    }
    try {
      state = await gateway.refresh();
    } on Object {
      // Keep the last known entitlement when the store is unreachable.
    }
  }

  /// Buys [plan]. Throws [PurchaseCancelled] or [PurchaseFailure].
  Future<void> purchase(PlanOffer plan) async {
    final gateway = ref.read(purchaseGatewayProvider);
    if (gateway == null) {
      throw const PurchaseFailure('Purchases are not available in this build.');
    }
    state = await gateway.purchase(plan);
  }

  /// Restores earlier purchases. Throws [PurchaseFailure].
  Future<void> restore() async {
    final gateway = ref.read(purchaseGatewayProvider);
    if (gateway == null) {
      throw const PurchaseFailure('Purchases are not available in this build.');
    }
    state = await gateway.restore();
  }
}

/// Refreshes the entitlement every time the app comes to the foreground.
class SubscriptionLifecycle extends ConsumerStatefulWidget {
  const SubscriptionLifecycle({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<SubscriptionLifecycle> createState() =>
      _SubscriptionLifecycleState();
}

class _SubscriptionLifecycleState extends ConsumerState<SubscriptionLifecycle>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) {
      ref.read(subscriptionProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watching keeps the controller (and its login sync) alive app-wide.
    ref.watch(subscriptionProvider);
    return widget.child;
  }
}
