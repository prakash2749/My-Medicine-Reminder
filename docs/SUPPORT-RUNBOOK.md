# Support and incident response

Owner ticket: [MED-038 #48](https://github.com/prakash2749/My-Medicine-Reminder/issues/48). Prepared 18 October 2026. Status: ready for engineering/QA review; operations are not activated. Scope: Android local medicine reminders, History, Refills, export, guest use and optional account access.

## Activation and rotation

Before inviting beta users, the team must fill this roster, verify access privately and run the tabletop exercise below. Do not publish private phone numbers or credentials here. Use an agreed private support channel; public GitHub issues contain synthetic reproductions only.

| Responsibility | Named owner / backup | Required access and decision |
| --- | --- | --- |
| Support primary | Unassigned | Monitor agreed inbox, acknowledge, redact and record incidents |
| Support backup | Unassigned | Cover primary absence; accept explicit handoff |
| Platform/data responder | Unassigned | Reproduce reminder/storage failures, own compatible fixes |
| Privacy responder | Unassigned | Handle accidental sensitive evidence and suspected disclosure privately; obtain qualified advice when needed |
| Release decision-maker | Unassigned | Halt expansion, approve a tested forward fix and resume rollout |

Record coverage timezone, staffed days/hours, support address, private incident location and access-controlled retention/deletion process before activation. There is no staffed coverage or response-time promise until these are agreed. Review the rota weekly; primary/backup acknowledge each handover with open incidents, next action and next update time. If the primary cannot acknowledge, the backup assumes triage; if neither is available, pause beta expansion rather than advertise coverage.

The targets below are proposed internal targets **during staffed coverage**, not a 24-hour or clinical service promise. The first available responder handles an urgent report immediately; the roster determines who can approve release action. Explicitly set the next update time in the private record. The named responder keeps ownership until the next owner acknowledges.

| Severity | Trigger | Proposed first action / target | Escalation |
| --- | --- | --- | --- |
| S0 critical | Suspected private-data exposure, widespread data loss, or duplicate/obsolete alerts with potential for serious confusion | Stop release expansion and page available owners immediately; acknowledgement target 1 staffed hour | Platform, privacy and release owners; follow-up each staffed hour until contained |
| S1 high | Supported-device reminders fail, records cannot open, actions claim success without saving, reset/deletion cannot finish | Acknowledge within 4 staffed hours; preserve data and reproduce | Platform owner; daily staffed update and release-blocking decision |
| S2 normal | Isolated export, translation, layout or stock-display defect with saved records intact | Acknowledge within 2 staffed days; schedule fix and communicate scope | Feature owner; agree next update |
| Treatment question | Whether to take, skip, change or repeat a dose; symptoms or treatment interpretation | Explain that app support handles software only; direct treatment questions to the person's prescriber/pharmacist and urgent health concerns to appropriate local healthcare services | Do not infer treatment from app records; do not turn this into a dosing recommendation |

## First response and evidence

1. Determine whether this is a software failure or a treatment question. Do not ask for medication names, instructions, a prescription, dose History PDF or adherence percentages. A reminder, log or scheduling flag cannot establish whether a medicine was taken.
2. Ask for app version/build from Android App info (if unavailable, record unknown), phone manufacturer/model, Android version, interface language, broad problem category, and a minimal reproduction using made-up medicine details. Do not request device serials, account emails, exact dose times, screenshots of real plans, database files, encryption keys, auth tokens, `logcat` dumps or full bug reports. Ask whether notification permission, channel, precise-alarm access or battery settings changed, without asking what medication was involved.
3. If Settings opens: **Settings → Review diagnostics → inspect every field → Copy diagnostics**. The user chooses whether and where to paste it. Cancel leaves the clipboard unchanged. Explain that the clipboard and pasted copies are outside the app's control; the user can replace the clipboard afterward. Do not request a health export instead. If the app cannot open or copy fails, proceed with minimal reproduction/device/build details; do not send the user into reset to obtain diagnostics.
4. Store the minimum report in the agreed private support channel. Link a sanitized synthetic bug and a private incident identifier; never copy a support conversation into a public issue. Do not auto-attach screenshots or health exports. Use [the incident template](SUPPORT-INCIDENT-TEMPLATE.md).
5. If someone sends sensitive evidence accidentally, restrict access, do not forward or paste it into issues, and notify the privacy responder. Redact a minimal working copy, remove the original under the agreed retention process, record where copies may remain and communicate privately. Do not promise deletion from systems outside team control. Qualified privacy review determines any legal duties; this runbook does not make that determination.

Suggested request:

> Please share your app build, phone model, Android version and what failed using made-up details. If Settings opens, choose Review diagnostics, inspect the text, then copy it only if you want to share it here. Please leave out medicine names, prescriptions, account details and health reports. We can investigate software behavior; treatment or missed-dose questions belong with your prescriber or pharmacist.

There is no built-in support inbox or automatic diagnostic upload. Do not promise remote access, cloud restore or guaranteed alarm delivery.

## Diagnostic schema 1

`reminderDiagnosticBundle()` serializes only the allowlist below, never the full readiness object. JSON keys remain in English in both interfaces. The preview is a point-in-time snapshot; reopening it captures new readiness. A user can paste this text as a bundle; there is no file export or network request.

| Field | Meaning / limit |
| --- | --- |
| `schema: 1`, `scope: local-readiness`, `remoteTelemetry: false` | Contract and current local-only collection behavior |
| `schedulingSupported` | Adapter reports support; not certification of this phone |
| `notificationPermission`, `preciseAlarmPermission` | Last observed readiness flags; not a guarantee of delivery |
| `refillChannelEnabled` | Last observed refill-channel state; does not describe medicine-channel sound or Do Not Disturb |
| `futureSchedulePresent` | A scheduling horizon was reported; omits exact timestamp and counts |
| `reconciliationFailed` | A scheduling/recovery error was recorded; omits the raw error |
| `callbackObserved`, `posted`, `humanReceipt`: `not measured` | These delivery stages are unmeasured, not successful |

No owner/medicine IDs, plan/stock values, dates, exact times, raw errors, notes, credentials, network identifiers or health records are included. The bundle does not diagnose database integrity or prove that an alert was seen. Request a fresh review after a settings change; never silently substitute a new bundle after the user has reviewed the old one.

## Missing, late or obsolete reminders

1. Record affected build/OEM/OS, synthetic reproduction and whether this followed reboot, update, travel/time change, force-stop or permission change. Unknown scope stays unknown; one emulator pass is not physical-device evidence.
2. Ask the user to open the app, inspect Reminder health, retry readiness where offered, then check Android notification permission, the medicine channel/sound, precise alarms, Do Not Disturb and battery restrictions. Avoid blanket instructions to disable device security or every power restriction. Use the phone's actual settings; do not invent manufacturer menu names.
3. Offer the Settings test reminder. It is an immediate test request, not proof of future alarm delivery. Ask only whether the test appeared; do not ask for real notification screenshots. A disabled refill channel is a separate condition from medicine reminder delivery.
4. Explain existing limits: powered-off/force-stopped apps cannot reliably remind; key access may require unlocking after boot; saved schedules retain their own timezone; scheduling is bounded (up to 30 days, 450 Android alarms) and regular opens help extend it. Do not modify prescribed timing or suggest an extra dose to compensate for an alert failure.
5. For obsolete or duplicate alerts, reproduce edit/pause/archive/delete/snooze and stale notification actions with synthetic data. Escalate if alarms survive reconciliation or a stale action changes records. Do not advise clearing storage. If requested by the user, stopping a problematic plan's reminders through pause/archive is distinct from any treatment decision; it does not change their prescription.
6. Route reliability cases to [#42](https://github.com/prakash2749/My-Medicine-Reminder/issues/42) with the [device kit](EPICS-1-7-RESEARCH-AND-DEVICE-KIT.md). Repeat failed scenarios on the affected OEM after fixing. Do not assert that the supported flag or scheduled-through horizon measures human receipt.

## Missing records, write failures and deletion incidents

1. Preserve the installation and device key. **Do not suggest uninstall/reinstall, Android Clear storage, erase/reset, a forced downgrade, or a new key as routine repair.** There is no cloud medicine backup/key recovery. Signing in does not back up or merge guest records; signing out or switching profile can change the visible dataset.
2. Ask whether the user intentionally switched guest/account profiles, uninstalled, cleared storage or reset, without requesting account identifiers. If appropriate, let the user return to the original profile. Do not merge profiles or claim missing records are recovered before observing them.
3. If storage is full, suggest freeing unrelated device space without deleting this app's data, then using Retry. An unreadable or unsupported payload must remain intact and surface failure; never overwrite it with an empty dataset to make the error disappear. Escalate failed writes/opens with build and synthetic reproduction, not a production database attachment.
4. A pending erase marker means an intentional reset was interrupted. The app retries that request before exposing health data; do not bypass the marker, export hidden data or create a replacement key. Let the user retry the requested erase. A failure is still a failure, even when some cleanup has finished. Escalate if it cannot finish or alarms remain.
5. Permanent individual deletion removes that medicine's associated records and app-owned reports; archive preserves history. Explain the distinction before a user initiates either action. Neither support nor this task silently performs a deletion. Saved/shared copies cannot be recalled. PDF export is a human-readable report, not a supported restorable backup.
6. Record what is known and what remains inaccessible. Missing-key data has no implemented recovery path; do not promise decryption or fabricate reconstructed doses. Reproduce migration/corruption/interruption cases with synthetic fixtures under [#43](https://github.com/prakash2749/My-Medicine-Reminder/issues/43).

## Release containment and compatible recovery

Current source baseline: Android application ID `com.example.medicine_reminder`; SQLCipher database `medicines-v1.db`, SQL schema 1, secure key identifier `medicine.database.key.v1`; JSON writer 3/readers 1–3; reset marker `medicine.reset.pending.v1`. Reconfirm these in source and the actual candidate at every release. The database filename's v1 does not imply the JSON payload is v1. The current Gradle release configuration uses the debug signing key and is **not a production release setup**; configure and verify production signing under #50 before shipping.

1. Release owner records affected track/build, last known compatible build, source revision, signing lineage, artifact hash, rollout state and known impact. Pause expansion/recruitment when appropriate. Halting a staged rollout stops further distribution; already updated users retain that build. Prepare their recovery path rather than promising a remote downgrade. See [Play staged rollout behavior](https://support.google.com/googleplay/android-developer/answer/6346149?hl=en).
2. Prefer a forward fix with a higher version code and the established application identity/signing lineage. Android uses version codes to prevent lower-version installation, and updates must satisfy signing compatibility. Do not use a different app ID/key, uninstall, Clear storage or force-downgrade flags as a user rollback procedure. See [Android versioning](https://developer.android.com/studio/publish/versioning) and [app signing](https://developer.android.com/studio/publish/app-signing).
3. Reverting feature source is acceptable only if the resulting **new candidate** still reads/writes every deployed payload safely, preserves fields and meaning, and retains migration, key, reset, recovery receiver and alarm identity behavior. Reverting to a pre-stock/pre-recovery writer could discard newer fields even if it opens schema 1. No downgrade compatibility has been established. Block release if compatibility is unknown; never use automatic deletion as a migration fallback.
4. Before rollout, QA installs the previous deployed build on a disposable device, seeds synthetic plans, actions/Undo, snoozes, revisions, stock/refills, two isolated profiles and an app-owned temporary report, and captures a private test-only baseline of stable IDs, event/stock values and pending alarms. Update **in place**, preserving identity/signing; reopen both profiles and compare values/IDs, historical snapshots, current/future alarms and snooze deadline. Check that report startup cleanup removes only temporary copies. Re-run update while the app is closed to check headless recovery before foreground repair. Duplicate alarms or records are release blockers.
5. Repeat failed writes, unsupported payloads, missing-key existing DB, interrupted reset/deletion, locked/unlocked boot, denied/regranted permission, time/zone changes and offline restart using synthetic fixtures. A candidate must not report success after failed persistence or regenerate deleted data. Use the [existing review evidence](EPICS-1-7-REVIEW.md), recovery scripts and native suites as baselines, with physical OEM results under #42/#43. Existing same-APK update/emulator tests do not establish previous-production-to-candidate migration compatibility.
6. Independent reviewer and release owner record pass/fail evidence and residual risk before resuming a limited rollout. Verify affected users have an offered compatible update and support guidance. Do not claim a signed release, rollback drill or physical upgrade has happened merely because this runbook exists.

## Incident record, handover and closure

Use [SUPPORT-INCIDENT-TEMPLATE.md](SUPPORT-INCIDENT-TEMPLATE.md) in the agreed private system. Assign one incident owner and explicit next action/update time. Keep public bugs synthetic. Record containment separately from recovery; halted distribution is not recovery for already affected installs.

Close only after scope and cause are understood or uncertainty is explicitly accepted, the fix is independently reviewed, synthetic regression and affected-device retest pass, the compatible update path is verified, user communication is complete, and privacy follow-up is assigned. Record residual OEM/OS limitations honestly. For S0/S1, review the timeline and prevention actions within five staffed days of recovery, assigning a person and due date to each action. Remove unneeded private evidence according to the agreed process; retain only minimal sanitized decisions.

## Pre-beta tabletop and readiness checklist

- Fill primary/backup/escalation contacts, support channel, coverage hours and evidence retention/access decisions. Test the handoff privately; this document does not send messages or enroll responders.
- On a synthetic test install, review/cancel/copy diagnostics in English and Hindi. Confirm copied text matches preview; simulate clipboard failure. Confirm no health fields or automatic sending, and verify TalkBack/large text on physical phones.
- Walk through: notification revoked after update; obsolete snooze after edit; full-storage write failure; missing-key database; interrupted reset; accidental prescription attachment; treatment question. For each, name the owner, severity, safe next step and next update time. Never use real records for the exercise.
- Complete the previous-build-to-candidate in-place update exercise on each required OEM, plus device timing and recovery scenarios. Attach actual outcomes under #42/#43, not blank templates or fixture descriptions.
- Teammate reviews this runbook and the diagnostic UX; release owner approves the operational roster. #48 remains open until that evidence is accepted. #44 owns approved public privacy/support pages; #46 owns beta operations; #50 owns signed staged release.
