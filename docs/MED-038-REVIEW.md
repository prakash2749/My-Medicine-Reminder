# MED-038 implementation review

Ticket: [#48](https://github.com/prakash2749/My-Medicine-Reminder/issues/48). Reviewed 18 October 2026. Engineering self-review; independent acceptance and staffed support activation remain pending.

## Delivered behavior

[Design](MED-038-DESIGN.md) was recorded before coding. [The support runbook](SUPPORT-RUNBOOK.md) defines support primary/backup and escalation roles, proposed staffed-hour severity targets, redacted evidence collection, reminder-failure triage, record-preserving data-loss response, compatible forward-fix release steps and a pre-beta tabletop. [The private incident template](SUPPORT-INCIDENT-TEMPLATE.md) supplies ownership, handover, containment, compatibility, QA and closure fields without requesting health records. README links both handoff artifacts.

Settings now offers Review diagnostics in English and Hindi. It captures the existing allowlisted schema-1 readiness JSON, shows the exact selectable text with clipboard disclosure, and copies only after the user chooses Copy diagnostics. Cancel/back/outside dismissal leaves the clipboard untouched. Reconciliation updates while the dialog is open cannot silently replace the reviewed snapshot. Reopen to capture fresh readiness. Copy failures show a localized retry message without raw platform details. Duplicate review actions are guarded and mounted checks protect asynchronous completion.

## Review findings and disposition

| Concern | Result |
| --- | --- |
| Prescription/account/error leakage | Bundle serialization calls the existing strict allowlist, not the sensitive readiness `toJson()`. Exact-key regression uses hostile error text, owner/dose ID and precise date inputs. No free-text, PDF, raw log or automatic transmission enters this flow. |
| Snapshot consent | A single immutable string feeds preview and clipboard. Widget regression changes readiness behind the dialog and proves the old reviewed snapshot is copied; reopening shows fresh state. |
| Cancel/failure behavior | Open, cancel, system back and outside dismissal produce zero clipboard writes. Simulated platform failure does not show success or private exception details; explicit retry succeeds. |
| Dialog waiting state | Initial implementation reused the background indeterminate busy indicator during review, leaving an unnecessary animation running. Replaced with a separate review guard before final validation. |
| Language/layout | Both languages pass the review/copy flow at 360 × 800 logical pixels with 200% text. JSON stays left-to-right and scrollable. Fluent Hindi, physical clipboard and TalkBack checks remain pending. |
| Data preservation | No persistence/key/schema/alarm changes in this task. Runbook inspected against SQLCipher schema 1, payload writer 3/readers 1–3, missing-key refusal and pending reset handling. It forbids routine destructive repair and requires synthetic in-place upgrade/ID/ledger/snooze/alarm comparisons. |
| Release response | Current official Android/Play versioning, signing and staged-rollout references are linked next to the corresponding runbook steps. Halting distribution is distinguished from recovery of already updated installs. Current debug release-signing configuration is explicitly flagged for #50. |
| Operational honesty | Roster, support address, coverage hours and private retention/access decisions are unassigned gates. Proposed targets are not a promised staffed service. #42/#43 physical validation and independent review are still required. |

## Validation evidence

Validated with Flutter 3.47.7 / Dart 3.13.5 at `C:/tmp/medicine-flutter`, using the isolated `D:/tmp/medicine-epics-validation` snapshot and process-local D: temporary directories. All 139 selected workspace Dart/test/asset/Android-source/dependency hashes match the snapshot. Evidence is local under `build/med-038/`; the older `build/epics-1-7/` artifacts retain their original scope.

| Check | Result | Evidence |
| --- | --- | --- |
| Format | 99 Dart files, zero changes | `format.log` |
| Static analysis | No issues, 10.5 seconds | `analyze.log` |
| Full unit/widget/regression suite | 282 passed, 24 seconds; includes six new support tests and existing migration/recovery regressions | `tests.log`, `test/views/medicine_support_test.dart` |
| Normal Android debug APK | Passed, 75.3 seconds; main entry point, default ABIs | `app-build.log`, `medicine-reminder-debug.apk`, `SHA256SUMS.txt` |
| Workspace/snapshot comparison | 139 source/dependency hashes match | `source-hashes.json` |
| Local document links and whitespace | Handoff links resolve; tracked diff whitespace check passes | Local validation |

The new support tests cover strict privacy fields, cancellation paths, stale-preview consistency, clipboard failure/retry, and English/Hindi large-text flows. They mock the platform clipboard; they do not prove OEM clipboard behavior, real-user comprehension or clinical review. No emulator/physical-phone test, previous-production signed upgrade exercise, privacy incident, live support enrollment, message sending or deployment was performed by this task. The release runbook is a procedure awaiting a real drill, not evidence of a completed rollback.

The APK SHA256 is `5DFF61949C92B5547CFEFBB15672C28DA17A892327C8E7BD64A0FFFEA5E44A5A`. This is a debug QA artifact, not a signed production release. Existing Kotlin-plugin and Java source/target deprecation warnings remain dependency follow-ups; the build completed successfully.

## QA and completion gates

1. Teammate reviews the runbook and data-preservation/clinical-routing wording, then exercises the copy UI on physical Android with TalkBack and both languages.
2. Team assigns primary/backup/escalation owners, actual coverage, private channel and evidence retention/access policy; complete and record the synthetic tabletop.
3. Finish #42/#43 device/upgrade evidence and carry the tested compatibility checks into #50 release approval. Public support/privacy pages remain #44.

Move #48 to Review / Testing for this handoff and keep it open until acceptance evidence is reviewed. Source changes and QA artifacts remain local; no commit or push is part of this task.
