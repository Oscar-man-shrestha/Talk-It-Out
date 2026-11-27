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

  test('extended endpoints match API.md', () {
    expect(Endpoints.usersSearch, '/users/search');
    expect(Endpoints.usersSuggested, '/users/suggested');
    expect(Endpoints.myHandle, '/users/me/handle');
    expect(Endpoints.handleAvailable, '/users/handle-available');
    expect(Endpoints.myInterests, '/users/me/interests');
    expect(Endpoints.postsSearch, '/posts/search');
    expect(Endpoints.postsClassify, '/posts/classify');
    expect(Endpoints.postSignals('p1'), '/posts/p1/signals');
    expect(Endpoints.myFeedSettings, '/users/me/feed-settings');
    expect(Endpoints.postsSimilar, '/posts/similar');
    expect(Endpoints.userProfile('u1'), '/users/u1/profile');
    expect(Endpoints.userPosts('u1'), '/users/u1/posts');
    expect(Endpoints.userBlock('u1'), '/users/u1/block');
    expect(Endpoints.myBlocked, '/users/me/blocked');
    expect(Endpoints.postReport('p1'), '/posts/p1/report');
    expect(Endpoints.postLikes('p1'), '/posts/p1/likes');
    expect(Endpoints.postFollow('p1'), '/posts/p1/follow');
    expect(Endpoints.commentVote('p1', 'c1'), '/posts/p1/comments/c1/vote');
    expect(Endpoints.postBest('p1'), '/posts/p1/best');
    expect(Endpoints.withdrawMessage('m1'), '/messages/m1/withdraw');
    expect(Endpoints.groupMessage('g1', 'm1'), '/groups/g1/messages/m1');
    expect(Endpoints.messagePin('g1', 'm1'), '/groups/g1/messages/m1/pin');
    expect(Endpoints.groupPolls('g1'), '/groups/g1/polls');
    expect(Endpoints.groupPollVote('g1', 'pol1'), '/groups/g1/polls/pol1/vote');
    expect(Endpoints.groupMember('g1', 'u1'), '/groups/g1/members/u1');
    expect(Endpoints.groupLeave('g1'), '/groups/g1/leave');
    expect(Endpoints.groupSettings('g1'), '/groups/g1/settings');
    expect(Endpoints.invitations, '/invitations');
    expect(Endpoints.acceptInvitation('i1'), '/invitations/i1/accept');
    expect(Endpoints.declineInvitation('i1'), '/invitations/i1/decline');
    expect(Endpoints.groupInvitations('g1'), '/groups/g1/invitations');
    expect(Endpoints.groupInvitation('g1', 'i1'), '/groups/g1/invitations/i1');
    expect(Endpoints.groupInvites('g1'), '/groups/g1/invites');
    expect(Endpoints.groupInvite('g1', 'code1'), '/groups/g1/invites/code1');
    expect(Endpoints.invite('code1'), '/invites/code1');
    expect(Endpoints.acceptInvite('code1'), '/invites/code1/accept');
  });
}
