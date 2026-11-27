import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/models/enums.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/core/ui/labels.dart';
import 'package:talk_it_out/core/ui/screen_async.dart';
import 'package:talk_it_out/core/ui/stitch_chrome.dart';
import 'package:talk_it_out/core/utils/relative_time.dart';
import 'package:talk_it_out/core/widgets/async_body.dart';
import 'package:talk_it_out/features/discovery/add_members_sheet.dart';
import 'package:talk_it_out/features/discovery/person_profile_screen.dart';
import 'package:talk_it_out/features/groups/data/group_invitation.dart';
import 'package:talk_it_out/features/groups/group_providers.dart';
import 'package:talk_it_out/core/ui/brand.dart';
import 'package:talk_it_out/features/invites/invite_sheet.dart';
import 'package:talk_it_out/core/ui/app_icons.dart';

class MembersScreen extends ConsumerWidget {
  const MembersScreen({required this.groupId, super.key});

  final String groupId;

  Future<void> _kickMember(
    BuildContext context,
    WidgetRef ref, {
    required String userId,
    required String name,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove $name?'),
        content: Text(
          '$name will leave this group and stop seeing its messages. You can invite them again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await ref.read(groupRepositoryProvider).removeMember(groupId, userId);
      } on RepositoryException catch (error) {
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
        return;
      }
      ref.invalidate(membersProvider(groupId));
      ref.invalidate(groupDetailProvider(groupId));
      messenger.showSnackBar(
        SnackBar(
          content: Text('$name was removed from the group.'),
          backgroundColor: Brand.ink,
        ),
      );
    }
  }

  Future<void> _leaveGroup(BuildContext context, WidgetRef ref) async {
    final isController =
        ref.read(groupDetailProvider(groupId)).value?.myRole ==
        GroupRole.controller;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave this group?'),
        content: Text(
          isController
              ? 'You will stop seeing its messages and cannot send new ones. The member who joined earliest becomes the controller.'
              : 'You will stop seeing its messages and cannot send new ones.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Leave Group'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(groupRepositoryProvider).leaveGroup(groupId);
      } on RepositoryException catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(error.message)));
        }
        return;
      }
      ref.invalidate(groupsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You left the group.'),
            backgroundColor: Brand.ink,
          ),
        );
        context.go('/groups');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(membersProvider(groupId));
    final group = ref.watch(groupDetailProvider(groupId));
    final isController = group.value?.myRole == GroupRole.controller;
    final items = members.value ?? const [];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 900;
    final isMobile = screenWidth < 600;
    final hPad = isDesktop ? (screenWidth - 860) / 2 : (isMobile ? 12.0 : 20.0);

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
              style: TextStyle(color: isDark ? Brand.inkSoft : Brand.inkSoft),
            ),
          ),
        ),
        child: ListView(
          padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 40),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF18181B) : Brand.muted,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0x24FFFFFF) : Brand.border,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.groups_rounded, color: Brand.ink, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    '${items.length} ${items.length == 1 ? "Member" : "Members"}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  if (isController)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Brand.ink,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'YOU ARE THE CONTROLLER',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (isController) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => showAddMembersSheet(context, groupId),
                  icon: const Icon(PhosphorIconsRegular.userPlus, size: 16),
                  label: const Text('Invite members'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Brand.ink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const ValueKey('members-invite-link'),
                  onPressed: () => showInviteSheet(
                    context,
                    groupId: groupId,
                    agenda: group.value?.agenda ?? '',
                  ),
                  icon: const Icon(PhosphorIconsRegular.link, size: 16),
                  label: const Text('Invite with a link or QR code'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Brand.ink,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              _PendingInvitations(groupId: groupId),
            ],
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
                    GestureDetector(
                      key: ValueKey('member-${member.userId}'),
                      onTap: () => openPerson(context, ref, member.userId),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: member.role == GroupRole.controller
                              ? Brand.ink
                              : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Brand.ink),
                        ),
                        child: Center(
                          child: Text(
                            member.name.isNotEmpty
                                ? member.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: member.role == GroupRole.controller
                                  ? Colors.white
                                  : Brand.ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () =>
                                openPerson(context, ref, member.userId),
                            child: Text(
                              member.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (member.role == GroupRole.controller)
                            const Text(
                              'Reviews every message before it is shared',
                              style: TextStyle(
                                fontSize: 11,
                                color: Brand.inkSoft,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: member.role == GroupRole.controller
                            ? Brand.ink
                            : Brand.muted,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        roleLabel(member.role),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: member.role == GroupRole.controller
                              ? Colors.white
                              : Brand.ink,
                        ),
                      ),
                    ),
                    if (isController &&
                        member.role != GroupRole.controller) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Remove ${member.name}',
                        icon: const Icon(
                          Icons.person_remove_outlined,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        onPressed: () => _kickMember(
                          context,
                          ref,
                          userId: member.userId,
                          name: member.name,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Leave Group Action Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    PhosphorIconsRegular.warning,
                    color: Colors.red.shade700,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Leave this group',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF991B1B),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'You will stop seeing its messages. You can rejoin only if invited again.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF7F1D1D),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade400),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    onPressed: () => _leaveGroup(context, ref),
                    icon: const Icon(Icons.exit_to_app_rounded, size: 16),
                    label: const Text(
                      'Leave',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Invited, not answered yet (`API.md` 69). The controller can cancel.
class _PendingInvitations extends ConsumerWidget {
  const _PendingInvitations({required this.groupId});

  final String groupId;

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    PendingInvitation inv,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cancel the invitation to ${inv.name}?'),
        content: const Text(
          'They will no longer be able to accept it. You can invite them again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            key: const ValueKey('confirm-cancel-invitation'),
            style: FilledButton.styleFrom(backgroundColor: Brand.ink),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel invitation'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(groupRepositoryProvider).cancelInvitation(groupId, inv.id);
      ref.invalidate(groupInvitationsProvider(groupId));
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: Brand.ink,
          content: Text('Invitation to ${inv.name} cancelled.'),
        ),
      );
    } on RepositoryException catch (e) {
      ref.invalidate(groupInvitationsProvider(groupId));
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending =
        ref.watch(groupInvitationsProvider(groupId)).value ?? const [];
    if (pending.isEmpty) return const SizedBox.shrink();
    return Padding(
      key: const ValueKey('pending-invitations'),
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Invited (${pending.length})',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Brand.ink,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'They join after they accept.',
            style: TextStyle(fontSize: 12, color: Brand.inkSoft),
          ),
          const SizedBox(height: 6),
          for (final inv in pending)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Brand.accentSoft,
                    child: Text(
                      inv.name.isEmpty ? '?' : inv.name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Brand.accentInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      inv.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    'Invited ${relativeTime(inv.createdAt)}',
                    style: const TextStyle(fontSize: 12, color: Brand.inkSoft),
                  ),
                  TextButton(
                    key: ValueKey('cancel-invitation-${inv.id}'),
                    onPressed: () => _cancel(context, ref, inv),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
