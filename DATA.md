# DATA.md: Schema, DTOs, and Models

This is a **frontend-only** repo. The database (Neon PostgreSQL) belongs to the backend team. Section 1 documents the backend schema **for reference only**, taken from PRD v1, so the frontend understands what the data means. The frontend never reads these tables directly. It only sees the JSON in `API.md`.

---

## 1. Backend schema (reference only, from PRD v1)

### users
| Field | Notes |
|---|---|
| `id` | |
| profile fields | Unspecified in PRD. Frontend assumes `name`, `email` (D8). |

### groups
| Field | Notes |
|---|---|
| `id` | |
| `agenda` | Short text describing the group's purpose. There is no `name` field (D5). |
| `controller_id` | One controller per group. |
| `source_post_id` | Nullable. Set if the group was spawned from a post. |
| `created_at` | |

### group_members
| Field | Notes |
|---|---|
| `group_id` | |
| `user_id` | |
| `role` | `controller` or `contributor` |

### raw_messages (controller access only)
| Field | Notes |
|---|---|
| `id` | |
| `group_id` | |
| `sender_id` | Real sender, always stored. |
| `original_text` | |
| `rewritten_text` | Null until the pipeline completes. |
| `is_anonymous` | |
| `intent_preservation_score` | |
| `relevance_score` | |
| `relevance_label` | For example relevant / borderline / off-topic. |
| `pipeline_status` | `queued`, `processing`, `done`, `failed` |
| `status` | Controller decision: `pending`, `accepted`, `rejected` |
| `created_at` | |

### published_messages (the only table group-facing APIs read)
| Field | Notes |
|---|---|
| `id` | |
| `group_id` | |
| `raw_message_id` | Backend-internal link. **Never sent to group-facing clients.** |
| `text` | The rewrite. |
| `display_sender_id` | **Null if anonymous.** |
| `published_at` | |

### posts and comments
`id`, `author_id`, `content`, `nsfw_flag` and other NLP flags, `created_at` (comments also reference the post).

### notifications
`id`, `user_id`, `type` (for example `message_rejected`), `ref_id`, `created_at`, `read_at`.

---

## 2. Mapping: backend field to what the frontend receives

| Backend field | Frontend receives? | Where |
|---|---|---|
| `raw_messages.original_text` | **Controller only** | Review endpoints (API 12, 13) |
| `raw_messages.sender_id` | **Controller only** | Review endpoints |
| `raw_messages.rewritten_text` | Controller only (before publish) | Review endpoints |
| scores, labels, `pipeline_status` | Controller only | Review endpoints |
| `raw_messages.is_anonymous` | Controller; and the sender for own messages | API 12, 13, 11 |
| `published_messages.text` | Everyone in group | API 9 |
| `published_messages.display_sender_id` | Everyone in group, as `display_sender` (object) or `null` | API 9 |
| `published_messages.raw_message_id` | **Never** | n/a |
| `raw_messages.status` | Sender sees own status only | API 11 |

---

## 3. Dart models (freezed + json_serializable)

Keep group-facing and controller-facing models in separate feature folders.

### Shared (`lib/core` or per feature)
```dart
User { String id; String name; String? email; }

Group {
  String id; String agenda; String controllerId;
  String? sourcePostId; DateTime createdAt;
  GroupRole myRole;
  int? pendingCount;          // non-null only when myRole == controller
}

GroupMember { String userId; String name; GroupRole role; }
```

### Group-facing only (`features/groups`)
```dart
PublishedMessage {
  String id;
  String groupId;
  String text;                // the rewrite
  DisplaySender? displaySender; // null => render "Anonymous user"
  DateTime publishedAt;
  // NO originalText, NO senderId, NO isAnonymous, NO rawMessageId
}

DisplaySender { String id; String name; }

MyMessageStatus {
  String id; String groupId;
  MessageStatus status;       // pending | accepted | rejected (no reason)
  bool isAnonymous; DateTime createdAt;
  // NO text of anyone else; no rewrite
}
```

### Controller-only (`features/review`)
```dart
RawMessage {
  String id; String groupId;
  String senderId; String senderName;     // real sender, always shown to controller
  String originalText;
  String? rewrittenText;                  // null until pipeline done or if failed
  bool isAnonymous;
  double? intentPreservationScore;
  double? relevanceScore;
  RelevanceLabel? relevanceLabel;         // advisory only
  PipelineStatus pipelineStatus;
  MessageStatus status;
  DateTime createdAt;
}
```
Convenience getter: `bool get rewriteUnavailable => pipelineStatus == PipelineStatus.failed;`

### Feed (`features/feed`)
```dart
Author { String id; String name; }

Post {
  String id; Author author; String content;
  bool nsfwFlag; Map<String, dynamic> otherFlags;
  int reactionCount; String? myReaction; int commentCount;
  DateTime createdAt;
}

Comment {
  String id; String postId; Author author; String content;
  bool nsfwFlag; Map<String, dynamic> otherFlags;
  DateTime createdAt;
}
```
No anonymity in the feed: `author` is never null.

### Notifications (`features/notifications`)
```dart
AppNotification {
  String id; NotificationType type; String refId;
  NotificationGroup group;   // { id, agenda }
  DateTime createdAt; DateTime? readAt;
  bool get isUnread => readAt == null;
}
```

Response types used by repositories (from `API.md`, not separate backend tables):

```dart
PageResult<T> { List<T> items; String? nextCursor; }

AuthSession { String token; User user; }

SentMessage { String id; String groupId; MessageStatus status; DateTime createdAt; }
// No text field. Sending does not echo the body back.

AcceptResult { String id; MessageStatus status; String publishedMessageId; }
RejectResult { String id; MessageStatus status; } // no reason

ReactionResult { int reactionCount; String? myReaction; }
UnreadCount { int count; }
```

`RepositoryException` carries `code` and a human-readable `message` for the error body in `API.md`.

---

## 4. Enums

Every enum parses tolerantly: an unknown backend value maps to a safe fallback instead of throwing.

| Enum | Values | Fallback for unknown |
|---|---|---|
| `GroupRole` | `controller`, `contributor` | `contributor` (least privilege) |
| `MessageStatus` | `pending`, `accepted`, `rejected` | `pending` |
| `PipelineStatus` | `queued`, `processing`, `done`, `failed` | `processing` |
| `RelevanceLabel` | `relevant`, `borderline`, `off_topic` | `borderline` |
| `NotificationType` | `message_rejected`, `message_pending_review` | `unknown` (rendered generically or ignored) |

Never fall back to `controller` when parsing a role.

---

## 5. State machines

**Message status (controller decision):** `pending -> accepted | rejected`. Terminal after the decision. The frontend never moves a message backwards.

**Pipeline status (backend-driven, shown to controller):**
```
queued -> processing -> done
                    \-> failed   (UI: "Rewrite unavailable"; original still reviewable)
```
While `queued` or `processing`, the controller can still see the original and decide.

---

## 6. Visibility matrix (who can see what)

| Data | Controller | Contributor (own message) | Contributor (others' messages) | Platform user (not in group) |
|---|---|---|---|---|
| Published text (rewrite) | Yes | Yes | Yes | No |
| Sender of a non-anonymous published message | Yes | Yes | Yes | No |
| Sender of an anonymous message | **Yes** | Yes (it's theirs) | **No** ("Anonymous user") | No |
| Original text | **Yes** | Not shown in v1 (D11) | **Never** | No |
| Rewrite before publish | Yes | No | No | No |
| Intent score, relevance result, pipeline status | Yes | No | No | No |
| Own message status (pending / accepted / rejected) | Yes | Yes | No | No |
| Rejection reason | n/a, none exists | n/a, none exists | n/a | n/a |
| Feed posts, comments, authors | Yes | Yes | Yes | Yes (all users) |

---

## 7. Mock seed data checklist (`Mock*Repository`)

The mock repositories must contain at least these cases so every UI state can be developed and tested without a backend:

**Users and groups**
- Current user is **controller** of one group (with pending messages) and **contributor** in another.
- A group spawned from a post (`source_post_id` set).

**Published messages (group chat)**
- A message with a named sender.
- An accepted **anonymous** message (`display_sender = null`).
- Enough messages to test scrolling.

**Review queue (controller-only)**
- Pending message, pipeline `done`, relevant, high intent score.
- Pending message, pipeline `done`, **off_topic** (low relevance).
- Pending message, **anonymous**, pipeline `done` (real sender visible).
- Pending message, pipeline `processing` (no rewrite, no scores).
- Pending message, pipeline `queued`.
- Pending message, pipeline `failed` ("Rewrite unavailable").
- Empty queue state (after all decided).

**My messages (contributor)**
- One `pending`, one `accepted`, one `rejected` (no reason).

**Feed**
- Normal post, post with `nsfw_flag = true`, post with an unknown extra flag key.
- Post authored by the current user (shows "Create group from this post").
- Post authored by someone else (no such action).
- Post with comments, including a flagged comment.

**Notifications**
- Unread `message_rejected` (no reason text).
- Unread `message_pending_review` (controller).
- One already read.
- One with an unknown type (must not crash).

**Error and latency simulation**
- A configurable delay and a way to force an error, so loading and error states can be exercised.

---

## 8. Frontend-side data rules

- Group-facing code never imports `RawMessage`. Enforce with a test or lint rule.
- Do not store message text or sender identity in logs, analytics, crash reports, or unencrypted local storage. Only the auth token is persisted, in `flutter_secure_storage`.
- Treat all IDs as opaque strings.
- Null handling: `display_sender == null` always means anonymous. Do not guess identity from any other field.
