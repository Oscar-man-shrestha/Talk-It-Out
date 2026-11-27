import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/models/enums.dart';
import 'package:talk_it_out/core/ui/brand.dart';
import 'package:talk_it_out/features/auth/session_controller.dart';
import 'package:talk_it_out/features/discovery/data/discovery_models.dart';
import 'package:talk_it_out/features/discovery/safety_actions.dart';
import 'package:talk_it_out/features/feed/data/post.dart';
import 'package:talk_it_out/features/groups/group_providers.dart';
import 'package:talk_it_out/core/ui/page_padding.dart';
import 'package:talk_it_out/core/ui/app_icons.dart';

/// Someone's profile (`API.md` 59).
final personProvider = FutureProvider.autoDispose.family<PersonProfile, String>(
  (ref, userId) => ref.watch(discoveryRepositoryProvider).getPerson(userId),
);

/// Someone's public questions.
final personPostsProvider = FutureProvider.autoDispose
    .family<List<Post>, String>(
      (ref, userId) =>
          ref.watch(discoveryRepositoryProvider).personPosts(userId),
    );

/// Opens someone's profile, or your own Profile tab for yourself.
void openPerson(BuildContext context, WidgetRef ref, String userId) {
  final me = ref.read(sessionProvider).value?.id;
  if (userId == me) {
    context.go('/profile');
  } else {
    context.push('/people/$userId');
  }
}

/// Instagram-style profile of another person: who they are, what you
/// share, their questions, and Add to group / Block.
class PersonProfileScreen extends ConsumerWidget {
  const PersonProfileScreen({required this.userId, super.key});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = ref.watch(personProvider(userId));
    final data = person.value;
    return Scaffold(
      backgroundColor: Brand.canvas,
      appBar: AppBar(
        // Opened from a link there is nothing to pop: go somewhere useful.
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/feed'),
        ),
        title: Text(
          data == null
              ? ''
              : (data.handle != null ? '@${data.handle}' : data.profile.name),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (data != null)
            PopupMenuButton<String>(
              key: const ValueKey('person-menu'),
              tooltip: 'More',
              icon: const Icon(PhosphorIconsRegular.dotsThree),
              onSelected: (value) async {
                if (value == 'block') {
                  await confirmAndBlock(
                    context,
                    ref,
                    userId,
                    data.profile.name,
                  );
                } else if (value == 'unblock') {
                  await unblockPerson(context, ref, userId, data.profile.name);
                }
              },
              itemBuilder: (_) => [
                if (data.blockedByMe)
                  const PopupMenuItem(value: 'unblock', child: Text('Unblock'))
                else
                  PopupMenuItem(
                    value: 'block',
                    child: Text(
                      'Block',
                      style: TextStyle(color: Colors.red.shade800),
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: person.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (error, _) => _Unavailable(
          message: error is RepositoryException && error.code == 'not_found'
              ? "This profile isn't available."
              : 'Could not load this profile.',
          onRetry: () => ref.invalidate(personProvider(userId)),
        ),
        data: (p) => p.blockedByMe
            ? _BlockedView(person: p, userId: userId)
            : _ProfileBody(person: p, userId: userId),
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.person_off_outlined,
              size: 40,
              color: Brand.inkFaint,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Brand.inkSoft),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class _BigAvatar extends StatelessWidget {
  const _BigAvatar({required this.name, this.url});

  static const size = 84.0;

  final String name;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final letters = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Brand.accentSoft,
        shape: BoxShape.circle,
        border: Border.all(color: Brand.accentBorder, width: 2),
      ),
      child: Text(
        letters.isEmpty ? '?' : letters,
        style: TextStyle(
          fontSize: size * 0.32,
          fontWeight: FontWeight.w800,
          color: Brand.accentInk,
        ),
      ),
    );
    if (url == null) return fallback;
    return ClipOval(
      child: Image.network(
        url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

class _BlockedView extends ConsumerWidget {
  const _BlockedView({required this.person, required this.userId});

  final PersonProfile person;
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = person.profile.name;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BigAvatar(name: name, url: person.profile.avatarUrl),
            const SizedBox(height: 14),
            Text(
              'You blocked $name',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Brand.ink,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "You can't see each other's questions or profiles, or add each other to groups.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Brand.inkSoft, height: 1.4),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              key: const ValueKey('person-unblock'),
              onPressed: () => unblockPerson(context, ref, userId, name),
              child: const Text('Unblock'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.person, required this.userId});

  final PersonProfile person;
  final String userId;

  Future<void> _addToGroup(BuildContext context, WidgetRef ref) async {
    final groups = [
      for (final g in ref.read(groupsProvider).value ?? const [])
        if (g.myRole == GroupRole.controller) g,
    ];
    if (groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Only a group controller can add people. Create a group first.',
          ),
        ),
      );
      return;
    }
    final groupId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Brand.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Text(
                'Add to a group you control',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Brand.ink,
                ),
              ),
            ),
            for (final g in groups)
              ListTile(
                leading: const Icon(PhosphorIconsRegular.usersThree),
                title: Text(
                  g.agenda,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.of(ctx).pop(g.id),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (groupId == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(groupRepositoryProvider)
          .addMember(groupId, userId: userId);
      ref.invalidate(membersProvider(groupId));
      ref.invalidate(personProvider(userId));
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: Brand.ink,
          content: Text(
            'Invitation sent to ${person.profile.name.split(' ').first}. '
            'They join after accepting.',
          ),
        ),
      );
    } on RepositoryException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = person.profile;
    final posts = ref.watch(personPostsProvider(userId));
    final width = MediaQuery.sizeOf(context).width;
    final hPad = pageHPad(width);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(personProvider(userId));
        ref.invalidate(personPostsProvider(userId));
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 32),
        children: [
          Row(
            children: [
              _BigAvatar(name: p.name, url: p.avatarUrl),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Brand.ink,
                      ),
                    ),
                    if (person.handle != null)
                      Text(
                        '@${person.handle}',
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Brand.inkSoft,
                        ),
                      ),
                    if (p.headline.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        p.headline,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Brand.ink,
                        ),
                      ),
                    ],
                    if (p.location.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            PhosphorIconsRegular.mapPin,
                            size: 14,
                            color: Brand.inkFaint,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              p.location,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Brand.inkSoft,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (person.sharedGroups > 0)
            Row(
              children: [
                const Icon(
                  PhosphorIconsRegular.usersThree,
                  size: 16,
                  color: Brand.inkSoft,
                ),
                const SizedBox(width: 6),
                Text(
                  person.sharedGroups == 1
                      ? 'In 1 of your groups'
                      : 'In ${person.sharedGroups} of your groups',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Brand.inkSoft,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('person-add-to-group'),
              onPressed: () => _addToGroup(context, ref),
              style: FilledButton.styleFrom(
                backgroundColor: Brand.ink,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(PhosphorIconsRegular.userPlus, size: 18),
              label: const Text('Invite to group'),
            ),
          ),
          if (p.bio.isNotEmpty) ...[
            const SizedBox(height: 18),
            const _Heading('About'),
            Text(
              p.bio,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: Brand.ink,
              ),
            ),
          ],
          if (p.skills.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final skill in p.skills)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Brand.border),
                    ),
                    child: Text(
                      skill,
                      style: const TextStyle(fontSize: 12, color: Brand.ink),
                    ),
                  ),
              ],
            ),
          ],
          if (p.experiences.isNotEmpty) ...[
            const SizedBox(height: 18),
            const _Heading('Experience'),
            for (final e in p.experiences.take(3))
              _Line(title: e.title, subtitle: e.company),
          ],
          if (p.educations.isNotEmpty) ...[
            const SizedBox(height: 14),
            const _Heading('Education'),
            for (final e in p.educations.take(2))
              _Line(title: e.school, subtitle: e.degree),
          ],
          const SizedBox(height: 18),
          const _Heading('Questions'),
          posts.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, _) => const Text(
              'Could not load questions.',
              style: TextStyle(color: Brand.inkSoft),
            ),
            data: (items) => items.isEmpty
                ? const Text(
                    'No public questions yet.',
                    style: TextStyle(fontSize: 13, color: Brand.inkSoft),
                  )
                : Column(
                    children: [
                      for (final post in items)
                        _QuestionTile(
                          post: post,
                          onTap: () => context.push('/feed/${post.id}'),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: Brand.ink,
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Brand.ink,
              ),
            ),
            if (subtitle.isNotEmpty)
              TextSpan(
                text: ' · $subtitle',
                style: const TextStyle(color: Brand.inkSoft),
              ),
          ],
        ),
        style: const TextStyle(fontSize: 13.5),
      ),
    );
  }
}

class _QuestionTile extends StatelessWidget {
  const _QuestionTile({required this.post, required this.onTap});

  final Post post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Brand.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.title ?? post.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Brand.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${post.reactionCount} likes · ${post.commentCount} answers',
                  style: const TextStyle(fontSize: 12, color: Brand.inkSoft),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
