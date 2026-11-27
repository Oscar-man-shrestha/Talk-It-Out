# Talk It Out Premium: the approved plan

Approved by the founder on 2026-11-26, after the research in
[`reports/Talk It Out premium subscription plan.md`](../reports/Talk%20It%20Out%20premium%20subscription%20plan.md).
The founder chose a simpler shape than the research's team-first proposal:
**two offers, Free and Premium at about ₹99 a month**, paid by individuals.

## The two offers

| | Free | Premium |
|---|---|---|
| Price | ₹0 | **₹99 a month** (US $2.99). A yearly option may come later. |
| Who | Everyone | Any individual, for themselves |
| What | **Everything Talk It Out does today, with no new limits**: groups, chat, anonymous messages, AI tone rewrite, controller review, the feed, Catch up, notifications | Everything in Free, **plus new features** (below) |

## Never for sale (from the research; non-negotiable)

- Anonymity, its disclosure, the AI rewrite (same model and speed for everyone), controller review, reports and blocks.
- Anything that reveals or hints at who wrote an anonymous message.
- Premium marks on anonymous messages or inside group chats: a paid badge next to an anonymous message would narrow down who wrote it. Premium marks appear only on named feed content and the person's own screens.
- "Priority" rewrites, history limits, or anything that makes Free worse.

## Premium features, Phase 1 (built, Run 122)

1. **Group Insights** for groups you lead: activity over the last 14 days, how many people take part, how many messages wait for review and your own review time, the most talked-about words, and the busiest hours. Published text only, counts only, and breakdowns only for groups of 5 or more members.
2. **Chat themes**: choose a bubble colour (6) and a wallpaper (4) for your own view of chats. Saved on the device; a lapsed subscription returns to the default look.
3. **Premium badge**: a gold crown next to your name on your feed posts and comments (never in group chats, never on anything anonymous). API.md §74.
4. **Group templates** when creating a group (for example Sprint retro, Class feedback, Town hall Q&A) that fill in the topic for you.
5. **Starred messages**: star published chat messages (long-press) and find them under Profile or the chat menu. Published text only, saved per account on the device; anonymous messages stay "Anonymous user".

Later candidates: weekly digest email for group leaders, AI writing help in the feed, personal answer statistics, yearly plan, team plans for organisations (the research's Team tier).

## Where people find it

Sidebar "Get Premium" button (wide screens), a Premium card under the group list, the plan and tools cards on Profile, and the Premium screen with Free vs Premium cards and a "How you pay" card (UPI, cards, net banking or store balance, all through Google Play or the App Store).

## How it is sold

- **iPhone and Android:** Premium is an in-app subscription through Apple and Google (required for a personal subscription; they keep 15% under Apple's Small Business Program and Google's subscription rate). Through RevenueCat (`purchases_flutter`), free below $2.5K monthly revenue.
- **Web:** Razorpay Checkout (UPI, cards, net banking, wallets), built in Run 127 (API.md 75); cancel on the Premium page. Phones still use only App Store / Google Play: no Razorpay links or prices inside the iPhone or Android apps.
- **The backend decides who is Premium** (`subscriptions` table, RevenueCat webhook, `GET /billing/entitlements`); the app never trusts itself. A manual grant exists for testing and pilots.

## Founder to-do before real payments

**Razorpay (web):** sign up at razorpay.com and finish KYC (business and bank details; you do this yourself). In Test mode first: Settings -> API keys (copy the key id and secret into the backend `.env` as `RAZORPAY_KEY_ID` / `RAZORPAY_KEY_SECRET`, never into the repo); Subscriptions -> Plans -> a ₹99 monthly plan (`RAZORPAY_PLAN_ID`); Webhooks -> `https://<api>/billing/webhooks/razorpay` with the `subscription.*` events and a secret (`RAZORPAY_WEBHOOK_SECRET`). Switch to live keys after KYC. Fees: about 2% + GST per payment, no setup fee (check razorpay.com/pricing).


Apple Paid Apps Agreement, tax and banking, enrol in the Small Business Program; Google Play payments profile and GSTIN; create the ₹99 monthly product in both stores and in RevenueCat; set the RevenueCat keys and webhook secret. Until then Premium works in the demo (mock) and by manual grant.
