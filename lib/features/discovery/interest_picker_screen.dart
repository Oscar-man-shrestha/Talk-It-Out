import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/ui/brand.dart';
import 'package:talk_it_out/features/discovery/data/discovery_models.dart';
import 'package:talk_it_out/features/discovery/discovery_providers.dart';
import 'package:talk_it_out/features/discovery/interest_icons.dart';
import 'package:talk_it_out/core/ui/app_icons.dart';

/// Pinterest-style "What are you into?" picker. [firstRun] shows the
/// welcome wording and a Skip button.
class InterestPickerScreen extends ConsumerStatefulWidget {
  const InterestPickerScreen({this.firstRun = false, super.key});

  final bool firstRun;

  static const minimum = 3;

  @override
  ConsumerState<InterestPickerScreen> createState() =>
      _InterestPickerScreenState();
}

class _InterestPickerScreenState extends ConsumerState<InterestPickerScreen> {
  Set<String>? _picked;
  var _saving = false;
  var _query = '';

  Future<void> _save(List<String> picked) async {
    setState(() => _saving = true);
    try {
      await ref.read(interestsProvider.notifier).save(picked);
      if (!mounted) return;
      final router = GoRouter.maybeOf(context);
      if (router == null) {
        await Navigator.of(context).maybePop();
      } else if (router.canPop()) {
        router.pop();
      } else {
        router.go('/feed');
      }
    } on RepositoryException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(interestsProvider);
    final data = state.value;
    final picked = _picked ??= data == null ? null : {...data.picked};
    final width = MediaQuery.sizeOf(context).width;
    final side = width > 760 ? (width - 680) / 2 : 20.0;
    final count = picked?.length ?? 0;
    final q = _query.trim().toLowerCase();
    final shown = data == null
        ? const <InterestOption>[]
        : [
            for (final o in data.available)
              if (q.isEmpty ||
                  o.label.toLowerCase().contains(q) ||
                  o.blurb.toLowerCase().contains(q))
                o,
          ];
    final enough = count >= InterestPickerScreen.minimum;

    return Scaffold(
      backgroundColor: Brand.canvas,
      appBar: AppBar(
        elevation: 0,
        leading: widget.firstRun ? null : const BackButton(),
        automaticallyImplyLeading: !widget.firstRun,
        actions: [
          if (widget.firstRun)
            TextButton(
              key: const ValueKey('interests-skip'),
              onPressed: _saving ? null : () => _save(const []),
              child: const Text(
                'Skip',
                style: TextStyle(color: Colors.white70),
              ),
            ),
        ],
      ),
      body: data == null
          ? Center(
              child: state.hasError
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Could not load topics.',
                          style: TextStyle(color: Brand.inkSoft),
                        ),
                        TextButton(
                          onPressed: () => ref.invalidate(interestsProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    )
                  : const CircularProgressIndicator(strokeWidth: 2),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(side, 4, side, 24),
              children: [
                Text(
                  widget.firstRun ? 'What are you into?' : 'Your interests',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: Brand.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pick ${InterestPickerScreen.minimum} or more. Your For You feed '
                  'starts from these and learns from the questions you like and answer.',
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: Brand.inkSoft,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  key: const ValueKey('interests-search'),
                  onChanged: (v) => setState(() => _query = v),
                  style: const TextStyle(fontSize: 14.5, color: Brand.ink),
                  decoration: InputDecoration(
                    hintText: 'Search topics',
                    hintStyle: const TextStyle(color: Brand.inkFaint),
                    prefixIcon: const Icon(
                      PhosphorIconsRegular.magnifyingGlass,
                      size: 18,
                      color: Brand.inkSoft,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: const BorderSide(color: Brand.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: const BorderSide(color: Brand.border),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No topic matches "$_query".',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Brand.inkSoft),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 10,
                    children: [
                      for (final option in shown)
                        _InterestChip(
                          option: option,
                          selected: picked!.contains(option.id),
                          onTap: () => setState(() {
                            if (!picked.remove(option.id)) {
                              picked.add(option.id);
                            }
                          }),
                        ),
                    ],
                  ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Brand.border),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        PhosphorIconsRegular.shieldCheck,
                        size: 18,
                        color: Brand.ink,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Only you see your interests. They shape your '
                          'For You feed and are never shown to anyone.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: Brand.inkSoft,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: data == null
          ? null
          : SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(side, 8, side, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        count == 0 ? 'None picked' : '$count picked',
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: Brand.ink,
                        ),
                      ),
                    ),
                    FilledButton(
                      key: const ValueKey('interests-continue'),
                      onPressed: _saving || !enough
                          ? null
                          : () => _save(picked!.toList()),
                      style: FilledButton.styleFrom(
                        backgroundColor: Brand.ink,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Brand.muted,
                        disabledForegroundColor: Brand.inkSoft,
                        minimumSize: const Size(160, 50),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        enough
                            ? (widget.firstRun ? 'Show my feed' : 'Save')
                            : 'Pick ${InterestPickerScreen.minimum - count} more',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
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

class _InterestChip extends StatelessWidget {
  const _InterestChip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final InterestOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : Brand.ink;
    return Semantics(
      button: true,
      selected: selected,
      label: option.label,
      excludeSemantics: true,
      child: Material(
        color: selected ? Brand.ink : Colors.white,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? Brand.ink : Brand.border),
        ),
        child: InkWell(
          key: ValueKey('interest-${option.id}'),
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected
                      ? PhosphorIconsRegular.check
                      : interestIcon(option.icon),
                  size: 16,
                  color: fg,
                ),
                const SizedBox(width: 7),
                Text(
                  option.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
