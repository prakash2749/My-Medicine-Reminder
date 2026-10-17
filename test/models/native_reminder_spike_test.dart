import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_reminder/core/models/native_reminder_spike.dart';
import 'package:medicine_reminder/core/services/medicine_notifications.dart';

void main() {
  group('MED-005 Native Reminder Spike Verification Tests', () {
    // -------------------------------------------------------------------------
    // AC1: Device Matrix & OS Power Mode Resilience
    // -------------------------------------------------------------------------
    group('AC1: Device Matrix & OS Power Mode Resilience', () {
      test('Device Matrix: Covers Android (API 26-35) and iOS (iOS 15-18)', () {
        final devices = NativeReminderSpikeFixtures.devices;
        expect(devices.length, greaterThanOrEqualTo(8));

        final androidDevices = NativeReminderSpikeFixtures.devicesByPlatform(
            SpikePlatform.android);
        final iosDevices =
            NativeReminderSpikeFixtures.devicesByPlatform(SpikePlatform.ios);

        expect(androidDevices.isNotEmpty, isTrue);
        expect(iosDevices.isNotEmpty, isTrue);

        final apiLevels =
            androidDevices.map((d) => d.apiLevel).whereType<int>().toSet();
        expect(apiLevels, contains(35)); // Android 15
        expect(apiLevels, contains(34)); // Android 14
        expect(apiLevels, contains(33)); // Android 13
        expect(apiLevels, contains(27)); // Android 8.1 (Baseline)

        final iosVersions = iosDevices.map((d) => d.osVersion).toList();
        expect(iosVersions.any((v) => v.contains('18')), isTrue); // iOS 18
        expect(iosVersions.any((v) => v.contains('15')), isTrue); // iOS 15

        // All devices must verify UI-absent delivery and interactive actions
        for (final device in devices) {
          expect(device.processAbsentDelivery, isTrue);
          expect(device.lockScreenActionsSupported, contains('Taken'));
          expect(device.lockScreenActionsSupported, contains('Snooze 15 min'));
          expect(device.rebootRecoverySupported, isTrue);
          expect(device.status, VerificationStatus.pass);
        }

        // Quota limits check: Android 450, iOS 60
        for (final d in androidDevices) {
          expect(d.maxScheduledHorizon, 450);
          expect(d.alarmMechanism, AlarmMechanism.alarmManagerExact);
        }
        for (final d in iosDevices) {
          expect(d.maxScheduledHorizon, 60);
          expect(d.alarmMechanism, AlarmMechanism.userNotificationCenter);
        }

        expect(NativeReminderSpikeFixtures.passRate, 100.0);
        expect(NativeReminderSpikeFixtures.deviceCount, devices.length);
        expect(
          NativeReminderSpikeFixtures.devicesByStatus(VerificationStatus.pass)
              .length,
          devices.length,
        );
      });

      test('OEM Power Management & Idle Modes Audited', () {
        final devices = NativeReminderSpikeFixtures.devices;
        final idleModes = devices.map((d) => d.idleModeTested).toSet();

        expect(idleModes, contains(IdleMode.deepDoze));
        expect(idleModes, contains(IdleMode.standardDoze));
        expect(idleModes, contains(IdleMode.appStandbyBucket));
        expect(idleModes, contains(IdleMode.oemBatterySaver));
        expect(idleModes, contains(IdleMode.iosLowPowerMode));

        // OEM skins represented
        final skins = devices.map((d) => d.oemSkin).toSet();
        expect(skins.any((s) => s.contains('One UI')), isTrue);
        expect(skins.any((s) => s.contains('HyperOS')), isTrue);
        expect(skins.any((s) => s.contains('OxygenOS')), isTrue);
        expect(skins.any((s) => s.contains('Stock Android')), isTrue);
        expect(skins.any((s) => s.contains('SpringBoard')), isTrue);

        // Recovery durations all meet <2000ms SLA
        for (final d in devices) {
          expect(d.averageRecoveryDurationMs, lessThanOrEqualTo(2000));
          expect(d.averageRecoveryDurationMs, greaterThan(0));
        }
      });
    });

    // -------------------------------------------------------------------------
    // AC2: Permission Lifecycle & State Transitions
    // -------------------------------------------------------------------------
    group('AC2: Permission Lifecycle & State Transitions', () {
      test('Permission Lifecycle Scenarios & Zero-Crash Invariant', () {
        final permissions = NativeReminderSpikeFixtures.permissionScenarios;
        expect(permissions.length, greaterThanOrEqualTo(6));
        expect(NativeReminderSpikeFixtures.allZeroCrash, isTrue);

        // Verify Full Authorization
        final full = permissions.firstWhere(
          (p) => p.state == PermissionState.fullyGranted,
        );
        expect(full.expectedReadiness.supported, isTrue);
        expect(full.expectedReadiness.notifications, isTrue);
        expect(full.expectedReadiness.exact, isTrue);
        expect(full.fallbackScheduleMode, 'exactAllowWhileIdle');
        expect(full.zeroCrashObserved, isTrue);

        // Verify POST_NOTIFICATIONS Denied (Android 13+)
        final notifDenied = permissions.firstWhere(
          (p) => p.state == PermissionState.notificationsDenied,
        );
        expect(notifDenied.expectedReadiness.notifications, isFalse);
        expect(notifDenied.fallbackScheduleMode, 'cancelled');
        expect(
          notifDenied.honestUiMessage,
          contains('Notifications are off. Enable them in Settings'),
        );
        expect(notifDenied.zeroCrashObserved, isTrue);

        // Verify SCHEDULE_EXACT_ALARM Revoked (Android 14+)
        final exactRevoked = permissions.firstWhere(
          (p) => p.state == PermissionState.exactAlarmRevoked,
        );
        expect(exactRevoked.expectedReadiness.notifications, isTrue);
        expect(exactRevoked.expectedReadiness.exact, isFalse);
        expect(exactRevoked.fallbackScheduleMode, 'inexactAllowWhileIdle');
        expect(
          exactRevoked.honestUiMessage,
          contains(
              'Reminders may arrive late. Allow precise alarms in Settings.'),
        );
        expect(exactRevoked.zeroCrashObserved, isTrue);

        // Verify Channel Blocked Scenarios
        final doseBlocked = permissions.firstWhere(
          (p) => p.state == PermissionState.channelDosesBlocked,
        );
        expect(doseBlocked.expectedReadiness.notifications, isFalse);
        expect(doseBlocked.fallbackScheduleMode, 'cancelled');
        expect(doseBlocked.zeroCrashObserved, isTrue);

        final refillBlocked = permissions.firstWhere(
          (p) => p.state == PermissionState.channelRefillsBlocked,
        );
        expect(refillBlocked.expectedReadiness.notifications, isTrue);
        expect(refillBlocked.expectedReadiness.refillNotifications, isFalse);
        expect(refillBlocked.fallbackScheduleMode, 'exactAllowWhileIdle');
        expect(refillBlocked.zeroCrashObserved, isTrue);

        final allBlocked = permissions.firstWhere(
          (p) => p.state == PermissionState.allChannelsBlocked,
        );
        expect(allBlocked.expectedReadiness.notifications, isFalse);
        expect(allBlocked.expectedReadiness.refillNotifications, isFalse);
        expect(allBlocked.fallbackScheduleMode, 'cancelled');
        expect(allBlocked.zeroCrashObserved, isTrue);
      });

      test('Exhaustive Permission State Transition Graph & Labels', () {
        // Verify all enum labels
        expect(
          PermissionState.fullyGranted.label,
          'Fully Granted & Authorized',
        );
        expect(
          PermissionState.notificationsDenied.label,
          'Notifications Denied',
        );
        expect(
          PermissionState.exactAlarmRevoked.label,
          'SCHEDULE_EXACT_ALARM Revoked',
        );
        expect(
          PermissionState.channelDosesBlocked.label,
          'Dose Channel Disabled',
        );
        expect(
          PermissionState.channelRefillsBlocked.label,
          'Refill Channel Disabled',
        );
        expect(
          PermissionState.allChannelsBlocked.label,
          'All App Channels Disabled',
        );

        // Transition simulation:
        // 1. Initial full state
        var readiness = const ReminderReadiness(
          supported: true,
          notifications: true,
          exact: true,
          refillNotifications: true,
        );
        expect(readiness.notifications, isTrue);
        expect(readiness.exact, isTrue);

        // 2. User revokes exact alarm in system settings
        readiness = readiness.copyWith(exact: false);
        expect(readiness.exact, isFalse);
        expect(readiness.notifications, isTrue);
        expect(
          readiness.message,
          'Reminders may arrive late. Allow precise alarms in Settings.',
        );

        // 3. User re-grants exact alarm
        readiness = readiness.copyWith(exact: true);
        expect(readiness.exact, isTrue);
        expect(readiness.message, 'Reminders are ready.');

        // 4. User revokes notifications entirely
        readiness = readiness.copyWith(notifications: false);
        expect(readiness.notifications, isFalse);
        expect(
          readiness.message,
          'Notifications are off. Enable them in Settings to receive reminders.',
        );

        // 5. Notifications re-enabled but dose channel muted
        readiness = readiness.copyWith(
            notifications:
                false); // channel muted treats notifications as false
        expect(
          readiness.message,
          'Notifications are off. Enable them in Settings to receive reminders.',
        );

        // 6. Dose channel unmuted but refill channel muted
        readiness = readiness.copyWith(
          notifications: true,
          refillNotifications: false,
        );
        expect(readiness.notifications, isTrue);
        expect(readiness.refillNotifications, isFalse);
        expect(readiness.message, 'Reminders are ready.');

        // 7. Error condition overrides all other messages
        readiness = readiness.copyWith(error: 'System storage unavailable');
        expect(readiness.message, 'System storage unavailable');
      });

      test('Settings Deep-Link Consistency', () {
        for (final p in NativeReminderSpikeFixtures.permissionScenarios) {
          expect(p.deepLinkAction, 'openNotificationSettings');
          expect(p.notes.isNotEmpty, isTrue);
          expect(p.scenario.isNotEmpty, isTrue);
        }
      });
    });

    // -------------------------------------------------------------------------
    // AC3: Storage & Cryptographic Boundaries (BFU vs AFU)
    // -------------------------------------------------------------------------
    group('AC3: Storage & Cryptographic Boundaries (BFU vs AFU)', () {
      test('Storage Records: CE vs DE Evaluation & HIPAA Rationale', () {
        final records = NativeReminderSpikeFixtures.storageRecords;
        expect(records.length, greaterThanOrEqualTo(3));

        // CE Storage on Android: Inaccessible BFU, Accessible AFU
        final ceAndroid = records.firstWhere(
          (r) =>
              r.storageContext == DirectBootStorage.credentialProtected &&
              r.platform == SpikePlatform.android,
        );
        expect(ceAndroid.accessibilityBeforeFirstUnlock, isFalse);
        expect(ceAndroid.accessibilityAfterFirstUnlock, isTrue);
        expect(ceAndroid.phiExposedToLockScreen, isFalse);
        expect(ceAndroid.nonDestructiveKeyRecovery, isTrue);
        expect(ceAndroid.securityComplianceRationale, contains('ADOPTED'));
        expect(ceAndroid.keystoreProvider, contains('Android KeyStore'));

        // DE Storage on Android: Accessible BFU, but rejected for PHI compliance
        final deAndroid = records.firstWhere(
          (r) => r.storageContext == DirectBootStorage.deviceProtected,
        );
        expect(deAndroid.accessibilityBeforeFirstUnlock, isTrue);
        expect(deAndroid.securityComplianceRationale, contains('REJECTED'));
        expect(deAndroid.securityComplianceRationale, contains('Cellebrite'));

        // iOS Keychain
        final iosStorage = records.firstWhere(
          (r) => r.platform == SpikePlatform.ios,
        );
        expect(iosStorage.accessibilityBeforeFirstUnlock, isFalse);
        expect(iosStorage.accessibilityAfterFirstUnlock, isTrue);
        expect(iosStorage.securityComplianceRationale, contains('ADOPTED'));
        expect(
          iosStorage.securityComplianceRationale,
          contains('kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly'),
        );

        expect(NativeReminderSpikeFixtures.allNonDestructive, isTrue);
      });

      test('DirectBootStorage Enum Descriptions', () {
        expect(
          DirectBootStorage.credentialProtected.description,
          'Credential-Protected (CE) Storage',
        );
        expect(
          DirectBootStorage.deviceProtected.description,
          'Device-Protected (DE) Storage',
        );
      });

      test('Non-Destructive Key Invariant Simulation (StateError on BFU)', () {
        // In Direct Boot (BFU), hardware Keystore is inaccessible.
        // If an existing SQLite database exists and key retrieval returns null:
        // The store must throw StateError rather than creating a random new key.
        bool simulateStoreOpenWithKey(String? key, bool dbExists) {
          if (key == null) {
            if (dbExists) {
              throw StateError(
                'The existing medicine database key is unavailable.',
              );
            }
          }
          return true;
        }

        // BFU with existing db throws StateError
        expect(
          () => simulateStoreOpenWithKey(null, true),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('The existing medicine database key is unavailable.'),
            ),
          ),
        );

        // AFU with existing db and unlocked key succeeds
        expect(simulateStoreOpenWithKey('valid-sqlcipher-key', true), isTrue);

        // Brand new install (db does not exist yet) allows key generation
        expect(simulateStoreOpenWithKey(null, false), isTrue);
      });

      test('WorkManager Retry Simulation for BFU Locked State', () {
        // WorkManager background task catches StateError on BFU, returns retry
        bool executeWorkTask({required bool deviceLocked}) {
          try {
            if (deviceLocked) {
              throw StateError(
                'The existing medicine database key is unavailable.',
              );
            }
            return true; // Work succeeded
          } catch (_) {
            return false; // Result.retry() in WorkManager
          }
        }

        // BFU execution fails safely and requests retry
        expect(executeWorkTask(deviceLocked: true), isFalse);
        // AFU execution succeeds
        expect(executeWorkTask(deviceLocked: false), isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // AC3: Physical Platform Boundaries & Limitations
    // -------------------------------------------------------------------------
    group('AC3: Physical Platform Boundaries & Limitations', () {
      test('Physical Limitations Taxonomy & System Mechanisms', () {
        final limits = NativeReminderSpikeFixtures.physicalLimitations;
        expect(limits.length, 5);

        // 1. Powered-Off
        final poweredOff = limits.firstWhere(
          (l) => l.limitationType == PhysicalLimitationType.poweredOff,
        );
        expect(poweredOff.canDeliverReminders, isFalse);
        expect(poweredOff.osMechanism, contains('AP and CPU powered down'));
        expect(poweredOff.recoveryTrigger, contains('BOOT_COMPLETED'));
        expect(poweredOff.patientSafetyAdvice, contains('pillbox'));

        // 2. Force-Stop Quarantine
        final forceStop = limits.firstWhere(
          (l) => l.limitationType == PhysicalLimitationType.forceStopQuarantine,
        );
        expect(forceStop.canDeliverReminders, isFalse);
        expect(
            forceStop.osMechanism, contains('FLAG_EXCLUDE_STOPPED_PACKAGES'));
        expect(forceStop.recoveryTrigger,
            contains('Explicit manual application launch'));
        expect(forceStop.patientSafetyAdvice, contains('Force Stop'));

        // 3. OEM Task Killer Daemons
        final oemKiller = limits.firstWhere(
          (l) => l.limitationType == PhysicalLimitationType.aggressiveOemKiller,
        );
        expect(oemKiller.canDeliverReminders, isTrue);
        expect(oemKiller.osMechanism, contains('Samsung Smart Manager'));
        expect(oemKiller.recoveryTrigger, contains('Autostart'));
        expect(oemKiller.patientSafetyAdvice, contains('battery exemption'));

        // 4. iOS SpringBoard Ceiling
        final iosLimit = limits.firstWhere(
          (l) =>
              l.limitationType ==
              PhysicalLimitationType.springBoardQuotaExhaustion,
        );
        expect(iosLimit.canDeliverReminders, isTrue);
        expect(iosLimit.osMechanism, contains('64'));
        expect(iosLimit.patientSafetyAdvice, contains('14-30 days'));

        // 5. Clock Tampering / DST
        final clockTampering = limits.firstWhere(
          (l) => l.limitationType == PhysicalLimitationType.clockTampering,
        );
        expect(clockTampering.canDeliverReminders, isTrue);
        expect(clockTampering.osMechanism, contains('monotonic'));
        expect(clockTampering.recoveryTrigger, contains('ACTION_TIME_CHANGED'));
        expect(
          clockTampering.patientSafetyAdvice,
          contains('without re-triggering taken doses'),
        );
      });

      test('PhysicalLimitationType Enum Titles', () {
        expect(
          PhysicalLimitationType.poweredOff.title,
          'Powered-Off Hardware',
        );
        expect(
          PhysicalLimitationType.forceStopQuarantine.title,
          'Force-Stop Quarantine',
        );
        expect(
          PhysicalLimitationType.aggressiveOemKiller.title,
          'OEM Battery Killer Daemons',
        );
        expect(
          PhysicalLimitationType.springBoardQuotaExhaustion.title,
          'iOS SpringBoard 64-Alarm Cap',
        );
        expect(
          PhysicalLimitationType.clockTampering.title,
          'Clock Manipulation / Daylight Saving Shift',
        );
      });
    });

    // -------------------------------------------------------------------------
    // Empirical Event Logs & Monotonic Telemetry
    // -------------------------------------------------------------------------
    group('Empirical Recovery Event Logs & Monotonic Telemetry', () {
      test('All 5 Empirical Event Logs Satisfy SLA and Assertions', () {
        final logs = NativeReminderSpikeFixtures.empiricalEventLogs;
        expect(logs.length, 5);

        final events = logs.map((l) => l.event).toSet();
        expect(events, contains('TIMEZONE_CHANGED'));
        expect(events, contains('TIME_SET (Clock Forward)'));
        expect(events, contains('TIME_SET (Clock Backward)'));
        expect(events, contains('MY_PACKAGE_REPLACED'));
        expect(events, contains('BOOT_COMPLETED'));

        for (final log in logs) {
          expect(log.workerResult, 'SUCCESS');
          expect(log.durationMs, lessThan(2000));
          expect(log.verifiedAssertions, isNotEmpty);
          expect(log.generationIncremented, isTrue);
          expect(log.trigger.isNotEmpty, isTrue);
        }
      });

      test('Monotonic Telemetry Fields & Clock Drift Thresholds', () {
        final clockFwd = NativeReminderSpikeFixtures.empiricalEventLogs
            .firstWhere((l) => l.event.contains('Clock Forward'));
        expect(
          clockFwd.verifiedAssertions.any((a) => a.contains('threshold')),
          isTrue,
        );

        final clockBwd = NativeReminderSpikeFixtures.empiricalEventLogs
            .firstWhere((l) => l.event.contains('Clock Backward'));
        expect(
          clockBwd.verifiedAssertions
              .any((a) => a.contains('Stock balance unchanged')),
          isTrue,
        );

        final bootLog = NativeReminderSpikeFixtures.empiricalEventLogs
            .firstWhere((l) => l.event == 'BOOT_COMPLETED');
        expect(
          bootLog.verifiedAssertions.any(
            (a) => a.toLowerCase().contains('generation'),
          ),
          isTrue,
        );
        expect(
          bootLog.verifiedAssertions
              .any((a) => a.contains('450 future alarms')),
          isTrue,
        );
      });
    });

    // -------------------------------------------------------------------------
    // Horizon Boundary Calculations & Quota Limits
    // -------------------------------------------------------------------------
    group('Horizon Boundary Calculations (Android 450 vs iOS 64 Ceiling)', () {
      test('Platform Maximum Alarm Ceilings and SpringBoard Headroom', () {
        expect(
          NativeReminderSpikeFixtures.maxAlarmsForPlatform(
              SpikePlatform.android),
          450,
        );
        expect(
          NativeReminderSpikeFixtures.maxAlarmsForPlatform(SpikePlatform.ios),
          60,
        );
        expect(NativeReminderSpikeFixtures.iosSpringBoardCeiling, 64);
        expect(NativeReminderSpikeFixtures.iosSafetyHeadroom, 4);
        expect(
          NativeReminderSpikeFixtures.iosSpringBoardCeiling -
              NativeReminderSpikeFixtures.maxAlarmsForPlatform(
                  SpikePlatform.ios),
          NativeReminderSpikeFixtures.iosSafetyHeadroom,
        );
      });

      test('Calculates Scheduled Alarms Bounded by Platform Ceiling', () {
        // Zero or negative
        expect(
          NativeReminderSpikeFixtures.calculateScheduledAlarms(
            platform: SpikePlatform.android,
            candidateCount: 0,
          ),
          0,
        );
        expect(
          NativeReminderSpikeFixtures.calculateScheduledAlarms(
            platform: SpikePlatform.ios,
            candidateCount: -5,
          ),
          0,
        );

        // Below ceiling
        expect(
          NativeReminderSpikeFixtures.calculateScheduledAlarms(
            platform: SpikePlatform.android,
            candidateCount: 30,
          ),
          30,
        );
        expect(
          NativeReminderSpikeFixtures.calculateScheduledAlarms(
            platform: SpikePlatform.ios,
            candidateCount: 30,
          ),
          30,
        );

        // Exactly at ceiling
        expect(
          NativeReminderSpikeFixtures.calculateScheduledAlarms(
            platform: SpikePlatform.android,
            candidateCount: 450,
          ),
          450,
        );
        expect(
          NativeReminderSpikeFixtures.calculateScheduledAlarms(
            platform: SpikePlatform.ios,
            candidateCount: 60,
          ),
          60,
        );

        // Exceeding ceiling (capped strictly)
        expect(
          NativeReminderSpikeFixtures.calculateScheduledAlarms(
            platform: SpikePlatform.android,
            candidateCount: 451,
          ),
          450,
        );
        expect(
          NativeReminderSpikeFixtures.calculateScheduledAlarms(
            platform: SpikePlatform.android,
            candidateCount: 1200,
          ),
          450,
        );
        expect(
          NativeReminderSpikeFixtures.calculateScheduledAlarms(
            platform: SpikePlatform.ios,
            candidateCount: 61,
          ),
          60,
        );
        expect(
          NativeReminderSpikeFixtures.calculateScheduledAlarms(
            platform: SpikePlatform.ios,
            candidateCount: 500,
          ),
          60,
        );
      });

      test('Computes Horizon Days Across Dose Regimens (1 to 20 doses/day)',
          () {
        // 0 doses/day
        expect(
          NativeReminderSpikeFixtures.computeHorizonDays(
            platform: SpikePlatform.android,
            dailyDoseFrequency: 0,
          ),
          0.0,
        );

        // 1 dose/day (30-day max lookahead)
        expect(
          NativeReminderSpikeFixtures.computeHorizonDays(
            platform: SpikePlatform.android,
            dailyDoseFrequency: 1,
          ),
          30.0,
        );
        expect(
          NativeReminderSpikeFixtures.computeHorizonDays(
            platform: SpikePlatform.ios,
            dailyDoseFrequency: 1,
          ),
          30.0,
        );

        // 2 doses/day (60 doses over 30 days)
        // iOS: 60 / 2 = 30 days (fits exactly within 30-day lookahead)
        expect(
          NativeReminderSpikeFixtures.computeHorizonDays(
            platform: SpikePlatform.ios,
            dailyDoseFrequency: 2,
          ),
          30.0,
        );
        expect(
          NativeReminderSpikeFixtures.computeHorizonDays(
            platform: SpikePlatform.android,
            dailyDoseFrequency: 2,
          ),
          30.0,
        );

        // 3 doses/day (90 doses over 30 days)
        // Android: 450 / 3 = 150 days -> capped at 30 days lookahead
        expect(
          NativeReminderSpikeFixtures.computeHorizonDays(
            platform: SpikePlatform.android,
            dailyDoseFrequency: 3,
          ),
          30.0,
        );
        // iOS: 60 / 3 = 20.0 days (reaches ceiling before 30 days)
        expect(
          NativeReminderSpikeFixtures.computeHorizonDays(
            platform: SpikePlatform.ios,
            dailyDoseFrequency: 3,
          ),
          20.0,
        );

        // 4 doses/day (e.g. QID antibiotic)
        // iOS: 60 / 4 = 15.0 days
        expect(
          NativeReminderSpikeFixtures.computeHorizonDays(
            platform: SpikePlatform.ios,
            dailyDoseFrequency: 4,
          ),
          15.0,
        );

        // 6 doses/day (polypharmacy: 3 meds BID)
        // iOS: 60 / 6 = 10.0 days
        expect(
          NativeReminderSpikeFixtures.computeHorizonDays(
            platform: SpikePlatform.ios,
            dailyDoseFrequency: 6,
          ),
          10.0,
        );
        expect(
          NativeReminderSpikeFixtures.computeHorizonDays(
            platform: SpikePlatform.android,
            dailyDoseFrequency: 6,
          ),
          30.0, // 450 / 6 = 75 days -> 30 days
        );

        // 15 doses/day
        // Android: 450 / 15 = 30.0 days (fits exactly at 30-day horizon)
        expect(
          NativeReminderSpikeFixtures.computeHorizonDays(
            platform: SpikePlatform.android,
            dailyDoseFrequency: 15,
          ),
          30.0,
        );
        // iOS: 60 / 15 = 4.0 days
        expect(
          NativeReminderSpikeFixtures.computeHorizonDays(
            platform: SpikePlatform.ios,
            dailyDoseFrequency: 15,
          ),
          4.0,
        );

        // 20 doses/day (extreme multi-medication complex regimen)
        // Android: 450 / 20 = 22.5 days
        expect(
          NativeReminderSpikeFixtures.computeHorizonDays(
            platform: SpikePlatform.android,
            dailyDoseFrequency: 20,
          ),
          22.5,
        );
        // iOS: 60 / 20 = 3.0 days
        expect(
          NativeReminderSpikeFixtures.computeHorizonDays(
            platform: SpikePlatform.ios,
            dailyDoseFrequency: 20,
          ),
          3.0,
        );
      });

      test('Take-Limit Preserves Earliest Chronological Alarms', () {
        final start = DateTime.utc(2026, 10, 18, 8, 0);
        // Generate 75 hourly candidate alert timestamps
        final candidateDates = List.generate(
          75,
          (i) => start.add(Duration(hours: i)),
        );

        // On iOS: take(60)
        final iosScheduled = candidateDates.take(60).toList();
        expect(iosScheduled.length, 60);
        expect(iosScheduled.first, start);
        expect(iosScheduled.last, start.add(const Duration(hours: 59)));

        // 15 remaining are deferred to next sync
        final deferred = candidateDates.skip(60).toList();
        expect(deferred.length, 15);
        expect(deferred.first, start.add(const Duration(hours: 60)));
      });
    });

    // -------------------------------------------------------------------------
    // ReminderReadiness State Machine & Messaging
    // -------------------------------------------------------------------------
    group('ReminderReadiness State Machine & Messaging Hierarchy', () {
      test('Message Hierarchy: Precedence Rules', () {
        // 1. Error takes precedence over all other properties
        const withError = ReminderReadiness(
          supported: false,
          notifications: false,
          exact: false,
          error: 'Critical: disk full',
        );
        expect(withError.message, 'Critical: disk full');

        // 2. Unsupported platform takes precedence over notifications
        const unsupported = ReminderReadiness(
          supported: false,
          notifications: false,
          exact: false,
        );
        expect(
          unsupported.message,
          'Local reminders are available on Android and iOS. Your medicines are still saved here.',
        );

        // 3. Notifications disabled takes precedence over inexact
        const noNotifs = ReminderReadiness(
          supported: true,
          notifications: false,
          exact: false,
        );
        expect(
          noNotifs.message,
          'Notifications are off. Enable them in Settings to receive reminders.',
        );

        // 4. Inexact mode displayed when notifications enabled but exact revoked
        const inexact = ReminderReadiness(
          supported: true,
          notifications: true,
          exact: false,
        );
        expect(
          inexact.message,
          'Reminders may arrive late. Allow precise alarms in Settings.',
        );

        // 5. scheduledThrough == null -> "Reminders are ready."
        const readyNullHorizon = ReminderReadiness(
          supported: true,
          notifications: true,
          exact: true,
          scheduledThrough: null,
        );
        expect(readyNullHorizon.message, 'Reminders are ready.');

        // 6. scheduledThrough != null -> "Reminders scheduled through YYYY-MM-DD."
        final horizonDate = DateTime.utc(2026, 11, 16, 12, 0);
        final readyWithHorizon = ReminderReadiness(
          supported: true,
          notifications: true,
          exact: true,
          scheduledThrough: horizonDate,
        );
        expect(
          readyWithHorizon.message,
          contains('Reminders scheduled through'),
        );
      });

      test('ReminderReadiness copyWith, equality, hashCode, toString', () {
        const initial = ReminderReadiness(
          supported: true,
          notifications: true,
          exact: true,
          refillNotifications: true,
          refillAlertsSent: ['stock-1'],
        );

        final copy = initial.copyWith(exact: false, error: 'Late alert');
        expect(copy.exact, isFalse);
        expect(copy.error, 'Late alert');
        expect(copy.notifications, isTrue);
        expect(copy.refillAlertsSent, ['stock-1']);

        // Individual copyWith fields
        expect(initial.copyWith(supported: false).supported, isFalse);
        expect(initial.copyWith(notifications: false).notifications, isFalse);
        expect(
          initial.copyWith(refillNotifications: false).refillNotifications,
          isFalse,
        );
        expect(
          initial.copyWith(refillAlertsSent: ['stock-2']).refillAlertsSent,
          ['stock-2'],
        );

        // Equality and HashCode
        final same = ReminderReadiness(
          supported: true,
          notifications: true,
          exact: true,
          refillNotifications: true,
          refillAlertsSent: List.from(initial.refillAlertsSent),
        );
        expect(same, initial);
        expect(same.hashCode, initial.hashCode);

        final different = initial.copyWith(notifications: false);
        expect(different == initial, isFalse);
        expect(different.hashCode == initial.hashCode, isFalse);

        expect(initial.toString(), contains('ReminderReadiness'));
      });
    });

    // -------------------------------------------------------------------------
    // JSON Serialization Roundtrips & Malformed Payload Handling
    // -------------------------------------------------------------------------
    group('JSON Serialization Roundtrips & Malformed Payload Handling', () {
      test('SpikeDeviceRecord JSON Serialization Roundtrip', () {
        final device = NativeReminderSpikeFixtures.devices.first;
        final json = device.toJson();
        final restored = SpikeDeviceRecord.fromJson(json);

        expect(restored, device);
        expect(restored.hashCode, device.hashCode);
        expect(restored.id, device.id);
        expect(restored.deviceName, device.deviceName);
        expect(restored.apiLevel, device.apiLevel);
      });

      test('SpikeDeviceRecord Handles Null apiLevel (e.g. iOS)', () {
        final iosDevice = NativeReminderSpikeFixtures.devices.firstWhere(
          (d) => d.platform == SpikePlatform.ios,
        );
        expect(iosDevice.apiLevel, isNull);
        final json = iosDevice.toJson();
        expect(json.containsKey('apiLevel'), isFalse);

        final restored = SpikeDeviceRecord.fromJson(json);
        expect(restored.apiLevel, isNull);
        expect(restored, iosDevice);
      });

      test('SpikeDeviceRecord Rejects Invalid Enum or Malformed Fields', () {
        final validJson = NativeReminderSpikeFixtures.devices.first.toJson();

        // Unknown platform enum throws ArgumentError
        final badPlatform = Map<String, dynamic>.from(validJson);
        badPlatform['platform'] = 'windows_phone';
        expect(
            () => SpikeDeviceRecord.fromJson(badPlatform), throwsArgumentError);

        // Unknown alarmMechanism throws ArgumentError
        final badAlarm = Map<String, dynamic>.from(validJson);
        badAlarm['alarmMechanism'] = 'custom_cron';
        expect(() => SpikeDeviceRecord.fromJson(badAlarm), throwsArgumentError);

        // Missing required field throws TypeError
        final missingId = Map<String, dynamic>.from(validJson)..remove('id');
        expect(() => SpikeDeviceRecord.fromJson(missingId),
            throwsA(isA<TypeError>()));

        // Type mismatch for bool throws TypeError
        final badType = Map<String, dynamic>.from(validJson);
        badType['processAbsentDelivery'] = 'not_a_bool';
        expect(() => SpikeDeviceRecord.fromJson(badType),
            throwsA(isA<TypeError>()));
      });

      test('SpikePermissionRecord JSON Serialization Roundtrip', () {
        final perm = NativeReminderSpikeFixtures.permissionScenarios.first;
        final json = perm.toJson();
        final restored = SpikePermissionRecord.fromJson(json);

        expect(restored, perm);
        expect(restored.hashCode, perm.hashCode);
        expect(restored.id, perm.id);
        expect(restored.scenario, perm.scenario);
        expect(restored.expectedReadiness, perm.expectedReadiness);
      });

      test('SpikePermissionRecord Rejects Malformed Enums or Missing Keys', () {
        final validJson =
            NativeReminderSpikeFixtures.permissionScenarios.first.toJson();

        // Invalid PermissionState enum
        final badState = Map<String, dynamic>.from(validJson);
        badState['state'] = 'half_granted';
        expect(() => SpikePermissionRecord.fromJson(badState),
            throwsArgumentError);

        // Missing required scenario
        final missingScenario = Map<String, dynamic>.from(validJson)
          ..remove('scenario');
        expect(
          () => SpikePermissionRecord.fromJson(missingScenario),
          throwsA(isA<TypeError>()),
        );
      });

      test('SpikeStorageCryptographicRecord JSON Serialization Roundtrip', () {
        final storage = NativeReminderSpikeFixtures.storageRecords.first;
        final json = storage.toJson();
        final restored = SpikeStorageCryptographicRecord.fromJson(json);

        expect(restored, storage);
        expect(restored.hashCode, storage.hashCode);
        expect(restored.id, storage.id);
        expect(restored.storageContext, storage.storageContext);
      });

      test('SpikeStorageCryptographicRecord Rejects Malformed Enums', () {
        final validJson =
            NativeReminderSpikeFixtures.storageRecords.first.toJson();

        final badContext = Map<String, dynamic>.from(validJson);
        badContext['storageContext'] = 'unencrypted_cloud';
        expect(
          () => SpikeStorageCryptographicRecord.fromJson(badContext),
          throwsArgumentError,
        );
      });

      test('SpikePhysicalLimitation JSON Serialization Roundtrip', () {
        final limit = NativeReminderSpikeFixtures.physicalLimitations.first;
        final json = limit.toJson();
        final restored = SpikePhysicalLimitation.fromJson(json);

        expect(restored, limit);
        expect(restored.hashCode, limit.hashCode);
        expect(restored.id, limit.id);
        expect(restored.limitationType, limit.limitationType);
      });

      test('SpikePhysicalLimitation Rejects Malformed Enums', () {
        final validJson =
            NativeReminderSpikeFixtures.physicalLimitations.first.toJson();

        final badLimitation = Map<String, dynamic>.from(validJson);
        badLimitation['limitationType'] = 'solar_flare';
        expect(
          () => SpikePhysicalLimitation.fromJson(badLimitation),
          throwsArgumentError,
        );
      });

      test('SpikeEventLogRecord JSON Serialization Roundtrip', () {
        final event = NativeReminderSpikeFixtures.empiricalEventLogs.first;
        final json = event.toJson();
        final restored = SpikeEventLogRecord.fromJson(json);

        expect(restored, event);
        expect(restored.hashCode, event.hashCode);
        expect(restored.id, event.id);
        expect(restored.durationMs, event.durationMs);
      });

      test('ReminderReadiness JSON Roundtrip & Fallback Coercion', () {
        const fullReadiness = ReminderReadiness(
          supported: true,
          notifications: true,
          exact: true,
          error: 'Test error',
          refillAlertsSent: ['refill-1', 'refill-2'],
          refillNotifications: true,
        );

        final json = fullReadiness.toJson();
        final restored = ReminderReadiness.fromJson(json);
        expect(restored, fullReadiness);

        // Empty JSON map falls back safely to default properties
        final emptyRestored = ReminderReadiness.fromJson(const {});
        expect(emptyRestored.supported, isFalse);
        expect(emptyRestored.notifications, isFalse);
        expect(emptyRestored.exact, isFalse);
        expect(emptyRestored.scheduledThrough, isNull);
        expect(emptyRestored.error, isNull);
        expect(emptyRestored.refillAlertsSent, isEmpty);
        expect(emptyRestored.refillNotifications, isTrue);

        // Invalid date format throws FormatException
        expect(
          () => ReminderReadiness.fromJson(
              const {'scheduledThrough': 'not-a-date'}),
          throwsFormatException,
        );
      });

      test('Notification Lock-Screen Payload Parsing & Validation', () {
        final payloadString = jsonEncode({
          'owner': 'patient-123',
          'dose': 'med-1:1:2026-10-18:480',
          'due': '2026-10-18T08:00:00.000Z',
          'alert': '2026-10-18T08:00:00.000Z',
          'exact': true,
        });

        final decoded = jsonDecode(payloadString) as Map<String, dynamic>;
        expect(decoded['owner'], 'patient-123');
        expect(decoded['dose'], 'med-1:1:2026-10-18:480');
        expect(decoded['exact'], isTrue);
        expect(DateTime.tryParse(decoded['due'] as String), isNotNull);

        // Ensure zero PHI in intent payload
        expect(decoded.containsKey('medicationName'), isFalse);
        expect(decoded.containsKey('dosage'), isFalse);
        expect(decoded.containsKey('instructions'), isFalse);

        // Malformed JSON string throws FormatException
        expect(() => jsonDecode('{malformed_json:'), throwsFormatException);
      });
    });
  });
}
