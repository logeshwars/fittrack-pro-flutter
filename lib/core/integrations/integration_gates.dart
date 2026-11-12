/// Release gates for external services that must not be simulated locally.
enum IntegrationFeature {
  revenueCatSubscriptions,
  androidHealthConnect,
  iosHealthKit
}

class IntegrationGates {
  const IntegrationGates._();

  /// All external integrations are disabled until the corresponding
  /// credentials, native capabilities and identity mappings are audited.
  static bool enabled(IntegrationFeature feature) => false;
}
