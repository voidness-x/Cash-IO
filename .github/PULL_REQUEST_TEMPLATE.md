## Summary

<!-- Describe what changed and why. Reference any related issue IDs. -->

## Architectural & Security Checklist

- [ ] **Double-Entry Invariant:** Every recorded transaction enforces $\sum \text{postings} = 0$ with $\ge 2$ legs.
- [ ] **Zero-Telemetry Guarantee:** No analytics, crash trackers, or unapproved outbound network endpoints introduced.
- [ ] **Cryptographic & Enclave Safety:** No plaintext secrets, PINs, or recovery mnemonics written to disk or logs.
- [ ] **Static Analysis:** `flutter analyze --fatal-infos --fatal-warnings` passes with **0 issues**.
- [ ] **Automated Test Suite:** `flutter test --concurrency=1` (including `security_vulnerability_suite_test.dart`) passes 100%.

## Verification Evidence

<!-- Paste test output or UI screenshots here. -->
