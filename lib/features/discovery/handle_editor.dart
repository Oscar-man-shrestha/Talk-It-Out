import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/ui/brand.dart';
import 'package:talk_it_out/features/discovery/data/discovery_models.dart';

/// The signed-in person's @handle and ideas for one (`API.md` 53).
final handleProvider = FutureProvider<HandleState>(
  (ref) => ref.watch(discoveryRepositoryProvider).getHandle(),
);

Future<void> showHandleEditor(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Brand.canvas,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const HandleEditor(),
  );
}

class HandleEditor extends ConsumerStatefulWidget {
  const HandleEditor({super.key});

  @override
  ConsumerState<HandleEditor> createState() => _HandleEditorState();
}

class _HandleEditorState extends ConsumerState<HandleEditor> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  HandleCheck? _check;
  var _checking = false;
  var _saving = false;
  var _seeded = false;
  var _checkId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final h = value.trim().toLowerCase();
    setState(() {
      _check = null;
      _checking = h.isNotEmpty;
    });
    if (h.isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: 300), () => _run(h));
  }

  Future<void> _run(String h) async {
    final id = ++_checkId;
    try {
      final check = await ref.read(discoveryRepositoryProvider).checkHandle(h);
      if (!mounted || id != _checkId) return;
      setState(() {
        _check = check;
        _checking = false;
      });
    } on RepositoryException {
      if (!mounted || id != _checkId) return;
      setState(() => _checking = false);
    }
  }

  void _use(String handle) {
    _ctrl.text = handle;
    _ctrl.selection = TextSelection.collapsed(offset: handle.length);
    _onChanged(handle);
  }

  Future<void> _save() async {
    final h = _ctrl.text.trim().toLowerCase();
    if (h.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final saved = await ref.read(discoveryRepositoryProvider).setHandle(h);
      ref.invalidate(handleProvider);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: Brand.ink,
          content: Text('You are now @$saved'),
        ),
      );
    } on RepositoryException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      // Taken while typing: show ideas.
      await _run(h);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(handleProvider).value;
    if (state != null && !_seeded) {
      _seeded = true;
      if (state.handle != null) _ctrl.text = state.handle!;
    }
    final typed = _ctrl.text.trim().toLowerCase();
    final current = state?.handle;
    final unchanged = typed.isNotEmpty && typed == current;
    final ok =
        unchanged || (_check?.available ?? false) && _check?.handle == typed;
    final ideas = (_check != null && !_check!.available)
        ? _check!.suggestions
        : (current == null
              ? state?.suggestions ?? const <String>[]
              : const <String>[]);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your @handle',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Brand.ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'People can find and add you by your name or handle. Your email stays private.',
            style: TextStyle(fontSize: 13, height: 1.4, color: Brand.inkSoft),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('handle-field'),
            controller: _ctrl,
            autofocus: true,
            onChanged: _onChanged,
            onSubmitted: (_) => ok ? _save() : null,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9._]')),
              LengthLimitingTextInputFormatter(30),
            ],
            style: const TextStyle(fontSize: 16, color: Brand.ink),
            decoration: InputDecoration(
              prefixText: '@',
              hintText: 'your.handle',
              filled: true,
              fillColor: Colors.white,
              suffixIcon: _checking
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : typed.isEmpty
                  ? null
                  : Icon(
                      ok ? Icons.check_circle : Icons.cancel,
                      color: ok ? Colors.green.shade700 : Colors.red.shade700,
                    ),
              helperText: ok && !unchanged ? 'Available' : null,
              errorText:
                  _check != null &&
                      !_check!.available &&
                      _check!.handle == typed
                  ? _check!.problem
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Brand.border),
              ),
            ),
          ),
          if (ideas.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              current == null && _check == null
                  ? 'Ideas for you'
                  : 'Try one of these',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Brand.inkSoft,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final idea in ideas)
                  ActionChip(
                    label: Text('@$idea'),
                    onPressed: () => _use(idea),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Brand.border),
                    shape: const StadiumBorder(),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('handle-save'),
              onPressed: ok && !unchanged && !_saving ? _save : null,
              style: FilledButton.styleFrom(
                backgroundColor: Brand.ink,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: const StadiumBorder(),
              ),
              child: Text(_saving ? 'Saving…' : 'Save'),
            ),
          ),
        ],
      ),
    );
  }
}
