# Deploying Talk It Out

This guide puts Talk It Out on the internet **for free**, using free tiers only. It takes about an hour the first time. A paid setup for real launch traffic is described at the end.

## The free setup

| Part | Runs on | Cost | Limits |
|---|---|---|---|
| Database | [Neon](https://neon.tech) (Postgres) | Free | 0.5 GB of storage, which is plenty to start; photos are stored in the database, so it fills faster if people share many. |
| API server | [Render](https://render.com) free web service | Free | Sleeps after 15 minutes without traffic. The first request after that takes about a minute. |
| Web app | GitHub Pages | Free (the repository is public) | None that matter here. |
| AI rewrites | Ollama and the rewrite worker on your own computer | Free | Rewrites happen while your computer is on. Messages sent while it is off wait in review until it is back. |
| Email (password reset) | Your Gmail account | Free | About 500 emails a day. |

```
 Phone or browser ──HTTPS──▶ GitHub Pages (web app)
        │
        └──────HTTPS──────▶ Render (API) ◀──HTTPS── your computer:
                               │                     rewrite worker + Ollama
                               ▼
                           Neon (Postgres)
```

The rewrite worker only makes outgoing requests to the API, so your computer needs no open ports, router changes or tunnel.

You need accounts on GitHub (you have one), Neon and Render. Both offer sign-in with GitHub, and neither asks for a card on the free plan.

---

## Step 1: Create the database (Neon)

1. Sign in at neon.tech and create a project, for example `talkitout`, in the region closest to your users.
2. Copy the connection string. It looks like `postgresql://user:password@ep-xxx.region.aws.neon.tech/neondb?sslmode=require`. Keep `?sslmode=require` at the end.
3. Create the tables from your computer:

```bash
cd backend
DATABASE_URL='postgresql://...your Neon string...' npm run migrate
```

You should see `Applied 001_init.sql` through `Applied 023_answers_follows_groups.sql`. Run the same command after every update that adds a migration.

4. Optional starter content, 61 questions across all 30 interests:

```bash
DATABASE_URL='postgresql://...' npm run seed:questions
```

## Step 2: Deploy the API (Render)

1. Sign in at render.com with GitHub and allow it to read the `Talk-It-Out` repository.
2. Choose **New**, then **Blueprint**, pick the repository and the branch you want to deploy. Render reads `render.yaml` from the repository.
3. Render asks for four values:

| Setting | Value |
|---|---|
| `DATABASE_URL` | Your Neon connection string from Step 1. |
| `CORS_ORIGINS` | `https://<your-github-username>.github.io` (all lowercase). |
| `APP_WEB_URL` | `https://<your-github-username>.github.io/Talk-It-Out` |
| `GOOGLE_CLIENT_ID` | Leave empty for now, or see Step 6. |

4. Choose **Apply**. The first build takes a few minutes. When it is live, open `https://talkitout-api.onrender.com/ready` (Render shows the exact address). It should say `{"status":"ready"}`.
5. In the service's **Environment** tab, copy the generated `PIPELINE_API_KEY`. The worker needs it in Step 4.

The blueprint sets `autoDeploy: false`, so pushing code does not redeploy by surprise. Choose **Manual Deploy** in Render when you want an update live.

## Step 3: Publish the web app (GitHub Pages)

1. On GitHub, open the repository's **Settings**, then **Pages**, and under **Build and deployment** choose **GitHub Actions** as the source.
2. In **Settings**, then **Secrets and variables**, then **Actions**, open the **Variables** tab and add:
   - `API_BASE_URL`: your Render address, for example `https://talkitout-api.onrender.com`;
   - `GOOGLE_CLIENT_ID` (optional, see Step 6).
3. Open the **Actions** tab, choose **deploy-web**, then **Run workflow**, on the branch you deployed in Step 2.
4. After about five minutes the app is live at `https://<your-github-username>.github.io/Talk-It-Out/`.

Run the workflow again whenever you want the latest app published.

## Step 4: Turn on AI rewrites (your computer)

Install [Ollama](https://ollama.com), then:

```bash
ollama pull qwen2.5:3b
cd pipeline
cp .env.example .env
```

Edit `pipeline/.env`:

```
PIPELINE_BACKEND_BASE_URL=https://talkitout-api.onrender.com
PIPELINE_API_KEY=<the PIPELINE_API_KEY from Render>
MODEL_ENDPOINT=http://127.0.0.1:11434/v1/chat/completions
MODEL_ID=qwen2.5:3b
MODEL_EXTRA_BODY={"keep_alive":"2h"}
PIPELINE_POLL_INTERVAL_SECONDS=1
```

Start the worker, and leave it running while you want rewrites:

```bash
python3 -m talkitout_pipeline
```

It logs `model warm in ...s`, then `worker loop started`. A rewrite then takes about 2 seconds on a recent laptop. The worker's polling also keeps the free Render service awake while it runs.

If you want group messages to work without your computer, set `PIPELINE_MODE=stub` and `RUN_STUB_WORKER=true` on Render instead. Messages then get a clearly labelled placeholder instead of a real rewrite, which is useful for demos but not for real users.

## Step 5: Try it end to end

1. Open the GitHub Pages address on your phone and choose **Create an account**.
2. Create a group, open **Invite with a link**, and send the link to a second account (or a friend).
3. From the second account, send an anonymous message. With the worker running, the rewrite appears in the controller's review queue within seconds.
4. Accept it and check that it appears in the chat as "Anonymous user".

On a phone, use the browser's **Add to Home screen**. The app then opens full screen with its own icon, like an installed app.

## Step 6: Optional extras (still free)

- **Password-reset email:** in Render set `MAIL_TRANSPORT=smtp`, `SMTP_HOST=smtp.gmail.com`, `SMTP_PORT=465`, `SMTP_USER` (your Gmail address), `SMTP_PASS` (a Gmail app password) and `MAIL_FROM`. See `docs/SETUP_GOOGLE_AND_EMAIL.md`.
- **Sign in with Google:**
  1. Create an OAuth web client in Google Cloud Console and add `https://<your-github-username>.github.io` as an authorised JavaScript origin.
  2. Put the client ID in Render (`GOOGLE_CLIENT_ID`) and in the GitHub variable of the same name.
  3. Redeploy both.
- **Keep the API awake without your computer:** a free monitor such as UptimeRobot can open `/ready` every 10 minutes. One always-on free service uses about 720 of Render's 750 free hours a month.
- **Android app file for testers:** with the Android SDK installed, build an APK and share it through a GitHub Release. Testers allow "install unknown apps" once.

  ```bash
  flutter build apk --release --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=https://talkitout-api.onrender.com
  ```

## Troubleshooting

| Symptom | Fix |
|---|---|
| The app says it cannot reach the server | Open `<API>/ready`. If it is slow, the free service was asleep; wait a minute. Check `API_BASE_URL` in the GitHub variable, then run the workflow again. |
| Sign-in fails with a network error in the browser console mentioning CORS | `CORS_ORIGINS` on Render must be exactly `https://<username>.github.io`, with no path and no trailing slash. |
| Messages stay "rewriting" | The worker is not running, or its `PIPELINE_API_KEY` does not match Render's. The worker log says `invalid_pipeline_key` in that case. |
| Invite links open the wrong address | Set `APP_WEB_URL` on Render to the GitHub Pages address. |
| Render build fails | Use the branch that contains `render.yaml` and `backend/Dockerfile`. |
| Neon errors about SSL | Keep `?sslmode=require` at the end of `DATABASE_URL`. |

## When you are ready to pay: one server for everything

For real users, move everything to one virtual server: 8 GB of RAM, about US$10–25 a month at Hetzner, DigitalOcean or similar. This way rewrites do not depend on your laptop and nothing sleeps.

1. Install Docker, then copy `.env.stack.example` to `.env` and fill it in (secrets from `openssl rand -hex 32`).
2. Run `docker compose up -d --build`. This starts Postgres, migrations, the API and the web app.
3. Install Ollama on the server, and run the worker as a service. Use `MODEL_EXTRA_BODY={"keep_alive":"-1"}` so the model never unloads.
4. Put a reverse proxy with automatic HTTPS (for example Caddy) in front of ports 3000 and 8080, on your own domain.
5. Set up daily database backups.

Then follow `docs/PLAY_STORE.md` to publish the Android app.
