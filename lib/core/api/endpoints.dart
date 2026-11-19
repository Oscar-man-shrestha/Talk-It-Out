/// Every path from `API.md`. Repositories use these. Widgets do not.
abstract final class Endpoints {
  static const register = '/auth/register';
  static const login = '/auth/login';
  static const me = '/me';
  static const logout = '/auth/logout';
  static const refreshTokens = '/auth/refresh-tokens';
  static const refresh = '/auth/refresh';
  static const myAccount = '/users/me';
  static const passwordReset = '/auth/password-reset';
  static const passwordResetVerify = '/auth/password-reset/verify';
  static const passwordResetConfirm = '/auth/password-reset/confirm';
  static const changePassword = '/auth/change-password';
  static const logoutAll = '/auth/logout-all';
  static const google = '/auth/google';
  static const eventsTicket = '/events/ticket';
  static const events = '/events';
  static const groups = '/groups';
  static const posts = '/posts';
  static const notifications = '/notifications';
  static const unreadCount = '/notifications/unread-count';
  static const notificationsReadAll = '/notifications/read-all';

  static const myProfile = '/users/me/profile';
  static const myExperiences = '/users/me/experiences';
  static const myEducations = '/users/me/educations';
  static const myAvatar = '/users/me/avatar';
  static const myCover = '/users/me/cover';

  static String myExperience(String id) => '/users/me/experiences/$id';

  static String myEducation(String id) => '/users/me/educations/$id';

  static String messageReactions(String groupId, String messageId) =>
      '/groups/$groupId/messages/$messageId/reactions';

  static String group(String groupId) => '/groups/$groupId';

  static String groupMembers(String groupId) => '/groups/$groupId/members';

  static String groupMessages(String groupId) => '/groups/$groupId/messages';

  static String myMessages(String groupId) => '/groups/$groupId/messages/mine';

  static String reviewQueue(String groupId) => '/groups/$groupId/review-queue';

  static String reviewCounts(String groupId) =>
      '/groups/$groupId/review-counts';

  static String groupAttachments(String groupId) =>
      '/groups/$groupId/attachments';

  static String groupAttachment(String groupId, String attachmentId) =>
      '/groups/$groupId/attachments/$attachmentId';

  static String reviewMessage(String groupId, String messageId) =>
      '/groups/$groupId/review-queue/$messageId';

  static String acceptMessage(String messageId) =>
      '/messages/$messageId/accept';

  static String rejectMessage(String messageId) =>
      '/messages/$messageId/reject';

  static String rewriteMessage(String messageId) =>
      '/messages/$messageId/rewrite';

  static String post(String postId) => '/posts/$postId';

  static String postReactions(String postId) => '/posts/$postId/reactions';

  static String postComments(String postId) => '/posts/$postId/comments';

  static String postGroup(String postId) => '/posts/$postId/group';

  static String comment(String postId, String commentId) =>
      '/posts/$postId/comments/$commentId';

  static String commentReport(String postId, String commentId) =>
      '/posts/$postId/comments/$commentId/report';

  static String notificationRead(String notificationId) =>
      '/notifications/$notificationId/read';

  // Discovery & Users
  static const usersSearch = '/users/search';
  static const usersSuggested = '/users/suggested';
  static const myHandle = '/users/me/handle';
  static const handleAvailable = '/users/handle-available';
  static const myInterests = '/users/me/interests';
  static const postsSearch = '/posts/search';
  static const postsClassify = '/posts/classify';
  static String postSignals(String postId) => '/posts/$postId/signals';
  static const myFeedSettings = '/users/me/feed-settings';
  static const postsSimilar = '/posts/similar';
  static String userProfile(String userId) => '/users/$userId/profile';
  static String userPosts(String userId) => '/users/$userId/posts';
  static String userBlock(String userId) => '/users/$userId/block';
  static const myBlocked = '/users/me/blocked';
  static String postReport(String postId) => '/posts/$postId/report';
  static String postLikes(String postId) => '/posts/$postId/likes';

  // Feed & Comments interactions
  static String postFollow(String postId) => '/posts/$postId/follow';
  static String commentVote(String postId, String commentId) =>
      '/posts/$postId/comments/$commentId/vote';
  static String postBest(String postId) => '/posts/$postId/best';

  // Group operations & Invitations
  static String withdrawMessage(String messageId) =>
      '/messages/$messageId/withdraw';
  static String groupMessage(String groupId, String messageId) =>
      '/groups/$groupId/messages/$messageId';
  static String messagePin(String groupId, String messageId) =>
      '/groups/$groupId/messages/$messageId/pin';
  static String groupPolls(String groupId) => '/groups/$groupId/polls';
  static String groupPollVote(String groupId, String pollId) =>
      '/groups/$groupId/polls/$pollId/vote';
  static String groupMember(String groupId, String userId) =>
      '/groups/$groupId/members/$userId';
  static String groupLeave(String groupId) => '/groups/$groupId/leave';
  static String groupSettings(String groupId) => '/groups/$groupId/settings';
  static const invitations = '/invitations';
  static String acceptInvitation(String invitationId) =>
      '/invitations/$invitationId/accept';
  static String declineInvitation(String invitationId) =>
      '/invitations/$invitationId/decline';
  static String groupInvitations(String groupId) =>
      '/groups/$groupId/invitations';
  static String groupInvitation(String groupId, String invitationId) =>
      '/groups/$groupId/invitations/$invitationId';

  // Invite links
  static String groupInvites(String groupId) => '/groups/$groupId/invites';
  static String groupInvite(String groupId, String code) =>
      '/groups/$groupId/invites/$code';
  static String invite(String code) => '/invites/$code';
  static String acceptInvite(String code) => '/invites/$code/accept';
}
