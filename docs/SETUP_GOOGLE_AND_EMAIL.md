# Setting up Google sign-in and email codes

Both features are built and tested; each only needs one value from you.
Never commit these values: they go in `backend/.env` (gitignored) or on
the `flutter run` / `flutter build` command line.

## 1. Email codes with Gmail (password reset)

The project's official sender is **talkitoutapp.mail@gmail.com**.

1. Turn on **2-Step Verification** for that Gmail account: <https://myaccount.google.com/security>.
2. Open <https://myaccount.google.com/apppasswords>, create an app
   password named "Talk It Out", and copy the 16 letters.
3. In `backend/.env` set:
   ```
   MAIL_TRANSPORT=smtp
   SMTP_HOST=smtp.gmail.com
   SMTP_PORT=465
   SMTP_USER=talkitoutapp.mail@gmail.com
   SMTP_PASS=abcd efgh ijkl mnop
   ```
   (Spaces in the app password are fine. Leave `SMTP_URL` empty.)
4. Restart the backend and check it:
   ```bash
   cd backend && npm run mail:test -- talkitoutapp.mail@gmail.com
   ```
   `sent via smtp ...` means it works. `EAUTH` means the user or app
   password is wrong (your normal Gmail password does not work here).

Gmail allows about 500 emails a day, plenty for a team project. For a
public launch, use a transactional provider (Brevo, Postmark, Resend);
they all give SMTP settings that go in the same variables.

## 2. Sign in with Google

1. Go to <https://console.cloud.google.com/>, create (or pick) a project.
2. **APIs & Services → OAuth consent screen**: choose *External*, fill in
   the app name and your email, add yourself under *Test users*.
3. **APIs & Services → Credentials → Create credentials → OAuth client
   ID → Web application**.
   - *Authorized JavaScript origins*: add every address the web app is
     opened from, for example `http://localhost:52001` and
     `http://127.0.0.1:52001` (and your real domain later).
   - No redirect URI is needed.
4. Copy the **Client ID** (it ends in `.apps.googleusercontent.com`).
   It is not a secret, but keep it out of Git anyway so each deployment
   can use its own.
5. Backend, in `backend/.env`:
   ```
   GOOGLE_CLIENT_ID=1234567890-abc.apps.googleusercontent.com
   ```
   (Comma-separate several ids if Android/iOS get their own.)
6. App, when running or building:
   ```bash
   flutter run -d web-server --web-hostname=127.0.0.1 --web-port=52001 \
     --dart-define=USE_MOCK=false \
     --dart-define=API_BASE_URL=http://localhost:3000 \
     --dart-define=GOOGLE_CLIENT_ID=1234567890-abc.apps.googleusercontent.com
   ```
   The login screen then shows Google's "Continue with Google" button.
   Without the id, live builds hide it; mock builds always show a demo
   button that signs in as the sample account.

**Android:** add an *Android* OAuth client in the same project (package
name `com.talkitout.talk_it_out`, plus your signing key's SHA-1), and keep
passing the **Web** client id as `GOOGLE_CLIENT_ID`; the app sends it as
the server client id so Google issues a token for the backend.
**iOS:** needs an iOS client id and a URL scheme in `ios/Runner/Info.plist`
(see the google_sign_in package docs); not set up yet.

### What happens on first Google sign-in
- A new email gets a new account with no password (it can set one later
  with "Forgot?").
- An email that already has an account is linked to that Google account.
  Because registration never verified emails, linking removes the old
  password and signs out every device, so nobody who registered that
  email with their own password keeps access. "Forgot?" sets a new one.
