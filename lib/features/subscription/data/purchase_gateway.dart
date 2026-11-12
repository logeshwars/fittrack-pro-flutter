import '../domain/subscription_state.dart';

/// The user closed the store sheet; not an error worth showing.
class PurchaseCancelled implements Exception {
  const PurchaseCancelled();
}

/// A purchase or restore failed for a reason the user should see.
class PurchaseFailure implements Exception {
  const PurchaseFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Port to the store billing SDK so UI and rules run without it in tests.
abstract interface class PurchaseGateway {
  /// Identifies the store customer as the signed-in user.
  Future<void> logIn(String userId);

  /// Detaches the store customer when the user signs out.
  Future<void> logOut();

  /// Re-reads the entitlement; called on login and every app foreground.
  Future<SubscriptionState> refresh();

  /// Plans from the current offering, best value first.
  Future<List<PlanOffer>> plans();

  Future<SubscriptionState> purchase(PlanOffer plan);

  Future<SubscriptionState> restore();
}
