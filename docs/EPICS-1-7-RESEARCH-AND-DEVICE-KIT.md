# Epics 1–7: human studies and physical-device kit

Prepared 18 October 2026. **No participant sessions or physical-device results are claimed here.** The user will arrange people and phones. Use synthetic medicine plans for all tasks. Do not collect prescriptions, identifiers, audio, or screenshots without specific permission. Participants can stop at any time. Recruit independently of treatment decisions.

## Discovery: MED-001

Recruit eight adults who manage recurring fixed daily/weekday medicines themselves and four family helpers, keeping their roles separate. Include English/Hindi speakers, different phone experience, and older adults. Exclude emergencies and anyone seeking dosing advice. Assign anonymous IDs A01–A08 and H01–H04. Keep scheduling/contact details outside the research notes and delete them when sessions finish.

Suggested introduction: “We are studying reminders, not your treatment. You do not need to name any medicine or condition. Participation is optional; you can skip any question. May we take anonymous written notes?” Record consent as yes/no; no recording by default.

Ask about the last actual reminder problem: what happened, where they were, what the phone did, how they noticed, what workaround they used, and the consequence in their own words without clinical details. Ask what currently works, phone manufacturer/API, language and accessibility needs, offline use, stock tracking and whether switching apps would help. Helpers: distinguish their own reminders from remote monitoring; do not imply caregiver alerts exist.

Use one row per participant: `ID | role | consent | phone/API | language | recurring problem codes | workaround | switch reason | anonymous example | researcher | date`.

After all sessions, count each problem once per participant, separately for self-managers and helpers. Rank the three most frequent with exact sample denominators and anonymous examples. Do not generalize prevalence. Initial segment hypothesis: adults in India managing their own fixed daily/weekday plans on Android. Stop/change if at least six of eight self-managers report no meaningful unmet problem and their current solution works, or if dangerous confusion persists after two iterations. This threshold is a predeclared product decision, not a statistical claim. Select/approve the segment only after results.

## Prototype and usability: MED-004 and MED-030

Use the working app as the original interactive prototype. First round: at least five target users; second round: at least five representative users including older adults. Record whether any participant repeats across rounds. Do not coach tasks. Only explain that all medicines are fictional.

1. Begin offline as a guest, select preferred language, and add “Demo medicine”, strength “100 mg”, amount “0.5 tablet”, two chosen times, weekdays and an end date.
2. Explain the next dose in their own words. Record Taken on one specific occurrence.
3. Snooze a different occurrence and explain whether that records consumption.
4. Undo a mistaken confirmation; explain whether the app is telling them to take another dose.
5. Find History, an unconfirmed entry, and the denominator. Export/preview and cancel the share sheet.
6. Set stock, add a refill, reconcile a physical count; distinguish a stock correction from a dose correction.
7. Disable notifications using OS Settings, find the problem, and restore permission. Test cancellation of the reset confirmation, then perform reset on the synthetic profile.

Per task: `participant ID | round | app commit/build | device | language | font size | started | ended | completion unaided/assisted/failed | wrong occurrence/action | interpretation | error severity | issue owner | fix/build | retest`.

Stop a task on a dangerous misunderstanding; do not reinforce it. Any wrong-dose confirmation, Snooze interpreted as Taken, or Undo interpreted as an extra-dose instruction is release-blocking. Fix/retest or disable the affected flow. Review TalkBack reading order and labels, 200% text, 48dp targets, contrast and motor access on each main flow. Automated layout tests support this work; they do not substitute for TalkBack or user observations.

## Competitive audit: MED-002

Existing competitor model fixtures are **unverified secondary material** unless raw captures/links can be supplied. They do not establish observed app behavior. Install current India-region Medisafe and MyTherapy on a test phone; record exact app version, date, Android/API, region and whether an account/subscription is required. Capture onboarding, add/edit, confirmation, snooze, history, export, permission recovery and paywalls with synthetic data. Distinguish observed behavior from store descriptions and participant complaints.

For the requested 30+ reviews, predeclare a reproducible sample (e.g. newest 15 English/Hindi India-region reviews for each app on the capture date). Preserve review permalink/store identifier, date, language, sampling rank and a brief paraphrase/category. Do not invent review quotes or count fixtures as captured reviews. Review complaints are hypotheses until independently reproduced. Record gaps and an original workflow proposal separately from competitor defects.

## Device feasibility and reliability: MED-005 and MED-032

Use an actual Samsung, Xiaomi/Redmi, and Pixel/Motorola-class phone. Cover the oldest supported API and current target APIs across the set. Record physical model, Android/API, OEM OS, build SHA/APK hash, battery mode, notification/channel/exact permissions, DND state, network state, timezone, screen lock/unlock state and test operator. Do not change a participant's personal clock; use dedicated test phones.

Predeclare supported-state target: each one-minute-spaced synthetic reminder appears once within 60 seconds of its scheduled time when precise-alarm permission is available, notifications/channel/sound enabled, device powered on/unlocked once after boot, and the package is not force-stopped. Approximate mode has no 60-second promise; record actual delay. Test at least 20 occurrences per supported scenario per phone, including five simultaneous medicines; report sample size, median/max delay, missing and duplicate count. Zero unexplained missing/duplicate occurrences in this sample is required; it is not a universal reliability guarantee. A callback/post timestamp is not human receipt.

Cases: foreground; screen off; normal process death without force-stop; Doze; reboot then first unlock; airplane mode; low battery/battery saver; muted medicine channel; denied notification permission; denied/revoked precise-alarm permission; manual forward/backward clock change; timezone travel; package update; simultaneous alerts; edit/pause/archive/delete during snooze; low-stock episode/refill; account switch; reset. Separately document powered off, force-stop, before-first-unlock storage, and OEM restrictions as unsupported/degraded states. Verify the app explains recovery and does not silently label records as Taken.

Use `adb shell dumpsys alarm`, `dumpsys notification`, and logcat only for synthetic accounts. `scripts/verify_android_recovery.ps1` is specifically an emulator system-event check; it is not OEM evidence. Never use `pm clear` or clock mutation against a personal device. Re-enable original permissions, timezone, automatic time and battery settings after tests.

Result row: `case/run | device/API/OEM | permissions | battery/DND/network | due time/zone | callback observed time or unknown | posted time or unknown | visible alert time | human observation | delay | count | evidence path | result | issue/owner | retest`. Keep raw logs and SHA256 checksums; redact health/account data before sharing. Record failed results, do not replace them with a fixture.

## Wording and privacy decisions: MED-003, MED-027 and MED-028

Product owner to confirm: India; adults 18+; Android first; English/Hindi; self-managed fixed daily/weekday regimens; team capacity. Explicit exclusions: diagnosis, dose calculations, interactions, emergency monitoring, automatic prescription interpretation, caregiver monitoring, cloud medicine backup/sync. Existing sign-in is optional and does not upload/migrate local medicine records.

Assign named clinical wording, fluent Hindi, privacy/regulatory and QA reviewers. Names and sign-offs remain unfilled until supplied; proposed role labels are not assignments. Hindi reviewers must check “ले ली”, “छोड़ें”, “15 मिनट बाद याद दिलाएँ”, Undo, reset and permissions in the actual rendered UI/notifications/report. Preserve all entered prescriptions verbatim. Privacy reviewer must use the current India commencement sources in EPICS-1-7-PRIVACY-REVIEW.md and document applicability, legal entity/contact, user rights and any medical-software classification decision. No compliance certification is implied.

## Evidence sign-off

`task | evidence IDs and date | reviewer name/role | pass/fail | unresolved issue | accountable owner | next action`.

All study/device/legal/translation result rows currently remain **pending**. Never close the relevant GitHub acceptance criteria solely because the protocol or automated fixtures exist.
