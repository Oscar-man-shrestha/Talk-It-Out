# Product Requirements Document (PRD)
## Talk It Out — Safe Deliberation & Psychological Safety Platform

**Document Version:** 1.0 (Production Backend & Database Handoff)  
**Status:** Approved for Backend Implementation  
**Target Platform:** Cross-Platform Web & Mobile (Flutter Frontend)  

---

## 1. Executive Summary & Vision

**Talk It Out** is a high-trust, asynchronous collaboration and deliberation platform engineered to eliminate fear of retaliation, hierarchical bias, and toxic debate in modern organizations.

In conventional workplace tools (Slack, Teams, Email, in-person meetings), critical dissenting opinions are withheld because individual contributors fear social friction or career retribution. When candid feedback is shared, it is often expressed aggressively or defensively, creating friction and polarization.

**Talk It Out solves this through a dual-shielded deliberation model:**
1. **Per-Message Mathematical Anonymity:** Contributors can shield their identity on a per-message basis. Peers only ever see *"Anonymous user"*, signed with ephemeral blinded keys.
2. **AI Non-Adversarial Tone Synthesis:** Raw submissions undergo automated natural language processing (NLP) to remove accusatory, aggressive, or passive-aggressive language while preserving 100% of the underlying technical substance and actionable intent.
3. **Controller Governance:** A designated room Controller / Moderator inspects the AI proposal alongside the contributor's raw draft, accepting the polished synthesis into the public chat or rejecting it.
4. **Transparent Parity & Psychological Safety:** Controllers post direct announcements with identical modern chat ergonomics, eliminating power asymmetry while preserving clear role clarity.

---

## 2. Core Problem Statements & Value Proposition

| Pain Point | Conventional System | Talk It Out Solution |
|---|---|---|
| **Fear of Retaliation** | Names are permanently attached to every message; psychological safety is low. | Per-message anonymity checkbox decoupling contributor identity from group chat publication. |
| **Toxic / Inflammatory Phrasing** | Frustrated teammates use heated phrasing that sparks defensiveness and derailed retrospectives. | Two-stage AI pipeline synthesizes constructive, collaborative phrasing before publication. |
| **Controller / Moderator Burnout** | Moderators manually rephrase or referee heated debates in real-time. | AI pre-generates structured neutral proposals with diff comparison and consensus impact projections. |
| **Dominant Voices Monopolize** | Loudest participants hijack meetings; introverted or junior engineers stay quiet. | Asynchronous deliberation queue treats all submissions with equal priority and anonymity protection. |
| **Lack of Feedback on Rejection** | Submissions vanish into a black hole or receive harsh personal criticism. | "My Messages" ledger tracks status (`pending`, `accepted`, `rejected`) with neutral notification delivery. |

---

## 3. User Personas & Permissions Matrix

### Persona A: Maya Lin (The Candid Contributor)
- **Role:** Software Engineer / Product Designer (Individual Contributor).
- **Need:** Wants to raise concerns about rushed sprint deadlines, architectural debt, or compensation equity without being branded as uncooperative.
- **Key Capabilities:**
  - Submit messages in groups where enrolled as Contributor.
  - Toggle "Anonymous message" with immediate cryptographic disclosure.
  - Track submission status in "My messages" without peers seeing original text.
  - React with emojis, reply to messages, browse public feed, build profile.

### Persona B: Julian Vance (The Controller / Moderator)
- **Role:** Team Lead, Engineering Manager, or Elected Facilitator.
- **Need:** Needs candid ground-truth feedback from the team, but must keep discussions productive, non-toxic, and focused on specific agendas.
- **Key Capabilities:**
  - Create agenda-driven deliberation rooms.
  - Access protected Review Queue for pending raw submissions.
  - Inspect AI-generated neutral proposals alongside raw contributor drafts with visual diff highlights.
  - One-click "Publish Rewrite" (pushes to group chat) or "Reject Raw".
  - Post official controller announcements directly to the group chat using the unified composer.
  - Moderate group membership (invite members via `@username`, kick non-cooperative members).
  - Delete published messages if needed.

### Persona C: Observer / Community Member
- **Role:** Cross-functional peer or public community member.
- **Need:** Learns from open community discussions and converts high-signal Q&A posts into dedicated deliberation groups.

### Role-Based Access Control (RBAC) Matrix

| Feature / Action | Contributor | Controller | Observer / Logged Out |
|---|:---:|:---:|:---:|
| View Group Chat (`PublishedMessage`) | Yes | Yes | No (Auth Required) |
| Post Contributor Submission (Queued for Review) | Yes | No (Controller has direct post) | No |
| Toggle Per-Message Anonymity | Yes | No (Controllers speak officially) | No |
| Post Direct Controller Announcement | No | Yes | No |
| Access Review Queue & Detail Screen (`RawMessage`) | **NEVER** (Redirected) | Yes (Guarded) | No |
| View Raw Contributor Text | **NEVER** (Privacy Rule) | Yes (Review Queue Only) | No |
| Accept / Reject Submissions | No | Yes | No |
| Delete Published Group Message | No | Yes | No |
| Kick Group Member | No | Yes | No |
| Leave Group | Yes | Yes (if transferring/delegating) | N/A |
| Invite Member by `@username` | No | Yes | No |
| Add Emoji Reactions / Reply Quote | Yes | Yes | No |
| View / Edit Own Profile & Avatar | Yes | Yes | No |
| Browse Public Feed & React | Yes | Yes | Yes (Read-only feed) |
| Create Group From Feed Post | Post Author Only | Post Author Only | No |

---

## 4. Complete Feature Breakdown & Product Rationale

### 4.1 Authentication & Secure Session Management
- **Description:** Complete email/password authentication with role-aware onboarding (Contributor vs Controller presets for instant demoing).
- **Why Added:** Enterprise-grade security requires zero plaintext token leakage. Access tokens and refresh tokens are stored strictly in hardware-backed `flutter_secure_storage`.
- **Backend Requirement:** Issue cryptographically signed JWT tokens with standard expiration (`exp`), user ID (`sub`), email, and roles.

### 4.2 Agenda Deliberation Rooms (Groups)
- **Description:** Agenda-driven spaces where teams deliberate on specific topics (e.g., *"Sprint 42 Timeline & Technical Debt"*).
- **Why Added:** Discussions without clear agendas devolve into unstructured chatter. Every group has an explicit agenda, creator, controller, member count, and psychological safety protocol.
- **Features in Screen:**
  - Search bar with instant client/server filtering across agenda keywords.
  - Role filter chips: `All Groups`, `Controller` (where user moderates), `Contributor` (where user participates).
  - Sort ordering: `Recent Activity` vs `Alphabetical`.
  - Floating Action Button: Quick access to the Create Group wizard.
  - Psychological Safety Banner: Explains zero-knowledge peer decoupling to build user trust.

### 4.3 WhatsApp / Instagram-Style Deliberation Chat
- **Description:** Real-time conversational group interface combining WhatsApp ergonomics with Instagram floating emoji reactions.
- **Why Added:** Users are most comfortable with familiar consumer messaging UX. Bringing consumer-grade messaging ergonomics into workplace deliberation dramatically increases engagement.
- **Features in Screen:**
  - **Monochrome Precision Visuals:** High-contrast, clean black & white theme (`#FFFFFF` canvas, `#FAFAFA` sub-surface, `#09090B` outgoing bubbles, white incoming bubbles with `#E4E4E7` borders).
  - **Sender Marks:** Distinct avatar badges with participant initials or anonymous visibility-off shield.
  - **Shielded Badges:** Messages submitted anonymously render with an explicit `Shielded` chip and display name `"Anonymous user"`. Real sender is mathematically stripped from the published model.
  - **Floating Emoji Reactions Bar:** Long-press or tap reaction button displays Instagram/WhatsApp-style floating pill (`❤️`, `👍`, `😂`, `😮`, `😢`, `🔥`, and `+` emoji sheet).
  - **Reaction Counter Badges:** Interactive badges pinned to the bottom corner of message bubbles displaying live count and highlighting if the current user reacted.
  - **Quoted Reply Bar:** Tapping reply docks the message above the composer with an accent bar and truncated quote snippet.
  - **Message Deletion:** Controllers have a contextual option to delete inappropriate published messages with immediate confirmation dialog.

### 4.4 Controller Message Composer & Visual Parity
- **Description:** Dedicated direct-posting composer for Controllers with exact visual parity to the Contributor composer.
- **Why Added:** Previously, controllers had an awkward black announcement box that alienated facilitators and created visual disharmony. The new unified composer gives controllers the exact same sleek input pill, smiley picker, attachment button, and Send button, while enforcing the hard rule that controllers post official direct messages without an anonymity checkbox.

### 4.5 Contributor Privacy Composer & Anonymity Disclosure
- **Description:** Rich composer for contributors with an explicit anonymity toggle and legal disclosure banner.
- **Why Added (Hard Rule):** Contributors must understand the precise boundaries of anonymity.
  - Checkbox: `"Anonymous message"` sits immediately before the Send action.
  - Disclosure: *"Anonymous messages are hidden from the group but visible to the controller."*
  - Safety Shield: Informs users that messages undergo AI non-adversarial synthesis prior to controller publication.

### 4.6 "My Messages" Status Ledger
- **Description:** Private ledger where contributors track the lifecycle of their submissions.
- **Why Added:** Solves the "black hole" problem without violating peer privacy.
- **Rules:** Shows status (`pending`, `accepted`, `rejected`) and submission timestamp. Does **not** display rejection reasons or allow peers to view other contributors' raw drafts.

### 4.7 Two-Stage AI Tone Synthesis Pipeline
- **Description:** Asynchronous processing pipeline that transforms raw input into non-adversarial proposals.
- **Pipeline 1 (Advisory & Scoring):** Computes relevance score (0–100%), sentiment polarity, and toxicity flags. Relevance is advisory only (never auto-rejects).
- **Pipeline 2 (Tone Synthesis):** Generates structured non-adversarial proposal preserving core technical points, elevating diplomacy, and proposing actionable remedies.

### 4.8 Controller Review Queue & Diff Studio
- **Description:** Protected governance cockpit accessible strictly to the group Controller.
- **Why Added:** Controllers need fast, ergonomic tools to process high volumes of submissions.
- **Features in Screen:**
  - Filtering modal: Minimum relevance score slider, anonymity filter, priority ordering (FIFO vs High Tension First vs Consensus Blockers).
  - Visual Diff Comparison: Highlights original contributor draft vs AI structured proposal with red/green inline text changes.
  - Synthesis Rationale Pills: Explains why AI adjusted phrasing (`"Preserved core intent"`, `"Elevated professional tone"`).
  - Consensus Impact Projection: Displays projected acceptance probability lift.
  - Action Dock: Solid black "Publish Rewrite" and outlined "Reject Raw".

### 4.9 Real-Time Membership Governance
- **Description:** Member management panel inside group settings.
- **Why Added:** Controllers need tools to manage membership while contributors need freedom to leave discussions.
- **Features:**
  - Member list with roles (`Controller`, `Contributor`).
  - Kick Member: Controller can remove disruptive members with a single confirmation.
  - Leave Group: Any contributor can safely exit an agenda deliberation.
  - Invite by `@username`: Controller can invite specific teammates into the room by handle with real-time feedback.

### 4.10 Public Community Feed & Feed-to-Group Conversion
- **Description:** Company-wide or community-wide open Q&A forum.
- **Why Added:** Bridges top-of-funnel brainstorming with deep deliberation rooms.
- **Features:**
  - Filter by Topic (`Engineering & Tech`, `Leadership`, `Comp & Equity`, `Psych Safety`, `Ethics`).
  - Filter by Experience Level and Status (`Open Questions`, `Active Discussions`).
  - Like & comment counts with leaderboard of trending voices.
  - **"Create Group from this Post"**: Allowed strictly for the post author, seeding a new deliberation room directly from community inquiries.

### 4.11 Notification & Alerts Center
- **Description:** Central hub for group activity and review updates.
- **Why Added:** Keeps participants updated asynchronously without spamming email.
- **Features:**
  - Filter by `All`, `Submissions`, `Moderation`.
  - Rejection notifications deliver neutral text (no rejection reason slot, preserving privacy invariants).
  - Unread count badge on bottom navigation bar.

### 4.12 Public Profile & Identity Studio
- **Description:** Professional identity page with real file image uploads.
- **Why Added:** Users want professional identity representation while maintaining fine-grained control over zero-knowledge identity decoupling.
- **Features:**
  - Real file upload for Profile Picture and Cover Photo (local device image picker generating base64 Data URLs or direct uploads).
  - Professional headline, location, bio summary, and social links (LinkedIn, GitHub, Personal Website).
  - Interactive Experience timeline (add, edit, delete job positions).
  - Education history (add, edit, delete degrees).
  - Dynamic Skills tags (add/remove skills).
  - Zero-Knowledge identity salt rotation & tone style preference selector.

### 4.13 Multi-Device Responsive Architecture
- **Description:** Seamless adaptation across Mobile (< 600px), Tablet (600–900px), and Desktop/Ultrawide (>= 900px).
- **Why Added:** Deliberations happen on phones on the go and workstations at desks. The app must deliver native-quality responsiveness on both.

---

## 5. Non-Functional Requirements & Security Invariants

1. **Zero-Knowledge Identity Decoupling:**
   - Group-facing models (`PublishedMessage`) must **never** contain the original raw text, original author ID, or blinded key seed.
   - Database queries for group chat must return `sender = NULL` for anonymous messages.
2. **Controller Isolation:**
   - `RawMessage` records are strictly restricted to the Controller of that specific group. Contributor APIs must return HTTP 403 Forbidden if accessed by non-controllers.
3. **No "Show Original" Leakage:**
   - Under no circumstances will any API endpoint or UI component provide contributors with a toggle, button, or endpoint to view another contributor's original text.
4. **Performance Targets:**
   - HTTP API response latency: `< 120ms` (P95).
   - WebSocket message broadcast latency: `< 50ms`.
   - NLP pipeline processing time: `< 3.5s` (asynchronous, never blocks client UI).
5. **Token Security:**
   - JWT tokens stored in secure OS storage (Keychain on iOS/macOS, Keystore on Android, secure HTTP-only cookies on Web).
