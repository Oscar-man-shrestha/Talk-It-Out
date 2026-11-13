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
import 'package:talk_it_out/core/widgets/async_body.dart';
import 'package:talk_it_out/features/groups/group_providers.dart';

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
        title: Text('Kick $name?'),
        content: Text(
          'Are you sure you want to kick $name from this group? They will lose access to the ongoing deliberation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Kick Member'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(groupRepositoryProvider).removeMember(groupId, userId);
      ref.invalidate(membersProvider(groupId));
      ref.invalidate(groupDetailProvider(groupId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name was kicked from the group.'),
            backgroundColor: const Color(0xFF09090B),
          ),
        );
      }
    }
  }

  Future<void> _leaveGroup(BuildContext context, WidgetRef ref) async {
    final isController =
        ref.read(groupDetailProvider(groupId)).value?.myRole ==
        GroupRole.controller;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Group?'),
        content: Text(
          isController
              ? 'Are you sure you want to leave this deliberation? You will no longer receive updates or be able to submit messages. The member who joined earliest will become the controller.'
              : 'Are you sure you want to leave this deliberation? You will no longer receive updates or be able to submit messages.',
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
            backgroundColor: Color(0xFF09090B),
          ),
        );
        context.go('/groups');
      }
    }
  }

  Future<void> _showAddMemberModal(BuildContext context, WidgetRef ref) async {
    final usernameCtrl = TextEditingController();
    var selectedRole = GroupRole.contributor;
    String? error;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Invite Member to Deliberation',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF09090B),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(modalCtx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Request a user to join this agenda room by entering their username or handle.',
                style: TextStyle(fontSize: 12, color: Color(0xFF71717A)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: usernameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  prefixText: '@',
                  hintText: 'username (e.g. alex_dev, sophia_ai)',
                  filled: true,
                  fillColor: const Color(0xFFFAFAFA),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE4E4E7)),
                  ),
                  errorText: error,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Quick Suggestions:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF71717A),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final handle in [
                    'alex_m',
                    'kavita_r',
                    'david_k',
                    'sophia_ai',
                    'marcus_nlp',
                  ])
                    ActionChip(
                      label: Text(
                        '@$handle',
                        style: const TextStyle(fontSize: 11),
                      ),
                      backgroundColor: const Color(0xFFF4F4F5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      onPressed: () {
                        setModalState(() {
                          usernameCtrl.text = handle;
                          error = null;
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF09090B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () async {
                    final raw = usernameCtrl.text.trim();
                    if (raw.isEmpty) {
                      setModalState(() => error = 'Please enter a username');
                      return;
                    }
                    Navigator.of(modalCtx).pop();
                    try {
                      await ref
                          .read(groupRepositoryProvider)
                          .addMember(
                            groupId,
                            username: raw,
                            role: selectedRole,
                          );
                      ref.invalidate(membersProvider(groupId));
                      ref.invalidate(groupDetailProvider(groupId));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Invitation sent to @$raw. Added to group.',
                            ),
                            backgroundColor: const Color(0xFF09090B),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to invite member: $e'),
                            backgroundColor: Colors.red.shade800,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text(
                    'Send Invitation & Add',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                  const Spacer(),
                  if (isController)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF09090B),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'MODERATOR CONTROLS ACTIVE',
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
                  onPressed: () => _showAddMemberModal(context, ref),
                  icon: const Icon(Icons.person_add_alt_1, size: 16),
                  label: const Text('Invite Member by Username'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF09090B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (member.role == GroupRole.controller)
                            const Text(
                              'Group Creator & Review Controller',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF71717A),
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
                            ? const Color(0xFF09090B)
                            : const Color(0xFFF4F4F5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        roleLabel(member.role),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: member.role == GroupRole.controller
                              ? Colors.white
                              : const Color(0xFF09090B),
                        ),
                      ),
                    ),
                    if (isController &&
                        member.role != GroupRole.controller) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Kick ${member.name}',
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
                    Icons.warning_amber_rounded,
                    color: Colors.red.shade700,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Deliberation Participation',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF991B1B),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Leaving will forfeit your access to agenda updates and room discussions.',
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
