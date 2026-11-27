import 'package:flutter/material.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/core/ui/page_padding.dart';
import 'package:talk_it_out/core/ui/app_icons.dart';

class StitchPageHeader extends StatelessWidget implements PreferredSizeWidget {
  const StitchPageHeader({
    required this.title,
    this.leading,
    this.actions = const [],
    this.emphasizePageTitle = false,
    super.key,
  });

  final String title;
  final Widget? leading;
  final List<Widget> actions;
  final bool emphasizePageTitle;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final hPad = pageHPad(screenWidth);
    // On phones a back button replaces the logo tile, leaving the title
    // room next to the actions (as messaging apps do).
    final showLogo = leading == null || screenWidth >= 600;

    // The compact black bar shared by inner screens (Run 125).
    return Material(
      color: const Color(0xFF0A0A0A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        bottom: false,
        // The bar has a fixed height; very large text would not fit in it.
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: SizedBox(
            height: 56,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: IconButtonTheme(
                data: IconButtonThemeData(
                  style: IconButton.styleFrom(foregroundColor: Colors.white),
                ),
                child: Row(
                  children: [
                    ?leading,
                    if (leading != null) const SizedBox(width: 4),
                    if (showLogo) ...[
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          PhosphorIconsFill.usersThree,
                          size: 18,
                          color: Color(0xFF0A0A0A),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  AppStrings.appName.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                    color: emphasizePageTitle
                                        ? Colors.white60
                                        : Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: emphasizePageTitle ? 16 : 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: emphasizePageTitle ? -0.2 : 0,
                              color: emphasizePageTitle
                                  ? Colors.white
                                  : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...actions,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StitchInitials extends StatelessWidget {
  const StitchInitials({required this.name, this.size = 44, super.key});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final letters = name.trim().isEmpty
        ? '?'
        : name
              .trim()
              .split(RegExp(r'\s+'))
              .take(2)
              .map((part) => part[0].toUpperCase())
              .join();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Text(
        letters,
        style: TextStyle(
          color: scheme.onPrimary,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.35,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}
