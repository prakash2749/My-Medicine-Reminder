# MED-008 System Design: Encrypted Local Persistence and Migrations

## 1. Executive Summary & Objective

**Backlog ID:** MED-008  
**Release Phase:** M1 (Core MVP)  
**Priority:** P0 (Phase-blocking)  
**Proposed Role:** B — Domain / Platform  
**Target:** Robust, encrypted, zero-cloud-leakage local storage architecture for user medication schedules, dose histories, inventory ledgers, and reminder synchronization.

This system guarantees that:
1. Patient health data remains on-device, protected by hardware-backed encryption keys and SQLCipher.
2. Migrations between schema and payload versions (v1 -> v2 -> v3) execute safely with validation and rollback on error without wiping prior data.
3. Plaintext leaks via OS backups (`adb backup`, iOS iCloud Backup, Android Auto Backup) are explicitly disabled.
4. Background tasks and native notification actions can safely access the authoritative store using transaction-serialized locks without racing the UI.

---

## 2. Architecture & Component Decomposition

```
+-------------------------------------------------------------+
|                     Presentation Layer                      |
| (Today Timeline, Add/Edit Medicine, Refills, History Views) |
+------------------------------+------------------------------+
                               |
                               v
+-------------------------------------------------------------+
|               MedicineReminderProvider (State)              |
+------------------------------+------------------------------+
                               |
                               v
+-------------------------------------------------------------+
|               MedicineStore Interface (Contract)            |
|       - activate(owner)                                     |
|       - load(owner) -> MedicineData                         |
|       - change(owner, transform) -> MedicineData            |
|       - reconcile(sync) -> void                             |
+------------------------------+------------------------------+
                               |
       +-----------------------+-----------------------+
       |                                               |
       v (Mobile / macOS)                              v (Web / Desktop Fallback)
+-------------------------------+             +-------------------------------+
|     EncryptedMedicineStore    |             |     SecureSnapshotStore       |
|  - SQLCipher SQLite           |             |  - Platform Secure Storage    |
|  - Random 256-bit DB Key      |             |  - Serialized JSON Snapshot   |
|  - Atomic Transactions        |             +-------------------------------+
+---------------+---------------+
                |
                v
+-------------------------------+
|     FlutterSecureStorage      |
|  - Android KeyStore           |
|  - iOS / macOS Keychain       |
|    (first_unlock_this_device) |
+-------------------------------+
```

### 2.1 Database Schema (SQLite Level)

On SQLite-capable platforms (Android, iOS, macOS), the database resides at `medicines-v1.db` in the application's private, non-backed-up data directory.

Tables:
1. `medicine_data`:
   ```sql
   CREATE TABLE medicine_data (
     owner TEXT PRIMARY KEY,
     payload TEXT NOT NULL
   );
   ```
   - `owner`: A SHA-256 or user UUID isolating data per authenticated account.
   - `payload`: Versioned JSON serialization of all medication schedules, revisions, dose events, and stock ledgers.
2. `medicine_settings`:
   ```sql
   CREATE TABLE medicine_settings (
     id INTEGER PRIMARY KEY CHECK(id=1),
     owner TEXT
   );
   ```
   - Singleton record tracking the currently active authenticated session. Prevents background workers or queued UI tasks from mutating records across an account switch boundary.

---

## 3. Data Versioning & Migration Pipeline

The payload format is versioned independently of the SQLite table schema. This decouples database connection logic from domain model evolution.

```
+--------------------------+
| Payload Version 1 (v1)   |
| - Base medications      |
| - Action events          |
+------------+-------------+
             |
             | Migration: Derive immutable dose snapshots for confirmed events
             v
+--------------------------+
| Payload Version 2 (v2)   |
| - Previous revisions     |
| - Immutable dose records |
| - Edit history retention |
+------------+-------------+
             |
             | Migration: Initialize stock accounts, stock entries, and recovery context
             v
+--------------------------+
| Payload Version 3 (v3)   |
| - Inventory ledger       |
| - Reminder recovery ctx  |
| - Timezone offset anchor |
+--------------------------+
```

### 3.1 Migration Rules
1. **Backward Compatibility:** `MedicineData.decode(jsonString)` handles version 1, 2, and 3 payloads.
2. **Deterministic Upgrade:** When loading a version 1 payload, recorded dose snapshots are reconstructed using the historical calendar dates and schedule rules so that past confirmed events are permanently anchored.
3. **Fail-Safe Integrity:** Any unsupported payload version (`version > 3` or invalid JSON structure) immediately throws a `FormatException` without overwriting the stored data or resetting the database.
4. **No Destructive Fallbacks:** If decryption or decoding fails, the store does **not** auto-delete or re-seed empty data. A user notification or error screen must inform the user rather than causing silent data loss.

---

## 4. Security, Key Management & Platform Backup Policy

### 4.1 Key Storage
- **Key Generation:** A cryptographically secure 256-bit random key (`Random.secure().nextInt(256)`) is created upon initial database creation.
- **Storage:** Saved into `FlutterSecureStorage` under key `medicine.database.key.v1`.
- **iOS Keychain Attribute:** `first_unlock_this_device`. The database remains accessible after the first device unlock, allowing scheduled background reminder maintenance even while the screen is locked.
- **Key Missing with Existing Database:** If the database file exists on disk but the key is missing from secure storage, the application explicitly throws `StateError('The existing medicine database key is unavailable.')` to prevent corrupting or overwriting user data.

### 4.2 Backup & Plaintext Leak Prevention
- **Android `AndroidManifest.xml`:**
  - `android:allowBackup="false"`
  - `android:fullBackupContent="false"`
  - Excludes the app database and SharedPreferences from cloud backup transfers and `adb backup` extraction.
- **iOS `Info.plist` & Container:**
  - Uses private application support directory excluded from iTunes / iCloud backups (`NSURLIsExcludedFromBackupKey`).
- **No Plaintext Logging:** Payload JSON and medical names/dosages are strictly excluded from debug logs and crash breadcrumbs.

---

## 5. Concurrency, Serialization & Native Access

1. **Mutation Mutex (`_serial` queue):**
   All store operations (`activate`, `load`, `change`, `reconcile`) pipe through a sequential `Future` chain (`_tail`), guaranteeing single-writer execution.
2. **Transaction Isolation:**
   `change(owner, transform)` executes within an exclusive SQL transaction:
   - Queries `medicine_settings` to verify `activeOwner == owner`.
   - Reads existing authoritative data.
   - Computes the new `MedicineData` using the pure `transform` function.
   - Writes the new payload atomically.
   - If an exception occurs, the transaction rolls back cleanly without dirtying memory state.
3. **Reconciliation Lock:**
   Native alarms (scheduled via `MedicineNotifications`) and WorkManager background tasks synchronize via `reconcile()`, ensuring that reminder scheduling and database persistence do not interleave.

---

## 6. Acceptance Criteria Traceability Matrix

| Acceptance Criteria | Architectural Implementation | Verification Method |
| :--- | :--- | :--- |
| **AC1: Restart and Version Survival** | SQLCipher disk storage with v1 -> v2 -> v3 upward migration and version validation in `MedicineData.decode`. | Automated unit test with historical v1 payload asserting preservation of dose history. |
| **AC2: Health Data Backup Exclusion** | `allowBackup="false"` in Android manifest; iOS secure storage with `first_unlock_this_device`. | Manifest analysis and static inspection of OS attributes. |
| **AC3: Key Management & Recovery** | Missing key detection prevents database recreation; key failure fails closed with explicit error. | Unit test simulating missing key with existing DB path. |
| **AC4: Atomic Account Switching** | `medicine_settings` table check inside transaction; rejection of cross-account mutations. | Race-condition test with active account switch. |
