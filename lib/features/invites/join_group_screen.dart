import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/ui/brand.dart';
import 'package:talk_it_out/features/groups/group_providers.dart';
import 'package:talk_it_out/features/invites/invite_repository.dart';
import 'package:talk_it_out/core/ui/app_icons.dart';

final _previewProvider = FutureProvider.autoDispose
    .family<InvitePreview, String>(
      (ref, code) => ref.watch(inviteRepositoryProvider).previewInvite(code),
    );

/// Opened from an invite link (`/join/:code`, `talkitout://app/join/:code`).
/// Signed-out visitors sign in or register first and come back here.
class JoinGroupScreen extends ConsumerStatefulWidget {
  const JoinGroupScreen({required this.code, super.key});

  final String code;

  @override
  ConsumerState<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends ConsumerState<JoinGroupScreen> {
  var _joining = false;
  String? _error;

  Future<void> _join(InvitePreview preview) async {
    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      final groupId = await ref
          .read(inviteRepositoryProvider)
          .acceptInvite(widget.code);
      ref.invalidate(groupsProvider);
      if (mounted) context.go('/groups/$groupId');
    } on RepositoryException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = ref.watch(_previewProvider(widget.code));
    return Scaffold(
      backgroundColor: Brand.canvas,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(PhosphorIconsRegular.x),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/groups'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: preview.when(
              loading: () => const CircularProgressIndicator(strokeWidth: 2),
              error: (e, _) => _Invalid(
                message: e is RepositoryException
                    ? e.message
                    : 'Could not open this invite.',
              ),
              data: (p) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: Brand.ink,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.groups_2,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (p.invitedBy != null)
                    Text(
                      '${p.invitedBy} invited you to',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Brand.inkSoft,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    p.agenda,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Brand.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    p.memberCount == 1
                        ? '1 member'
                        : '${p.memberCount} members',
                    style: const TextStyle(fontSize: 13, color: Brand.inkSoft),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Brand.accentSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Brand.accentBorder),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Point(
                          Icons.visibility_off_outlined,
                          'Send with your name or anonymously.',
                        ),
                        _Point(
                          PhosphorIconsRegular.sparkle,
                          'An AI rewrites messages in a calm tone.',
                        ),
                        _Point(
                          PhosphorIconsRegular.shieldCheck,
                          "The group's controller reviews every message and can see who sent anonymous ones.",
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red.shade800),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    key: const ValueKey('join-group'),
                    onPressed: _joining
                        ? null
                        : p.alreadyMember
                        ? () => context.go('/groups/${p.groupId}')
                        : () => _join(p),
                    style: FilledButton.styleFrom(
                      backgroundColor: Brand.ink,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      p.alreadyMember
                          ? "You're in. Open the group"
                          : 'Join group',
                    ),
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

class _Point extends StatelessWidget {
  const _Point(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: Brand.accentInk),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: Brand.accentInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Invalid extends StatelessWidget {
  const _Invalid({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.link_off, size: 42, color: Brand.inkFaint),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, color: Brand.ink),
        ),
        const SizedBox(height: 6),
        const Text(
          'Ask the person who sent it for a new link.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Brand.inkSoft),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => context.go('/groups'),
          child: const Text('Go to my groups'),
        ),
      ],
    );
  }
}
