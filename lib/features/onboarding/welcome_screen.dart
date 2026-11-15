import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talk_it_out/core/ui/brand.dart';
import 'package:talk_it_out/features/auth/session_controller.dart';
import 'package:talk_it_out/features/invites/join_with_link.dart';

class _Page {
  const _Page(this.icon, this.title, this.body);

  final IconData icon;
  final String title;
  final String body;
}

// The anonymity wording must stay exact: the controller can see senders.
const _pages = [
  _Page(
    Icons.visibility_off_outlined,
    'Say what matters, safely',
    'Send messages in a group with your name or anonymously. Anonymous messages '
        'are hidden from the group but visible to the controller who reviews them.',
  ),
  _Page(
    Icons.auto_awesome,
    'Calm words, same point',
    'Before anyone reads it, an AI rewrites your message in a calm tone. Preview '
        'the wording first, and get a gentle hint while you type.',
  ),
  _Page(
    Icons.verified_user_outlined,
    'Nothing goes out unchecked',
    "The group's controller sees your original next to the rewrite and decides "
        'what is published. Other members never see your original words.',
  ),
  _Page(
    Icons.forum_outlined,
    'Ask the community',
    'A public Q&A for work questions: pay, managers, burnout and more. Your name is '
        'always shown there. For You learns what you care about.',
  ),
];

/// The welcome tour, shown once to a brand-new account (`/welcome`).
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _pager = PageController();
  var _index = 0;

  bool get _last => _index == _pages.length;

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  void _done(String to) {
    ref.read(justRegisteredProvider.notifier).mark(false);
    context.go(to);
  }

  void _next() => _pager.nextPage(
    duration: const Duration(milliseconds: 260),
    curve: Curves.easeOut,
  );

  @override
  Widget build(BuildContext context) {
    final name = ref.watch(sessionProvider).value?.name.split(' ').first ?? '';
    return Scaffold(
      backgroundColor: Brand.canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    key: const ValueKey('welcome-skip'),
                    onPressed: () => _done('/groups'),
                    child: const Text(
                      'Skip',
                      style: TextStyle(color: Brand.inkSoft),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pager,
                    onPageChanged: (i) => setState(() => _index = i),
                    children: [
                      for (final (i, p) in _pages.indexed)
                        _PageView(
                          page: p,
                          greeting: i == 0 && name.isNotEmpty
                              ? 'Welcome, $name'
                              : null,
                        ),
                      _StartView(
                        onCreate: () => _done('/groups/new'),
                        onJoin: () {
                          ref.read(justRegisteredProvider.notifier).mark(false);
                          showJoinWithLinkDialog(context);
                        },
                        onExplore: () => _done('/feed'),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i <= _pages.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _index ? 18 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: i == _index ? Brand.ink : Brand.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                  child: _last
                      ? const SizedBox(height: 48)
                      : FilledButton(
                          key: const ValueKey('welcome-next'),
                          onPressed: _next,
                          style: FilledButton.styleFrom(
                            backgroundColor: Brand.ink,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _index == _pages.length - 1
                                ? 'Get started'
                                : 'Next',
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

class _PageView extends StatelessWidget {
  const _PageView({required this.page, this.greeting});

  final _Page page;
  final String? greeting;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: 112,
            height: 112,
            decoration: const BoxDecoration(
              color: Brand.ink,
              shape: BoxShape.circle,
            ),
            child: Icon(page.icon, size: 50, color: Colors.white),
          ),
          const SizedBox(height: 28),
          if (greeting != null) ...[
            Text(
              greeting!,
              style: const TextStyle(fontSize: 15, color: Brand.inkSoft),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.15,
              color: Brand.ink,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            page.body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15.5,
              height: 1.5,
              color: Brand.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _StartView extends StatelessWidget {
  const _StartView({
    required this.onCreate,
    required this.onJoin,
    required this.onExplore,
  });

  final VoidCallback onCreate;
  final VoidCallback onJoin;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    Widget option(
      Key key,
      IconData icon,
      String title,
      String body,
      VoidCallback onTap,
    ) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            key: key,
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Brand.border),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 26, color: Brand.ink),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Brand.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          body,
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            color: Brand.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Brand.inkSoft),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          const Text(
            'Where do you want to start?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Brand.ink,
            ),
          ),
          const SizedBox(height: 20),
          option(
            const ValueKey('welcome-create'),
            Icons.add_circle_outline,
            'Create a group',
            'For a team, a project or a retro. You become its controller.',
            onCreate,
          ),
          option(
            const ValueKey('welcome-join'),
            Icons.link,
            'Join with an invite link',
            'Someone sent you a link? Paste it here.',
            onJoin,
          ),
          option(
            const ValueKey('welcome-explore'),
            Icons.explore_outlined,
            'Explore questions',
            'Read what people ask about work, and pick your interests.',
            onExplore,
          ),
        ],
      ),
    );
  }
}
