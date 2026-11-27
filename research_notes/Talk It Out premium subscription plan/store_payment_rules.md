# App-Store Payment Rules for Selling Subscriptions in a Mobile App (Apple + Google, India focus, as of Nov 2026)

Research date: 2026-11-26. Scope: a solo founder in India selling (a) a consumer "Plus" subscription and (b) a B2B team/seat plan for a Flutter app on iOS, Android and web. Nothing here is legal advice. Several items are under active litigation (US Supreme Court, Supreme Court of India, CCI), and store pages change often. Re-check the primary pages before shipping.

## Q1. Apple App Store Review Guidelines 3.1.1, 3.1.2 and 3.1.3(b)/(c): can a business buy seats on the web and members unlock them in the iOS app? What may the app say or link to?

### Takeaway
Digital features and subscriptions sold inside the iOS app must use Apple In-App Purchase (IAP) (3.1.1). Web-bought access can be honoured in the app under 3.1.3(b) Multiplatform Services, but only if the same items are also available as IAP. 3.1.3(c) Enterprise Services lets org-bought seats unlock without IAP, but its text covers apps "only sold directly by you to organizations". An app that also sells a consumer Plus plan may not fit that cleanly (this is uncertain). Outside the US storefront the app may not steer users to web purchase, but you may email your users about other ways to pay. On the US storefront, buttons and links to web purchase are now allowed.

### Cited Findings
- **3.1.1 (IAP required):** "If you want to unlock features or functionality within your app, (by way of example: subscriptions, … access to premium content, or unlocking a full version), you must use in-app purchase. Apps may not use their own mechanisms to unlock content or functionality, such as license keys, augmented reality markers, QR codes…" — [Apple App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- **3.1.1 restore:** Apps "should make sure you have a restore mechanism for any restorable in-app purchases." — [Apple Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- **3.1.1(a) Link to Other Purchase Methods:** Developers may apply for StoreKit External Purchase Link entitlements "in specific regions" to link to a permitted destination. "These entitlements are not required for developers to include buttons, external links, or other calls to action in their United States storefront apps." In all other storefronts "except for the United States storefront … apps and their metadata may not include buttons, external links, or other calls to action that direct customers to purchasing mechanisms other than in-app purchase." — [Apple Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- **3.1.2(a) Permissible uses:** An auto-renewable subscription must "provide ongoing value", "the subscription period must last at least seven days and be available across all of the user's devices". SaaS and cloud support are listed as appropriate. Free trials are configured in App Store Connect. Bait-and-switch or scam subscriptions are removed and can cost you your developer account. — [Apple Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- **3.1.2(b):** Users "should not be able to inadvertently subscribe to multiple variations of the same thing", and upgrades and downgrades must be seamless. — [Apple Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- **3.1.2(c):** "Before asking a customer to subscribe, you should clearly describe what the user will get for the price … Ensure you clearly communicate the requirements described in Schedule 2 of the Apple Developer Program License Agreement." — [Apple Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- **3.1.3 intro:** Apps under 3.1.3 "cannot, within the app, encourage users to use a purchasing method other than in-app purchase, except for apps on the United States storefront and as set forth in 3.1.1(a) and 3.1.3(a). Developers can send communications outside of the app to their user base about purchasing methods other than in-app purchase." — [Apple Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- **3.1.3(b) Multiplatform Services:** "Apps that operate across multiple platforms may allow users to access content, subscriptions, or features they have acquired in your app on other platforms or your web site … provided those items are also available as in-app purchases within the app." — [Apple Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- **3.1.3(c) Enterprise Services:** "If your app is only sold directly by you to organizations or groups for their employees or students (for example professional databases and classroom management tools), you may allow enterprise users to access previously-purchased content or subscriptions. Consumer, single user, or family sales must use in-app purchase." — [Apple Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- **3.1.3(f) Free stand-alone apps:** Free companion apps to a paid web tool are exempt from IAP only for VoIP, cloud storage, email services or web hosting, and only with "no purchasing inside the app, or calls to action for purchase outside of the app". A group-chat product is not one of the listed categories. — [Apple Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- **5.1.1(v):** "If your app supports account creation, you must also offer account deletion within the app." — [Apple Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- **Apple multiapp subscriptions:** Before showing subscription options, verify whether the user is already an active subscriber. — [Apple: Auto-renewable subscriptions](https://developer.apple.com/app-store/subscriptions/)

### Inferences
- **Consumer Plus on iOS (all storefronts):** Plus must be sold through IAP inside the iOS app. Selling Plus only on the web and unlocking it in iOS, with no IAP option, would conflict with 3.1.1 and with the "also available as in-app purchases" condition in 3.1.3(b). A web Plus plan is fine as long as an IAP Plus also exists. Note that 3.1.3(b) does not require equal pricing.
- **B2B team plan on iOS, two possible routes, both with uncertainty:**
  1. **3.1.3(c) route.** The org buys on the web and members sign in and get team features with no IAP. The guideline text says the *app* is "only sold directly by you to organizations". Talk It Out also sells consumer Plus, so a reviewer could say the app is not enterprise-only. Whether Apple applies 3.1.3(c) per feature or plan in a mixed consumer + B2B app is not stated in the guidelines (uncertain). Lower-risk ways to use it:
     - The team plan is clearly org-purchased: invoiced, priced per seat, with an admin console on the web.
     - Members cannot buy anything team-related in the app.
     - The iOS app shows no "buy team plan" call to action outside the US.
  2. **3.1.3(b) route.** Also offer an IAP version of the team product, for example an admin subscribing to a "Team" IAP tier in the app. This fits 3.1.3(b) literally. But IAP is tied to one Apple ID, and seat-based billing for other people's accounts is awkward. Feasibility is not verified.
- **Team access through invite codes.** Invite codes or "license keys" that unlock paid features are expressly listed as forbidden "own mechanisms" in 3.1.1, unless an exception such as 3.1.3(b) or (c) applies. So the team-unlock flow should be framed as signing into an org-paid account (3.1.3(c)) rather than redeeming a code.
- **What the iOS app may say outside the US (India included):** No buttons, links or "cheaper on our website" text that steers users to the web. Neutral account sign-in is fine. Email, push campaigns outside the app and the website may tell users about web pricing (3.1.3 intro).
- **Cross-device rule:** Because 3.1.2(a) requires subscriptions to be "available across all of the user's devices", an IAP Plus should also unlock on Android and web. That means server-side entitlements keyed to the Talk It Out account, not to the store.

### Gaps
- Apple does not publish whether 3.1.3(c) can apply to one B2B plan inside an app that also sells consumer IAP. App Review outcomes for mixed apps are case by case. No authoritative source was found.
- The "last updated" date of the guidelines page was not visible in the fetched text. The US-storefront language matches Apple's May 2025 revision. See Q2.
- The full Schedule 2 text (DPLA §3.8 subscription disclosure requirements) was not fetched.
- The regions currently eligible for the StoreKit External Purchase Link Entitlement were not listed in the fetched text. It was not verified whether India is among them. I believe it is not, but this is unconfirmed.

## Q2. The 2025 US changes after Epic v. Apple: what is allowed now, where, at what commission, and the status of appeals in 2026

### Takeaway
On the **US storefront only**, iOS apps may since May 2025 include buttons and links to buy on the web. Apple currently reportedly charges **no commission** on those linked-out purchases. The Ninth Circuit (December 2025) upheld the contempt finding but said Apple may eventually charge a cost-based, non-prohibitive fee, to be set on remand. The US Supreme Court granted Apple's petition on 30 June 2026, limited to one question about contempt. The case is being briefed and is undecided as of late November 2026. None of this applies to the India storefront.

### Cited Findings
- **April 2025 contempt order.** In April 2025 the district court held Apple in civil contempt of the 2021 injunction. It barred Apple from charging any commission on link-out purchases and from imposing most link-related conditions. — [SCL LLP summary (29 Dec 2025)](https://scl-llp.com/ninth-circuit-upholds-apple-contempt-finding-but-narrows-scope-of-remedial-relief/); [Courthouse News](https://www.courthousenews.com/ninth-circuit-confirms-contempt-finding-against-apple-in-epic-games-battle/)
- **Apple's response, May 2025.** Apple changed its US App Store rules to let apps link to external payment systems. — [TechCrunch, 2 May 2025](https://techcrunch.com/2025/05/02/apple-changes-us-app-store-rules-to-let-apps-redirect-users-to-their-own-websites-for-payments/)
- **US-only carve-out in today's guidelines.** In all storefronts "except for the United States storefront", apps may not include buttons, external links or calls to action to other purchase methods. — [Apple Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- **Ninth Circuit, December 2025.** A unanimous panel affirmed the contempt finding "in full". It agreed that Apple's 27% commission was prohibitive in effect and that its link-design restrictions violated the injunction. It reversed the bar on *any* commission, calling it closer to a "punitive criminal contempt sanction". — [SCL LLP](https://scl-llp.com/ninth-circuit-upholds-apple-contempt-finding-but-narrows-scope-of-remedial-relief/); [Fenwick](https://www.fenwick.com/insights/publications/ninth-circuit-largely-upholds-ruling-in-epic-v-apple); [Cravath](https://www.cravath.com/news-insights/epic-games-ninth-circuit-win-affirming-civil-contempt-finding.html)
  - **Commission standard on remand.** Apple may charge a commission "based on the costs that are genuinely and reasonably necessary for its coordination of external links for linked-out purchases, but no more". That may include some IP compensation, but "not much". Security and privacy features are excluded. Any negotiated fee must be approved by Judge Gonzalez Rogers. — [SCL LLP](https://scl-llp.com/ninth-circuit-upholds-apple-contempt-finding-but-narrows-scope-of-remedial-relief/); [Ashurst Perkins Coie](https://www.ashurstperkinscoie.com/en/insights/epic-v-apple-the-ninth-circuit-weighs-in/)
  - **Prominence.** Apple may require that IAP be displayed at least as prominently as link-outs. — [Courthouse News](https://www.courthousenews.com/ninth-circuit-confirms-contempt-finding-against-apple-in-epic-games-battle/) (as summarized in search results)
  - TechCrunch described the ruling as the court partially reversing the restrictions Epic won on iOS. — [TechCrunch, 11 Dec 2025](https://techcrunch.com/2025/12/11/epic-gamess-fortnite-is-back-in-us-google-play-store-as-court-partially-reverses-restrictions-it-won-on-ios/)
- **US Supreme Court filings in 2026:**
  - 4 May 2026: Apple applied to stay the Ninth Circuit mandate (No. 25A1213). — [SCOTUS docket PDF](https://www.supremecourt.gov/DocketPDF/25/25A1213/407958/20260504154515930_2026-05-04%20Apple-Epic%20SCT%20Application%20to%20Stay%20Mandate.pdf)
  - 26 May 2026: Apple filed its cert petition (No. 25-1311). — [Cert petition](https://www.supremecourt.gov/DocketPDF/25/25-1311/409561/20260526163506450_2026-05-26%20Apple-Epic%20--%20Cert%20Petition%20and%20Appendix.pdf)
  - 30 June 2026: certiorari reportedly granted "limited to Question 1 presented by the petition", which leaves the commission and steering rules themselves outside review. — [MacObserver](https://www.macobserver.com/news/supreme-court-apple-epic-appeal-question-1-narrow/) (the page could not be fetched, so this detail comes from the search snippet only)
  - 12 August 2026: Apple applied to stay the district-court remand proceedings (No. 26A194). — [SCOTUS application](https://www.supremecourt.gov/DocketPDF/26/26A194/418814/20260812134307741_2026-08-12%20SCOTUS%20-%20Application%20for%20Stay%20of%20District%20Court%20Proceedings%20w%20Apps.pdf); [Apple's district-court stay motion, Aug 2026](https://www.courthousenews.com/wp-content/uploads/2026/08/motion-stay-epic.pdf)
  - 14 September 2026: Apple filed its merits brief, arguing the injunction never covered commissions and that contempt cannot rest on the "spirit" of an order. — [Apple merits brief](https://www.supremecourt.gov/DocketPDF/25/25-1311/424150/20260914154510009_2026-09-14%20No.%2025-1311%20Apple-Epic%20Merits%20Opening%20Brief.pdf); [Sigma Law Group](https://sigmalawgroup.com/blog/2026-09-15-apple-epic-supreme-court-contempt-brief/); [MacObserver](https://www.macobserver.com/news/apple-supreme-court-brief-epic-injunction-never-covered-commissions/)
  - 32 states and D.C. filed in support of Epic. — [iClarified](https://iclarified.com/103809/32-states-and-dc-back-epic-in-apples-supreme-court-appeal); background: [AEI](https://www.aei.org/domestic-policy/technology-and-innovation/the-apple-epic-feud-goes-to-the-supreme-court-over-a-question-of-judicial-power/)
- **Current commission on US link-outs.** Search-result summaries of Apple's 2026 filings say Apple has said it will not charge any commission on link-out purchases while the Supreme Court decides. — [Apple stay motion (Aug 2026)](https://www.courthousenews.com/wp-content/uploads/2026/08/motion-stay-epic.pdf) (reported through search summaries, not read in full)

### Inferences
- **For a US user on iOS today:** Talk It Out could show a "Subscribe on the web" button next to IAP and keep the full web price apart from payment-processor fees. That holds until a remand fee is set or the Supreme Court rules otherwise. Expect a possible future cost-based fee and prominence rules (IAP at least as visible as the link).
- **For India, EU and the rest of the world:** These US changes do not apply. The India storefront keeps the anti-steering rule (Q1).
- If the Supreme Court vacates the contempt finding, Apple could reinstate a commission and link restrictions on the US storefront. A US-steering strategy should therefore be treated as revocable.

### Gaps
- The exact day of the Ninth Circuit opinion was not confirmed. Sources say December 2025, and TechCrunch reported on 11 December 2025.
- Not found:
  - the outcomes of Apple's May 2026 application to stay the mandate (25A1213) and its August 2026 application (26A194)
  - any oral-argument date
  - whether any remand commission has been set
- The cert-grant scope ("Question 1 only") rests on one outlet's snippet, because the page returned 403.
- **EU differences for Apple, not verified this run.** Apple's EU alternative terms (DMA) use a different fee structure with link-out entitlements. Apple's Small Business Program page mentions a "further reduced commission of 10%" for "developers on the alternative terms in the EU" ([Apple SBP](https://developer.apple.com/app-store/small-business-program/)). The full EU fee schedule was not fetched.

## Q3. Google Play Payments policy: when Play Billing is required, exceptions, alternative and user choice billing (India and elsewhere), and B2B or outside purchases

### Takeaway
Play-distributed apps must use Google Play Billing for in-app digital purchases, including subscriptions and "business productivity software". The exceptions are physical goods and similar items, enrolment in a regional alternative-billing or link-out program, or being **consumption-only**, meaning content bought elsewhere and nothing sold in the app. In **India**, User Choice Billing (an alternative biller alongside Play Billing) has been available since 2023 at a 4-point lower service fee. India's legal challenges (CCI, NCLAT, Supreme Court) are still unresolved. In the US, EEA and UK, a new structure from 30 June 2026 splits a 10% subscription service fee from a 5% Play-Billing fee, and link-outs and alternative billing are allowed through programs.

### Cited Findings
- **Payments policy, Section 2.** Play-distributed apps must use Play Billing for in-app purchases of digital items, including subscriptions, app features and cloud services, "unless Section 3, 8, or 9 applies". — [Google Play Payments policy](https://support.google.com/googleplay/android-developer/answer/9858738)
- **Section 3 exceptions.** Play Billing must *not* be used for:
  - physical goods
  - certain physical services
  - credit card and utility bill remittances
  - peer-to-peer payments, auctions and tax-exempt donations
  - real-money gambling content

  — [Payments policy](https://support.google.com/googleplay/android-developer/answer/9858738)
- **Section 4 (anti-steering):** "apps may not lead users to a payment method other than Google Play's billing system". This covers listings, in-app promotions, webviews, links and sign-up flows, unless Section 3, 8 or 9 applies. — [Payments policy](https://support.google.com/googleplay/android-developer/answer/9858738)
- **Sections 8 and 9.** In eligible countries or regions, developers enrolled in the relevant program may offer an alternative billing system in the app (Section 8) or lead users outside the app (Section 9). — [Payments policy](https://support.google.com/googleplay/android-developer/answer/9858738)
- **Consumption-only apps are allowed:**
  - "Google Play allows any app to be consumption-only, even if it is part of a paid service." Example: "a user could log in when the app opens and access content paid for somewhere else".
  - In a consumption-only app, products "cannot be purchased from within the app".
  - Such apps may give general information without links, for example "Go to our website to upgrade your subscription to Premium".
  - Outside the app, "you are free to communicate with your users about alternative purchase options".
  - Links to account management, privacy policies or help pages are fine, provided they do not lead on to a prohibited payment method.

  — [Understanding Google Play's Payments policy (FAQ)](https://support.google.com/googleplay/android-developer/answer/10281818)
- **B2B software.** The FAQ lists "business productivity software, or financial management software" among cloud software and services that must use Play Billing when sold in the app. No separate enterprise exception was found. — [Payments policy FAQ](https://support.google.com/googleplay/android-developer/answer/10281818)
- **India and South Korea alternative billing.** Google offers "all developers the ability to offer an alternative billing system" next to Play Billing. The service fee is 4 percentage points lower when the user picks the alternative. — [Payments policy FAQ](https://support.google.com/googleplay/android-developer/answer/10281818); [Google Play service fees](https://support.google.com/googleplay/android-developer/answer/112622)
- **India options in practice.** Developers in India have three paths: Play Billing; an alternative biller alongside it (User Choice Billing, available since 2023); or a consumption-only model with no service fee. — [Business Standard, Nov 2026](https://www.business-standard.com/india-news/sc-questions-app-developers-on-opting-out-of-google-s-play-billing-system-126110301862_1.html); [MediaNama, Nov 2026](https://www.medianama.com/2026/11/223-google-play-billing-case-supreme-court/)
  - Earlier context: Google enforced its billing policy in India in 2023 while saying it complied with the CCI. — [TechCrunch, 17 May 2023](https://techcrunch.com/2023/05/17/google-pushes-ahead-with-in-app-billing-policy-in-india-insists-watchdog-compliance)
- **CCI and NCLAT:**
  - October 2022: the CCI fined Google ₹936.44 crore over its mandatory Play Billing.
  - March 2025: NCLAT partly upheld the CCI but cut the penalty to about ₹216.69 crore. It rejected the CCI's Section 4(2)(c) finding that Google denied market access to payment processors. Sources differ slightly on the amount (₹216.68 vs ₹216.69 crore).

  — [CompetitionLawyer.in](https://www.competitionlawyer.in/google-gets-some-relief-in-google-play-billing-case-in-appeal-nclats-reduces-penalties-and-rejects-ex-ante-regulation-by-cci/); [Vajiram & Ravi explainer](https://vajiramandravi.com/current-affairs/google-vs-cci-case-impact-on-indias-android-ecosystem-digital-market/)
- **Supreme Court of India, 3 November 2026:**
  - The Court heard developers' appeal against the Madras High Court judgment of 19 January 2024, which had rejected their civil suits over Play Billing and User Choice Billing.
  - It asked whether developer agreements let them opt out of Google's payment system, and it will decide whether a civil court or the CCI is the right forum.
  - Google argued that the CCI had already found its fees not unreasonable or excessive.
  - No final ruling was found.

  — [MediaNama](https://www.medianama.com/2026/11/223-google-play-billing-case-supreme-court/); [Business Standard](https://www.business-standard.com/india-news/sc-questions-app-developers-on-opting-out-of-google-s-play-billing-system-126110301862_1.html); [FVBB](https://fvbb.com/ns/sc-to-decide-forum-for-google-billing/328570)
- **US, EEA and UK (new structure from 30 June 2026):**
  - The service fee is now separate from the billing fee. The service fee "starts at 10% on your first $1M (USD) in annual earnings" and applies whatever the payment route (Play Billing, alternative billing or external web links).
  - "The 10% service fee also applies to all auto-renewing subscriptions."
  - In those regions "the billing fee is set at 5%". "For transactions processed via alternative billing or external web links, the billing fee does not apply."

  — [Android Developers Blog, 24 Jun 2026](https://android-developers.googleblog.com/2026/06/play-expanded-billing.html)
- **Billing choice program:** It is "available to all developers globally who provide digital services or content", starting with the US, UK and EEA. Developers may design their own choice screen within Google's UX guidelines, and Google says "we will continue expanding availability to additional markets". The blog did not mention India by name. — [Android Developers Blog](https://android-developers.googleblog.com/2026/06/play-expanded-billing.html); [Billing choice program enrollment](https://support.google.com/googleplay/android-developer/answer/17161464)
- **US external content links program:**
  - Enrolled developers must report transactions and pay service fees from 1 October 2026.
  - The fee deadline for external app downloads moved to 1 February 2027.
  - Reported download fees: $3.65 for games and $2.85 for apps.

  — [Play Console Help: external content links program (US)](https://support.google.com/googleplay/android-developer/answer/16470497?hl=en) (figures from the search summary; the page was not fetched in full)
- **Epic v. Google:**
  - November 2025: Google proposed a settlement allowing in-app alternative payments and external web links. — [TechCrunch, 5 Nov 2025](https://techcrunch.com/2025/11/05/epic-games-ceo-calls-googles-antitrust-settlement-a-win-for-androids-vision-as-an-open-platform/)
  - 4 March 2026: Google announced the settlement and dropped its commissions to 20% on IAP, plus 5% when developers use Google billing. — [TechCrunch, 4 Mar 2026](https://techcrunch.com/2026/03/04/google-settles-with-epic-games-drops-its-play-store-commissions-to-20/)
  - Google's help page says the "U.S. District Court's order remains in effect". — [Payments policy FAQ](https://support.google.com/googleplay/android-developer/answer/10281818)
- **EEA under the DMA.** Developers can offer EEA users an alternative to Play Billing in their apps and may direct users outside the app to offers, subject to program requirements. — [Payments policy FAQ](https://support.google.com/googleplay/android-developer/answer/10281818); [Service fees](https://support.google.com/googleplay/android-developer/answer/112622)

### Inferences
- **Consumer Plus on Android in India.** Choose between Play Billing only (15% fee for subscriptions, see Q4) and enrolling in User Choice Billing to add an Indian biller such as Razorpay or Cashfree. With User Choice Billing, Google's fee on alternative-billed transactions is about 11% (15% minus 4 points, inferred), plus your own payment-gateway fee and the work of complying with the RBI e-mandate rules (Q5). The saving is small, so Play Billing alone is the simpler default.
- **B2B team plan on Android.** Google's explicit carve-out is consumption-only: no purchasing in the app. Talk It Out will sell Plus in the app, so the app is not consumption-only overall. Whether a hybrid app may also honour web-bought team seats without offering them in Play Billing is not addressed in Google's text (see Gaps). The cautious design:
  - Team seats are bought only on the web by an admin.
  - The Android app shows no team purchase CTA or link outside program-enrolled regions.
  - Members simply sign in and get entitlements from the server.
- **Wording.** Outside enrolled regions, avoid "buy on our website" links in the Android app. Neutral text pointing to account management is lower risk. The "Go to our website…" text is explicitly allowed only for consumption-only apps.

### Gaps
- Not found: whether Google allows an app that sells a consumer subscription through Play Billing to *also* unlock an org-bought team plan purchased on the web. No Google text covers hybrid apps or B2B seats.
- Not confirmed whether US federal court approval of the Google–Epic settlement is final.
- The fee schedule beyond the first $1M for subscriptions in the US, EEA and UK was not legible ("Standard" label only).
- Billing-fee details for India and other markets: Google said "we'll announce billing fee details for other markets soon" (24 Jun 2026). No announcement was found.
- Not found: whether India was added to the new global billing choice program, or whether the old User Choice Billing terms still govern. This was the state as of the service-fees page fetch.
- One source says the CCI opened a separate probe into User Choice Billing. It was not verified in this run.

## Q4. Commission rates: Apple and Google standard, small-business, subscription and 2025–2026 changes

### Takeaway
- **Apple (outside EU-alternative and US link-out cases):** 30% standard, 15% under the Small Business Program (at most US$1M proceeds a year), and subscriptions fall to 15% after a subscriber has a year of paid service. Small Business Program members get 15% from day one.
- **Google, rest of world including India:** subscriptions 15%; other IAP 15% on the first US$1M, then 30%; alternative billing 4 points lower in India and South Korea.
- **Google, US/EEA/UK since 30 June 2026 (AU/JP since 30 Sept 2026):** subscriptions are a 10% service fee plus 5% if using Play Billing.
- **US iOS link-outs:** currently reported at 0% Apple commission (Q2).

### Cited Findings
- **Apple subscriptions:** "During a subscriber's first year of service, you receive 70% of the subscription price at each billing cycle, minus applicable taxes. After a subscriber accumulates one year of paid service, your net revenue increases to 85%."
  - Free trials and renewal extensions do not count toward the year.
  - Paid days resume if the subscription is recovered within 60 days.
  - Under the Small Business Program, "you receive 85% … regardless of whether or not the subscription has accumulated one year of paid service."

  — [Apple: Auto-renewable subscriptions](https://developer.apple.com/app-store/subscriptions/)
- **Apple Small Business Program:**
  - A "reduced commission rate of 15%" for developers with up to US$1M in proceeds in the prior calendar year, and for new developers.
  - Proceeds are counted net of commission and taxes, across all Associated Developer Accounts.
  - Above US$1M in the current year, the standard rate applies to the rest of that year.
  - You must enrol, accept the Paid Apps agreement and list associated accounts.
  - For "developers on the alternative terms in the EU in the App Store Small Business Program and for subscriptions after their first year, Apple will offer a further reduced commission of 10%".

  — [Apple Small Business Program](https://developer.apple.com/app-store/small-business-program/)
- **Apple in India (context).** Apple said more than 94% of App Store billings and sales facilitated in India accrued to developers without any commission to Apple. That figure includes free apps and physical goods. — [Apple Newsroom India, Apr 2025](https://www.apple.com/in/newsroom/2025/04/app-store-ecosystem-in-india-facilitated-rs-44447-crore-in-billings-and-sales)
- **Google, rest of world:** 15% on the first US$1M of annual revenue and 30% above; "Subscriptions are 15% regardless of revenue"; India and South Korea alternative billing is 4% below the Play Billing rate. — [Google Play service fees](https://support.google.com/googleplay/android-developer/answer/112622)
- **Google, AU/EEA/JP/UK/US new rate card:**
  - Auto-renewing subscriptions: 10% + 5% billing fee (new and existing installs), first US$1M tier.
  - Other IAP, new installs: 20% + 5%, or 15% + 5% in the Play Games Level Up / Apps Experience programs.
  - Other IAP, existing installs: 25% + 5%, or 20% via external web links.
  - Rollout: 30 June 2026 for the EEA, UK and US; 30 September 2026 for Australia and Japan.

  — [Google Play service fees](https://support.google.com/googleplay/android-developer/answer/112622); [Android Developers Blog, 24 Jun 2026](https://android-developers.googleblog.com/2026/06/play-expanded-billing.html)
- **Conflicting secondary reporting.** Secondary blogs differ on when US alternative-billing fees took effect, and an early-March-2026 piece said no new US fees applied. — [FoxData](https://foxdata.com/en/blogs/google-play-store-opens-external-billing-fees-drop-to-10-starting-june-30-2026/); [Neonpay](https://www.neonpay.com/blog/google-just-announced-new-play-store-fees-heres-whats-actually-happening--how-it-impacts-dtc); [RefundHalt](https://refundhalt.com/blog/google-play-us-alternative-billing-refunds). Google's own help page (1 Oct 2026 reporting start) is the better source.

### Inferences
- **A new Indian solo developer in year one:**
  - Apple Plus: 15% if enrolled in the Small Business Program (enrolment is not automatic). Otherwise 30% in the first year, then 15%.
  - Google Plus (India user): 15%, or about 11% via User Choice Billing plus gateway costs.
  - Web Plus or team plan through an Indian gateway: gateway fee only (commonly about 2%, not verified here), but you handle GST and RBI compliance yourself.
- **Apple's rates are calculated on price net of tax.** "minus applicable taxes" means the 15% or 30% applies after GST is deducted.

### Gaps
- Apple's standard 30% rate is not printed on the fetched Small Business Program page. It is implied by "70% … first year" on the subscriptions page.
- Not fetched: Apple's EU fee schedule (Core Technology Commission and store services tiers) and any 2026 Apple global fee changes. No 2025–2026 change to Apple's 30/15 rates outside the EU and US was found in this run, but it was not exhaustively checked.
- The Google rate above US$1M for subscriptions in new-structure regions is unclear.

## Q5. Required subscription UI (restore, pricing and terms, trial disclosure, cancellation, account deletion) and India-specific rules (RBI e-mandate, GST)

### Takeaway
- **Both stores require:**
  - clear plan name, duration and what is included
  - full renewal price as the most prominent pricing element
  - trial length and the price after it
  - how to cancel
  - links to Terms and Privacy
  - a way to sign in or restore
  - in-app account deletion; Google also needs a web deletion link
- **India, for anything billed outside the stores (web, User Choice Billing):** the RBI's April 2026 e-mandate framework applies. Auto-debits up to ₹15,000 per transaction need no extra authentication once the mandate is registered, and there is a 24-hour pre-debit notice with easy pause or revoke. GST is 18% on digital services.

### Cited Findings
- **Apple sign-up screen must include:**
  - "Subscription name and duration, and the content or services provided during the subscription period"
  - "Full renewal price, shown clearly and prominently, and localized"
  - "A way for current subscribers to sign in or restore purchases"

  Other Apple requirements:
  - The app and its metadata must link to the Terms of Use and Privacy Policy.
  - "the amount that will be billed must be the most prominent pricing element".
  - Free trials must "clearly indicate how long the free trial lasts and the price billed once the free trial is over".

  — [Apple: Auto-renewable subscriptions](https://developer.apple.com/app-store/subscriptions/)
- **Apple cancellation:** "always make it easy for people to access the system-provided management UI where they can cancel". `showManageSubscriptions(in:)` opens it in the app.
  - Family Sharing (up to 5 members) cannot be undone once enabled.
  - Offer codes are supported.
  - Billing grace period options are 3, 16 or 28 days.

  — [Apple: Auto-renewable subscriptions](https://developer.apple.com/app-store/subscriptions/)
- **Apple account deletion and restore:** in-app account deletion is required if accounts can be created (5.1.1(v)). Restorable IAP needs a restore mechanism (3.1.1). — [Apple Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- **Google Subscriptions policy:**
  - Be transparent about terms, cost, billing frequency, auto-renewal and whether a subscription is required. "Users should not have to perform any additional action to review the information."
  - Trials must state duration, price, content, when and how they convert, and how to cancel before conversion.
  - Provide an easy online cancellation method, such as a link to the Play Subscription Center in account settings.
  - Listed violations include:
    - annual plans that prominently show the monthly cost
    - SKUs named "Free Trial" that auto-charge
    - accidental-tap subscribe flows
    - missing cancellation links

  — [Google Play Subscriptions policy](https://support.google.com/googleplay/android-developer/answer/9900533)
- **Google account deletion:** Apps that allow account creation must provide an in-app path to delete the account and its data, and a web link where users can request deletion.
  - The web page must work, be relevant and name the app or developer as listed on Play.
  - Deactivating or "freezing" an account does not count as deletion.
  - Any data you retain must be disclosed in the privacy policy.
  - Announced April 2023, with Data safety form deadlines from 7 December 2023.

  — [Play Console Help: account deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en); [Android Developers Blog, Apr 2023](https://android-developers.googleblog.com/2023/04/giving-people-more-control-over-their-data.html)
- **RBI Digital Payments – E-mandate Framework, 2026** (21 April 2026, RBI/DPSS/2026-27/396). It consolidates earlier e-mandate circulars.
  - The issuer must send a pre-transaction notification "at least 24 hours prior to the actual charge / debit", naming the merchant, amount, date and time, reference numbers and reason.
  - Customers can set caps and can modify, pause or revoke mandates, validated with additional factor authentication (AFA).

  — [RBI Master Direction](https://www.rbi.org.in/Scripts/BS_ViewMasDirections.aspx?id=13374); [RBI notification PDF](https://rbidocs.rbi.org.in/rdocs/notification/PDFs/396MDD002E435ECA145509929FC3ACBCFD0E9.PDF)
- **₹15,000 limit (press reports).** Recurring debits up to ₹15,000 per transaction run without a fresh OTP once the mandate is registered. Above that, OTP or AFA is required. Insurance, mutual funds and credit-card bills have a ₹1 lakh ceiling. One report says banks may not charge for e-mandate services. — [Business Today, 21 Apr 2026](https://www.businesstoday.in/personal-finance/news/story/rbi-caps-recurring-payments-at-rs15000-without-otp-under-new-e-mandate-framework-526759-2026-04-21); [Business Today, 2 May 2026](https://www.businesstoday.in/personal-finance/news/story/rbi-auto-debit-rules-explained-what-new-changes-mean-for-your-upi-and-card-payments-528507-2026-05-02)
  - The earlier ₹15,000 limit dates from June 2022. — [Business Standard, Jun 2022](https://business-standard.com/article/finance/new-e-mandate-guidelines-rbi-enhances-limit-for-e-mandates-on-credit-debit-cards-to-rs-15-000-122060800417_1.html)
- **GST:** 18% on digital services (OIDAR) supplied in India. Since 1 October 2023, overseas OIDAR providers pay IGST on supplies to businesses as well as consumers. — [India Briefing](https://india-briefing.com/news/tax-digital-services-oidar-in-india-gst-applicability-and-compliance-22465.html); [India Briefing, Oct 2023 changes](https://www.india-briefing.com/news/indias-oidar-taxation-shift-key-changes-effective-october-1-2023-29757.html); [Business Standard, Sep 2023](https://business-standard.com/economy/news/new-gst-rules-to-tighten-compliance-for-foreign-digital-service-providers-123092701385_1.html)
- **Apple's India pricing (older, roughly 2020).** Apple raised Indian App Store and IAP prices by 2% on top of the 18% GST already in place. — [TechRadar](https://www.techradar.com/news/apple-is-raising-prices-in-app-store-and-in-app-purchases-in-india-and-elsewhere)
  - Apple pays developers "minus applicable taxes". — [Apple subscriptions](https://developer.apple.com/app-store/subscriptions/)

### Inferences
- **Store-billed Plus (IAP or Play Billing).** The store handles the payment mandate and generally the consumer-facing tax. Developer proceeds arrive net of tax and commission. Your RBI burden is minimal there.
- **Web Plus, team seats, or User Choice Billing.** Your payment gateway's recurring product (card e-mandate or UPI AutoPay) must follow the 2026 framework: 24-hour pre-debit notice, easy cancel or pause, and an AFA step above ₹15,000 per charge. A yearly team invoice above ₹15,000 would likely need customer authentication on each renewal, or should be billed by invoice or bank transfer rather than auto-debit.
- **GST registration and invoicing.** An Indian founder selling directly on the web probably has to register for GST once thresholds are crossed and charge 18%. B2B customers will want GST invoices for input-tax credit. This is not verified, so confirm with a CA.
- **Build one compliance checklist across stores and web:**
  - clear price and renewal terms
  - trial disclosure
  - a manage or cancel entry point in settings: the Apple system UI on iOS, the Play Subscription Center on Android, the gateway portal on web
  - restore or sign-in
  - in-app account deletion plus a web deletion page
  - Terms and Privacy links

### Gaps
- The exact effective date of the RBI 2026 framework, and its ₹15,000 and ₹1 lakh limits, were not confirmed from the RBI text itself. The fetched snippets did not include the limit tables.
- UPI AutoPay limits specifically were not verified.
- **How GST works on store sales was not confirmed from Apple or Google documentation:**
  - whether Apple or Google acts as the deemed supplier for GST on Indian sales
  - how Indian developers receive or report proceeds and claim credits
  - Google's India tax help page appeared in results ([Google tax info for India](https://support.google.com/product-documentation/answer/15152449?hl=de)) but was not read.
- Not covered:
  - GST registration thresholds and place-of-supply rules for an Indian developer's own web sales
  - TDS or TCS on gateway payouts, and export-of-service treatment for foreign web customers
- **Apple CCI case (India), pending.** The CCI's 24 June 2024 investigation report called the App Store an "unavoidable trading partner" that forced use of Apple's IAP.
  - In May 2026 the Delhi High Court told Apple to cooperate but barred a final CCI order before 15 July 2026.
  - Apple is separately challenging global-turnover penalties, in a petition filed November 2025.
  - No final CCI order was found. A "$38B" fine figure is only a press estimate.

  — [MacRumors, 19 May 2026](https://www.macrumors.com/2026/05/19/india-refuses-to-let-apple-pause-app-store-case/); [ThePrint](https://theprint.in/judiciary/what-is-the-antitrust-case-against-apple-why-has-delhi-hc-allowed-cci-probe-but-paused-final-order/2934606/); [Business Standard, Jun 2026](https://www.business-standard.com/companies/news/apple-agrees-to-provide-india-financial-data-to-cci-in-antitrust-case-126060400006_1.html); [Inc42](https://inc42.com/buzz/apple-antitrust-probe-delhi-hc-asks-cci-not-to-pass-final-order/)

  A future CCI order could change iOS steering rules in India. Status after July 2026 is unknown.
