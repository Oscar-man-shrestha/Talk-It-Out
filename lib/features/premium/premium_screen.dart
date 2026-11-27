import 'package:talk_it_out/app/repository_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/core/ui/app_icons.dart';
import 'package:talk_it_out/core/ui/brand.dart';
import 'package:talk_it_out/core/ui/floating_emblem.dart';
import 'package:talk_it_out/core/ui/motion.dart';
import 'package:talk_it_out/core/ui/page_padding.dart';
import 'package:talk_it_out/core/ui/surfaces.dart';
import 'package:talk_it_out/features/premium/data/premium_models.dart';
import 'package:talk_it_out/features/premium/premium_providers.dart';
import 'package:talk_it_out/features/premium/plan_compare.dart';
import 'package:talk_it_out/features/premium/store_purchases.dart';

/// Premium (`docs/PREMIUM_PLAN.md`): Free stays complete; Premium adds new
/// tools for ₹99 a month, sold through the app stores on phones.
class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  var _busy = false;
  String? _storePrice;

  @override
  void initState() {
    super.initState();
    _loadPrice();
  }

  Future<void> _loadPrice() async {
    final store = ref.read(storePurchasesProvider);
    if (!store.available) return;
    final price = await store.monthlyPrice();
    if (mounted && price != null) setState(() => _storePrice = price);
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _buy() async {
    tapFeedback();
    setState(() => _busy = true);
    try {
      final outcome = await ref.read(storePurchasesProvider).buy();
      switch (outcome) {
        case PurchaseOutcome.purchased:
          await _refresh();
          _snack(AppStrings.premiumThanks);
        case PurchaseOutcome.cancelled:
          _snack(AppStrings.premiumCancelled);
        case PurchaseOutcome.failed:
          _snack(AppStrings.premiumFailed);
        case PurchaseOutcome.unavailable:
          _snack(AppStrings.premiumStoreUnavailable);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    try {
      await ref.read(storePurchasesProvider).restore();
      await _refresh();
      _snack(AppStrings.premiumRestored);
    } catch (_) {
      _snack(AppStrings.premiumFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Web (Razorpay) subscriptions are cancelled here; store ones in the store.
  Future<void> _cancelWeb() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.premiumCancelWeb),
        content: const Text(AppStrings.premiumCancelWebConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Premium'),
          ),
          FilledButton(
            key: const ValueKey('premium-cancel-web-confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel renewal'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(billingRepositoryProvider).cancelWebSubscription();
      ref.invalidate(entitlementsProvider);
      _snack(AppStrings.premiumCancelledWeb);
    } catch (_) {
      _snack(AppStrings.premiumFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The server decides; a slow webhook is covered by asking it to sync.
  Future<void> _refresh() async {
    try {
      await ref.read(entitlementsProvider.notifier).syncNow();
    } catch (_) {
      ref.invalidate(entitlementsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ent = ref.watch(entitlementsProvider).value ?? Entitlements.free;
    final store = ref.watch(storePurchasesProvider);
    final hPad = pageHPad(MediaQuery.sizeOf(context).width, maxContent: 760);
    return Scaffold(
      backgroundColor: Brand.canvas,
      appBar: AppBar(
        // Stays light: the page opens with its own crown header.
        backgroundColor: Brand.canvas,
        foregroundColor: Brand.ink,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        shape: const RoundedRectangleBorder(),
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(PhosphorIconsRegular.x),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/profile'),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 32),
        children: [
          const Center(
            child: Reveal(
              child: FloatingEmblem(icon: PhosphorIconsFill.crown, size: 84),
            ),
          ),
          const Reveal(
            index: 1,
            child: Text(
              AppStrings.premiumTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.8,
                color: Brand.ink,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Reveal(
            index: 2,
            child: Text(
              AppStrings.premiumTagline,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.45,
                color: Brand.inkSoft,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Reveal(
            index: 3,
            child: ent.premium
                ? _YouArePremium(
                    ent: ent,
                    onCancelWeb:
                        ent.provider == 'razorpay' && ent.willRenew && !_busy
                        ? _cancelWeb
                        : null,
                  )
                : _PriceCard(
                    price: _storePrice ?? AppStrings.premiumPrice,
                    busy: _busy,
                    available: store.available,
                    onBuy: _buy,
                  ),
          ),
          const SizedBox(height: 22),
          PlanCompare(premium: ent.premium),
          const SizedBox(height: 14),
          const HowYouPay(),
          const SizedBox(height: 14),
          const _NeverSold(),
          const SizedBox(height: 20),
          const Text(
            AppStrings.premiumDisclosure,
            key: ValueKey('premium-disclosure'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.45, color: Brand.inkSoft),
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            children: [
              TextButton(
                onPressed: () => context.push('/legal/terms'),
                child: const Text(AppStrings.premiumTerms),
              ),
              TextButton(
                onPressed: () => context.push('/legal/privacy'),
                child: const Text(AppStrings.premiumPrivacy),
              ),
              if (store.available && !kIsWeb)
                TextButton(
                  key: const ValueKey('premium-restore'),
                  onPressed: _busy ? null : _restore,
                  child: const Text(AppStrings.premiumRestore),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({
    required this.price,
    required this.busy,
    required this.available,
    required this.onBuy,
  });

  final String price;
  final bool busy;
  final bool available;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Brand.ink,
        borderRadius: BorderRadius.circular(20),
        boxShadow: Surfaces.raisedShadow,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                key: const ValueKey('premium-price'),
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  AppStrings.premiumPerMonth,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (available)
            PressScale(
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('premium-subscribe'),
                  onPressed: busy ? null : onBuy,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Brand.ink,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          AppStrings.premiumSubscribe,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            )
          else
            Text(
              AppStrings.premiumStoreUnavailable,
              key: const ValueKey('premium-store-unavailable'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          if (available && kIsWeb)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    PhosphorIconsRegular.lockSimple,
                    size: 13,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      AppStrings.premiumWebPayNote,
                      key: const ValueKey('premium-web-pay-note'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _YouArePremium extends StatelessWidget {
  const _YouArePremium({required this.ent, this.onCancelWeb});

  final Entitlements ent;

  /// Set for a renewing web (Razorpay) subscription.
  final VoidCallback? onCancelWeb;

  @override
  Widget build(BuildContext context) {
    final end = ent.expiresAt;
    final line = end == null
        ? AppStrings.premiumNoEnd
        : (ent.willRenew
              ? AppStrings.premiumRenews(shortDate(end))
              : AppStrings.premiumEnds(shortDate(end)));
    return Container(
      key: const ValueKey('premium-active'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Brand.accentSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Brand.accentBorder),
      ),
      child: Row(
        children: [
          const Icon(
            PhosphorIconsFill.sealCheck,
            size: 28,
            color: Brand.accentInk,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  AppStrings.premiumYouHave,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Brand.accentInk,
                  ),
                ),
                Text(
                  line,
                  style: const TextStyle(fontSize: 13, color: Brand.accentInk),
                ),
                if (onCancelWeb != null)
                  TextButton(
                    key: const ValueKey('premium-cancel-web'),
                    onPressed: onCancelWeb,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      foregroundColor: Brand.accentInk,
                    ),
                    child: const Text(AppStrings.premiumCancelWeb),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What is never for sale, said plainly under the plans.
class _NeverSold extends StatelessWidget {
  const _NeverSold();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(PhosphorIconsRegular.shieldCheck, size: 18, color: Brand.inkSoft),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            AppStrings.premiumNeverSold,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: Brand.inkSoft,
            ),
          ),
        ),
      ],
    );
  }
}

/// "26 Dec 2026".
String shortDate(DateTime d) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final local = d.toLocal();
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}
