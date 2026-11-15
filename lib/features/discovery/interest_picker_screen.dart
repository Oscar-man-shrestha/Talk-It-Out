import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/ui/brand.dart';
import 'package:talk_it_out/features/discovery/data/discovery_models.dart';
import 'package:talk_it_out/features/discovery/discovery_providers.dart';
import 'package:talk_it_out/features/discovery/interest_icons.dart';

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
    final columns = width >= 900 ? 4 : (width >= 560 ? 3 : 2);
    final count = picked?.length ?? 0;
    final enough = count >= InterestPickerScreen.minimum;

    return Scaffold(
      backgroundColor: Brand.canvas,
      appBar: AppBar(
        backgroundColor: Brand.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: widget.firstRun ? null : const BackButton(),
        automaticallyImplyLeading: !widget.firstRun,
        actions: [
          if (widget.firstRun)
            TextButton(
              key: const ValueKey('interests-skip'),
              onPressed: _saving ? null : () => _save(const []),
              child: const Text('Skip', style: TextStyle(color: Brand.inkSoft)),
            ),
        ],
      ),
      body: data == null
          ? Center(
              child: state.hasError
                  ? Text('${state.error}')
                  : const CircularProgressIndicator(strokeWidth: 2),
            )
          : CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.firstRun
                              ? 'What are you into?'
                              : 'Your interests',
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
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      // Taller on phones so two-line blurbs fit.
                      childAspectRatio: columns == 2 ? 0.98 : 1.15,
                    ),
                    delegate: SliverChildBuilderDelegate((context, i) {
                      final option = data.available[i];
                      final selected = picked!.contains(option.id);
                      return _InterestTile(
                        option: option,
                        selected: selected,
                        onTap: () => setState(() {
                          if (!picked.remove(option.id)) picked.add(option.id);
                        }),
                      );
                    }, childCount: data.available.length),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: data == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  key: const ValueKey('interests-continue'),
                  onPressed: _saving || !enough
                      ? null
                      : () => _save(picked!.toList()),
                  style: FilledButton.styleFrom(
                    backgroundColor: Brand.ink,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Brand.muted,
                    disabledForegroundColor: Brand.inkSoft,
                    minimumSize: const Size.fromHeight(52),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    enough
                        ? (widget.firstRun ? 'Continue' : 'Save')
                        : 'Pick ${InterestPickerScreen.minimum - count} more',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _InterestTile extends StatelessWidget {
  const _InterestTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final InterestOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: option.label,
      child: Material(
        color: selected ? Brand.ink : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: ValueKey('interest-${option.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: selected ? Brand.ink : Brand.border),
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // A vector icon in a circle: crisp on every device,
                    // light on the dark selected tile.
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? Colors.white : Brand.accentSoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        interestIcon(option.icon),
                        size: 22,
                        color: Brand.ink,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      option.label,
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: selected ? Colors.white : Brand.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      option.blurb,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.3,
                        color: selected ? Colors.white70 : Brand.inkSoft,
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 160),
                    opacity: selected ? 1 : 0,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 15,
                        color: Brand.ink,
                      ),
                    ),
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
