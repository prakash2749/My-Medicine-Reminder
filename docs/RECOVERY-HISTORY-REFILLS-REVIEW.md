# Recovery, history, and refill review

Implementation/self-review: 18 October 2026. Scope: MED-020, MED-022, MED-023,
and MED-024. No issues were closed; independent teammate and release-device
review remain separate requirements.

## Delivered behavior

- Android system events queue recovery through the existing Dart WorkManager
  dispatcher. Encrypted authoritative plans replace cached boot replay. Recovery
  regenerates only eligible future alarms, preserving confirmations and stock.
- Startup/resume/manual retry detect timezone, boot, monotonic-clock drift, and
  recovery generation changes. Travel notices preserve anchored plan timezones.
  Today exposes last check time, permission recovery, and delivery limits.
- History has period/medicine/state filtering, daily recording progress,
  original dose details/corrections, and documented recording coverage gaps.
  Summaries exclude future, paused, and canceled unconfirmed occurrences.
- Refills has stock setup, purchases, physical-count reconciliation, thresholds,
  estimated supply, stop/restart tracking, archived stock access, and a ledger.
  Taken and Undo apply exact decimal consumption/reversal once. Negative stock
  remains visible; units and stale counted balances are checked.
- Payload version 3 migrates versions 1/2 without replacing data or encryption
  keys. Native scheduling and refill-notice acknowledgement share the store lock;
  all feature mutations retain added collections and account isolation.

## Review findings resolved

- The History progress bar's custom spoken value used text where this Flutter
  SDK requires a numeric semantics value. Corrected and verified with widgets.
- Dose and refill channel blocking initially shared a gate. They now use
  separate channel checks; blocked refill notices remain eligible for retry.
- Physical-count edits now reject both a changed stock balance and a changed
  stock revision, preventing a stale count from hiding newly logged consumption.
- Archive guards also apply to stock threshold mutations. Original consumption
  quantities remain unchanged by later dose edits or medicine renaming.
- Native receiver work uses `goAsync` and waits for enqueue persistence off the
  UI thread. Cold-event verification waits for process termination before
  changing device state and avoids racing headless startup with a paused driver.

## Evidence

- Static analysis: no issues. Full unit/widget/adapter suite: **143 passed**
  (46 added tests). Logs: `build/recovery-history-refills-final-analyze.log` and
  `build/recovery-history-refills-final-tests.log`.
- Android API 35 native flow passed: actual SQLCipher reopen, real low-stock
  notification, stock consumption, recovery worker, schedule replacement,
  pause/resume, archive, and original records. Initial native flow output:
  `00:14 +2: All tests passed!`; `build/recovery-history-refills-native-flow.log`.
  The final populated-screen run also passed (`00:29 +2`), recorded in
  `build/recovery-history-refills-native-final.log`.
- Closed-process system matrix passed **timezone, forward clock adjustment,
  backward clock adjustment, package replacement, and reboot**. Each verification
  checks native alarms before binding a foreground provider, plus three retained
  dose actions, unchanged 9.5-tablet stock, completed-dose exclusion, unique
  alarm IDs, and no paused/archived alarms. Log:
  `build/recovery-system-matrix-final.log`; per-event logs:
  `build/recovery-system-{timezone,clock-forward,clock-backward,package-update,reboot}.log`.
- Native screenshots are saved under `build/medicine-native-screenshots/` and
  visually inspected: populated History (one Taken/two eligible), Refills with
  archived low stock and paused unknown stock, and the stock ledger.
  Narrow-screen/enlarged-text checks cover both app themes.

The matrix uses only the isolated `MedicineReminder_QA` emulator and synthetic
accounts. The fixture APK/normal test APK contain test entrypoints; build
`lib/main.dart` for a normal app. The runner's first attempts exposed test setup
races: a start-paused debug launch can interrupt headless initialization, and
signals sent during forced process teardown can be delayed. The final script
allows teardown to settle, waits for background success, then launches the
verification fixture normally. No production recovery exception was suppressed.

## Limits

OS scheduling is best effort. Force-stop, power-off, first-unlock protection,
permissions, channel settings, and OEM battery restrictions still apply.
Database writes and OS notifications cannot be one atomic transaction. A crash
after refill delivery but before acknowledgement can retry the same native ID;
exactly-once OS delivery is not promised. These windows are documented in the
design and user-facing delivery limits.

The native bridge uses public classes/constants from lockfile-resolved
`workmanager_android` 0.10.9 and should be retested when upgrading. Its existing
Kotlin Gradle plugin compatibility warning remains a dependency-upgrade concern.
Physical Android delivery/OEM testing and iOS build/delivery need their respective
devices. No seven-day unattended test or independent peer review is claimed.
