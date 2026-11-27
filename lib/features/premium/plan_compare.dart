import 'package:flutter/material.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/core/ui/app_icons.dart';
import 'package:talk_it_out/core/ui/brand.dart';
import 'package:talk_it_out/core/ui/motion.dart';
import 'package:talk_it_out/core/ui/surfaces.dart';

/// Free and Premium side by side (stacked on phones): what each includes.
class PlanCompare extends StatelessWidget {
  const PlanCompare({required this.premium, super.key});

  /// The viewer already has Premium: that card says "Your plan".
  final bool premium;

  @override
  Widget build(BuildContext context) {
    final free = _PlanCard(
      key: const ValueKey('plan-free'),
      title: AppStrings.premiumFreeTitle,
      price: '₹0',
      caption: AppStrings.planFreeCaption,
      features: AppStrings.planFreeFeatures,
      current: !premium,
    );
    final paid = _PlanCard(
      key: const ValueKey('plan-premium'),
      title: AppStrings.premiumTitle,
      price: AppStrings.premiumPrice,
      caption: AppStrings.planPremiumCaption,
      features: AppStrings.planPremiumFeatures,
      current: premium,
      highlighted: true,
    );
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth >= 560) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: Reveal(index: 4, child: free)),
                const SizedBox(width: 12),
                Expanded(child: Reveal(index: 5, child: paid)),
              ],
            ),
          );
        }
        return Column(
          children: [
            Reveal(index: 4, child: paid),
            const SizedBox(height: 12),
            Reveal(index: 5, child: free),
          ],
        );
      },
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.caption,
    required this.features,
    required this.current,
    this.highlighted = false,
    super.key,
  });

  final String title;
  final String price;
  final String caption;
  final List<String> features;
  final bool current;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final onDark = highlighted;
    final ink = onDark ? Colors.white : Brand.ink;
    final soft = onDark ? Colors.white.withValues(alpha: 0.7) : Brand.inkSoft;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: highlighted
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2B2B30), Brand.ink],
              ),
              boxShadow: Surfaces.raisedShadow,
            )
          : Surfaces.card(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                highlighted
                    ? PhosphorIconsFill.crown
                    : PhosphorIconsRegular.chatsCircle,
                size: 18,
                color: highlighted ? const Color(0xFFF5C451) : ink,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
              ),
              if (current)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: onDark
                        ? Colors.white.withValues(alpha: 0.14)
                        : Brand.muted,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    AppStrings.planYourPlan,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: ink,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: TextStyle(
                  fontSize: 30,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                  color: ink,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  AppStrings.premiumPerMonth,
                  style: TextStyle(fontSize: 12.5, color: soft),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(caption, style: TextStyle(fontSize: 12.5, color: soft)),
          const SizedBox(height: 14),
          for (final f in features)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    PhosphorIconsFill.checkCircle,
                    size: 16,
                    color: highlighted
                        ? const Color(0xFFF5C451)
                        : const Color(0xFF16A34A),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      f,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.35,
                        color: ink,
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

/// How people pay: through Google Play or the App Store, with the methods
/// those stores take in India; Premium then works wherever they sign in.
class HowYouPay extends StatelessWidget {
  const HowYouPay({super.key});

  @override
  Widget build(BuildContext context) {
    const methods = AppStrings.payMethods;
    return Container(
      key: const ValueKey('how-you-pay'),
      padding: const EdgeInsets.all(18),
      decoration: Surfaces.card(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(PhosphorIconsRegular.lockSimple, size: 18, color: Brand.ink),
              SizedBox(width: 8),
              Text(
                AppStrings.payTitle,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Brand.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in methods)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Brand.muted,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    m,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Brand.ink,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          for (final (i, step) in AppStrings.paySteps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Brand.ink,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      step,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: Brand.ink,
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
