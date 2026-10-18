/// Exact user-facing copy from `CURSOR_FRONTEND_BRIEF.md` section 7.
abstract final class AppStrings {
  static const appName = 'Talk It Out';
  static const shellPlaceholder = 'Groups, feed, and review will appear here.';

  static const loginTitle = 'Log in';
  static const registerTitle = 'Create account';
  static const emailLabel = 'Email';
  static const passwordLabel = 'Password';
  static const nameLabel = 'Name';
  static const loginAction = 'Log in';
  static const registerAction = 'Create account';
  static const needAccount = 'Need an account? Create one';
  static const haveAccount = 'Already have an account? Log in';
  static const logout = 'Log out';

  static const navGroups = 'Groups';
  static const navFeed = 'Feed';
  static const navNotifications = 'Notifications';
  static const navProfile = 'Profile';

  static const groupsEmpty = 'You are not in any groups yet.';
  static const createGroup = 'Create group';
  static const agendaLabel = 'Agenda';
  static const agendaHint = 'What is this group for?';
  static const membersTitle = 'Members';
  static const roleController = 'Controller';
  static const roleContributor = 'Contributor';

  static String pendingCount(int count) => '$count waiting for review';

  static const chatEmpty = 'No messages yet.';
  static const messageHint = 'Write a message';
  static const send = 'Send';
  static const anonymousCheckbox = 'Anonymous message';
  static const anonymousDisclosure =
      'Anonymous messages are hidden from the group but visible to the controller.';
  static const anonymousUser = 'Anonymous user';
  static const myMessages = 'My messages';
  static const myMessagesEmpty = 'You have not sent any messages yet.';
  static const statusPending = 'Pending';
  static const statusAccepted = 'Accepted';
  static const statusRejected = 'Rejected';

  static const reviewTitle = 'Review';
  static const reviewEmpty = 'Nothing waiting for review.';
  static const originalLabel = 'Original';
  static const rewriteLabel = 'Rewrite';
  static const senderLabel = 'Sender';
  static const anonymousFlag = 'Sent as anonymous';
  static const relevanceLabel = 'Relevance';
  static const relevanceAdvisory = 'Relevance is a suggestion. You decide.';
  static const intentLabel = 'Intent preservation';
  static const accept = 'Accept';
  static const reject = 'Reject';
  static const rewriteUnavailable = 'Rewrite unavailable';
  static const pipelineQueued = 'Waiting to rewrite';
  static const pipelineProcessing = 'Rewriting…';
  static const relevanceRelevant = 'Relevant';
  static const relevanceBorderline = 'Borderline';
  static const relevanceOffTopic = 'Off topic';

  static const feedEmpty = 'No posts yet.';
  static const newPost = 'New post';
  static const postHint = 'Share an agenda or idea';
  static const publishPost = 'Post';
  static const commentHint = 'Write a comment';
  static const addComment = 'Comment';
  static const commentsTitle = 'Comments';
  static const commentsEmpty = 'No comments yet.';
  static const like = 'Like';
  static const liked = 'Liked';
  static const createGroupFromPost = 'Create group from this post';
  static const flagged = 'Flagged';

  static const notificationsEmpty = 'No notifications.';

  static String messageRejected(String agenda) =>
      'Your message in $agenda was rejected.';

  static String messagePendingReview(String agenda) =>
      'A message in $agenda is waiting for your review.';

  static const notificationGeneric = 'You have a new notification.';
  static const loading = 'Loading';
  static const retry = 'Try again';
  static const errorGeneric = 'Something went wrong. Please try again.';
  static const notAllowed = 'You are not allowed to do that.';
  static const notFound = 'We could not find that.';
  static const profileTitle = 'Profile';

  static const agendaRequired = 'Add an agenda first.';
  static const messageRequired = 'Write a message before sending.';
  static const postRequired = 'Write something before posting.';
  static const commentRequired = 'Write a comment before sending.';
  static const missingCredentials = 'Enter your email and password.';
  static const missingAccountFields = 'Enter your name, email, and password.';
  static const emailInUse = 'That email is already registered.';
  static const wrongLogin = 'Email or password is incorrect.';
  static const sessionExpired = 'Please log in again.';
  static const acceptNoRewrite = 'This message has no rewrite yet.';
  static const alreadyReviewed = 'That message was already reviewed.';
  static const groupAlreadyExists = 'A group already exists for this post.';
  static const reactionRequired = 'Choose a reaction.';
}
