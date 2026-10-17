# Medicine flow

For the expanded guest, English/Hindi, PDF export, privacy/reset and quality work, see [epics 1–7 status](EPICS-1-7-STATUS.md) and its linked design/review. The feature-specific evidence below records the earlier medicine/recovery implementation; the current complete-suite results are in the epic review.

The signed-in user can add or edit a medicine, preview seven days of doses, view Today's timeline, and record Taken, Skip, Undo, or Snooze. Medicines can be paused, resumed, or archived. History shows recording summaries and original dose details; Refills tracks stock and corrections. There is no seeded medication data. Names and instructions are entered by the user; strength and quantity are separate fields. Identical names require a confirmation to add a separate plan.

## Storage and accounts

Android, iOS, and macOS use SQLCipher SQLite with a random device key in platform secure storage. SQLite schema version 1 stores a versioned account snapshot in a transaction. Mutations reload the authoritative snapshot before committing; actions append to a correction trail. An unsupported data version fails without resetting records. Keys are never regenerated to recover an existing unreadable database.

Account payload version 3 retains immutable prior schedule revisions and original recorded-dose snapshots, adding inventory accounts/entries and reminder recovery context. Versions 1 and 2 are read without replacing the database or key; migrated stock is unknown until a user sets a baseline. Confirmed doses keep their original name, strength, quantity, and time across edits and archive. See [MED-019 system design](MED-019-DESIGN.md) and [recovery/history/refills design](RECOVERY-HISTORY-REFILLS-DESIGN.md).

Windows, Linux, and web use the same versioned snapshot in platform secure storage, with serialized writes. Browser storage requires HTTPS or localhost and is tied to the browser/origin. Desktop and browser scheduling is not enabled. These platforms do not have the Android background worker. Very large datasets should migrate from secure-storage snapshots to an encrypted desktop database before adding long-term history/export features.

Medicine data stays on this device and is scoped by the authenticated user's ID. Login does not upload or synchronize medicine data. Signing out cancels this installation's reminders and hides records; signing back into the same account restores them. Switching accounts does not merge records. Android database/preferences are excluded from backup and transfer; iOS uses a private directory excluded from backup and a device-only Keychain key. App uninstall, key loss, browser storage clearing, and device replacement have no restore mechanism in this release.

## Schedule rules

- One to eight distinct clock times on daily or selected weekdays, with inclusive start/end dates.
- A named IANA timezone is captured from the device when the plan is created. The schedule remains anchored to that timezone during travel; the timeline displays the current device's local time. The preview displays the plan's time.
- Calendar recurrence preserves wall-clock times rather than adding elapsed 24-hour intervals. A daylight-saving gap moves to the next valid local time; a fold produces one occurrence. Tests cover both transitions.
- A dose ID combines the medicine ID, schedule revision, local calendar date, and configured minute. Taken/Skipped state belongs to a dated dose. Retrying completion or Undo does not create another effective result.
- Snooze moves the next alert 15 minutes later without changing the prescribed time. Snoozing an upcoming dose cannot move its alert earlier. Completion cancels its alert; Undo preserves the event trail. Undo of an already past dose does not emit an immediate replacement alarm.
- A past dose without an action is shown as **Unconfirmed**. It is not automatically treated as missed or taken. Progress means the proportion of today's scheduled doses the user recorded as taken.
- Edits take effect at save time, displayed in the editor and on the saved medicine. Earlier doses remain attached to their original schedule version. A stale editor cannot overwrite a newer version; reopen it to edit the current plan. The plan timezone is preserved by the editor.
- Pause and archive cancel all future alerts, including snoozes. Resume starts from the current instant without replaying alerts from the paused period. Pausing app reminders is not a treatment instruction. Archive is read-only; permanent deletion separately removes all versions and records.
- An early-confirmed future dose retains its original details and owns its original medicine/time slot across edits, preventing a duplicate at the same instant. Undo of a superseded future dose leaves it canceled, including after its old due time. Canceled, unconfirmed records do not count as pending doses.
- Medicines > Active/Archived > View recorded doses opens original details and correction controls. Past historical doses can be corrected manually; historical snoozes and obsolete notification actions cannot restart reminders.
- PRN, interval regimens, cloud synchronization, and export remain subsequent features.

## History and stock

Today opens History and Refills. History defaults to seven device-local calendar days and accepts ranges of up to 366 days. The summary is recorded Taken divided by eligible due doses, not proven adherence. Future doses, paused intervals, canceled unconfirmed occurrences, and unknown coverage are excluded. New plans record when tracking starts; older reconstructed schedules without action logs appear as coverage gaps. Explicitly recorded past doses remain reportable. State filters affect the records list; period and medicine filters define the summary. Original details survive edits and archive, and correction events recompute reporting.

Refills supports initial stock, replenishment, physical-count corrections, thresholds, and a dated inventory ledger. Quantities use exact integers at four decimal places. Taken decrements once; Undo reverses only a matching consumption. Stock setup is a present-day baseline and does not subtract old Taken logs. Skip/snooze/unconfirmed do not consume stock. Negative balances remain visible as Needs correction. Unit conversions are never guessed; stop tracking before changing the unit. Old stock accounts/entries remain in the ledger after stopping. A stale physical-count form cannot overwrite intervening consumption.

Low-stock notifications are private and deduplicated per stock episode; replenishment or recovery above the threshold resets the episode. Permission/channel denial leaves the alert eligible for retry. Paused and archived plans do not emit refill notices. Supply dates are labeled estimates based on the current schedule over 90 days; paused or unknown stock does not receive an invented estimate. Archive retains the ledger; permanent medicine deletion removes it along with dose history.

## Reminders

Local alarms are scheduled natively using `flutter_local_notifications`. Delivery does not depend on the Today screen staying open. Notification content is private; Taken and Snooze actions open the app and require the matching signed-in account. Stale or deleted plan actions cannot recreate records. Notification payloads contain IDs and timestamps, not medicine names or instructions.

Reconciliation schedules up to 30 days ahead, capped at 450 pending Android alarms and 60 iOS notifications. It checks permission, channel blocking, and exact-alarm access; without exact access Android schedules approximate alarms and displays degraded capability. The Today screen shows the last scheduled date. Device/OEM limits and power restrictions still require device testing.

Android WorkManager replenishes the horizon approximately every 12 hours, without a network requirement. This is housekeeping, not the delivery mechanism. The app's `ReminderRecoveryReceiver` queues unique recovery work after boot, package replacement, time/timezone changes, and exact-alarm access grants. It replaces cached boot replay, reads encrypted authoritative plans, and rebuilds only eligible future alarms. Startup/resume and manual retry also check timezone, Android monotonic uptime/boot count, and recovery generation so unchanged payloads can still be rescheduled after system changes. Dose records and stock are never invented by recovery.

Travel notices compare device and plan timezone offsets, preserve the existing plan timezone, and ask users to verify timing with their clinician. Acknowledging the notice does not change prescribed times. Delivery limits are available from Today. Force-stop, denied permissions, pre-unlock key access, disabled channels, and OS background restrictions can prevent reminders. Powered-off devices cannot deliver them. WorkManager execution is best effort; reopening repairs eligible schedules. iOS currently replenishes only when opened/resumed; it does not promise indefinite unattended delivery. Notification Settings links and permission recovery are available from Today.

Database changes are atomic; OS alarm APIs do not support a joint database/alarm transaction. Serialized reconciliation cancels obsolete pending and displayed alarms before scheduling replacements. If this fails, the plan stays saved and the reminder status offers recovery. Startup/resume/manual retry and the Android worker repair from durable state. A small commit-to-cancel failure window remains. Notification actions recheck active revision inside the mutation, so an obsolete alarm cannot record a dose after an intervening edit.

## Validation

Use Flutter 3.47.7 / Dart 3.13.5 or a compatible later SDK. The machine's global Flutter 3.41.6 is older than this repository's constraint; a separate matching SDK was prepared at `C:/tmp/medicine-flutter` for this work.

```powershell
dart format --output=none --set-exit-if-changed lib test integration_test test_driver
flutter analyze
flutter test --coverage
flutter build apk --debug
```

Run native checks on a disposable Android emulator after installing a debug build and granting its notification permission:

```powershell
adb install -r -t build/app/outputs/flutter-apk/app-debug.apk
adb shell pm grant com.example.medicine_reminder android.permission.POST_NOTIFICATIONS
adb shell appops set com.example.medicine_reminder SCHEDULE_EXACT_ALARM allow
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/medicine_flow_test.dart -d emulator-5554 --no-dds
```

The native test uses only synthetic accounts. It exercises SQLCipher close/reopen, native scheduling, stock consumption/refill notification, recovery work, edit-during-snooze alarm replacement, pause/resume, archive, retained records, and deletion. The driver saves native screenshots to `build/medicine-native-screenshots`. It does not call production authentication. A normal app build still needs the Supabase configuration described in README. The drive command removes the test app unless `--keep-app-running` is supplied; install and grant permissions again before a new run.

Current unit/widget/adapter suite: 143 passing tests with clean static analysis. The native flow and all five system-event checks (timezone, forward/backward clock, package update, reboot) pass on Android API 35. See [current review and evidence](RECOVERY-HISTORY-REFILLS-REVIEW.md), [MED-019 review](MED-019-REVIEW.md) for the earlier baseline, and the [recovery/history/refills design](RECOVERY-HISTORY-REFILLS-DESIGN.md). The driver command above avoids a Flutter 3.47.7 golden-stream reporting error in the `flutter test` integration runner. Android's `Asia/Calcutta` timezone alias has a regression test and uses the complete timezone database.

For system-event checks, build `integration_test/recovery_system_fixture_test.dart` into `build/recovery-system-fixture.apk`, install/grant permissions, and run once with the driver and `--keep-app-running` to seed its synthetic account. Then run `scripts/verify_android_recovery.ps1`. The script is restricted to the isolated `MedicineReminder_QA` emulator, changes its timezone/clock, installs the same APK as an update, and reboots it. It restores the initial timezone and auto-time setting. Verification uses a normal unpaused launch after successful headless work, before any foreground provider can repair alarms; a start-paused debug driver can race the background isolate. Logs are in `build/recovery-system-*.log`.

This machine's C: drive was nearly full. Builds/tests were run with process-local `TEMP` and `TMP` set to `D:/tmp/medicine-build-temp`, and Java's temporary directory set there using `JAVA_TOOL_OPTIONS=-Djava.io.tmpdir=D:/tmp/medicine-build-temp`. The separate emulator's files are under `D:/tmp/medicine-avds`; existing emulator data was not changed.

Before release, verify notification taps and actions from cold start, lock/unlock, permission revoke/regrant, channel blocking, reboot/update, force-stop recovery, offline use for seven days, and at least one manufacturer with battery restrictions on real phones. Run iOS build and delivery checks on macOS/iPhone; Windows cannot verify Swift compilation or iOS delivery. Do not mark the board's real-device evidence requirements complete from unit tests alone.
