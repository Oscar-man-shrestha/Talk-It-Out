<p align="center">
  <img src="docs/store/icon-512.png" width="96" alt="Talk It Out icon">
</p>

<h1 align="center">Talk It Out</h1>

<p align="center">
  <strong>Say what matters at work, safely.</strong><br>
  Anonymous when it needs to be, rewritten calmly by AI, and reviewed before anyone sees it.
</p>

<p align="center">
  <a href="https://github.com/Oscar-man-shrestha/Talk-It-Out/actions/workflows/flutter-ci.yml"><img src="https://github.com/Oscar-man-shrestha/Talk-It-Out/actions/workflows/flutter-ci.yml/badge.svg" alt="flutter-ci"></a>
  <a href="https://github.com/Oscar-man-shrestha/Talk-It-Out/actions/workflows/backend-ci.yml"><img src="https://github.com/Oscar-man-shrestha/Talk-It-Out/actions/workflows/backend-ci.yml/badge.svg" alt="backend-ci"></a>
  <a href="https://github.com/Oscar-man-shrestha/Talk-It-Out/actions/workflows/pipeline-ci.yml"><img src="https://github.com/Oscar-man-shrestha/Talk-It-Out/actions/workflows/pipeline-ci.yml/badge.svg" alt="pipeline-ci"></a>
  <a href="https://github.com/Oscar-man-shrestha/Talk-It-Out/actions/workflows/stack-ci.yml"><img src="https://github.com/Oscar-man-shrestha/Talk-It-Out/actions/workflows/stack-ci.yml/badge.svg" alt="stack-ci"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-black" alt="MIT license"></a>
</p>

---

Talk It Out is a mobile and web app for honest conversation at work. It combines two things under one account:

- **Groups**, where a team raises difficult topics safely. Members can write anonymously, an AI rewrites every message in a calm tone, and the group's controller reviews each message before anyone else sees it.
- **A community feed**, where anyone can ask workplace questions (pay, managers, burnout, careers) and get answers. The feed is ranked for each person and is never anonymous.

The app is built with Flutter (Android and web), a Node.js and PostgreSQL backend, and a self-hosted language model. It is complete enough to deploy today; see [Deploying for free](#deploying-for-free).

**Read the full product and technical guide: [docs/Talk-It-Out-Guide.pdf](docs/Talk-It-Out-Guide.pdf)** (16 pages, for new users and teammates).

## Contents

- [Why it exists](#why-it-exists)
- [Features](#features)
- [How a group message works](#how-a-group-message-works)
- [Privacy guarantees](#privacy-guarantees)
- [Language technology](#language-technology)
- [Architecture](#architecture)
- [Technology](#technology)
- [Getting started](#getting-started)
- [Testing](#testing)
- [Deploying for free](#deploying-for-free)
- [Project layout](#project-layout)
- [Documentation](#documentation)
- [Status and roadmap](#status-and-roadmap)
- [Contributing, security and license](#contributing-security-and-license)

## Why it exists

People hold back at work. Feedback about a manager, a broken process, pay or burnout feels risky to say with your name, while fully anonymous tools invite abuse and heated wording starts arguments. Talk It Out gives teams a middle ground: anonymity where it helps, calm wording, and a human who checks every message before it is shared.

## Features

**Groups and chat**
- Create a group around an agenda; the creator becomes its **controller**. Add members with typo-tolerant people search, or share an **invite link or QR code** that can expire or have a use limit.
- Send messages with your name or **anonymously**. Preview the AI wording before sending, and get a gentle tone hint while typing.
- Replies (also by swiping a message), photos (stripped of location and camera data), reactions, pins, polls, search, @mentions, a "New messages" divider and saved drafts.
- **Catch up:** an automatic, name-free summary of a busy conversation.
- **Group info:** a description and rules from the controller, plus your own mute and pin.

**Controller review**
- The original message next to the AI rewrite, with a word-level difference and advisory scores (meaning kept, relevance).
- Accept publishes the rewrite; reject publishes nothing and gives no reason. Ask the AI for a new rewrite at any time.
- An Approved and Rejected history.

**Community feed**
- Ask a question with a title, topic and details. Topic suggestions and "Already asked?" similar questions appear while you type.
- **For You** ranks questions from 30 interests, picked and learned, and every question says why it is shown. **Latest** has filters, sorting and endless scrolling.
- Search that understands typos and word families.
- Answers with upvotes, a **best answer** chosen by the asker, following questions, edits marked as edited, likes with "Liked by", and sharing.

**People and safety**
- Profiles with @handles, skills, experience and shared groups.
- Block people, report questions and comments, and turn personalisation off.
- Delete your account in the app.

**Getting started in the app**
- A short welcome tour for new accounts, helpful empty screens, "Continue as" accounts on the sign-in screen, and Sign in with Google.
- Privacy policy, terms and account deletion pages, in the app and on the web.

## How a group message works

```
 1. Write          2. Queue              3. Rewrite              4. Review               5. Publish
 member types,  →  stored as pending  →  worker asks the     →   controller sees    →   approved rewrite only;
 may tick          with a rewrite job    model, checks and       original + rewrite,     anonymous messages
 Anonymous                               scores the result       accepts or rejects      store no author
```

If the controller rejects a message, nothing is published and the sender gets a plain notification without a reason. The group only ever reads published, approved text.

## Privacy guarantees

Anonymity is enforced by the data model, not just hidden in the interface.

- **Two tables.** `raw_messages` holds the original wording and the real sender, and only the group's controller can read it. `published_messages` holds approved text; for an anonymous message the author is stored as empty, and a database constraint enforces this.
- **The controller can always see the sender.** The app says so next to the Anonymous checkbox every time. Talk It Out never claims more anonymity than it gives.
- **No "show original" control exists anywhere**, and the app's group screens use a model without original-text or real-sender fields. A test fails the build if review code is used elsewhere.
- **Message text and sender identity are never logged**, cached or sent to analytics. Mentions and summaries never name senders, and group reactions show counts only.
- Feed activity used for ranking is deleted after 180 days. Account deletion keeps published group messages but makes them anonymous.

## Language technology

Only the message rewrite uses a large language model. Everything else is fast, explainable classic NLP that runs on the server or on the phone, so text is never sent to a third-party AI company.

| Feature | Technique |
|---|---|
| Message rewrite | Qwen2.5-3B-Instruct, self-hosted through Ollama. Prompt-injection defence, deterministic output validation, scores for meaning kept and relevance. |
| People search | Accent folding, Damerau-Levenshtein and Jaro-Winkler distance, phonetic keys, Postgres trigram indexes. |
| Topics and interests | A lexicon classifier over 30 interests, with stemming. |
| For You | Interests, TF-IDF similarity, engagement with time decay, a network bonus and freshness, then diversity and exploration. Each result has a reason. |
| Search and "Already asked?" | BM25 with stemming, typo and prefix expansion, and "did you mean". |
| Catch up | Extractive TextRank (PageRank over TF-IDF sentence similarity). |
| Tone hint | On-device patterns for insults, blame, absolutes and shouting. Nothing is sent anywhere. |

## Architecture

```
  Flutter app (Android, web)
        │  HTTPS (REST + Server-Sent Events)
        ▼
  Express API (Node.js, TypeScript) ──────── Google Sign-In, Gmail SMTP
        │  SQL                        ▲
        ▼                             │ internal HTTP (claim / result), key-protected
  PostgreSQL 16                 Rewrite worker (Python) ──── Ollama (Qwen2.5-3B)
  tables, NOTIFY triggers,
  jobs outbox
```

- **Live updates:** Postgres triggers send `NOTIFY` events, each API instance `LISTEN`s and pushes Server-Sent Events, and the app refreshes only what changed. This works across several API instances without Redis.
- **Jobs:** a jobs table works as an outbox with leases, retries and back-off. The rewrite worker claims one job at a time over a versioned internal contract, never touches the database, and never receives sender identity.
- **The app** has a Mock and an API implementation for every data source, switched at build time. The whole app runs offline as a demo.

## Technology

| Layer | Technology |
|---|---|
| App | Flutter 3.47 (Dart), Riverpod 3, go_router, Dio, freezed |
| API | Node.js 20+, Express 5, TypeScript, Zod, node-postgres, Argon2 |
| Database | PostgreSQL 16 with pg_trgm |
| AI worker | Python 3 (standard library only), any OpenAI-compatible model server |
| Model | Qwen2.5-3B-Instruct through Ollama |
| Delivery | Docker Compose, GitHub Actions (four CI workflows), Render blueprint, GitHub Pages |

## Getting started

### Demo mode (no server needed)

```bash
flutter pub get
flutter run -d chrome --dart-define=USE_MOCK=true
```

On the sign-in screen choose **Use the demo account**. The sample user, Priya, is a member of one group and the controller of another, so you can try both sides.

### Full stack on your computer

Requirements: Flutter 3.47, Node.js 20+, PostgreSQL 16, Python 3.10+, and Ollama for real rewrites.

```bash
# 1. API
cd backend
cp .env.example .env           # set DATABASE_URL, JWT_SECRET and PIPELINE_API_KEY
                               # (openssl rand -hex 32), and PIPELINE_MODE=external
npm install
npm run migrate
npm run dev                    # http://localhost:3000

# 2. Rewrite worker (separate terminal)
ollama pull qwen2.5:3b
cd pipeline
cp .env.example .env           # same PIPELINE_API_KEY as backend/.env
python3 -m talkitout_pipeline

# 3. App (separate terminal)
flutter run -d chrome --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=http://localhost:3000
```

Without the worker, set `PIPELINE_MODE=stub` in `backend/.env` to get clearly labelled placeholder rewrites instead. Optional starter content: `npm run seed:questions` (in `backend`) adds 61 questions covering all 30 interests.

### Everything with Docker

```bash
cp .env.stack.example .env     # set POSTGRES_PASSWORD and JWT_SECRET
docker compose up -d --build   # web on :8080, API on :3000
```

## Testing

| Suite | Command | Covers |
|---|---|---|
| App | `flutter test` | Screens and flows, privacy rules, review, feed, groups, safety, onboarding |
| API | `cd backend && npm test` | Every route against a real Postgres, including privacy sweeps |
| Rewrite worker | `cd pipeline && python3 -m unittest discover -s tests -t .` | Contract, prompt-injection layer, validation, scoring |
| End to end | `node backend/scripts/live-check.mjs http://localhost:3000` | A running stack, including real rewrites |
| Static checks | `dart format`, `flutter analyze`, `tsc`, `eslint` | Formatting, types, lint |

All four suites run on every push in GitHub Actions.

## Deploying for free

You can put Talk It Out online without paying anything, using free tiers:

| Part | Free service |
|---|---|
| Database | Neon (Postgres, 0.5 GB) |
| API | Render free web service (sleeps after 15 idle minutes) |
| Web app | GitHub Pages, using the included `deploy-web` workflow |
| AI rewrites | Ollama and the worker on your own computer. They only make outgoing requests, so no ports or tunnels are needed. |
| Phones | "Add to Home screen" from the web app, or an APK shared directly |

The repository includes a Render blueprint (`render.yaml`) and a GitHub Pages workflow (`.github/workflows/deploy-web.yml`). **Step-by-step instructions: [docs/DEPLOY.md](docs/DEPLOY.md).** For a paid single-server setup and the Google Play release, see the same guide and [docs/PLAY_STORE.md](docs/PLAY_STORE.md).

## Project layout

```
lib/                 Flutter app (features: auth, groups, review, feed, discovery,
                     invites, onboarding, notifications, profile, legal)
test/                Flutter tests
backend/             Express API: src/routes, src/nlp, migrations, tests
pipeline/            Python rewrite worker and its tests
assets/legal/        Privacy policy, terms and account deletion (shown in the app)
docs/                Guide PDF, deployment, Play Store, startup plan, setup guides
tool/                Icon and guide generators
API.md               The HTTP contract (sections 1 to 68)
LOGS.md              Project log, open decisions and test results
```

## Documentation

| Document | Contents |
|---|---|
| [docs/Talk-It-Out-Guide.pdf](docs/Talk-It-Out-Guide.pdf) | Product and technical guide: features, architecture, privacy, running |
| [docs/DEPLOY.md](docs/DEPLOY.md) | Free deployment step by step, and the paid single-server setup |
| [docs/PLAY_STORE.md](docs/PLAY_STORE.md) | Google Play release: signing, listing text, Data safety answers |
| [docs/STARTUP_PLAN.md](docs/STARTUP_PLAN.md) | Product research, NLP roadmap, metrics and launch plan |
| [docs/SETUP_GOOGLE_AND_EMAIL.md](docs/SETUP_GOOGLE_AND_EMAIL.md) | Google Sign-In and Gmail for password-reset email |
| [API.md](API.md) | Every endpoint with request and response shapes |
| [backend/README.md](backend/README.md) | API setup, configuration and production checklist |
| [pipeline/README.md](pipeline/README.md) | Rewrite worker configuration and safety rules |
| [backend/docs/groups-pipeline-contract.md](backend/docs/groups-pipeline-contract.md) | Internal contract between the API and the worker |
| [LOGS.md](LOGS.md) | Project history, open decisions and test results |

## Status and roadmap

All features above are built and tested, and continuous integration passes. The Android project is prepared for Google Play: app name, icon, internet permission, release signing and legal pages.

**Next**
- Public deployment
- Push notifications and crash reporting (Firebase)
- Verified app links

**Then**
- Meaning-based search with embeddings
- Thread summaries for controllers
- Smart replies
- Nepali and Hindi

**Later**
- Organisation workspaces
- Moderation tools
- iOS

## Contributing, security and license

- Contributions are welcome; see [CONTRIBUTING.md](CONTRIBUTING.md). Privacy rules in `AGENTS.md` apply to every change.
- Report security issues privately as described in [SECURITY.md](SECURITY.md).
- Contact: talkitoutapp.mail@gmail.com
- Released under the [MIT License](LICENSE).
