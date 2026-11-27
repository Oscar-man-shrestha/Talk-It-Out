import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talk_it_out/core/models/enums.dart';
import 'package:talk_it_out/core/models/group.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/core/ui/screen_async.dart';
import 'package:talk_it_out/core/widgets/async_body.dart';
import 'package:talk_it_out/features/groups/data/my_message_status.dart';
import 'package:talk_it_out/features/groups/data/published_message.dart';
import 'package:talk_it_out/features/groups/group_providers.dart';
import 'package:talk_it_out/features/profile/profile_state.dart';
import 'package:talk_it_out/core/ui/brand.dart';
import 'package:talk_it_out/features/groups/group_chat_screen.dart';
import 'package:talk_it_out/core/ui/empty_state.dart';
import 'package:talk_it_out/features/invites/join_with_link.dart';
import 'package:talk_it_out/features/groups/data/group_invitation.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/ui/motion.dart';
import 'package:talk_it_out/core/ui/app_icons.dart';
import 'package:talk_it_out/features/groups/chat_header.dart';
import 'package:talk_it_out/core/ui/large_title_header.dart';
import 'package:talk_it_out/app/side_nav.dart';
import 'package:talk_it_out/core/ui/page_padding.dart';
import 'package:talk_it_out/features/premium/premium_promo.dart';

const _border = Brand.border;
const _ink = Brand.ink;
const _muted = Brand.inkSoft;
const _faint = Brand.inkFaint;
const _low = Brand.canvas;

class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  final _search = TextEditingController();
  GroupRole? _role;
  var _showBanner = true;

  /// The chat open beside the list on wide screens.
  String? _selectedId;
  String _sortOrder = 'Recent Activity';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(groupsProvider);
    final userProfile = ref.watch(userProfileProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    // Wide: list and chat side by side (the sidebar replaces the tab bar).
    // (screenWidth is the space beside the sidebar when it shows.)
    final wide = screenWidth >= 900;
    final sidebar = SidebarScope.visible(context);
    final hPad = wide ? 10.0 : pageHPad(screenWidth) - 4;
    final query = _search.text.trim().toLowerCase();
    final allGroups = groups.value ?? const <Group>[];
    final controllerCount = allGroups
        .where((group) => group.myRole == GroupRole.controller)
        .length;
    final contributorCount = allGroups
        .where((group) => group.myRole == GroupRole.contributor)
        .length;

    final items = allGroups.where((group) {
      final matchesRole = _role == null || group.myRole == _role;
      final matchesQuery =
          query.isEmpty || group.agenda.toLowerCase().contains(query);
      return matchesRole && matchesQuery;
    }).toList();

    if (_sortOrder == 'Alphabetical') {
      items.sort(
        (a, b) => a.agenda.toLowerCase().compareTo(b.agenda.toLowerCase()),
      );
    }
    // Pinned groups stay on top, like pinned chats in WhatsApp. The sort is
    // stable, so the chosen order holds within each part.
    final pinned = [
      for (final g in items)
        if (g.pinned) g,
    ];
    final rest = [
      for (final g in items)
        if (!g.pinned) g,
    ];
    items
      ..clear()
      ..addAll([...pinned, ...rest]);

    final selected = items.any((g) => g.id == _selectedId)
        ? _selectedId
        : items.firstOrNull?.id;
    final listPane = Scaffold(
      backgroundColor: Colors.white,
      appBar: LargeTitleHeader(
        title: AppStrings.navGroups,
        subtitle: allGroups.isEmpty
            ? null
            : '${allGroups.length} ${allGroups.length == 1 ? 'group' : 'groups'}',
        actions: [
          if (!sidebar)
            HeroAvatarButton(
              onTap: () => context.go('/profile'),
              avatarUrl: userProfile.avatarUrl,
            ),
        ],
      ),
      floatingActionButton: sidebar
          ? null
          : FloatingActionButton.extended(
              heroTag: 'groups-fab',
              onPressed: () => context.push('/groups/new'),
              backgroundColor: Brand.accent,
              foregroundColor: Colors.white,
              elevation: 6,
              shape: const StadiumBorder(),
              icon: const Icon(PhosphorIconsRegular.plus, size: 20),
              label: const Text(
                'Create Group',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
      body: AsyncBody(
        // With no groups but an invitation, show the list so it can be
        // answered.
        status: asyncStatus(
          groups,
          isEmpty:
              allGroups.isEmpty &&
              (ref.watch(myInvitationsProvider).value?.isEmpty ?? true),
        ),
        errorMessage: errorText(groups.error),
        onRetry: () => ref.invalidate(groupsProvider),
        empty: const _EmptyGroupsView(),
        child: RefreshIndicator(
          onRefresh: () async => ref.refresh(groupsProvider.future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 96),
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(fontSize: 12, color: _ink),
                      decoration: InputDecoration(
                        hintText: 'Search agenda or topic...',
                        hintStyle: const TextStyle(fontSize: 12, color: _faint),
                        filled: true,
                        fillColor: Colors.white,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                        prefixIcon: const Icon(
                          PhosphorIconsRegular.magnifyingGlass,
                          size: 20,
                          color: _faint,
                        ),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: () {
                                  _search.clear();
                                  setState(() {});
                                },
                                icon: const Icon(
                                  PhosphorIconsRegular.x,
                                  size: 18,
                                  color: _faint,
                                ),
                              ),
                        border: _fieldBorder(_border),
                        enabledBorder: _fieldBorder(_border),
                        focusedBorder: _fieldBorder(Brand.accent),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: _role == null,
                      showDot: _role == null,
                      onTap: () => setState(() => _role = null),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Controlling',
                      count: controllerCount,
                      selected: _role == GroupRole.controller,
                      onTap: () => setState(() => _role = GroupRole.controller),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Contributing',
                      count: contributorCount,
                      selected: _role == GroupRole.contributor,
                      onTap: () =>
                          setState(() => _role = GroupRole.contributor),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      tooltip: 'Sort groups',
                      initialValue: _sortOrder,
                      onSelected: (val) => setState(() => _sortOrder = val),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: _border),
                      ),
                      color: Colors.white,
                      elevation: 3,
                      itemBuilder: (ctx) => const [
                        PopupMenuItem(
                          value: 'Recent Activity',
                          height: 36,
                          child: Row(
                            children: [
                              Icon(Icons.bolt, size: 14, color: _ink),
                              SizedBox(width: 6),
                              Text(
                                'Recent Activity',
                                style: TextStyle(fontSize: 12, color: _ink),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'Alphabetical',
                          height: 36,
                          child: Row(
                            children: [
                              Icon(Icons.sort_by_alpha, size: 14, color: _ink),
                              SizedBox(width: 6),
                              Text(
                                'Alphabetical (A-Z)',
                                style: TextStyle(fontSize: 12, color: _ink),
                              ),
                            ],
                          ),
                        ),
                      ],
                      child: Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: _border),
                        ),
                        child: const Icon(
                          PhosphorIconsRegular.slidersHorizontal,
                          size: 17,
                          color: _ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_showBanner) ...[
                const SizedBox(height: 12),
                _ProtocolBanner(
                  onDismiss: () => setState(() => _showBanner = false),
                ),
              ],
              const SizedBox(height: 12),
              const _InvitationsSection(),
              if (items.isEmpty)
                _NoMatch(
                  onClear: () => setState(() {
                    _search.clear();
                    _role = null;
                  }),
                )
              else
                for (final (i, group) in items.indexed) ...[
                  Reveal(
                    index: i,
                    child: PressScale(
                      scale: 0.985,
                      child: _GroupCard(
                        group: group,
                        selected: wide && group.id == selected,
                        onOpen: wide
                            ? () => setState(() => _selectedId = group.id)
                            : null,
                      ),
                    ),
                  ),
                  if (i < items.length - 1)
                    const Divider(
                      height: 2,
                      thickness: 0.6,
                      indent: 73,
                      endIndent: 12,
                      color: _border,
                    ),
                ],
              // Your groups come first; Premium is offered after them.
              const SizedBox(height: 12),
              const PremiumPromoCard(),
              const SizedBox(height: 12),
              Material(
                color: _low,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => context.push('/groups/new'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border),
                    ),
                    child: const Row(
                      children: [
                        _IconBox(icon: Icons.psychology_outlined),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Need a safe anonymous space?',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: _ink,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                AppStrings.anonymousDisclosure,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.35,
                                  color: _muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          PhosphorIconsRegular.caretRight,
                          size: 20,
                          color: _faint,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!wide) return listPane;
    // Wide screens: the list beside the chosen chat, like WhatsApp Desktop.
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          SizedBox(width: 400, child: _PaneSize(child: listPane)),
          const VerticalDivider(width: 1, thickness: 1, color: _border),
          Expanded(
            child: selected == null
                ? const _PickAGroup()
                : _PaneSize(
                    child: GroupChatScreen(
                      key: ValueKey('embedded-$selected'),
                      groupId: selected,
                      embedded: true,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

OutlineInputBorder _fieldBorder(Color color) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: color),
  );
}

class _ProtocolBanner extends StatelessWidget {
  const _ProtocolBanner({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      decoration: BoxDecoration(
        color: Brand.accentSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Brand.accentBorder),
      ),
      child: Row(
        children: [
          const Icon(
            PhosphorIconsFill.shieldCheck,
            size: 18,
            color: Brand.accentInk,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Every message is rewritten for tone and approved by the group\'s controller before anyone sees it.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: Brand.accentInk,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Dismiss',
            onPressed: onDismiss,
            icon: const Icon(
              PhosphorIconsRegular.x,
              size: 16,
              color: Brand.accentInk,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Icon(icon, size: 18, color: _ink),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.showDot = false,
  });

  final String label;
  final int? count;
  final bool selected;
  final bool showDot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Brand.accent : Colors.white,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? Brand.accent : _border),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : _ink,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.2)
                        : _low,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : _ink,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupCard extends ConsumerWidget {
  const _GroupCard({required this.group, this.selected = false, this.onOpen});

  final Group group;

  /// Highlighted: the chat open beside the list (wide screens).
  final bool selected;

  /// Opens the group; by default the full-screen chat.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = group.myRole == GroupRole.controller;
    final members = ref.watch(membersProvider(group.id)).value;
    final messages = ref.watch(groupMessagesProvider(group.id)).value;
    final mine = ref.watch(myMessagesProvider(group.id)).value;
    final queue = group.pendingCount ?? 0;
    final myPending = controller
        ? 0
        : (mine ?? const <MyMessageStatus>[])
              .where((item) => item.status == MessageStatus.pending)
              .length;
    final pending = controller ? queue : myPending;
    final unread = ref.watch(groupUnreadCountProvider(group.id));
    final latest = _latestPublished(messages);
    final activity = latest?.publishedAt ?? group.createdAt;
    DateTime? pendingSince;
    if (!controller && mine != null) {
      for (final item in mine) {
        if (item.status != MessageStatus.pending) continue;
        final since = pendingSince;
        if (since == null || item.createdAt.isBefore(since)) {
          pendingSince = item.createdAt;
        }
      }
    }

    final preview = latest == null ? null : _previewText(latest);

    final hasUnread = unread > 0;
    final status = pending > 0
        ? (controller
              ? AppStrings.pendingCount(pending)
              : (pending == 1
                    ? 'Your message is waiting for review'
                    : '$pending of your messages are waiting for review'))
        : null;

    return Material(
      color: selected ? Brand.muted : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: ValueKey('group-${group.id}'),
        onTap: onOpen ?? () => context.push('/groups/${group.id}'),
        borderRadius: BorderRadius.circular(14),
        hoverColor: Brand.muted.withValues(alpha: 0.6),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GroupAvatar(
                name: group.agenda,
                size: 48,
                live: controller && pending > 0,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  group.agenda,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: hasUnread
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    letterSpacing: -0.25,
                                    color: _ink,
                                  ),
                                ),
                              ),
                              if (group.pinned) ...[
                                const SizedBox(width: 5),
                                Icon(
                                  PhosphorIconsFill.pushPin,
                                  key: ValueKey('pinned-${group.id}'),
                                  size: 13,
                                  color: _faint,
                                ),
                              ],
                              if (group.muted) ...[
                                const SizedBox(width: 5),
                                Icon(
                                  PhosphorIconsRegular.bellSlash,
                                  key: ValueKey('muted-${group.id}'),
                                  size: 13,
                                  color: _faint,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          listTimeLabel(activity),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: hasUnread
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: hasUnread ? _ink : _faint,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            preview ??
                                (members == null
                                    ? AppStrings.noMessagesYet
                                    : '${members.length} '
                                          '${members.length == 1 ? 'member' : 'members'}'
                                          ' · ${AppStrings.noMessagesYet}'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.35,
                              color: hasUnread ? _ink : _muted,
                              fontWeight: hasUnread
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (hasUnread) ...[
                          const SizedBox(width: 8),
                          _UnreadBadge(count: unread),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Role, review status and the review shortcut; wraps
                    // onto a second line when space runs out.
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 2,
                      children: [
                        _RoleTag(controller: controller),
                        if (status != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (controller)
                                const _LiveDot()
                              else
                                const Icon(
                                  PhosphorIconsRegular.hourglassMedium,
                                  size: 13,
                                  color: _muted,
                                ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  pendingSince != null && !controller
                                      ? '$status · ${_ago(pendingSince)}'
                                      : status,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: controller
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: controller ? _ink : _muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        if (status != null && controller)
                          TextButton(
                            onPressed: () =>
                                context.push('/groups/${group.id}/review'),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 30),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              visualDensity: VisualDensity.compact,
                              foregroundColor: _ink,
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: const Text('Review →'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// One line, like a chat list: who said it, or what kind of message.
  String _previewText(PublishedMessage m) {
    final who = m.displaySender?.name ?? AppStrings.anonymousUser;
    final first = who.split(' ').first;
    final body = m.poll != null
        ? 'Poll: ${m.text}'
        : m.attachmentId != null
        ? (m.text.trim().isEmpty ? 'Photo' : 'Photo: ${m.text}')
        : m.text;
    return '$first: ${body.replaceAll('\n', ' ')}';
  }
}

/// Small role marker next to the group name.
class _RoleTag extends StatelessWidget {
  const _RoleTag({required this.controller});

  final bool controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: controller ? Brand.accentSoft : _low,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: controller ? Brand.accentBorder : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            controller
                ? PhosphorIconsFill.shieldCheck
                : PhosphorIconsRegular.user,
            size: 11,
            color: controller ? Brand.accentInk : _muted,
          ),
          const SizedBox(width: 4),
          Text(
            controller ? AppStrings.roleController : 'Member',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: controller ? Brand.accentInk : _muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Today: the time. Otherwise the day label used in chat.
String listTimeLabel(DateTime date, {DateTime? now}) {
  final d = date.toLocal();
  final today = (now ?? DateTime.now()).toLocal();
  if (d.year == today.year && d.month == today.month && d.day == today.day) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour >= 12 ? 'PM' : 'AM'}';
  }
  return dayLabel(date, now: now);
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = unreadBadgeLabel(count);
    return Semantics(
      label: '$label unread',
      child: Container(
        constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Brand.accent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: Brand.accent,
        shape: BoxShape.circle,
      ),
    );
  }
}

PublishedMessage? _latestPublished(List<PublishedMessage>? messages) {
  if (messages == null || messages.isEmpty) return null;
  return messages.reduce(
    (latest, message) =>
        message.publishedAt.isAfter(latest.publishedAt) ? message : latest,
  );
}

String _ago(DateTime time) {
  final delta = DateTime.now().difference(time.toLocal());
  if (delta.isNegative || delta.inSeconds < 45) return 'just now';
  if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
  if (delta.inHours < 24) return '${delta.inHours}h ago';
  return '${delta.inDays}d ago';
}

class _NoMatch extends StatelessWidget {
  const _NoMatch({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: _low,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: _border),
            ),
            child: const Icon(Icons.manage_search, size: 26, color: _muted),
          ),
          const SizedBox(height: 12),
          const Text(
            'No groups match your search',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _ink,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Try searching by a broader keyword, agenda title, or start a new group discussion.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: _muted),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onClear,
            style: FilledButton.styleFrom(
              backgroundColor: Brand.accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear Filters & Search'),
          ),
        ],
      ),
    );
  }
}

class _EmptyGroupsView extends StatelessWidget {
  const _EmptyGroupsView();

  @override
  Widget build(BuildContext context) {
    final empty = EmptyState(
      inList: true,
      key: const ValueKey('groups-empty'),
      icon: PhosphorIconsRegular.usersThree,
      title: 'Start your first safe space',
      body: AppStrings.groupsEmpty,
      points: const [
        (
          Icons.visibility_off_outlined,
          'Members can write anonymously. Only the controller sees who sent it.',
        ),
        (
          PhosphorIconsRegular.sparkle,
          'Every message is rewritten in a calm tone.',
        ),
        (
          PhosphorIconsRegular.shieldCheck,
          'The controller reviews each message before the group sees it.',
        ),
      ],
      actions: [
        EmptyAction(
          'Create a group',
          () => context.push('/groups/new'),
          icon: PhosphorIconsRegular.plus,
          key: const ValueKey('groups-empty-create'),
        ),
        EmptyAction(
          'Join with an invite link',
          () => showJoinWithLinkDialog(context),
          icon: PhosphorIconsRegular.link,
          key: const ValueKey('groups-empty-join'),
        ),
        EmptyAction(
          'Explore questions',
          () => context.go('/feed'),
          icon: PhosphorIconsRegular.compass,
        ),
      ],
    );
    // Premium stays easy to find before the first group exists.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 96),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [empty, const PremiumPromoCard()],
            ),
          ),
        ),
      ),
    );
  }
}

/// Invitations waiting for your answer (`API.md` 69): you join a group only
/// by accepting, like WhatsApp's group invites.
class _InvitationsSection extends ConsumerStatefulWidget {
  const _InvitationsSection();

  @override
  ConsumerState<_InvitationsSection> createState() =>
      _InvitationsSectionState();
}

class _InvitationsSectionState extends ConsumerState<_InvitationsSection> {
  final _busy = <String>{};

  Future<void> _answer(GroupInvitation inv, {required bool accept}) async {
    setState(() => _busy.add(inv.id));
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(groupRepositoryProvider);
    try {
      if (accept) {
        final groupId = await repo.acceptInvitation(inv.id);
        ref.invalidate(groupsProvider);
        ref.invalidate(myInvitationsProvider);
        if (mounted) context.push('/groups/$groupId');
      } else {
        await repo.declineInvitation(inv.id);
        ref.invalidate(myInvitationsProvider);
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: Brand.ink,
            content: Text('Declined. You were not added to ${inv.agenda}.'),
          ),
        );
      }
    } on RepositoryException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      ref.invalidate(myInvitationsProvider);
    } finally {
      if (mounted) setState(() => _busy.remove(inv.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final invitations = ref.watch(myInvitationsProvider).value ?? const [];
    if (invitations.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const ValueKey('group-invitations'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Text(
            invitations.length == 1
                ? 'Invitation'
                : 'Invitations (${invitations.length})',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Brand.ink,
            ),
          ),
        ),
        for (final inv in invitations)
          Container(
            key: ValueKey('invitation-${inv.id}'),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Brand.ink, width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      PhosphorIconsRegular.userPlus,
                      size: 20,
                      color: Brand.ink,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        inv.agenda,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Brand.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${inv.invitedBy ?? 'Someone'} invited you · '
                  '${inv.memberCount == 1 ? '1 member' : '${inv.memberCount} members'}',
                  style: const TextStyle(fontSize: 12.5, color: Brand.inkSoft),
                ),
                const SizedBox(height: 4),
                const Text(
                  'You join only if you accept. Anonymous messages are hidden from the group but visible to the controller.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: Brand.inkSoft,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: ValueKey('decline-${inv.id}'),
                        onPressed: _busy.contains(inv.id)
                            ? null
                            : () => _answer(inv, accept: false),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        key: ValueKey('accept-${inv.id}'),
                        onPressed: _busy.contains(inv.id)
                            ? null
                            : () => _answer(inv, accept: true),
                        style: FilledButton.styleFrom(
                          backgroundColor: Brand.ink,
                        ),
                        child: const Text('Accept'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Wide screens, before a group is chosen.
class _PickAGroup extends StatelessWidget {
  const _PickAGroup();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Brand.canvas,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIconsRegular.chatsCircle, size: 44, color: _faint),
            SizedBox(height: 12),
            Text(
              'Choose a group to open its conversation',
              style: TextStyle(fontSize: 14, color: _muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tells a pane its own size, so a chat beside the list lays itself out as
/// it would on a screen that wide (bubble widths, padding, hover actions).
class _PaneSize extends StatelessWidget {
  const _PaneSize({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(size: Size(box.maxWidth, box.maxHeight)),
        child: child,
      ),
    );
  }
}
