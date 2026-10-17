# Epics 1–7 completion design

## Scope and evidence

Source: repository issues #1–#7 and their 34 child tasks, inspected 18 October 2026. Launch, Growth, and Future expansion (#8–#10) are excluded. Existing login, encrypted storage, dose actions, revisioned schedules, native recovery, History and Refills remain the foundation.

The user will arrange participants and physical phones. Interviews, usability observations, OEM reliability results, fluent Hindi review, clinical wording approval, and legal review must remain pending until actual evidence exists. A model fixture or an emulator is not a physical-device experiment. Existing MED-005 documents contain assertions beyond the available run logs; this audit does not adopt those claims.

## Remaining implementation

1. Unlimited offline guest use with an explicit local-only explanation; persist the choice, keep guest and authenticated records separate, and return guests directly to Today. Never silently migrate guest health data on sign-in.
2. Device/English/Hindi language preference with a persistent override. Translate application-owned UI, validation, and future notification actions; preserve medicine names, instructions, units stored on plans, occurrence IDs, and timing. Hindi digits normalize before numeric parsing. Language changes refresh pending notification text.
3. A local PDF preview for the selected History date range and medicine filter. Include original plan/revision, dose quantities/units, schedule zone, due/recording times, unconfirmed status, generation time, and coverage gaps. Use Flutter text shaping to render multilingual report pages offline, then embed the pages in a PDF. Reports are image-based rather than searchable. Bound exports explicitly; never silently omit rows. No automatic upload or sharing.
4. Erase all local medicine data across local profiles using a durable reset marker. Clear native reminders, encrypted database/snapshots and encryption key; on interruption retry the marker before opening health data. Retain authentication and non-health language preferences. Invalidate previews after any health-data change. Clear app-owned export cache on startup, reset, and deletion; externally shared copies cannot be recalled.
5. Settings with local-only redacted diagnostics, reminder test, lock-screen privacy and offline help. No remote analytics/crash SDK. Diagnostics distinguish scheduling/readiness from delivery/receipt; do not include identities, medicine names, occurrence IDs, exact schedules, or health text.

## State and concurrency

Guest identity is a reserved local owner key, never a fake authenticated Supabase user. The existing provider/store mutation queue remains authoritative. A durable preference loads before root navigation. Reset increments the provider generation, serializes with writes/reconciliation, and leaves a pending marker on any incomplete cleanup. Reopening a marked store completes deletion before returning records. Native cancellation is retried by empty-data reconciliation. Previously queued notification intents cannot recreate missing occurrences.

PDF preview captures an immutable health snapshot and its fingerprint. Share rechecks the fingerprint immediately before invoking the OS; changed/deleted data requires regeneration. Report generation errors remain visible and never report a successful save/share. OS-owned share caches have a documented retention policy and cleanup hook where supported.

## Interface direction

Keep the existing teal, text-led utility interface. Add Settings to the app bar and Export to History. Use scrollable sheets/dialogs, wrapping actions, descriptive labels and at least Material touch targets. Avoid fixed-height text containers in new flows. Test both languages at 200% text scaling on a narrow screen.

## Verification

Run formatting, static analysis and the complete suite. Add behavioral tests for offline guest restart/isolation, persistent locale and digit parsing, translated native actions without timing changes, reset failure/retry/isolation, redaction, export filtering/invalidation and multilingual multipage rendering. Render synthetic PDF pages and inspect layout. Build the normal Android app and extend emulator end-to-end coverage. Record physical-device and human-review gates separately, with executable protocols and blank result templates.
