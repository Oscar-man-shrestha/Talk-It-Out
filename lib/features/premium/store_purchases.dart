import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:talk_it_out/features/premium/data/billing_repository.dart';
import 'package:talk_it_out/features/premium/razorpay/razorpay_checkout.dart';

/// What happened when someone tried to subscribe.
enum PurchaseOutcome { purchased, cancelled, failed, unavailable }

/// Buying Premium (`docs/PREMIUM_PLAN.md`). A personal subscription inside
/// the iPhone and Android apps must go through Apple and Google billing;
/// the website uses Razorpay ([RazorpayWebPurchases]). The
/// server still decides who is Premium (`GET /billing/entitlements`).
abstract class StorePurchases {
  /// False on the web and in builds without store keys.
  bool get available;

  /// The localised monthly price from the store, if it can be read.
  Future<String?> monthlyPrice();

  Future<PurchaseOutcome> buy();

  /// Re-links earlier store purchases to this account.
  Future<void> restore();
}

/// The web, or a phone build without RevenueCat keys: nothing to buy here.
class UnavailableStorePurchases implements StorePurchases {
  const UnavailableStorePurchases();

  @override
  bool get available => false;

  @override
  Future<String?> monthlyPrice() async => null;

  @override
  Future<PurchaseOutcome> buy() async => PurchaseOutcome.unavailable;

  @override
  Future<void> restore() async {}
}

/// The demo (USE_MOCK): subscribing succeeds at once.
class MockStorePurchases implements StorePurchases {
  MockStorePurchases(this._billing);

  final MockBillingRepository _billing;

  @override
  bool get available => true;

  @override
  Future<String?> monthlyPrice() async => '₹99';

  @override
  Future<PurchaseOutcome> buy() async {
    _billing.grant();
    return PurchaseOutcome.purchased;
  }

  @override
  Future<void> restore() async {}
}

/// App Store and Google Play through RevenueCat. The RevenueCat user is the
/// backend user, so the webhook can find who paid.
class RevenueCatStorePurchases implements StorePurchases {
  RevenueCatStorePurchases({required this.apiKey, required this.userId});

  final String apiKey;
  final String userId;

  /// The offering set up in RevenueCat for Premium.
  static const offeringId = 'premium';

  Future<void>? _ready;

  Future<void> _ensureReady() => _ready ??= () async {
    if (!await Purchases.isConfigured) {
      await Purchases.configure(
        PurchasesConfiguration(apiKey)..appUserID = userId,
      );
    } else {
      await Purchases.logIn(userId);
    }
  }();

  Future<Package?> _monthly() async {
    await _ensureReady();
    final offerings = await Purchases.getOfferings();
    final offering = offerings.getOffering(offeringId) ?? offerings.current;
    return offering?.monthly;
  }

  @override
  bool get available => true;

  @override
  Future<String?> monthlyPrice() async {
    try {
      return (await _monthly())?.storeProduct.priceString;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<PurchaseOutcome> buy() async {
    try {
      final package = await _monthly();
      if (package == null) return PurchaseOutcome.unavailable;
      await Purchases.purchase(PurchaseParams.package(package));
      return PurchaseOutcome.purchased;
    } on PlatformException catch (e) {
      return PurchasesErrorHelper.getErrorCode(e) ==
              PurchasesErrorCode.purchaseCancelledError
          ? PurchaseOutcome.cancelled
          : PurchaseOutcome.failed;
    }
  }

  @override
  Future<void> restore() async {
    await _ensureReady();
    await Purchases.restorePurchases();
  }
}

/// The store key for this device, or '' on the web and other platforms.
String storeKeyFor({
  required String appleKey,
  required String googleKey,
  TargetPlatform? platform,
  bool web = kIsWeb,
}) {
  if (web) return '';
  return switch (platform ?? defaultTargetPlatform) {
    TargetPlatform.iOS || TargetPlatform.macOS => appleKey,
    TargetPlatform.android => googleKey,
    _ => '',
  };
}

/// The website: Razorpay Checkout (API.md 75). The server starts the
/// subscription and checks Razorpay's signature before Premium turns on.
class RazorpayWebPurchases implements StorePurchases {
  RazorpayWebPurchases(this._billing);

  final BillingRepository _billing;

  @override
  bool get available => razorpayCheckoutSupported;

  @override
  Future<String?> monthlyPrice() async => '₹99';

  @override
  Future<PurchaseOutcome> buy() async {
    try {
      if (!await _billing.razorpayEnabled()) return PurchaseOutcome.unavailable;
      final checkout = await _billing.startRazorpay();
      final paid = await openRazorpayCheckout(checkout);
      if (paid == null) return PurchaseOutcome.cancelled;
      final ent = await _billing.verifyRazorpay(paid);
      return ent.premium ? PurchaseOutcome.purchased : PurchaseOutcome.failed;
    } catch (_) {
      return PurchaseOutcome.failed;
    }
  }

  // Web subscriptions live on the server; nothing to restore from a store.
  @override
  Future<void> restore() async {}
}
