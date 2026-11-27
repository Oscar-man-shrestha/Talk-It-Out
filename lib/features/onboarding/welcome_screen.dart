import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talk_it_out/core/ui/app_icons.dart';
import 'package:talk_it_out/core/ui/brand.dart';
import 'package:talk_it_out/core/ui/motion.dart';
import 'package:talk_it_out/features/auth/session_controller.dart';
import 'package:talk_it_out/features/invites/join_with_link.dart';

/// One step of "How it works".
class _Step {
  const _Step(this.icon, this.title, this.body);

  final IconData icon;
  final String title;
  final String body;
}

// The anonymity wording must stay exact: the controller can see senders.
const _steps = [
  _Step(
    PhosphorIconsRegular.pencilSimple,
    'Write it your way',
    'Send with your name or anonymously. Anonymous messages are hidden from '
        'the group but visible to the controller who reviews them.',
  ),
  _Step(
    PhosphorIconsRegular.sparkle,
    'AI keeps the point, calms the tone',
    'Before anyone reads it, an AI rewrites your message in a calm tone. '
        'Your facts, numbers and questions stay.',
  ),
  _Step(
    PhosphorIconsRegular.shieldCheck,
    'The controller reviews, then the group sees it',
    "The group's controller decides what is published. Other members never "
        'see your original words.',
  ),
];

enum _Start { join, create, explore }

/// The welcome screen, shown once to a brand-new account (`/welcome`).
/// One screen: how it works in three steps, then where to start.
/// Layout from the Stitch project "Talk It Out — First-time experience".
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  var _choice = _Start.join;

  void _done(String to) {
    ref.read(justRegisteredProvider.notifier).mark(false);
    context.go(to);
  }

  void _go(_Start choice) {
    switch (choice) {
      case _Start.join:
        ref.read(justRegisteredProvider.notifier).mark(false);
        showJoinWithLinkDialog(context);
      case _Start.create:
        _done('/groups/new');
      case _Start.explore:
        _done('/feed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = ref.watch(sessionProvider).value?.name.split(' ').first ?? '';
    final width = MediaQuery.sizeOf(context).width;
    final side = width > 560 ? (width - 480) / 2 : 20.0;
    return Scaffold(
      backgroundColor: Brand.canvas,
      body: Column(
        children: [
          _Hero(name: name, side: side, onSkip: () => _done('/groups')),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(side, 20, side, 16),
              children: [
                const _SectionLabel('HOW IT WORKS'),
                for (final (i, s) in _steps.indexed)
                  Reveal(
                    index: i,
                    child: _StepCard(number: i + 1, step: s),
                  ),
                const SizedBox(height: 18),
                const Text(
                  'How do you want to start?',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Brand.ink,
                  ),
                ),
                const SizedBox(height: 12),
                _ChoiceCard(
                  key: const ValueKey('welcome-join'),
                  title: 'Join my team',
                  body: 'Paste an invite link from your team',
                  recommended: true,
                  selected: _choice == _Start.join,
                  onTap: () => setState(() => _choice = _Start.join),
                ),
                _ChoiceCard(
                  key: const ValueKey('welcome-create'),
                  title: 'Start a group',
                  body:
                      'For a team, a project or a retro. You become its '
                      'controller.',
                  selected: _choice == _Start.create,
                  onTap: () => setState(() => _choice = _Start.create),
                ),
                _ChoiceCard(
                  key: const ValueKey('welcome-explore'),
                  title: 'Just explore',
                  body: 'Read community questions and pick your interests',
                  selected: _choice == _Start.explore,
                  onTap: () => setState(() => _choice = _Start.explore),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(side, 8, side, 12),
              child: FilledButton(
                key: const ValueKey('welcome-continue'),
                onPressed: () => _go(_choice),
                style: FilledButton.styleFrom(
                  backgroundColor: Brand.ink,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Continue'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.name, required this.side, required this.onSkip});

  final String name;
  final double side;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Brand.ink,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(side, 8, side - 8, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      PhosphorIconsRegular.chatsCircle,
                      size: 16,
                      color: Brand.ink,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'TALK IT OUT',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('welcome-skip'),
                    onPressed: onSkip,
                    child: const Text(
                      'Skip for now',
                      style: TextStyle(color: Color(0xFFD4D4D8)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Reveal(
                child: Text(
                  name.isEmpty ? 'Welcome' : 'Welcome, $name',
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Reveal(
                index: 1,
                child: Text(
                  'Say what you really think at work, kindly and safely.',
                  style: TextStyle(
                    fontSize: 15.5,
                    height: 1.45,
                    color: Color(0xFFD4D4D8),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: Brand.inkSoft,
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.number, required this.step});

  final int number;
  final _Step step;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Brand.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: Brand.muted,
              shape: BoxShape.circle,
            ),
            child: Icon(step.icon, size: 17, color: Brand.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$number  ',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Brand.inkSoft,
                        ),
                      ),
                      TextSpan(
                        text: step.title,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: Brand.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  step.body,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: Brand.inkSoft,
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

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.title,
    required this.body,
    required this.selected,
    required this.onTap,
    this.recommended = false,
    super.key,
  });

  final String title;
  final String body;
  final bool selected;
  final bool recommended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: true,
        selected: selected,
        label: '$title. $body',
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected ? Brand.ink : Brand.border,
                  width: selected ? 1.6 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Brand.ink,
                              ),
                            ),
                            if (recommended)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Brand.ink,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'RECOMMENDED',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          body,
                          style: const TextStyle(
                            fontSize: 13.5,
                            height: 1.35,
                            color: Brand.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? Brand.ink : Colors.transparent,
                      border: Border.all(
                        color: selected ? Brand.ink : Brand.inkFaint,
                        width: 1.6,
                      ),
                    ),
                    child: selected
                        ? const Icon(
                            PhosphorIconsRegular.check,
                            size: 13,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
