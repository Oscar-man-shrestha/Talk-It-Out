# Backend Agent Rules

Applies to everything under `backend/`.

## Scope
- Backend only. Do not edit the Flutter app (`lib/`, `test/`, `pubspec.yaml`).
- The contract is what the Flutter `Api*Repository` classes actually call. `API.md` is the written version; if they differ, the code wins, and update `API.md`.

## Privacy hard rules
1. `published_messages` never exposes the real author of an anonymous message. Store `author_id = NULL` and keep the CHECK constraint.
2. Group-facing endpoints never return `raw_message_id`, original text, or `is_anonymous` alongside a sender.
3. Review endpoints return 403 to anyone who is not that group's controller.
4. `messages/mine` returns the caller's own messages, status only. No text, no rewrite, no rejection reason.
5. Rejection notifications contain no reason.
6. Never log raw message text or sender identity.

## Conventions
- Secrets only in `.env` (gitignored). Commit a `.env.example`.
- Migrations in `backend/migrations/`. Never edit an applied migration; add a new one.
- Run tests and lint before ending a run.