# Contributing to Talk It Out 🤝

Thank you for your interest in contributing to **Talk It Out**! We are committed to fostering an inclusive, welcoming, and privacy-first engineering culture.

---

## 🔒 The Privacy Golden Rules (Non-Negotiable)

Before writing any code, every contributor must understand that Talk It Out is built around **strict cryptographic and architectural anonymity guarantees**. Pull requests violating any of the following rules will be rejected immediately:

1. **Group-Facing Isolation:** Group chat screens must use **only** `PublishedMessage`. If a message is marked `is_anonymous = true`, its sender must be `null` and render as `"Anonymous user"`.
2. **Review Enclave Isolation:** The `RawMessage` model is restricted exclusively to `lib/features/review/`. It must never be imported into contributor-facing or group-facing code. This rule is enforced automatically via `test/no_raw_message_import_test.dart`.
3. **No "Show Original" UI:** Under no circumstance may any button, long-press menu, or toggle reveal raw message text or real sender identities to peers.
4. **Mandatory Anonymity Disclosure:** The disclosure text (*"Anonymous messages are hidden from the group but visible to the controller."*) must always appear directly adjacent to the anonymity checkbox before Send.
5. **No Probe Rejections:** Rejection notifications must never contain rejection reasons or feedback text.
6. **Zero Raw Logging:** Raw text and real author IDs must never be logged, printed to console, or transmitted to analytics.

---

## 🛠️ Development Workflow

### 1. Prerequisites
- **Flutter SDK:** Version 3.22.x+ (stable channel)
- **Dart SDK:** Version 3.4.x+

### 2. Setup
```bash
# Clone the repository
git clone https://github.com/Oscar-man-shrestha/Talk-It-Out.git
cd Talk-It-Out

# Install packages
flutter pub get

# Generate immutable models and serializers
dart run build_runner build --delete-conflicting-outputs
```

### 3. Running Locally
Run the app in in-memory Mock Mode (no backend required):
```bash
flutter run -d web-server --web-port=52000 --dart-define=USE_MOCK=true
```

To test against your local or staging backend:
```bash
flutter run -d web-server --web-port=52000 \
  --dart-define=USE_MOCK=false \
  --dart-define=API_BASE_URL=http://localhost:3000/api/v1
```

---

## 📐 Code Style & Architecture Guidelines

- **Feature-First Architecture:** Group code by domain feature under `lib/features/<feature_name>/` (`data/`, `domain/`, `presentation/`).
- **State Management:** Use Riverpod 2.x `AsyncNotifier` or `Notifier`. Do not use `setState` for domain or network state.
- **Data Access:** All data operations must pass through repository interfaces (`*Repository`). UI widgets must never call Dio directly.
- **Strings:** Centralize all user-facing strings in `lib/core/strings/app_strings.dart`.
- **UI Design:** Adhere to the **Monochrome Precision** theme (`lib/app/theme.dart`). Use curated black, white, and subtle zinc borders (`#E4E4E7`). Ensure touch targets are at least 48x48dp.
- **Responsiveness:** Use adaptive padding calculations (`screenWidth > 860 ? (screenWidth - 800) / 2 : 16.0`) rather than rigid fixed-width containers that clip viewports.

---

## 🧪 Quality Gates (Mandatory Before Pull Requests)

Every commit and pull request must pass the three standard quality gates:

```bash
# 1. Check code formatting
dart format --output=none --set-exit-if-changed .

# 2. Static code analysis (must have 0 issues)
flutter analyze

# 3. Automated test suite (all tests must pass)
flutter test
```

---

## 📝 Pull Request Checklist

When opening a Pull Request:
- [ ] Code is formatted with `dart format .`
- [ ] `flutter analyze` reports 0 issues.
- [ ] `flutter test` passes (including `privacy_ui_test.dart` and `no_raw_message_import_test.dart`).
- [ ] No hardcoded tokens, URLs, or secrets.
- [ ] Updated `LOGS.md` with an entry describing your changes.
