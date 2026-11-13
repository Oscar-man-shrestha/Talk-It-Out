import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/core/ui/stitch_chrome.dart';
import 'package:talk_it_out/features/feed/data/post_topic.dart';
import 'package:talk_it_out/features/feed/feed_providers.dart';

const _ink = Color(0xFF09090B);
const _muted = Color(0xFF71717A);
const _faint = Color(0xFFA1A1AA);
const _border = Color(0xFFE4E4E7);
const _soft = Color(0xFFF4F4F5);
const _error = Color(0xFFBA1A1A);

/// Limits match the API (`API.md` 42 and endpoint 17).
const titleMax = 150;
const detailsMax = 5000;
const _titleMin = 8;

/// Ask a question in the public feed: title, topic and details.
class NewPostScreen extends ConsumerStatefulWidget {
  const NewPostScreen({super.key});

  @override
  ConsumerState<NewPostScreen> createState() => _NewPostScreenState();
}

class _NewPostScreenState extends ConsumerState<NewPostScreen> {
  final _title = TextEditingController();
  final _details = TextEditingController();
  final _detailsFocus = FocusNode();
  String? _topic;
  var _busy = false;
  var _triedSubmit = false;
  String? _serverError;

  @override
  void initState() {
    super.initState();
    _title.addListener(_changed);
    _details.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _title.dispose();
    _details.dispose();
    _detailsFocus.dispose();
    super.dispose();
  }

  String get _titleText => _title.text.trim();
  String get _detailsText => _details.text.trim();
  bool get _hasDraft => _titleText.isNotEmpty || _detailsText.isNotEmpty;

  String? get _titleError {
    if (_titleText.isEmpty) return AppStrings.askTitleRequired;
    if (_titleText.length < _titleMin) return AppStrings.askTitleTooShort;
    if (_titleText.length > titleMax) return AppStrings.askTitleTooLong;
    return null;
  }

  String? get _topicError =>
      _topic == null ? AppStrings.askTopicRequired : null;

  String? get _detailsError {
    if (_detailsText.isEmpty) return AppStrings.askDetailsRequired;
    if (_detailsText.length > detailsMax) return AppStrings.askDetailsTooLong;
    return null;
  }

  bool get _valid =>
      _titleError == null && _topicError == null && _detailsError == null;

  Future<void> _submit() async {
    setState(() {
      _triedSubmit = true;
      _serverError = null;
    });
    if (!_valid) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(feedRepositoryProvider)
          .createPost(title: _titleText, topic: _topic, content: _detailsText);
      ref.invalidate(feedProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text(AppStrings.askPosted)));
      context.pop();
    } on RepositoryException catch (error) {
      if (mounted) setState(() => _serverError = error.message);
    } catch (_) {
      if (mounted) setState(() => _serverError = AppStrings.errorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_hasDraft || _busy) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.askDiscardTitle),
        content: const Text(AppStrings.askDiscardBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(AppStrings.askKeepEditing),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.black),
            child: const Text(AppStrings.askDiscard),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final hPad = screenWidth > 860 ? (screenWidth - 800) / 2 : 16.0;

    return PopScope(
      canPop: !_hasDraft || _busy,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) context.pop();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: StitchPageHeader(
          title: AppStrings.askTitle,
          leading: BackButton(
            onPressed: () async {
              if (await _confirmDiscard() && context.mounted) context.pop();
            },
          ),
        ),
        body: ListView(
          padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 40),
          children: [
            const _Notice(),
            const SizedBox(height: 20),
            _Label(
              AppStrings.askTitleLabel,
              counter: '${_titleText.length}/$titleMax',
              over: _titleText.length > titleMax,
            ),
            _Box(
              error: _triedSubmit ? _titleError : null,
              child: TextField(
                key: const ValueKey('ask-title'),
                controller: _title,
                enabled: !_busy,
                maxLength: titleMax,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                buildCounter: (
                  _, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) => null,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _detailsFocus.requestFocus(),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
                decoration: _inputDecoration(AppStrings.askTitleHint),
              ),
            ),
            const SizedBox(height: 18),
            const _Label(AppStrings.askTopicLabel),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final topic in PostTopic.all)
                  ChoiceChip(
                    key: ValueKey('ask-topic-${topic.id}'),
                    avatar: Icon(
                      topic.icon,
                      size: 16,
                      color: _topic == topic.id ? Colors.white : _muted,
                    ),
                    label: Text(topic.label),
                    selected: _topic == topic.id,
                    showCheckmark: false,
                    color: WidgetStatePropertyAll(
                      _topic == topic.id ? Colors.black : Colors.white,
                    ),
                    side: BorderSide(
                      color: _topic == topic.id ? Colors.black : _border,
                    ),
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _topic == topic.id ? Colors.white : _ink,
                    ),
                    onSelected: _busy
                        ? null
                        : (_) => setState(() => _topic = topic.id),
                  ),
              ],
            ),
            if (_triedSubmit && _topicError != null) _ErrorLine(_topicError!),
            const SizedBox(height: 18),
            _Label(
              AppStrings.askDetailsLabel,
              counter: '${_detailsText.length}/$detailsMax',
              over: _detailsText.length > detailsMax,
            ),
            _Box(
              error: _triedSubmit ? _detailsError : null,
              child: TextField(
                key: const ValueKey('ask-details'),
                controller: _details,
                focusNode: _detailsFocus,
                enabled: !_busy,
                minLines: 6,
                maxLines: 14,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 14, height: 1.45, color: _ink),
                decoration: _inputDecoration(AppStrings.askDetailsHint),
              ),
            ),
            const SizedBox(height: 14),
            const _Tips(),
            if (_serverError != null) ...[
              const SizedBox(height: 14),
              _ErrorLine(_serverError!),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                key: const ValueKey('ask-submit'),
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _faint,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.arrow_upward_rounded, size: 18),
                label: const Text(
                  AppStrings.askSubmit,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(color: _faint, fontWeight: FontWeight.w400),
  border: InputBorder.none,
  enabledBorder: InputBorder.none,
  focusedBorder: InputBorder.none,
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  isDense: true,
);

class _Notice extends StatelessWidget {
  const _Notice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.visibility_outlined, size: 18, color: _ink),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              AppStrings.askPublicNotice,
              style: TextStyle(fontSize: 12.5, height: 1.45, color: _ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tips extends StatelessWidget {
  const _Tips();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            AppStrings.askTipsTitle,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          for (final tip in AppStrings.askTips)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(Icons.circle, size: 4, color: _muted),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tip,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: _muted,
                      ),
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

class _Label extends StatelessWidget {
  const _Label(this.text, {this.counter, this.over = false});

  final String text;
  final String? counter;
  final bool over;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
          ),
          if (counter != null)
            Text(
              counter!,
              style: TextStyle(
                fontSize: 11.5,
                fontFamily: 'monospace',
                color: over ? _error : _faint,
              ),
            ),
        ],
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.child, this.error});

  final Widget child;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: error == null ? _border : _error),
          ),
          child: child,
        ),
        if (error != null) _ErrorLine(error!),
      ],
    );
  }
}

class _ErrorLine extends StatelessWidget {
  const _ErrorLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: _error,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
