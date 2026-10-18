/// Every path from `API.md`. Repositories use these. Widgets do not.
abstract final class Endpoints {
  static const register = '/auth/register';
  static const login = '/auth/login';
  static const me = '/me';
  static const logout = '/auth/logout';
  static const groups = '/groups';
  static const posts = '/posts';
  static const notifications = '/notifications';
  static const unreadCount = '/notifications/unread-count';

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
