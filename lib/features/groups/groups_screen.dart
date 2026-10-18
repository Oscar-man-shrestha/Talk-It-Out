import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talk_it_out/core/models/enums.dart';
import 'package:talk_it_out/core/models/group.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/core/ui/labels.dart';
import 'package:talk_it_out/core/ui/screen_async.dart';
import 'package:talk_it_out/core/ui/stitch_chrome.dart';
import 'package:talk_it_out/core/widgets/async_body.dart';
import 'package:talk_it_out/features/groups/data/my_message_status.dart';
import 'package:talk_it_out/features/groups/data/published_message.dart';
import 'package:talk_it_out/features/groups/group_providers.dart';

const _border = Color(0xFFE4E4E7);
const _ink = Color(0xFF09090B);
const _muted = Color(0xFF71717A);
const _faint = Color(0xFFA1A1AA);
const _low = Color(0xFFFAFAFA);

class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  final _search = TextEditingController();
  GroupRole? _role;
  var _showBanner = true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(groupsProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final hPad = screenWidth > 640 ? (screenWidth - 576) / 2 : 16.0;
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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: StitchPageHeader(
        title: AppStrings.navGroups,
        emphasizePageTitle: true,
        actions: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _low,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border),
            ),
            child: const Icon(Icons.shield_outlined, size: 20, color: _ink),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.black,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => context.go('/profile'),
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(Icons.person, size: 18, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/groups/new'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: const StadiumBorder(),
        icon: const Icon(Icons.add, size: 20),
        label: const Text(
          'Create Group',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      body: AsyncBody(
        status: asyncStatus(groups, isEmpty: allGroups.isEmpty),
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
                          Icons.search,
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
                                  Icons.close,
                                  size: 18,
                                  color: _faint,
                                ),
                              ),
                        border: _fieldBorder(_border),
                        enabledBorder: _fieldBorder(_border),
                        focusedBorder: _fieldBorder(Colors.black),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => context.push('/groups/new'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      fixedSize: const Size.fromHeight(36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text(
                      'New Group',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
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
                      label: 'All Groups',
                      selected: _role == null,
                      showDot: _role == null,
                      onTap: () => setState(() => _role = null),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: AppStrings.roleController,
                      count: controllerCount,
                      selected: _role == GroupRole.controller,
                      onTap: () => setState(() => _role = GroupRole.controller),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: AppStrings.roleContributor,
                      count: contributorCount,
                      selected: _role == GroupRole.contributor,
                      onTap: () =>
                          setState(() => _role = GroupRole.contributor),
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
              if (items.isEmpty)
                _NoMatch(
                  onClear: () => setState(() {
                    _search.clear();
                    _role = null;
                  }),
                )
              else
                for (final group in items) ...[
                  _GroupCard(group: group),
                  const SizedBox(height: 12),
                ],
              const SizedBox(height: 4),
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
                        Icon(Icons.chevron_right, size: 20, color: _faint),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 36, 16),
      decoration: BoxDecoration(
        color: _low,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Stack(
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconBox(icon: Icons.verified_user_outlined),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Psychological Safety Protocol',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _ink,
                            ),
                          ),
                        ),
                        SizedBox(width: 6),
                        _Dot(),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Groups are moderated by a Controller with AI pre-screening to protect team candidness and eliminate toxicity.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: -8,
            right: -8,
            child: IconButton(
              tooltip: 'Dismiss banner',
              onPressed: onDismiss,
              icon: const Icon(Icons.close, size: 18, color: _faint),
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

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: Colors.black,
        shape: BoxShape.circle,
      ),
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
      color: selected ? Colors.black : _low,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? Colors.black : _border),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: selected ? Colors.white : _muted,
                ),
              ),
              if (showDot) ...[
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
              if (count != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : _border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.black : _ink,
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
  const _GroupCard({required this.group});

  final Group group;

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

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => context.push('/groups/${group.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Avatar(
                    letters: _initials(group.agenda),
                    filled: controller,
                    live: controller && pending > 0,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.agenda,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _MetaLine(
                          memberCount: members?.length,
                          activeLabel: 'Active ${_ago(activity)}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: controller ? Colors.black : _low,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: controller ? Colors.black : _border,
                          ),
                        ),
                        child: Text(
                          roleLabel(group.myRole).toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: controller ? Colors.white : _ink,
                          ),
                        ),
                      ),
                      if (unread > 0) ...[
                        const SizedBox(height: 8),
                        _UnreadBadge(count: unread),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: _border),
              const SizedBox(height: 10),
              if (pending > 0 && controller)
                Row(
                  children: [
                    const _LiveDot(),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppStrings.pendingCount(pending),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _ink,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => context.push('/groups/${group.id}/review'),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _low,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: _border),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Review Queue',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _ink,
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(Icons.arrow_forward, size: 13, color: _ink),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              else if (pending > 0)
                Row(
                  children: [
                    const Icon(Icons.hourglass_top, size: 16, color: _muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pending == 1
                            ? '1 message pending approval'
                            : '$pending messages pending approval',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _ink,
                        ),
                      ),
                    ),
                    if (pendingSince != null)
                      Text(
                        _ago(pendingSince),
                        style: const TextStyle(fontSize: 11, color: _faint),
                      ),
                  ],
                )
              else
                const Row(
                  children: [
                    Icon(Icons.task_alt, size: 16, color: _ink),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'All messages published',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _ink,
                        ),
                      ),
                    ),
                    _Dot(),
                  ],
                ),
              if (latest != null) ...[
                const SizedBox(height: 8),
                _PreviewLine(
                  icon: !controller && pending > 0
                      ? Icons.check_circle_outline
                      : Icons.chat_outlined,
                  prefix: !controller && pending > 0
                      ? 'Accepted: '
                      : '${latest.displaySender?.name ?? AppStrings.anonymousUser}: ',
                  quote: !controller && pending > 0,
                  text: latest.text,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.memberCount, required this.activeLabel});

  final int? memberCount;
  final String activeLabel;

  @override
  Widget build(BuildContext context) {
    final members = memberCount == null
        ? null
        : memberCount == 1
        ? '1 member'
        : '$memberCount members';
    return Row(
      children: [
        if (members != null) ...[
          const Icon(Icons.group_outlined, size: 14, color: _muted),
          const SizedBox(width: 4),
          Text(members, style: const TextStyle(fontSize: 11, color: _muted)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text('•', style: TextStyle(fontSize: 10, color: _faint)),
          ),
        ],
        Flexible(
          child: Text(
            activeLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: _muted),
          ),
        ),
      ],
    );
  }
}

class _PreviewLine extends StatelessWidget {
  const _PreviewLine({
    required this.icon,
    required this.prefix,
    required this.text,
    required this.quote,
  });

  final IconData icon;
  final String prefix;
  final String text;
  final bool quote;

  @override
  Widget build(BuildContext context) {
    final body = quote ? '"$text"' : text;
    return Row(
      children: [
        Icon(icon, size: 15, color: quote ? _ink : _faint),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: prefix,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _ink,
                  ),
                ),
                TextSpan(
                  text: body,
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.letters,
    required this.filled,
    required this.live,
  });

  final String letters;
  final bool filled;
  final bool live;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: filled ? Colors.black : _low,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: filled ? Colors.black : _border),
            ),
            child: Text(
              letters,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: filled ? Colors.white : _ink,
              ),
            ),
          ),
          if (live)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 14,
                height: 14,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: _border),
                ),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
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
          color: Colors.black,
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
        color: Colors.black,
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

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty);
  final letters = parts.take(2).map((part) => part[0].toUpperCase()).join();
  return letters.isEmpty ? '?' : letters;
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
              backgroundColor: Colors.black,
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
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(AppStrings.groupsEmpty, textAlign: TextAlign.center),
      ),
    );
  }
}
