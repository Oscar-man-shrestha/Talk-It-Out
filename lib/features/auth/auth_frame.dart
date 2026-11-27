import 'package:flutter/material.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/core/ui/ambient_background.dart';
import 'package:talk_it_out/core/ui/brand.dart';
import 'package:talk_it_out/core/ui/motion.dart';
import 'package:talk_it_out/core/ui/app_icons.dart';

/// The premium frame around sign-in and sign-up (Run 117).
///
/// Wide screens: a dark brand panel with the animated scene on the left
/// and the form on the right. Phones and tablets: the scene behind, the
/// form in a floating white card. [form] is the screen's own scrollable
/// content; this frame only places and animates it.
class AuthFrame extends StatelessWidget {
  const AuthFrame({required this.form, super.key});

  final Widget form;

  static const _wideBreakpoint = 1000.0;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= _wideBreakpoint) {
      return Row(
        children: [
          const Expanded(flex: 5, child: _BrandPanel()),
          Expanded(
            flex: 4,
            child: ColoredBox(
              color: Brand.canvas,
              child: Reveal(child: form),
            ),
          ),
        ],
      );
    }
    return AmbientBackground(child: Reveal(offset: 22, child: form));
  }
}

/// White card with a soft, layered shadow that floats over the scene.
class AuthCard extends StatelessWidget {
  const AuthCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= AuthFrame._wideBreakpoint;
    if (wide) return child;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Brand.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 40,
            offset: Offset(0, 18),
          ),
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        // Phones: slim sides so the form keeps nearly its full width.
        padding: MediaQuery.sizeOf(context).width < 600
            ? const EdgeInsets.fromLTRB(14, 20, 14, 16)
            : const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: child,
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The light scene, inverted into a deep ink panel.
          const ColorFiltered(
            colorFilter: ColorFilter.matrix([
              -0.92, 0, 0, 0, 236, //
              0, -0.92, 0, 0, 236, //
              0, 0, -0.92, 0, 236, //
              0, 0, 0, 1, 0,
            ]),
            child: AmbientBackground(child: SizedBox.expand()),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xCC09090B), Color(0x6609090B)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(56, 48, 56, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Reveal(child: _Logo()),
                const Spacer(),
                Reveal(
                  index: 1,
                  child: Text(
                    AppStrings.heroEyebrow,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.2,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Reveal(
                  index: 2,
                  child: Text(
                    AppStrings.heroTitle,
                    style: TextStyle(
                      fontSize: 52,
                      height: 1.05,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.6,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Reveal(
                  index: 3,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Text(
                      AppStrings.heroBody,
                      style: TextStyle(
                        fontSize: 17,
                        height: 1.5,
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                const Reveal(
                  index: 4,
                  child: _Point(
                    icon: Icons.visibility_off_outlined,
                    text: AppStrings.heroPointAnonymous,
                  ),
                ),
                const Reveal(
                  index: 5,
                  child: _Point(
                    icon: PhosphorIconsRegular.magicWand,
                    text: AppStrings.heroPointRewrite,
                  ),
                ),
                const Reveal(
                  index: 6,
                  child: _Point(
                    icon: PhosphorIconsRegular.shieldCheck,
                    text: AppStrings.heroPointReview,
                  ),
                ),
                const Spacer(),
                Reveal(
                  index: 7,
                  child: Row(
                    children: [
                      Icon(
                        PhosphorIconsRegular.lockSimple,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          AppStrings.heroFootnote,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                    ],
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

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            PhosphorIconsFill.chatsCircle,
            size: 19,
            color: Brand.ink,
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          AppStrings.appName,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: Icon(icon, size: 17, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
