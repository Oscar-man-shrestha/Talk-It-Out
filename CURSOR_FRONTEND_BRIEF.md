# CURSOR_FRONTEND_BRIEF.md

**Version:** 2
**Repo:** Flutter frontend only
**Product:** Collaboration platform with controller-moderated groups, a public feed, and per-message anonymity

This file is the product source of truth for the app. Agent rules live in `AGENTS.md`. The HTTP contract lives in `API.md`. Models and visibility live in `DATA.md`. Progress lives in `LOGS.md`.

If this file disagrees with a hard rule in `AGENTS.md`, follow `AGENTS.md`.

---

## 1. What the app is

People discuss work in groups. A single **controller** approves every message before the group sees it. An NLP pipeline (backend, not this repo) rewrites the message into a professional version and scores how well it fits the group agenda. The controller still decides.

A contributor can tick **Anonymous message** just before sending. The group then sees **"Anonymous user"**. The controller still sees the real sender.

There is also a **public feed** of posts and comments. The feed has no anonymity. A post author can turn that post into a group and becomes its controller.

The UI never waits on NLP. A sent message stays `pending` until the controller accepts it. Nothing is published optimistically.

## 2. Roles

| Role | Sees | Can do |
|---|---|---|
| Controller (one per group) | Original text, rewrite, real sender, anonymity flag, relevance result, pipeline status | Accept or reject. No rewrite editing. |
| Contributor | Published rewrites only. Own messages as status only (`pending`, `accepted`, `rejected`) with no reason | Send a message. Optionally mark it anonymous. |
| Platform user | Public feed, authors always shown | Post, comment, react. Create a group from **their own** post. |

## 3. Screens

Every screen has four states: **loading**, **empty**, **error with retry**, **success**.

| Screen | Who | Notes |
|---|---|---|
| Log in | Signed out | Email and password |
| Create account | Signed out | Name, email, password |
| Groups | Signed in | Groups the user belongs to. Controller rows may show a pending count. |
| Create group | Signed in | Agenda only. Caller becomes controller. |
| Group chat | Member | Published messages only. Null sender renders **"Anonymous user"**. |
| Composer | Contributor | Checkbox **"Anonymous message"** sits immediately before Send, with the disclosure beside it. No composer for the controller (D6). |
| My messages | Member | Own messages, status only. No text, no rejection reason. |
| Members | Member | Name and role. |
| Review queue | Controller only | Pending messages, oldest first. Guarded route. |
| Review detail | Controller only | Original, rewrite, sender, anonymity flag, relevance (advisory), intent score, pipeline status. Accept and Reject. No reason field. No edit. |
| Feed | Signed in | Posts. Authors always shown. |
| New post | Signed in | Content only. |
| Post detail | Signed in | Comments, like, and **Create group from this post** only when the current user is the author. |
| Notifications | Signed in | Rejection (no reason) and pending-review. Badge from unread count. |
| Profile | Signed in | Name, email, log out. |

Shell: bottom navigation with Groups, Feed, Notifications, Profile.

## 4. Message lifecycle (UI)

1. Contributor sends text plus `is_anonymous`. The UI shows it as pending in **My messages** only.
2. While pipeline status is `queued` or `processing`, the controller still sees the original and may decide. The rewrite and scores stay empty.
3. When pipeline status is `failed`, the controller sees **"Rewrite unavailable"** and can still review the original. If accept fails because there is no rewrite, show the human-readable error from the API (D1).
4. **Accept** publishes the rewrite into the group chat. Anonymous messages show **"Anonymous user"**.
5. **Reject** publishes nothing. The contributor gets a plain notification. No reason is shown anywhere.

Relevance (`relevant`, `borderline`, `off_topic`) is a suggestion on the review screen. It never hides or rejects a message by itself.

## 5. Out of scope for v1

Do not build these, even if a prompt asks casually. Log the conflict in `LOGS.md` and skip that part.

- Auto-approve, deputies, timeouts, bulk approve
- Editing the rewrite
- Rejection reasons or any feedback beyond the plain notification
- Audit log or controller accountability UI
- Anonymity in the public feed
- Auto-rejecting or hiding messages from relevance
- A "show original" control for contributors (no button, toggle, long-press, or hidden menu)
- Controller transfer when a controller leaves (leave a `TODO(open-item)` only)

## 6. Build phases

Do one phase per run. Stop. Wait for the user to say "continue".

| Phase | Name | Done when |
|---|---|---|
| 0 | Setup | Flutter app exists, shell placeholder runs, folders and shared strings/endpoints exist, quality gates pass |
| 1 | Models and repositories | Freezed models and mock repositories match `DATA.md`, including the mock seed list. No screens yet. |
| 2 | Auth and shell | Register, login, logout, session in secure storage, bottom nav, controller route guard stub |
| 3 | Groups | Group list, create, members, chat of published messages, my-messages status |
| 4 | Composer and anonymity | Send flow, checkbox plus disclosure directly before Send, no controller composer |
| 5 | Controller review | Queue and detail, accept/reject, pipeline states, route guard enforced |
| 6 | Notifications | List, unread badge, mark read, polling on resume and pull-to-refresh |
| 7 | Public feed | Posts, comments, reactions, create-group-from-post for the author only |
| 8 | Polish and tests | Empty/error/loading on every screen, accessibility, tests for privacy rules |
| 9 | Real API | `Api*Repository` against `API.md`, `USE_MOCK=false`. Still no backend code in this repo. |

## 7. Exact UI copy

Use these strings. Do not paraphrase them in widgets. Put them in one strings file.

| Key | Exact copy |
|---|---|
| appName | Talk It Out |
| shellPlaceholder | Groups, feed, and review will appear here. |
| loginTitle | Log in |
| registerTitle | Create account |
| emailLabel | Email |
| passwordLabel | Password |
| nameLabel | Name |
| loginAction | Log in |
| registerAction | Create account |
| needAccount | Need an account? Create one |
| haveAccount | Already have an account? Log in |
| logout | Log out |
| navGroups | Groups |
| navFeed | Feed |
| navNotifications | Notifications |
| navProfile | Profile |
| groupsEmpty | You are not in any groups yet. |
| createGroup | Create group |
| agendaLabel | Agenda |
| agendaHint | What is this group for? |
| membersTitle | Members |
| roleController | Controller |
| roleContributor | Contributor |
| pendingCount | {count} waiting for review |
| chatEmpty | No messages yet. |
| messageHint | Write a message |
| send | Send |
| anonymousCheckbox | Anonymous message |
| anonymousDisclosure | Anonymous messages are hidden from the group but visible to the controller. |
| anonymousUser | Anonymous user |
| myMessages | My messages |
| myMessagesEmpty | You have not sent any messages yet. |
| statusPending | Pending |
| statusAccepted | Accepted |
| statusRejected | Rejected |
| reviewTitle | Review |
| reviewEmpty | Nothing waiting for review. |
| originalLabel | Original |
| rewriteLabel | Rewrite |
| senderLabel | Sender |
| anonymousFlag | Sent as anonymous |
| relevanceLabel | Relevance |
| relevanceAdvisory | Relevance is a suggestion. You decide. |
| intentLabel | Intent preservation |
| accept | Accept |
| reject | Reject |
| rewriteUnavailable | Rewrite unavailable |
| pipelineQueued | Waiting to rewrite |
| pipelineProcessing | Rewriting… |
| relevanceRelevant | Relevant |
| relevanceBorderline | Borderline |
| relevanceOffTopic | Off topic |
| feedEmpty | No posts yet. |
| newPost | New post |
| postHint | Share an agenda or idea |
| publishPost | Post |
| commentHint | Write a comment |
| addComment | Comment |
| commentsTitle | Comments |
| commentsEmpty | No comments yet. |
| like | Like |
| liked | Liked |
| createGroupFromPost | Create group from this post |
| flagged | Flagged |
| notificationsEmpty | No notifications. |
| messageRejected | Your message in {agenda} was rejected. |
| messagePendingReview | A message in {agenda} is waiting for your review. |
| notificationGeneric | You have a new notification. |
| loading | Loading |
| retry | Try again |
| errorGeneric | Something went wrong. Please try again. |
| notAllowed | You are not allowed to do that. |
| notFound | We could not find that. |
| profileTitle | Profile |
| agendaRequired | Add an agenda first. |
| messageRequired | Write a message before sending. |
| postRequired | Write something before posting. |
| commentRequired | Write a comment before sending. |
| missingCredentials | Enter your email and password. |
| missingAccountFields | Enter your name, email, and password. |
| emailInUse | That email is already registered. |
| wrongLogin | Email or password is incorrect. |
| sessionExpired | Please log in again. |
| acceptNoRewrite | This message has no rewrite yet. |
| alreadyReviewed | That message was already reviewed. |
| groupAlreadyExists | A group already exists for this post. |
| reactionRequired | Choose a reaction. |

`{count}` and `{agenda}` are filled in by the strings file. Rejection copy has no reason slot.

## 8. Acceptance criteria (v1)

- Accepted messages show the rewrite. Anonymous ones show **Anonymous user**. Named ones show the sender name.
- Rejected messages never appear in the group chat.
- Group-facing code does not import `RawMessage` and has no way to reveal original text.
- The anonymity disclosure is visible next to the checkbox, immediately before Send.
- Controller routes redirect anyone who is not that group's controller.
- Review shows pipeline `queued`, `processing`, `done`, and `failed` without blocking the UI.
- Feed authors are always visible. Create-group is offered only to the post author.
- Unknown enum values from the backend do not crash the app.
- `dart format .`, `flutter analyze` (zero issues), and `flutter test` pass.

## 9. Ready-to-paste prompts

Paste one prompt per Cursor run. Each prompt already ends with the log line. Say **continue** to move to the next phase.

### Prompt 0: Kickoff

```
You are working in the Flutter frontend repo only. Read AGENTS.md fully. Read LOGS.md (Status Snapshot, Open Decisions, last 3 run entries). Read CURSOR_FRONTEND_BRIEF.md, API.md, and DATA.md.

Do not write or change code in this run. Reply with:
- current phase and next step from LOGS.md
- any conflict between the docs
- confirmation that you will do one phase per run, frontend only, and follow the hard rules in AGENTS.md section 4

Append the results into LOGS.md as per the format provided in it.
```

### Phase 0: Setup

```
Do Phase 0 (Setup) only, then stop.

Frontend only. Read AGENTS.md, LOGS.md (snapshot, open decisions, last 3 runs), and CURSOR_FRONTEND_BRIEF.md sections 6 and 7.

Scaffold the Flutter app in this repo (android and ios). Add flutter_riverpod and go_router. Create feature folders lib/features/{auth,groups,review,feed,notifications,profile}, shared code in lib/core, app wiring in lib/app. Read USE_MOCK and API_BASE_URL from --dart-define (mock defaults to true). Add light and dark themes, a placeholder shell, one strings file with the exact copy in brief section 7, and one endpoints.dart with every path in API.md. Every future screen will use a shared loading / empty / error-with-retry / success widget; add that widget now. Do not build feature screens, models, or API calls yet.

Run dart format ., flutter analyze (zero issues), and flutter test.

Append the results into LOGS.md as per the format provided in it.
```

### Phase 1: Models and repositories

```
Do Phase 1 (Models and repositories) only, then stop.

Frontend only. Read AGENTS.md, LOGS.md (snapshot, open decisions, last 3 runs), DATA.md, and API.md.

Add freezed + json_serializable models exactly as DATA.md section 3, in the feature folders named there. Group-facing code must not import RawMessage. Enums must use the safe fallbacks in DATA.md section 4. Add repository interfaces plus Mock*Repository implementations that cover the mock seed checklist in DATA.md section 7, switched later by USE_MOCK. No screens. No Dio calls. Do not hand-edit generated files; run build_runner.

Run dart format ., flutter analyze (zero issues), and flutter test. Include a test that group-facing libraries do not import RawMessage.

Append the results into LOGS.md as per the format provided in it.
```

### Phase 2: Auth and shell

```
Do Phase 2 (Auth and shell) only, then stop.

Frontend only. Read AGENTS.md, LOGS.md (snapshot, open decisions, last 3 runs), brief sections 3 and 7, and API.md section 3.

Build Log in, Create account, and Profile using the mock auth repository. Store the token only in flutter_secure_storage. Signed-out users go to Log in. Add the bottom navigation: Groups, Feed, Notifications, Profile. Placeholder bodies are fine for tabs that later phases own. Add the controller-route guard so non-controllers cannot open review routes. Use the strings file. Handle loading, empty, error with retry, and success. Widgets must not call Dio.

Run dart format ., flutter analyze (zero issues), and flutter test.

Append the results into LOGS.md as per the format provided in it.
```

### Phase 3: Groups

```
Do Phase 3 (Groups) only, then stop.

Frontend only. Read AGENTS.md, LOGS.md (snapshot, open decisions, last 3 runs), brief sections 3, 4, and 7, API.md sections 4 and 5, and DATA.md.

Build the groups list, create group (agenda only), members, group chat, and my messages. Chat uses only PublishedMessage. A null display sender renders "Anonymous user". My messages shows status only (Pending, Accepted, Rejected) and no message text. Use mock repositories. Handle loading, empty, error with retry, and success. Do not add the composer yet. Do not import RawMessage from this feature.

Run dart format ., flutter analyze (zero issues), and flutter test.

Append the results into LOGS.md as per the format provided in it.
```

### Phase 4: Composer and anonymity

```
Do Phase 4 (Composer and anonymity) only, then stop.

Frontend only. Read AGENTS.md section 4 and LOGS.md (snapshot, open decisions, last 3 runs), plus brief sections 4 and 7.

Add the contributor composer on the group chat. The "Anonymous message" checkbox sits immediately before Send, with this disclosure beside it: "Anonymous messages are hidden from the group but visible to the controller." Sending creates a pending message and does not publish it into the chat. The controller has no composer (D6). There is no "show original" control. Do not log message text.

Run dart format ., flutter analyze (zero issues), and flutter test.

Append the results into LOGS.md as per the format provided in it.
```

### Phase 5: Controller review

```
Do Phase 5 (Controller review) only, then stop.

Frontend only. Read AGENTS.md section 4 and LOGS.md (snapshot, open decisions, last 3 runs), plus brief sections 4 and 7, API.md section 6, and DATA.md.

Build the review queue and review detail inside features/review, using RawMessage only there. Show original, rewrite, real sender, anonymity flag, intent score, and relevance. Show "Relevance is a suggestion. You decide." Relevance never hides a message. Show "Rewrite unavailable" when the pipeline failed, "Waiting to rewrite" when queued, and "Rewriting…" when processing. Accept and Reject have no reason field and do not edit the rewrite. Non-controllers hitting these routes are redirected. Do not block the UI on the pipeline.

Run dart format ., flutter analyze (zero issues), and flutter test.

Append the results into LOGS.md as per the format provided in it.
```

### Phase 6: Notifications

```
Do Phase 6 (Notifications) only, then stop.

Frontend only. Read AGENTS.md, LOGS.md (snapshot, open decisions, last 3 runs), brief section 7, API.md section 8, and DATA.md.

Build the notifications list and unread badge. Rejection copy is "Your message in {agenda} was rejected." with no reason. Pending-review copy is "A message in {agenda} is waiting for your review." Unknown types render the generic string and do not crash. Mark one as read. Refresh on pull-to-refresh and when the app resumes (polling, D10). Handle loading, empty, error with retry, and success.

Run dart format ., flutter analyze (zero issues), and flutter test.

Append the results into LOGS.md as per the format provided in it.
```

### Phase 7: Public feed

```
Do Phase 7 (Public feed) only, then stop.

Frontend only. Read AGENTS.md, LOGS.md (snapshot, open decisions, last 3 runs), brief sections 3 and 7, API.md section 7, and DATA.md.

Build the feed, new post, post detail, comments, and like / unlike. Authors are always shown. There is no anonymity. Show "Flagged" when nsfw_flag is true, and tolerate unknown keys in other_flags. "Create group from this post" appears only for the post author. Handle loading, empty, error with retry, and success.

Run dart format ., flutter analyze (zero issues), and flutter test.

Append the results into LOGS.md as per the format provided in it.
```

### Phase 8: Polish and tests

```
Do Phase 8 (Polish and tests) only, then stop.

Frontend only. Read AGENTS.md sections 4, 6, and 7, LOGS.md (snapshot, open decisions, last 3 runs), and brief section 8.

Check every screen for loading, empty, error with retry, and success. Check semantic labels, 48dp tap targets, text scaling, and contrast in both themes. Add or fix tests for: anonymous sender renders "Anonymous user"; no show-original affordance; disclosure sits with the checkbox; group-facing code does not import RawMessage; unknown enum values do not throw; controller routes redirect. Fix only gaps. Do not add out-of-scope features.

Run dart format ., flutter analyze (zero issues), and flutter test.

Append the results into LOGS.md as per the format provided in it.
```

### Phase 9: Real API

```
Do Phase 9 (Real API) only, then stop.

Frontend only. Read AGENTS.md, LOGS.md (snapshot, open decisions, last 3 runs), and API.md.

Add Api*Repository implementations for every repository interface, using Dio only inside those classes. Paths come from endpoints.dart. Map the error body in API.md to the human-readable strings. 401 clears the session and goes to Log in. 403 on controller routes redirects away. USE_MOCK=false selects the API implementations. Do not add backend, SQL, Redis, or NLP code. If the contract is wrong, update API.md and DATA.md in this run and say so.

Run dart format ., flutter analyze (zero issues), and flutter test.

Append the results into LOGS.md as per the format provided in it.
```

### Resume prompt

```
You are working in the Flutter frontend repo only. Read AGENTS.md fully. Read LOGS.md (Status Snapshot, Open Decisions, and the last 3 run entries). Read the brief sections for the current phase.

Continue from the next step in the Status Snapshot. Do one phase only, then stop. Follow the hard rules. Do not invent out-of-scope features.

Append the results into LOGS.md as per the format provided in it.
```
