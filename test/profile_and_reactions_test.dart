import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/mock/mock_board.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/mock/mock_ids.dart';
import 'package:talk_it_out/core/utils/relative_time.dart';
import 'package:talk_it_out/features/auth/data/mock_auth_repository.dart';
import 'package:talk_it_out/features/groups/data/message_reactions.dart';
import 'package:talk_it_out/features/groups/data/mock_group_repository.dart';
import 'package:talk_it_out/features/groups/data/mock_message_bridge.dart';
import 'package:talk_it_out/features/notifications/data/mock_notification_repository.dart';
import 'package:talk_it_out/features/profile/data/mock_profile_repository.dart';
import 'package:talk_it_out/features/profile/data/profile.dart';

MockControls get _fast => MockControls(delay: Duration.zero);

MockProfileRepository _profiles([MockAuthRepository? auth]) {
  return MockProfileRepository(_fast, auth ?? MockAuthRepository(_fast));
}

final _png = Uint8List.fromList([
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
]);

void main() {
  group('profile repository', () {
    test('a new profile is the account and nothing else', () async {
      final profile = await _profiles().getMyProfile();
      expect(profile.id, MockIds.priya);
      expect(profile.name, 'Priya');
      expect(profile.email, MockAuthRepository.mockEmail);
      expect(profile.headline, isEmpty);
      expect(profile.skills, isEmpty);
      expect(profile.experiences, isEmpty);
      expect(profile.educations, isEmpty);
      expect(profile.avatarUrl, isNull);
    });

    test('each account gets its own profile', () async {
      final auth = MockAuthRepository(_fast);
      final repo = _profiles(auth);
      await repo.updateDetails(
        const ProfileDetails(name: 'Priya', headline: 'Notes lead'),
      );

      await auth.register(
        name: 'Sam',
        email: 'sam@example.com',
        password: 'long-enough-1',
      );
      final sam = await repo.getMyProfile();
      expect(sam.name, 'Sam');
      expect(sam.headline, isEmpty);
    });

    test('details, skills, experience and education round-trip', () async {
      final repo = _profiles();
      await repo.updateDetails(
        const ProfileDetails(name: 'Priya R', bio: 'Hello', location: 'Pune'),
      );
      await repo.updateSkills(['Flutter', 'NLP']);
      final job = await repo.addExperience(
        ProfileExperience(
          id: '',
          title: 'Engineer',
          company: 'Acme',
          startDate: DateTime(2022),
          isCurrent: true,
        ),
      );
      final school = await repo.addEducation(
        const ProfileEducation(id: '', school: 'State University'),
      );

      var profile = await repo.getMyProfile();
      expect(profile.name, 'Priya R');
      expect(profile.bio, 'Hello');
      expect(profile.skills, ['Flutter', 'NLP']);
      expect(profile.experiences.single.id, job.id);
      expect(profile.experiences.single.period, '2022 – Present');
      expect(profile.educations.single.id, school.id);

      await repo.deleteExperience(job.id);
      await repo.deleteEducation(school.id);
      profile = await repo.getMyProfile();
      expect(profile.experiences, isEmpty);
      expect(profile.educations, isEmpty);
    });

    test('a blank name is rejected', () async {
      expect(
        _profiles().updateDetails(const ProfileDetails(name: '  ')),
        throwsA(isA<RepositoryException>()),
      );
    });

    test('images are checked by content and size', () async {
      final repo = _profiles();
      final url = await repo.uploadImage(
        ProfileImageKind.avatar,
        bytes: _png,
        filename: 'avatar',
      );
      expect(url, startsWith('data:image/png;base64,'));
      expect((await repo.getMyProfile()).avatarUrl, url);

      await expectLater(
        repo.uploadImage(
          ProfileImageKind.avatar,
          bytes: Uint8List.fromList('not an image'.codeUnits),
          filename: 'avatar.png',
        ),
        throwsA(
          isA<RepositoryException>().having(
            (e) => e.code,
            'code',
            'unsupported_media_type',
          ),
        ),
      );
      final huge = Uint8List(MockProfileRepository.maxImageBytes + 1)
        ..setAll(0, _png);
      await expectLater(
        repo.uploadImage(ProfileImageKind.cover, bytes: huge, filename: 'c'),
        throwsA(
          isA<RepositoryException>().having(
            (e) => e.code,
            'code',
            'file_too_large',
          ),
        ),
      );

      await repo.removeImage(ProfileImageKind.avatar);
      expect((await repo.getMyProfile()).avatarUrl, isNull);
    });
  });

  group('profile JSON', () {
    test('reads the API shape', () {
      final profile = Profile.fromJson({
        'user': {
          'id': 'u1',
          'name': 'Priya',
          'email': 'priya@example.com',
          'headline': 'Lead',
          'github_handle': 'priya',
          'skills': ['A', 'B'],
          'avatar_url': 'http://localhost:3000/media/abc',
          'cover_url': null,
        },
        'experiences': [
          {
            'id': 'e1',
            'title': 'Engineer',
            'company': 'Acme',
            'start_date': '2021-03-01',
            'end_date': '2023-06-30',
            'is_current': false,
          },
        ],
        'educations': [
          {'id': 'd1', 'school': 'State', 'start_year': 2015, 'end_year': 2019},
        ],
      });
      expect(profile.githubHandle, 'priya');
      expect(profile.skills, ['A', 'B']);
      expect(profile.coverUrl, isNull);
      expect(profile.experiences.single.period, '2021 – 2023');
      expect(profile.educations.single.period, '2015 – 2019');
    });

    test('tolerates missing and mistyped fields', () {
      final profile = Profile.fromJson({
        'user': {'id': 'u1', 'name': 'Priya', 'skills': 'oops', 'bio': 7},
        'experiences': 'nope',
      });
      expect(profile.bio, isEmpty);
      expect(profile.skills, isEmpty);
      expect(profile.email, isNull);
      expect(profile.experiences, isEmpty);
      expect(Profile.fromJson(const {}).name, isEmpty);
    });

    test('a current role never sends an end date', () {
      final body = ProfileExperience(
        id: 'e1',
        title: 'Engineer',
        company: 'Acme',
        startDate: DateTime(2022, 4, 9),
        endDate: DateTime(2024),
        isCurrent: true,
      ).toRequest();
      expect(body['start_date'], '2022-04-09');
      expect(body['end_date'], isNull);
      expect(body.containsKey('id'), isFalse);
    });
  });

  group('message reactions', () {
    test('parse counts only and ignore junk', () {
      final reactions = MessageReactions.fromJson({
        'message_id': 'pm1',
        'reactions': {'👍': 2, '❤️': 0, '🔥': 'x'},
        'my_reactions': ['👍', 5],
        'reactors': ['u1'],
      });
      expect(reactions.counts, {'👍': 2});
      expect(reactions.mine, {'👍'});
    });

    test('toggle adds, then removes', () {
      const start = MessageReactions(messageId: 'pm1', counts: {'👍': 1});
      final added = start.toggled('👍');
      expect(added.counts['👍'], 2);
      expect(added.mine, {'👍'});
      final removed = added.toggled('👍');
      expect(removed.counts['👍'], 1);
      expect(removed.mine, isEmpty);
      expect(
        removed.toggled('🔥').toggled('🔥').counts.containsKey('🔥'),
        false,
      );
    });

    test('mock repository toggles and rejects unknown emoji', () async {
      final groups = MockGroupRepository(
        _fast,
        MockBoard(),
        MockMessageBridge(),
      );
      final messages = await groups.listMessages(MockIds.notesGroup);
      final id = messages.items.first.id;
      final before = await groups.getReactions(MockIds.notesGroup, id);
      final after = await groups.toggleReaction(
        MockIds.notesGroup,
        id,
        emoji: kReactionEmojis.first,
      );
      expect(after.mine.contains(kReactionEmojis.first), isTrue);
      expect(
        after.counts[kReactionEmojis.first],
        (before.counts[kReactionEmojis.first] ?? 0) + 1,
      );
      expect(
        groups.toggleReaction(MockIds.notesGroup, id, emoji: '🤖'),
        throwsA(isA<RepositoryException>()),
      );
    });
  });

  test('mark all read leaves nothing unread', () async {
    final notifications = MockNotificationRepository(_fast);
    expect((await notifications.unreadCount()).count, greaterThan(0));
    await notifications.markAllRead();
    expect((await notifications.unreadCount()).count, 0);
    expect(
      (await notifications.list()).items.every((n) => !n.isUnread),
      isTrue,
    );
  });

  test('relative time reads naturally', () {
    final now = DateTime(2026, 11, 13, 12);
    String ago(Duration d) => relativeTime(now.subtract(d), now: now);
    expect(ago(const Duration(seconds: 5)), 'just now');
    expect(ago(const Duration(minutes: 5)), '5m ago');
    expect(ago(const Duration(hours: 3)), '3h ago');
    expect(ago(const Duration(days: 2)), '2d ago');
    expect(ago(const Duration(days: 20)), '24 Oct');
    expect(relativeTime(DateTime(2025, 1, 2), now: now), '2 Jan 2025');
  });
}
