import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:talk_it_out/core/ui/brand.dart';

/// The invite code inside a pasted link or code, or null.
/// Accepts `https://…/#/join/abcd2345ef`, `talkitout://app/join/…` or the
/// bare 10-character code.
String? inviteCodeFrom(String input) {
  final text = input.trim().toLowerCase();
  final inLink = RegExp(r'join/([a-z2-9]{10})(?![a-z0-9])').firstMatch(text);
  if (inLink != null) return inLink.group(1);
  if (RegExp(r'^[a-z2-9]{10}$').hasMatch(text)) return text;
  return null;
}

/// "Join with an invite link": paste a link someone sent you.
Future<void> showJoinWithLinkDialog(BuildContext context) async {
  final code = await showDialog<String>(
    context: context,
    builder: (_) => const _JoinLinkDialog(),
  );
  if (code != null && context.mounted) context.push('/join/$code');
}

/// Owns its text field, so the field is only cleaned up once the dialog
/// has finished closing.
class _JoinLinkDialog extends StatefulWidget {
  const _JoinLinkDialog();

  @override
  State<_JoinLinkDialog> createState() => _JoinLinkDialogState();
}

class _JoinLinkDialogState extends State<_JoinLinkDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final found = inviteCodeFrom(_controller.text);
    if (found == null) {
      setState(
        () => _error = 'That does not look like a Talk It Out invite link.',
      );
      return;
    }
    Navigator.of(context).pop(found);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Join with an invite link'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Paste the link a group controller sent you.',
            style: TextStyle(fontSize: 13, color: Brand.inkSoft),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('join-link-field'),
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'https://…/join/…',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('join-link-go'),
          style: FilledButton.styleFrom(backgroundColor: Brand.ink),
          onPressed: _submit,
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
