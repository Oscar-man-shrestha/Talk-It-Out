import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talk_it_out/app/providers.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/features/auth/session_controller.dart';
import 'package:talk_it_out/features/premium/data/billing_repository.dart';
import 'package:talk_it_out/features/premium/data/premium_models.dart';
import 'package:talk_it_out/features/premium/store_purchases.dart';

/// The signed-in person's Premium state, from the server (`API.md` 71).
/// Follows sign-in and sign-out; signed out is Free.
class EntitlementsNotifier extends AsyncNotifier<Entitlements> {
  @override
  Future<Entitlements> build() async {
    final user = ref.watch(sessionProvider).value;
    if (user == null) return Entitlements.free;
    return ref.watch(billingRepositoryProvider).entitlements();
  }

  /// After a purchase or restore: asks the server to re-check the store.
  Future<Entitlements> syncNow() async {
    final next = await ref.read(billingRepositoryProvider).sync();
    state = AsyncData(next);
    return next;
  }
}

final entitlementsProvider =
    AsyncNotifierProvider<EntitlementsNotifier, Entitlements>(
      EntitlementsNotifier.new,
    );

/// True only when the server says so; false while loading or on error.
final isPremiumProvider = Provider<bool>(
  (ref) => ref.watch(entitlementsProvider).value?.premium ?? false,
);

/// How Premium is bought on this device.
final storePurchasesProvider = Provider<StorePurchases>((ref) {
  final config = ref.watch(appConfigProvider);
  final billing = ref.watch(billingRepositoryProvider);
  if (config.useMock && billing is MockBillingRepository) {
    return MockStorePurchases(billing);
  }
  // The website pays through Razorpay (API.md 75).
  if (kIsWeb) return RazorpayWebPurchases(billing);
  final key = storeKeyFor(
    appleKey: config.revenuecatAppleKey,
    googleKey: config.revenuecatGoogleKey,
  );
  final userId = ref.watch(sessionProvider).value?.id;
  if (key.isEmpty || userId == null) return const UnavailableStorePurchases();
  return RevenueCatStorePurchases(apiKey: key, userId: userId);
});
