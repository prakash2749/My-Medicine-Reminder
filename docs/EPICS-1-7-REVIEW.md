# Epics 1–7 implementation self-review

18 October 2026. This is an engineering self-review; independent teammate, human-study, physical-phone, fluent Hindi and legal review remain as listed in [the status matrix](EPICS-1-7-STATUS.md).

## Changes

- Added an offline-first welcome and unlimited, persistent local guest profile. It is a reserved local owner namespace, not a synthetic Supabase login. Existing signed-in records remain separate; no automatic guest/account migration or medicine upload is added.
- Added persistent Device/English/Hindi settings, translated core controls/validation and future notification actions, and numeric normalization. Plan IDs/timing, stored medicine names and instructions are preserved. Bundled OFL Noto Sans Devanagari renders report text without a font network request. A fluent reviewer must still approve terminology.
- Added local History PDF export/preview, original dose quantities/revisions/zones, self-reported denominator and unknown coverage. Flutter shapes pages offline and embeds compact JPEG pages directly so long reports do not retain full RGB pages. PDFs are not searchable/accessibility-tagged. Reports refuse more than 2,000 eligible records, 100 selected plans or 300 pages and never silently truncate. Multiline instructions paginate without changing the saved text. The user can select a shorter range/one medicine. Sharing requires an explicit tap and current health fingerprint. Native share caches are cleaned on startup/deletion/reset; external copies cannot be recalled.
- Added local-only allowlisted diagnostics, native test notification, private lock-screen content explanation, offline recovery help and erasure controls. No remote telemetry service or consent toggle for a nonexistent upload is introduced. Removed raw exception/deep-link payloads from app debug logs.
- Added a secure-storage reset marker and serialization with SQLite reconciliation. Reset cancels native alerts, deletes health profiles, database/key and named report caches, then activates an empty current profile. Failures remain visible, block further local mutations and can be retried. Opening a marked store retries cleanup. A corrupt or partially initialized database can be erased only after an explicit reset request; a normal failed open preserves it.
- Made DST semantics match the documented contract: a missing wall time moves to the first valid minute of that local date; a repeated time uses the later instant once; a wholly skipped calendar date produces no dose. Original occurrence identity keeps the requested wall minute. This is reminder scheduling, not clinical dose advice.
- Added real study/device protocols and an evidence matrix. Prior competitor/device fixtures have provenance notices: typed fixtures and serialization tests are not empirical observations or compliance certification.

## Review findings resolved

1. Narrow form dropdown overflow at 200% text: expanded the form selector and exercised both locales at 360px.
2. Native SQLCipher secure-delete PRAGMA returns a row on Android: use `rawQuery`, not `execute`. Emulator regression caught this after unit tests passed.
3. Interrupted initial database creation can leave a file with no health tables: reset checks schema before deleting rows, and explicit reset can remove an unreadable database while normal opens stay non-destructive.
4. Reset failure could otherwise leave an old provider writable: pending reset hides the local dataset and blocks mutations; retry finishes before normal use.
5. Cached language/notification text: reload the preference in foreground/headless adapters, refresh pending requests, and keep IDs/due instants unchanged.
6. Export races with corrections/deletion/account switch: capture a health snapshot/fingerprint and disable sharing after invalidation.
7. New fixture tests had UTC-midnight windows for US local dates and compared timestamp serialization rather than instants: use named-zone day boundaries and instant equality. Added exact DST gap and skipped-date regressions.
8. Existing SDK processes generated incompatible native-hook caches in the shared workspace: validation uses an isolated source snapshot with one SDK. No IDE process/global SDK was stopped or modified.
9. A new local welcome initially obscured the existing signup route: kept a separate optional account welcome, restored login-to-signup navigation, and included it in the smoke regression. Removed the inactive OCR upload benefit and inaccurate medicine-account-backup wording.
10. Concurrent emulator/build/default-worker test runs exhausted host memory: reran sequentially with two test workers. The final serial suite passes. Native interrupted-reset tests now seed saved medicine/stock data and pending alarms before persisting the reset marker, then verify erasure, cancellation and key rotation.

## Validation

The complete final suite passes **276 tests** with coverage using `flutter test --no-pub --concurrency=2 --coverage --reporter expanded`; analysis reports no issues. Tests use synthetic data only. The prior recovery implementation also has an API 35 emulator five-event system matrix (timezone, forward/backward clock, package update and reboot) in `build/recovery-system-matrix-final.log`; that evidence is an emulator result, not an OEM phone claim.

| Check | Final result | Workspace evidence |
| --- | --- | --- |
| Format and whitespace | 98 Dart files, zero formatting changes; `git diff --check` clean | `build/epics-1-7/format.log` |
| Static analysis | No issues | `build/epics-1-7/analyze.log` |
| Full unit/widget/property/regression suite | 276 passed, coverage generated | `build/epics-1-7/tests.log`, `coverage.lcov.info` |
| Native English and Hindi flows | Both passed, plus framework teardown, 30 seconds | `build/epics-1-7/native-flow.log` |
| Native storage/export/reset assertions | SQLCipher reopen, exact stock/refill/Undo, preview invalidation, temporary-report cleanup, key rotation; interrupted reset with stored medicine/stock and pending alarms erases/cancels on reopen | Same native flow log and `integration_test/epics_completion_test.dart` |
| Normal app offline smoke | Fresh install enters guest without Supabase configuration or notification permission; restart returns to saved guest | `build/epics-1-7/normal-offline.log`; reproducible with `scripts/verify_android_guest.ps1` on the named disposable AVD |
| Report visual QA | All five pages of the final Hindi/Latin long-name/multiline-instruction PDF rendered with PyMuPDF and inspected; both native PDF previews inspected | `build/epics-1-7/pdf/`, `build/epics-1-7/ui/` |
| Normal Android debug build | Passed, main entry point `lib/main.dart`, all default ABIs, 25.2 seconds | `build/epics-1-7/app-build.log`; `medicine-reminder-debug.apk` and `SHA256SUMS.txt` in the same folder |
| Source comparison | No differences between workspace and validated Dart, asset, Android source and dependency files | `build/epics-1-7/source-hashes.json` |

The packaged APK is the normal debug app, not the integration-test entry point. Build artifacts are local/ignored; no commit, push, deployment or GitHub issue closure was performed. The isolated QA emulator was shut down after testing. The offline smoke restored its original airplane-mode state. No personal phone was used.

Environment: Windows; Flutter 3.47.7 / Dart 3.13.5 at `C:/tmp/medicine-flutter`; API 35 `MedicineReminder_QA`, emulator-5554. Validation source snapshot: `D:/tmp/medicine-epics-validation`, excluding SDK caches/build products and plugin symlink directories during incremental source refresh.

The installed dependency graph retains local notifications 21 and PDF 3.12/printing 5.14. The image codec is pinned to 4.8 because newer image 4.11 calls an archive API unavailable under PDF 3.12's archive constraint; PDF 3.13 requires an XML major incompatible with the current notification Windows adapter. Avoid an unrelated notification major-version migration in this feature change. KGP deprecation warnings from Workmanager remain a dependency follow-up; native build results determine current compatibility.

## Remaining release gates

Use the [participant/device kit](EPICS-1-7-RESEARCH-AND-DEVICE-KIT.md) for the actual interviews, usability rounds, TalkBack/contrast/motor review, current competitor capture, physical OEM matrix and reviewer sign-offs. The [privacy assessment](EPICS-1-7-PRIVACY-REVIEW.md) is an engineering inventory with official commencement references, not a legal opinion. iOS is uncompiled on this Windows host. Physical storage-full, backup/keychain and OS share-destination results remain pending. All seven epics must remain open until those acceptance criteria are satisfied.
