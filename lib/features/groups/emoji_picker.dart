import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:talk_it_out/core/ui/brand.dart';
import 'package:talk_it_out/features/groups/emoji_data.dart';

/// Recently used emoji, newest first, kept on this device.
class RecentEmoji {
  RecentEmoji._();

  static const _key = 'recent_emoji';
  static const _max = 24;
  static final List<String> _items = [];
  static var _loaded = false;

  static List<String> get items => List.unmodifiable(_items);

  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final raw = await const FlutterSecureStorage().read(key: _key);
      if (raw == null) return;
      final list = (jsonDecode(raw) as List).whereType<String>();
      for (final e in list) {
        if (!_items.contains(e)) _items.add(e);
      }
    } catch (_) {
      // No storage (tests, private mode): recents stay for this session.
    }
  }

  static void use(String emoji) {
    _items
      ..remove(emoji)
      ..insert(0, emoji);
    if (_items.length > _max) _items.removeRange(_max, _items.length);
    unawaited(
      const FlutterSecureStorage()
          .write(key: _key, value: jsonEncode(_items))
          .catchError((_) {}),
    );
  }
}

/// Opens the emoji keyboard for the message box. It stays open like a
/// phone's emoji keyboard: each tap inserts at the cursor, ⌫ deletes.
Future<void> showEmojiPicker(
  BuildContext context,
  TextEditingController controller,
) async {
  unawaited(RecentEmoji.load());
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Brand.card,
    showDragHandle: true,
    builder: (sheetContext) => EmojiPickerPanel(
      key: const ValueKey('emoji-picker'),
      onPicked: (emoji) => insertAtCursor(controller, emoji),
      onBackspace: () => deleteBeforeCursor(controller),
    ),
  );
}

/// Opens the picker to choose one emoji (for a reaction).
Future<String?> pickEmoji(BuildContext context) {
  unawaited(RecentEmoji.load());
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Brand.card,
    showDragHandle: true,
    builder: (sheetContext) => EmojiPickerPanel(
      key: const ValueKey('reaction-picker'),
      onPicked: (emoji) => Navigator.of(sheetContext).pop(emoji),
    ),
  );
}

void insertAtCursor(TextEditingController controller, String insert) {
  final value = controller.value;
  final selection = value.selection;
  final start = selection.isValid ? selection.start : value.text.length;
  final end = selection.isValid ? selection.end : value.text.length;
  final text = value.text.replaceRange(start, end, insert);
  controller.value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: start + insert.length),
  );
}

/// Deletes one whole character (an emoji counts as one) before the cursor.
void deleteBeforeCursor(TextEditingController controller) {
  final value = controller.value;
  final selection = value.selection;
  final end = selection.isValid ? selection.start : value.text.length;
  if (end <= 0) return;
  if (selection.isValid && !selection.isCollapsed) {
    controller.value = TextEditingValue(
      text: value.text.replaceRange(selection.start, selection.end, ''),
      selection: TextSelection.collapsed(offset: selection.start),
    );
    return;
  }
  final before = value.text.substring(0, end).characters;
  final kept = before.skipLast(1).toString();
  controller.value = TextEditingValue(
    text: kept + value.text.substring(end),
    selection: TextSelection.collapsed(offset: kept.length),
  );
}

/// Search, category tabs (with Recent first), and a grid of emoji.
class EmojiPickerPanel extends StatefulWidget {
  const EmojiPickerPanel({required this.onPicked, this.onBackspace, super.key});

  final ValueChanged<String> onPicked;

  /// Shown as ⌫ when set (typing mode).
  final VoidCallback? onBackspace;

  @override
  State<EmojiPickerPanel> createState() => _EmojiPickerPanelState();
}

class _EmojiPickerPanelState extends State<EmojiPickerPanel> {
  final _search = TextEditingController();
  var _tab = 0;

  @override
  void initState() {
    super.initState();
    // Open on Recent when there are some, else on Smileys.
    _tab = RecentEmoji.items.isEmpty ? 1 : 0;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<String> _visible() {
    final q = _search.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      return [
        for (final c in kEmojiCategories)
          for (final e in c.emojis)
            if (e.keywords.contains(q)) e.emoji,
      ];
    }
    if (_tab == 0) return RecentEmoji.items;
    return [for (final e in kEmojiCategories[_tab - 1].emojis) e.emoji];
  }

  void _pick(String emoji) {
    RecentEmoji.use(emoji);
    widget.onPicked(emoji);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final emojis = _visible();
    final height = MediaQuery.sizeOf(context).height * 0.45;
    final searching = _search.text.trim().isNotEmpty;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 8,
        ),
        child: SizedBox(
          height: height.clamp(280.0, 420.0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('emoji-search'),
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search emoji',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        filled: true,
                        fillColor: Brand.muted,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  if (widget.onBackspace != null)
                    IconButton(
                      key: const ValueKey('emoji-backspace'),
                      tooltip: 'Delete',
                      onPressed: widget.onBackspace,
                      icon: const Icon(Icons.backspace_outlined, size: 20),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              if (!searching)
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (var i = 0; i <= kEmojiCategories.length; i++)
                        _TabIcon(
                          icon: i == 0
                              ? Icons.history
                              : kEmojiCategories[i - 1].icon,
                          label: i == 0
                              ? 'Recent'
                              : kEmojiCategories[i - 1].name,
                          selected: _tab == i,
                          onTap: () => setState(() => _tab = i),
                        ),
                    ],
                  ),
                ),
              const Divider(height: 8, color: Brand.border),
              Expanded(
                child: emojis.isEmpty
                    ? Center(
                        child: Text(
                          searching
                              ? 'No emoji found'
                              : 'Emoji you use show up here',
                          style: const TextStyle(color: Brand.inkSoft),
                        ),
                      )
                    : GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 46,
                            ),
                        itemCount: emojis.length,
                        itemBuilder: (_, i) => InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _pick(emojis[i]),
                          child: Center(
                            child: Text(
                              emojis[i],
                              style: const TextStyle(fontSize: 26),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabIcon extends StatelessWidget {
  const _TabIcon({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        key: ValueKey('emoji-tab-$label'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 44,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? Brand.ink : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Icon(
            icon,
            size: 20,
            color: selected ? Brand.ink : Brand.inkFaint,
          ),
        ),
      ),
    );
  }
}
