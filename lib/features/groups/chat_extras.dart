import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/core/ui/brand.dart';
import 'package:talk_it_out/features/groups/data/group_repository.dart';
import 'package:talk_it_out/features/groups/data/published_message.dart';
import 'package:talk_it_out/features/groups/group_providers.dart';

// ─── Pinned bar ───────────────────────────────────────────────────────────────

/// The latest pinned message, under the agenda. Tap to jump to it.
class PinnedBar extends StatelessWidget {
  const PinnedBar({required this.message, required this.onTap, super.key});

  final PublishedMessage message;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const ValueKey('pinned-bar'),
      onTap: () => onTap(message.id),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Brand.accentSoft,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Brand.accentBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.push_pin, size: 15, color: Brand.accentInk),
            const SizedBox(width: 8),
            const Text(
              '${AppStrings.pinned}: ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Brand.accentInk,
              ),
            ),
            Expanded(
              child: Text(
                message.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Brand.accentInk),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Polls ────────────────────────────────────────────────────────────────────

/// Options with live totals. Tap an option to vote; tap your vote again to
/// take it back. Nobody can see who voted for what.
class PollCard extends ConsumerStatefulWidget {
  const PollCard({
    required this.groupId,
    required this.poll,
    this.onDark = false,
    super.key,
  });

  final String groupId;
  final Poll poll;

  /// Drawn inside your own (dark) bubble.
  final bool onDark;

  @override
  ConsumerState<PollCard> createState() => _PollCardState();
}

class _PollCardState extends ConsumerState<PollCard> {
  var _busy = false;

  Future<void> _vote(int index) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(groupRepositoryProvider)
          .vote(
            widget.groupId,
            widget.poll.id,
            widget.poll.myVote == index ? null : index,
          );
      ref.invalidate(groupMessagesProvider(widget.groupId));
    } on RepositoryException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final poll = widget.poll;
    final ink = widget.onDark ? Colors.white : Brand.ink;
    final soft = widget.onDark ? Brand.accentBorder : Brand.inkSoft;
    final track = widget.onDark
        ? Colors.white.withValues(alpha: 0.18)
        : Brand.muted;
    final fill = widget.onDark
        ? Colors.white.withValues(alpha: 0.42)
        : Brand.accentBorder;
    return Column(
      key: ValueKey('poll-${poll.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < poll.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              key: ValueKey('poll-option-$i'),
              onTap: () => _vote(i),
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: poll.totalVotes == 0
                                ? 0
                                : poll.options[i].votes,
                            child: Container(color: fill),
                          ),
                          Expanded(
                            flex: poll.totalVotes == 0
                                ? 1
                                : poll.totalVotes - poll.options[i].votes,
                            child: Container(color: track),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: poll.myVote == i ? ink : Colors.transparent,
                        width: 1.4,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          poll.myVote == i
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 16,
                          color: ink,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            poll.options[i].text,
                            style: TextStyle(fontSize: 13, color: ink),
                          ),
                        ),
                        Text(
                          '${poll.options[i].votes}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        Text(
          '${AppStrings.voteCount(poll.totalVotes)} · '
          '${AppStrings.pollVotesPrivate}',
          style: TextStyle(fontSize: 11, color: soft),
        ),
      ],
    );
  }
}

/// Controller: write a poll question and 2 to 6 options.
Future<void> showCreatePollDialog(BuildContext context, String groupId) {
  return showDialog<void>(
    context: context,
    builder: (_) => _CreatePollDialog(groupId: groupId),
  );
}

class _CreatePollDialog extends ConsumerStatefulWidget {
  const _CreatePollDialog({required this.groupId});

  final String groupId;

  @override
  ConsumerState<_CreatePollDialog> createState() => _CreatePollDialogState();
}

class _CreatePollDialogState extends ConsumerState<_CreatePollDialog> {
  final _question = TextEditingController();
  final _options = [TextEditingController(), TextEditingController()];
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _question.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _post() async {
    final question = _question.text.trim();
    final options = [
      for (final c in _options)
        if (c.text.trim().isNotEmpty) c.text.trim(),
    ];
    if (question.isEmpty || options.length < 2) {
      setState(() => _error = 'Write a question and at least 2 options.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(groupRepositoryProvider)
          .createPoll(widget.groupId, question: question, options: options);
      ref.invalidate(groupMessagesProvider(widget.groupId));
      if (mounted) Navigator.of(context).pop();
    } on RepositoryException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('create-poll'),
      title: const Text(AppStrings.newPoll),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const ValueKey('poll-question'),
                controller: _question,
                maxLength: 300,
                decoration: const InputDecoration(
                  labelText: AppStrings.pollQuestion,
                ),
              ),
              for (var i = 0; i < _options.length; i++)
                TextField(
                  key: ValueKey('poll-option-field-$i'),
                  controller: _options[i],
                  maxLength: 100,
                  decoration: InputDecoration(
                    labelText: '${AppStrings.pollOption} ${i + 1}',
                  ),
                ),
              if (_options.length < 6)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () =>
                        setState(() => _options.add(TextEditingController())),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text(AppStrings.addOption),
                  ),
                ),
              const Text(
                AppStrings.pollVotesPrivate,
                style: TextStyle(fontSize: 12, color: Brand.inkSoft),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text(AppStrings.cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _post,
          child: const Text(AppStrings.postPoll),
        ),
      ],
    );
  }
}

// ─── Search ───────────────────────────────────────────────────────────────────

/// Searches the group's published messages; returns the tapped message id.
class ChatSearchSheet extends ConsumerStatefulWidget {
  const ChatSearchSheet({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<ChatSearchSheet> createState() => _ChatSearchSheetState();
}

class _ChatSearchSheetState extends ConsumerState<ChatSearchSheet> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<PublishedMessage>? _results;
  String? _error;
  var _busy = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _changed(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _run(value));
  }

  Future<void> _run(String value) async {
    final q = value.trim();
    if (q.length < 2) {
      setState(() {
        _results = null;
        _error = null;
      });
      return;
    }
    setState(() => _busy = true);
    try {
      final items = await ref
          .read(groupRepositoryProvider)
          .searchMessages(widget.groupId, q);
      if (mounted && _query.text.trim() == q) {
        setState(() {
          _results = items;
          _error = null;
        });
      }
    } on RepositoryException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Column(
          children: [
            TextField(
              key: const ValueKey('chat-search-field'),
              controller: _query,
              autofocus: true,
              onChanged: _changed,
              decoration: InputDecoration(
                hintText: AppStrings.searchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _busy
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                filled: true,
                fillColor: Brand.muted,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Brand.inkSoft)),
            if (results != null && results.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  AppStrings.searchNone,
                  style: TextStyle(color: Brand.inkSoft),
                ),
              ),
            if (results != null)
              Expanded(
                child: ListView.separated(
                  itemCount: results.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: Brand.border),
                  itemBuilder: (_, i) {
                    final m = results[i];
                    return ListTile(
                      key: ValueKey('search-result-${m.id}'),
                      onTap: () => Navigator.of(context).pop(m.id),
                      title: Text(
                        m.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5),
                      ),
                      subtitle: Text(
                        m.displaySender?.name ?? AppStrings.anonymousUser,
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Rewrite preview ──────────────────────────────────────────────────────────

/// What the sender chose after previewing.
enum PreviewChoice { send, change }

/// Asks the AI to reword the draft and shows the result, polling until it
/// is ready. Only the sender sees it. Returns [PreviewChoice.send] with the
/// preview id when they send it, or null / change otherwise (the preview is
/// discarded then).
Future<({PreviewChoice choice, String? previewId})?> showRewritePreview(
  BuildContext context, {
  required String groupId,
  required String text,
  required bool anonymous,
}) {
  return showModalBottomSheet<({PreviewChoice choice, String? previewId})>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Brand.card,
    builder: (_) =>
        _PreviewSheet(groupId: groupId, text: text, anonymous: anonymous),
  );
}

class _PreviewSheet extends ConsumerStatefulWidget {
  const _PreviewSheet({
    required this.groupId,
    required this.text,
    required this.anonymous,
  });

  final String groupId;
  final String text;
  final bool anonymous;

  @override
  ConsumerState<_PreviewSheet> createState() => _PreviewSheetState();
}

class _PreviewSheetState extends ConsumerState<_PreviewSheet> {
  String? _previewId;
  RewritePreview? _preview;
  String? _error;
  Timer? _poll;
  var _sent = false;

  GroupRepository get _repo => ref.read(groupRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _poll?.cancel();
    final id = _previewId;
    // Closed without sending: throw the draft preview away.
    if (id != null && !_sent) {
      unawaited(_repo.discardPreview(widget.groupId, id).catchError((_) {}));
    }
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final id = await _repo.requestPreview(
        widget.groupId,
        text: widget.text,
        isAnonymous: widget.anonymous,
      );
      if (!mounted) return;
      _previewId = id;
      _check();
      _poll = Timer.periodic(const Duration(milliseconds: 1500), (_) {
        _check();
      });
    } on RepositoryException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _check() async {
    final id = _previewId;
    if (id == null) return;
    try {
      final p = await _repo.getPreview(widget.groupId, id);
      if (!mounted) return;
      setState(() => _preview = p);
      if (p.ready || p.failed) _poll?.cancel();
    } on RepositoryException catch (e) {
      _poll?.cancel();
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _preview;
    final done = p != null && (p.ready || p.failed);
    return Padding(
      key: const ValueKey('preview-sheet'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, size: 18, color: Brand.ink),
              SizedBox(width: 8),
              Text(
                AppStrings.previewTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Brand.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Brand.accentSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Brand.accentBorder),
            ),
            child: _error != null
                ? Text(_error!, style: const TextStyle(color: Brand.inkSoft))
                : !done
                ? const Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Text(
                        AppStrings.previewWorking,
                        style: TextStyle(color: Brand.accentInk),
                      ),
                    ],
                  )
                : Text(
                    p.failed
                        ? AppStrings.previewFailed
                        : (p.rewrittenText ?? ''),
                    key: const ValueKey('preview-text'),
                    style: const TextStyle(
                      fontSize: 14.5,
                      height: 1.45,
                      color: Brand.accentInk,
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          const Text(
            AppStrings.previewNote,
            style: TextStyle(fontSize: 12, color: Brand.inkSoft),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      Navigator.of(context)
                          .pop((choice: PreviewChoice.change, previewId: null)),
                  child: const Text(AppStrings.previewChange),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('preview-send'),
                  onPressed: done && _error == null
                      ? () {
                          _sent = true;
                          Navigator.of(context).pop((
                            choice: PreviewChoice.send,
                            previewId: _previewId,
                          ));
                        }
                      : null,
                  child: const Text(AppStrings.previewSend),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
