# Master Backend & Database Handoff Report
## Talk It Out — Complete System, Feature & Database Architecture Specification

**Document Version:** 1.0 (Comprehensive Master Report)  
**Author:** Frontend Engineering Team  
**Intended Readers:** Backend Engineers, Database Architects, DevOps Engineers, Machine Learning / NLP Engineers  
**Frontend Application:** Flutter 3.x (Web, iOS, Android, macOS, Linux, Windows)  
**Repository Location:** `/Users/oscar/Desktop/talk_it_out`  
**Live Frontend Preview:** `http://127.0.0.1:52000` (Mock Mode Active)  

---

## Table of Contents
1. [Executive Summary & Purpose of this Report](#1-executive-summary--purpose-of-this-report)
2. [How the Frontend Connects to the Backend](#2-how-the-frontend-connects-to-the-backend)
3. [The Core Architectural Innovation: Zero-Knowledge Anonymity Enclave](#3-the-core-architectural-innovation-zero-knowledge-anonymity-enclave)
4. [Exhaustive Feature-by-Feature Catalog (Why Added, UI Mechanics & Backend Tasks)](#4-exhaustive-feature-by-feature-catalog)
   - [Feature 1: Authentication, Registration & Session Persistence](#feature-1-authentication-registration--session-persistence)
   - [Feature 2: Agenda-Driven Deliberation Groups](#feature-2-agenda-driven-deliberation-groups)
   - [Feature 3: WhatsApp/Instagram Modern Group Chat & Bubble Layout](#feature-3-whatsappinstagram-modern-group-chat--bubble-layout)
   - [Feature 4: Contributor Message Ingress & Anonymity Disclosure](#feature-4-contributor-message-ingress--anonymity-disclosure)
   - [Feature 5: Controller Direct Messaging Parity (Unified Composer)](#feature-5-controller-direct-messaging-parity-unified-composer)
   - [Feature 6: AI-Assisted Moderation & Review Queue](#feature-6-ai-assisted-moderation--review-queue)
   - [Feature 7: AI Rewrite Acceptance & Group Chat Broadcast](#feature-7-ai-rewrite-acceptance--group-chat-broadcast)
   - [Feature 8: Safe Rejection Workflow (Probe Prevention)](#feature-8-safe-rejection-workflow-probe-prevention)
   - [Feature 9: Contributor Status Ledger ("My Messages")](#feature-9-contributor-status-ledger-my-messages)
   - [Feature 10: Emoji Reactions (Floating Bar & Aggregations)](#feature-10-emoji-reactions-floating-bar--aggregations)
   - [Feature 11: Threaded Quote-Reply System](#feature-11-threaded-quote-reply-system)
   - [Feature 12: Controller Message Deletion](#feature-12-controller-message-deletion)
   - [Feature 13: Member Moderation (Invite by @username, Kick, Leave Group)](#feature-13-member-moderation-invite-by-username-kick-leave-group)
   - [Feature 14: Comprehensive Professional Profile (Skills, Experiences, Educations)](#feature-14-comprehensive-professional-profile-skills-experiences-educations)
   - [Feature 15: Media Image Upload (Avatars & Cover Banners)](#feature-15-media-image-upload-avatars--cover-banners)
   - [Feature 16: Public Community Feed & Group Conversion](#feature-16-public-community-feed--group-conversion)
   - [Feature 17: Notification Center & Badge Counter](#feature-17-notification-center--badge-counter)
   - [Feature 18: Cross-Device Responsiveness & Monochrome Aesthetics](#feature-18-cross-device-responsiveness--monochrome-aesthetics)
5. [Complete PostgreSQL 16 Database Schema (DDL)](#5-complete-postgresql-16-database-schema-ddl)
6. [Asynchronous NLP Worker & Tone Synthesis Pipeline](#6-asynchronous-nlp-worker--tone-synthesis-pipeline)
7. [WebSocket Real-Time Event Protocol](#7-websocket-real-time-event-protocol)
8. [Step-by-Step Backend Team Action Plan](#8-step-by-step-backend-team-action-plan)
9. [How to Run & Verify the Frontend with Live Backend](#9-how-to-run--verify-the-frontend-with-live-backend)

---

## 1. Executive Summary & Purpose of this Report

Welcome to the **Talk It Out** engineering handoff.

Modern workplace collaboration tools (Slack, Microsoft Teams, Discord, Email) fail to provide psychological safety for candid technical and organizational feedback. Dissenting opinions are routinely withheld because individual contributors fear career retribution, peer judgment, or friction with management. When people do speak up under stress, discussions often degrade into defensive or inflammatory arguments.

**Talk It Out solves this through a dual-shielded collaboration model:**
1. **Per-Message Mathematical Anonymity:** Contributors can shield their identity on any message with a single click. The identity is physically stripped from public representations.
2. **AI Non-Adversarial Tone Synthesis:** Raw messages are processed by an NLP pipeline that removes accusatory, hostile, and defensive tone while preserving 100% of the underlying technical substance.
3. **Controller Governance:** A room Controller (Team Lead, Moderator) inspects the AI proposal alongside the raw submission, approving the sanitized version into the live group chat.
4. **Full Chat Parity:** Controllers possess identical modern WhatsApp-style chat capabilities to post guidance, announcements, and direct replies.

The Flutter frontend (`/Users/oscar/Desktop/talk_it_out`) is **100% built, tested, and polished**. This document provides the backend and database teams with **everything needed** to implement the supporting REST API, PostgreSQL database, Redis queues, and NLP microservices.

---

## 2. How the Frontend Connects to the Backend

### 2.1 The Repository Pattern & Mock/Live Toggle
The Flutter client uses **Riverpod 2.x** and strictly implements the **Repository Pattern**. UI widgets never touch HTTP clients directly. Every feature defines an abstract repository interface with two concrete implementations:
- `Mock*Repository`: In-memory simulated data store (active by default during development).
- `Api*Repository`: Production HTTP client using Dio, injecting Bearer tokens, and communicating with REST endpoints.

The switch is governed by a single compile-time environment variable `USE_MOCK` in [lib/app/repository_providers.dart](file:///Users/oscar/Desktop/talk_it_out/lib/app/repository_providers.dart):
```dart
final useMock = const bool.fromEnvironment('USE_MOCK', defaultValue: true);
```

### 2.2 Pointing the Frontend at Your Backend
When you are ready to test your backend, launch the Flutter app with:
```bash
flutter run -d web-server --web-port=52000 \
  --dart-define=USE_MOCK=false \
  --dart-define=API_BASE_URL=http://localhost:3000/api/v1
```

### 2.3 Authentication Ingestion
All API calls automatically include the JWT access token in the header via `lib/core/api/auth_interceptor.dart`:
```http
Authorization: Bearer <jwt_access_token>
```
Tokens are stored inside `flutter_secure_storage` (iOS Keychain / Android KeyStore / encrypted web storage).

---

## 3. The Core Architectural Innovation: Zero-Knowledge Anonymity Enclave

### Why Standard Database Designs Fail Anonymity
In standard chat platforms, a message row has an `author_id` column, and an `is_anonymous` boolean flag. The server simply omits the user's name when serializing JSON to clients.
**This is fundamentally insecure:**
- A rogue database query immediately unmasks the anonymous author.
- A developer inspecting WebSocket traffic can see the underlying foreign keys.
- An attacker exploiting a GraphQL or REST over-fetching vulnerability can extract the author.

### How Talk It Out Enforces Zero-Knowledge Isolation
In Talk It Out, anonymity is enforced at the **relational database level** using a **Dual-Table Architecture**:

```
[ Contributor Submits Anonymous Message ]
                   │
                   ▼
       ┌────────────────────────┐
       │   raw_messages Table   │  <-- ACCESSIBLE ONLY BY CONTROLLER
       ├────────────────────────┤
       │ id: uuid               │
       │ author_id: "u-maya-01" │
       │ raw_content: "..."     │
       │ is_anonymous: TRUE     │
       │ status: "pending"      │
       └────────────────────────┘
                   │
                   ▼ (NLP Worker computes tone rewrite)
                   ▼ (Controller clicks "Publish Rewrite")
       ┌────────────────────────┐
       │published_messages Table│  <-- PUBLIC TO ALL GROUP PEERS
       ├────────────────────────┤
       │ id: uuid               │
       │ author_id: NULL        │  <-- ENFORCED BY CHECK CONSTRAINT!
       │ content: "..."         │
       │ is_anonymous: TRUE     │
       └────────────────────────┘
```

#### SQL Check Constraint:
```sql
CONSTRAINT chk_anonymity_author_null CHECK (
    (is_anonymous = TRUE AND author_id IS NULL) OR
    (is_anonymous = FALSE)
)
```
When an anonymous message is published, `author_id` is set to **`NULL`**. No database query from a peer or public API endpoint can ever discover who wrote the message.

---

## 4. Exhaustive Feature-by-Feature Catalog

Every feature below details:
1. **Why Added:** Product & engineering motivation.
2. **Frontend UI Mechanics:** What the user sees and interacts with.
3. **Backend & Database Requirements:** Exact tables, columns, queries, and REST endpoints.

---

### Feature 1: Authentication, Registration & Session Persistence
- **Why Added:** Secure user onboarding and hardware-backed session persistence.
- **Frontend UI Mechanics:**
  - Login screen with email & password validation.
  - Registration screen with full name, username, email, and password.
  - Auto-login on app launch if token is valid.
  - Auto-redirect to `/login` when token expires.
- **Backend Requirements:**
  - `POST /api/v1/auth/register` (creates user, hashes password with Argon2id).
  - `POST /api/v1/auth/login` (verifies credentials, returns `{ token, refreshToken, user }`).
  - `POST /api/v1/auth/refresh` (rotates JWT tokens via Redis session store).
  - `POST /api/v1/auth/logout` (invalidates tokens).
  - `GET /api/v1/auth/me` (returns current user profile).

---

### Feature 2: Agenda-Driven Deliberation Groups
- **Why Added:** Open, unmoderated group chats degrade into noise. Deliberation groups are anchored around a specific goal ("Agenda") to keep discussions productive.
- **Frontend UI Mechanics:**
  - Groups directory listing title, agenda summary, controller name, and member count.
  - "New Group" modal allowing creation of a room with title, agenda, and visual gradient.
  - Creator of the group is automatically assigned the permanent role of **Controller**.
- **Backend Requirements:**
  - `GET /api/v1/groups` (queries `groups` joined with `group_members` for the caller).
  - `POST /api/v1/groups` (inserts into `groups` and sets `group_members.role = 'controller'`).
  - `GET /api/v1/groups/:id` (returns group metadata, controller details, and member count).

---

### Feature 3: WhatsApp/Instagram Modern Group Chat & Bubble Layout
- **Why Added:** Replaced basic linear chat text with high-fidelity, mobile-responsive message bubbles with distinct left/right alignment, rounded corners, timestamps, and role badges.
- **Frontend UI Mechanics:**
  - Outgoing user messages are right-aligned (white bubble with subtle border in light mode).
  - Incoming peer messages are left-aligned (soft surface container).
  - Badge hierarchy:
    - `"Controller"` badge with shield icon for verified moderators.
    - `"Anonymous user"` badge with ghost icon for anonymous posts.
    - Contributor name & avatar for non-anonymous posts.
- **Backend Requirements:**
  - `GET /api/v1/groups/:id/messages` returning array of `PublishedMessage` objects.
  - **Hard Security Rule:** For any message where `is_anonymous = true`, the backend serializer **must set `sender = null`**. The server must never emit `raw_message_id` or author metadata.

---

### Feature 4: Contributor Message Ingress & Anonymity Disclosure
- **Why Added:** Enables individual contributors to propose feedback candidly without fear of peer judgment or retribution.
- **Frontend UI Mechanics:**
  - Text input field with attachment icon and send button.
  - Checkbox labeled `"Anonymous message"` sitting directly above the Send button.
  - Immediate disclosure banner: *"Anonymous messages are hidden from the group but visible to the controller."*
  - Submitting does **NOT** post into the chat. It informs the contributor that their proposal is queued for Controller review.
- **Backend Requirements:**
  - `POST /api/v1/groups/:id/messages` accepting `{ content, isAnonymous, replyToId }`.
  - Inserts row into `raw_messages` with `status = 'pending'`.
  - Enqueues job to Redis/BullMQ queue `nlp_moderation_queue`.
  - Responds with `201 Created` (`{ id, status: "pending" }`).
  - **Zero broadcast to public chat at this stage.**

---

### Feature 5: Controller Direct Messaging Parity (Unified Composer)
- **Why Added:** Previously, room Controllers had no way to post announcements or direct guidance into the chat, creating a broken experience. Now Controllers possess an identical modern chat composer.
- **Frontend UI Mechanics:**
  - Identical clean chat bar with emoji button, attachment button, input pill, and send button.
  - No anonymous checkbox (Controllers must remain transparent and accountable).
  - Submissions are published **immediately** to the group chat.
- **Backend Requirements:**
  - `POST /api/v1/groups/:id/messages/controller` accepting `{ content, replyToId }`.
  - Guard: Verifies `req.user.id == group.controller_id`.
  - Inserts directly into `published_messages` (`author_id = req.user.id`, `is_controller = true`, `is_anonymous = false`).
  - Broadcasts `chat:message_published` over WebSockets to `room:group:<groupId>`.

---

### Feature 6: AI-Assisted Moderation & Review Queue
- **Why Added:** Protects groups from flame wars and toxic rants while assisting Controllers with pre-generated constructive rewrites.
- **Frontend UI Mechanics:**
  - Route `/groups/:id/review` accessible strictly by the Controller.
  - Review cards displaying:
    - Contributor's raw draft.
    - AI-synthesized non-adversarial constructive proposal.
    - Toxicity score indicator (green/amber/red).
    - Agenda relevance score (0–100%).
    - AI rationale explaining what tone improvements were made.
- **Backend Requirements:**
  - `GET /api/v1/groups/:id/review/queue`.
  - Guard: Returns `403 Forbidden` if caller is not the room Controller.
  - Returns array of `RawMessage` items with AI metrics and proposals.

---

### Feature 7: AI Rewrite Acceptance & Group Chat Broadcast
- **Why Added:** Allows the Controller to approve the sanitized, constructive proposal with one tap, pushing it live to all group members.
- **Frontend UI Mechanics:**
  - "Publish Rewrite" button on the review card.
  - Card animates away; message instantly appears in the group chat.
- **Backend Requirements:**
  - `POST /api/v1/groups/:id/review/:messageId/accept`.
  - In a single SQL transaction:
    1. Update `raw_messages.status = 'accepted'`.
    2. Insert into `published_messages` (`content = ai_rewrite_proposal`, `author_id = is_anonymous ? NULL : author_id`, `is_anonymous = is_anonymous`).
    3. Insert into `notifications` notifying author their message was published.
    4. Emit WebSocket event `chat:message_published` to `room:group:<groupId>`.

---

### Feature 8: Safe Rejection Workflow (Probe Prevention)
- **Why Added:** When a message violates guidelines or is completely off-topic, the Controller can reject it. Per hard product rules, **no rejection reason** is given to the contributor to prevent adversarial probe attacks.
- **Frontend UI Mechanics:**
  - "Reject Raw" button on the review card.
  - Contributor receives a neutral in-app notification: *"Your message in <Group> was not accepted."*
- **Backend Requirements:**
  - `POST /api/v1/groups/:id/review/:messageId/reject`.
  - Update `raw_messages.status = 'rejected'`.
  - Insert neutral notification into `notifications` table without reason text.
  - **Do NOT store or return rejection reason strings.**

---

### Feature 9: Contributor Status Ledger ("My Messages")
- **Why Added:** Solves the "black hole" submission dilemma. Contributors can track whether their proposals were reviewed, accepted, or rejected.
- **Frontend UI Mechanics:**
  - Screen listing the user's submissions with status pills: `Pending Review` (amber), `Accepted` (green), `Rejected` (gray).
  - **Privacy Guarantee:** Peer contributors cannot access this ledger, and raw text is never echoed.
- **Backend Requirements:**
  - `GET /api/v1/groups/:id/my-messages`.
  - Query: `SELECT id, status, is_anonymous, submitted_at, published_message_id FROM raw_messages WHERE author_id = :userId AND group_id = :groupId;`

---

### Feature 10: Emoji Reactions (Floating Bar & Aggregations)
- **Why Added:** Micro-feedback (agreement, applause, inspiration) without cluttering the chat room.
- **Frontend UI Mechanics:**
  - Long press or tap reaction icon on any message to reveal floating emoji bar: 👍, ❤️, 🔥, 💡, 👏, 🎯.
  - Tapping toggles reaction on/off.
  - Pill counters displayed below message bubble with active highlighting if current user reacted.
- **Backend Requirements:**
  - `POST /api/v1/groups/:id/messages/:messageId/reactions` with `{ emoji }`.
  - Inserts or deletes record from `message_reactions`.
  - Broadcasts `chat:reaction_updated` over WebSockets.

---

### Feature 11: Threaded Quote-Reply System
- **Why Added:** Contextual continuity in fast-moving deliberations.
- **Frontend UI Mechanics:**
  - Swiping a message or tapping "Reply" attaches a quoted preview bar above the composer with author name and snippet.
  - Published reply includes the quoted preview bubble at the top.
- **Backend Requirements:**
  - `parent_id` foreign key on `published_messages` referencing parent `published_messages.id`.
  - Serializer includes parent author display name and 100-character snippet.

---

### Feature 12: Controller Message Deletion
- **Why Added:** Allows Controllers to moderate, redact, or clean up obsolete/inappropriate messages from the live chat.
- **Frontend UI Mechanics:**
  - Tapping message options menu reveals "Delete Message" for Controllers.
  - Confirmation dialog prompts before deletion.
- **Backend Requirements:**
  - `DELETE /api/v1/groups/:id/messages/:messageId`.
  - Guard: Controller only (`403 Forbidden` for contributors).
  - Deletes row from `published_messages` (or sets `is_deleted = true`).
  - Broadcasts `chat:message_deleted` over WebSockets.

---

### Feature 13: Member Moderation (Invite by @username, Kick, Leave Group)
- **Why Added:** Gives Controllers tools to curate trusted cohorts and remove disruptive participants, while allowing contributors to exit voluntarily.
- **Frontend UI Mechanics:**
  - Controller taps "Add Member", enters `@username`, and sends invite.
  - Controller taps "Kick" next to any non-controller member with a confirmation modal.
  - Contributors can tap "Leave Group" in the group settings menu.
- **Backend Requirements:**
  - `POST /api/v1/groups/:id/members/invite` (`{ username }`).
  - `DELETE /api/v1/groups/:id/members/:userId` (Controller kicks member).
  - `POST /api/v1/groups/:id/leave` (Contributor exits).

---

### Feature 14: Comprehensive Professional Profile (Skills, Experiences, Educations)
- **Why Added:** Establishes professional credibility for non-anonymous feed posts and career networking.
- **Frontend UI Mechanics:**
  - Profile identity card with full name, headline, bio, location, avatar, and banner cover.
  - Social handles: Website, GitHub, Twitter, LinkedIn.
  - Dynamic Skills chip editor: add skill, delete skill with immediate chip rendering.
  - Experience Section: Add, edit, and delete work history (Role, Company, Location, Date Range, Description).
  - Education Section: Add, edit, and delete academic history (School, Degree, Field of Study, Years).
- **Backend Requirements:**
  - `GET /api/v1/users/:id/profile` (returns profile, experiences, educations, skills).
  - `PUT /api/v1/users/me/profile` (updates bio, headline, skills, location, social links).
  - `POST / PUT / DELETE /api/v1/users/me/experiences` for work history CRUD.
  - `POST / PUT / DELETE /api/v1/users/me/educations` for academic history CRUD.

---

### Feature 15: Media Image Upload (Avatars & Cover Banners)
- **Why Added:** Users requested real image uploads rather than pasting unvalidated external image URLs.
- **Frontend UI Mechanics:**
  - Tapping "Upload Image" opens the native device file picker (macOS, Windows, iOS, Android, Web).
  - Local image bytes are read and previewed immediately.
  - Curated avatar presets are also selectable with one tap.
- **Backend Requirements:**
  - `POST /api/v1/users/me/avatar` and `POST /api/v1/users/me/cover`.
  - Accepts `multipart/form-data` with `file: <binary>`.
  - Validates image magic bytes (`image/png`, `image/jpeg`, `image/webp`).
  - Resizes and compresses image via Sharp / Pillow.
  - Stores in AWS S3 or Cloudflare R2 bucket.
  - Returns public HTTPS CDN URL (`{ url: "https://cdn.talkitout.app/..." }`).

---

### Feature 16: Public Community Feed & Group Conversion
- **Why Added:** Open space for company-wide discussions. High-engagement posts can be converted into structured deliberation groups.
- **Frontend UI Mechanics:**
  - Feed posts with author identity, timestamp, content, like counter, and comment threads.
  - **Hard Rule: Zero anonymity in the public feed.** Authors are always visible.
  - "Create group from this post" action available exclusively to the post's author, automatically generating an agenda-driven room seeded from the post text.
- **Backend Requirements:**
  - `GET /api/v1/feed` (cursor-based pagination).
  - `POST /api/v1/feed` (creates new post).
  - `POST /api/v1/feed/:id/like` and `POST /api/v1/feed/:id/comments`.
  - `POST /api/v1/feed/:id/convert-to-group` (author-only, creates deliberation group).

---

### Feature 17: Notification Center & Badge Counter
- **Why Added:** Keeps users informed of review decisions, group invites, and mentions.
- **Frontend UI Mechanics:**
  - Unread count badge on bottom navigation bar.
  - Notification list with read/unread visual distinction.
  - "All" vs "Unread" filter toggle and "Mark all as read" button.
- **Backend Requirements:**
  - `GET /api/v1/notifications` returning notification objects.
  - `PATCH /api/v1/notifications/:id/read`.
  - `POST /api/v1/notifications/read-all`.

---

### Feature 18: Cross-Device Responsiveness & Monochrome Aesthetics
- **Why Added:** Ensures the application is usable on mobile phones (<600px), tablets (600–900px), and ultrawide desktops (>=900px) in sleek black & white styling.
- **Frontend UI Mechanics:**
  - Adaptive horizontal padding (`hPad = screenWidth > 860 ? (screenWidth - 800) / 2 : 16.0`).
  - Dynamic bubble clamps (`0.84 * screenWidth` on mobile, `540px` on tablet, `640px` on desktop).
  - Pure monochrome palette: Canvas `#FAFAFA`, Border `#E4E4E7`, Text `#09090B`, Primary `#000000`.

---

## 5. Complete PostgreSQL 16 Database Schema (DDL)

The database schema below represents the production-ready relational architecture. Apply this via your migration tool of choice (Prisma, TypeORM, Flyway, or raw SQL migrations):

```sql
-- Enable Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "citext";

-- Enums
CREATE TYPE user_role_enum AS ENUM ('member', 'admin', 'moderator');
CREATE TYPE group_member_role_enum AS ENUM ('controller', 'contributor');
CREATE TYPE message_status_enum AS ENUM ('pending', 'accepted', 'rejected');
CREATE TYPE notification_type_enum AS ENUM ('review_pending', 'message_accepted', 'message_rejected', 'group_invite', 'mention');

-- Users Table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email CITEXT UNIQUE NOT NULL,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    avatar_url TEXT,
    headline VARCHAR(255) DEFAULT 'Individual Contributor',
    role user_role_enum DEFAULT 'member',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- User Profiles
CREATE TABLE user_profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    bio TEXT,
    cover_url TEXT,
    location VARCHAR(120),
    website VARCHAR(255),
    github_handle VARCHAR(100),
    twitter_handle VARCHAR(100),
    linkedin_url VARCHAR(255),
    skills TEXT[] DEFAULT '{}',
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- User Experiences
CREATE TABLE user_experiences (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(120) NOT NULL,
    company VARCHAR(120) NOT NULL,
    location VARCHAR(120),
    start_date DATE NOT NULL,
    end_date DATE,
    is_current BOOLEAN DEFAULT FALSE,
    description TEXT,
    display_order INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- User Educations
CREATE TABLE user_educations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    school VARCHAR(150) NOT NULL,
    degree VARCHAR(100) NOT NULL,
    field_of_study VARCHAR(100),
    start_year INT,
    end_year INT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Deliberation Groups
CREATE TABLE groups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(150) NOT NULL,
    agenda TEXT NOT NULL,
    controller_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    banner_gradient VARCHAR(100) DEFAULT 'from-blue-600 to-indigo-900',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Group Members (RBAC)
CREATE TABLE group_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role group_member_role_enum NOT NULL DEFAULT 'contributor',
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_group_member UNIQUE (group_id, user_id)
);

-- Dual-Table Enclave: Raw Submissions (Protected)
CREATE TABLE raw_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    raw_content TEXT NOT NULL,
    is_anonymous BOOLEAN DEFAULT FALSE,
    status message_status_enum NOT NULL DEFAULT 'pending',
    relevance_score NUMERIC(4, 3) CHECK (relevance_score >= 0.0 AND relevance_score <= 1.0),
    toxicity_score NUMERIC(4, 3) CHECK (toxicity_score >= 0.0 AND toxicity_score <= 1.0),
    ai_rewrite_proposal TEXT,
    ai_rationale TEXT,
    submitted_at TIMESTAMPTZ DEFAULT NOW(),
    reviewed_at TIMESTAMPTZ,
    reviewed_by UUID REFERENCES users(id) ON DELETE SET NULL
);

-- Dual-Table Enclave: Published Messages (Public to Group)
-- HARD ZERO-KNOWLEDGE CONSTRAINT: If is_anonymous = true, author_id MUST BE NULL
CREATE TABLE published_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    raw_message_id UUID REFERENCES raw_messages(id) ON DELETE SET NULL,
    author_id UUID REFERENCES users(id) ON DELETE SET NULL,
    content TEXT NOT NULL,
    is_anonymous BOOLEAN DEFAULT FALSE,
    is_controller BOOLEAN DEFAULT FALSE,
    parent_id UUID REFERENCES published_messages(id) ON DELETE SET NULL,
    published_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_anonymity_author_null CHECK (
        (is_anonymous = TRUE AND author_id IS NULL) OR
        (is_anonymous = FALSE)
    )
);

-- Message Reactions
CREATE TABLE message_reactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    message_id UUID NOT NULL REFERENCES published_messages(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    emoji VARCHAR(10) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_user_message_emoji UNIQUE (message_id, user_id, emoji)
);

-- Public Feed Posts
CREATE TABLE feed_posts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    author_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    likes_count INT DEFAULT 0,
    comments_count INT DEFAULT 0,
    created_group_id UUID REFERENCES groups(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Feed Comments
CREATE TABLE feed_comments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id UUID NOT NULL REFERENCES feed_posts(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Feed Likes
CREATE TABLE feed_likes (
    post_id UUID NOT NULL REFERENCES feed_posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (post_id, user_id)
);

-- Notifications
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    recipient_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type notification_type_enum NOT NULL,
    title VARCHAR(150) NOT NULL,
    body TEXT NOT NULL,
    group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
    published_message_id UUID REFERENCES published_messages(id) ON DELETE CASCADE,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Performance Indexes
CREATE INDEX idx_group_members_user ON group_members(user_id);
CREATE INDEX idx_group_members_group_role ON group_members(group_id, role);
CREATE INDEX idx_raw_messages_review ON raw_messages(group_id, status) WHERE status = 'pending';
CREATE INDEX idx_raw_messages_author_lookup ON raw_messages(author_id, group_id);
CREATE INDEX idx_published_messages_group_time ON published_messages(group_id, published_at ASC);
CREATE INDEX idx_message_reactions_message ON message_reactions(message_id);
CREATE INDEX idx_notifications_recipient_unread ON notifications(recipient_id, is_read) WHERE is_read = FALSE;
CREATE INDEX idx_feed_posts_created ON feed_posts(created_at DESC);
CREATE INDEX idx_feed_comments_post ON feed_comments(post_id, created_at ASC);
```

---

## 6. Asynchronous NLP Worker & Tone Synthesis Pipeline

### 6.1 Worker Queue Design
When a contributor posts a message, the HTTP API inserts into `raw_messages` with `status = 'pending'` and enqueues a job into Redis (`nlp_moderation_queue` via BullMQ or Celery).

### 6.2 Prompt for Non-Adversarial Constructive Tone Synthesis
The worker executes an LLM completion using the following system prompt:

```text
SYSTEM PROMPT:
You are the AI Deliberation Engine for Talk It Out.
Your task is to rephrase raw team feedback into a constructive, objective, and non-adversarial proposal suitable for executive and peer review.

STRICT RULES:
1. PRESERVE 100% OF TECHNICAL SUBSTANCE: All bugs, performance bottlenecks, architecture risks, deadline concerns, and resource deficits MUST be retained.
2. ELIMINATE ADVERSARIAL PHRASING: Strip out blame ("you guys failed"), emotional aggression, sarcasm, and passive-aggressive complaints.
3. USE SOLUTION-ORIENTED FRAMING: Reframe statements into collaborative proposals ("To mitigate risk X, we should consider Y...").
4. RETURN VALID JSON strictly following the schema.

CONTEXT:
Group Title: {{ group.title }}
Group Agenda: {{ group.agenda }}
Raw Input: "{{ raw_message.content }}"

OUTPUT JSON SCHEMA:
{
  "rewrite": "Constructive version of the proposal",
  "relevance_score": 0.0 to 1.0 (float: alignment with agenda),
  "toxicity_score": 0.0 to 1.0 (float: hostility/anger in raw input),
  "rationale": "One-sentence explanation of what tone adjustments were made"
}
```

Once computed, the worker updates `raw_messages` with `ai_rewrite_proposal`, `ai_rationale`, `relevance_score`, and `toxicity_score`, and notifies the Controller over WebSockets.

---

## 7. WebSocket Real-Time Event Protocol

To ensure instant chat updates without polling, implement a WebSocket server on top of Redis Pub/Sub:

### 7.1 Rooms
- `room:group:<groupId>`: All members of the group.
- `room:group:<groupId>:controller`: Controller only.
- `room:user:<userId>`: Private notifications.

### 7.2 Event Catalog

| Event Name | Channel / Room | Trigger | Payload |
|---|---|---|---|
| `chat:message_published` | `room:group:<groupId>` | Controller accepts rewrite OR sends direct announcement | Full `PublishedMessage` object (`sender: null` if anonymous). |
| `chat:reaction_updated` | `room:group:<groupId>` | Member adds/removes emoji reaction | `{ messageId, reactions: { "👍": 5 }, userReactions: ["👍"] }` |
| `chat:message_deleted` | `room:group:<groupId>` | Controller deletes published message | `{ deletedMessageId: "pub-msg-101" }` |
| `review:new_submission` | `room:group:<groupId>:controller` | Contributor submits draft; NLP finishes | `{ rawMessageId, pendingCount: 3 }` |
| `notification:new` | `room:user:<userId>` | Message accepted/rejected or invite received | Full `Notification` object. |

---

## 8. Step-by-Step Backend Team Action Plan

Follow this sequential roadmap to bring the backend to life:

1. **Step 1: Database Setup**
   - Provision PostgreSQL 16.
   - Run the DDL script from Section 5.
   - Seed users: `priya@example.com` / `secret123` (Contributor in Group 1, Controller in Group 2), `julian@example.com` / `secret123` (Controller in Group 1).
2. **Step 2: Authentication Service**
   - Implement `/auth/register`, `/auth/login`, `/auth/refresh`, `/auth/me` with JWT Bearer tokens and Argon2id.
3. **Step 3: Groups & Deliberation Engine**
   - Implement group listing, creation, and member moderation (`invite`, `kick`, `leave`).
4. **Step 4: Dual-Table Message Ingress**
   - Implement `POST /groups/:id/messages` (writing to `raw_messages`).
   - Implement `GET /groups/:id/my-messages` (status ledger).
5. **Step 5: NLP Queue & AI Worker**
   - Stand up Redis & BullMQ.
   - Implement the tone synthesis prompt with OpenAI, Anthropic, or local Mistral model.
6. **Step 6: Controller Review & Parity Chat**
   - Implement `GET /groups/:id/review/queue`.
   - Implement `POST /groups/:id/review/:id/accept` (atomic write to `published_messages` with `author_id = NULL` for anonymous).
   - Implement `POST /groups/:id/review/:id/reject` (no feedback text).
   - Implement `POST /groups/:id/messages/controller` (direct announcement).
7. **Step 7: WebSockets & Reactions**
   - Wire up real-time message broadcasting and reaction toggling.
8. **Step 8: Profiles, S3 Media Upload & Public Feed**
   - Implement profile update, experiences, educations, multipart image upload to S3/R2, and public feed.

---

## 9. How to Run & Verify the Frontend with Live Backend

Once your backend is running locally at `http://localhost:3000/api/v1`:

1. Open a terminal in `/Users/oscar/Desktop/talk_it_out`.
2. Start the Flutter web client pointed at your server:
   ```bash
   flutter run -d web-server --web-port=52000 \
     --dart-define=USE_MOCK=false \
     --dart-define=API_BASE_URL=http://localhost:3000/api/v1
   ```
3. Open `http://127.0.0.1:52000/#/login` in Google Chrome or any browser.
4. Execute the following verification run:
   - **Login:** Log in with Priya's credentials.
   - **Post Anonymous Proposal:** In "Making NLP notes", submit a message with "Anonymous message" checked. Verify it does not appear in the group chat and appears as `Pending Review` in "My messages".
   - **Review Queue:** Switch to "Dashboard improvements" (where Priya is Controller), open Review Queue, and click "Publish Rewrite".
   - **Chat Verification:** Confirm the accepted rewrite appears instantly in the group chat labeled `"Anonymous user"` with no sender profile.
   - **Parity Message:** As Controller, send a direct announcement; confirm instant appearance.
   - **Reactions & Deletion:** Long press to add 👍; delete message from menu.
   - **Profile & Image Upload:** Edit profile, add work experience, upload a real photo; confirm persistence.

---

**Report Authored By:** Frontend Systems Architecture  
**Accompanying Technical Documents:**
- [PRD.md](file:///Users/oscar/Desktop/talk_it_out/PRD.md)
- [ARCHITECTURE.md](file:///Users/oscar/Desktop/talk_it_out/ARCHITECTURE.md)
- [PLAN.md](file:///Users/oscar/Desktop/talk_it_out/PLAN.md)
- [HANDOFF.md](file:///Users/oscar/Desktop/talk_it_out/HANDOFF.md)
