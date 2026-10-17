# MED-019 implementation review

Self-review of the edit, pause, resume, and archive change, 18 October 2026.
This does not replace the board's independent teammate/real-device review.

## Implemented

- Prefilled editor for name, strength, form, dose quantity/unit, instructions,
  times, weekdays, and inclusive course dates. Existing timezone and paused
  state are preserved; effective save time is explained and displayed.
- Serialized revision-checked mutations close the previous version and commit
  its successor together. Account switches invalidate queued commands.
- Payload version 2 retains old versions and original acted-dose snapshots;
  version 1 action trails migrate without a new database or encryption key.
- Today and recorded-dose details use the same projection. Early-confirmed
  slots cannot be duplicated by a later revision. Undo of a retired future
  confirmation leaves a canceled record, excluded from pending counts.
- Pause/resume cancels old snoozes and skips the paused interval. Archive is
  read-only for plans, retains recorded-dose access, and removes future alarms.
  Explicit deletion removes all versions, snapshots, and events for that plan.

## Findings resolved during review

1. Notification validation could race an intervening edit. Active revision is
   now rechecked inside the mutation transaction, with a queued-action regression.
2. Active/Archived controls overflowed at enlarged text on a narrow screen.
   They now wrap; the small-screen editor/navigation regression passes.
3. Undo of an early-confirmed retired dose could become Unconfirmed once its
   former due time passed. Cancellation is now derived from the closed version's
   bound, remains stable over time, and prevents new actions/alerts for that slot.

## Automated evidence

- `flutter analyze`: no issues.
- `flutter test --coverage`: 97 tests passed, including 25 new tests.
- Regression coverage includes edit during snooze, early confirmations, end
  dates, weekday changes, exact effective boundaries, pause/resume gaps, archive,
  round-trip/migration, rapid stale submissions, failed storage, failed alarm
  cancellation, reminder retry, account isolation, and stale notification races.
- Widget checks include prefilled editing, save failure/retry, archive/record
  access, and a 360-pixel screen at 1.6 text scale.
- Full-suite log: `build/med019-final-tests.log` (local ignored build artifact).

## Native and release boundary

Android API 35 emulator integration passed with the documented driver command.
The final APK was rebuilt and the test checked actual SQLCipher reopen, retained
original confirmations, pending alarm IDs after edit during snooze, pause/resume,
archive cancellation, and archived persistence after reopening. Native output:
`00:11 +2: All tests passed!`; log: `build/med019-native-final.log`.
The first attempt failed its notification-permission precondition on the fresh
emulator; installing the test app and granting notification/exact-alarm access
resolved that setup issue. No production account or real medicine data was used.

Database/OS alarms cannot share one transaction. Obsolete cancellation precedes
replacement scheduling; failures are visible and repairable. A crash in the
commit-to-cancel window can leave an old alarm visible until reconciliation;
its action cannot mutate a retired dose through the notification path.

Physical-device delivery, reboot/update/clock changes, OEM battery behavior,
and iOS compilation/delivery remain release checks and MED-020 scope. No board
issue is closed or real-device evidence claimed by this implementation review.
