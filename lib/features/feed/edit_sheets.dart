import 'package:flutter/material.dart';
import 'package:talk_it_out/core/ui/brand.dart';
import 'package:talk_it_out/features/feed/data/post.dart';

/// Edits one piece of text (an answer). Returns the new text, or null.
Future<String?> showEditTextSheet(
  BuildContext context, {
  required String title,
  required String initial,
  int maxLength = 2000,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Brand.canvas,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _EditSheet(
      title: title,
      fields: [_Field('Text', initial, maxLength, 6)],
      onSave: (values) => values[0],
    ),
  );
}

typedef QuestionEdit = ({String title, String content});

/// Edits a question's title and details. Returns the edit, or null.
Future<QuestionEdit?> showEditQuestionSheet(BuildContext context, Post post) {
  return showModalBottomSheet<QuestionEdit>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Brand.canvas,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _EditSheet(
      title: 'Edit your question',
      fields: [
        _Field('Question', post.title ?? '', 150, 2),
        _Field('Details', post.content, 5000, 6),
      ],
      onSave: (values) => (title: values[0], content: values[1]),
    ),
  );
}

class _Field {
  const _Field(this.label, this.initial, this.maxLength, this.lines);

  final String label;
  final String initial;
  final int maxLength;
  final int lines;
}

class _EditSheet<T> extends StatefulWidget {
  const _EditSheet({
    required this.title,
    required this.fields,
    required this.onSave,
  });

  final String title;
  final List<_Field> fields;
  final T Function(List<String> values) onSave;

  @override
  State<_EditSheet<T>> createState() => _EditSheetState<T>();
}

class _EditSheetState<T> extends State<_EditSheet<T>> {
  late final _controllers = [
    for (final f in widget.fields) TextEditingController(text: f.initial),
  ];
  String? _error;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final values = [for (final c in _controllers) c.text.trim()];
    // The last field (the body) is required.
    if (values.last.isEmpty) {
      setState(() => _error = 'This cannot be empty.');
      return;
    }
    Navigator.of(context).pop(widget.onSave(values));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Brand.ink,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Edits are marked as edited so readers know it changed.',
                style: TextStyle(fontSize: 12.5, color: Brand.inkSoft),
              ),
              const SizedBox(height: 14),
              for (final (i, f) in widget.fields.indexed) ...[
                TextField(
                  key: ValueKey('edit-field-$i'),
                  controller: _controllers[i],
                  maxLength: f.maxLength,
                  minLines: f.lines,
                  maxLines: f.lines + 4,
                  autofocus: i == widget.fields.length - 1,
                  decoration: InputDecoration(
                    labelText: f.label,
                    border: const OutlineInputBorder(),
                    errorText: i == widget.fields.length - 1 ? _error : null,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('edit-save'),
                      onPressed: _save,
                      style: FilledButton.styleFrom(backgroundColor: Brand.ink),
                      child: const Text('Save'),
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
