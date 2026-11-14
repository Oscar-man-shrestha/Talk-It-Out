# Talk It Out: Product and NLP Plan

*Written 2026-11-14. This is a living plan. Update it as the beta teaches you things.*

## 1. Where the product is today

Talk It Out is a place to say the hard thing at work without fear. It has two halves:

- **Groups:** private, WhatsApp-style chats. Any member can send a message anonymously. A local AI model rewrites heated wording into a constructive proposal, and the group's controller reviews every message before anyone else sees it.
- **Feed:** a public Q&A board. People ask workplace questions, others answer, like and save them, and a question can become a group.

Already built: chat (replies, reactions, pins, polls, photos, search), AI rewrite with tone and intent checks, moderation analysis, Google sign-in, live updates, profiles. Backend: Express + PostgreSQL. Worker: Python with a local `qwen2.5:3b` model. App: Flutter.

## 2. What the best apps do, and what we take

| App | What it does best | What Talk It Out takes |
|---|---|---|
| **Instagram** | Search shows people you are connected to first. It tolerates typos and suggests "Did you mean". Explore ranks by your interests. Posts have "Not interested" and "Why you're seeing this". Multi-select "Add people" sheet with suggested accounts. | Fuzzy people search ranked by shared groups. Suggested people when the search box is empty. Multi-select Add Members sheet. "Not interested" and a reason line on each post. |
| **Pinterest** | Asks new users to pick topics at sign-up. The home feed starts from those picks, then learns from what you save and open. | An interest picker before the first feed. Interests that learn from likes, answers, saves and opens. |
| **TikTok** | The For You feed learns fast from small signals and mixes in content outside your interests so it doesn't get stuck. | Implicit signals (open, like, answer, save) and an exploration share in For You. |
| **X / Twitter** | Published its ranking design in 2023: gather candidates, score them, filter, then make sure one author or topic doesn't dominate. | The same pipeline shape: candidates → score → filter hidden/blocked → diversity re-rank. |
| **Reddit / Hacker News** | "Hot" ranking: votes matter, but older posts fade with a time-decay formula. | Engagement with time decay inside the For You score. |
| **LinkedIn** | People You May Know from shared connections. Handles and headlines in search results. | Suggested people from shared groups. Headline under each search result. |
| **Quora / Stack Overflow** | Follow topics. Before you post, it shows similar questions that already exist. | Topic suggestion while writing now; "similar questions" in the next phase. |
| **Blind / Fishbowl** | Anonymous professional talk, verified by work email. | Next phase: work-email verification badges and company spaces (the B2B wedge). |
| **WhatsApp / Telegram** | Fast, familiar chat. | Already done: emoji keyboard, reactions, replies, date dividers, big emoji. |

## 3. Natural language processing: where and how

Rule for all of it: **anonymous group messages are never used for ranking, profiling or search across groups.** NLP for the feed and search uses public posts and your own public actions only.

### Built in this run (Phase 1)

| Feature | Technique | Why this technique |
|---|---|---|
| **People search** (add members) | Text normalisation (accents, case, `_ . -` and digits stripped, repeated letters collapsed). Candidates from PostgreSQL trigram similarity (`pg_trgm`, indexed). Re-ranked with Jaro-Winkler, Damerau-Levenshtein (typos and swapped letters) and a phonetic key (Rohan ≈ Rohn, Katherine ≈ Catherine). | Instant, runs in the database, no model to host, and handles typos, nicknames and spelling variants of South Asian and Western names. |
| **Search ranking** | Exact handle > handle prefix > name word prefix > fuzzy > phonetic, then boosted by how many groups you share. "Did you mean" label on fuzzy hits. | The same order Instagram uses: people you know first. |
| **@handle suggestions** | When a handle is taken, suggest variants made from the person's name. | Like Instagram's sign-up. |
| **Topic tagging of posts** | Tokenise, drop stop words, stem (Porter-style), match a weighted phrase lexicon for 15 interests. Titles count double. Multi-label scores, stored per post. | Zero-shot, explainable, fast, testable. No training data needed yet. |
| **Topic suggestion while writing** | The same classifier on the draft. | Fewer wrong topics, less effort. |
| **For You feed** | Score = interest match + content similarity (TF-IDF cosine between the post and what you engaged with) + engagement with time decay + shared-group bonus + freshness. Then filter hidden posts and re-rank for diversity (no more than 2 in a row on one topic), with a small exploration share. Each post gets a reason ("Because you follow Career growth"). | A transparent hybrid that works from day one with few users, and the shape every big feed uses. |
| **Learning interests** | Like +0.5, answer +1, save +0.75, open +0.2, "Not interested" −1.5 on the post's topics. Old signals fade. | Implicit feedback, as Pinterest and TikTok do. |
| **Feed search** | BM25 ranking with stemming and typo tolerance (fuzzy term match). | Search that understands "promotion" ≈ "promoted" and survives typos. |

### Phase 2 (next 4–6 weeks)

- **Sentence embeddings:** a small local model through the existing Ollama, e.g. `nomic-embed-text`, stored in PostgreSQL with `pgvector`. Uses:
  - semantic search ("my manager takes credit" finds "boss presents my work as his");
  - better For You similarity;
  - **similar questions before posting**, to cut duplicates.
- **Thread summaries for controllers:** "TL;DR of 40 messages" from the existing rewrite model.
- **Smart replies:** three short reply suggestions in chat, generated locally.
- **Toxicity pre-check while typing:** a gentle "This may read as an attack. Want the AI to soften it?" before submit.
- **Learning-to-rank:** once there are about 50k feed events, train a small gradient-boosted model (LightGBM) on clicks, likes and answers to replace the hand-set weights. Keep the reason line.

### Phase 3 (3–6 months)

- **Team health insights for controllers:** aggregated sentiment and topic trends per group. Only show a number when at least 5 people contributed (k-anonymity), so no one is singled out.
- **Multilingual:** Nepali and Hindi rewrite and search (Romanised and native script).
- **Voice notes with transcription:** local Whisper. The transcript goes through the same rewrite and review, so anonymity holds.
- **Notification timing:** learn when each person usually opens the app.

## 4. Data we collect, and the promises we make

What we collect for the feed:
- the interests people pick;
- likes, answers, saves, opens and "Not interested" on public posts.

What we never use for the feed, search or ads: anonymous messages, group messages, who is anonymous.

Promises to put in the privacy policy and show in the app:

1. **Visible and editable.** You can see and change your interests at any time in Profile. Every For You post says why it is there.
2. **Off switch** (Phase 2). Turning off personalisation gives a plain Latest feed.
3. **Retention.** Feed events are deleted after 180 days, and at once when an account is deleted. This run already deletes them with the account.
4. **No selling of data. No ads based on group content.**
5. **Law.** Follow India's DPDP Act 2023 (consent, purpose limitation, erasure) and GDPR if EU users join.

## 5. Roadmap

| Phase | When | Goal | Main work |
|---|---|---|---|
| 1 | Done (this run) | Discovery and personalisation that work | People search, Add Members sheet, @handles, interests, topic tagging, For You, feed search |
| 2 | Weeks 1–6 | Beta-ready | Embeddings and similar questions, thread summaries, smart replies, personalisation off switch, analytics events, crash reporting, App Store and Play Store builds, cloud deploy (managed Postgres, one GPU-less worker with a 3B model or an API fallback) |
| 3 | Months 2–3 | Teams pay | Company spaces with work-email verification, SSO (Google Workspace and Microsoft), admin console, controller rotation, exports, team health insights |
| 4 | Months 3–6 | Grow | Learning-to-rank, multilingual, voice notes, public community spaces, referral loop ("invite your team") |

## 6. Metrics to watch from day one

- **Activation:** the share of new users who, within 24 hours, pick interests, join a group and send one message.
- **Retention:** D1, D7, D30.
- **Feed quality:**
  - For You engagement rate (likes plus answers per post shown), compared with Latest;
  - the "Not interested" rate.
- **Search:**
  - search-to-add rate in Add Members;
  - "no results" rate.
- **Safety:**
  - controller review time (median);
  - rewrite acceptance rate;
  - report rate.
- **Business:** teams with 5 or more weekly active members; paid conversion.

## 7. Business model (hypotheses to test in the beta)

- **Free:** teams up to 10 people, all core features.
- **Pro:** price per seat per month. Unlimited groups, summaries, insights, admin.
- **Enterprise:** SSO and SCIM, data residency, audit export, on-premises AI model.
- **Public Q&A feed:** free. It is the top of the funnel: people find answers, then bring their team.

Comparable products to study: Blind and Fishbowl (anonymous professional talk), Culture Amp and Officevibe (engagement surveys), Slack and Teams (where teams talk today). Talk It Out's edge is **real conversation with safety built in**: AI rewrite, controller review and true anonymity. Surveys and open chat don't offer all three.

## 8. Launch plan

1. **Closed beta:** 3–5 real teams, such as a startup, a college club and a small agency. Weekly 20-minute interviews. Track the metrics above.
2. **Fix the top 3 frictions each week.** Keep a public changelog.
3. **Landing page and waitlist:** the app already has "Request access".
4. **App stores:** TestFlight and Play internal testing first, then public.
5. **Content seeding:** write 30–50 good public questions across the 15 interests so For You is not empty on day one.

## 9. Risks and answers

| Risk | Answer |
|---|---|
| Anonymity is broken by writing style | AI rewrite already normalises style; never expose who is anonymous; k-anonymity on insights. |
| Controller abuses power | Phase 3: controller rotation, an audit log visible to members, an escalation path. |
| Feed is empty early | Seeded content, the exploration share, Latest as a fallback. |
| Ranking feels creepy | A reason on every post, editable interests, an off switch. |
| AI cost at scale | Local 3B model now; batch jobs; API fallback only for paid tiers. |
