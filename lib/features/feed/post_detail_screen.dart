import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/core/ui/screen_async.dart';
import 'package:talk_it_out/core/widgets/async_body.dart';
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
                                '• PSYCH SAFETY • POLL SES...',
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
                                  child: const Text(
                                    'SK',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'Sophia K.',
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
                                        '@sophiak • ...',
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
                                  child: const Text(
                                    '#WORKPLACEAI',
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

                            // Post Content (high-fidelity sample matching image4)
                            Text(
                              post.content.length > 50 ? post.content : 'Should AI rewriting be mandatory for executive all-hands Q&A, or strictly opt-in? We tested both in a 200-person team—here are the candid results. When mandatory, 3x more junior engineers submitted concerns, but tone homogenization was noticeable.',
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: _kTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Key Finding Metric Box
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _kSurfaceSubtle,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _kBorderSubtle),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: _kPrimary,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(
                                      Icons.trending_up,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'KEY FINDING CALLOUT',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.6,
                                            color: _kTextSecondary,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          '+210% Psycho...',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: _kTextPrimary,
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
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'HIGH IMPACT',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'monospace',
                                        color: _kTextPrimary,
                                      ),
                                    ),
                                  ),
                                ],
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
                                            post.reactionCount > 0
                                                ? '${post.reactionCount}'
                                                : '142',
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
                                    const Row(
                                      children: [
                                        Icon(
                                          Icons.chat_bubble_outline,
                                          size: 18,
                                          color: _kTextSecondary,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          '38',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.w600,
                                            color: _kTextSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 16),
                                    const Row(
                                      children: [
                                        Icon(
                                          Icons.repeat,
                                          size: 18,
                                          color: _kTextSecondary,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          '12',
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
                                      'ENCRYPTED',
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

                      // Controller Action Banner (matches image4)
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                      '+4 peers ready',
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
                                    '38',
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
                              _buildSortMenuItem(
                                'TOP FIRST',
                                'Top First (Agreed)',
                              ),
                              _buildSortMenuItem('NEWEST', 'Newest First'),
                              _buildSortMenuItem(
                                'MOST DISCUSSED',
                                'Most Discussed',
                              ),
                              _buildSortMenuItem(
                                'SHIELDED ONLY',
                                'Shielded Only',
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
                      if (_sortMode == 'SHIELDED ONLY') ...[
                        const _DiscussionItem(
                          isAnonymous: true,
                          authorName: 'Anonymous Pers...',
                          isShielded: true,
                          timeAgo: '25m ago',
                          content: 'We noticed executive pushback if the AI rewrite sounds too diplomatic—they felt questions were sanitized. We ended up keeping the original bulleted concerns intact and only softening the rhetorical edge.',
                          likesCount: '9',
                        ),
                      ] else if (_sortMode == 'NEWEST') ...[
                        for (final comment in liveComments.reversed) ...[
                          _DiscussionItem(
                            authorInitials: comment.author.name.isNotEmpty
                                ? comment.author.name[0].toUpperCase()
                                : '?',
                            authorName: comment.author.name,
                            timeAgo: 'just now',
                            content: comment.content,
                            likesCount: '0',
                          ),
                          const SizedBox(height: 8),
                        ],
                        const _DiscussionItem(
                          isAnonymous: true,
                          authorName: 'Anonymous Pers...',
                          isShielded: true,
                          timeAgo: '25m ago',
                          content: 'We noticed executive pushback if the AI rewrite sounds too diplomatic—they felt questions were sanitized. We ended up keeping the original bulleted concerns intact and only softening the rhetorical edge.',
                          likesCount: '9',
                        ),
                        const SizedBox(height: 8),
                        const Padding(
                          padding: EdgeInsets.only(left: 24),
                          child: _DiscussionItem(
                            authorInitials: 'SK',
                            authorName: 'Sophia K.',
                            isAuthor: true,
                            timeAgo: '45m ago',
                            content: "Exactly. The key is making sure the AI rewrite preserves nuance. If it strips the core tension or urgency, leadership assumes it's low priority.",
                            likesCount: '18',
                          ),
                        ),
                        const SizedBox(height: 8),
                        const _DiscussionItem(
                          authorInitials: 'M',
                          authorName: 'M',
                          timeAgo: '1h ago',
                          badgeText: 'Rewritten: Gentle Tone',
                          badgeIcon: Icons.auto_awesome,
                          content: "Completely agree on psychological safety unlocking participation. When folks aren't paralyzed about how their critique lands, we get the real production blockers surfaced immediately.",
                          likesCount: '24',
                        ),
                      ] else ...[
                        const _DiscussionItem(
                          authorInitials: 'M',
                          authorName: 'M',
                          timeAgo: '1h ago',
                          badgeText: 'Rewritten: Gentle Tone',
                          badgeIcon: Icons.auto_awesome,
                          content: "Completely agree on psychological safety unlocking participation. When folks aren't paralyzed about how their critique lands, we get the real production blockers surfaced immediately.",
                          likesCount: '24',
                        ),
                        const SizedBox(height: 8),
                        const Padding(
                          padding: EdgeInsets.only(left: 24),
                          child: _DiscussionItem(
                            authorInitials: 'SK',
                            authorName: 'Sophia K.',
                            isAuthor: true,
                            timeAgo: '45m ago',
                            content: "Exactly. The key is making sure the AI rewrite preserves nuance. If it strips the core tension or urgency, leadership assumes it's low priority.",
                            likesCount: '18',
                          ),
                        ),
                        const SizedBox(height: 8),
                        const _DiscussionItem(
                          isAnonymous: true,
                          authorName: 'Anonymous Pers...',
                          isShielded: true,
                          timeAgo: '25m ago',
                          content: 'We noticed executive pushback if the AI rewrite sounds too diplomatic—they felt questions were sanitized. We ended up keeping the original bulleted concerns intact and only softening the rhetorical edge.',
                          likesCount: '9',
                        ),
                        const SizedBox(height: 8),
                        for (final comment in liveComments) ...[
                          _DiscussionItem(
                            authorInitials: comment.author.name.isNotEmpty
                                ? comment.author.name[0].toUpperCase()
                                : '?',
                            authorName: comment.author.name,
                            timeAgo: 'just now',
                            content: comment.content,
                            likesCount: '0',
                          ),
                          const SizedBox(height: 8),
                        ],
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
                                      'AI Rewrite: Active',
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
    this.badgeText,
    this.badgeIcon,
    this.isAuthor = false,
    this.isAnonymous = false,
    this.isShielded = false,
  });

  final String? authorInitials;
  final String authorName;
  final String timeAgo;
  final String? badgeText;
  final IconData? badgeIcon;
  final bool isAuthor;
  final bool isAnonymous;
  final bool isShielded;
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
              if (isAnonymous)
                Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: _kPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.security,
                    size: 14,
                    color: Colors.white,
                  ),
                )
              else
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
              if (isShielded) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: _kSurfaceMuted,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text(
                    'Shielded',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: _kTextSecondary,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              Text(
                '• $timeAgo',
                style: const TextStyle(fontSize: 11, color: _kTextTertiary),
              ),
              const Spacer(),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _kSurfaceMuted,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (badgeIcon != null) ...[
                        Icon(badgeIcon, size: 10, color: _kTextSecondary),
                        const SizedBox(width: 3),
                      ],
                      Text(
                        badgeText!,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: _kTextSecondary,
                        ),
                      ),
                    ],
                  ),
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
                  onSelected: (val) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          val == 'copy'
                              ? 'Comment copied to clipboard'
                              : 'Feedback logged securely',
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
                      value: 'tone',
                      height: 34,
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 14,
                            color: _kTextSecondary,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Inspect Tone Stack',
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
