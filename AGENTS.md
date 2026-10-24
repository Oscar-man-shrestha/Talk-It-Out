# AGENTS.md: Rules for Agents

This file applies to every AI agent working in this repo, including Cursor and Google Antigravity. Antigravity loads this file as an always-on rule. Read it fully at the start of every run.

## 0. Continue from here

Phases 0–9 are already built, and the UI overhaul (logged as phase 10) is done. The Flutter app is in this repo. Do not run `flutter create`. Do not rebuild models, screens, repositories, the router, or the theme unless the user asks for a specific fix.

`LOGS.md` is the living status. Read its **Status Snapshot**, **Open Decisions**, and the **last 3 run entries** before changing anything. If this section and `LOGS.md` disagree about progress, trust `LOGS.md` for status and trust the hard rules in this file for behavior.

**What is already in the app**
- Auth: login, register, session, logout. Tokens live only in `flutter_secure_storage`.
- Shell: bottom nav for Groups, Feed, Notifications (unread badge), and Profile.
- Groups: list, create, chat, members, and "My messages" (status only, no message text, no rejection reason).
- Composer: contributors only. The "Anonymous message" checkbox and its disclosure sit immediately before Send. Sending does not publish into the chat.
- Review: controller only. Non-controllers are redirected. Accept publishes the rewrite. Reject does not. There is no rewrite editor and no rejection-reason field.
- Feed: posts, comments, like, and "Create group from this post" for the post author only. Authors are always visible. There is no anonymity in the feed.
- Notifications: list, mark read, unread count. Copy has no reason slot.
- Data: `Mock*Repository` when `USE_MOCK` is true (the default). `Api*Repository` when it is false. Widgets never call Dio. A live backend has not been verified.

**Mock login** (in memory only, from `API.md`): `priya@example.com` / `secret123`. Priya is a contributor in "Making NLP notes" and the controller of "Dashboard improvements". She can send in the first group and review only the second. Controllers have no composer.

**Preview on this Mac.** There is no Android emulator and Xcode is incomplete, so use the web server:

```bash
flutter run -d web-server --web-hostname=127.0.0.1 --web-port=52000 --dart-define=USE_MOCK=true
```

Then open `http://127.0.0.1:52000/#/login`. `ERR_CONNECTION_REFUSED` (error -102) means nothing is listening. Check `lsof -nP -iTCP:52000 -sTCP:LISTEN`. If that is empty, start the command above. If `curl -I http://127.0.0.1:52000/` returns 200 and the browser still refuses, the browser is not reaching this machine's loopback (proxy or VPN). The server binds only to `127.0.0.1`.

**Where to look**
- Routes and guards: `lib/app/router.dart`. Shell: `lib/app/shell.dart`.
- Mock versus API switch: `lib/app/repository_providers.dart`.
- Endpoint paths: `lib/core/api/endpoints.dart`. User-facing copy: `lib/core/strings/app_strings.dart`.
- Screens: `lib/features/{auth,groups,review,feed,notifications,profile}`.
- `RawMessage` stays inside `lib/features/review`. `test/no_raw_message_import_test.dart` enforces that.
- Product copy and acceptance: `CURSOR_FRONTEND_BRIEF.md`. HTTP contract: `API.md`. Models and seed: `DATA.md`.
- Python NLP rewrite worker: `pipeline/` (a separate Python component at the repo root, not part of the Flutter app). Its rules live in `pipeline/AGENTS.md`; it talks to the backend only through the HTTP contract in `backend/docs/groups-pipeline-contract.md`.

**Layout constraints from the UI overhaul**
- Do not wrap a `ListView` in a `ResponsiveContainer` or `ConstrainedBox`. That clips the test viewport and breaks `test/privacy_ui_test.dart`. Widen screens with inline `hPad` from `MediaQuery`: `screenWidth > 860 ? (screenWidth - 800) / 2 : 16.0`, applied as padding.
- The shell must keep a `NavigationBar`. `privacy_ui_test.dart` finds `NavigationBar`.
- `MessageStatus` is only `pending`, `accepted`, and `rejected`. There is no `unknown` value.
- Theme colors live in `lib/app/theme.dart` and follow the downloaded Stitch export **Monochrome Precision** (light): canvas `#FFFFFF` / `#FAFAFA`, border `#E4E4E7`, text `#09090B`, secondary text `#71717A`, primary black buttons, white cards, 4–12px radii. `TalkItOutApp` uses `ThemeMode.light`. Do not restore the older lavender/dark palette (`#8083FF`, `#0F131D`).

**If the user says "continue"**
Do the **Next step** in the `LOGS.md` Status Snapshot, then stop and append a run entry. As of 2026-10-15 the next step is to wait for a product or API decision on open items D1–D13. Do not implement those open items unless the user decides them. Do not start another visual redesign unless the user asks.

**Leave alone unless the user asks**
- Finished phases, unrelated refactors, and new dependencies.
- Out-of-scope v1 features listed in section 4.
- Backend, NLP, SQL, Redis, or infrastructure.
- Git commits and pushes.
- Pointing `USE_MOCK=false` at a guessed server URL.

Last known quality gates (Run 010): `dart format` pass, `flutter analyze` 0 issues, `flutter test` 24 passed. After any code change, run the gates in section 7 again. Never claim a gate passed if you did not run it. Google Stitch mockups for Login, Groups, Chat, and Review are in Stitch project `11580632017565253805`. Do not put API keys in this repo.

## 1. Mission and scope

- This repo is the **Flutter frontend** of a collaboration platform (groups, public feed, per-message anonymity). Product details: `CURSOR_FRONTEND_BRIEF.md`.
- **Never** write or add backend code (Express, BullMQ, Redis, SQL migrations), or infrastructure, and never touch database access, schema, or migrations. The backend under `backend/` is another team's job. The app talks to it only through the HTTP API in `API.md`.
- **Exception — the Python NLP worker:** implementing and maintaining the separate Python HTTP worker under `pipeline/` is permitted. It is governed by `pipeline/AGENTS.md` and must communicate with the backend **only** through the documented HTTP contract (`backend/docs/groups-pipeline-contract.md`); it must never access the database directly. Do not modify Flutter frontend code (`lib/`, `test/`), backend implementation, or infrastructure unless separately authorized.
- Never modify files outside this repo.

## 2. Start-of-run checklist

1. Read this file.
2. Read `LOGS.md`: the **Status Snapshot**, **Open Decisions**, and the **last 3 run entries**. That is how you know where the project stands.
3. Read the sections of `CURSOR_FRONTEND_BRIEF.md` relevant to the task, plus `API.md` and `DATA.md` when touching data or networking.
4. Do only what the prompt asks. Phases 0–9 are done (section 0). Do not start another build phase unless the user asks for one. If they say "continue", do the Next step in `LOGS.md` and stop.

## 3. Source of truth (if documents disagree)

1. Hard rules in this file
2. `CURSOR_FRONTEND_BRIEF.md`
3. `API.md` and `DATA.md`
4. The prompt in the current run (if it conflicts with 1, refuse that part and log why)

## 4. Hard rules (never break, never weaken to make something easier)

**Privacy and anonymity**
1. Group-facing screens use **only** `PublishedMessage`. Sender is nullable; null renders **"Anonymous user"**. The model has no original-text field and no real-sender field.
2. Controller-facing screens use the separate `RawMessage` model, only inside `features/review`. Never import it from group-facing or contributor code.
3. Contributors can never see another contributor's original text. **No "show original" UI exists** (no button, toggle, long-press, hidden menu).
4. The anonymity disclosure is always shown next to the checkbox: "Anonymous messages are hidden from the group but visible to the controller."
5. Never log, cache, or print raw message text or sender identity (debug prints, analytics, crash reports).
6. Controller-only routes are guarded; non-controllers are redirected.
7. The anonymity checkbox ("Anonymous message") sits just before the send action.

**Out of scope for v1 (do not build, even if asked casually; log the conflict instead)**
- Auto-approve, deputies, timeouts, bulk approve for the controller
- Editing the rewrite
- Rejection reasons or any rejection feedback beyond the plain notification
- Audit log or controller accountability UI
- Anonymity in the public feed
- Auto-rejecting or hiding messages based on relevance (relevance is advisory only)
- Inventing controller-transfer behavior (open item)

## 5. Architecture rules

- Feature-first folders: `lib/features/{auth,groups,review,feed,notifications,profile}`; shared code in `lib/core`; app wiring in `lib/app`.
- State: Riverpod (`AsyncNotifier`). Routing: `go_router`.
- All data access goes through repository interfaces with two implementations: `Mock*Repository` and `Api*Repository`. Switched by `USE_MOCK` (`--dart-define`). Widgets never call Dio directly.
- All endpoint paths live in one `endpoints.dart`.
- All user-facing strings live in one strings file. Use the exact copy in the brief (section 7).
- Every screen handles **loading, empty, error (with retry), success**.
- Never block the UI on NLP. Handle `pending` and `processing` gracefully. Never optimistically publish a message.
- Enum parsing must tolerate unknown backend values (safe fallback, no crash).

## 6. Code conventions

- Dart null safety; no `dynamic` unless unavoidable; prefer `freezed` immutable models.
- Do not hand-edit generated files (`*.g.dart`, `*.freezed.dart`). Regenerate with `dart run build_runner build --delete-conflicting-outputs`.
- Small, focused files and widgets; no giant build methods.
- No hardcoded base URLs, tokens, or secrets. Use `--dart-define`. Store tokens only in `flutter_secure_storage`.
- Do not add a new dependency without a reason; if you add one, record it and the reason in `LOGS.md`.
- Accessibility: semantic labels, minimum 48dp tap targets, support dynamic text size, readable contrast in both themes.
- User-facing errors are human-readable. Never show raw exceptions.

## 7. Quality gates (before ending any run that changed code)

```
dart format .
flutter analyze        # zero issues
flutter test           # all passing
```

If a gate fails and you cannot fix it, say so plainly in `LOGS.md`. Never claim a gate passed if you did not run it.

## 8. Working style

- Small, reviewable changes. Do not refactor unrelated code.
- When the docs are silent, choose the simplest reasonable option, **record it in LOGS.md under "Assumptions / decisions"** and add it to the Open Decisions table if the user should confirm it. Do not stop and wait unless the issue touches a hard rule.
- If a requested change touches a hard rule, do not implement that part. Explain the conflict in `LOGS.md`.
- If `API.md` or `DATA.md` must change (because the code or the backend contract changed), update them in the same run and mention it in the log.
- Be honest in logs: report what is done, partial, skipped, and broken.

## 9. End-of-run (mandatory)

Every run ends by updating `LOGS.md`, following the format defined in it:

1. Update the **Status Snapshot** (phase table, current phase, next step, blockers, last updated).
2. Update **Open Decisions** if anything was added or resolved.
3. **Append** a new run entry at the bottom of the run log (never edit or delete previous entries).

The user ends every prompt with "Append the results into LOGS.md as per the format provided in it." If a prompt forgets that line, still do it. A run without a log entry is an incomplete run.
