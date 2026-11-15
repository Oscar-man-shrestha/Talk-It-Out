import 'dart:async';

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
import 'package:talk_it_out/features/discovery/data/discovery_models.dart';
import 'package:talk_it_out/features/discovery/discovery_providers.dart';
import 'package:talk_it_out/features/feed/data/post.dart';
import 'package:talk_it_out/features/feed/data/post_topic.dart';
import 'package:talk_it_out/features/feed/feed_providers.dart';
import 'package:talk_it_out/features/feed/saved_posts.dart';
import 'package:talk_it_out/features/profile/profile_state.dart';
import 'package:talk_it_out/core/ui/brand.dart';
import 'package:talk_it_out/features/discovery/person_profile_screen.dart';
import 'package:talk_it_out/features/discovery/safety_actions.dart';

const _border = Brand.border;
const _ink = Brand.ink;
const _muted = Brand.inkSoft;
const _faint = Brand.inkFaint;
const _chip = Brand.muted;
const _low = Brand.canvas;

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

  /// 0 = For you (ranked), 1 = Latest.
  var _mode = 0;
  Timer? _searchDebounce;
  FeedSearchResult? _searchResult;
  var _searching = false;
  var _searchId = 0;

  @override
  void initState() {
    super.initState();
    // First visit: ask for interests once, like Pinterest.
    ref.listenManual(
      interestsProvider,
      (previous, next) => _maybePromptInterests(),
      fireImmediately: true,
    );
  }

  /// Opens the interest picker for people who never saw it, but only while
  /// the feed itself is on screen (not under "Ask" or a question).
  void _maybePromptInterests() {
    final value = ref.read(interestsProvider).value;
    if (value == null || value.chosen) return;
    if (ref.read(interestPromptShownProvider)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ref.read(interestPromptShownProvider)) return;
      final router = GoRouter.maybeOf(context);
      if (router == null || !(ModalRoute.of(context)?.isCurrent ?? false)) {
        return;
      }
      // Only on the feed itself: never over "Ask", a question, or while a
      // deep link is still loading.
      final path = router.routerDelegate.currentConfiguration.uri.path;
      if (path != '/feed') return;
      ref.read(interestPromptShownProvider.notifier).set();
      router.push('/feed/interests?first=1');
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final q = value.trim();
    setState(() {
      if (q.isEmpty) {
        _searchResult = null;
        _searching = false;
      }
    });
    if (q.isEmpty) return;
    _searchDebounce = Timer(
      const Duration(milliseconds: 250),
      () => _runSearch(q),
    );
  }

  Future<void> _runSearch(String q) async {
    final id = ++_searchId;
    setState(() => _searching = true);
    try {
      final result = await ref.read(discoveryRepositoryProvider).searchPosts(q);
      if (!mounted || id != _searchId) return;
      setState(() {
        _searchResult = result;
        _searching = false;
      });
    } on RepositoryException {
      if (!mounted || id != _searchId) return;
      setState(() => _searching = false);
    }
  }

  void _useCorrection(String text) {
    _search.text = text;
    _search.selection = TextSelection.collapsed(offset: text.length);
    _onSearchChanged(text);
  }

  void _openPost(Post post) {
    // A light signal for For You; never blocks opening the question, and
    // never sent when personalisation is off.
    final personalized =
        ref.read(interestsProvider).value?.personalized ?? true;
    if (!personalized) {
      context.push('/feed/${post.id}');
      return;
    }
    unawaited(
      ref
          .read(discoveryRepositoryProvider)
          .sendSignal(post.id, 'open')
          .catchError((_) {}),
    );
    context.push('/feed/${post.id}');
  }

  Future<void> _notInterested(RankedPost item) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final undo = await ref
          .read(forYouProvider.notifier)
          .notInterested(item.post.id);
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: Brand.ink,
          content: const Text("Got it. You'll see fewer posts like this."),
          action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.white,
            onPressed: undo,
          ),
        ),
      );
    } on RepositoryException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _whyThisPost(RankedPost item, InterestState? interests) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Brand.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Why you're seeing this",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.reason?.text ?? 'New in the community',
                style: const TextStyle(fontSize: 14, color: _ink),
              ),
              const SizedBox(height: 6),
              const Text(
                'For You uses the interests you picked, the questions you like, '
                'answer and open, and what is popular now. It never uses group '
                'or anonymous messages.',
                style: TextStyle(fontSize: 12.5, height: 1.4, color: _muted),
              ),
              if (item.interests.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final id in item.interests)
                      if (interests?.byId(id) case final option?)
                        _InterestChip(
                          option: option,
                          active: interests!.picked.contains(id),
                        ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.visibility_off_outlined),
                title: const Text('Not interested'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _notInterested(item);
                },
              ),
              ListTile(
                key: const ValueKey('why-report'),
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.flag_outlined, color: Colors.red.shade800),
                title: Text(
                  'Report question',
                  style: TextStyle(color: Colors.red.shade800),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  showReportQuestionSheet(context, ref, item.post.id);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.tune),
                title: const Text('Edit your interests'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  context.push('/feed/interests');
                },
              ),
            ],
          ),
        ),
      ),
    );
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
      ref.invalidate(forYouProvider);
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

  var _loadingMore = false;

  Future<void> _loadMore() async {
    final notifier = ref.read(feedProvider.notifier);
    if (_loadingMore || !notifier.hasMore) return;
    setState(() => _loadingMore = true);
    try {
      await notifier.loadMore();
    } on RepositoryException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(feedProvider);
    final forYou = _mode == 0 ? ref.watch(forYouProvider) : null;
    final interests = ref.watch(interestsProvider).value;
    if (interests != null && !interests.chosen) _maybePromptInterests();
    final searchingText = _search.text.trim().isNotEmpty;
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
            color: Brand.accent,
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
        backgroundColor: Brand.accent,
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
        status: forYou != null && !searchingText
            ? asyncStatus(forYou, isEmpty: false)
            : asyncStatus(feed, isEmpty: items.isEmpty && !searchingText),
        errorMessage: errorText((forYou ?? feed).error),
        onRetry: () {
          ref.invalidate(feedProvider);
          ref.invalidate(forYouProvider);
        },
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
          onRefresh: () async {
            ref.invalidate(forYouProvider);
            ref.invalidate(feedProvider);
            await Future.wait([
              ref.read(feedProvider.future),
              if (_mode == 0) ref.read(forYouProvider.future),
            ]);
          },
          child: NotificationListener<ScrollNotification>(
            // Endless scrolling on Latest: fetch older questions before
            // the reader reaches the end.
            onNotification: (n) {
              if (_mode == 1 && n.metrics.extentAfter < 800) _loadMore();
              return false;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 96),
              children: [
                _FeedTabs(
                  mode: _mode,
                  onChanged: (mode) => setState(() => _mode = mode),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _search,
                  key: const ValueKey('feed-search'),
                  onChanged: (value) {
                    setState(() {});
                    _onSearchChanged(value);
                  },
                  style: const TextStyle(fontSize: 13, color: _ink),
                  decoration: InputDecoration(
                    hintText: 'Search questions (typos are fine)',
                    hintStyle: const TextStyle(fontSize: 12, color: _faint),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 19,
                      color: _faint,
                    ),
                    suffixIcon: searchingText
                        ? IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(
                              Icons.close,
                              size: 18,
                              color: _muted,
                            ),
                            onPressed: () {
                              _search.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    border: _fieldBorder(_border),
                    enabledBorder: _fieldBorder(_border),
                    focusedBorder: _fieldBorder(Brand.accent),
                  ),
                ),
                if (searchingText) ...[
                  const SizedBox(height: 10),
                  if (_searching && _searchResult == null)
                    const LinearProgressIndicator(minHeight: 2, color: _ink),
                  if (_searchResult?.didYouMean case final suggestion?)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text.rich(
                        TextSpan(
                          style: const TextStyle(fontSize: 13, color: _muted),
                          children: [
                            const TextSpan(text: 'Showing results for '),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.baseline,
                              baseline: TextBaseline.alphabetic,
                              child: GestureDetector(
                                onTap: () => _useCorrection(suggestion),
                                child: Text(
                                  suggestion,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    fontStyle: FontStyle.italic,
                                    color: _ink,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_searchResult != null && _searchResult!.items.isEmpty)
                    _CaughtUp(
                      title: 'No questions match "${_search.text.trim()}"',
                      body: 'Try other words, or ask it yourself.',
                    ),
                  for (final post
                      in _searchResult?.items ?? const <Post>[]) ...[
                    PostCard(
                      post: post,
                      onOpen: () => _openPost(post),
                      onToggleLike: () => _toggleLike(post),
                      onCreateGroup: post.author.id == userId
                          ? () => _createGroup(post)
                          : null,
                      creatingGroup: _creatingId == post.id,
                      onAuthor: () => openPerson(context, ref, post.author.id),
                    ),
                    const SizedBox(height: 12),
                  ],
                ] else if (_mode == 0) ...[
                  const SizedBox(height: 10),
                  _InterestBar(
                    interests: interests,
                    onEdit: () => interests?.personalized == false
                        ? context.go('/profile')
                        : context.push('/feed/interests'),
                  ),
                  const SizedBox(height: 12),
                  if ((forYou?.value ?? const <RankedPost>[]).isEmpty)
                    const _CaughtUp(
                      title: 'Nothing here yet',
                      body: 'Be the first to ask a question, or check Latest.',
                    ),
                  for (final item in forYou?.value ?? const <RankedPost>[]) ...[
                    _ReasonLine(
                      item: item,
                      onMore: () => _whyThisPost(item, interests),
                    ),
                    PostCard(
                      post: item.post,
                      onOpen: () => _openPost(item.post),
                      onToggleLike: () => _toggleLike(item.post),
                      onCreateGroup: item.post.author.id == userId
                          ? () => _createGroup(item.post)
                          : null,
                      creatingGroup: _creatingId == item.post.id,
                      onAuthor: () =>
                          openPerson(context, ref, item.post.author.id),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if ((forYou?.value ?? const <RankedPost>[]).isNotEmpty)
                    const _CaughtUp(
                      title: "You're all caught up",
                      body: 'Like or answer questions and For You gets better.',
                    ),
                ] else ...[
                  const SizedBox(height: 12),
                  _Hero(
                    openCount: openCount,
                    onAsk: () => context.push('/feed/new'),
                    onRankings: _scrollToBoard,
                  ),
                  const SizedBox(height: 12),
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
                        onOpen: () => _openPost(post),
                        onToggleLike: () => _toggleLike(post),
                        onCreateGroup: post.author.id == userId
                            ? () => _createGroup(post)
                            : null,
                        creatingGroup: _creatingId == post.id,
                        onAuthor: () =>
                            openPerson(context, ref, post.author.id),
                      ),
                      const SizedBox(height: 12),
                    ],
                  if (ref.read(feedProvider.notifier).hasMore)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: _loadingMore
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : OutlinedButton(
                                key: const ValueKey('feed-load-more'),
                                onPressed: _loadMore,
                                child: const Text('Load more questions'),
                              ),
                      ),
                    )
                  else if (visible.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    const _CaughtUp(
                      title: "You're caught up with community consensus!",
                      body: 'Questions on this feed stay attributed to the person who wrote them.',
                    ),
                  ],
                ],
              ],
            ),
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
                    backgroundColor: Brand.accent,
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
                color: Brand.accent,
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
      color: active ? Brand.accent : Colors.white,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: active ? Brand.accent : _border),
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
      color: active ? Brand.accent : Colors.transparent,
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
              color: first ? Brand.accent : Brand.border,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: first ? Brand.accent : _border),
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
    this.onAuthor,
    super.key,
  });

  /// Opens the author's profile.
  final VoidCallback? onAuthor;

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
                  GestureDetector(
                    key: ValueKey('post-author-${post.id}'),
                    onTap: onAuthor,
                    child: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Brand.accent,
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
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: GestureDetector(
                                onTap: onAuthor,
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
                        : AppStrings.commentCount(post.commentCount),
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
                      color: Brand.accent,
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
      color: filled ? Brand.accent : (tinted ? _chip : Colors.white),
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: filled ? Brand.accent : _border),
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

/// Instagram-style text tabs: For you | Latest.
class _FeedTabs extends StatelessWidget {
  const _FeedTabs({required this.mode, required this.onChanged});

  final int mode;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(int index, String label) {
      final active = mode == index;
      return Expanded(
        child: InkWell(
          key: ValueKey('feed-tab-$index'),
          onTap: () => onChanged(index),
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                    color: active ? _ink : _faint,
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 2.5,
                  width: active ? 56 : 0,
                  decoration: BoxDecoration(
                    color: _ink,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(children: [tab(0, 'For you'), tab(1, 'Latest')]),
    );
  }
}

class _InterestChip extends StatelessWidget {
  const _InterestChip({required this.option, this.active = true});

  final InterestOption option;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? Colors.white : _chip,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _border),
      ),
      child: Text(
        '${option.emoji} ${option.label}',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _ink,
        ),
      ),
    );
  }
}

/// The interests For You is built from, with an edit button.
class _InterestBar extends StatelessWidget {
  const _InterestBar({required this.interests, required this.onEdit});

  final InterestState? interests;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final state = interests;
    if (state == null) return const SizedBox(height: 30);
    if (!state.personalized) {
      return Row(
        children: [
          const Icon(Icons.toggle_off_outlined, size: 18, color: _muted),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'Personalisation is off: showing what is popular and new.',
              style: TextStyle(fontSize: 12.5, color: _muted),
            ),
          ),
          TextButton(onPressed: onEdit, child: const Text('Settings')),
        ],
      );
    }
    if (state.picked.isEmpty) {
      return Material(
        color: Brand.accentSoft,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Brand.accentBorder),
            ),
            child: const Row(
              children: [
                Text('✨', style: TextStyle(fontSize: 22)),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Make For You yours',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Pick a few interests and we will put those questions first.',
                        style: TextStyle(fontSize: 12.5, color: _muted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: _muted),
              ],
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final id in state.picked)
            if (state.byId(id) case final option?)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _InterestChip(option: option),
              ),
          ActionChip(
            key: const ValueKey('edit-interests'),
            avatar: const Icon(Icons.tune, size: 15, color: _ink),
            label: const Text('Edit'),
            onPressed: onEdit,
            backgroundColor: Colors.white,
            side: const BorderSide(color: _border),
            shape: const StadiumBorder(),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// "Because you follow Career growth" above a For You post, with a menu.
class _ReasonLine extends StatelessWidget {
  const _ReasonLine({required this.item, required this.onMore});

  final RankedPost item;
  final VoidCallback onMore;

  IconData get _icon => switch (item.reason?.kind) {
    'interest' || 'learned' => Icons.favorite_border,
    'similar' => Icons.auto_awesome_outlined,
    'network' => Icons.groups_2_outlined,
    'popular' => Icons.local_fire_department_outlined,
    'explore' => Icons.explore_outlined,
    'yours' => Icons.check_circle_outline,
    _ => Icons.fiber_new_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Row(
        children: [
          Icon(_icon, size: 14, color: _muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              item.reason?.text ?? 'New in the community',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: _muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            key: ValueKey('post-more-${item.post.id}'),
            tooltip: 'More',
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            icon: const Icon(Icons.more_horiz, color: _muted),
            onPressed: onMore,
          ),
        ],
      ),
    );
  }
}
