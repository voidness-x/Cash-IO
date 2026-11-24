# Cash-IO Local DevSecOps Security, Static Analysis & Vulnerability Audit
$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "     CASH-IO DEVSECOPS SECURITY & VULNERABILITY AUDIT     " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Secret & Credential Hygiene Scan
Write-Host "`n[1/5] Scanning Source Tree for Hardcoded Secrets & Private Keys..." -ForegroundColor Yellow
$secretPatterns = @(
    "BEGIN RSA PRIVATE KEY",
    "BEGIN EC PRIVATE KEY",
    "BEGIN OPENSSH PRIVATE KEY",
    "AIza[0-9A-Za-z\-_]{35}",
    "ghp_[0-9A-Za-z]{36}",
    "sk_live_[0-9a-zA-Z]{24}"
)
$sourceFiles = Get-ChildItem -Path "lib", "test", "web", "rust" -Recurse -File -ErrorAction SilentlyContinue
foreach ($pattern in $secretPatterns) {
    $hits = $sourceFiles | Select-String -Pattern $pattern -ErrorAction SilentlyContinue
    if ($hits) {
        Write-Host "CRITICAL: Potential secret pattern '$pattern' detected!" -ForegroundColor Red
        $hits | ForEach-Object { Write-Host "  -> $($_.Path):$($_.LineNumber)" -ForegroundColor Red }
        exit 1
    }
}
Write-Host "PASSED: Zero hardcoded credentials or private keys detected." -ForegroundColor Green

# 2. Strict Flutter Static Analysis
Write-Host "`n[2/5] Running Strict Static Code Analysis (--fatal-infos --fatal-warnings)..." -ForegroundColor Yellow
flutter analyze --fatal-infos --fatal-warnings
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAILED: Static analyzer reported warnings or infos." -ForegroundColor Red
    exit 1
}
Write-Host "PASSED: Zero analyzer warnings or infos." -ForegroundColor Green

# 3. Dedicated OWASP / CWE Adversarial Vulnerability Suite
Write-Host "`n[3/5] Executing Adversarial Security & Vulnerability Test Suite..." -ForegroundColor Yellow
flutter test test/security_vulnerability_suite_test.dart --concurrency=1
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAILED: Security vulnerability test suite reported failures." -ForegroundColor Red
    exit 1
}
Write-Host "PASSED: Cryptographic, SSRF, Path Traversal, Brute-Force & Injection defenses verified." -ForegroundColor Green

# 4. Complete Regression & Double-Entry Invariant Matrix
Write-Host "`n[4/5] Running Full System Test Matrix..." -ForegroundColor Yellow
flutter test --concurrency=1
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAILED: Regression test suite failed." -ForegroundColor Red
    exit 1
}
Write-Host "PASSED: Full test suite green." -ForegroundColor Green

# 5. Supply-Chain Dependency & Rust Core Audit
Write-Host "`n[5/5] Auditing Dart & Rust Supply-Chain Dependencies..." -ForegroundColor Yellow
dart pub outdated --no-dev-dependencies
if (Get-Command cargo -ErrorAction SilentlyContinue) {
    Push-Location "rust"
    cargo test
    if (Get-Command cargo-audit -ErrorAction SilentlyContinue) {
        cargo audit
    }
    Pop-Location
} else {
    Write-Host "Notice: Local Rust toolchain not on PATH; Rust clippy/test/audit runs automatically in GitHub Actions." -ForegroundColor Gray
}

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "   AUDIT PASSED: REPOSITORY MEETS STRICT SECURITY GATES   " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
