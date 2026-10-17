# MED-038 support and incident response design

Issue: [#48](https://github.com/prakash2749/My-Medicine-Reminder/issues/48). Designed 18 October 2026, before implementation. This prepares launch operations; it does not activate a staffed support service.

## Problem and scope

Support needs reproducible app-failure evidence without requesting medicine reports, prescriptions, credentials, or device dumps. Settings currently exposes allowlisted readiness JSON, but has no explicit review-and-copy handoff. Release response also needs to protect the only local copy of medicine records and reminders.

Deliver a support runbook, a reusable incident record, and an English/Hindi Settings action to review and copy the existing readiness snapshot. No new backend, telemetry, support address, automatic message, package dependency, database migration, or account requirement is introduced. Team contacts, coverage hours and OEM evidence must be supplied before operating a beta.

## Diagnostic handoff

1. User opens Settings and chooses Review diagnostics.
2. Capture one immutable allowlisted readiness JSON string. Display the exact string to be copied, with an explanation of omitted health/account data and clipboard visibility. No free-text input is merged into it.
3. Cancel, back or outside dismissal leaves the clipboard untouched. Only Copy diagnostics writes the reviewed snapshot. The user pastes it into their chosen support conversation; no transmission occurs in the app.
4. Confirm a successful platform clipboard write. On failure show a localized retry message without raw exception text. Guard duplicate actions and dispose/unmount boundaries.

Keep schema 1 and the existing field contract in `medicine_diagnostics.dart`. The payload is readiness information only: permission/channel flags, presence of a scheduling horizon, reconciliation failure flag and explicitly unmeasured delivery stages. It does not prove notification delivery, dose consumption or database health. Do not serialize `ReminderReadiness.toJson()`, which includes dates, IDs and raw errors.

Use selectable, left-to-right JSON, a scrollable dialog and wrapping actions at large text sizes. Translate application copy, retaining stable machine-readable JSON keys. Fluent Hindi and physical TalkBack/clipboard review remain human QA gates.

## Operational design

Define primary support, backup, platform/data responder, privacy responder and release decision-maker as roles with a fill-in roster. Separate app malfunction from treatment questions; support cannot interpret prescriptions or recommend dose changes. Define proposed severity/coverage targets without advertising an unstaffed service. Use synthetic reproductions, a user-reviewed diagnostic bundle and minimal device/build details, with private handling of accidental sensitive attachments.

For missing records, preserve installation and encryption key; never suggest uninstall, clear storage or reset as routine troubleshooting. Account sign-in is not backup. For incidents, halt expansion, assess exposure, reproduce with synthetic records and issue a compatible forward fix. An older source tree is not a safe database rollback: SQL schema is currently 1 while payload writers emit 3 and readers accept 1–3. No production downgrade is approved by this task.

The runbook records the exact schema, signing, notification identity, snooze and scheduling checks required before releasing an update. Physical upgrade and OEM reliability work stays tracked under #42/#43, with actual signed rollout under #50.

## Review and validation plan

- Verify all diagnostic keys and hostile raw error/ID/date inputs remain outside the copied bundle.
- Widget tests: no copy on open/cancel/back; copied text matches the preview even if readiness changes; platform copy failure does not claim success; retry works; English/Hindi flow at narrow width and 200% text.
- Run formatter, static analysis and unit/widget suite with the validated Flutter SDK; inspect release instructions against the actual persistence/recovery implementation and current primary Android/Play documentation.
- Record exact checks and pending operational/device approvals in MED-038-REVIEW.md. Keep #48 open for teammate review and operational sign-off.
