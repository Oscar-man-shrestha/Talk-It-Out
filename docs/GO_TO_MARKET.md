# Talk It Out: Getting Paying Customers

A practical playbook that builds on [STARTUP_PLAN.md](STARTUP_PLAN.md) (metrics, model hypotheses, beta). Prices and numbers here are **starting hypotheses to test**, not research results.

## 1. Who pays, and why

**Talk It Out is a B2B product with a free public funnel.** People don't pay to talk anonymously. Organisations pay so that their people speak up *safely*, and so that leaders hear about problems early.

| Buyer | Pain they will pay to fix | Who signs |
|---|---|---|
| **Startups and agencies (10–200 people)** | Retros and all-hands where nobody says the real thing; people quit without warning | Founder, Head of People, Eng manager |
| **HR / People teams** | Anonymous survey tools are one-way and slow; there is no safe two-way channel | HR head |
| **Colleges, clubs, student bodies** | Students fear speaking to faculty; feedback is either silent or toxic | Dean's office, student council |
| **Community and NGO leads** | Members won't raise issues in public groups | Programme lead |

**Start with one:** tech startups and agencies in India. You can reach them directly, they decide fast, and they already pay for SaaS seats.

**One-line pitch:** *"Your team's honest feedback, without the fear: anonymous when needed, rewritten for tone by AI, approved by a lead before anyone sees it."*

## 2. What is free and what is paid

| Plan | Price (hypothesis) | What you get |
|---|---|---|
| **Free** | ₹0 | Public Q&A feed; up to 3 groups; teams up to 10; core AI rewrite and review |
| **Team** | ₹149 / user / month (₹99 billed yearly) · ~$3–4 international | Unlimited groups and members; **Insights** (themes and sentiment trends per group, k-anonymous); weekly digest email; priority rewrites; custom tone |
| **Business** | ₹299 / user / month | Admin console (all groups, controllers, reports); Google Workspace / Microsoft sign-in; **controller audit log**; data export; retention controls |
| **Enterprise** | Talk to us | SSO/SCIM, data residency, on-premises AI model, DPA, SLA |

Rules of thumb:
- Charge **per active seat**, monthly, with ~30% off yearly.
- Put the paywall on **organisation value** (insights, admin, scale), never on safety. Anonymity and review stay free, because they're the trust story.
- Offer a **14-day Team trial** with no card when someone creates their second group or invites their 11th person.

### Features to build that people will pay for (in order)

1. **Group Insights** for controllers and admins: top themes this week, sentiment trend, open issues, response time. Show aggregates only when a group has at least 5 people (k-anonymity), so nobody can be singled out.
2. **Weekly digest email**: "3 new themes in Engineering Retro; 2 questions waiting for you."
3. **Admin console** (web): see every group, assign controllers, handle reports, export.
4. **Workspace sign-in**: join automatically with a company email domain.
5. **Templates**: "Sprint retro", "Skip-level 1:1", "Exit-interview room", "Class feedback". These cut setup time and make the value obvious.

## 3. Payments

- **Sell team plans on the web** (Razorpay in India, Stripe internationally) from an admin page. Members just sign in to the app.
- **App stores:** Apple and Google generally require their in-app billing for *consumer* digital subscriptions bought inside the app. Business seats bought outside the app and used in it are a common pattern (Slack and Notion work this way), but **check the current App Store guideline 3.1 and Google Play Payments policy before launch**. Rules change, and this is not legal advice.
- Start with **manual invoices** for the first 5–10 customers. Don't build billing before someone wants to pay.

## 4. Getting the first 10 paying teams (founder-led)

**Weeks 1–2: proof**
- Use Talk It Out in **3 real teams for free** (friends' startups, a college club). Collect 3 short quotes and one number, for example "retro participation up from 4 to 11 people".
- Record a **60-second demo**. The reel in `marketing/` is a start: show an angry message becoming a calm one, the controller approving it, and the group seeing it.

**Weeks 2–6: direct outreach**
- List 100 target companies (Indian startups of 20–200 people; LinkedIn, Wellfound, YC and Indian startup lists).
- Message founders and HR leads with a personal note, then the demo, then an offer: **"Run your next retro on Talk It Out, free. If people speak up more, keep it at ₹99 a seat."**
- Aim for 10 demos a week, 3 pilots, 1–2 paid.

**Ongoing: content and community (the free funnel)**
- The **public Q&A feed is your SEO and social engine.** Seed it with 50 strong workplace questions ("How do I tell my manager the deadline is unrealistic?"). Share the best answers as LinkedIn and Instagram carousels that link back to the app.
- Post 3 times a week on LinkedIn about speaking up at work, toxic positivity and better retros. Founders and HR people live there.
- Partner with **HR communities and college placement cells** for workshops on "safe feedback culture" that use the app live.

**Referral loop:** every group a controller creates invites people. Add "Start a group for your own team" at the end of a good session, plus a free month for each team referred.

## 5. Look premium so people trust you with money

- **App store page:** 6 screenshots with one benefit each ("Speak up anonymously", "AI rewrites tone, not meaning", "A lead approves every message"), a 20-second preview video, and a privacy-first description.
- **Landing page:** hero, a 60-second demo, three promises, a privacy section that says exactly who sees what, pricing, a "Book a 15-minute demo" button and customer quotes.
- **Trust pages:** privacy policy, data processing (India's DPDP Act), security overview, and the controller audit log on the roadmap. Buyers in HR ask for these first.
- **Polish in the app:** onboarding that explains anonymity in 3 screens, no empty states without a next step, fast loading (skeletons, not spinners), and smooth motion. Run 117 started this.

## 6. Numbers to watch

| Stage | Metric | Early target |
|---|---|---|
| Acquisition | Demos booked per week | 10 |
| Activation | Teams with 5+ people sending a message in week 1 | 60% |
| Value | Messages per active member per week; rewrite acceptance | 3+; 80%+ |
| Conversion | Pilot to paid | 30% |
| Retention | Paid teams active at month 3 | 85% |
| Revenue | MRR; seats per team | ₹50k MRR by month 6 is a strong signal |

## 7. The next 90 days

| Days | Do |
|---|---|
| 1–30 | 3 free pilot teams; build **Insights v1** and the **weekly digest**; landing page with pricing and "Book a demo"; App Store and Play listings |
| 31–60 | 100-company outreach list; 30 demos; 6 pilots; manual invoices; 3 case-study quotes; LinkedIn content 3x a week |
| 61–90 | Self-serve Team plan on the web (Razorpay); admin console v1; referral credit; first 10 paying teams |

## 8. What could kill it, and the answer

| Risk | Answer |
|---|---|
| "We already have Slack and Google Forms" | Show the gap: Slack isn't safe and forms aren't a conversation. Demo the rewrite and approval flow live. |
| Leaders fear what they'll hear | Position it as early warning: "Hear it in a retro, not in an exit interview." |
| Anonymity is misused | Controller review, reports, rate limits, and the audit log for trust. |
| AI cost per seat | The local model handles most rewrites; use paid API fallbacks only on paid tiers. |
