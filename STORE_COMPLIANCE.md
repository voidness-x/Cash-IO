# Cash-IO: App Store & Google Play Store Compliance Declaration

**Application Name:** Cash-IO  
**Package Identifier:** `com.cashio.app`  
**Classification:** Financial Management / Offline-First Personal Finance  
**Security Architecture:** Zero-Knowledge Client-Side AES-256-GCM + Argon2id  

---

## 1. Apple App Store Compliance

### 1.1 Privacy Nutrition Labels (App Privacy Questionnaire)
Under Apple Guidelines, Cash-IO collects **zero personal data**:

| Category | Policy Declaration | Justification |
| :--- | :--- | :--- |
| **Data Used to Track You** | **None** | No ad networks, tracking SDKs, device fingerprinting, or IDFA collection. |
| **Data Linked to You** | **None** | The app does not require creating a centralized account or submitting email/phone numbers. |
| **Data Not Linked to You** | **None** | All transactions, account balances, and receipt attachments remain strictly on-device in an encrypted sandbox. |

### 1.2 Cryptographic Export Compliance (U.S. EAR & French ANSSI)
* **Encryption Used:** Standard authenticated symmetric encryption (AES-256-GCM) and key derivation (Argon2id).
* **U.S. Export Administration Regulations (EAR):**
  * The software qualifies for **EAR Section 742.15(b)** (Mass Market Encryption Software).
  * Exemption Question on App Store Connect: *"Does your app use encryption?"* $\rightarrow$ **YES**.
  * Follow-up: *"Does your app qualify for any exemptions provided under Category 5, Part 2?"* $\rightarrow$ **YES** (Mass-market consumer software utilizing standard, non-proprietary cryptographic algorithms).
* **Self-Classification Report (ECCN):** 5D992.c (Mass market software).

---

## 2. Google Play Store Compliance

### 2.1 Google Play Data Safety Form
When submitting to the Google Play Console:

1. **Does your app collect or share any user data?**
   * Select: **No**.
2. **Is all user data encrypted in transit?**
   * Select: **Yes** (Client-side AES-256-GCM before pushing to Google Drive `drive.appdata`).
3. **Do you provide a way for users to request data deletion?**
   * Select: **Yes** (Users can wipe profile vaults locally with one tap; uninstalling immediately deletes all local SQLite and Keystore data).

### 2.2 Google API Services User Data Policy (Google Drive Scope Disclosure)
* **Requested Scope:** `https://www.googleapis.com/auth/drive.appdata`
* **Prominent Disclosure for Google Reviewers:**
  > *"Cash-IO requests access solely to the hidden Application Data folder (`drive.appdata`). Cash-IO does NOT request or access any user documents, spreadsheets, photos, or general Drive files. It only writes opaque, client-side AES-256 encrypted backups (`vault.enc`) to synchronize financial event logs across the user's personal devices."*

---

## 3. Zero-Telemetry Architecture Verification

* **Third-Party Trackers:** 0
* **Crash Reporters:** 0 (Crash logs handled via OS-level opt-in only)
* **Advertising Frameworks:** 0
* **External Network Calls:** Strictly limited to:
  1. *Google Drive API* (`drive.appdata`) — strictly opt-in upon user tapping "Connect".
  2. *Public Exchange Rate Feed* — strictly opt-in upon user tapping "Refresh Rates".
  3. *GitHub Releases Signed OTA Manifest* (`https://github.com/voidness-x/Cash-IO/releases`) — anonymous HTTPS manifest & SHA-256 checksum verification for direct builds (disabled on store-managed builds where required by store guidelines).
