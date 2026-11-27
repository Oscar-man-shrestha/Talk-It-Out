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

  /// Why the AI could not rephrase a message (API.md 72), in plain words.
  /// Shown to the controller and in the sender's own preview only.
  static String rewriteReason(String? code) => switch (code) {
    'unsupported_language' =>
      'The AI only rephrases messages written in English.',
    'input_too_long' => 'The message is too long for the AI to rephrase.',
    'intent_not_preserved' =>
      'The AI could not rephrase it without changing its meaning.',
    'abusive_language_kept' =>
      'Every AI attempt still contained abusive wording, so none is shown.',
    'hate_speech_kept' =>
      'Every AI attempt still contained the hateful claim, so none is shown.',
    'abuse_only' =>
      'The message is only abusive language: there is nothing to rephrase.',
    'model_refused' =>
      'The AI declined: the message is mostly abuse, with little to rephrase.',
    'output_too_long' ||
    'blank_output' ||
    'prompt_scaffold_leak' => 'The AI rewrite failed our safety checks.',
    'model_timeout' ||
    'model_unavailable' ||
    'model_bad_response' ||
    'model_empty_output' => 'The AI service was unavailable. Try again.',
    _ => 'The AI could not rephrase this message.',
  };

  /// Advisory moderation flags on the original message (API.md 72).
  static String moderationFlag(String flag) => switch (flag) {
    'hate_speech' => 'Hate speech',
    'threat' => 'Threat',
    'abusive_language' => 'Abusive language',
    'profanity' => 'Profanity',
    'self_harm' => 'May need support',
    _ => 'Flagged',
  };
  static const moderationFlagsNote =
      'Flagged by the AI on the original. Advisory: you decide.';
  static const pipelineQueued = 'Waiting to rewrite';
  static const pipelineProcessing = 'Rewriting…';
  static const relevanceRelevant = 'Relevant';
  static const relevanceBorderline = 'Borderline';
  static const relevanceOffTopic = 'Off topic';

  static const feedEmpty = 'No posts yet.';

  static const emojiTooltip = 'Emoji';
  static const copyLink = 'Copy link';
  static const copyQuestion = 'Copy question';
  static const linkCopied = 'Link copied.';
  static const questionCopied = 'Question copied.';
  static const saveQuestion = 'Save question';
  static const unsaveQuestion = 'Remove from saved';
  static const newRewrite = 'Ask the AI for a new rewrite';
  static const rewriteRequested =
      'Asked for a fresh rewrite. It will appear here when ready.';
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

  // Never names the sender: the message may be anonymous.
  static String mentioned(String agenda) => 'You were mentioned in $agenda.';

  static String groupInvitation(String agenda) =>
      'You are invited to join $agenda.';

  static String questionAnswered(String title) => 'New answer on "$title".';

  static String answerBest(String title) =>
      'Your answer was marked best on "$title".';

  // Only the sender gets this, so it never reveals an anonymous author.
  static String messagePublished(String agenda) =>
      'Your message in $agenda was published.';

  // Names the group only; the members list shows who.
  static String memberJoined(String agenda) => 'A new member joined $agenda.';

  static String questionLiked(String title) =>
      'People liked your question "$title".';
  static const loading = 'Loading';
  static const retry = 'Try again';
  static const errorGeneric = 'Something went wrong. Please try again.';
  static const serverUnreachable =
      'Can\'t reach the server. Check your connection and try again.';
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

  // "Continue as" (Run 119).
  static String continuePasswordHint(String name) =>
      'Enter the password for $name, then sign in.';
  static String continueWithGoogleHint(String name) =>
      '$name signs in with Google. Use "Continue with Google" below.';

  // Sign-in hero (Run 117). Every line describes what the product does.
  static const heroEyebrow = 'PRIVATE BY DESIGN';
  static const heroTitle = 'Say what matters.\nKeep it safe.';
  static const heroBody =
      'Every message is rewritten for tone and approved by your group\'s '
      'controller before anyone sees it.';
  static const heroPointAnonymous = 'Speak up anonymously when you need to';
  static const heroPointRewrite = 'AI rewrites the tone, never the meaning';
  static const heroPointReview = 'A controller approves every message';
  static const heroFootnote =
      'The group sees the rewrite. Only the controller sees your original words.';

  /// Create-group card on your own question (feed).
  static const createGroupFromPostBody =
      'Start a group to work on this question. You become its controller: '
      'every message is rewritten for tone and you decide what is shared.';
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
  static const resetCodeLabel = '6-digit code';
  static const resetNewPasswordLabel = 'New password';
  static const resetConfirm = 'Set new password';
  static const resetDone = 'Password updated. Log in with your new password.';
  static const resetCodeInvalid = 'That code is not valid or has expired.';
  static const resetCodeFormat = 'Enter the 6-digit code from the email.';
  static const resetResend = 'Send a new code';
  static const resetBackToLogin = 'Back to log in';
  static const resetMockHint = 'Mock mode: the code is 123456.';
  static const resetNoAccount =
      'No account uses this email. Check it, or create an account.';
  static String resetStep(int step) => 'STEP $step OF 3';
  static const resetCodeTitle = 'Check your email';
  static String resetCodeIntro(String email) =>
      'We sent a 6-digit code to $email. It expires in 15 minutes.';
  static const resetVerify = 'Verify code';
  static const resetPasswordTitle = 'Choose a new password';
  static const resetPasswordIntro =
      'Code verified. Pick a password with at least 8 characters.';
  static const resetConfirmPasswordLabel = 'Confirm new password';
  static const resetPasswordsDiffer = 'The two passwords do not match.';
  static String resetResendIn(int seconds) => 'Send a new code in ${seconds}s';
  static const resetNewCodeSent = 'A new code is on its way.';
  static const resetChangeEmail = 'Use a different email';
  static const resetCreateAccount = 'Create an account';
  static const resetCheckSpam = 'Not there? Check your spam folder.';
  static const enterValidEmail = 'Enter a valid email address.';
  static const deleteAccount = 'Delete account';
  static const deleteAccountSubtitle =
      'Permanently remove your account and personal data';
  static const deleteAccountBody =
      'This cannot be undone. Your profile, posts, comments and unsent '
      'messages are deleted. Messages already published in groups stay but '
      'show as "Anonymous user". Groups you control pass to the member who '
      'joined earliest. Enter your password to confirm.';

  // Comments and questions you own
  static const cannotReportOwn = 'You cannot report your own comment.';
  static const reportComment = 'Report comment';
  static const withdrawReport = 'Withdraw report';
  static const commentReported =
      'Reported. The question\'s author can see it and remove the comment.';
  static const reportWithdrawn = 'Report withdrawn.';

  /// Feed likes and answer upvotes.
  static const likePost = 'Like';
  static const unlikePost = 'Unlike';
  static const cannotUpvoteOwnAnswer = "You can't upvote your own answer.";
  static const removeComment = 'Remove comment';
  static const commentRemoved = 'Comment removed.';
  static const removeCommentConfirm =
      'Remove this comment for everyone? This cannot be undone.';
  static String reportedTimes(int n) =>
      n == 1 ? 'Reported by 1 person' : 'Reported by $n people';
  static const deleteQuestion = 'Delete question';
  static const deleteQuestionConfirm =
      'Delete this question with its likes and comments? A group started '
      'from it keeps running. This cannot be undone.';
  static const questionDeleted = 'Question deleted.';
  static const remove = 'Remove';

  // Review history
  static const reviewNoneApproved = 'No approved messages yet.';
  static const reviewNoneRejected = 'No rejected messages yet.';
  static const reviewDecidedNote =
      'This message has been decided. Decisions are final.';

  static const groupChatTitle = 'Group chat';

  // Profile anonymity card
  static const anonymityCardTitle = 'ANONYMOUS MESSAGES';
  static const anonymityCardSubtitle =
      'Tick "Anonymous message" when you write in a group chat';
  static const anonymityMembersSee = 'Group sees:';
  static const anonymityControllerSees = 'Controller sees:';
  static const anonymityNoId = 'no name, no ID';
  static const anonymityReviews = 'reviews first';
  static const anonymityCardNote =
      'The AI also rewrites the wording, so your style does not give you away. '
      'Nothing is published until the controller approves it.';

  // Chat images
  static const attachImage = 'Add a photo';
  static const removeImage = 'Remove photo';
  static const imageUnreadable = 'That image could not be read. Try another.';
  static const imageCaptionNeeded = 'Add a caption to send with the photo.';
  static const imagePrivacyNamed =
      'Location and camera details are removed before anyone sees it.';
  static const imagePrivacyAnonymous =
      'Location and camera details are removed. Check the photo itself does '
      'not show who you are: your face, desk, screen name, or handwriting.';
  static const imageUnavailable = 'Image unavailable';
  static const imageInReview =
      'Photo attached. The controller sees it in review.';

  // Chat upgrades (Run 092)
  static const searchTooShort = 'Type at least 2 characters to search.';
  static const previewExpired = 'That preview has expired. Preview again.';
  static const withdrawTooLate =
      'The controller has already decided on this message.';
  static const withdraw = 'Withdraw';
  static const withdrawConfirm =
      'Take this message back? The controller will not see it.';
  static const withdrawn = 'Message withdrawn.';
  static const previewAction = 'Preview AI wording';
  static const previewWorking = 'The AI is rewording your draft…';
  static const previewTitle = 'How the group will read it';
  static const previewFailed =
      'The AI could not reword this draft. You can still send it; the '
      'controller will see it as written.';
  static const previewSend = 'Send for review';
  static const previewChange = 'Change draft';
  static const previewNote =
      'Only you see this preview. The controller reviews it after you send.';
  static const loadEarlier = 'Load earlier messages';
  static const searchHint = 'Search this group';
  static const searchNone = 'No messages match.';
  static const pinned = 'Pinned';
  static const pin = 'Pin to top';
  static const unpin = 'Unpin';
  static const newPoll = 'New poll';
  static const pollQuestion = 'Question';
  static const pollOption = 'Option';
  static const addOption = 'Add option';
  static const postPoll = 'Post poll';
  static const pollVotesPrivate = 'Votes are counted, never shown by name.';
  static String voteCount(int n) => n == 1 ? '1 vote' : '$n votes';
  static const originalMessage = 'Original message';
  static const olderMessageHint =
      'That message is further back. Tap "Load earlier messages" first.';
  static const jumpToLatest = 'Jump to latest';
  static const noMessagesYet = 'No messages yet';

  // Premium (docs/PREMIUM_PLAN.md, API.md 71).
  static const premium = 'Premium';
  static const premiumTitle = 'Talk It Out Premium';
  static const premiumTagline =
      'More tools for the groups you lead. Everything you use today stays free.';
  static const premiumPrice = '₹99';
  static const premiumPerMonth = 'per month';
  static const premiumSubscribe = 'Get Premium';
  static const premiumRestore = 'Restore purchases';
  static const premiumYouHave = "You're Premium";
  static String premiumRenews(String date) => 'Renews on $date';
  static String premiumEnds(String date) => 'Premium ends on $date';
  static const premiumNoEnd = 'No end date';
  static const premiumThanks = 'Welcome to Premium. Thank you!';
  static const premiumCancelled = 'No charge was made.';
  static const premiumFailed =
      'The store could not complete the purchase. Please try again.';
  static const premiumRestored = 'Purchases restored.';
  static const premiumStoreUnavailable =
      'Get Premium in the Talk It Out app on iPhone or Android.';
  static const premiumFreeTitle = 'Free, always';
  static const premiumWebPayNote =
      'Secure checkout by Razorpay: UPI, cards, net banking or wallets.';
  static const premiumCancelWeb = 'Cancel web subscription';
  static const premiumCancelWebConfirm =
      'Premium stays on until the end of the month you paid for, then it stops renewing.';
  static const premiumCancelledWeb =
      'Cancelled. Premium stays on until the end of your paid month.';

  // Plan comparison and payment (Premium screen, Run 122).
  static const planYourPlan = 'Your plan';
  static const starMessage = 'Star';
  static const unstarMessage = 'Unstar';
  static const starNeedsPremium = 'Starred messages are part of Premium.';
  static const starredTitle = 'Starred messages';
  static const starredEmpty =
      'No starred messages yet. Long-press a message in a group and choose Star.';
  static const chatThemeTitle = 'Chat theme';
  static const premiumFeatureThemesBodyLocked =
      'Choose your bubble colour and chat wallpaper with Premium.';
  static const chatThemeBubbles = 'Your bubble colour';
  static const chatThemeWallpaper = 'Wallpaper';
  static const chatThemePreviewOther = 'How is the release going?';
  static const chatThemePreviewMine = 'Nearly there, testing today.';
  static const promoTitle = 'Get Talk It Out Premium';
  static const promoBody = 'Insights, templates, chat themes and more.';
  static const sidebarGetPremium = 'Get Premium';
  static const sidebarPremium = 'Premium';
  static const planFreeCaption = 'Everything you need to talk it out.';
  static const planPremiumCaption =
      'Everything in Free, plus tools to do more.';
  static const planFreeFeatures = [
    'Unlimited groups and chats',
    'Anonymous messages',
    'AI tone rewrites on every message',
    'Controller review and safety tools',
    'Public Q&A feed, answers and likes',
    'Catch up summaries and notifications',
  ];
  static const planPremiumFeatures = [
    'Everything in Free',
    'Group Insights for the groups you lead',
    'Group templates: retro, town hall, class feedback',
    'Chat themes: your own bubble colour and wallpaper',
    'Starred messages, saved to find later',
    'Premium badge next to your name in the feed',
    'Support an independent, privacy-first app',
  ];
  static const payTitle = 'How you pay';
  static const payMethods = [
    'UPI',
    'Debit or credit card',
    'Net banking',
    'Wallets (web)',
    'Google Play balance',
    'Apple ID balance',
  ];
  static const paySteps = [
    'On your phone, tap Get Premium in the Talk It Out app. On the website, tap Get Premium on this page.',
    'Pay securely: Google Play or the App Store on phones, Razorpay on the web (UPI, cards, net banking, wallets). Talk It Out never sees your card or UPI details.',
    'Premium starts at once and works wherever you sign in.',
    'It renews every month for ₹99. Cancel anytime: in your store subscriptions on phones, or on this page for web payments.',
  ];
  static const premiumFreeBody =
      'Groups, chat, anonymous messages, AI tone rewrites, review, the feed and Catch up. No limits added.';
  static const premiumNeverSold =
      'Anonymity, AI rewrites and moderation are never paid features, and Premium is never shown on anonymous messages.';
  static const premiumFeatureInsights = 'Group Insights';
  static const premiumFeatureInsightsBody =
      'Activity, review times and top themes for the groups you lead. Counts only, never names.';
  static const premiumFeatureTemplates = 'Group templates';
  static const premiumFeatureTemplatesBody =
      'Start a sprint retro, class feedback or town hall in one tap.';
  static const premiumFeatureThemes = 'Chat themes';
  static const premiumFeatureThemesBody =
      'Your own bubble colour and chat wallpaper.';
  static const premiumFeatureBadge = 'Premium badge';
  static const premiumFeatureBadgeBody =
      'A crown next to your name in the public feed.';
  static const premiumFeatureStarred = 'Starred messages';
  static const premiumFeatureStarredBody =
      'Save important messages and find them later.';
  static const premiumDisclosure =
      'Renews every month until you cancel. Cancel anytime in your App Store or Google Play subscription settings; you keep Premium until the end of the paid month.';
  static const premiumTerms = 'Terms';
  static const premiumPrivacy = 'Privacy';
  static const premiumLocked = 'Premium';
  static const premiumUnlock = 'Unlock with Premium';

  // Group Insights.
  static const insightsTitle = 'Group Insights';
  static String insightsWindow(int days) => 'Last $days days';
  static const insightsMessages = 'Messages shared';
  static const insightsPending = 'Waiting for review';
  static const insightsAccepted = 'Approved';
  static const insightsRejected = 'Not approved';
  static const insightsReviewTime = 'Your typical review time';
  static const insightsParticipants = 'People who posted by name';
  static const insightsAnonymous = 'Anonymous messages';
  static const insightsBusiest = 'Busiest hours';
  static const insightsTopWords = 'Most talked about';
  static const insightsNoWords = 'Not enough messages yet.';
  static const insightsActivity = 'Activity';
  static const insightsSmallGroup =
      'Participation and timing appear once the group has 5 or more members, so nobody can be singled out.';
  static const insightsPrivacy =
      'Counts from published messages only. Nobody is named.';
  static const insightsTeaserTitle = 'See how your group is doing';
  static const insightsTeaserBody =
      'Group Insights shows activity, review times and top themes for groups you lead. Part of Premium.';
  static const insightsControllerOnly =
      'Only the group’s controller can see its insights.';

  // Group templates.
  static const templatesTitle = 'Start from a template';
  static const templateRetro = 'Sprint retro';
  static const templateRetroAgenda =
      'Sprint retro: what went well, what slowed us down, what to try next';
  static const templateClass = 'Class feedback';
  static const templateClassAgenda =
      'Class feedback: what is working and what could help you learn better';
  static const templateTownHall = 'Town hall Q&A';
  static const templateTownHallAgenda =
      'Town hall Q&A: questions for leadership, answered openly';
  static const templateOneOnOne = '1:1 feedback';
  static const templateOneOnOneAgenda =
      '1:1 feedback: what I need from you and what you need from me';
  static const templateExit = 'Exit conversation';
  static const templateExitAgenda =
      'Exit conversation: what we should keep, fix and stop doing';
}
