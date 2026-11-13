# API.md: Endpoints Used by the Flutter App

**Status: PROPOSED contract.** The PRD does not define endpoint names or JSON shapes. This is the contract the frontend is built against. Confirm it with the backend team (Open Decision D12), then fix any difference here and in the `Api*Repository` classes.

The backend (Express) is owned by another team. The frontend never talks to Neon, Redis, or the NLP pipelines directly.

---

## 1. Conventions

| Item | Value |
|---|---|
| Base URL | `API_BASE_URL` (`--dart-define`), e.g. `http://10.0.2.2:3000` for Android emulator |
| Format | JSON, `Content-Type: application/json` |
| Field naming | `snake_case` in JSON, `camelCase` in Dart |
| Timestamps | ISO 8601 UTC strings |
| IDs | Strings (UUID or similar). Treat as opaque. |
| Auth | `Authorization: Bearer <token>` on every endpoint except register and login |
| Pagination (list endpoints) | `?limit=<int>&cursor=<string>`; response `{ "items": [...], "next_cursor": "<string>" \| null }` |

**Error body (all non-2xx):**
```json
{ "error": { "code": "string_code", "message": "Human readable message" } }
```

**Status codes the app handles**

| Code | App behavior |
|---|---|
| 400 / 422 | Show validation message |
| 401 | Clear session, go to login |
| 403 | Show "not allowed"; for controller routes, redirect away |
| 404 | Show not-found state |
| 409 | Show conflict message |
| 5xx / network | Show retryable error state |

---

## 2. Endpoint summary

| # | Method | Path | Who | Purpose |
|---|---|---|---|---|
| 1 | POST | `/auth/register` | Public | Create account |
| 2 | POST | `/auth/login` | Public | Log in |
| 3 | GET | `/me` | Any user | Current user |
| 4 | POST | `/auth/logout` | Any user | Log out (optional server-side) |
| 5 | GET | `/groups` | Any user | Groups I belong to |
| 6 | POST | `/groups` | Any user | Create group (caller becomes controller) |
| 7 | GET | `/groups/:groupId` | Member | Group detail |
| 8 | GET | `/groups/:groupId/members` | Member | Members and roles |
| 9 | GET | `/groups/:groupId/messages` | Member | Published messages (group-facing) |
| 10 | POST | `/groups/:groupId/messages` | Contributor | Send message (stored as pending) |
| 11 | GET | `/groups/:groupId/messages/mine` | Member | Status of my own messages |
| 12 | GET | `/groups/:groupId/review-queue` | **Controller only** | Pending messages |
| 13 | GET | `/groups/:groupId/review-queue/:messageId` | **Controller only** | One message (refresh pipeline status) |
| 14 | POST | `/messages/:messageId/accept` | **Controller only** | Accept and publish |
| 15 | POST | `/messages/:messageId/reject` | **Controller only** | Reject |
| 16 | GET | `/posts` | Any user | Feed |
| 17 | POST | `/posts` | Any user | Create post |
| 18 | GET | `/posts/:postId` | Any user | Post detail |
| 19 | POST | `/posts/:postId/reactions` | Any user | Add reaction |
| 20 | DELETE | `/posts/:postId/reactions` | Any user | Remove my reaction |
| 21 | GET | `/posts/:postId/comments` | Any user | Comments |
| 22 | POST | `/posts/:postId/comments` | Any user | Add comment |
| 23 | POST | `/posts/:postId/group` | Post author | Create group from post (author becomes controller) |
| 24 | GET | `/notifications` | Any user | My notifications |
| 25 | POST | `/notifications/:notificationId/read` | Any user | Mark one as read |
| 26 | GET | `/notifications/unread-count` | Any user | Badge count |

---

## 3. Auth

### 1. POST `/auth/register`
Request:
```json
{ "name": "Priya", "email": "priya@example.com", "password": "secret123" }
```
Response `201`:
```json
{ "token": "jwt...", "user": { "id": "u1", "name": "Priya", "email": "priya@example.com" } }
```

### 2. POST `/auth/login`
Request:
```json
{ "email": "priya@example.com", "password": "secret123" }
```
Response `200`: same shape as register.

### 3. GET `/me`
Response `200`:
```json
{ "id": "u1", "name": "Priya", "email": "priya@example.com" }
```

### 4. POST `/auth/logout`
Response `204`. The app always clears local session even if this fails.

---

## 4. Groups

### 5. GET `/groups`
Response `200` (`items` of Group summary):
```json
{
  "items": [
    {
      "id": "g1",
      "agenda": "Making NLP notes",
      "controller_id": "u9",
      "source_post_id": null,
      "created_at": "2026-10-01T10:00:00Z",
      "my_role": "contributor",
      "pending_count": null
    },
    {
      "id": "g2",
      "agenda": "Dashboard improvements",
      "controller_id": "u1",
      "source_post_id": "p4",
      "created_at": "2026-10-05T09:30:00Z",
      "my_role": "controller",
      "pending_count": 3
    }
  ],
  "next_cursor": null
}
```
`pending_count` is non-null **only** when `my_role` is `controller`.

### 6. POST `/groups`
Request:
```json
{ "agenda": "Making NLP notes" }
```
Response `201`: Group object (same fields as above, `my_role: "controller"`). Caller becomes controller.

### 7. GET `/groups/:groupId`
Response `200`: Group object. `403` if not a member.

### 8. GET `/groups/:groupId/members`
Response `200`:
```json
{
  "items": [
    { "user_id": "u9", "name": "Arhat", "role": "controller" },
    { "user_id": "u1", "name": "Priya", "role": "contributor" }
  ],
  "next_cursor": null
}
```

---

## 5. Messages (group-facing)

### 9. GET `/groups/:groupId/messages`
**Group-facing. Returns published messages only.** The server must never include the real sender of an anonymous message, and never include original text.

Response `200`:
```json
{
  "items": [
    {
      "id": "pm1",
      "group_id": "g1",
      "text": "I suggest we add a login to the dashboard so activity can be traced.",
      "display_sender": { "id": "u1", "name": "Priya" },
      "published_at": "2026-10-10T12:00:00Z"
    },
    {
      "id": "pm2",
      "group_id": "g1",
      "text": "Could we revisit the sprint timeline?",
      "display_sender": null,
      "published_at": "2026-10-10T12:05:00Z"
    }
  ],
  "next_cursor": null
}
```
`display_sender: null` means anonymous, and the UI renders **"Anonymous user"**. There is no `raw_message_id`, `sender_id`, `is_anonymous`, or `original_text` field in this response.

### 10. POST `/groups/:groupId/messages`
Request:
```json
{ "text": "…", "is_anonymous": true }
```
Response `201` (status only, no content echo of anyone else's data):
```json
{ "id": "m100", "group_id": "g1", "status": "pending", "created_at": "2026-10-12T17:00:00Z" }
```
The message is held as `pending` and queued for the NLP pipeline by the backend. It does **not** appear in endpoint 9 until accepted.

### 11. GET `/groups/:groupId/messages/mine`
Only the caller's own messages, status only. No rewrite, no rejection reason.
Response `200`:
```json
{
  "items": [
    { "id": "m100", "group_id": "g1", "status": "pending", "is_anonymous": true, "created_at": "2026-10-12T17:00:00Z" },
    { "id": "m099", "group_id": "g1", "status": "rejected", "is_anonymous": false, "created_at": "2026-10-11T08:00:00Z" }
  ],
  "next_cursor": null
}
```
Whether to also show the sender's own text here is intentionally left out (Open Decision D11); the model carries no text field.

---

## 6. Controller review (controller only)

All three endpoints return `403` for anyone who is not the group's controller. The frontend also guards these routes in the router.

### 12. GET `/groups/:groupId/review-queue`
Returns `status = pending` messages, oldest first.

Response `200`:
```json
{
  "items": [
    {
      "id": "m100",
      "group_id": "g1",
      "sender_id": "u1",
      "sender_name": "Priya",
      "original_text": "…raw text…",
      "rewritten_text": "…professional rewrite…",
      "is_anonymous": true,
      "intent_preservation_score": 0.91,
      "relevance_score": 0.22,
      "relevance_label": "off_topic",
      "pipeline_status": "done",
      "status": "pending",
      "created_at": "2026-10-12T17:00:00Z"
    }
  ],
  "next_cursor": null
}
```

Field notes:
- `rewritten_text`, `intent_preservation_score`, `relevance_score`, `relevance_label` are `null` until the pipeline finishes, or if it fails.
- `pipeline_status`: `queued | processing | done | failed`. `failed` means show **"Rewrite unavailable"**; the original is still reviewable.
- `relevance_label`: `relevant | borderline | off_topic` (advisory only; see D3).

### 13. GET `/groups/:groupId/review-queue/:messageId`
Response `200`: one object with the same shape as an item above. Used to refresh `pipeline_status` while the detail screen is open.

### 14. POST `/messages/:messageId/accept`
No body. Response `200`:
```json
{ "id": "m100", "status": "accepted", "published_message_id": "pm10" }
```
Effect (backend): the rewrite is published to the group. Anonymous messages are published with `display_sender: null`.
If `pipeline_status` is `failed` and no rewrite exists, the backend decides behavior (see D1); the frontend shows the returned error message.

### 15. POST `/messages/:messageId/reject`
No body. **No reason field.** Response `200`:
```json
{ "id": "m100", "status": "rejected" }
```
Effect (backend): nothing is published; the contributor gets a `message_rejected` notification with no reason.

---

## 7. Public feed (no anonymity: authors are always shown)

### 16. GET `/posts`
Response `200`:
```json
{
  "items": [
    {
      "id": "p4",
      "author": { "id": "u1", "name": "Priya" },
      "content": "I want to make NLP notes",
      "nsfw_flag": false,
      "other_flags": {},
      "reaction_count": 5,
      "my_reaction": "like",
      "comment_count": 2,
      "created_at": "2026-10-04T09:00:00Z"
    }
  ],
  "next_cursor": null
}
```
`my_reaction` is `null` when the caller has not reacted. `other_flags` is an open object of Pipeline 2 flags (schema pending, D2). The app must tolerate unknown keys.

### 17. POST `/posts`
Request: `{ "content": "I want to make NLP notes" }`
Response `201`: Post object. Flags may be unset until Pipeline 2 finishes, so re-fetching can change them.

### 18. GET `/posts/:postId`
Response `200`: Post object.

### 19. POST `/posts/:postId/reactions`
Request: `{ "type": "like" }`
Response `200`: `{ "reaction_count": 6, "my_reaction": "like" }`

### 20. DELETE `/posts/:postId/reactions`
Response `200`: `{ "reaction_count": 5, "my_reaction": null }`

### 21. GET `/posts/:postId/comments`
Response `200`:
```json
{
  "items": [
    {
      "id": "c1",
      "post_id": "p4",
      "author": { "id": "u2", "name": "Rohan" },
      "content": "Count me in",
      "nsfw_flag": false,
      "other_flags": {},
      "created_at": "2026-10-04T10:00:00Z"
    }
  ],
  "next_cursor": null
}
```

### 22. POST `/posts/:postId/comments`
Request: `{ "content": "Count me in" }`
Response `201`: Comment object.

### 23. POST `/posts/:postId/group`
No body. Creates a group whose agenda comes from the post and whose **controller is the post author**. `403` if the caller is not the post author (frontend only offers the action to the author; see D7).
Response `201`: Group object with `source_post_id` set and `my_role: "controller"`.

---

## 8. Notifications

### 24. GET `/notifications`
Response `200`:
```json
{
  "items": [
    {
      "id": "n1",
      "type": "message_rejected",
      "ref_id": "m099",
      "group": { "id": "g1", "agenda": "Making NLP notes" },
      "created_at": "2026-10-11T09:00:00Z",
      "read_at": null
    },
    {
      "id": "n2",
      "type": "message_pending_review",
      "ref_id": "m100",
      "group": { "id": "g2", "agenda": "Dashboard improvements" },
      "created_at": "2026-10-12T17:00:01Z",
      "read_at": null
    }
  ],
  "next_cursor": null
}
```
Types in v1: `message_rejected` (contributor, no reason), `message_pending_review` (controller). Unknown types must be ignored gracefully (render nothing or a generic row, never crash). The `group.agenda` is used in the display text because groups have no name (D5).

### 25. POST `/notifications/:notificationId/read`
Response `200`: `{ "id": "n1", "read_at": "2026-10-12T17:30:00Z" }`

### 26. GET `/notifications/unread-count`
Response `200`: `{ "count": 2 }`

---

## 9. Privacy contract (the backend must honor this; the frontend verifies it in Phase 9)

1. Endpoint 9 (`/groups/:groupId/messages`) reads only from published data and never contains the real sender of an anonymous message.
2. Endpoints 12 to 15 return `403` for non-controllers.
3. No endpoint returns another contributor's original text to a non-controller.
4. Endpoint 11 returns only the caller's own messages, status only.
5. Rejection notifications never include a reason.

---

## 10. Backend additions (migrations 005–007)

These endpoints are covered by backend tests. Since Run 071 the app calls endpoints 27–31 through `ApiProfileRepository`, 33 through `ApiGroupRepository.getReactions`/`toggleReaction`, and 34 through `ApiNotificationRepository.markAllRead`. Since Run 073 the app also uses endpoint 35: it requests a refresh token after sign-in, keeps it in secure storage, exchanges it once on a `401` (a single shared exchange, because reuse revokes the family) and replays the request; sign-out revokes it. Endpoints 1–26 above are unchanged; in particular, login/register still return exactly `{ token, user }`. Same conventions as section 1: snake_case JSON, `{ "error": { "code", "message" } }` envelope, everything except `GET /media/:mediaId` needs `Authorization: Bearer`.

### 27. GET `/users/:userId/profile` (also `/users/me/profile`)
Response `200`:
```json
{
  "user": {
    "id": "u1", "name": "Priya", "username": "priya",
    "email": "priya@example.com",
    "headline": "", "bio": "", "location": "", "website": "",
    "github_handle": "", "twitter_handle": "", "linkedin_url": "",
    "skills": [], "avatar_url": null, "cover_url": null
  },
  "experiences": [],
  "educations": []
}
```
`email` is only present on your own profile. A user who never edited a profile gets empty strings and lists. `404` for an unknown id.

### 28. PUT `/users/me/profile`
Body: any subset of `name`, `headline`, `bio`, `location`, `website`, `github_handle`, `twitter_handle`, `linkedin_url`, `skills` (array, max 50, de-duplicated case-insensitively). Unknown fields return `422`. Changing `name` also changes the name shown by `/me` and in published messages. Response `200`: the same shape as endpoint 27.

### 29. Experience: POST `/users/me/experiences`, PUT and DELETE `/users/me/experiences/:id`
Body: `title`, `company` (required), `location`, `start_date` (`YYYY-MM-DD`, required), `end_date` (nullable), `is_current`, `description`. A current role must have no `end_date`, and `end_date` must not be before `start_date` (`422` otherwise). POST returns `201` with the entry, PUT returns `200` (full replacement), DELETE returns `204`. Someone else's entry returns `404`. Max 50 entries.

### 30. Education: POST `/users/me/educations`, PUT and DELETE `/users/me/educations/:id`
Body: `school` (required), `degree`, `field_of_study`, `start_year`, `end_year` (integers or null; end not before start). Same status codes as endpoint 29.

### 31. POST `/users/me/avatar` and POST `/users/me/cover`
`multipart/form-data` with one field `file`. PNG, JPEG, or WebP, max 2 MB. The type is detected from the file bytes, not the header. Response `201`: `{ "url": "http://<host>[/api/v1]/media/<id>" }`. Only the latest image of each kind is kept. Errors: `413 file_too_large`, `415 unsupported_media_type`, `422` for a missing or wrong field. `DELETE /users/me/avatar` (or `/cover`) clears it with `204`.

### 32. GET `/media/:mediaId`
Public, no auth, so `<img>` tags work. Serves the stored bytes with their detected type, `Cross-Origin-Resource-Policy: cross-origin`, and a one-day immutable cache. Images live in Postgres for v1 (no object-store credentials yet).

### 33. GET and POST `/groups/:groupId/messages/:messageId/reactions`
POST body: `{ "emoji": "👍" }`, one of 👍 ❤️ 🔥 💡 👏 🎯. It toggles the caller's reaction. Both GET and POST return `200`:
```json
{ "message_id": "pm1", "reactions": { "👍": 2, "❤️": 1 }, "my_reactions": ["👍"] }
```
Members only (`403` otherwise). Responses carry counts only, never who reacted, so reacting reveals nothing about an anonymous author. Deleting a published message deletes its reactions. Endpoint 9's response shape is unchanged.

### 34. POST `/notifications/read-all`
Marks all of the caller's unread notifications as read. Response `200`: `{ "marked_count": 3 }`.

### 35. Refresh tokens
- `POST /auth/refresh-tokens` (Bearer) returns `201` `{ "refresh_token", "expires_at" }` (30-day lifetime).
- `POST /auth/refresh` with `{ "refresh_token" }` (no Bearer) returns `200` `{ "token", "refresh_token", "expires_at" }`. Every use rotates the token. Reusing an already-rotated token revokes that whole token family and returns `401`. It shares the login rate limit.
- `DELETE /auth/refresh-tokens` (Bearer) revokes all of the caller's refresh tokens with `204`.

Only SHA-256 hashes of refresh tokens are stored. Access tokens stay stateless, exactly as before.

### 36. POST `/groups/:groupId/leave` (controller hand-over, D4)
Unchanged for contributors (`204`). Since Run 073 a **controller** may leave too: the member who joined the group earliest (ties broken by user id) becomes the controller in the same transaction and takes over the review queue; the response is `204`. A controller who is the only member gets `409` `{ "error": { "code": "last_member", "message": "You are the only member, so there is nobody to take over this group." } }`. The old `409 controller_must_transfer` response no longer exists.

**Notifications (D10, decided):** no push service. The app re-checks the unread count when it returns to the foreground and every 30 seconds while it stays there, and reloads the list when the count changes.

### 37. DELETE `/users/me` (delete account)
Body: `{ "password": "..." }` (required again, so a stolen access token alone cannot erase an account). Response `204`. A wrong password returns `403 wrong_password`, deliberately not `401`, so clients do not treat a typo as an expired session. Everything happens in one transaction:
- every group the user controls is handed to its earliest-joined member (same rule as endpoint 36); a group with no other member is removed with its content;
- the user's published group messages stay, so other members' history is intact, but they are re-marked anonymous (`display_sender: null`, shown as "Anonymous user");
- the user's original drafts, with their jobs and review notifications, their feed posts (with comments and likes on them), their own comments, likes and notifications are deleted;
- profile, images, reactions and refresh tokens go with the user row.

The old access token stops working immediately (`401`), because the auth check looks the user up on every request.

### 38. Password reset by emailed code
The app's "Forgot?" link opens a two-step screen (email, then code + new password) that calls these endpoints. In mock mode the code is always `123456`.
- `POST /auth/password-reset` with `{ "email" }` returns `202` `{ "status": "sent_if_registered" }` for **every** valid email, registered or not, and sends the mail without waiting for it, so neither the answer nor its timing reveals which emails have accounts. A registered email gets a 6-digit code that expires in 15 minutes; a new request voids older codes. Returns `503 email_not_configured` when `MAIL_TRANSPORT` is unset or `disabled`.
- `POST /auth/password-reset/confirm` with `{ "email", "code", "new_password" }` returns `204` and sets the password (8–128 characters). It also ends every session of that user (endpoint 39): existing access and refresh tokens stop working. A wrong, used or expired code returns `400 invalid_code` ("That code is not valid or has expired."); after 5 wrong attempts the code stops working.
- Both share the login rate limit. Only an HMAC of each code is stored (`password_resets`).

**Keep active session (login screen):** when the switch is on (the default), the app asks for a refresh token after sign-in (endpoint 35), so the session survives the access token's expiry. When it is off, no refresh token is requested and the user signs in again once the access token expires.

### 39. Account security: change password and sign out everywhere
Every access token now carries the user's `token_version` (claim `tv`; tokens from before migration 009 count as `0`). Bumping the version ends every session at once: all access tokens get `401` and all refresh tokens are revoked.
- `POST /auth/change-password` (Bearer) with `{ "current_password", "new_password" }` returns `200` `{ "token" }`: a fresh access token, so this device stays signed in while every other session ends. A wrong current password is `403 wrong_password` (not `401`); a short or unchanged password is `422`; an account created with Google that has no password yet is `409 no_password`. Shares the login rate limit.
- `POST /auth/logout-all` (Bearer) returns `204` and ends every session, including this one.
- A password reset (endpoint 38) also ends every session.

In the app, Profile → Account has **Change password** and **Sign out of all devices** next to Log out and Delete account.

### 40. POST `/auth/google` (Sign in with Google)
Body: `{ "id_token": "<Google ID token>" }`. Response `200` is exactly the login response (`{ "token", "user" }`), so refresh tokens, Keep active session and everything else work the same.
- The token is checked against Google's published keys: RS256 signature, audience in `GOOGLE_CLIENT_ID`, issuer `accounts.google.com`, not expired, and `email_verified` true. Anything else is `401`.
- A known Google account signs in. A new email creates an account with **no password**. An email that already has a password account is linked: the old password is removed and every session ends, because registration never verified emails. A different Google account for an already linked email is `409 google_account_mismatch`.
- Accounts without a password get `401` on password sign-in (same answer as a wrong password) and `409 no_password` on change password and delete account; "Forgot?" sets a password.
- `503 google_not_configured` when `GOOGLE_CLIENT_ID` is unset. Shares the login rate limit.
- Setup steps: [`docs/SETUP_GOOGLE_AND_EMAIL.md`](docs/SETUP_GOOGLE_AND_EMAIL.md).
- Email delivery is configured in `backend/.env`: `MAIL_TRANSPORT=smtp` plus `SMTP_URL` works with any email provider; `MAIL_TRANSPORT=log` prints the code to the server console for local development and is refused when `NODE_ENV=production`.
