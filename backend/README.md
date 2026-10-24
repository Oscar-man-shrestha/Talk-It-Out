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

## Production checklist

**Environment & secrets**

- Copy `.env.example` to `.env` and fill every secret. `JWT_SECRET` is
  required: at least 32 characters, never the placeholder (startup fails
  otherwise outside tests). Same rule for `PIPELINE_API_KEY` when set.
  Generate with
  `node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"`.
- Set `CORS_ORIGINS` to the exact origins the Flutter web build is served
  from; never `*` in production.
- Set `JWT_EXPIRES_IN` deliberately (default 7d; there are no refresh tokens).

**Network**

- Terminate HTTPS at a reverse proxy (nginx/Caddy/ALB); the app itself
  speaks HTTP. Forward `X-Forwarded-For` and set `TRUST_PROXY` to the
  number of trusted proxy hops, or per-IP rate limits see the proxy's IP.
- Keep `/internal/pipeline/*` bound to localhost or a private network; it is
  authenticated by `PIPELINE_API_KEY` but not meant to be public.

**Single-instance caveats (in-memory state)**

- Rate limits (global/auth/internal) and per-account login throttling use
  in-memory stores, and both workers run in-process. Running more than one
  API instance requires a shared rate-limit store such as Redis, moving the
  workers out-of-process (one claimant per job kind), and making login
  throttling shared — otherwise limits and locks are per instance.

**Database**

- Back up Postgres on a schedule (`pg_dump` or volume snapshots); test a
  restore. Apply migrations with `npm run migrate` during deploys — the
  runner is idempotent and records applied files in `schema_migrations`.
  Never edit an applied migration; add a new numbered one.
- Pool and timeouts are tunable: `PG_POOL_MAX`, `PG_IDLE_TIMEOUT_MS`,
  `PG_STATEMENT_TIMEOUT_MS`, `PG_CONNECT_TIMEOUT_MS`.

**Operations**

- `GET /health` is a cheap liveness probe (never touches the DB);
  `GET /ready` returns 503 when the database is down — use it for
  readiness checks.
- SIGTERM/SIGINT drain gracefully: workers stop, the pool closes, exit
  within 10s.
- `JSON_BODY_LIMIT` caps request bodies (default 100kb). `npm audit`
  regularly; see the Run 040 LOGS entry for the current findings and why
  the available fixes (vitest 5 / zod 4) were not applied blindly.

## Not in this slice

Real NLP rewrite pipeline (stub only), a real feed moderation provider
(fake only), profiles, WebSockets, controller transfer, editing posts or
comments (the `content_revision` guard is already in place for it).
