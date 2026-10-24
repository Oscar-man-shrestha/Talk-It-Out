# Talk It Out — Backend (v1 + slice 2)

Express + PostgreSQL 16 backend for the Talk It Out Flutter app. Implements
auth, groups with moderated (rewrite-before-publish) messaging and controller
operations (direct announcements, message deletion, member removal, leave),
notifications, and the public feed (posts, comments, like reactions, and
post-to-group conversion). The HTTP contract is defined by the Flutter
`Api*Repository` classes; see `API.md` at the repo root.

The rewrite pipeline is a **stub** (`src/worker/stubWorker.ts`), clearly not
NLP. Feed content analysis goes through an isolated provider boundary
(`src/feed-analysis/`, contract_version 1) with a deterministic **fake**
provider (`FEED_PROVIDER=fake`); a real Team 12 adapter would implement the
same internal contract without touching the database.

## Groups rewrite pipeline (external Python worker)

The real groups pipeline is built by a teammate in Python and plugs in through
the versioned contract in `docs/groups-pipeline-contract.md`
(contract_version: 1). The backend contains no NLP logic.

- `PIPELINE_MODE=stub` (default): the in-process stub worker runs as today.
- `PIPELINE_MODE=external`: the stub worker is suppressed; the Python worker
  claims jobs at `POST /internal/pipeline/claim` and reports via
  `/internal/pipeline/result` or `/internal/pipeline/fail`, authenticated
  with the `X-Pipeline-Key` header (`PIPELINE_API_KEY`; unset disables the
  internal API with 503). The worker never touches the database and never
  receives sender identity or `is_anonymous`.
- `scripts/fake-external-worker.sh` is a **test tool** (not a pipeline) that
  claims one job and posts a canned result.
- Submissions longer than `PIPELINE_MAX_INPUT_CHARS` are rejected with 422.

## Feed analysis notes

- Posts and comments are analyzed asynchronously through the `jobs` outbox
  (job kind `analyze_feed_content`, separate worker loop from the groups stub
  worker, so feed problems cannot block groups processing).
- The client's Post/Comment models cannot represent pending/failed/unavailable
  analysis, so the API serializes `nsfw_flag=false` / `other_flags={}` unless
  `analysis_status='complete'`; the true status is kept in the database and is
  never treated as "verified safe" internally.

## Stack

TypeScript, Express 5, PostgreSQL 16 (`pg`, plain SQL migrations, no ORM),
zod validation, argon2 password hashing, jsonwebtoken access tokens,
vitest + supertest tests, eslint.

## Setup

```bash
# 1. Postgres 16 on host port 5433 (app db + separate test db)
docker compose up -d

# 2. Config
cp .env.example .env   # then set a real JWT_SECRET

# 3. Install + create tables
npm install
npm run migrate

# 4. Run (dev, auto-restart)
npm run dev
```

The same router is served at `/` and `/api/v1`, so both
`http://localhost:3000/health` and `http://localhost:3000/api/v1/health` work.
Set `RUN_STUB_WORKER=true` to run the stub rewrite worker in-process and
`RUN_FEED_WORKER=true` (with `FEED_PROVIDER=fake`) to run the feed analysis
worker in-process.

## Tests / lint

```bash
npm test        # vitest + supertest against the TEST database only
npm run lint    # eslint
npm run build   # tsc -> dist/
npm start       # node dist/server.js
```

## Migrations

Numbered `.sql` files in `migrations/`, applied in order by
`npm run migrate` and recorded in `schema_migrations`. Never edit an applied
migration — add a new numbered file instead.

## Not in this slice

Real NLP rewrite pipeline (stub only), a real feed moderation provider
(fake only), profiles, WebSockets, controller transfer, editing posts or
comments (the `content_revision` guard is already in place for it).
