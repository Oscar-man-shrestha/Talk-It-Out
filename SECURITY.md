# Security & Privacy Policy 🛡️

Talk It Out is engineered from the ground up for psychological safety and zero-knowledge privacy. We take security, identity decoupling, and vulnerability disclosure with the utmost seriousness.

---

## 🔒 Supported Versions

Only the latest release branch receives active security updates and patches:

| Version | Supported |
|---|---|
| `1.x.x` | :white_check_mark: Yes |
| `< 1.0.0` | :x: No |

---

## 🛡️ Core Security & Privacy Commitments

1. **Zero-Knowledge Decoupling:** In public deliberation rooms, anonymous messages have their `author_id` set to `NULL` at the database level and emit `sender: null` across all API and WebSocket streams.
2. **Hardware-Backed Storage:** Authentication tokens and session secrets are stored strictly within `flutter_secure_storage` (iOS Keychain, Android KeyStore, encrypted local enclaves). Tokens are never written to unencrypted LocalStorage or application logs.
3. **No Profiling or Probing:** Submissions that are rejected by room controllers receive zero feedback strings to prevent automated trial-and-error probing attacks against AI moderation or identity filters.
4. **Isolated Memory Enclaves:** The internal raw representation of a message (`RawMessage`) is cryptographically and architecturally barred from group-facing code.

---

## 🚨 Reporting a Vulnerability

If you discover a security vulnerability or identity leak within Talk It Out:

1. **Do NOT open a public GitHub issue.**
2. Send an email to **security@talkitout.app** with:
   - A clear description of the vulnerability (e.g., identity unmasking, token exposure, SQL traversal).
   - Step-by-step reproduction instructions or a minimal Proof of Concept (PoC).
   - Potential impact on anonymity or data integrity.
3. We will acknowledge receipt of your vulnerability report within **48 hours** and provide regular status updates until a patch is deployed.
4. Once resolved, we will publish a coordinated security advisory and credit researchers responsibly.
