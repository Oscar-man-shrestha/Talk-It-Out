import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/models/enums.dart';
import 'package:talk_it_out/core/ui/brand.dart';
import 'package:talk_it_out/features/feed/edit_sheets.dart';
import 'package:talk_it_out/features/groups/catch_up.dart';
import 'package:talk_it_out/features/groups/group_providers.dart';
import 'package:talk_it_out/features/invites/invite_sheet.dart';
import 'package:talk_it_out/core/ui/page_padding.dart';
import 'package:talk_it_out/core/ui/app_icons.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';

/// Group info, like WhatsApp's and Discord's: what the group is for, its
/// rules, your own mute and pin, and shortcuts (`API.md` 67).
class GroupInfoScreen extends ConsumerWidget {
  const GroupInfoScreen({required this.groupId, super.key});

  final String groupId;

  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      ref.invalidate(groupDetailProvider(groupId));
      ref.invalidate(groupsProvider);
    } on RepositoryException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _editText(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String initial,
    required int maxLength,
    required bool rules,
  }) async {
    final text = await showEditTextSheet(
      context,
      title: title,
      initial: initial,
      maxLength: maxLength,
    );
    if (text == null || !context.mounted) return;
    final repo = ref.read(groupRepositoryProvider);
    await _act(
      context,
      ref,
      () => rules
          ? repo.updateGroupInfo(groupId, rules: text)
          : repo.updateGroupInfo(groupId, description: text),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(groupDetailProvider(groupId));
    final members = ref.watch(membersProvider(groupId)).value;
    return Scaffold(
      backgroundColor: Brand.canvas,
      appBar: AppBar(
        title: const Text(
          'Group info',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      body: group.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (e, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(groupDetailProvider(groupId)),
            child: const Text('Could not load. Try again'),
          ),
        ),
        data: (g) {
          final controller = g.myRole == GroupRole.controller;
          final count = members?.length ?? g.memberCount;
          final width = MediaQuery.sizeOf(context).width;
          final hPad = pageHPad(width);
          return ListView(
            padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 32),
            children: [
              Center(
                child: Container(
                  width: 76,
                  height: 76,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Brand.ink,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    _initials(g.agenda),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                g.agenda,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: Brand.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${count == 1 ? '1 member' : '$count members'} · Created ${_date(g.createdAt)}'
                '${controller ? ' · You are the controller' : ''}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, color: Brand.inkSoft),
              ),
              const SizedBox(height: 18),
              _Section(
                key: const ValueKey('info-description'),
                title: 'About',
                text: g.description,
                empty: controller
                    ? 'Add a short description so people know what this group is for.'
                    : 'No description yet.',
                onEdit: controller
                    ? () => _editText(
                        context,
                        ref,
                        title: 'Group description',
                        initial: g.description,
                        maxLength: 500,
                        rules: false,
                      )
                    : null,
              ),
              const SizedBox(height: 10),
              _Section(
                key: const ValueKey('info-rules'),
                title: 'Group rules',
                text: g.rules,
                empty: controller
                    ? 'Add rules everyone sees, for example "Talk about problems, not people."'
                    : 'No rules yet. Be kind and specific.',
                onEdit: controller
                    ? () => _editText(
                        context,
                        ref,
                        title: 'Group rules',
                        initial: g.rules,
                        maxLength: 1000,
                        rules: true,
                      )
                    : null,
              ),
              const SizedBox(height: 10),
              _Card(
                child: Column(
                  children: [
                    _SwitchRow(
                      key: const ValueKey('info-mute'),
                      icon: Icons.notifications_off_outlined,
                      title: 'Mute',
                      subtitle: 'Keep the group, but leave it out of the Groups badge.',
                      value: g.muted,
                      onChanged: (on) => _act(
                        context,
                        ref,
                        () => ref
                            .read(groupRepositoryProvider)
                            .updateGroupSettings(groupId, muted: on),
                      ),
                    ),
                    const Divider(height: 1),
                    _SwitchRow(
                      key: const ValueKey('info-pin'),
                      icon: PhosphorIconsRegular.pushPin,
                      title: 'Pin to top',
                      subtitle: 'Keep this group at the top of your list.',
                      value: g.pinned,
                      onChanged: (on) => _act(
                        context,
                        ref,
                        () => ref
                            .read(groupRepositoryProvider)
                            .updateGroupSettings(groupId, pinned: on),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _Card(
                child: Column(
                  children: [
                    _LinkRow(
                      PhosphorIconsRegular.users,
                      'Members',
                      '$count',
                      () => context.push('/groups/$groupId/members'),
                    ),
                    if (controller) ...[
                      const Divider(height: 1),
                      _LinkRow(
                        PhosphorIconsRegular.link,
                        'Invite with a link or QR code',
                        null,
                        () => showInviteSheet(
                          context,
                          groupId: groupId,
                          agenda: g.agenda,
                        ),
                      ),
                      const Divider(height: 1),
                      // Premium (API.md 71); the screen shows a teaser
                      // without it.
                      _LinkRow(
                        PhosphorIconsRegular.chartBar,
                        AppStrings.insightsTitle,
                        AppStrings.premium,
                        () => context.push('/groups/$groupId/insights'),
                      ),
                    ],
                    const Divider(height: 1),
                    _LinkRow(
                      PhosphorIconsRegular.sparkle,
                      'Catch up',
                      null,
                      () => showCatchUpSheet(context, groupId),
                    ),
                    const Divider(height: 1),
                    _LinkRow(
                      Icons.outbox_outlined,
                      'My messages',
                      null,
                      () => context.push('/groups/$groupId/mine'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Anonymous messages are hidden from the group but visible to the controller.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Brand.inkSoft),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _initials(String text) {
    final words = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final letters = words.take(2).map((w) => w[0].toUpperCase()).join();
    return letters.isEmpty ? '?' : letters;
  }

  static String _date(DateTime d) {
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
    final l = d.toLocal();
    return '${l.day} ${months[l.month - 1]} ${l.year}';
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Brand.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.text,
    required this.empty,
    this.onEdit,
    super.key,
  });

  final String title;
  final String text;
  final String empty;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Brand.ink,
                    ),
                  ),
                ),
                if (onEdit != null)
                  TextButton(
                    onPressed: onEdit,
                    child: Text(text.isEmpty ? 'Add' : 'Edit'),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                text.isEmpty ? empty : text,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: text.isEmpty ? Brand.inkSoft : Brand.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Brand.ink),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Brand.inkSoft),
                ),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow(this.icon, this.title, this.trailing, this.onTap);

  final IconData icon;
  final String title;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Brand.ink),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: const TextStyle(fontSize: 13, color: Brand.inkSoft),
              ),
            const SizedBox(width: 4),
            const Icon(PhosphorIconsRegular.caretRight, color: Brand.inkSoft),
          ],
        ),
      ),
    );
  }
}
