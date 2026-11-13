import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/core/ui/screen_async.dart';
import 'package:talk_it_out/core/ui/stitch_chrome.dart';
import 'package:talk_it_out/core/widgets/async_body.dart';
import 'package:talk_it_out/features/auth/session_controller.dart';
import 'package:talk_it_out/features/feed/data/post.dart';
import 'package:talk_it_out/features/feed/data/post_topic.dart';
import 'package:talk_it_out/features/feed/feed_providers.dart';
import 'package:talk_it_out/features/feed/saved_posts.dart';
import 'package:talk_it_out/features/profile/profile_state.dart';

const _border = Color(0xFFE4E4E7);
const _ink = Color(0xFF09090B);
const _muted = Color(0xFF71717A);
const _faint = Color(0xFFA1A1AA);
const _chip = Color(0xFFF4F4F5);
const _low = Color(0xFFFAFAFA);

/// "All Topics" plus the fixed feed topics (`API.md` 42).
final _topics = <(IconData, String, PostTopic?)>[
  (Icons.apps_rounded, 'All Topics', null),
  for (final topic in PostTopic.all) (topic.icon, topic.label, topic),
];

/// Ordering of the visible questions.
const _sorts = ['Newest', 'Most liked', 'Most discussed'];

// Index 0 shows everything, so a first visit never hides posts that
// already have comments.
const _statuses = [
  'All questions',
  'Unanswered',
  'Peer solved',
  'Active debate',
  'Saved',
];

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final _search = TextEditingController();
  final _boardKey = GlobalKey();
  var _topic = 0;
  var _sort = 0;
  var _status = 0;
  var _weekly = true;
  String? _creatingId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Post> _visible(List<Post> items) {
    final query = _search.text.trim().toLowerCase();
    final topic = _topics[_topic].$3;
    final visible = [
      for (final post in items)
        if (_matches(post, query, topic) && _statusMatches(post)) post,
    ];
    switch (_sort) {
      case 1:
        visible.sort((a, b) => b.reactionCount.compareTo(a.reactionCount));
      case 2:
        visible.sort((a, b) => b.commentCount.compareTo(a.commentCount));
      default:
        visible.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return visible;
  }

  bool _matches(Post post, String query, PostTopic? topic) {
    final haystack = '${post.title ?? ''} ${post.content} ${post.author.name}'
        .toLowerCase();
    if (query.isNotEmpty && !haystack.contains(query)) return false;
    if (topic == null) return true;
    // Questions carry a topic; older posts fall back to keywords.
    if (post.topic != null) return post.topic == topic.id;
    return topic.keywords.any(haystack.contains);
  }

  bool _statusMatches(Post post) {
    switch (_status) {
      case 1:
        return post.commentCount == 0;
      case 2:
        return post.commentCount > 0;
      case 3:
        return post.commentCount >= 2;
      case 4:
        return ref.read(savedPostsProvider).contains(post.id);
      default:
        return true;
    }
  }

  List<_Voice> _leaders(List<Post> posts) {
    final byAuthor = <String, _Voice>{};
    // Weekly = the last 7 days, daily = the last 24 hours.
    final cutoff = DateTime.now().toUtc().subtract(
      _weekly ? const Duration(days: 7) : const Duration(days: 1),
    );
    for (final post in posts) {
      if (post.createdAt.isBefore(cutoff)) continue;
      final voice = byAuthor.putIfAbsent(
        post.author.id,
        () => _Voice(post.author.name),
      );
      voice.score += post.reactionCount;
    }
    final ranked = byAuthor.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    if (ranked.length > 3) return ranked.sublist(0, 3);
    return ranked;
  }

  Future<void> _toggleLike(Post post) async {
    final repo = ref.read(feedRepositoryProvider);
    try {
      if (post.myReaction == null) {
        await repo.addReaction(post.id, type: 'like');
      } else {
        await repo.removeReaction(post.id);
      }
      ref.invalidate(feedProvider);
    } on RepositoryException {
      // The list stays as it was. A later refresh can retry.
    }
  }

  Future<void> _createGroup(Post post) async {
    setState(() => _creatingId = post.id);
    try {
      final group = await ref
          .read(feedRepositoryProvider)
          .createGroupFromPost(post.id);
      if (mounted) context.go('/groups/${group.id}');
    } on RepositoryException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _creatingId = null);
    }
  }

  void _scrollToBoard() {
    final target = _boardKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 250),
      alignment: 0.1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(feedProvider);
    ref.watch(savedPostsProvider);
    final items = feed.value ?? const <Post>[];
    final visible = _visible(items);
    final userId = ref.watch(sessionProvider).value?.id;
    final userProfile = ref.watch(userProfileProvider);
    final openCount = items.where((post) => post.commentCount == 0).length;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 900;
    final isMobile = screenWidth < 600;
    final hPad = isDesktop ? (screenWidth - 860) / 2 : (isMobile ? 12.0 : 20.0);
    final compactHeader = screenWidth < 640;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: _low,
      appBar: StitchPageHeader(
        title: 'Community Q&A Feed',
        actions: [
          Container(
            height: 32,
            padding: EdgeInsets.symmetric(horizontal: compactHeader ? 0 : 10),
            constraints: compactHeader
                ? const BoxConstraints.tightFor(width: 32, height: 32)
                : null,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _chip,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_user_rounded, size: 16, color: _ink),
                if (!compactHeader) ...[
                  const SizedBox(width: 6),
                  const Text(
                    'Public',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _ink,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.black,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => context.go('/profile'),
              child: SizedBox(
                width: 32,
                height: 32,
                child: userProfile.avatarUrl != null
                    ? Image.network(
                        userProfile.avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.person,
                              size: 17,
                              color: Colors.white,
                            ),
                      )
                    : const Icon(Icons.person, size: 17, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/feed/new'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: const StadiumBorder(),
        icon: const Icon(Icons.help_outline, size: 18),
        label: const Text(
          '+ ASK QUESTION',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ),
      body: AsyncBody(
        status: asyncStatus(feed, isEmpty: items.isEmpty),
        errorMessage: errorText(feed.error),
        onRetry: () => ref.invalidate(feedProvider),
        empty: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.forum_outlined,
                    size: 32,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  AppStrings.feedEmpty,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => context.push('/feed/new'),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text(AppStrings.newPost),
                ),
              ],
            ),
          ),
        ),
        child: RefreshIndicator(
          onRefresh: () async => ref.refresh(feedProvider.future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 96),
            children: [
              _Hero(
                openCount: openCount,
                onAsk: () => context.push('/feed/new'),
                onRankings: _scrollToBoard,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 13, color: _ink),
                decoration: InputDecoration(
                  hintText: 'Search honest dilemmas, rubrics, tags...',
                  hintStyle: const TextStyle(fontSize: 12, color: _faint),
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  prefixIcon: const Icon(Icons.search, size: 19, color: _faint),
                  suffixIcon: const Icon(Icons.tune, size: 18, color: _muted),
                  border: _fieldBorder(_border),
                  enabledBorder: _fieldBorder(_border),
                  focusedBorder: _fieldBorder(Colors.black),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < _topics.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      _TopicChip(
                        icon: _topics[i].$1,
                        label: _topics[i].$2,
                        active: _topic == i,
                        onTap: () => setState(() => _topic = i),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Flexible(
                    child: _MenuPill(
                      value: _sort,
                      options: _sorts,
                      onChanged: (value) => setState(() => _sort = value),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: _MenuPill(
                      value: _status,
                      options: _statuses,
                      onChanged: (value) => setState(() => _status = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Leaderboard(
                key: _boardKey,
                voices: _leaders(items),
                weekly: _weekly,
                onWeekly: () => setState(() => _weekly = true),
                onDaily: () => setState(() => _weekly = false),
              ),
              const SizedBox(height: 12),
              if (visible.isEmpty)
                const _CaughtUp(
                  title: 'No questions match',
                  body: 'Try another topic, or clear the search to see the full feed.',
                )
              else
                for (final post in visible) ...[
                  PostCard(
                    post: post,
                    onOpen: () => context.push('/feed/${post.id}'),
                    onToggleLike: () => _toggleLike(post),
                    onCreateGroup: post.author.id == userId
                        ? () => _createGroup(post)
                        : null,
                    creatingGroup: _creatingId == post.id,
                  ),
                  const SizedBox(height: 12),
                ],
              if (visible.isNotEmpty) ...[
                const SizedBox(height: 4),
                const _CaughtUp(
                  title: "You're caught up with community consensus!",
                  body: 'Questions on this feed stay attributed to the person who wrote them.',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _ago(DateTime value) {
  final delta = DateTime.now().difference(value.toLocal());
  if (delta.isNegative || delta.inMinutes < 1) return 'just now';
  if (delta.inMinutes < 60) return '${delta.inMinutes} min ago';
  if (delta.inHours < 24) {
    final hours = delta.inHours;
    return hours == 1 ? '1 hour ago' : '$hours hours ago';
  }
  if (delta.inDays < 14) {
    final days = delta.inDays;
    return days == 1 ? '1 day ago' : '$days days ago';
  }
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

OutlineInputBorder _fieldBorder(Color color) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(4),
    borderSide: BorderSide(color: color),
  );
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.openCount,
    required this.onAsk,
    required this.onRankings,
  });

  final int openCount;
  final VoidCallback onAsk;
  final VoidCallback onRankings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _OutlinePill(
                icon: Icons.bolt_rounded,
                label: 'Candid Peer Consensus',
              ),
              const Spacer(),
              if (openCount > 0)
                _OutlinePill(
                  label: '$openCount unanswered',
                  leadingDot: true,
                  mono: true,
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Ask a Question & Talk It Out',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              height: 1.15,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Questions are posted under your name • Answered by peers and workplace controllers.',
            style: TextStyle(fontSize: 13, height: 1.45, color: _muted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onAsk,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    fixedSize: const Size.fromHeight(40),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  icon: const Icon(Icons.help_outline, size: 17),
                  label: const Text('ASK YOUR QUESTION'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: onRankings,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _ink,
                  fixedSize: const Size(40, 40),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: const BorderSide(color: _border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Icon(Icons.military_tech_outlined, size: 17),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OutlinePill extends StatelessWidget {
  const _OutlinePill({
    required this.label,
    this.icon,
    this.leadingDot = false,
    this.mono = false,
  });

  final String label;
  final IconData? icon;
  final bool leadingDot;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _chip,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: _ink),
            const SizedBox(width: 4),
          ],
          if (leadingDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: mono ? FontWeight.w500 : FontWeight.w500,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicChip extends StatelessWidget {
  const _TopicChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? Colors.black : Colors.white,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: active ? Colors.black : _border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 14, color: active ? Colors.white : _muted),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: active ? Colors.white : _muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuPill extends StatelessWidget {
  const _MenuPill({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final int value;
  final List<String> options;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.only(left: 10, right: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          isDense: true,
          icon: const Icon(Icons.expand_more, size: 15, color: _muted),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _ink,
          ),
          items: [
            for (var i = 0; i < options.length; i++)
              DropdownMenuItem(
                value: i,
                child: Text(options[i], overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      ),
    );
  }
}

class _Voice {
  _Voice(this.name);

  final String name;
  int score = 0;
}

class _Leaderboard extends StatelessWidget {
  const _Leaderboard({
    required this.voices,
    required this.weekly,
    required this.onWeekly,
    required this.onDaily,
    super.key,
  });

  final List<_Voice> voices;
  final bool weekly;
  final VoidCallback onWeekly;
  final VoidCallback onDaily;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_outlined, size: 16, color: _ink),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'MOST ACTIVE AUTHORS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    color: _ink,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: _chip,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  children: [
                    _Toggle(label: 'Weekly', active: weekly, onTap: onWeekly),
                    _Toggle(label: 'Daily', active: !weekly, onTap: onDaily),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (voices.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'No posts in this window.',
                style: TextStyle(fontSize: 12, color: _muted),
              ),
            )
          else
            Row(
              children: [
                for (var i = 0; i < voices.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _VoiceTile(voice: voices[i], first: i == 0),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? Colors.black : Colors.transparent,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: active ? Colors.white : _muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _VoiceTile extends StatelessWidget {
  const _VoiceTile({required this.voice, required this.first});

  final _Voice voice;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final letters = voice.name.trim().isEmpty
        ? '?'
        : voice.name
              .trim()
              .split(RegExp(r'\s+'))
              .take(2)
              .map((part) => part[0].toUpperCase())
              .join();
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: _low,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: first ? Colors.black : const Color(0xFFE4E4E7),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: first ? Colors.black : _border),
            ),
            child: Text(
              letters,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: first ? Colors.white : _ink,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  voice.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _ink,
                  ),
                ),
                Text(
                  '⚡ ${voice.score} pts',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: _muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CaughtUp extends StatelessWidget {
  const _CaughtUp({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _chip,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.auto_awesome, size: 18, color: _ink),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, height: 1.4, color: _muted),
          ),
        ],
      ),
    );
  }
}

class PostCard extends StatelessWidget {
  const PostCard({
    required this.post,
    required this.onOpen,
    required this.onToggleLike,
    this.onCreateGroup,
    this.creatingGroup = false,
    this.showAnswer = true,
    super.key,
  });

  final Post post;
  final VoidCallback onOpen;
  final VoidCallback onToggleLike;
  final VoidCallback? onCreateGroup;
  final bool creatingGroup;
  final bool showAnswer;

  @override
  Widget build(BuildContext context) {
    final liked = post.myReaction != null;
    final letters = post.author.name.trim().isEmpty
        ? '?'
        : post.author.name
              .trim()
              .split(RegExp(r'\s+'))
              .take(2)
              .map((part) => part[0].toUpperCase())
              .join();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      letters,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                post.author.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _ink,
                                ),
                              ),
                            ),
                            if (post.nsfwFlag) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _chip,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: _border),
                                ),
                                child: Text(
                                  AppStrings.flagged,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFBA1A1A),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _ago(post.createdAt),
                          style: const TextStyle(fontSize: 11, color: _muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _chip,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _border),
                    ),
                    child: Text(
                      '⚡ ${post.reactionCount}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (PostTopic.byId(post.topic) case final topic?) ...[
                Row(
                  children: [
                    Icon(topic.icon, size: 13, color: _muted),
                    const SizedBox(width: 4),
                    Text(
                      topic.label,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
              if (post.title != null) ...[
                Text(
                  post.title!,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                post.content,
                maxLines: post.title != null ? 4 : null,
                overflow: post.title != null ? TextOverflow.ellipsis : null,
                style: TextStyle(
                  fontSize: post.title != null ? 13.5 : 14,
                  fontWeight: post.title != null
                      ? FontWeight.w400
                      : FontWeight.w700,
                  height: 1.4,
                  color: post.title != null ? _muted : _ink,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _low,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _border),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.auto_awesome, size: 15, color: _ink),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NOT REWRITTEN BY AI',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: _ink,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Shown as the author wrote it.',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.3,
                              color: _muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.poll_outlined, size: 14, color: _muted),
                  const SizedBox(width: 4),
                  Text(
                    post.commentCount == 0
                        ? 'Awaiting first answer'
                        : '${post.commentCount} ${AppStrings.commentsTitle}',
                    style: const TextStyle(fontSize: 11, color: _muted),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(height: 1, color: _border),
              const SizedBox(height: 8),
              Row(
                children: [
                  _CountButton(
                    icon: Icons.arrow_upward_rounded,
                    count: post.reactionCount,
                    filled: liked,
                    onTap: onToggleLike,
                  ),
                  const SizedBox(width: 6),
                  _CountButton(
                    icon: Icons.chat_bubble_outline,
                    count: post.commentCount,
                    onTap: onOpen,
                  ),
                  if (onCreateGroup != null) ...[
                    const SizedBox(width: 6),
                    _CountButton(
                      icon: Icons.group_add,
                      label: creatingGroup ? '…' : 'Group',
                      tinted: true,
                      onTap: creatingGroup ? () {} : onCreateGroup!,
                    ),
                  ],
                  const Spacer(),
                  if (showAnswer)
                    Material(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(4),
                      child: InkWell(
                        onTap: onOpen,
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit_note,
                                size: 14,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'ANSWER',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountButton extends StatelessWidget {
  const _CountButton({
    required this.icon,
    required this.onTap,
    this.count,
    this.label,
    this.filled = false,
    this.tinted = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final int? count;
  final String? label;
  final bool filled;
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? Colors.white : (tinted ? _ink : _muted);
    return Material(
      color: filled ? Colors.black : (tinted ? _chip : Colors.white),
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: filled ? Colors.black : _border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 14, color: foreground),
              if (count != null || label != null) ...[
                const SizedBox(width: 4),
                Text(
                  label ?? '$count',
                  style: TextStyle(
                    fontSize: label == null ? 12 : 11,
                    fontWeight: FontWeight.w500,
                    color: foreground,
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
