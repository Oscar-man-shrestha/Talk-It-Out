# Google Play launch guide

Everything needed to publish Talk It Out on Google Play, in order. Items marked **You** need your accounts, money or a decision; everything else is already in the repo.

## 1. Before the first build

| Step | Status |
|---|---|
| App ID `com.talkitout.talk_it_out` (permanent once published) | Set in `android/app/build.gradle.kts` |
| App name "Talk It Out", internet permission, `talkitout://` links | Set in `AndroidManifest.xml` |
| App icon (adaptive, monochrome for themed icons) and 512px store icon | `docs/store/icon-512.png`; redraw with `python3 tool/make_icons.py` |
| Privacy policy, terms, account deletion pages | In the app (Register, Profile) and served by the backend at `/legal/privacy`, `/legal/terms`, `/legal/delete-account` |
| **You:** a Google Play developer account (one-time US$25) | |
| **You:** a server with HTTPS for the API (see section 4) | |
| **You:** install the Android command-line tools (Android Studio → SDK Manager → SDK Tools → Command-line Tools), then run `flutter doctor --android-licenses` | |

## 2. Signing key (once, keep it forever)

Google Play needs every update signed with the same upload key. Create it once and back it up somewhere safe (a password manager); never commit it.

```bash
keytool -genkey -v -keystore ~/talkitout-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then create `android/key.properties` (already ignored by git):

```
storePassword=<the password you chose>
keyPassword=<the password you chose>
keyAlias=upload
storeFile=/Users/<you>/talkitout-upload.jks
```

Turn on **Play App Signing** in the Play Console when you upload the first build, so a lost upload key can be reset.

## 3. Build the upload bundle

```bash
flutter build appbundle --release --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=https://api.<your-domain> --dart-define=GOOGLE_CLIENT_ID=<web client id>
```

The file is `build/app/outputs/bundle/release/app-release.aab`. Raise `version:` in `pubspec.yaml` (for example `1.0.1+2`) before every new upload; the number after `+` must always go up.

## 4. Server (needed before real users)

The app on a phone cannot reach `localhost`. You need:

- **API:** the `backend/` Docker image on any host (Render, Railway, Fly.io, a small VPS), with HTTPS on a domain such as `api.<your-domain>`.
- **Database:** managed Postgres 16. Run `npm run migrate` against it.
- **Rewrite worker:** the `pipeline/` worker with a model it can reach (Ollama on a GPU box, or a hosted model). Without it, messages wait for review with "Rewrite unavailable".
- **Email:** Gmail SMTP is already set up; move to a transactional email service when volume grows.
- **Backups:** daily database backups, kept 30 days (the privacy policy promises they are overwritten within 30 days).
- **Optional:** `npm run seed:questions` so the feed is not empty on day one (`-- --remove` deletes them later).

## 5. Store listing (copy you can paste)

**App name (30 max):** Talk It Out: Safe Team Talk

**Short description (80 max):** Speak up at work safely. Anonymous feedback, AI tone rewrite and honest Q&A.

**Full description:**

> Some things are hard to say at work. Talk It Out makes them easier.
>
> **Say it safely in your team.** Create a group for any topic: a project, a retro, a team. Send messages with your name or anonymously. Anonymous messages are hidden from the group; only the group's controller, who reviews every message, can see who sent them.
>
> **Say it calmly.** Before a message reaches the group, an AI rewrites it in a calm, professional tone, so the point lands without the heat. You can preview the wording first, and a gentle tone hint helps while you type.
>
> **Nothing goes out unchecked.** The group's controller sees the original and the rewrite side by side and decides what is published.
>
> **Ask the community.** A public Q&A feed for workplace questions: pay, promotions, managers, burnout, remote work and more. For You learns what you care about and shows why each question is there. Search understands typos, and "Already asked?" finds similar questions before you post.
>
> **Built for safety.** Block anyone, report questions, turn personalisation off, and delete your account any time. No ads, and we never sell your data.

**Category:** Business (alternative: Social). **Tags:** workplace, feedback, team communication.

**Contact email:** talkitoutapp.mail@gmail.com. **Privacy policy URL:** `https://api.<your-domain>/legal/privacy`.

**Graphics (You):**
- 512×512 icon: `docs/store/icon-512.png`.
- 1024×500 feature graphic.
- 2 to 8 phone screenshots, at least 1080 px on the short side. Good ones: For You, a group chat with an anonymous message, the review screen, "Already asked?", the interest picker.

## 6. Play Console forms (answers that match the code)

**Data safety**

| Data type | Collected | Shared | Purpose | Optional |
|---|---|---|---|---|
| Name, email address, user IDs | Yes | No | Account management, app functionality | No |
| Photos (chat and profile photos you choose) | Yes | No | App functionality | Yes |
| Other user-generated content (messages, questions, comments) | Yes | No | App functionality | No |
| App interactions (questions opened, "Not interested") | Yes | No | Personalisation | Yes (switch in Profile) |
| Location, contacts, financial, health, device IDs | No | | | |

- **Data encrypted in transit:** Yes, with HTTPS in production.
- **Users can request deletion:** Yes, in the app, and at `https://api.<your-domain>/legal/delete-account`.

**Account deletion:** the app lets people create accounts, so Play requires the in-app deletion (Profile → Delete account) and a web link (`/legal/delete-account`). Both exist.

**User-generated content policy:** Play requires the following, all of which exist:
- terms that ban objectionable content;
- in-app reporting (questions and comments);
- blocking people;
- moderation: controllers review every group message, and questions reported by 5 people are hidden.

**Content rating questionnaire:** users can interact and share content; no violence, sexual content, gambling or drugs in the app itself. Expect a Teen or Mature rating depending on answers; the terms set 18+.

**Target audience:** 18 and over. Not designed for children.

**Ads:** No ads.

## 7. Release path

1. **Internal testing:** you and up to 100 testers by email. Check sign-in, a group with an anonymous message, review, the feed and deletion on real phones.
2. **Closed testing:** new personal developer accounts must run a closed test with at least 12 testers for 14 days before applying for production.
3. **Production:** roll out to 10%, watch crashes and reviews, then 100%.

## 8. Still needed for a strong launch (not yet built)

- **Push notifications:** Firebase Cloud Messaging, so people hear about reviews and replies when the app is closed. **You:** a Firebase project.
- **Crash reporting:** for example Firebase Crashlytics or Sentry. **You:** an account.
- **Verified app links:** `https://` links that open the app, via `assetlinks.json` on your domain. Until then, invites use `talkitout://` links and a web fallback.
