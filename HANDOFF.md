# Engineering Handoff Specification (HANDOFF.md)
## Complete Feature Guide & API Contract for Backend & Database Engineers

**Document Version:** 1.0 (Production Frontend Handoff)  
**Target Audience:** Backend Developers, Database Engineers, DevOps, System Integrators  
**Source Code Repository:** Flutter 3.x Cross-Platform Client (`/Users/oscar/Desktop/talk_it_out`)  
**Status:** Frontend Complete & Validated. Ready for Full Backend Wiring.  

---

## 1. Executive Summary & Integration Architecture

This document serves as the **master engineering handoff** from the frontend engineering team to the backend, database, and infrastructure teams.

The Flutter frontend is architected using **Riverpod 2.x** and follows a strict **Repository Pattern**. Every screen and widget interacts *exclusively* with abstract repository interfaces located in `lib/features/*/data/`. Widgets **never** call Dio or HTTP clients directly.

### 1.1 Switching Between Mock and Production Live Backend
The entire application dynamically switches between in-memory mock repositories and real HTTP network repositories via a single compile-time boolean `USE_MOCK`:

```dart
// lib/app/repository_providers.dart
final useMock = const bool.fromEnvironment('USE_MOCK', defaultValue: true);
```

To run the Flutter app pointed at your live backend, launch it with:
```bash
flutter run -d web-server --web-port=52000 \
  --dart-define=USE_MOCK=false \
  --dart-define=API_BASE_URL=http://localhost:3000/api/v1
```

### 1.2 Authentication & Security Headers
All protected API endpoints require a standard Bearer token in the `Authorization` header:
```http
Authorization: Bearer <jwt_access_token>
```
The token is automatically injected by `lib/core/api/auth_interceptor.dart` retrieved securely from `flutter_secure_storage`. When an HTTP `401 Unauthorized` is encountered, the client automatically attempts a token refresh using `POST /auth/refresh` before redirecting to login.

---

## 2. Comprehensive Feature-by-Feature Breakdown

Below is the exhaustive catalog of every user-facing feature implemented in the Flutter frontend, the rationale for why it was added, its UX mechanics, and the exact backend API contract required to support it.

---

### Feature 1: User Authentication & Session Lifecycle
- **Why Added:** To provide enterprise-grade identity management, authenticated session continuity, and secure token lifecycle handling.
- **Frontend Location:** `lib/features/auth/`
- **User Experience:**
  - Login screen with email & password validation.
  - Registration screen with full name, username, email, and password.
  - Persistent login state stored in hardware-backed secure storage (`flutter_secure_storage`).
  - Automatic redirect to `/groups` on authentication; redirect to `/login` on logout or token expiry.
- **Backend API Endpoints:**

#### 1. Login
- **Method:** `POST`
- **Path:** `/api/v1/auth/login`
- **Request Body:**
```json
{
  "email": "priya@example.com",
  "password": "secret123"
}
```
- **Response `200 OK`:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "d8e3b4a2-...",
  "user": {
    "id": "u-priya-001",
    "email": "priya@example.com",
    "name": "Priya Sharma",
    "username": "priya_s",
    "role": "contributor",
    "avatarUrl": "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150"
  }
}
```

#### 2. Register
- **Method:** `POST`
- **Path:** `/api/v1/auth/register`
- **Request Body:**
```json
{
  "email": "maya@example.com",
  "username": "maya_lin",
  "password": "securepassword123",
  "name": "Maya Lin"
}
```
- **Response `201 Created`:** Identical structure to Login response.

---

### Feature 2: Agenda-Driven Deliberation Groups
- **Why Added:** Freeform messaging tools degenerate into noise. Talk It Out groups are structured deliberation rooms anchored around a specific goal or problem statement ("Agenda").
- **Frontend Location:** `lib/features/groups/`
- **User Experience:**
  - Directory of groups displaying Title, Agenda summary, Controller name, and Member count.
  - "New Group" modal allowing creation of a room with title, agenda, and visual gradient.
  - The creator of a group is permanently assigned the role of **Controller**.
- **Backend API Endpoints:**

#### 1. List Groups
- **Method:** `GET`
- **Path:** `/api/v1/groups`
- **Response `200 OK`:**
```json
[
  {
    "id": "grp-nlp-notes",
    "title": "Making NLP notes",
    "agenda": "Consolidate lecture transcripts into concise study guides.",
    "controllerId": "u-controller-002",
    "controllerName": "Julian Vance",
    "memberCount": 8,
    "userRole": "contributor",
    "createdAt": "2026-10-01T12:00:00Z"
  }
]
```

#### 2. Create Group
- **Method:** `POST`
- **Path:** `/api/v1/groups`
- **Request Body:**
```json
{
  "title": "API Architecture Alignment",
  "agenda": "Establish database migration standards and zero-knowledge privacy gates."
}
```
- **Response `201 Created`:** Created Group object with `userRole: "controller"`.

---

### Feature 3: Dual-Mode Real-Time Group Chat (WhatsApp / Instagram Ergonomics)
- **Why Added:** Users expect modern chat usability: message bubble layouts, distinct visual hierarchies, timestamps, reply quotes, and reaction bars, while strictly adhering to privacy guarantees.
- **Frontend Location:** `lib/features/groups/group_chat_screen.dart`
- **User Experience:**
  - Modern bubble layout: outgoing user messages right-aligned; peers and controller left-aligned.
  - Prominent role badges:
    - `"Controller"` badge with shield icon for official room moderators.
    - `"Anonymous user"` badge with ghost icon for privacy-shielded messages.
    - Contributor name & avatar for non-anonymous messages.
  - Hover / long-press emoji reaction bar (👍, ❤️, 🔥, 💡, 👏, 🎯).
  - Threaded swipe-to-reply quoting parent message preview.
  - Controller-exclusive message deletion menu.
- **Backend API Endpoints:**

#### 1. Fetch Group Chat History
- **Method:** `GET`
- **Path:** `/api/v1/groups/:id/messages`
- **Security Rule:** This endpoint returns **ONLY** `PublishedMessage` records. Under no circumstance should raw contributor drafts or true author identities of anonymous messages be returned.
- **Response `200 OK`:**
```json
[
  {
    "id": "pub-msg-101",
    "content": "To prevent regressions in sprint deliverables, let's explore implementing an automated linting check on pull requests.",
    "isAnonymous": true,
    "isController": false,
    "sender": null,
    "replyTo": null,
    "reactions": {
      "👍": 4,
      "💡": 2
    },
    "userReactions": ["👍"],
    "publishedAt": "2026-10-20T01:15:00.000Z"
  },
  {
    "id": "pub-msg-102",
    "content": "Agreed. I have set up the CI gate on GitHub Actions.",
    "isAnonymous": false,
    "isController": true,
    "sender": {
      "id": "u-controller-002",
      "name": "Julian Vance",
      "avatarUrl": "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150"
    },
    "replyTo": {
      "id": "pub-msg-101",
      "authorName": "Anonymous user",
      "snippet": "To prevent regressions in sprint deliverables..."
    },
    "reactions": {
      "🔥": 5
    },
    "userReactions": [],
    "publishedAt": "2026-10-20T01:18:00.000Z"
  }
]
```

---

### Feature 4: Contributor Message Ingress with Anonymity Disclosure
- **Why Added:** Allows individual contributors to submit critical feedback without fear of retaliation or social friction.
- **Frontend Location:** `lib/features/groups/group_chat_screen.dart` (Contributor Composer)
- **User Experience:**
  - Text input field with send button.
  - Dedicated "Anonymous message" checkbox located immediately above the Send action.
  - Permanent privacy disclosure text: *"Anonymous messages are hidden from the group but visible to the controller."*
  - Submitting does **NOT** post directly into the chat. The user receives immediate feedback that their message has been submitted to the review queue.
- **Backend API Endpoint:**

#### Submit Message for Review
- **Method:** `POST`
- **Path:** `/api/v1/groups/:id/messages`
- **Request Body:**
```json
{
  "content": "Our current database indexes are causing 4-second latency spikes during retrospectives.",
  "isAnonymous": true,
  "replyToId": "pub-msg-101"
}
```
- **Backend Handling:**
  1. Record is inserted into `raw_messages` table with `status = 'pending'`.
  2. The message is enqueued into `nlp_moderation_queue` for AI processing.
  3. Respond with `201 Created`. **Do NOT broadcast to group chat.**
- **Response `201 Created`:**
```json
{
  "id": "raw-msg-882",
  "status": "pending",
  "isAnonymous": true,
  "submittedAt": "2026-10-20T01:20:00.000Z"
}
```

---

### Feature 5: Controller Direct Messaging Parity
- **Why Added:** In earlier iterations, Controllers lacked an in-chat message composer and could only approve others' messages. This feature provides full UX parity: Controllers now have an identical WhatsApp-style composer to post official guidance, announcements, and replies directly to the room.
- **Frontend Location:** `lib/features/groups/group_chat_screen.dart` (Controller Composer)
- **User Experience:**
  - Identical clean chat bar with attachment icon, input field, and send button.
  - No anonymity toggle (Controllers are accountable leaders; their messages are always identified with the Controller shield).
  - Submitting publishes **immediately** to the chat.
- **Backend API Endpoint:**

#### Controller Publish Direct Message
- **Method:** `POST`
- **Path:** `/api/v1/groups/:id/messages/controller`
- **Security Guard:** Verified `role == 'controller'`. Contributors receive `403 Forbidden`.
- **Request Body:**
```json
{
  "content": "Sprint goals have been updated in Jira. Please review before 5 PM.",
  "replyToId": null
}
```
- **Backend Handling:**
  1. Insert into `published_messages` (`author_id = req.user.id`, `is_controller = true`, `is_anonymous = false`).
  2. Emit real-time WebSocket event `chat:message_published` to `room:group:<groupId>`.
- **Response `201 Created`:** `PublishedMessage` JSON object.

---

### Feature 6: Controller AI Moderation & Review Queue
- **Why Added:** Prevents flame wars, toxic rants, and off-topic distractions by giving the room Controller an AI-assisted moderation workspace.
- **Frontend Location:** `lib/features/review/review_queue_screen.dart`
- **User Experience:**
  - Route guarded: non-controllers are redirected immediately.
  - Review cards displaying:
    - Contributor's Raw Draft text.
    - AI Synthesized Non-Adversarial Rewrite proposal.
    - Objective Metrics: Toxicity score bar (green/amber/red) and Agenda Relevance score (0–100%).
    - AI Rationale explaining what tone improvements were made.
    - Dual Action Buttons: "Publish Rewrite" and "Reject Raw".
- **Backend API Endpoint:**

#### Fetch Review Queue
- **Method:** `GET`
- **Path:** `/api/v1/groups/:id/review/queue`
- **Security Guard:** Controller only (`403 Forbidden` if contributor).
- **Response `200 OK`:**
```json
[
  {
    "id": "raw-msg-882",
    "groupId": "grp-nlp-notes",
    "author": {
      "id": "u-priya-001",
      "name": "Priya Sharma",
      "avatarUrl": "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150"
    },
    "originalContent": "The sprint deadline is completely unrealistic and management is ignoring technical debt.",
    "aiRewriteProposal": "We have concerns regarding the current sprint schedule given our existing architectural debt, and recommend adjusting deliverables.",
    "aiRationale": "Replaced accusatory statement with constructive risk mitigation framing.",
    "relevanceScore": 0.88,
    "toxicityScore": 0.35,
    "isAnonymous": true,
    "submittedAt": "2026-10-20T01:20:00.000Z"
  }
]
```

---

### Feature 7: AI Rewrite Acceptance & Instant Publication
- **Why Added:** Allows the Controller to approve the sanitized, constructive proposal with one tap, pushing it live into the group deliberation.
- **Frontend Location:** `lib/features/review/review_queue_screen.dart`
- **Backend API Endpoint:**

#### Accept Rewrite
- **Method:** `POST`
- **Path:** `/api/v1/groups/:id/review/:messageId/accept`
- **Backend Handling (Atomic Transaction):**
  1. `UPDATE raw_messages SET status = 'accepted', reviewed_at = NOW() WHERE id = :messageId;`
  2. `INSERT INTO published_messages (group_id, raw_message_id, author_id, content, is_anonymous, is_controller) VALUES (:groupId, :messageId, (CASE WHEN raw.is_anonymous THEN NULL ELSE raw.author_id END), raw.ai_rewrite_proposal, raw.is_anonymous, FALSE);`
  3. Create record in `notifications` for the author: "Your message in <group> was accepted and published."
  4. Emit WebSocket event `chat:message_published` to `room:group:<groupId>`.
- **Response `200 OK`:**
```json
{
  "success": true,
  "publishedMessageId": "pub-msg-205",
  "status": "accepted"
}
```

---

### Feature 8: Draft Rejection Without Adversarial Feedback
- **Why Added:** If a message violates team safety guidelines or is totally irrelevant, the Controller can reject it. Per hard product rules, **no rejection reason** is collected or transmitted to the contributor. This prevents adversarial probing and keeps feedback neutral.
- **Frontend Location:** `lib/features/review/review_queue_screen.dart`
- **Backend API Endpoint:**

#### Reject Draft
- **Method:** `POST`
- **Path:** `/api/v1/groups/:id/review/:messageId/reject`
- **Backend Handling:**
  1. `UPDATE raw_messages SET status = 'rejected', reviewed_at = NOW() WHERE id = :messageId;`
  2. Create neutral notification for author: "Your message in <group> was not accepted."
  3. Zero feedback text is stored or returned.
- **Response `200 OK`:**
```json
{
  "success": true,
  "status": "rejected"
}
```

---

### Feature 9: Contributor Submission Ledger ("My Messages")
- **Why Added:** Solves the "black hole" problem of submissions. Contributors can check the status of their pending submissions without exposing raw text or reasons to peers.
- **Frontend Location:** `lib/features/groups/my_messages_screen.dart`
- **User Experience:**
  - Status pill list: `Pending Review` (amber), `Accepted` (green), `Rejected` (neutral gray).
  - Shows timestamp and anonymity indicator.
  - **Hard Privacy Rule:** Raw message text is NEVER rendered or returned by the API here.
- **Backend API Endpoint:**

#### Fetch My Messages
- **Method:** `GET`
- **Path:** `/api/v1/groups/:id/my-messages`
- **Query Filter:** `author_id = req.user.id AND group_id = :id`
- **Response `200 OK`:**
```json
[
  {
    "id": "raw-msg-882",
    "status": "pending",
    "isAnonymous": true,
    "submittedAt": "2026-10-20T01:20:00.000Z",
    "publishedMessageId": null
  },
  {
    "id": "raw-msg-551",
    "status": "accepted",
    "isAnonymous": true,
    "submittedAt": "2026-10-18T10:00:00.000Z",
    "publishedMessageId": "pub-msg-101"
  }
]
```

---

### Feature 10: Emoji Reactions (Instagram / WhatsApp Floating Bar)
- **Why Added:** Non-verbal micro-feedback is critical for async consensus. Teammates can quickly signal agreement without cluttering the chat with "+1" messages.
- **Frontend Location:** `lib/features/groups/group_chat_screen.dart`
- **User Experience:**
  - Long press or tap reaction icon on any message to reveal floating emoji bar: 👍, ❤️, 🔥, 💡, 👏, 🎯.
  - Tapping an emoji toggles the user's reaction.
  - Active reactions are displayed in pills below the message with aggregate counts.
- **Backend API Endpoint:**

#### Toggle Reaction
- **Method:** `POST`
- **Path:** `/api/v1/groups/:id/messages/:messageId/reactions`
- **Request Body:**
```json
{
  "emoji": "👍"
}
```
- **Backend Handling:**
  - If user already reacted with this emoji, delete the row.
  - If not, insert row into `message_reactions`.
  - Broadcast `chat:reaction_updated` over WebSockets.
- **Response `200 OK`:**
```json
{
  "messageId": "pub-msg-101",
  "reactions": {
    "👍": 5,
    "💡": 2
  },
  "userReactions": ["👍"]
}
```

---

### Feature 11: Controller Message Deletion
- **Why Added:** Allows Controllers to moderate and remove inappropriate or accidental messages from the public chat.
- **Frontend Location:** `lib/features/groups/group_chat_screen.dart`
- **User Experience:** Message action bottom sheet shows "Delete Message" option for Controllers.
- **Backend API Endpoint:**

#### Delete Published Message
- **Method:** `DELETE`
- **Path:** `/api/v1/groups/:id/messages/:messageId`
- **Security Guard:** Controller only (`403 Forbidden` for contributors).
- **Backend Handling:**
  1. `DELETE FROM published_messages WHERE id = :messageId AND group_id = :id;`
  2. Broadcast `chat:message_deleted` over WebSockets.
- **Response `200 OK`:**
```json
{
  "success": true,
  "deletedMessageId": "pub-msg-101"
}
```

---

### Feature 12: Member Moderation (Invite by Username, Kick Member, Leave Group)
- **Why Added:** Room governance requires tools to build trusted cohorts and remove disruptive members.
- **Frontend Location:** `lib/features/groups/group_members_screen.dart`
- **User Experience:**
  - Controller can tap "Add Member", enter `@username`, and invite a colleague.
  - Controller can tap "Kick" next to any non-controller member with a confirmation modal.
  - Any contributor can tap "Leave Group" in the group settings menu to exit voluntarily.
- **Backend API Endpoints:**

#### 1. Invite Member
- **Method:** `POST`
- **Path:** `/api/v1/groups/:id/members/invite`
- **Security Guard:** Controller only.
- **Request Body:** `{ "username": "maya_lin" }`
- **Response `201 Created`:** Updated member object.

#### 2. Kick Member
- **Method:** `DELETE`
- **Path:** `/api/v1/groups/:id/members/:userId`
- **Security Guard:** Controller only.
- **Response `200 OK`:** `{ "success": true, "removedUserId": "u-003" }`

#### 3. Leave Group
- **Method:** `POST`
- **Path:** `/api/v1/groups/:id/leave`
- **Security Guard:** Contributor only (Controller must transfer room before leaving).
- **Response `200 OK`:** `{ "success": true }`

---

### Feature 13: Rich Public Profile (Experiences, Educations, Dynamic Skills)
- **Why Added:** Creates professional credibility and context for non-anonymous discussions and peer recognition.
- **Frontend Location:** `lib/features/profile/profile_screen.dart`
- **User Experience:**
  - Profile Identity Card: Full name, headline, location, bio, avatar, and customizable banner cover.
  - Social Links: Website, GitHub, Twitter, LinkedIn.
  - Dynamic Skills chip editor: add skill, delete skill with immediate visual chips.
  - Work Experience Section: Add, edit, and delete career history (Role, Company, Location, Date range, Description).
  - Education Section: Add, edit, and delete academic history (School, Degree, Field of study, Year).
- **Backend API Endpoints:**

#### 1. Get User Profile
- **Method:** `GET`
- **Path:** `/api/v1/users/:id/profile`
- **Response `200 OK`:**
```json
{
  "user": {
    "id": "u-priya-001",
    "email": "priya@example.com",
    "name": "Priya Sharma",
    "username": "priya_s",
    "headline": "Senior Cryptographic Engineer & Zero-Knowledge Researcher",
    "bio": "Specializing in zero-knowledge architectures, distributed systems consensus, and anonymous deliberation protocols.",
    "location": "San Francisco, CA",
    "avatarUrl": "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150",
    "coverUrl": "https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=1200",
    "website": "https://priyasharma.dev",
    "githubHandle": "priyasharma-zk",
    "twitterHandle": "priya_zk",
    "linkedinUrl": "linkedin.com/in/priya-sharma-zk",
    "skills": ["Zero-Knowledge Proofs", "Flutter", "PostgreSQL", "Distributed Systems"]
  },
  "experiences": [
    {
      "id": "exp-001",
      "title": "Lead Security Architect",
      "company": "Nexus Protocol",
      "location": "San Francisco, CA",
      "startDate": "2023-01-01",
      "endDate": null,
      "isCurrent": true,
      "description": "Architected cryptographic identity decoupling and distributed consensus engines."
    }
  ],
  "educations": [
    {
      "id": "edu-001",
      "school": "University of California, Berkeley",
      "degree": "B.S. Electrical Engineering & Computer Sciences",
      "fieldOfStudy": "Computer Science",
      "startYear": 2016,
      "endYear": 2020
    }
  ]
}
```

#### 2. Update Profile Details
- **Method:** `PUT`
- **Path:** `/api/v1/users/me/profile`
- **Request Body:**
```json
{
  "name": "Priya Sharma",
  "headline": "Staff Distributed Systems Engineer",
  "bio": "Updated bio text...",
  "location": "San Francisco, CA",
  "website": "https://priyasharma.dev",
  "githubHandle": "priyasharma-zk",
  "twitterHandle": "priya_zk",
  "linkedinUrl": "linkedin.com/in/priya-sharma-zk",
  "skills": ["Zero-Knowledge Proofs", "Go", "PostgreSQL", "Rust"]
}
```

#### 3. Experience & Education CRUD
- `POST /api/v1/users/me/experiences` | `PUT /api/v1/users/me/experiences/:id` | `DELETE /api/v1/users/me/experiences/:id`
- `POST /api/v1/users/me/educations` | `PUT /api/v1/users/me/educations/:id` | `DELETE /api/v1/users/me/educations/:id`

---

### Feature 14: Media File Upload (Avatars & Cover Photos)
- **Why Added:** Allows users to personalize their presence with real file uploads rather than pasting raw external URLs.
- **Frontend Location:** `lib/features/profile/profile_screen.dart` (`pickImageFile()`)
- **User Experience:**
  - Tapping "Upload Image" opens the operating system file picker (macOS / Windows / iOS / Android / Web).
  - Image is converted into high-fidelity image data and transmitted directly.
  - Avatar presets are also available for one-tap selection.
- **Backend API Endpoints:**

#### Upload Avatar or Cover Photo
- **Method:** `POST`
- **Path:** `/api/v1/users/me/avatar` (or `/api/v1/users/me/cover`)
- **Content-Type:** `multipart/form-data`
- **Form Field:** `file: <binary_image>`
- **Backend Handling:**
  1. Validate image format (`png`, `jpg`, `jpeg`, `webp`).
  2. Compress and resize via Sharp / Pillow.
  3. Store in AWS S3 or Cloudflare R2 bucket.
  4. Return public HTTPS CDN URL.
- **Response `200 OK`:**
```json
{
  "url": "https://cdn.talkitout.app/avatars/u-priya-001-avatar.webp"
}
```

---

### Feature 15: Public Community Feed & Group Conversion
- **Why Added:** Provides an open space for company-wide discussions and thought leadership. When a public post sparks deep debate, the author can escalate it into a structured deliberation group.
- **Frontend Location:** `lib/features/feed/`
- **User Experience:**
  - Public posts displaying author name, avatar, timestamp, content, like count, and comment count.
  - **Hard Rule:** Public feed has **NO anonymity**. Authors are always visible.
  - Interactive Like button and expandable comments thread.
  - Author-exclusive action: "Create group from this post" automatically creates an agenda-driven deliberation group seeded from the post's text.
- **Backend API Endpoints:**

#### 1. Fetch Feed Posts
- **Method:** `GET`
- **Path:** `/api/v1/feed`
- **Response `200 OK`:** Array of feed post objects.

#### 2. Convert Feed Post to Deliberation Group
- **Method:** `POST`
- **Path:** `/api/v1/feed/:postId/convert-to-group`
- **Security Guard:** Post author only.
- **Backend Handling:**
  1. Insert into `groups` (`title = post.title_or_snippet`, `agenda = post.content`, `controller_id = post.author_id`).
  2. Update `feed_posts.created_group_id = group.id`.
- **Response `201 Created`:** Group object with redirect route.

---

### Feature 16: Notification Center
- **Why Added:** Keeps users informed of review decisions, invitations, and group publications.
- **Frontend Location:** `lib/features/notifications/`
- **User Experience:**
  - Real-time unread notification count badge in navigation bar.
  - Notification list with read/unread styling.
  - Filter toggle: "All" vs "Unread".
  - One-tap "Mark all as read".
- **Backend API Endpoints:**

#### 1. Fetch Notifications
- **Method:** `GET`
- **Path:** `/api/v1/notifications`
- **Response `200 OK`:** Array of notification objects.

#### 2. Mark Notification as Read
- **Method:** `PATCH`
- **Path:** `/api/v1/notifications/:id/read`
- **Response `200 OK`:** `{ "success": true }`

#### 3. Mark All as Read
- **Method:** `POST`
- **Path:** `/api/v1/notifications/read-all`
- **Response `200 OK`:** `{ "success": true, "markedCount": 3 }`

---

## 3. Frontend-Backend Verification Checklist

When backend engineers have deployed their local API server, follow this checklist to verify full compatibility:

1. [ ] **Start Local Backend Server** at `http://localhost:3000/api/v1`.
2. [ ] **Launch Flutter in Live Mode:**
   ```bash
   flutter run -d web-server --web-port=52000 \
     --dart-define=USE_MOCK=false \
     --dart-define=API_BASE_URL=http://localhost:3000/api/v1
   ```
3. [ ] **Verify Login Flow:** Authenticate as Priya or register a new user; confirm token is stored in secure storage.
4. [ ] **Verify Group Creation:** Create a deliberation group; ensure you are returned as `controller`.
5. [ ] **Verify Contributor Anonymous Submission:** Log in as Maya; post an anonymous message in Priya's group; ensure message is NOT visible in chat and appears as `pending` in "My messages".
6. [ ] **Verify Review Queue:** Log back in as Priya (Controller); open Review Queue; verify raw draft and AI rewrite are visible; click "Publish Rewrite".
7. [ ] **Verify Chat Update:** Ensure the message appears in the group chat labeled as `"Anonymous user"` with `sender: null`.
8. [ ] **Verify Parity Composer:** As Controller, post a direct announcement in the group chat; verify instant publication.
9. [ ] **Verify Emoji Reactions:** Long press any message, tap 👍; verify reaction counter increments.
10. [ ] **Verify Profile & Upload:** Edit profile, add experience, upload avatar; verify data persists across reloads.

---

**Approved by:** Frontend Lead & Core Systems Architecture  
**Reference Documents:** [PRD.md](file:///Users/oscar/Desktop/talk_it_out/PRD.md) | [ARCHITECTURE.md](file:///Users/oscar/Desktop/talk_it_out/ARCHITECTURE.md) | [PLAN.md](file:///Users/oscar/Desktop/talk_it_out/PLAN.md)
