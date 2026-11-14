import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/models/enums.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/core/ui/labels.dart';
import 'package:talk_it_out/core/ui/screen_async.dart';
import 'package:talk_it_out/core/widgets/async_body.dart';
import 'package:talk_it_out/features/groups/group_providers.dart';
import 'package:talk_it_out/features/review/data/raw_message.dart';
import 'package:talk_it_out/features/review/review_providers.dart';
import 'package:talk_it_out/core/ui/brand.dart';
import 'package:talk_it_out/features/groups/chat_image.dart';

// Stitch Monochrome Precision Tokens
const _kPrimary = Brand.accent;
const _kSurface = Brand.card;
const _kSurfaceMuted = Brand.muted;
const _kSurfaceSubtle = Brand.canvas;
const _kBorderSubtle = Brand.border;
const _kBorderStrong = Brand.borderStrong;
const _kBorderHairline = Brand.muted;
const _kTextPrimary = Brand.ink;
const _kTextSecondary = Brand.inkSoft;
const _kError = Color(0xFFBA1A1A);

class ReviewDetailScreen extends ConsumerStatefulWidget {
  const ReviewDetailScreen({
    required this.groupId,
    required this.messageId,
    super.key,
  });

  final String groupId;
  final String messageId;

  @override
  ConsumerState<ReviewDetailScreen> createState() => _ReviewDetailScreenState();
}

class _ReviewDetailScreenState extends ConsumerState<ReviewDetailScreen> {
  Timer? _timer;
  var _busy = false;
  var _diffActive = false;
  String? _error;

  ReviewKey get _key => (groupId: widget.groupId, messageId: widget.messageId);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _refreshPipeline(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _refreshPipeline() {
    final message = ref.read(reviewDetailProvider(_key)).value;
    if (message == null) return;
    final waiting =
        message.pipelineStatus == PipelineStatus.queued ||
        message.pipelineStatus == PipelineStatus.processing;
    if (waiting) ref.invalidate(reviewDetailProvider(_key));
  }

  bool _rewriting(RawMessage message) =>
      message.pipelineStatus == PipelineStatus.queued ||
      message.pipelineStatus == PipelineStatus.processing;

  Future<void> _requestRewrite() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(reviewRepositoryProvider).requestRewrite(widget.messageId);
      ref.invalidate(reviewDetailProvider(_key));
      ref.invalidate(reviewQueueProvider(widget.groupId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.rewriteRequested)),
        );
      }
    } on RepositoryException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = AppStrings.errorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decide({required bool accept}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(reviewRepositoryProvider);
      if (accept) {
        await repo.accept(widget.messageId);
      } else {
        await repo.reject(widget.messageId);
      }
      ref.invalidate(reviewQueueProvider(widget.groupId));
      ref.invalidate(reviewCountsProvider(widget.groupId));
      ref.invalidate(reviewHistoryProvider);
      ref.invalidate(reviewDetailProvider(_key));
      ref.invalidate(groupMessagesProvider(widget.groupId));
      ref.invalidate(myMessagesProvider(widget.groupId));
      ref.invalidate(groupsProvider);
      if (mounted) Navigator.of(context).maybePop();
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
    final detail = ref.watch(reviewDetailProvider(_key));
    final groupAsync = ref.watch(groupDetailProvider(widget.groupId));
    final groupAgenda = groupAsync.value?.agenda ?? 'Group Review';
    final message = detail.value;

    return Scaffold(
      backgroundColor: _kSurface,
      appBar: _ReviewDetailAppBar(
        onNewRewrite:
            message == null ||
                _busy ||
                _rewriting(message) ||
                message.status != MessageStatus.pending
            ? null
            : _requestRewrite,
      ),
      body: AsyncBody(
        status: asyncStatus(detail, isEmpty: false),
        errorMessage: errorText(detail.error),
        onRetry: () => ref.invalidate(reviewDetailProvider(_key)),
        empty: const SizedBox.shrink(),
        child: message == null
            ? const SizedBox.shrink()
            : ReviewDetailBody(
                message: message,
                groupAgenda: groupAgenda,
                busy: _busy,
                diffActive: _diffActive,
                error: _error,
                onToggleDiff: () => setState(() => _diffActive = !_diffActive),
                onAccept: () => _decide(accept: true),
                onReject: () => _decide(accept: false),
              ),
      ),
    );
  }
}

class _ReviewDetailAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _ReviewDetailAppBar({this.onNewRewrite});

  /// Null while a rewrite is already being prepared or a decision is busy.
  final VoidCallback? onNewRewrite;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 900;
    final isMobile = screenWidth < 600;
    final hPad = isDesktop ? (screenWidth - 860) / 2 : (isMobile ? 12.0 : 16.0);

    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: _kSurface,
        border: Border(bottom: BorderSide(color: _kBorderSubtle)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  size: 22,
                  color: _kTextPrimary,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 8),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Brand.accent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(
                  child: Text(
                    'T',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'TALK IT OUT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                      color: _kTextSecondary,
                    ),
                  ),
                  Text(
                    AppStrings.reviewTitle,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.015,
                      color: _kTextPrimary,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              PopupMenuButton<String>(
                key: const ValueKey('review-menu'),
                tooltip: 'More',
                icon: const Icon(
                  Icons.more_vert,
                  size: 20,
                  color: _kTextSecondary,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                onSelected: (_) => onNewRewrite?.call(),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'rewrite',
                    enabled: onNewRewrite != null,
                    child: const Row(
                      children: [
                        Icon(Icons.cached, size: 18),
                        SizedBox(width: 10),
                        Text(AppStrings.newRewrite),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _kSurfaceSubtle,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _kBorderSubtle),
                ),
                child: const Icon(
                  Icons.person_outline,
                  size: 18,
                  color: _kTextPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReviewDetailBody extends StatelessWidget {
  const ReviewDetailBody({
    required this.message,
    required this.groupAgenda,
    required this.busy,
    required this.diffActive,
    required this.onToggleDiff,
    required this.onAccept,
    required this.onReject,
    this.error,
    super.key,
  });

  final RawMessage message;
  final String groupAgenda;
  final bool busy;
  final bool diffActive;
  final VoidCallback onToggleDiff;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 900;
    final isMobile = screenWidth < 600;
    final hPad = isDesktop ? (screenWidth - 860) / 2 : (isMobile ? 12.0 : 20.0);

    return Stack(
      children: [
        Positioned.fill(
          child: ListView(
            padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 120),
            children: [
              // 1. Submission Title Block
              _SubmissionHeader(
                messageId: message.id,
                agenda: groupAgenda,
                status: message.status,
              ),
              const SizedBox(height: 16),

              // 2. Metadata Card
              _MetadataCard(message: message),
              const SizedBox(height: 16),

              // 3. Section Title & Toggle
              _SectionToggleBar(diffActive: diffActive, onToggle: onToggleDiff),
              const SizedBox(height: 12),

              // 4. Card 1: Original Contributor Draft
              _OriginalDraftCard(message: message),
              if (message.attachmentId != null) ...[
                const SizedBox(height: 12),
                _AttachedImageCard(message: message),
              ],
              const SizedBox(height: 16),

              // 5. Card 2: AI Structured Proposal
              _AiProposalCard(message: message, diffActive: diffActive),
              const SizedBox(height: 16),

              if (error != null) ...[
                const SizedBox(height: 16),
                _ErrorBanner(error: error!),
              ],
            ],
          ),
        ),

        // 7. Fixed Bottom Actions Dock
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: message.status == MessageStatus.pending
              ? _FixedActionDock(
                  hPad: hPad,
                  busy: busy,
                  onAccept: onAccept,
                  onReject: onReject,
                )
              : _DecidedDock(hPad: hPad),
        ),
      ],
    );
  }
}

// ─── 1. Header with submission number & pending status ───────────────────────

class _SubmissionHeader extends StatelessWidget {
  const _SubmissionHeader({
    required this.messageId,
    required this.agenda,
    required this.status,
  });

  final String messageId;
  final String agenda;
  final MessageStatus status;

  @override
  Widget build(BuildContext context) {
    final subId = messageId.length > 5
        ? messageId.substring(messageId.length - 4).toUpperCase()
        : messageId.toUpperCase();

    return Container(
      padding: const EdgeInsets.only(bottom: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _kBorderSubtle)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'REVIEW SUBMISSION #$subId',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    letterSpacing: 0.12,
                    fontWeight: FontWeight.w600,
                    color: _kTextSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  agenda,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.02,
                    color: _kTextPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _kBorderStrong, width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: _kPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  status == MessageStatus.pending
                      ? 'PENDING REVIEW'
                      : status == MessageStatus.accepted
                      ? 'ACCEPTED'
                      : 'REJECTED',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.06,
                    color: _kTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 2. Metadata Card ────────────────────────────────────────────────────────

class _MetadataCard extends StatelessWidget {
  const _MetadataCard({required this.message});

  final RawMessage message;

  @override
  Widget build(BuildContext context) {
    // Controllers see the sender even when the message is anonymous.
    final senderLabel = message.senderName;
    final peerNode = message.senderId.length > 3
        ? message.senderId
              .substring(0, min(4, message.senderId.length))
              .toUpperCase()
        : 'NODE';

    final score = message.relevanceScore;
    final relevance = message.relevanceLabel != null
        ? relevanceText(message.relevanceLabel!)
        : 'Not scored yet';
    final scoreText = score == null
        ? relevance
        : '$relevance (${(score * 100).round()}% score)';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kSurfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _kSurface,
              shape: BoxShape.circle,
              border: Border.all(color: _kBorderSubtle),
            ),
            child: Icon(
              message.isAnonymous
                  ? Icons.visibility_off_outlined
                  : Icons.person_outline,
              size: 18,
              color: _kTextSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        senderLabel,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _kTextPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(
                      Icons.verified_user,
                      size: 14,
                      color: _kTextSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Received ${formatWhen(message.createdAt)} • Peer Node #$peerNode',
                  style: const TextStyle(fontSize: 12, color: _kTextSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _kBorderSubtle),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, size: 14, color: _kTextPrimary),
                const SizedBox(width: 4),
                Text(
                  scoreText,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _kTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 3. Section Title Bar & Focus Diff Toggle ────────────────────────────────

class _SectionToggleBar extends StatelessWidget {
  const _SectionToggleBar({required this.diffActive, required this.onToggle});

  final bool diffActive;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'ORIGINAL AND REWRITE',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            letterSpacing: 0.08,
            fontWeight: FontWeight.w600,
            color: _kTextSecondary,
          ),
        ),
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.tune, size: 14, color: _kTextPrimary),
                const SizedBox(width: 5),
                Text(
                  diffActive ? 'Reset View' : 'Focus Differences',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _kTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── 4. Card 1: Original Contributor Draft ───────────────────────────────────

class _OriginalDraftCard extends StatelessWidget {
  const _OriginalDraftCard({required this.message});

  final RawMessage message;

  @override
  Widget build(BuildContext context) {
    final words = message.originalText
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .length;
    final intentScore = message.intentPreservationScore;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.edit_note, size: 17, color: _kTextSecondary),
                  SizedBox(width: 6),
                  Text(
                    'ORIGINAL CONTRIBUTOR DRAFT',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.08,
                      color: _kTextSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _kSurfaceMuted,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _kBorderSubtle),
                ),
                child: Text(
                  '$words words',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: _kTextSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kSurfaceSubtle,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kBorderSubtle),
            ),
            child: Text(
              '“${message.originalText}”',
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                fontStyle: FontStyle.italic,
                color: _kTextPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: _kSurface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _kBorderSubtle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 13,
                      color: _kTextSecondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      message.isAnonymous
                          ? AppStrings.anonymousFlag
                          : 'Sent with name',
                      style: TextStyle(fontSize: 11, color: _kTextSecondary),
                    ),
                  ],
                ),
              ),
              Text(
                intentScore == null
                    ? 'Intent clarity: —'
                    : 'Intent clarity: ${(intentScore * 100).round()}%',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: _kTextSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── 5. Card 2: AI Structured Proposal ───────────────────────────────────────

class _AiProposalCard extends StatelessWidget {
  const _AiProposalCard({required this.message, required this.diffActive});

  final RawMessage message;
  final bool diffActive;

  String get _rewriteText {
    if (message.rewriteUnavailable) return AppStrings.rewriteUnavailable;
    if (message.pipelineStatus == PipelineStatus.queued) {
      return AppStrings.pipelineQueued;
    }
    if (message.pipelineStatus == PipelineStatus.processing) {
      return AppStrings.pipelineProcessing;
    }
    return message.rewrittenText ?? AppStrings.rewriteUnavailable;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kPrimary, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.auto_awesome, size: 18, color: _kPrimary),
                  SizedBox(width: 6),
                  Text(
                    'AI Structured Proposal',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.01,
                      color: _kTextPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _kPrimary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'DISCUSSION READY',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.08,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kSurfaceSubtle,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kBorderSubtle),
            ),
            child: diffActive
                ? _buildHighlightedProposal(_rewriteText)
                : Text(
                    _rewriteText,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      fontWeight: FontWeight.w400,
                      color: _kTextPrimary,
                    ),
                  ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.only(top: 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _kBorderHairline)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.insights, size: 15, color: _kTextSecondary),
                    SizedBox(width: 5),
                    Text(
                      'SYNTHESIS RATIONALE',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                        color: _kTextSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (message.intentPreservationScore != null)
                      _RationalePill(
                        text:
                            'Intent preserved: '
                            '${(message.intentPreservationScore! * 100).round()}%',
                      ),
                    if (message.relevanceLabel != null)
                      _RationalePill(
                        text: relevanceText(message.relevanceLabel!),
                      ),
                    _RationalePill(
                      text: '${_changedWords(_rewriteText)} words changed',
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

  static final _word = RegExp(r"[A-Za-z0-9']+");

  Set<String> get _originalWords => _word
      .allMatches(message.originalText.toLowerCase())
      .map((m) => m[0]!)
      .toSet();

  int _changedWords(String text) {
    final original = _originalWords;
    return _word
        .allMatches(text.toLowerCase())
        .where((m) => !original.contains(m[0]))
        .length;
  }

  /// Highlights the words in the rewrite that are not in the original.
  Widget _buildHighlightedProposal(String text) {
    final original = _originalWords;
    final spans = <TextSpan>[];
    var last = 0;
    for (final match in _word.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start)));
      }
      final changed = !original.contains(match[0]!.toLowerCase());
      spans.add(
        TextSpan(
          text: match[0],
          style: changed
              ? const TextStyle(
                  backgroundColor: _kSurfaceMuted,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationThickness: 1.5,
                  decorationColor: _kPrimary,
                )
              : null,
        ),
      );
      last = match.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 15, height: 1.5, color: _kTextPrimary),
        children: spans,
      ),
    );
  }
}

class _RationalePill extends StatelessWidget {
  const _RationalePill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: _kSurfaceSubtle,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _kBorderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check, size: 13, color: _kTextPrimary),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _kTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 7. Fixed Bottom Action Dock ─────────────────────────────────────────────

/// Shown instead of Accept / Reject once a message is decided.
class _DecidedDock extends StatelessWidget {
  const _DecidedDock({required this.hPad});

  final double hPad;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('decided-dock'),
      padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 18),
      decoration: const BoxDecoration(
        color: _kSurface,
        border: Border(top: BorderSide(color: _kBorderSubtle)),
      ),
      child: const SafeArea(
        top: false,
        child: Row(
          children: [
            Icon(Icons.lock_outline, size: 16, color: _kTextSecondary),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                AppStrings.reviewDecidedNote,
                style: TextStyle(fontSize: 12, color: _kTextSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FixedActionDock extends StatelessWidget {
  const _FixedActionDock({
    required this.hPad,
    required this.busy,
    required this.onAccept,
    required this.onReject,
  });

  final double hPad;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _kSurface,
        border: Border(top: BorderSide(color: _kBorderSubtle)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  // Reject button (Outlined)
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: busy ? null : onReject,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kTextPrimary,
                          backgroundColor: _kSurface,
                          side: const BorderSide(
                            color: _kBorderStrong,
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.close, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Reject Raw',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Accept / Publish button (Solid Black)
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: busy ? null : onAccept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kPrimary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.task_alt, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Publish Rewrite',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFDAD6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kError.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: _kError),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(fontSize: 13, color: _kError),
            ),
          ),
        ],
      ),
    );
  }
}

/// The photo sent with the message. Published with the rewrite on accept,
/// deleted on reject. Hidden photo details were removed on upload.
class _AttachedImageCard extends StatelessWidget {
  const _AttachedImageCard({required this.message});

  final RawMessage message;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('review-image'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Brand.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Brand.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.image_outlined, size: 16, color: Brand.inkSoft),
              SizedBox(width: 6),
              Text(
                'ATTACHED PHOTO',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: Brand.inkSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Published with the rewrite if you accept. Check it does not '
            'show who sent it.',
            style: TextStyle(fontSize: 11.5, color: Brand.inkSoft),
          ),
          const SizedBox(height: 10),
          ChatImage(
            groupId: message.groupId,
            attachmentId: message.attachmentId!,
            maxHeight: 320,
          ),
        ],
      ),
    );
  }
}
