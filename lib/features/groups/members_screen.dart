import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talk_it_out/core/models/enums.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/core/ui/labels.dart';
import 'package:talk_it_out/core/ui/screen_async.dart';
import 'package:talk_it_out/core/ui/stitch_chrome.dart';
import 'package:talk_it_out/core/widgets/async_body.dart';
import 'package:talk_it_out/features/groups/group_providers.dart';

class MembersScreen extends ConsumerWidget {
  const MembersScreen({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(membersProvider(groupId));
    final items = members.value ?? const [];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final hPad = screenWidth > 860 ? (screenWidth - 800) / 2 : 16.0;

    return Scaffold(
      appBar: const StitchPageHeader(
        title: AppStrings.membersTitle,
        leading: BackButton(),
      ),
      body: AsyncBody(
        status: asyncStatus(members, isEmpty: items.isEmpty),
        errorMessage: errorText(members.error),
        onRetry: () => ref.invalidate(membersProvider(groupId)),
        empty: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              AppStrings.membersTitle,
              style: TextStyle(
                color: isDark
                    ? const Color(0xFF71717A)
                    : const Color(0xFF71717A),
              ),
            ),
          ),
        ),
        child: ListView(
          padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 40),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF18181B)
                    : const Color(0xFFF4F4F5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? const Color(0x24FFFFFF)
                      : const Color(0xFFE4E4E7),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.groups_rounded,
                    color: Color(0xFF09090B),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${items.length} ${items.length == 1 ? "Member" : "Members"}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            for (final member in items) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF18181B) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? const Color(0x1FFFFFFF)
                        : const Color(0x14000000),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: member.role == GroupRole.controller
                            ? const Color(0xFF09090B)
                            : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF09090B)),
                      ),
                      child: Center(
                        child: Text(
                          member.name.isNotEmpty
                              ? member.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: member.role == GroupRole.controller
                                ? Colors.white
                                : const Color(0xFF09090B),
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        member.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: member.role == GroupRole.controller
                            ? (isDark
                                  ? const Color(0xFF27272A)
                                  : const Color(0xFFF4F4F5))
                            : (isDark
                                  ? const Color(0xFF27272A)
                                  : const Color(0xFFF4F4F5)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        roleLabel(member.role),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: member.role == GroupRole.controller
                              ? (isDark
                                    ? const Color(0xFF09090B)
                                    : const Color(0xFF09090B))
                              : (isDark
                                    ? const Color(0xFF09090B)
                                    : const Color(0xFF09090B)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
