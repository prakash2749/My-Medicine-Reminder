# Epics 1–7 delivery and remaining evidence

Scope: [Discovery](https://github.com/prakash2749/My-Medicine-Reminder/issues/1), [Platform](https://github.com/prakash2749/My-Medicine-Reminder/issues/2), [Domain](https://github.com/prakash2749/My-Medicine-Reminder/issues/3), [Experience](https://github.com/prakash2749/My-Medicine-Reminder/issues/4), [Reminders](https://github.com/prakash2749/My-Medicine-Reminder/issues/5), [Privacy](https://github.com/prakash2749/My-Medicine-Reminder/issues/6), [Quality](https://github.com/prakash2749/My-Medicine-Reminder/issues/7). Launch/Growth/Future expansion are excluded. Updated 18 October 2026.

The user will arrange participants and physical phones. “Implemented” below describes repository code/automated evidence, not completed external studies or release approval. No GitHub issues have been closed by this work. Child issues also request teammate review; this session provides self-review, not independent sign-off.

| Epic | Child task | Engineering result | Outstanding evidence |
| --- | --- | --- | --- |
| 1 Discovery | MED-001 #11 | Recruitment, consent, interview and analysis protocol prepared | 8 adult self-managers + 4 helpers; actual anonymous notes/counts and segment decision |
| 1 | MED-002 #12 | Original local workflow implemented; repeatable competitor/review capture protocol | Current installed-app audit, raw 30+ review sample; prior fixture claims are unverified |
| 1 | MED-003 #13 | Intended-use proposal, exclusions, data map and review questions recorded | Confirm market/capacity and named clinical/privacy reviewers; approval |
| 1 | MED-004 #14 | Working interactive guest/medicine/dose flows; task protocol prepared | At least 5 uncoached participant sessions and dangerous-error retests |
| 2 Platform | MED-005 #16 | Native reminder adapter/recovery and emulator evidence | Actual target-device feasibility; no physical/iOS claims from fixture models |
| 2 | MED-006 #15 | Existing Flutter/CI decision remains; issue already closed | Preserve team CI/release review |
| 2 | MED-008 #18 | Encrypted persistence, payload versions 1–3, account isolation, non-destructive failure and reset marker | Hardware backup/key-loss review and teammate evidence sign-off |
| 3 Domain | MED-007 #17 | Schedule/event semantics, original snapshots, fixed-point stock; explicit DST gap/fold/date-skip behavior | Named wording/semantics reviewer |
| 3 | MED-012 #22 | Daily/weekday/date-bounded recurrence | Teammate review |
| 3 | MED-017 #27 | Idempotent actions, Undo, correction trail and stock reversals | Teammate review |
| 3 | MED-019 #29 | Revisioned edit/pause/resume/archive preserving prior records | Teammate review |
| 3 | MED-022 #32 | Exact stock ledger, threshold and acknowledged low-stock episodes | Physical device alert checks |
| 4 Experience | MED-009 #19 | Shared navigation, labels and responsive core UI | TalkBack/contrast/motor interaction on actual phones |
| 4 | MED-010 #20 | Persistent unlimited guest profile, truthful local-storage welcome, no account requirement | Participant first-setup and permission-denial usability review |
| 4 | MED-011 #21 | Validated medicine creation, separate strength/quantity/unit | Clinical wording review |
| 4 | MED-013 #23 | Editor and seven-day future preview | Participant interpretation review |
| 4 | MED-016 #26 | Today, simultaneous next-dose summary, details and corrections | Participant review |
| 4 | MED-021 #31 | Readiness/retry/settings, generic lock-screen content, native test and offline help | OEM-specific guidance and observed physical test notification |
| 4 | MED-023 #33 | Active/archived medicines and full stock interface | Participant review |
| 4 | MED-024 #34 | Filterable History, eligible denominator, coverage gaps, original records | Participant denominator interpretation |
| 4 | MED-025 #35 | Offline multilingual local PDF preview, explicit OS sharing, bounds/invalidation/cache cleanup | Long-range/hardware share destination review |
| 4 | MED-027 #37 | Device/English/Hindi preference, UI/validation/notification copy, numeric entry normalization; prescription text preserved | Fluent reviewer in actual UI/actions/report |
| 5 Reminders | MED-014 #24 | Native local bounded scheduling and alarm reconciliation | Physical delivery matrix |
| 5 | MED-015 #25 | Permission/channel/exact-alarm readiness and settings recovery | OEM permission/revocation matrix |
| 5 | MED-018 #28 | Owner-validated actions, persisted 15-minute snooze and deep links | Physical lock-screen/action matrix |
| 5 | MED-020 #30 | Headless reboot/update/clock/zone recovery with persisted context | Existing emulator five-event matrix; repeat on physical OEM phones |
| 6 Privacy | MED-026 #36 | All-profile local reset, native cancellation, key/database/cache removal and interrupted-reset marker | Physical interruption/backup review |
| 6 | MED-028 #38 | Actual field/SDK/backup/export map, threat review and current official India commencement references | Qualified legal review and named mitigation owners |
| 6 | MED-029 #39 | Local allowlisted readiness diagnostics; raw sensitive logs removed; no remote telemetry SDK/transmission | Human payload review; no consent-withdrawal transmission path exists because optional telemetry is absent |
| 6 | MED-061 #71 | Individual-ID deletion removes revisions, records, inventory and alarms; clears owned reports; external copies explained | Teammate/hardware review |
| 7 Quality | MED-030 #40 | English/Hindi narrow-screen 200% layout regressions and overflow fix | Second round with at least 5 representative users including older adults; TalkBack/contrast |
| 7 | MED-031 #41 | DST/date/decimal/edit/action/stock/recovery regressions, plus gap/fold/date-skip regression fixes | Teammate review of fixtures and results |
| 7 | MED-032 #42 | Predeclared timing targets, OEM scenarios and result template | Actual Samsung, Xiaomi/Redmi, Pixel/Motorola runs |
| 7 | MED-033 #43 | Native synthetic-data flows, persistence/recovery and failure regression suite | Physical storage-full/upgrade/airplane-mode matrix and independent review |

## Deliverables

- [System design](EPICS-1-7-DESIGN.md)
- [Privacy/security review and legal questions](EPICS-1-7-PRIVACY-REVIEW.md)
- [Participant and physical-device kit](EPICS-1-7-RESEARCH-AND-DEVICE-KIT.md)
- [Implementation self-review and exact validation evidence](EPICS-1-7-REVIEW.md)

The seven epics should remain open until their outstanding acceptance evidence has been supplied and reviewed. The protocols are ready for the people/phones the user will arrange.
