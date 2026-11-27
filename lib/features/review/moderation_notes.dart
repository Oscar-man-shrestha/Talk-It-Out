import 'package:flutter/material.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/core/ui/app_icons.dart';
import 'package:talk_it_out/core/ui/brand.dart';
import 'package:talk_it_out/features/review/data/raw_message.dart';

/// Advisory moderation flags on the original message (API.md 72). They
/// never reject or hide anything: the controller decides.
class ModerationFlagChips extends StatelessWidget {
  const ModerationFlagChips({required this.message, super.key});

  final RawMessage message;

  @override
  Widget build(BuildContext context) {
    final flags = message.moderationFlags;
    if (flags.isEmpty) return const SizedBox.shrink();
    return Tooltip(
      message: AppStrings.moderationFlagsNote,
      child: Wrap(
        key: ValueKey('moderation-flags-${message.id}'),
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final flag in flags)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: flag == 'self_harm'
                    ? const Color(0xFFEFF6FF)
                    : const Color(0xFFFEF3F2),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: flag == 'self_harm'
                      ? const Color(0xFFBFDBFE)
                      : const Color(0xFFFECDCA),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    flag == 'self_harm'
                        ? PhosphorIconsRegular.info
                        : PhosphorIconsRegular.warningCircle,
                    size: 12,
                    color: flag == 'self_harm'
                        ? const Color(0xFF1D4ED8)
                        : const Color(0xFFB42318),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    AppStrings.moderationFlag(flag),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: flag == 'self_harm'
                          ? const Color(0xFF1D4ED8)
                          : const Color(0xFFB42318),
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

/// Why there is no rewrite yet, in plain words, with what to do next.
class RewriteReasonNote extends StatelessWidget {
  const RewriteReasonNote({required this.message, super.key});

  final RawMessage message;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('rewrite-reason-${message.id}'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Brand.muted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(PhosphorIconsRegular.info, size: 15, color: Brand.inkSoft),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${AppStrings.rewriteReason(message.rewriteErrorCode)} '
              'Use the retry button to try a new rewrite, or reject it.',
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: Brand.inkSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
