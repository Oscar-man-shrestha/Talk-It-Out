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

  static const askTitle = 'Ask a question';
  static const askPublicNotice =
      'Your name is shown with your question: the feed is public and never '
      'anonymous. For anonymous feedback, write in a group instead.';
  static const askTitleLabel = 'Question';
  static const askTitleHint = 'What do you want to ask?';
  static const askTopicLabel = 'Topic';
  static const askDetailsLabel = 'Details';
  static const askDetailsHint =
      'Give the context: what is happening, what you have tried, and what '
      'kind of answer would help.';
  static const askTipsTitle = 'What makes a good question';
  static const askTips = [
    'Be specific: one situation, one question.',
    'Describe the problem, not the people. Leave names out.',
    'Say what a useful answer looks like.',
  ];
  static const askSubmit = 'Post question';
  static const askPosted = 'Question posted.';
  static const askTitleRequired = 'Write your question.';
  static const askTitleTooShort = 'Make the question a little longer.';
  static const askTitleTooLong = 'Keep the question under 150 characters.';
  static const askTopicRequired = 'Choose a topic.';
  static const askDetailsRequired = 'Add some details.';
  static const askDetailsTooLong = 'Details can be at most 5000 characters.';
  static const askDiscardTitle = 'Discard this question?';
  static const askDiscardBody = 'What you have written will be lost.';
  static const askKeepEditing = 'Keep editing';
  static const askDiscard = 'Discard';
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

  static const tagline = 'Thoughtful group conversations, refined together.';
  static const emailHint = 'you@example.com';
  static const confirmPasswordLabel = 'Confirm password';
  static const showPassword = 'Show password';
  static const hidePassword = 'Hide password';
  static const invalidEmail = 'Enter a valid email address.';
  static const passwordTooShort = 'Use at least 8 characters.';
  static const passwordsDoNotMatch = 'Passwords do not match.';
  static const anonymityNoticeTitle = 'How anonymity works';
  static const demoModeTitle = 'Demo mode';
  static const demoModeBody =
      'This build runs on sample data. Nothing you enter leaves this device.';
  static const demoModeAction = 'Use the demo account';

  static const notificationsTitle = 'Notifications';
  static const markAllRead = 'Mark all read';
  static const filterAll = 'All';
  static const filterUnread = 'Unread';
  static const filterReview = 'To review';
  static const filterRejected = 'Rejected';
  static const notificationsFilterEmpty = 'Nothing here right now.';
  static const openReview = 'Open review';
  static const openMyMessages = 'View my messages';
  static const unreadLabel = 'Unread';

  static String unreadSummary(int count) => '$count unread';

  static const postTitle = 'Post';
  static const back = 'Back';
  static const createGroupFromPostHint =
      'Start a group with this post as its agenda. You become the controller.';
  static const feedAttribution =
      'Posts and comments on the feed always show who wrote them.';

  static String commentCount(int count) =>
      count == 1 ? '1 comment' : '$count comments';

  static const anonymityExplainer =
      'Anonymous messages are hidden from the group but visible to the '
      'controller.\n\nEvery message is rewritten for tone, then the controller '
      'reviews the original next to the rewrite and decides whether to '
      'publish it. Other contributors never see your original wording.';
  static const controllerReviews =
      'Messages are rewritten for tone and reviewed by the controller before '
      'they are published.';
  static const leaveGroupBody =
      'You will stop receiving updates from this group and will not be able '
      'to send messages to it.';
  static const howGroupsWork = 'How groups work';
  static const startGroup = 'Start a new group';
  static const createGroupIntro =
      'Set the agenda for a new group. Messages are rewritten for tone and '
      'reviewed before they are published.';
  static const controllerDuty =
      'As the creator you are the controller. You review each original '
      'message next to its rewrite and decide what is published.';
  static const toneRewriteTitle = 'Tone rewrite';
  static const toneRewriteBody =
      'Each message is rewritten for tone. Relevance scores are suggestions '
      'only; nothing is hidden or rejected automatically.';

  static const reviewDecisionHint =
      'Accept publishes the rewrite to the group. Reject publishes nothing.';
  static const reviewWaitingForRewrite =
      'You can accept once the rewrite is ready.';
  static const sentWithName = 'Sent with name';
  static const openMessage = 'Open message';

  static String scorePercent(double score) =>
      '${(score.clamp(0, 1) * 100).round()}%';

  static const profileNameRequired = 'Enter your name.';
  static const imageTooLarge = 'Choose an image smaller than 2 MB.';
  static const imageUnsupported = 'Choose a PNG, JPEG, or WebP image.';
  static const editProfile = 'Edit profile';
  static const save = 'Save';
  static const cancel = 'Cancel';
  static const delete = 'Delete';
  static const add = 'Add';
  static const edit = 'Edit';
  static const profileSaved = 'Profile saved.';
  static const headlineLabel = 'Headline';
  static const bioLabel = 'About';
  static const locationLabel = 'Location';
  static const websiteLabel = 'Website';
  static const githubLabel = 'GitHub username';
  static const linkedinLabel = 'LinkedIn URL';
  static const aboutTitle = 'About';
  static const aboutEmpty =
      'Add a headline and a short bio so people know you.';
  static const linksTitle = 'Links';
  static const skillsTitle = 'Skills';
  static const skillsEmpty = 'No skills added yet.';
  static const skillHint = 'Add a skill';
  static const experienceTitle = 'Experience';
  static const experienceEmpty = 'No experience added yet.';
  static const addExperience = 'Add experience';
  static const editExperience = 'Edit experience';
  static const educationTitle = 'Education';
  static const educationEmpty = 'No education added yet.';
  static const addEducation = 'Add education';
  static const editEducation = 'Edit education';
  static const jobTitleLabel = 'Title';
  static const companyLabel = 'Company';
  static const startYearLabel = 'Start year';
  static const endYearLabel = 'End year';
  static const currentRoleLabel = 'I currently work here';
  static const descriptionLabel = 'Description';
  static const schoolLabel = 'School';
  static const degreeLabel = 'Degree';
  static const fieldOfStudyLabel = 'Field of study';
  static const requiredField = 'This field is required.';
  static const invalidYear = 'Enter a four-digit year.';
  static const endBeforeStart = 'The end year cannot be before the start year.';
  static const changePhoto = 'Change photo';
  static const removePhoto = 'Remove photo';
  static const changeCover = 'Change cover';
  static const removeCover = 'Remove cover';
  static const accountTitle = 'Account';
  static const logoutConfirmTitle = 'Log out?';
  static const logoutConfirmBody = 'You will need to log in again.';

  static String deleteConfirm(String what) => 'Delete "$what"?';

  static String removeSkill(String skill) => 'Remove $skill';
  static const profileDatesInvalid =
      'Enter dates as years, like "2021 - Present" or "2019 - 2021".';
  static const wrongPassword = 'That password is not correct.';

  static const continueWithGoogle = 'Continue with Google';
  static const orDivider = 'or';
  static const googleFailed = 'Google sign-in failed. Please try again.';
  static const changePassword = 'Change password';
  static const changePasswordSubtitle =
      'Signs out your other devices after the change';
  static const currentPasswordLabel = 'Current password';
  static const confirmNewPasswordLabel = 'Confirm new password';
  static const passwordsDontMatch = 'The new passwords do not match.';
  static const passwordChanged =
      'Password changed. Your other devices are signed out.';
  static const logoutAll = 'Sign out of all devices';
  static const logoutAllSubtitle = 'Ends every session, including this one';
  static const logoutAllBody =
      'You will be signed out here and on every other phone, tablet or '
      'browser that is signed in to this account.';

  static const resetTitle = 'Reset your password';
  static const resetIntro =
      'Enter your account email and we will send you a 6-digit code.';
  static const resetSendCode = 'Send code';
  static const resetCodeSent =
      'If that email has an account, a code is on its way. It expires in 15 minutes.';
  static const resetCodeLabel = '6-digit code';
  static const resetNewPasswordLabel = 'New password';
  static const resetConfirm = 'Set new password';
  static const resetDone = 'Password updated. Log in with your new password.';
  static const resetCodeInvalid = 'That code is not valid or has expired.';
  static const resetCodeFormat = 'Enter the 6-digit code from the email.';
  static const resetResend = 'Send a new code';
  static const resetBackToLogin = 'Back to log in';
  static const resetMockHint = 'Mock mode: the code is 123456.';
  static const enterValidEmail = 'Enter a valid email address.';
  static const deleteAccount = 'Delete account';
  static const deleteAccountSubtitle =
      'Permanently remove your account and personal data';
  static const deleteAccountBody =
      'This cannot be undone. Your profile, posts, comments and unsent '
      'messages are deleted. Messages already published in groups stay but '
      'show as "Anonymous user". Groups you control pass to the member who '
      'joined earliest. Enter your password to confirm.';
}
