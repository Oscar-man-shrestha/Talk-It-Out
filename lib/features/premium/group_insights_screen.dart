import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/core/ui/app_icons.dart';
import 'package:talk_it_out/core/ui/brand.dart';
import 'package:talk_it_out/core/ui/floating_emblem.dart';
import 'package:talk_it_out/core/ui/motion.dart';
import 'package:talk_it_out/core/ui/page_padding.dart';
import 'package:talk_it_out/core/ui/screen_async.dart';
import 'package:talk_it_out/core/ui/skeleton.dart';
import 'package:talk_it_out/core/ui/surfaces.dart';
import 'package:talk_it_out/features/premium/data/premium_models.dart';
import 'package:talk_it_out/features/premium/premium_providers.dart';

final groupInsightsProvider = FutureProvider.autoDispose
    .family<GroupInsights, String>((ref, groupId) {
      // Re-check after Premium changes (for example right after buying).
      ref.watch(isPremiumProvider);
      return ref.watch(billingRepositoryProvider).insights(groupId);
    });

/// Group Insights (`API.md` 71): for the group's controller, with Premium.
/// Counts from published messages only; nobody is named.
class GroupInsightsScreen extends ConsumerWidget {
  const GroupInsightsScreen({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref.watch(groupInsightsProvider(groupId));
    final error = insights.error;
    final code = error is RepositoryException ? error.code : null;
    return Scaffold(
      backgroundColor: Brand.canvas,
      appBar: AppBar(title: const Text(AppStrings.insightsTitle)),
      body: switch (insights) {
        AsyncData(:final value) => _InsightsBody(insights: value),
        AsyncError() when code == 'premium_required' => const _Teaser(),
        AsyncError() when code == 'forbidden' => const _Message(
          icon: PhosphorIconsRegular.lockSimple,
          text: AppStrings.insightsControllerOnly,
        ),
        AsyncError() => _Message(
          icon: PhosphorIconsRegular.warningCircle,
          text: errorText(error) ?? AppStrings.errorGeneric,
          onRetry: () => ref.invalidate(groupInsightsProvider(groupId)),
        ),
        _ => const SkeletonList(count: 4),
      },
    );
  }
}

class _InsightsBody extends StatelessWidget {
  const _InsightsBody({required this.insights});

  final GroupInsights insights;

  @override
  Widget build(BuildContext context) {
    final i = insights;
    final hPad = pageHPad(MediaQuery.sizeOf(context).width, maxContent: 720);
    final review = i.reviewMedianMinutes;
    return ListView(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 32),
      children: [
        Text(
          AppStrings.insightsWindow(i.windowDays),
          style: const TextStyle(fontSize: 13, color: Brand.inkSoft),
        ),
        const SizedBox(height: 12),
        Reveal(
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Stat(AppStrings.insightsMessages, '${i.messages}'),
              _Stat(AppStrings.insightsPending, '${i.pending}'),
              _Stat(AppStrings.insightsAccepted, '${i.accepted}'),
              _Stat(AppStrings.insightsRejected, '${i.rejected}'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Reveal(
          index: 1,
          child: _Card(
            title: AppStrings.insightsActivity,
            child: _ActivityBars(days: i.daily),
          ),
        ),
        const SizedBox(height: 14),
        Reveal(
          index: 2,
          child: _Card(
            title: AppStrings.insightsReviewTime,
            child: Text(
              review == null ? '—' : _duration(review),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
                color: Brand.ink,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Reveal(
          index: 3,
          child: i.breakdownsAvailable
              ? _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Row(
                        AppStrings.insightsParticipants,
                        '${i.participants ?? 0}',
                      ),
                      _Row(
                        AppStrings.insightsAnonymous,
                        '${i.anonymousMessages ?? 0}',
                      ),
                      if ((i.busiestHours ?? const []).isNotEmpty)
                        _Row(
                          AppStrings.insightsBusiest,
                          [
                            for (final (hour, _) in i.busiestHours!)
                              _hourLabel(hour),
                          ].join(', '),
                        ),
                    ],
                  ),
                )
              : const _Note(
                  key: ValueKey('insights-small-group'),
                  text: AppStrings.insightsSmallGroup,
                ),
        ),
        const SizedBox(height: 14),
        Reveal(
          index: 4,
          child: _Card(
            title: AppStrings.insightsTopWords,
            child: i.topWords.isEmpty
                ? const Text(
                    AppStrings.insightsNoWords,
                    style: TextStyle(fontSize: 13.5, color: Brand.inkSoft),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (word, count) in i.topWords)
                        Chip(label: Text('$word · $count')),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 16),
        const _Note(text: AppStrings.insightsPrivacy),
      ],
    );
  }

  static String _duration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }

  static String _hourLabel(int hour) {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    return '$h ${hour < 12 ? 'AM' : 'PM'}';
  }
}

class _ActivityBars extends StatelessWidget {
  const _ActivityBars({required this.days});

  final List<DayCount> days;

  @override
  Widget build(BuildContext context) {
    final peak = days.fold<int>(1, (m, d) => d.count > m ? d.count : m);
    return SizedBox(
      height: 132,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final d in days)
            Expanded(
              child: Tooltip(
                message: '${d.date.day}/${d.date.month}: ${d.count}',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AnimatedContainer(
                        duration: Motion.slow,
                        curve: Motion.enter,
                        height: 4 + 84 * d.count / peak,
                        decoration: BoxDecoration(
                          color: d.count == 0 ? Brand.border : Brand.ink,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${d.date.day}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Brand.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.all(14),
      decoration: Surfaces.card(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
              color: Brand.ink,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12.5, color: Brand.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.title});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: Surfaces.card(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Brand.ink,
              ),
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: Brand.inkSoft),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Brand.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          PhosphorIconsRegular.shieldCheck,
          size: 16,
          color: Brand.inkSoft,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: Brand.inkSoft,
            ),
          ),
        ),
      ],
    );
  }
}

class _Teaser extends StatelessWidget {
  const _Teaser();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            key: const ValueKey('insights-teaser'),
            mainAxisSize: MainAxisSize.min,
            children: [
              const FloatingEmblem(
                icon: PhosphorIconsRegular.chartBar,
                size: 76,
              ),
              const Text(
                AppStrings.insightsTeaserTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: Brand.ink,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                AppStrings.insightsTeaserBody,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.45,
                  color: Brand.inkSoft,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => context.push('/premium'),
                icon: const Icon(PhosphorIconsFill.crown, size: 18),
                label: const Text(AppStrings.premiumUnlock),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.onRetry});

  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: Brand.inkFaint),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14.5, color: Brand.inkSoft),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text(AppStrings.retry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
