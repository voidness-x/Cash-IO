# Contributing to Cash-IO

Thank you for contributing to **Cash-IO**. Because Cash-IO safeguards personal financial ledgers under an air-gapped, zero-knowledge security model, all contributions must uphold strict accounting, cryptographic, and code-quality invariants.

---

## Core Engineering Invariants

1. **Double-Entry Zero-Sum Invariant:**
   Every financial transaction must contain at least two `PostingModel` legs whose `amountCents` sum to **exact zero** ($\sum \text{postings} = 0$). Never store monetary amounts as `double` or `float`; always use integer minor units (`int` cents).
2. **Zero-Telemetry Privacy:**
   Never introduce third-party analytics, crash-reporting SDKs, ad identifiers, or background network telemetry. All advisory heuristics must execute 100% on-device.
3. **Cryptographic Hygiene:**
   - Never log PINs, derived keys, decrypted backup JSON, or 12-word BIP-39 recovery mnemonics.
   - Always use `Random.secure()` for salts, nonces, and entropy.
   - Always use `E2eePackager.constantTimeEquals` / `constantTimeStringEquals` when comparing authentication tags, hashes, or PIN verifiers.
4. **Strict Static Analysis:**
   All Dart code must pass `flutter analyze --fatal-infos --fatal-warnings` with **zero** issues, and Rust code in `./rust` must pass `cargo clippy --all-targets -- -D warnings`.

---

## Development Workflow

1. **Create a feature branch** from `main`:
   ```bash
   git checkout -b feat/short-description
   ```
2. **Follow Test-Driven Development (TDD):**
   Write failing unit or adversarial security tests in `test/` first, implement the minimal clean solution, and refactor.
3. **Run the full local DevSecOps audit before opening a PR:**
   ```powershell
   pwsh ./scripts/security_audit.ps1
   ```
4. **Use Conventional Commits:**
   - `feat(ledger): ...`
   - `fix(security): ...`
   - `ci(actions): ...`
   - `docs(security): ...`
   - `test(owasp): ...`
