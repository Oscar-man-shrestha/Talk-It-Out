# Flutter subscription implementation: RevenueCat vs in_app_purchase, India web/B2B billing, and server-side entitlements

All sources were checked on **2026-11-26**. pub.dev shows only relative upload times ("7 days ago"), so the calendar dates below are worked out from that check date and are approximate.

Project context, from local files rather than the web:
- The app's `pubspec.yaml` declares Dart `sdk: ^3.13.3`.
- The backend is Express 5 (`express ^5.1.0`), `pg ^8.16.1`, TypeScript and vitest, with `engines.node >=20` (`/Users/oscar/Projects/Talk-It-Out/backend/package.json`).
- The repo's `AGENTS.md` says the `backend/` code belongs to another team and that any new Flutter dependency must be recorded in `LOGS.md`. Any implementation built from this research needs that team's sign-off.

---

## 1. RevenueCat for Flutter (purchases_flutter, purchases_ui_flutter): versions, compatibility, features, pricing

### Takeaway
`purchases_flutter` 11.0.4 (about 2026-11-19) needs Dart 3.4 or later, so it is compatible with this project's Dart 3.13 by its constraint. It brings Play Billing Library 9.1.0 and Kotlin 2.1+.

RevenueCat is free below $2.5K monthly tracked revenue (MTR), then 1% of MTR.

The main limit: **RevenueCat's own web checkout ("RevenueCat Billing") does not support customers based in India or B2B sales.** That rules it out for the web team/seat plan. RevenueCat still suits the individual plan sold in the mobile apps.

### Cited Findings
**Versions and compatibility**
- `purchases_flutter` latest is **11.0.4**, "Published 7 days ago" (about 2026-11-19). It fixes a custom `assetBase` when loading the web SDK and bumps purchases-hybrid-common to 20.10.0, which brings Android SDK 11.4.0, iOS SDK 5.103.1 and Web SDK 1.75.0. — [pub.dev changelog](https://pub.dev/packages/purchases_flutter/changelog)
- **11.0.0 is a breaking release** (about 28 days before the check, so about 2026-10-29). — [pub.dev changelog](https://pub.dev/packages/purchases_flutter/changelog)
  - The Android SDK moves to **Play Billing Library 9.1.0 and Kotlin 2.2**.
  - Minimums are Kotlin 2.1.0 and `compileSdk` 35; the changelog says Flutter 3.27+ sets `compileSdk` 35 by default.
  - Play-Store-blocked purchases now fail with `purchaseNotAllowedError`.
  - On iOS, `onPurchaseCompleted` no longer fires for purchases made through your own `PaywallPurchaseLogic`.
- CocoaPods: the 11.0.0 changelog recommends Swift Package Manager (Flutter 3.24+ with SPM enabled) and warns that "CocoaPods trunk becomes permanently read-only on December 2, 2026". — [pub.dev changelog](https://pub.dev/packages/purchases_flutter/changelog)
- The last explicit Flutter/Dart minimums in the changelog are Flutter 3.22.0 and Dart 3.4.0, stated at 9.16.0. — [pub.dev changelog](https://pub.dev/packages/purchases_flutter/changelog)
- The versions table lists **minimum Dart SDK 3.4** for every recent release (11.0.0–11.0.4 and 10.18.1–10.19.3). — [pub.dev versions](https://pub.dev/packages/purchases_flutter/versions)
  - The 10.19.x line was still being patched in parallel: 10.19.3 was uploaded "39 hours ago", about 2026-11-24.
- Package listing:
  - Platform tags: Android, iOS, macOS and web. The description text says only "The plugin supports iOS, macOS and Android". — [pub.dev purchases_flutter](https://pub.dev/packages/purchases_flutter)
  - Requirements: "Xcode 14.0+, Kotlin 2.1.0+, and minimum targets iOS 13.0+/Android SDK 21+". — [pub.dev purchases_flutter](https://pub.dev/packages/purchases_flutter)
  - Verified publisher revenuecat.com, 926 likes, 140 points, about 727k downloads. — [pub.dev purchases_flutter](https://pub.dev/packages/purchases_flutter)
- `purchases_ui_flutter` latest is **11.0.4** (same day), depending on `purchases_flutter ^11.0.4`. — [pub.dev purchases_ui_flutter](https://pub.dev/packages/purchases_ui_flutter)
  - It "supports iOS and Android" only; web is not mentioned.
  - **Paywalls need iOS 15.0+ and Android 24+.**
  - APIs: `RevenueCatUI.presentPaywall()`, `presentPaywallIfNeeded("<entitlementId>")`, `PaywallView`, `OriginalTemplatePaywallFooterView` (formerly `PaywallFooterView`), and Customer Center via `presentCustomerCenter()` and `CustomerCenterView`.
  - "Checkpoints" are experimental and invite-only.

**Pricing**
- **Pro is 1% of MTR once you reach $2.5K** ($25 at $2.5K), and nothing in months below the threshold. MTR is measured in USD before the platform cut. — [RevenueCat pricing](https://www.revenuecat.com/pricing/)
- Reaching $2.5K MTR without a card on file makes parts of the product unavailable until you add one. — [RevenueCat pricing](https://www.revenuecat.com/pricing/)
- Enterprise is negotiated. — [RevenueCat pricing](https://www.revenuecat.com/pricing/)
- "Our entire suite of features comes standard". Paywalls, web-to-app funnels and A/B/n testing are listed as Growth Tools with no tier gating stated. — [RevenueCat pricing](https://www.revenuecat.com/pricing/)
- Legacy Pro customers pay 1% instead of 1.2%. — [RevenueCat pricing](https://www.revenuecat.com/pricing/)

**RevenueCat Web**
- There are three billing engines:
  - **RevenueCat Billing**: RevenueCat's own engine, with Stripe as the payment gateway.
  - **Stripe Billing**: you manage products in Stripe and connect them.
  - **Paddle Billing**: Paddle is the merchant of record.
  
  Integration paths are the Web SDK, Web Purchase Links, Web Paywalls, Web Funnels, app-to-web purchases, and Redemption Links (anonymous web purchase, redeemed in the app through a deep link). — [RevenueCat Web overview](https://www.revenuecat.com/docs/web/overview.md)
- "RevenueCat Web is included in RevenueCat's price", with no extra RevenueCat fees. — [RevenueCat Web overview](https://www.revenuecat.com/docs/web/overview.md)
- Stripe fees on each engine (US prices). — [RevenueCat Web overview](https://www.revenuecat.com/docs/web/overview.md)
  - With RevenueCat Billing, Stripe charges 2.9% + 30¢; Stripe Tax is optional at 50¢ per transaction.
  - With the Stripe Billing engine, Stripe adds a "Stripe Billing fee: 0.7% of volume or $620.00 per month".
- **The RevenueCat Billing limitations list says "Customers based in India aren't supported... due to additional data collection and subscription billing requirements in that region" and "Selling to businesses (B2B) isn't supported."** — [RevenueCat Web overview](https://www.revenuecat.com/docs/web/overview.md)
- On RevenueCat Billing you are the merchant of record, with tax via Stripe Tax or Avalara. Paddle acts as merchant of record and handles tax. — [RevenueCat Web overview](https://www.revenuecat.com/docs/web/overview.md)

**RevenueCat's Stripe Billing integration**
- Stripe Checkout is embedded in Web Purchase Links. — [RevenueCat Stripe integration](https://www.revenuecat.com/docs/web/integrations/stripe.md)
- Supported:
  - "Per-unit and recurring quantity plans" (seats).
  - Trials.
  - Coupons and promotion codes.
- Not supported:
  - Tiered, usage-based and customer-chooses pricing.
  - **"PayPal and UPI are also not currently supported"**, and neither are asynchronous or bank-debit methods.
  - Pause: it revokes access immediately, and no `SUBSCRIPTION_PAUSED` event is sent for Stripe.
  - Test Clocks.
- "Cancellations may take up to two hours to reflect in RevenueCat."
- Stripe Managed Payments (Stripe as merchant of record) is available only through the Stripe Billing integration, not RevenueCat Web Billing. — [RevenueCat web billing search summary / Stripe Managed Payments doc](https://revenuecat.com/docs/web/integrations/stripe/stripe-managed-payments)

### Inferences
- **Compatibility.** The Dart constraint (>=3.4) is satisfied by this project's Dart ^3.13.3. On Android the project must use Kotlin 2.1+ and `compileSdk` 35+. On iOS it should move to SPM before CocoaPods trunk freezes on 2026-12-02, or at least confirm the pod still resolves.
- **Minimum OS versions.** RevenueCat's own paywall UI forces iOS 15+ and Android 24+ for paywall screens. A paywall hand-built in Flutter on top of `purchases_flutter` avoids that but loses no-code paywall editing and experiments.
- **Web.** Even though `purchases_flutter` is tagged for web, RevenueCat's hosted web billing cannot sell to Indian customers or businesses. The Stripe route excludes UPI, the dominant Indian method. RevenueCat is therefore a fit for the **mobile individual plan only**. The web team/seat plan needs a separate India-capable processor, such as Razorpay (section 3), with the backend as the place where the two are merged.
- **Mobile fees.** At low revenue RevenueCat costs nothing. At $10K MTR it costs about $100/month on top of store commissions.

### Gaps
- pub.dev does not show exact upload dates or a "tested with Flutter 3.4x" statement. Compatibility with the newest Flutter stable is inferred only from the Dart >=3.4 constraint. Run `flutter pub get` and a device build to confirm.
- I did not find documentation of what `purchases_flutter` on **web** does: which Web SDK (purchases-js) features are exposed and whether it is beta. The changelog only shows Web SDK version bumps.
- Whether RevenueCat can ingest Razorpay purchases (it supports Stripe, Paddle and the stores) was not found. Also unverified: whether its REST API can grant a promotional entitlement to represent a web seat.
- No RevenueCat page in this session gave the exact Customer Center or Experiments plan gating beyond "all features included".

---

## 2. Official in_app_purchase plugin: what you must build yourself, effort and pitfalls

### Takeaway
`in_app_purchase` 3.3.1 handles only the on-device purchase UI and the purchase stream. It does not support web.

Everything that makes a subscription trustworthy has to be built and run on the backend:
- verifying purchases with Apple's signed transactions and the Google Play Developer API;
- acknowledging Google purchases within 3 days;
- receiving App Store Server Notifications V2 and Google Real-time Developer Notifications (RTDN) over Pub/Sub;
- handling refunds and voids, grace and hold periods, and replaying missed events.

That is the work RevenueCat replaces.

### Cited Findings
- The latest `in_app_purchase` is **3.3.1**, "Published 2 months ago" (about late September 2026). — [pub.dev in_app_purchase](https://pub.dev/packages/in_app_purchase)
  - Platforms: Android (SDK 24+), iOS (13.0+), macOS (10.15+). **No web.**
  - Platform packages: `in_app_purchase_android ^0.5.0`, `in_app_purchase_storekit ^0.4.0`, `in_app_purchase_platform_interface ^1.4.0`.
  - It does not do server verification. It links to the store guides and says consumables restored across devices need you to "persist them on your own server".
  - Google upgrades and downgrades use `ChangeSubscriptionParam` with a `ReplacementMode`.
- **Google: verify on the backend.** Google's flow is: show the product, launch the purchase, "Verify the purchase on your server", grant, acknowledge. It recommends "passing the token to your secure backend server". — [Android: Integrate Play Billing](https://developer.android.com/google/play/billing/integrate)
- **Google: acknowledge within three days.** Acknowledgement "must be done **within three days so that the purchase isn't automatically refunded and entitlement revoked**". — [Android: Integrate Play Billing](https://developer.android.com/google/play/billing/integrate)
  - Google recommends `Purchases.subscriptions.acknowledge` from the backend after checking `acknowledgementState` through `purchases.subscriptionsv2.get`.
  - "All initial subscription purchases need to be acknowledged. Subscription renewals don't need to be acknowledged."
  - Do not rely on the acknowledgement window expiring as a way to reject purchases.
- **Google: user identifiers.** Attach `obfuscatedAccountId` / `obfuscatedProfileId` (for example an obfuscated user ID) for fraud detection and to attribute purchases to the right user. — [Android: Integrate Play Billing](https://developer.android.com/google/play/billing/integrate)
- **Google: subscription states.** Active, Cancelled (access until expiry), In grace period (access), On hold (no access), Paused, Expired. — [Android: Integrate Play Billing](https://developer.android.com/google/play/billing/integrate)
- **Google RTDN content.** RTDN arrives through Cloud Pub/Sub as base64 JSON. "These notifications tell you only that the purchase state changed... You must call the Google Play Developer API" (`purchases.subscriptionsv2.get`). — [RTDN reference](https://developer.android.com/google/play/billing/rtdn-reference)
  - Subscription `notificationType` codes: 1 RECOVERED, 2 RENEWED, 3 CANCELED, 4 PURCHASED, 5 ON_HOLD, 6 IN_GRACE_PERIOD, 7 RESTARTED, 8 PRICE_CHANGE_CONFIRMED (deprecated), 9 DEFERRED, 10 PAUSED, 11 PAUSE_SCHEDULE_CHANGED, 12 REVOKED, 13 EXPIRED, 17 ITEMS_CHANGED, 18 CANCELLATION_SCHEDULED, 19 PRICE_CHANGE_UPDATED, 20 PENDING_PURCHASE_CANCELED, 21 PLAN_TRANSITION_UPDATED, 22 PRICE_STEP_UP_CONSENT_UPDATED.
  - Other notification kinds: `voidedPurchaseNotification` (refunds, with `refundType`) and `pendingRefundReviewNotification`, which asks for a refund suggestion within 24 hours through the `ReviewRefund` API.
  - Use `messageId` to de-duplicate.
- **Apple notification retries.** For App Store Server Notifications V2, "it retries five times, at 1, 12, 24, 48, and 72 hours after the previous attempt". **"In the sandbox environment, the App Store server attempts to send the notification one time."** — [Apple: Responding to App Store Server Notifications](https://developer.apple.com/tutorials/data/documentation/appstoreservernotifications/responding-to-app-store-server-notifications.json)
  - Success is HTTP 200–206; 40x and 50x trigger a retry.
  - Recover missed notifications with **Get Notification History**. After outages, use **Get Transaction History** and **Get All Subscription Statuses**.
- **Apple's Node library.** `@apple/app-store-server-library` covers the App Store Server API client, `SignedDataVerifier` (verifies the JWS notification payload against Apple root certificates you download), `ReceiptUtility` and promotional offer signing. It requires **Node 22+**; no release date was shown. — [GitHub apple/app-store-server-library-node](https://github.com/apple/app-store-server-library-node)
- **Google Play sends purchases made outside the app.** Products can now be bought from the Play Store details page and from Gemini ("agentic commerce", which covers subscriptions). The app and backend must detect and deliver these purchases through RTDN. — [Android: Test Play Billing](https://developer.android.com/google/play/billing/test)

### Inferences
- **Do-it-yourself scope with `in_app_purchase` and Express**:
  - (a) A `POST /billing/apple/verify` route that takes the StoreKit transaction, verifies the JWS with `SignedDataVerifier`, and calls Get All Subscription Statuses.
  - (b) A `POST /billing/google/verify` route that calls `subscriptionsv2.get` with a Google service account, then acknowledges the purchase.
  - (c) An HTTPS endpoint for App Store Server Notifications V2, plus a scheduled job that calls Get Notification History.
  - (d) A Pub/Sub push endpoint for RTDN that re-fetches `subscriptionsv2.get` on every message.
  - (e) Handling for voided purchases and refunds.
  - (f) Mapping store accounts to users through `obfuscatedAccountId` on Google; Apple's equivalent is not verified here, see Gaps.
  - (g) Idempotency tables.
  
  My rough estimate is several engineer-weeks for a robust first version plus ongoing maintenance, against roughly 1–3 days to integrate RevenueCat. This estimate is not sourced.
- **Pitfalls:**
  - Apple sandbox sends each notification only once, so bugs hide in testing.
  - Google auto-refunds unacknowledged purchases after 3 days, and after about 3–5 minutes for license testers.
  - RTDN messages carry no state, so you must call the API.
  - Out-of-app purchases mean the app might never see the purchase.
  - Apple's Node library wants Node 22+, while the backend declares Node >=20.
- **Web.** `in_app_purchase` has no web support, so the web plan needs a separate processor either way.

### Gaps
- I did not verify whether `in_app_purchase_storekit` 0.4.x uses StoreKit 2 by default, or whether it exposes Apple's `appAccountToken` for mapping purchases to users.
- No primary source gave effort numbers for a do-it-yourself build; the estimate above is an inference.
- The Apple page on JWS verification steps was not readable (it renders with JavaScript). The verification details rest on Apple's library README.

---

## 3. Web/B2B billing in India: Razorpay Subscriptions vs Stripe Billing, RBI e-mandates, UPI Autopay, fees, GST, linking to app entitlements

### Takeaway
For an Indian business selling team plans on the web, **Razorpay Subscriptions is the practical choice**. It supports UPI Autopay and cards, quantity-based (per-seat) billing that can change on a live subscription, and has no setup fee.

Stripe has two problems here:
- **New Indian Stripe accounts are invite-only** (since May 2024 and still the case).
- RBI e-mandate rules make plan and seat changes awkward. You cannot update a mandate, and charges above the mandate maximum or ₹15,000 need extra authentication.

Linking is done through your own user and organization IDs in the backend, not through the stores.

### Cited Findings
**Stripe availability and e-mandate rules**
- **Stripe India is invite-only.** "Businesses from India are not able to sign up for a new Stripe account through our website, and instead need to request an invite". Existing accounts are still supported. Announced May 2024; no later reversal found. — [Stripe Support: invite-only in India](https://support.stripe.com/questions/stripe-accounts-are-invite-only-in-india); [YourStory, May 2024](https://yourstory.com/2024/05/us-payments-giant-stripe-services-invite-only-basis-india)
- **RBI e-mandate requirements**, as described by Stripe: — [Stripe: India recurring payments](https://docs.stripe.com/india-recurring-payments?integration=subscriptions)
  - a one-time mandate registered with additional factor authentication (3DS, or UPI PIN);
  - customers "must be alerted at least 24 hours before charges";
  - "Recurring transactions over 15,000 INR... must go through AFA each time";
  - "UPI doesn't support off-session transactions of greater than 15,000 INR";
  - this applies to India-based and international Stripe users charging India cards or UPI.
- **Stripe-specific behaviour.** — [Stripe: India recurring payments](https://docs.stripe.com/india-recurring-payments?integration=subscriptions)
  - Mandates are supported **only through Subscriptions**, not PaymentIntents or SetupIntents.
  - Stripe waits 26 hours before charging cards; for UPI it sends the pre-debit notice and charges a day later.
  - India-issued cards get **one attempt only, regardless of retry settings**.
  - Card mandates cover only India-issued Visa, Mastercard, Discover and Diners Club.
  - "You can't pass an existing mandate to a Subscription" and "You can't cancel or update a mandate".
  - For billing-interval changes or upgrades, Stripe recommends bringing the customer back on-session to cancel and re-create the subscription.
  - Mandates default to `amount_type=maximum`; amounts above the mandate amount or ₹15,000 need authentication.
  - Test cards exist (for example 4000003560000123), and a new failure-simulation flow requires API version `2026-09-30.endive`.
- **Stripe UPI.** UPI supports recurring payments through e-mandates (UPI AutoPay), which the customer authorizes in their UPI app. — [Stripe: UPI](https://docs.stripe.com/payments/upi); [Stripe: UPI AutoPay](https://docs.stripe.com/payments/upi/upi-autopay)
- **Regulatory update (secondary source).** Secondary sources say the RBI issued a consolidated e-mandate framework on 21 April 2026. I could not check this against the RBI text. — [cloudsoftzone blog](https://www.cloudsoftzone.com/blog/upi-autopay-vs-card-e-mandates-india-2026)
- **Conflicting source.** A June 2026 Salarybox comparison says Stripe India does not natively support e-NACH or UPI Autopay. That contradicts Stripe's own docs, so trust Stripe's docs. — [Salarybox](https://salarybox.in/blog/cheapest-payment-gateway-for-recurring-billing-in-india-e-nach-and-upi-autopay-cost-compared-2026/)

**Razorpay fees and features**
- **Standard fees.** — [Razorpay pricing](https://razorpay.com/pricing/)
  - 2% platform fee for domestic Visa, Mastercard, Amex, Diners, RuPay debit and UPI ("UPI is MDR-free", so the 2% is a platform fee).
  - **18% GST on Razorpay's fee.**
  - Setup fee Rs. 0 and annual maintenance charge Rs. 0.
- **Subscriptions fees.** Cards are "0.9% + platform fees" per transaction; UPI, NACH and e-mandate pricing is "on request". — [Razorpay pricing](https://razorpay.com/pricing/)
- **Razorpay Subscriptions features.** — [Razorpay Subscriptions FAQ](https://razorpay.com/docs/payments/subscriptions/faqs.md); [Razorpay supported methods](https://razorpay.com/docs/payments/subscriptions/supported-payment-methods.md); [Razorpay UPI recurring](https://razorpay.com/docs/payments/recurring-payments/upi.md)
  - UPI Autopay works with PhonePe, Google Pay, Paytm, BHIM and others.
  - The supported-methods page lists a **mandate-creation maximum of ₹1,00,000**.
  - Quantity billing: the example is ₹100 per user per month with quantity 5, giving ₹500.
  - Plan amount, duration and **quantity can be updated even while the subscription is live**.
  - **Add-ons are deprecated.**
  - Customers can pause UPI-authorised subscriptions from their UPI app.

### Inferences
- **Seats on Razorpay.** Model the team plan as a Razorpay subscription with `quantity = seats`. Seat increases raise each debit, so watch the ₹15,000 extra-authentication threshold for UPI (UPI cannot debit above ₹15,000 off-session at all). A 20-seat plan at ₹999 per seat (₹19,980 a month) would exceed it. Annual team plans would almost always exceed it. Offer invoice or manual payment (Razorpay invoices, or Stripe `send_invoice`) for larger teams.
- **Mobile fees compared.** Razorpay's 2% + 18% GST on the fee (about 2.36% in total) is far below the 15% store commission (section 6). That is one reason to sell team plans on the web, but see the in-app link limits in section 4.
- **Linking to the app.** The web checkout runs for a logged-in Talk It Out user and organization. The checkout passes `org_id` / `user_id` in Razorpay `notes` (or Stripe `metadata`). The Razorpay webhook updates the backend entitlement tables, and the mobile app reads entitlements from our API, not from RevenueCat or the stores.
- **If Stripe is used.** If an invite is obtained or a non-India entity is used, RevenueCat's Stripe integration could carry seats (per-unit quantity) into RevenueCat. But UPI is excluded there, and RevenueCat Billing excludes India and B2B, so a direct Stripe-webhook-to-backend path is simpler.

### Gaps
- **GST invoices:** I did not confirm whether Razorpay Subscriptions automatically issues GST-compliant tax invoices with the customer's GSTIN and place of supply, or whether a separate Razorpay Invoices product or accounting tool is needed. Check with Razorpay docs and a CA.
- Razorpay webhook signature and retry behaviour, and exact UPI Autopay subscription fees, were not retrieved; the pricing page says "on request".
- Stripe India fees were not retrieved. RevenueCat's pages quote US pricing only.
- The secondary claim that the ₹15,000 extra-authentication limit is raised to ₹1 lakh for some categories was not verified for SaaS.

---

## 4. Server-side entitlement design: PostgreSQL state, webhooks, entitlement checks in API routes, grace periods, team seats, idempotency (and recommended architecture)

### Takeaway
Make the **Express/PostgreSQL backend the single source of truth for entitlements**. It takes events from two sources: RevenueCat webhooks for the mobile individual plan, and Razorpay (or Stripe) webhooks for web team plans.

Store every event in an idempotency table keyed by provider event ID. Re-fetch the canonical state (RevenueCat `GET /subscribers`) instead of trusting event order. Gate API routes with an `entitlement` check that counts grace periods as active.

### Cited Findings
**RevenueCat webhooks** — [RevenueCat webhooks](https://www.revenuecat.com/docs/integrations/webhooks.md)
- Authentication: you set an Authorization header in the dashboard that is sent with every POST, and "Your server should verify the validity of the authorization header for every notification". Optional HMAC `X-RevenueCat-Webhook-Signature` is available, with a 5-minute replay tolerance suggested.
- Retries: any response other than 200 is a failure. RevenueCat retries up to 5 times at about 2.5, 5, 10, 20 and 40 minutes, about 80 minutes in total, and failed events can be retried manually.
- Timeout: "If your server doesn't finish the response in 60s, RevenueCat will disconnect". Respond fast and process later.
- Idempotency: delivery is at-least-once, so "guard against duplicated events by making your webhook processing idempotent", tracking the event `id`.
- Canonical state: RevenueCat recommends calling `GET /subscribers` after any webhook for a consistent data format.
- Environment: `environment: SANDBOX` comes from the store transaction, and one customer can have both sandbox and production transactions. Webhooks can be filtered by environment.
- Cancellation timing: cancellation events usually arrive within about 2 hours of the user cancelling.

**Store-side state and identifiers**
- Google states to model: grace period (access kept) versus account hold (no access). — [Android: Integrate Play Billing](https://developer.android.com/google/play/billing/integrate)
- Google: `obfuscatedAccountId` ties a purchase to your user. — [Android: Integrate Play Billing](https://developer.android.com/google/play/billing/integrate)
- Google: RTDN `messageId` should be de-duplicated. — [RTDN reference](https://developer.android.com/google/play/billing/rtdn-reference)
- Apple: up to 5 retries over about 7 days in production. — [Apple notifications](https://developer.apple.com/tutorials/data/documentation/appstoreservernotifications/responding-to-app-store-server-notifications.json)

**Store rules that shape the design**
- Apple 3.1.3(b) Multiplatform Services: apps "may allow users to access content, subscriptions, or features they have acquired in your app on other platforms or your web site... provided those items are also available as in-app purchases within the app." — [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- Apple 3.1.3(c) Enterprise Services: "If your app is only sold directly by you to organizations or groups for their employees or students... you may allow enterprise users to access previously-purchased content or subscriptions. Consumer, single user, or family sales must use in-app purchase." — [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- Apple 3.1.1(a): external purchase links and buttons are allowed only in the **US storefront**. "In all other storefronts... apps and their metadata may not include buttons, external links, or other calls to action that direct customers to purchasing mechanisms other than in-app purchase." — [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- Apple 3.1.2(a): subscriptions must last at least 7 days and "be available across all of the user's devices." — [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- Google Play India: developers offering an alternative billing system for users in India pay the standard fee "reduced by 4%". — [Google Play service fees](https://support.google.com/googleplay/android-developer/answer/112622)

### Inferences
**Recommended architecture**
1. **Mobile individual plan** uses `purchases_flutter`, optionally with `purchases_ui_flutter` paywalls on iOS 15+ and Android 24+.
   - After login, call `Purchases.logIn(<backend user UUID>)` so the RevenueCat app user ID equals our user ID.
   - Configure App Store Server Notifications V2 and Google RTDN to point at RevenueCat (RevenueCat's standard setup; not separately verified in this session).
   - RevenueCat then sends its webhook to `POST /billing/webhooks/revenuecat` on our backend.
2. **Web team/seat plan** uses Razorpay Subscriptions with `quantity = seats`.
   - Checkout runs on the web app for a logged-in org admin, with `notes: {org_id, user_id}`.
   - Webhooks go to `POST /billing/webhooks/razorpay`.
   - This is allowed in the iOS app under 3.1.3(c) when sold only to organizations. The iOS app (non-US storefronts) must **not** link or point to the web checkout; it can only let org members sign in and use their seat.
   - If the team plan is ever sold to individuals or families, it must also be offered as IAP (3.1.3(b) / 3.1.3(c)).
3. **The app reads entitlements from our API**, for example `GET /me/entitlements`, not from RevenueCat `CustomerInfo` alone. Only the backend knows about Razorpay team seats. RevenueCat `CustomerInfo` can still drive the paywall UI, with the API response winning on conflict.

**Suggested PostgreSQL tables** (an illustrative design, not sourced)
- `billing_events(provider text, event_id text, received_at timestamptz, processed_at timestamptz, payload jsonb, PRIMARY KEY(provider, event_id))`.
  - Use `INSERT ... ON CONFLICT DO NOTHING`, return 200 at once, then process asynchronously. This matches RevenueCat's 60s timeout and at-least-once delivery.
- `subscriptions(id uuid, provider text CHECK (provider IN ('revenuecat','razorpay','stripe')), external_id text, owner_type text ('user'|'org'), owner_id uuid, product_id text, status text, period_end timestamptz, grace_until timestamptz, will_renew bool, environment text, quantity int, updated_at timestamptz, raw jsonb, UNIQUE(provider, external_id))`.
  - Keep `status` as text with an application-level enum that tolerates unknown values, mirroring this repo's "tolerate unknown enum" rule.
- `org_seats(org_id uuid, user_id uuid, assigned_at timestamptz, PRIMARY KEY(org_id, user_id))`, with a check at assignment time that `count(*) <= subscriptions.quantity`.
- A view or function `user_entitlements(user_id)`, defined as the union of:
  - active user subscriptions where `coalesce(grace_until, period_end) > now()`;
  - org subscriptions where the user holds a seat.

**Entitlement check in API routes**
- Express middleware `requireEntitlement('premium')` queries `user_entitlements`. Cache it per request, or for a short time, and invalidate the cache on webhook processing.
- On a cache miss right after purchase, the app can call `POST /billing/sync`, which fetches RevenueCat `GET /subscribers/{id}`. This covers webhook delay.

**Ordering, grace and seat removal**
- Do not depend on event order. On each RevenueCat event, re-fetch the subscriber and upsert. On each RTDN or Razorpay event, re-fetch the canonical object.
- Grant access during store grace periods. Revoke on account hold, expiration, revocation or refund.
- For team plans, when quantity drops below the number of assigned seats, flag the org and let the admin choose which seats to remove. Do not drop them at random.

### Gaps
- RevenueCat's event-type list (INITIAL_PURCHASE, RENEWAL, CANCELLATION, EXPIRATION, BILLING_ISSUE, PRODUCT_CHANGE, TRANSFER and so on) is on a separate page that I did not retrieve. Names are not verified here.
- RevenueCat webhook ordering guarantees are not documented on the page.
- Apple Family Sharing for subscriptions, which could stand in for "family" plans, was not researched.
- I found no sourced reference implementation of a PostgreSQL entitlement schema; the schema above is my design.

---

## 5. Testing and required store setup for an Indian developer

### Takeaway
Use RevenueCat's Test Store for early development, then the platform sandboxes:
- Apple: TestFlight runs in sandbox, with daily renewals capped at 6.
- Google: license testers get test cards and 5–30 minute renewals, plus Play Billing Lab.
- Stripe or Razorpay test modes for web.

Selling requires accepting Apple's Paid Apps Agreement first, then US tax forms and banking. Google requires a payments profile, and Indian developers handle their own GST and provide a GSTIN where required.

### Cited Findings
**RevenueCat Test Store** — [RevenueCat sandbox testing](https://www.revenuecat.com/docs/test-and-launch/sandbox.md)
- RevenueCat provisions a **Test Store** with every new project. It works without App Store Connect or Play Console access, updates `CustomerInfo` and entitlements, and must be swapped for platform API keys before production.
- Platform sandboxes are "a required step before launch", and sandbox purchases are detected automatically.
- A "Sandbox data" dashboard toggle exists, and access to sandbox entitlements can be restricted to specific App User IDs.

**Apple: TestFlight**
- "Each subscription is renewed daily, up to 6 times within a 1-week period, regardless of the subscription's duration." — [Apple: TestFlight subscriptions](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testing-subscriptions-and-in-app-purchases-in-testflight)
- "Apps downloaded from TestFlight will automatically operate in a sandbox environment." — [Apple: TestFlight subscriptions](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testing-subscriptions-and-in-app-purchases-in-testflight)
- Sandbox Apple Accounts work only for apps in your own developer account. — [Apple: TestFlight subscriptions](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testing-subscriptions-and-in-app-purchases-in-testflight)
- The Apple sandbox supports testing renewals, state changes, interrupted purchases, win-back offers, and so on. — [Apple: Testing in sandbox](https://developer.apple.com/help/app-store-connect/test-in-app-purchases/overview-of-testing-in-sandbox)
- The sandbox sends App Store Server Notifications only once, with no retries. — [Apple notifications](https://developer.apple.com/tutorials/data/documentation/appstoreservernotifications/responding-to-app-store-server-notifications.json)

**Google: license testers and Play Billing Lab** — [Android: Test Play Billing](https://developer.android.com/google/play/billing/test)
- License testers can sideload debug builds whose package name matches the Play listing. They get test payment methods (always approves, always declines, slow card, chargeback) with no real charges.
- Renewal timings: 1 week and 1 month renew every **5 minutes**, 3 months every 10 minutes, 6 months every 15, 1 year every 30. There are at most 6 renewals.
- Other test periods: free trial 3 minutes, grace period 5 minutes, account hold 10 minutes.
- Acknowledgement window for testers:
  - The text says an unacknowledged tester purchase is refunded after **3 minutes**.
  - The feature table lists "Purchase acknowledgement" as **5 minutes**.
  - The page is inconsistent with itself.
- Play Billing Lab can:
  - change the Play country;
  - repeat trial offers;
  - test price changes;
  - force grace period or account hold;
  - test out-of-app purchases.
- Testers on a test track who are not license testers are **charged real money**.
- Draft and internal-track apps have spend limits.

**Apple setup**
- "In order to submit tax forms, you first need to sign the Paid Apps Agreement. All developers must complete a US tax form". — [App Store Connect Help: tax forms overview](https://developer.apple.com/help/app-store-connect/provide-tax-information/tax-forms-overview)
- Banking information is also required, and submitted forms can't be edited in App Store Connect. — [App Store Connect Help: tax forms overview](https://developer.apple.com/help/app-store-connect/provide-tax-information/tax-forms-overview)
- Enrolling in the Small Business Program requires accepting the latest Paid Apps agreement (Schedule 2). — [Apple Small Business Program](https://developer.apple.com/app-store/small-business-program/)
- For India, Apple's tax-ID table (alternative payment options context) lists the **GSTIN** registration number. This comes from a Japanese-language page; I couldn't confirm the English wording. — [App Store Connect Help (JP)](https://developer.apple.com/jp/help/app-store-connect/manage-tax-information/provide-tax-information-for-alternative-payment-options/)

**Google setup**
- India-based developers must work out their own GST obligation, and those required to hold a GSTIN must provide it to Google. — [Google Payments Center help](https://support.google.com/paymentscenter/answer/7421525)

**Web**
- Stripe test cards for India mandates are listed in section 3. — [Stripe: India recurring payments](https://docs.stripe.com/india-recurring-payments?integration=subscriptions)

### Inferences
- **Suggested testing order:**
  1. RevenueCat Test Store in the Flutter app; this works on this Mac without Xcode or emulator setup.
  2. Google internal testing track with license testers on a real device.
  3. iOS TestFlight.
  4. Razorpay or Stripe test mode on the web.
- Because the Apple sandbox never retries notifications, test webhook failure paths with RevenueCat's manual retry and Get Notification History.
- **Local constraint:** `AGENTS.md` says this Mac has no Android emulator and an incomplete Xcode. Store purchase testing needs a physical Android device or a working Xcode, plus a paid Apple Developer account. Neither can be tested on the Flutter web-server preview.

### Gaps
- Apple's accelerated sandbox renewal table (non-TestFlight sandbox, for example how many minutes a 1-month subscription takes) and StoreKit Configuration file testing in Xcode were not retrieved from primary sources in this session.
- I did not retrieve the exact Google Play merchant/payments-profile steps for Indian developers (bank account, PAN), or how Apple handles Indian GST on its commission.
- Whether Apple requires a W-8BEN from Indian individual developers versus companies was not confirmed; the help page says only "US tax form".

---

## 6. Alternatives (Adapty, Qonversion, Glassfy) and price comparison

### Takeaway
Adapty (free under $5K MTR, then 1%) and Qonversion (free to $7K MTR, then 0.8% of total revenue) both have more generous free tiers than RevenueCat (free under $2.5K, then 1%). Glassfy has shut down, according to a competitor's claim.

None of these changes the India web constraint. Store commissions of 15% dwarf any of these fees.

### Cited Findings
**Adapty** — [Adapty pricing](https://adapty.io/pricing/)
- Free while tracked revenue is under **$5K/month**.
- **Pro is 1% of MTR** beyond $5K, "No tiers, no fixed fees". Billing continues even if revenue later drops below $5K.
- Enterprise has custom pricing.
- The flow and paywall builder, A/B tests and analytics are listed under Pro.
- Web payments work through Stripe and Paddle, and a Flutter SDK is listed.
- G2 shows a "$99.00 Per Month" Pro listing, which looks outdated. — [G2 Adapty pricing](https://www.g2.com/products/adapty-io/pricing)

**Qonversion** — [Qonversion pricing](https://qonversion.io/pricing)
- Free at or under **$7,000 MTR**.
- Beyond that, **0.8% of total tracked revenue**: $64 at $8K, $400 at $50K.
- Includes a no-code paywall builder, A/B experiments, Stripe and Paddle integrations, and webhooks.
- **Conflict:** Qonversion's own marketing page says "Free Tier Up to $10k MTR" and "$6 per $1k MTR/mo", which contradicts its pricing page. Trust the pricing page. — [Qonversion Glassfy-alternative page](https://qonversion.io/glassfy-alternative)

**Glassfy**
- Qonversion's page says "Glassfy Has Shut Down" and offers a migration guide. This is a vendor claim; no shutdown date was found. — [Qonversion Glassfy alternative](https://qonversion.io/glassfy-alternative)
- A third-party blog calls Adapty the de facto successor. — [apppricinglab](https://apppricinglab.com/playbook/best-iap-subscription-tools)

**RevenueCat, for comparison**
- Free under $2.5K MTR, then 1% of MTR. — [RevenueCat pricing](https://www.revenuecat.com/pricing/)

**Store commissions, which dominate the cost**
- **Apple Small Business Program: "a reduced commission rate of 15% on paid apps and Apple In-App Purchases"** for developers with up to $1M in proceeds in the prior and current calendar years. — [Apple Small Business Program](https://developer.apple.com/app-store/small-business-program/)
- The page also says a further reduced 10% applies "for developers on the alternative terms in the EU... and for subscriptions after their first year". The wording is ambiguous; it may refer only to EU alternative terms. — [Apple Small Business Program](https://developer.apple.com/app-store/small-business-program/)
- **Google Play: 15% for auto-renewing subscriptions in remaining markets (which includes India)**, regardless of revenue. — [Google Play service fees](https://support.google.com/googleplay/android-developer/answer/112622)
- In Australia, the EEA, Japan, the UK and the US, Google's new structure is 10% plus a 5% billing fee. Regional rollout dates are 2026-06-30 (EEA, UK, US) and 2026-09-30 (Australia, Japan). — [Google Play service fees](https://support.google.com/googleplay/android-developer/answer/112622)

### Inferences
- **Monthly cost of the subscription tool at three revenue levels:**

  | MTR | RevenueCat | Adapty | Qonversion |
  |---|---|---|---|
  | $2K | $0 | $0 | $0 |
  | $6K | about $60 | about $60 | $0 |
  | $20K | about $200 | about $200 | about $160 |

- At these levels the differences are small next to the 15% store fee. Choosing RevenueCat is justified by:
  - the maturity of its Flutter SDK (verified publisher, 926 likes, very frequent releases);
  - Customer Center;
  - documented webhooks.

  Qonversion is the cheapest option if cost matters most.
- None of the three was shown to support Razorpay. The web team plan stays outside these tools in every option.

### Gaps
- I did not verify current `pub.dev` versions or Dart constraints for `adapty_flutter` or `qonversion_flutter`. Qonversion's pricing page does not name a Flutter SDK.
- No primary source gave the Glassfy shutdown date.
- No independent comparison of SDK reliability between the vendors was found.
