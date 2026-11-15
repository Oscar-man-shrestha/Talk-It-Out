import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/ui/brand.dart';
import 'package:talk_it_out/features/discovery/data/discovery_models.dart';
import 'package:talk_it_out/features/discovery/recent_people.dart';
import 'package:talk_it_out/features/groups/group_providers.dart';

/// Instagram-style "Add people": search with typo-tolerant suggestions,
/// people you may know, multi-select, then add everyone at once.
/// Returns how many people were added.
Future<int> showAddMembersSheet(BuildContext context, String groupId) async {
  final added = await showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Brand.canvas,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.92,
      child: AddMembersSheet(groupId: groupId),
    ),
  );
  return added ?? 0;
}

class AddMembersSheet extends ConsumerStatefulWidget {
  const AddMembersSheet({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<AddMembersSheet> createState() => _AddMembersSheetState();
}

class _AddMembersSheetState extends ConsumerState<AddMembersSheet> {
  final _search = TextEditingController();
  Timer? _debounce;
  var _query = '';
  var _loading = false;
  var _adding = false;
  String? _error;
  PeopleSearchResult? _results;
  List<PersonResult>? _suggested;
  final _selected = <String, PersonResult>{};
  var _requestId = 0;

  @override
  void initState() {
    super.initState();
    _loadSuggested();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadSuggested() async {
    try {
      final people = await ref
          .read(discoveryRepositoryProvider)
          .suggestedPeople(groupId: widget.groupId);
      if (mounted) setState(() => _suggested = people);
    } on RepositoryException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    setState(() {
      _query = q;
      if (q.isEmpty) {
        _results = null;
        _loading = false;
      }
    });
    if (q.isEmpty) return;
    // Search as you type, without a request per key press.
    _debounce = Timer(const Duration(milliseconds: 220), () => _run(q));
  }

  Future<void> _run(String q) async {
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(discoveryRepositoryProvider)
          .searchPeople(q, groupId: widget.groupId);
      if (!mounted || id != _requestId) return;
      setState(() {
        _results = result;
        _loading = false;
      });
    } on RepositoryException catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _toggle(PersonResult person) {
    if (person.inGroup) return;
    setState(() {
      if (_selected.remove(person.id) == null) _selected[person.id] = person;
    });
  }

  Future<void> _addSelected() async {
    if (_selected.isEmpty || _adding) return;
    setState(() => _adding = true);
    final repo = ref.read(groupRepositoryProvider);
    final added = <String>[];
    final addedPeople = <PersonResult>[];
    final failed = <String>[];
    for (final person in _selected.values) {
      try {
        await repo.addMember(widget.groupId, userId: person.id);
        added.add(person.name);
        addedPeople.add(person);
      } on RepositoryException catch (e) {
        failed.add('${person.name}: ${e.message}');
      }
    }
    if (addedPeople.isNotEmpty) {
      ref.read(recentPeopleProvider.notifier).addAll(addedPeople);
    }
    ref.invalidate(membersProvider(widget.groupId));
    ref.invalidate(groupDetailProvider(widget.groupId));
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop(added.length);
    if (added.isNotEmpty) {
      final first = added.first.split(' ').first;
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: Brand.ink,
          content: Text(
            added.length == 1
                ? 'Added $first to the group.'
                : 'Added $first and ${added.length - 1} '
                      '${added.length == 2 ? 'other' : 'others'}.',
          ),
        ),
      );
    }
    if (failed.isNotEmpty) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade800,
          content: Text(failed.join('\n')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final showingSearch = _query.isNotEmpty;
    final people = showingSearch
        ? (_results?.items ?? const <PersonResult>[])
        : (_suggested ?? const <PersonResult>[]);
    final count = _selected.length;
    // Recent people, marked when they are already in this group.
    final memberIds = {
      for (final m
          in ref.watch(membersProvider(widget.groupId)).value ?? const [])
        m.userId,
    };
    final suggestedIds = {
      for (final p in _suggested ?? const <PersonResult>[]) p.id,
    };
    final recent = showingSearch
        ? const <PersonResult>[]
        : [
            for (final p in ref.watch(recentPeopleProvider))
              if (!suggestedIds.contains(p.id))
                PersonResult(
                  id: p.id,
                  name: p.name,
                  handle: p.handle,
                  headline: p.headline,
                  avatarUrl: p.avatarUrl,
                  inGroup: memberIds.contains(p.id),
                  reason: 'Recently added',
                ),
          ];

    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Brand.border,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close, size: 22),
                onPressed: () => Navigator.of(context).pop(0),
              ),
              const Expanded(
                child: Text(
                  'Add members',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Brand.ink,
                  ),
                ),
              ),
              FilledButton(
                key: const ValueKey('add-members-confirm'),
                onPressed: count == 0 || _adding ? null : _addSelected,
                style: FilledButton.styleFrom(
                  backgroundColor: Brand.ink,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Brand.muted,
                  disabledForegroundColor: Brand.inkFaint,
                  minimumSize: const Size(64, 36),
                  shape: const StadiumBorder(),
                ),
                child: _adding
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(count == 0 ? 'Add' : 'Add ($count)'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            key: const ValueKey('add-members-search'),
            controller: _search,
            autofocus: true,
            onChanged: _onChanged,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 15, color: Brand.ink),
            decoration: InputDecoration(
              hintText: 'Search name or @handle',
              hintStyle: const TextStyle(color: Brand.inkFaint),
              prefixIcon: const Icon(Icons.search, color: Brand.inkSoft),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(
                        Icons.cancel,
                        size: 18,
                        color: Brand.inkFaint,
                      ),
                      onPressed: () {
                        _search.clear();
                        _onChanged('');
                      },
                    ),
              filled: true,
              fillColor: Brand.muted,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        if (_selected.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              children: [
                for (final p in _selected.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InputChip(
                      avatar: _Avatar(person: p, size: 22),
                      label: Text(p.name.split(' ').first),
                      onDeleted: () => _toggle(p),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Brand.border),
                      shape: const StadiumBorder(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
        SizedBox(
          height: 2,
          child: _loading
              ? const LinearProgressIndicator(minHeight: 2, color: Brand.ink)
              : null,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red.shade800),
                  ),
                ),
              if (showingSearch && (_results?.similarOnly ?? false))
                const _Hint(
                  icon: Icons.auto_fix_high,
                  text: 'No exact match. Showing names that look or sound similar.',
                ),
              if (recent.isNotEmpty) ...[
                Row(
                  children: [
                    const Expanded(child: _SectionTitle('Recent')),
                    TextButton(
                      key: const ValueKey('recent-clear'),
                      onPressed: () =>
                          ref.read(recentPeopleProvider.notifier).clear(),
                      child: const Text(
                        'Clear',
                        style: TextStyle(color: Brand.inkSoft),
                      ),
                    ),
                  ],
                ),
                for (final p in recent)
                  _PersonTile(
                    person: p,
                    query: '',
                    selected: _selected.containsKey(p.id),
                    onTap: () => _toggle(p),
                  ),
              ],
              if (!showingSearch)
                const _SectionTitle('Suggested')
              else if (people.isNotEmpty)
                const _SectionTitle('People'),
              if (!showingSearch && _suggested == null)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              if (!showingSearch && _suggested != null && people.isEmpty)
                const _Hint(
                  icon: Icons.person_search,
                  text: 'Search for anyone by name or @handle. Small typos are fine.',
                ),
              if (showingSearch &&
                  !_loading &&
                  _results != null &&
                  people.isEmpty)
                _Hint(
                  icon: Icons.search_off,
                  text:
                      'No one found for "$_query". Check the spelling, or ask them for their @handle.',
                ),
              for (final p in people)
                _PersonTile(
                  person: p,
                  query: showingSearch ? _query : '',
                  selected: _selected.containsKey(p.id),
                  onTap: () => _toggle(p),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Brand.ink,
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Brand.inkSoft),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                color: Brand.inkSoft,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.person, this.size = 44});

  final PersonResult person;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Brand.accentSoft,
        shape: BoxShape.circle,
        border: Border.all(color: Brand.accentBorder),
      ),
      child: Text(
        person.initials,
        style: TextStyle(
          fontSize: size * 0.34,
          fontWeight: FontWeight.w700,
          color: Brand.accentInk,
        ),
      ),
    );
    final url = person.avatarUrl;
    if (url == null) return fallback;
    return ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({
    required this.person,
    required this.query,
    required this.selected,
    required this.onTap,
  });

  final PersonResult person;
  final String query;
  final bool selected;
  final VoidCallback onTap;

  /// Bold the part of the name that matches what was typed.
  List<TextSpan> _nameSpans() {
    const base = TextStyle(
      fontSize: 14.5,
      fontWeight: FontWeight.w500,
      color: Brand.ink,
    );
    const bold = TextStyle(
      fontSize: 14.5,
      fontWeight: FontWeight.w800,
      color: Brand.ink,
    );
    final q = query.toLowerCase().replaceFirst(RegExp('^@+'), '');
    final lower = person.name.toLowerCase();
    var at = -1;
    if (q.isNotEmpty) {
      if (lower.startsWith(q)) {
        at = 0;
      } else {
        final i = lower.indexOf(' $q');
        if (i >= 0) at = i + 1;
      }
    }
    if (at < 0) return [TextSpan(text: person.name, style: base)];
    return [
      TextSpan(text: person.name.substring(0, at), style: base),
      TextSpan(text: person.name.substring(at, at + q.length), style: bold),
      TextSpan(text: person.name.substring(at + q.length), style: base),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = person.subtitle;
    return InkWell(
      key: ValueKey('person-${person.id}'),
      onTap: person.inGroup ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            _Avatar(person: person),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(children: _nameSpans()),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Brand.inkSoft,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (person.inGroup)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Brand.muted,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Member',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Brand.inkSoft,
                  ),
                ),
              )
            else
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? Brand.ink : Colors.transparent,
                  border: Border.all(
                    color: selected ? Brand.ink : Brand.inkFaint,
                    width: 1.6,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}
