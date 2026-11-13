import 'package:flutter/material.dart';
import 'package:talk_it_out/features/feed/data/post_topic.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/core/ui/screen_async.dart';
import 'package:talk_it_out/core/utils/relative_time.dart';
import 'package:talk_it_out/core/widgets/async_body.dart';
import 'package:talk_it_out/features/auth/session_controller.dart';
import 'package:talk_it_out/features/feed/data/comment.dart';
import 'package:talk_it_out/features/feed/feed_providers.dart';

// Stitch Monochrome Precision tokens
const _kPrimary = Color(0xFF09090B);
const _kSurface = Color(0xFFFFFFFF);
const _kSurfaceMuted = Color(0xFFF4F4F5);
const _kSurfaceSubtle = Color(0xFFFAFAFA);
const _kBorderSubtle = Color(0xFFE4E4E7);
const _kTextPrimary = Color(0xFF09090B);
const _kTextSecondary = Color(0xFF71717A);
const _kTextTertiary = Color(0xFFA1A1AA);

class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({required this.postId, super.key});

  final String postId;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _comment = TextEditingController();
  var _busy = false;
  var _isBookmarked = false;
  var _postPublicly = true;
  String? _error;
  String _sortMode = 'TOP FIRST';

  PopupMenuItem<String> _buildSortMenuItem(String value, String label) {
    final isSelected = _sortMode == value;
    return PopupMenuItem<String>(
      value: value,
      height: 38,
      child: Row(
        children: [
          Icon(
            isSelected ? Icons.check : Icons.circle_outlined,
            size: 14,
            color: isSelected ? _kTextPrimary : Colors.transparent,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: _kTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  /// Comments come oldest-first from the API.
  List<Comment> _sorted(List<Comment> items) {
    return _sortMode == 'NEWEST' ? items.reversed.toList() : items;
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _addComment() async {
    if (_comment.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(feedRepositoryProvider)
          .addComment(widget.postId, content: _comment.text);
      _comment.clear();
      ref.invalidate(commentsProvider(widget.postId));
      ref.invalidate(postDetailProvider(widget.postId));
      ref.invalidate(feedProvider);
    } on RepositoryException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = AppStrings.errorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createGroup() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final group = await ref
          .read(feedRepositoryProvider)
          .createGroupFromPost(widget.postId);
      if (mounted) context.go('/groups/${group.id}');
    } on RepositoryException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = AppStrings.errorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final postState = ref.watch(postDetailProvider(widget.postId));
    final comments = ref.watch(commentsProvider(widget.postId));
    final post = postState.value;
    final liveComments = comments.value ?? const <Comment>[];
    final userId = ref.watch(sessionProvider).value?.id;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final hPad = screenWidth > 860 ? (screenWidth - 800) / 2 : 16.0;

    return Scaffold(
      backgroundColor: _kSurface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          decoration: const BoxDecoration(
            color: _kSurface,
            border: Border(bottom: BorderSide(color: _kBorderSubtle)),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 18,
                      color: _kTextPrimary,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 4),
                  const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TALK IT OUT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: _kTextSecondary,
                        ),
                      ),
                      Text(
                        'Talk It Out Post Detail',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: _kTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.more_vert,
                      size: 20,
                      color: _kTextSecondary,
                    ),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: AsyncBody(
        status: asyncStatus(postState, isEmpty: false),
        errorMessage: errorText(postState.error),
        onRetry: () => ref.invalidate(postDetailProvider(widget.postId)),
        empty: const SizedBox.shrink(),
        child: post == null
            ? const SizedBox.shrink()
            : Stack(
                children: [
                  ListView(
                    padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 120),
                    children: [
                      // Sub-header context row (matches image4)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _kSurfaceSubtle,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _kBorderSubtle),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: _kPrimary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                '• PUBLIC FEED',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                  color: _kTextSecondary,
                                ),
                              ),
                            ),
                            IconButton(
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              padding: EdgeInsets.zero,
                              icon: Icon(
                                _isBookmarked
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                                size: 18,
                                color: _isBookmarked
                                    ? _kPrimary
                                    : _kTextSecondary,
                              ),
                              onPressed: () => setState(
                                () => _isBookmarked = !_isBookmarked,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              padding: EdgeInsets.zero,
                              icon: const Icon(
                                Icons.share_outlined,
                                size: 18,
                                color: _kTextSecondary,
                              ),
                              onPressed: () {},
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Main Original Post Card (matches image4)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _kSurface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _kBorderSubtle),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x06000000),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Author Row
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: const BoxDecoration(
                                    color: _kPrimary,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    _initials(post.author.name),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            post.author.name,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: _kTextPrimary,
                                            ),
                                          ),
                                          SizedBox(width: 4),
                                          Icon(
                                            Icons.verified,
                                            size: 15,
                                            color: _kPrimary,
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 1),
                                      Text(
                                        relativeTime(post.createdAt),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: _kTextSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _kSurfaceMuted,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    post.nsfwFlag
                                        ? AppStrings.flagged.toUpperCase()
                                        : 'PUBLIC',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                      color: _kTextSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            if (PostTopic.byId(post.topic)
                                case final topic?) ...[
                              Row(
                                children: [
                                  Icon(
                                    topic.icon,
                                    size: 14,
                                    color: _kTextSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    topic.label,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _kTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                            ],
                            if (post.title != null) ...[
                              Text(
                                post.title!,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                  color: _kTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            Text(
                              post.content,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: _kTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Reaction & Encryption Bar
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    InkWell(
                                      onTap: () async {
                                        final repo = ref.read(
                                          feedRepositoryProvider,
                                        );
                                        try {
                                          if (post.myReaction == null) {
                                            await repo.addReaction(
                                              post.id,
                                              type: 'like',
                                            );
                                          } else {
                                            await repo.removeReaction(post.id);
                                          }
                                          ref.invalidate(
                                            postDetailProvider(widget.postId),
                                          );
                                          ref.invalidate(feedProvider);
                                        } on RepositoryException catch (error) {
                                          if (mounted) {
                                            setState(
                                              () => _error = error.message,
                                            );
                                          }
                                        }
                                      },
                                      child: Row(
                                        children: [
                                          Icon(
                                            post.myReaction != null
                                                ? Icons.favorite
                                                : Icons.favorite_border,
                                            size: 18,
                                            color: post.myReaction != null
                                                ? const Color(0xFFBA1A1A)
                                                : _kTextSecondary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${post.reactionCount}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontFamily: 'monospace',
                                              fontWeight: FontWeight.w600,
                                              color: _kTextSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.chat_bubble_outline,
                                          size: 18,
                                          color: _kTextSecondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${post.commentCount}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.w600,
                                            color: _kTextSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.lock_outline,
                                      size: 14,
                                      color: _kTextTertiary,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'PUBLIC',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.6,
                                        color: _kTextTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Create-group banner: offered to the post author only.
                      if (post.author.id == userId)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _kSurfaceSubtle,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _kBorderSubtle),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.hub_outlined,
                                        size: 18,
                                        color: _kPrimary,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Launch Group from this Topic',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: _kTextPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _kPrimary,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'CONTROLLER MODE',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'monospace',
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Spin up an anonymous real-time room to draft formal Q&A policy guidelines with team leads.',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: _kTextSecondary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 22,
                                        height: 22,
                                        decoration: const BoxDecoration(
                                          color: _kSurfaceMuted,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.person,
                                          size: 13,
                                          color: _kTextSecondary,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'You become the controller',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: _kTextSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  FilledButton(
                                    onPressed: _busy ? null : _createGroup,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: _kPrimary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Create Group',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        SizedBox(width: 4),
                                        Icon(Icons.arrow_forward, size: 14),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Discussion Section Header (matches image4)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Discussion',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                  color: _kTextPrimary,
                                ),
                              ),
                              SizedBox(width: 6),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: _kSurfaceMuted,
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(999),
                                  ),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1.5,
                                  ),
                                  child: Text(
                                    '${liveComments.length}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w600,
                                      color: _kTextSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Sort discussion thread',
                            offset: const Offset(0, 24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(color: _kBorderSubtle),
                            ),
                            color: _kSurface,
                            elevation: 4,
                            initialValue: _sortMode,
                            onSelected: (val) {
                              setState(() => _sortMode = val);
                            },
                            itemBuilder: (ctx) => [
                              _buildSortMenuItem('TOP FIRST', 'Oldest First'),
                              _buildSortMenuItem('NEWEST', 'Newest First'),
                              _buildSortMenuItem(
                                'MOST DISCUSSED',
                                'Most Discussed',
                              ),
                            ],
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _kSurfaceMuted,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: _kBorderSubtle),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _sortMode,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                      color: _kTextPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.expand_more,
                                    size: 15,
                                    color: _kTextSecondary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Rich 3-tier Discussion Thread (dynamically sorted & filtered)
                      if (comments.isLoading && !comments.hasValue)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else if (comments.hasError && !comments.hasValue)
                        Center(
                          child: TextButton(
                            onPressed: () =>
                                ref.invalidate(commentsProvider(widget.postId)),
                            child: Text(
                              '${errorText(comments.error)} ${AppStrings.retry}',
                            ),
                          ),
                        )
                      else if (liveComments.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: Text(
                              AppStrings.commentsEmpty,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: _kTextSecondary,
                              ),
                            ),
                          ),
                        ),
                      for (final comment in _sorted(liveComments)) ...[
                        _DiscussionItem(
                          authorInitials: _initials(comment.author.name),
                          authorName: comment.author.name,
                          isAuthor: comment.author.id == post.author.id,
                          timeAgo: relativeTime(comment.createdAt),
                          content: comment.content,
                          likesCount: '',
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),

                  // Bottom Floating Comment Composer (matches image4)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 14),
                      decoration: BoxDecoration(
                        color: _kSurface,
                        border: const Border(
                          top: BorderSide(color: _kBorderSubtle),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x10000000),
                            blurRadius: 10,
                            offset: Offset(0, -3),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        top: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Status Toggles Bar
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                GestureDetector(
                                  onTap: () => setState(
                                    () => _postPublicly = !_postPublicly,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 18,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          color: _postPublicly
                                              ? _kPrimary
                                              : _kBorderSubtle,
                                        ),
                                        padding: const EdgeInsets.all(2),
                                        alignment: _postPublicly
                                            ? Alignment.centerRight
                                            : Alignment.centerLeft,
                                        child: Container(
                                          width: 14,
                                          height: 14,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Post Publicly',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _kTextPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    Container(
                                      width: 5,
                                      height: 5,
                                      decoration: const BoxDecoration(
                                        color: _kPrimary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    const Text(
                                      'Shown as written',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.w600,
                                        color: _kTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Input Surface
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _kSurfaceMuted,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _comment,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: _kTextPrimary,
                                      ),
                                      decoration: const InputDecoration(
                                        hintText: 'Add to candid discussion...',
                                        hintStyle: TextStyle(
                                          fontSize: 13,
                                          color: _kTextTertiary,
                                        ),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 8,
                                        ),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: FilledButton(
                                      onPressed: _busy ? null : _addComment,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: _kPrimary,
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                      ),
                                      child: _busy
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.arrow_upward,
                                              size: 16,
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _error!,
                                style: const TextStyle(
                                  color: Color(0xFFBA1A1A),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _DiscussionItem extends StatelessWidget {
  const _DiscussionItem({
    required this.authorName,
    required this.timeAgo,
    required this.content,
    required this.likesCount,
    this.authorInitials,
    this.isAuthor = false,
  });

  final String? authorInitials;
  final String authorName;
  final String timeAgo;
  final bool isAuthor;
  final String content;
  final String likesCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: _kPrimary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  authorInitials ?? '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                authorName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _kTextPrimary,
                ),
              ),
              if (isAuthor) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: _kPrimary,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text(
                    'Author',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              Text(
                '• $timeAgo',
                style: const TextStyle(fontSize: 11, color: _kTextTertiary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 34),
            child: Text(
              content,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: _kTextPrimary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 34),
            child: Row(
              children: [
                if (likesCount.isNotEmpty) ...[
                  const Icon(
                    Icons.favorite_border,
                    size: 14,
                    color: _kTextSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    likesCount,
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: _kTextSecondary,
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Replying to $authorName...'),
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text(
                    'Reply',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _kTextSecondary,
                    ),
                  ),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  tooltip: 'Comment actions',
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.more_horiz,
                    size: 16,
                    color: _kTextTertiary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: _kBorderSubtle),
                  ),
                  color: _kSurface,
                  elevation: 3,
                  onSelected: (val) async {
                    if (val == 'copy') {
                      await Clipboard.setData(ClipboardData(text: content));
                    }
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          val == 'copy'
                              ? 'Comment copied to clipboard'
                              : 'Reporting is not available yet.',
                        ),
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(
                      value: 'copy',
                      height: 34,
                      child: Row(
                        children: [
                          Icon(Icons.copy, size: 14, color: _kTextSecondary),
                          SizedBox(width: 8),
                          Text(
                            'Copy Text',
                            style: TextStyle(
                              fontSize: 12,
                              color: _kTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'report',
                      height: 34,
                      child: Row(
                        children: [
                          Icon(
                            Icons.flag_outlined,
                            size: 14,
                            color: _kTextSecondary,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Flag for Moderator',
                            style: TextStyle(
                              fontSize: 12,
                              color: _kTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
