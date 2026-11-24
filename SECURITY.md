# Security Policy & Threat Model

## Supported Versions

Only the latest minor release series receives active security patches via our store-independent GitHub Releases OTA channel (`https://github.com/voidness-x/Cash-IO/releases`).

| Version | Supported | Delivery Channel |
| :--- | :--- | :--- |
| `3.x.x` | Yes | GitHub Releases Signed OTA (`manifest.json` + SHA-256) |
| `< 3.0.0` | No | Upgrade to `3.x` |

---

## Reporting a Vulnerability

**Please do NOT report security vulnerabilities through public GitHub Issues.**

Instead, report suspected vulnerabilities privately via **GitHub Private Vulnerability Reporting** (`Security` tab $\rightarrow$ `Report a vulnerability` on [github.com/voidness-x/Cash-IO/security/advisories/new](https://github.com/voidness-x/Cash-IO/security/advisories/new)).

Please include:
1. Affected component and version/commit SHA.
2. Step-by-step proof-of-concept or unit test reproducing the issue.
3. Assessment of impact (confidentiality, ledger integrity, or availability).

We aim to acknowledge reports within **48 hours** and publish a verified patch + signed OTA manifest within **7 days** for critical findings.

---

## Threat Model (STRIDE) & Mitigations

| Threat Category | Adversarial Scenario | Implemented Control | Verification Suite |
| :--- | :--- | :--- | :--- |
| **Spoofing** | Brute-forcing a vault's 6-digit PIN or spoofing another profile's credentials. | Per-profile 256-bit `Random.secure()` salt, iterated PBKDF2-HMAC-SHA256 / Argon2id key derivation, constant-time hash comparison, and a 5-strike service-layer lockout (`HardwareVaultService`). | `test/security_vulnerability_suite_test.dart` |
| **Tampering** | Modifying encrypted `.cashio` backups, receipt `.bin` files, OTA binaries, or `.cashio.bak` rollback snapshots. | Encrypt-then-MAC (`HMAC-SHA256` with HKDF domain-separated subkeys) verified in constant time prior to decryption; SHA-256 verification on OTA payloads and rollback snapshots. | `test/security_vulnerability_suite_test.dart`, `test/phase4_security_sync_test.dart` |
| **Repudiation** | Silent balance drift or unrecorded mutations across synced devices. | Strict double-entry invariant ($\sum \text{postings} = 0$) + append-only CRDT mutation log ordered deterministically by `(lamport_clock, device_id)`. | `test/phase1_foundations_test.dart`, `test/phase2_services_test.dart` |
| **Information Disclosure** | OS app-switcher screenshot scraping, clipboard snooping, periodic XOR keystream leakage, or cross-vault receipt IDOR. | `AppPrivacyShield` overlay on background/inactive lifecycle states, 30s `ClipboardSanitizer` zeroization, non-repeating 256-bit counter-mode PRF keystream, and profile-scoped receipt keys. | `test/security_vulnerability_suite_test.dart`, `test/phase4_security_sync_test.dart` |
| **Denial of Service** | Oversized receipt uploads exhausting heap memory or corrupted OTA schema migrations breaking startup. | `maxReceiptSizeBytes` (10 MiB) hard cap, background `compute()` isolates for KDF/crypto, and automatic pre-update `.cashio.bak` rollback on invariant failure. | `test/security_vulnerability_suite_test.dart`, `test/phase6d_update_rollback_test.dart` |
| **Elevation of Privilege / Injection / SSRF** | Path traversal in receipt filenames (`CWE-22`), CSV formula execution (`CWE-1236`), SQL injection (`CWE-89`), OTA downgrade, or SSRF to internal/cloud metadata IPs. | Strict `^receipt_[A-Za-z0-9_-]+\.bin$` allowlist + `basename` check, CSV formula prefix neutralization (`'`), parameterized SQLite queries, build-number anti-downgrade gate, and HTTPS host/repo pinning (`github.com/voidness-x/Cash-IO`). | `test/security_vulnerability_suite_test.dart` |

---

## Automated DevSecOps Controls

Every commit and pull request is continuously verified by [`.github/workflows/security_audit.yml`](.github/workflows/security_audit.yml):

1. **Secret Detection:** [Gitleaks](https://github.com/gitleaks/gitleaks) scans full repository history for accidentally committed keys or tokens.
2. **Filesystem & IaC Vulnerability Scanning:** [Trivy](https://github.com/aquasecurity/trivy) scans for `CRITICAL` and `HIGH` CVEs and uploads SARIF findings to GitHub Code Scanning.
3. **Cross-Ecosystem Supply-Chain Audit:** [Google OSV-Scanner](https://github.com/google/osv-scanner), `cargo-audit` (RustSec Advisory DB), and `cargo-deny` validate `pubspec.lock` and `rust/Cargo.lock`.
4. **SBOM Generation:** Generates an SPDX JSON Software Bill of Materials on every run.
5. **Adversarial Unit Gate:** Executes `test/security_vulnerability_suite_test.dart` covering cryptographic bit-flip fuzzing, keystream non-periodicity, SSRF/downgrade rejection, CWE-22 path traversal, CWE-1236 CSV injection, and PIN lockout enforcement.
