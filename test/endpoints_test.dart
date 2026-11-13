import 'package:flutter_test/flutter_test.dart';
import 'package:talk_it_out/core/api/endpoints.dart';

void main() {
  test('paths match API.md', () {
    expect(Endpoints.register, '/auth/register');
    expect(Endpoints.login, '/auth/login');
    expect(Endpoints.me, '/me');
    expect(Endpoints.logout, '/auth/logout');
    expect(Endpoints.groups, '/groups');
    expect(Endpoints.group('g1'), '/groups/g1');
    expect(Endpoints.groupMembers('g1'), '/groups/g1/members');
    expect(Endpoints.groupMessages('g1'), '/groups/g1/messages');
    expect(Endpoints.myMessages('g1'), '/groups/g1/messages/mine');
    expect(Endpoints.reviewQueue('g1'), '/groups/g1/review-queue');
    expect(Endpoints.reviewMessage('g1', 'm1'), '/groups/g1/review-queue/m1');
    expect(Endpoints.acceptMessage('m1'), '/messages/m1/accept');
    expect(Endpoints.rejectMessage('m1'), '/messages/m1/reject');
    expect(Endpoints.posts, '/posts');
    expect(Endpoints.post('p1'), '/posts/p1');
    expect(Endpoints.postReactions('p1'), '/posts/p1/reactions');
    expect(Endpoints.postComments('p1'), '/posts/p1/comments');
    expect(Endpoints.postGroup('p1'), '/posts/p1/group');
    expect(Endpoints.notifications, '/notifications');
    expect(Endpoints.notificationRead('n1'), '/notifications/n1/read');
    expect(Endpoints.unreadCount, '/notifications/unread-count');
  });

  test('section 10 paths match API.md', () {
    expect(Endpoints.notificationsReadAll, '/notifications/read-all');
    expect(Endpoints.myProfile, '/users/me/profile');
    expect(Endpoints.myExperiences, '/users/me/experiences');
    expect(Endpoints.myExperience('e1'), '/users/me/experiences/e1');
    expect(Endpoints.myEducations, '/users/me/educations');
    expect(Endpoints.myEducation('d1'), '/users/me/educations/d1');
    expect(Endpoints.myAvatar, '/users/me/avatar');
    expect(Endpoints.myCover, '/users/me/cover');
    expect(
      Endpoints.messageReactions('g1', 'pm1'),
      '/groups/g1/messages/pm1/reactions',
    );
  });
}
