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
  static const passwordResetConfirm = '/auth/password-reset/confirm';
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

  static String reviewMessage(String groupId, String messageId) =>
      '/groups/$groupId/review-queue/$messageId';

  static String acceptMessage(String messageId) =>
      '/messages/$messageId/accept';

  static String rejectMessage(String messageId) =>
      '/messages/$messageId/reject';

  static String post(String postId) => '/posts/$postId';

  static String postReactions(String postId) => '/posts/$postId/reactions';

  static String postComments(String postId) => '/posts/$postId/comments';

  static String postGroup(String postId) => '/posts/$postId/group';

  static String notificationRead(String notificationId) =>
      '/notifications/$notificationId/read';
}
