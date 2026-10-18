# Talk-It-Out

## Collaboration Platform: Flutter Frontend

Frontend-only repo for a collaboration platform with controller-moderated **Groups**, a **Public Feed**, and per-message **Anonymity**. The backend (Express, BullMQ + Redis, Neon PostgreSQL, NLP pipelines) lives elsewhere. This app talks to it over HTTP (see `API.md`).

## Prerequisites

- Flutter (stable channel) with Dart SDK included. Check with `flutter --version` and `flutter doctor`.
- An Android emulator, iOS simulator, or a physical device.
- (Later, Phase 9) A running backend or its base URL.

## Setup

```bash
# 1. Get dependencies
flutter pub get

# 2. Generate freezed / json_serializable code
dart run build_runner build --delete-conflicting-outputs
```

If the Flutter project has not been scaffolded yet, Phase 0 of the build does it (see `CURSOR_FRONTEND_BRIEF.md`). You can also do it yourself in the repo root:

```bash
flutter create --org com.yourorg --platforms=android,ios .
```

## Run

The app reads its config from `--dart-define`:

| Flag | Meaning | Example |
|---|---|---|
| `USE_MOCK` | `true` uses built-in mock data (no backend needed) | `true` |
| `API_BASE_URL` | Backend base URL | `http://10.0.2.2:3000` (Android emulator), `http://localhost:3000` (iOS simulator) |

```bash
# Develop without a backend (default while backend is not ready)
flutter run --dart-define=USE_MOCK=true

Mock login (in-memory only, from `API.md`): `priya@example.com` / `secret123`.
Priya is a contributor in "Making NLP notes" and the controller of "Dashboard improvements".

# Against a real backend
flutter run --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

## Quality checks

```bash
dart format .
flutter analyze      # must report zero issues
flutter test         # must pass
```

While editing models, keep code generation running:

```bash
dart run build_runner watch --delete-conflicting-outputs
```

## Project structure

```
lib/
  main.dart
  app/            router, theme, config, providers
  core/           api client, errors, shared widgets, utils, strings
  features/
    auth/
    groups/       group list, chat (published messages only), composer
    review/       controller-only review queue and detail
    feed/         posts, comments, reactions
    notifications/
    profile/
test/
```

Group-facing code never imports controller-only models. That separation is what keeps anonymous senders hidden.

## Documentation map

| File | What it is |
|---|---|
| `CURSOR_FRONTEND_BRIEF.md` | Product context, screens, acceptance criteria, build phases, ready-to-paste prompts |
| `API.md` | Every endpoint with HTTP methods and JSON shapes |
| `DATA.md` | Backend schema (reference), DTOs, Dart models, visibility matrix, mock seed list |
| `AGENTS.md` | Rules for AI agents working in this repo |
| `LOGS.md` | Project status and a log of every agent run |

## Working with AI agents (Cursor)

1. Open the repo in Cursor. `AGENTS.md` is picked up as agent instructions.
2. Paste **Prompt 0 (Kickoff)** from the brief once, then the **Phase prompts** one at a time. Say "continue" to move to the next phase.
3. Every prompt ends with: `Append the results into LOGS.md as per the format provided in it.` That makes the agent record each run, so any later agent (or you) can read `LOGS.md` and see progress and status immediately.
4. To resume in a fresh chat, use the **Resume prompt** from the brief.

## Core rules in one glance

- Group chat shows only accepted, rewritten messages. Anonymous ones show as **"Anonymous user"**.
- Only the group controller sees the original message, the real sender, the relevance result and the anonymity flag, and only the controller can accept or reject.
- There is no "show original", no rejection reason, no auto-approve.
- The public feed has no anonymity.

Full list: `AGENTS.md` section 4.

## Troubleshooting

| Problem | Fix |
|---|---|
| Generated files missing (`*.g.dart`, `*.freezed.dart`) | Run the `build_runner` command from Setup |
| Android emulator cannot reach local backend | Use `http://10.0.2.2:<port>` instead of `localhost` |
| Stale generated code | `dart run build_runner build --delete-conflicting-outputs` |
| Weird build errors after dependency changes | `flutter clean && flutter pub get` |
# Talk-It-Out
# Talk-It-Out
# Talk-It-Out
