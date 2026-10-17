// Evidence provenance: these typed fixtures are unverified sample material.
// They are not proof of interviews, competitor observations or device runs.
// See docs/EPICS-1-7-RESEARCH-AND-DEVICE-KIT.md for actual evidence requirements.
import 'package:flutter/foundation.dart';

import '../services/medicine_notifications.dart';

/// Target mobile operating system platform family.
enum SpikePlatform {
  android('Android'),
  ios('iOS');

  final String label;
  const SpikePlatform(this.label);
}

/// Verification status for empirical test scenarios.
enum VerificationStatus {
  pass('PASS'),
  fail('FAIL'),
  degraded('DEGRADED');

  final String code;
  const VerificationStatus(this.code);
}

/// Low-level native alarm mechanism utilized by the host operating system.
enum AlarmMechanism {
  /// Android AlarmManager RTC_WAKEUP with setExactAndAllowWhileIdle
  alarmManagerExact('AlarmManager.setExactAndAllowWhileIdle'),

  /// Android AlarmManager RTC_WAKEUP with setAndAllowWhileIdle (fallback)
  alarmManagerInexact('AlarmManager.setAndAllowWhileIdle'),

  /// Apple UNUserNotificationCenter with UNCalendarNotificationTrigger
  userNotificationCenter('UNUserNotificationCenter');

  final String apiCall;
  const AlarmMechanism(this.apiCall);
}

/// Operating system power management or low-power idle state.
enum IdleMode {
  /// Standard Android Doze maintenance window
  standardDoze('AOSP Standard Doze'),

  /// Deep Doze with network cutoff and suspended alarms
  deepDoze('AOSP Deep Doze (Idle-While-Screen-Off)'),

  /// Android App Standby Buckets (Rare / Restricted)
  appStandbyBucket('App Standby Bucket (Rare/Restricted)'),

  /// OEM-specific aggressive battery optimizer (One UI / HyperOS / PowerGenie)
  oemBatterySaver('OEM Custom Battery Saver'),

  /// iOS Low Power Mode and SpringBoard Focus Modes
  iosLowPowerMode('iOS Low Power Mode / Focus Summary');

  final String description;
  const IdleMode(this.description);
}

/// Runtime permission state hierarchy for notifications and exact alarms.
enum PermissionState {
  /// All notifications, channels, and exact alarms authorized
  fullyGranted('Fully Granted & Authorized'),

  /// POST_NOTIFICATIONS denied at runtime (Android 13+ / API 33+ or iOS)
  notificationsDenied('Notifications Denied'),

  /// SCHEDULE_EXACT_ALARM revoked or denied (Android 12+ / API 31+)
  exactAlarmRevoked('SCHEDULE_EXACT_ALARM Revoked'),

  /// Specific notification channel 'medicine_doses_v1' blocked (Importance.none)
  channelDosesBlocked('Dose Channel Disabled'),

  /// Specific notification channel 'medicine_refills_v1' blocked (Importance.none)
  channelRefillsBlocked('Refill Channel Disabled'),

  /// Both dose and refill notification channels disabled
  allChannelsBlocked('All App Channels Disabled');

  final String label;
  const PermissionState(this.label);
}

/// Android Direct Boot file-based encryption storage contexts.
enum DirectBootStorage {
  /// Credential-Protected storage (keys unlocked only AFU via user PIN/passcode)
  credentialProtected('Credential-Protected (CE) Storage'),

  /// Device-Protected storage (keys available BFU; tied only to device hardware)
  deviceProtected('Device-Protected (DE) Storage');

  final String description;
  const DirectBootStorage(this.description);
}

/// Unavoidable hardware or platform limitation classifications.
enum PhysicalLimitationType {
  /// Hardware is completely powered down (AP/CPU unpowered)
  poweredOff('Powered-Off Hardware'),

  /// User or OEM invoked Force-Stop (FLAG_EXCLUDE_STOPPED_PACKAGES)
  forceStopQuarantine('Force-Stop Quarantine'),

  /// Non-standard OEM task killing daemons
  aggressiveOemKiller('OEM Battery Killer Daemons'),

  /// Hard SpringBoard pending notification ceiling (64 items)
  springBoardQuotaExhaustion('iOS SpringBoard 64-Alarm Cap'),

  /// User manually shifted device clock backwards or forward
  clockTampering('Clock Manipulation / Daylight Saving Shift');

  final String title;
  const PhysicalLimitationType(this.title);
}

/// An empirical device and OS verification audit record.
class SpikeDeviceRecord {
  final String id;
  final String deviceName;
  final SpikePlatform platform;
  final String osVersion;
  final int? apiLevel;
  final String oemSkin;
  final AlarmMechanism alarmMechanism;
  final IdleMode idleModeTested;
  final bool processAbsentDelivery;
  final List<String> lockScreenActionsSupported;
  final bool rebootRecoverySupported;
  final int maxScheduledHorizon;
  final int averageRecoveryDurationMs;
  final VerificationStatus status;
  final String observations;

  const SpikeDeviceRecord({
    required this.id,
    required this.deviceName,
    required this.platform,
    required this.osVersion,
    this.apiLevel,
    required this.oemSkin,
    required this.alarmMechanism,
    required this.idleModeTested,
    required this.processAbsentDelivery,
    required this.lockScreenActionsSupported,
    required this.rebootRecoverySupported,
    required this.maxScheduledHorizon,
    required this.averageRecoveryDurationMs,
    required this.status,
    required this.observations,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'deviceName': deviceName,
        'platform': platform.name,
        'osVersion': osVersion,
        if (apiLevel != null) 'apiLevel': apiLevel,
        'oemSkin': oemSkin,
        'alarmMechanism': alarmMechanism.name,
        'idleModeTested': idleModeTested.name,
        'processAbsentDelivery': processAbsentDelivery,
        'lockScreenActionsSupported': lockScreenActionsSupported,
        'rebootRecoverySupported': rebootRecoverySupported,
        'maxScheduledHorizon': maxScheduledHorizon,
        'averageRecoveryDurationMs': averageRecoveryDurationMs,
        'status': status.name,
        'observations': observations,
      };

  factory SpikeDeviceRecord.fromJson(Map<String, dynamic> json) =>
      SpikeDeviceRecord(
        id: json['id'] as String,
        deviceName: json['deviceName'] as String,
        platform: SpikePlatform.values.byName(json['platform'] as String),
        osVersion: json['osVersion'] as String,
        apiLevel: json['apiLevel'] as int?,
        oemSkin: json['oemSkin'] as String,
        alarmMechanism:
            AlarmMechanism.values.byName(json['alarmMechanism'] as String),
        idleModeTested:
            IdleMode.values.byName(json['idleModeTested'] as String),
        processAbsentDelivery: json['processAbsentDelivery'] as bool,
        lockScreenActionsSupported:
            List<String>.from(json['lockScreenActionsSupported'] as List),
        rebootRecoverySupported: json['rebootRecoverySupported'] as bool,
        maxScheduledHorizon: json['maxScheduledHorizon'] as int,
        averageRecoveryDurationMs: json['averageRecoveryDurationMs'] as int,
        status: VerificationStatus.values.byName(json['status'] as String),
        observations: json['observations'] as String,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpikeDeviceRecord &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          deviceName == other.deviceName &&
          platform == other.platform &&
          osVersion == other.osVersion &&
          apiLevel == other.apiLevel &&
          oemSkin == other.oemSkin &&
          alarmMechanism == other.alarmMechanism &&
          idleModeTested == other.idleModeTested &&
          processAbsentDelivery == other.processAbsentDelivery &&
          rebootRecoverySupported == other.rebootRecoverySupported &&
          maxScheduledHorizon == other.maxScheduledHorizon &&
          averageRecoveryDurationMs == other.averageRecoveryDurationMs &&
          status == other.status &&
          observations == other.observations &&
          listEquals(
            lockScreenActionsSupported,
            other.lockScreenActionsSupported,
          );

  @override
  int get hashCode => Object.hash(
        id,
        deviceName,
        platform,
        osVersion,
        apiLevel,
        oemSkin,
        alarmMechanism,
        idleModeTested,
        processAbsentDelivery,
        rebootRecoverySupported,
        maxScheduledHorizon,
        averageRecoveryDurationMs,
        status,
        observations,
        Object.hashAll(lockScreenActionsSupported),
      );
}

/// An audit record for runtime permission states and graceful degradation.
class SpikePermissionRecord {
  final String id;
  final String scenario;
  final PermissionState state;
  final SpikePlatform targetPlatform;
  final int? targetApiLevel;
  final ReminderReadiness expectedReadiness;
  final String fallbackScheduleMode;
  final String honestUiMessage;
  final String deepLinkAction;
  final bool zeroCrashObserved;
  final String notes;

  const SpikePermissionRecord({
    required this.id,
    required this.scenario,
    required this.state,
    required this.targetPlatform,
    this.targetApiLevel,
    required this.expectedReadiness,
    required this.fallbackScheduleMode,
    required this.honestUiMessage,
    required this.deepLinkAction,
    required this.zeroCrashObserved,
    required this.notes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'scenario': scenario,
        'state': state.name,
        'targetPlatform': targetPlatform.name,
        if (targetApiLevel != null) 'targetApiLevel': targetApiLevel,
        'expectedReadiness': expectedReadiness.toJson(),
        'fallbackScheduleMode': fallbackScheduleMode,
        'honestUiMessage': honestUiMessage,
        'deepLinkAction': deepLinkAction,
        'zeroCrashObserved': zeroCrashObserved,
        'notes': notes,
      };

  factory SpikePermissionRecord.fromJson(Map<String, dynamic> json) =>
      SpikePermissionRecord(
        id: json['id'] as String,
        scenario: json['scenario'] as String,
        state: PermissionState.values.byName(json['state'] as String),
        targetPlatform:
            SpikePlatform.values.byName(json['targetPlatform'] as String),
        targetApiLevel: json['targetApiLevel'] as int?,
        expectedReadiness: ReminderReadiness.fromJson(
          json['expectedReadiness'] as Map<String, dynamic>,
        ),
        fallbackScheduleMode: json['fallbackScheduleMode'] as String,
        honestUiMessage: json['honestUiMessage'] as String,
        deepLinkAction: json['deepLinkAction'] as String,
        zeroCrashObserved: json['zeroCrashObserved'] as bool,
        notes: json['notes'] as String,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpikePermissionRecord &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          scenario == other.scenario &&
          state == other.state &&
          targetPlatform == other.targetPlatform &&
          targetApiLevel == other.targetApiLevel &&
          expectedReadiness == other.expectedReadiness &&
          fallbackScheduleMode == other.fallbackScheduleMode &&
          honestUiMessage == other.honestUiMessage &&
          deepLinkAction == other.deepLinkAction &&
          zeroCrashObserved == other.zeroCrashObserved &&
          notes == other.notes;

  @override
  int get hashCode => Object.hash(
        id,
        scenario,
        state,
        targetPlatform,
        targetApiLevel,
        expectedReadiness,
        fallbackScheduleMode,
        honestUiMessage,
        deepLinkAction,
        zeroCrashObserved,
        notes,
      );
}

/// An audit record evaluating storage encryption, KeyStore binding, and BFU safety.
class SpikeStorageCryptographicRecord {
  final String id;
  final DirectBootStorage storageContext;
  final SpikePlatform platform;
  final String keystoreProvider;
  final bool accessibilityBeforeFirstUnlock;
  final bool accessibilityAfterFirstUnlock;
  final bool phiExposedToLockScreen;
  final bool nonDestructiveKeyRecovery;
  final String securityComplianceRationale;

  const SpikeStorageCryptographicRecord({
    required this.id,
    required this.storageContext,
    required this.platform,
    required this.keystoreProvider,
    required this.accessibilityBeforeFirstUnlock,
    required this.accessibilityAfterFirstUnlock,
    required this.phiExposedToLockScreen,
    required this.nonDestructiveKeyRecovery,
    required this.securityComplianceRationale,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'storageContext': storageContext.name,
        'platform': platform.name,
        'keystoreProvider': keystoreProvider,
        'accessibilityBeforeFirstUnlock': accessibilityBeforeFirstUnlock,
        'accessibilityAfterFirstUnlock': accessibilityAfterFirstUnlock,
        'phiExposedToLockScreen': phiExposedToLockScreen,
        'nonDestructiveKeyRecovery': nonDestructiveKeyRecovery,
        'securityComplianceRationale': securityComplianceRationale,
      };

  factory SpikeStorageCryptographicRecord.fromJson(Map<String, dynamic> json) =>
      SpikeStorageCryptographicRecord(
        id: json['id'] as String,
        storageContext:
            DirectBootStorage.values.byName(json['storageContext'] as String),
        platform: SpikePlatform.values.byName(json['platform'] as String),
        keystoreProvider: json['keystoreProvider'] as String,
        accessibilityBeforeFirstUnlock:
            json['accessibilityBeforeFirstUnlock'] as bool,
        accessibilityAfterFirstUnlock:
            json['accessibilityAfterFirstUnlock'] as bool,
        phiExposedToLockScreen: json['phiExposedToLockScreen'] as bool,
        nonDestructiveKeyRecovery: json['nonDestructiveKeyRecovery'] as bool,
        securityComplianceRationale:
            json['securityComplianceRationale'] as String,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpikeStorageCryptographicRecord &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          storageContext == other.storageContext &&
          platform == other.platform &&
          keystoreProvider == other.keystoreProvider &&
          accessibilityBeforeFirstUnlock ==
              other.accessibilityBeforeFirstUnlock &&
          accessibilityAfterFirstUnlock ==
              other.accessibilityAfterFirstUnlock &&
          phiExposedToLockScreen == other.phiExposedToLockScreen &&
          nonDestructiveKeyRecovery == other.nonDestructiveKeyRecovery &&
          securityComplianceRationale == other.securityComplianceRationale;

  @override
  int get hashCode => Object.hash(
        id,
        storageContext,
        platform,
        keystoreProvider,
        accessibilityBeforeFirstUnlock,
        accessibilityAfterFirstUnlock,
        phiExposedToLockScreen,
        nonDestructiveKeyRecovery,
        securityComplianceRationale,
      );
}

/// An audit record defining a hard physical or platform platform boundary.
class SpikePhysicalLimitation {
  final String id;
  final PhysicalLimitationType limitationType;
  final SpikePlatform platform;
  final String title;
  final String osMechanism;
  final bool canDeliverReminders;
  final String recoveryTrigger;
  final String patientSafetyAdvice;

  const SpikePhysicalLimitation({
    required this.id,
    required this.limitationType,
    required this.platform,
    required this.title,
    required this.osMechanism,
    required this.canDeliverReminders,
    required this.recoveryTrigger,
    required this.patientSafetyAdvice,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'limitationType': limitationType.name,
        'platform': platform.name,
        'title': title,
        'osMechanism': osMechanism,
        'canDeliverReminders': canDeliverReminders,
        'recoveryTrigger': recoveryTrigger,
        'patientSafetyAdvice': patientSafetyAdvice,
      };

  factory SpikePhysicalLimitation.fromJson(Map<String, dynamic> json) =>
      SpikePhysicalLimitation(
        id: json['id'] as String,
        limitationType: PhysicalLimitationType.values.byName(
          json['limitationType'] as String,
        ),
        platform: SpikePlatform.values.byName(json['platform'] as String),
        title: json['title'] as String,
        osMechanism: json['osMechanism'] as String,
        canDeliverReminders: json['canDeliverReminders'] as bool,
        recoveryTrigger: json['recoveryTrigger'] as String,
        patientSafetyAdvice: json['patientSafetyAdvice'] as String,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpikePhysicalLimitation &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          limitationType == other.limitationType &&
          platform == other.platform &&
          title == other.title &&
          osMechanism == other.osMechanism &&
          canDeliverReminders == other.canDeliverReminders &&
          recoveryTrigger == other.recoveryTrigger &&
          patientSafetyAdvice == other.patientSafetyAdvice;

  @override
  int get hashCode => Object.hash(
        id,
        limitationType,
        platform,
        title,
        osMechanism,
        canDeliverReminders,
        recoveryTrigger,
        patientSafetyAdvice,
      );
}

/// A logged empirical event record from native recovery harness execution.
class SpikeEventLogRecord {
  final String id;
  final String event;
  final String trigger;
  final String workerResult;
  final int durationMs;
  final List<String> verifiedAssertions;
  final bool generationIncremented;

  const SpikeEventLogRecord({
    required this.id,
    required this.event,
    required this.trigger,
    required this.workerResult,
    required this.durationMs,
    required this.verifiedAssertions,
    required this.generationIncremented,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'event': event,
        'trigger': trigger,
        'workerResult': workerResult,
        'durationMs': durationMs,
        'verifiedAssertions': verifiedAssertions,
        'generationIncremented': generationIncremented,
      };

  factory SpikeEventLogRecord.fromJson(Map<String, dynamic> json) =>
      SpikeEventLogRecord(
        id: json['id'] as String,
        event: json['event'] as String,
        trigger: json['trigger'] as String,
        workerResult: json['workerResult'] as String,
        durationMs: json['durationMs'] as int,
        verifiedAssertions: List<String>.from(
          json['verifiedAssertions'] as List,
        ),
        generationIncremented: json['generationIncremented'] as bool,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpikeEventLogRecord &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          event == other.event &&
          trigger == other.trigger &&
          workerResult == other.workerResult &&
          durationMs == other.durationMs &&
          generationIncremented == other.generationIncremented &&
          listEquals(verifiedAssertions, other.verifiedAssertions);

  @override
  int get hashCode => Object.hash(
        id,
        event,
        trigger,
        workerResult,
        durationMs,
        generationIncremented,
        Object.hashAll(verifiedAssertions),
      );
}

/// Static datasets, device audit matrices, and empirical verification fixtures
/// for the MED-005 Native Reminder Feasibility spike.
class NativeReminderSpikeFixtures {
  const NativeReminderSpikeFixtures._();

  /// Audited physical and emulated device matrix covering Android API 26-35 and iOS 15-18.
  static final List<SpikeDeviceRecord> devices = [
    const SpikeDeviceRecord(
      id: 'DEV-01',
      deviceName: 'Google Pixel 9 Pro',
      platform: SpikePlatform.android,
      osVersion: 'Android 15 (API 35)',
      apiLevel: 35,
      oemSkin: 'Stock Android (AOSP)',
      alarmMechanism: AlarmMechanism.alarmManagerExact,
      idleModeTested: IdleMode.deepDoze,
      processAbsentDelivery: true,
      lockScreenActionsSupported: ['Taken', 'Snooze 15 min'],
      rebootRecoverySupported: true,
      maxScheduledHorizon: 450,
      averageRecoveryDurationMs: 1420,
      status: VerificationStatus.pass,
      observations:
          '16KB memory page compliant. Impeller OpenGLES backend. Headless WorkManager rebuilds 450 alarms in ~1.4s.',
    ),
    const SpikeDeviceRecord(
      id: 'DEV-02',
      deviceName: 'Samsung Galaxy S24 Ultra',
      platform: SpikePlatform.android,
      osVersion: 'Android 14 (API 34)',
      apiLevel: 34,
      oemSkin: 'Samsung One UI 6.1',
      alarmMechanism: AlarmMechanism.alarmManagerExact,
      idleModeTested: IdleMode.oemBatterySaver,
      processAbsentDelivery: true,
      lockScreenActionsSupported: ['Taken', 'Snooze 15 min'],
      rebootRecoverySupported: true,
      maxScheduledHorizon: 450,
      averageRecoveryDurationMs: 1680,
      status: VerificationStatus.pass,
      observations:
          'Survives standard Device Care battery management. If placed into Deep Sleeping Apps, AlarmManager exact alarms still fire, but WorkManager requires whitelist.',
    ),
    const SpikeDeviceRecord(
      id: 'DEV-03',
      deviceName: 'Xiaomi 14 Pro',
      platform: SpikePlatform.android,
      osVersion: 'Android 14 (API 34)',
      apiLevel: 34,
      oemSkin: 'Xiaomi HyperOS 1.0',
      alarmMechanism: AlarmMechanism.alarmManagerExact,
      idleModeTested: IdleMode.oemBatterySaver,
      processAbsentDelivery: true,
      lockScreenActionsSupported: ['Taken', 'Snooze 15 min'],
      rebootRecoverySupported: true,
      maxScheduledHorizon: 450,
      averageRecoveryDurationMs: 1840,
      status: VerificationStatus.pass,
      observations:
          'Requires user to enable "Autostart" in HyperOS settings for BOOT_COMPLETED delivery. In-app settings bridge guides user.',
    ),
    const SpikeDeviceRecord(
      id: 'DEV-04',
      deviceName: 'OnePlus 12',
      platform: SpikePlatform.android,
      osVersion: 'Android 14 (API 34)',
      apiLevel: 34,
      oemSkin: 'OxygenOS 14',
      alarmMechanism: AlarmMechanism.alarmManagerExact,
      idleModeTested: IdleMode.appStandbyBucket,
      processAbsentDelivery: true,
      lockScreenActionsSupported: ['Taken', 'Snooze 15 min'],
      rebootRecoverySupported: true,
      maxScheduledHorizon: 450,
      averageRecoveryDurationMs: 1510,
      status: VerificationStatus.pass,
      observations:
          'Broadcasts received consistently across App Standby Rare bucket. Exact alarms fire without delay.',
    ),
    const SpikeDeviceRecord(
      id: 'DEV-05',
      deviceName: 'Google Pixel 6',
      platform: SpikePlatform.android,
      osVersion: 'Android 13 (API 33)',
      apiLevel: 33,
      oemSkin: 'Stock Android',
      alarmMechanism: AlarmMechanism.alarmManagerExact,
      idleModeTested: IdleMode.deepDoze,
      processAbsentDelivery: true,
      lockScreenActionsSupported: ['Taken', 'Snooze 15 min'],
      rebootRecoverySupported: true,
      maxScheduledHorizon: 450,
      averageRecoveryDurationMs: 1390,
      status: VerificationStatus.pass,
      observations:
          'POST_NOTIFICATIONS runtime permission handled gracefully. Exact alarm permissions granted by default on API 33.',
    ),
    const SpikeDeviceRecord(
      id: 'DEV-06',
      deviceName: 'Google Pixel 4',
      platform: SpikePlatform.android,
      osVersion: 'Android 8.1 (API 27)',
      apiLevel: 27,
      oemSkin: 'Stock Android Oreo',
      alarmMechanism: AlarmMechanism.alarmManagerExact,
      idleModeTested: IdleMode.standardDoze,
      processAbsentDelivery: true,
      lockScreenActionsSupported: ['Taken', 'Snooze 15 min'],
      rebootRecoverySupported: true,
      maxScheduledHorizon: 450,
      averageRecoveryDurationMs: 1980,
      status: VerificationStatus.pass,
      observations:
          'Notification channels (medicine_doses_v1, medicine_refills_v1) create valid heads-up notifications. Baseline Android minimum version.',
    ),
    const SpikeDeviceRecord(
      id: 'DEV-07',
      deviceName: 'Apple iPhone 16 Pro',
      platform: SpikePlatform.ios,
      osVersion: 'iOS 18.0',
      oemSkin: 'Apple SpringBoard',
      alarmMechanism: AlarmMechanism.userNotificationCenter,
      idleModeTested: IdleMode.iosLowPowerMode,
      processAbsentDelivery: true,
      lockScreenActionsSupported: ['Taken', 'Snooze 15 min'],
      rebootRecoverySupported: true,
      maxScheduledHorizon: 60,
      averageRecoveryDurationMs: 450,
      status: VerificationStatus.pass,
      observations:
          'SpringBoard retains 60 pending UNNotificationRequest across reboot even before first unlock. Foreground actions invoke AppDelegate successfully.',
    ),
    const SpikeDeviceRecord(
      id: 'DEV-08',
      deviceName: 'Apple iPhone 13',
      platform: SpikePlatform.ios,
      osVersion: 'iOS 15.6',
      oemSkin: 'Apple SpringBoard',
      alarmMechanism: AlarmMechanism.userNotificationCenter,
      idleModeTested: IdleMode.iosLowPowerMode,
      processAbsentDelivery: true,
      lockScreenActionsSupported: ['Taken', 'Snooze 15 min'],
      rebootRecoverySupported: true,
      maxScheduledHorizon: 60,
      averageRecoveryDurationMs: 510,
      status: VerificationStatus.pass,
      observations:
          'Notification categories "dose" render interactive action buttons cleanly on lock screen. Bounded strictly to 60 slots.',
    ),
  ];

  /// Audited permission state lifecycle scenarios demonstrating truthful degradation and zero crashes.
  static final List<SpikePermissionRecord> permissionScenarios = [
    const SpikePermissionRecord(
      id: 'PERM-01',
      scenario: 'Full Authorization (Ideal Baseline)',
      state: PermissionState.fullyGranted,
      targetPlatform: SpikePlatform.android,
      targetApiLevel: 35,
      expectedReadiness: ReminderReadiness(
        supported: true,
        notifications: true,
        exact: true,
        refillNotifications: true,
      ),
      fallbackScheduleMode: 'exactAllowWhileIdle',
      honestUiMessage: 'Reminders scheduled through 2026-11-16.',
      deepLinkAction: 'openNotificationSettings',
      zeroCrashObserved: true,
      notes:
          'Exact RTC hardware alarms armed; visual heads-up banners enabled; low stock notifications active.',
    ),
    const SpikePermissionRecord(
      id: 'PERM-02',
      scenario: 'POST_NOTIFICATIONS Denied at Runtime (Android 13+)',
      state: PermissionState.notificationsDenied,
      targetPlatform: SpikePlatform.android,
      targetApiLevel: 33,
      expectedReadiness: ReminderReadiness(
        supported: true,
        notifications: false,
        exact: true,
        refillNotifications: false,
      ),
      fallbackScheduleMode: 'cancelled',
      honestUiMessage:
          'Notifications are off. Enable them in Settings to receive reminders.',
      deepLinkAction: 'openNotificationSettings',
      zeroCrashObserved: true,
      notes:
          'Pending alarms cancelled immediately to avoid phantom battery drain. UI surfaces settings deep link button.',
    ),
    const SpikePermissionRecord(
      id: 'PERM-03',
      scenario: 'SCHEDULE_EXACT_ALARM Revoked by User or System (Android 14+)',
      state: PermissionState.exactAlarmRevoked,
      targetPlatform: SpikePlatform.android,
      targetApiLevel: 34,
      expectedReadiness: ReminderReadiness(
        supported: true,
        notifications: true,
        exact: false,
        refillNotifications: true,
      ),
      fallbackScheduleMode: 'inexactAllowWhileIdle',
      honestUiMessage:
          'Reminders may arrive late. Allow precise alarms in Settings.',
      deepLinkAction: 'openNotificationSettings',
      zeroCrashObserved: true,
      notes:
          'Automated fallback to setAndAllowWhileIdle prevents SecurityException crash. Honest warning displayed.',
    ),
    const SpikePermissionRecord(
      id: 'PERM-04',
      scenario: 'Dose Notification Channel Disabled (Importance.none)',
      state: PermissionState.channelDosesBlocked,
      targetPlatform: SpikePlatform.android,
      targetApiLevel: 26,
      expectedReadiness: ReminderReadiness(
        supported: true,
        notifications: false,
        exact: true,
        refillNotifications: true,
      ),
      fallbackScheduleMode: 'cancelled',
      honestUiMessage:
          'Notifications are off. Enable them in Settings to receive reminders.',
      deepLinkAction: 'openNotificationSettings',
      zeroCrashObserved: true,
      notes:
          'Detected via getNotificationChannels inspection. Dose alarms cancelled; refill alerts remain enabled.',
    ),
    const SpikePermissionRecord(
      id: 'PERM-05',
      scenario: 'Refill Notification Channel Disabled (Importance.none)',
      state: PermissionState.channelRefillsBlocked,
      targetPlatform: SpikePlatform.android,
      targetApiLevel: 26,
      expectedReadiness: ReminderReadiness(
        supported: true,
        notifications: true,
        exact: true,
        refillNotifications: false,
      ),
      fallbackScheduleMode: 'exactAllowWhileIdle',
      honestUiMessage: 'Reminders scheduled through 2026-11-16.',
      deepLinkAction: 'openNotificationSettings',
      zeroCrashObserved: true,
      notes:
          'Dose reminders continue scheduling with exact precision; refill alerts suppressed without unacknowledged episode drift.',
    ),
    const SpikePermissionRecord(
      id: 'PERM-06',
      scenario: 'All Notification Channels Disabled by User',
      state: PermissionState.allChannelsBlocked,
      targetPlatform: SpikePlatform.android,
      targetApiLevel: 26,
      expectedReadiness: ReminderReadiness(
        supported: true,
        notifications: false,
        exact: true,
        refillNotifications: false,
      ),
      fallbackScheduleMode: 'cancelled',
      honestUiMessage:
          'Notifications are off. Enable them in Settings to receive reminders.',
      deepLinkAction: 'openNotificationSettings',
      zeroCrashObserved: true,
      notes:
          'All alarms purged from system server. Clear settings prompt presented on Today screen.',
    ),
  ];

  /// Audited storage and cryptographic key accessibility boundaries.
  static final List<SpikeStorageCryptographicRecord> storageRecords = [
    const SpikeStorageCryptographicRecord(
      id: 'SEC-01',
      storageContext: DirectBootStorage.credentialProtected,
      platform: SpikePlatform.android,
      keystoreProvider: 'Android KeyStore (TEE / StrongBox)',
      accessibilityBeforeFirstUnlock: false,
      accessibilityAfterFirstUnlock: true,
      phiExposedToLockScreen: false,
      nonDestructiveKeyRecovery: true,
      securityComplianceRationale:
          'ADOPTED: CE storage binds encryption key to user passcode + TEE. Direct Boot BFU access is rejected to prevent forensic extraction of sensitive health data.',
    ),
    const SpikeStorageCryptographicRecord(
      id: 'SEC-02',
      storageContext: DirectBootStorage.deviceProtected,
      platform: SpikePlatform.android,
      keystoreProvider: 'Device Hardware TEE Only',
      accessibilityBeforeFirstUnlock: true,
      accessibilityAfterFirstUnlock: true,
      phiExposedToLockScreen: false,
      nonDestructiveKeyRecovery: true,
      securityComplianceRationale:
          'REJECTED: DE storage exposes SQLite database to physical extraction tools (Cellebrite) without user passcode, violating HIPAA/GDPR clinical privacy baseline.',
    ),
    const SpikeStorageCryptographicRecord(
      id: 'SEC-03',
      storageContext: DirectBootStorage.credentialProtected,
      platform: SpikePlatform.ios,
      keystoreProvider: 'Apple Keychain (Secure Enclave)',
      accessibilityBeforeFirstUnlock: false,
      accessibilityAfterFirstUnlock: true,
      phiExposedToLockScreen: false,
      nonDestructiveKeyRecovery: true,
      securityComplianceRationale:
          'ADOPTED: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly ensures encryption keys cannot be read from locked device dumps or transferred to other devices via iCloud.',
    ),
  ];

  /// Hard physical and platform limitation boundaries documented for clinical safety.
  static final List<SpikePhysicalLimitation> physicalLimitations = [
    const SpikePhysicalLimitation(
      id: 'LIM-01',
      limitationType: PhysicalLimitationType.poweredOff,
      platform: SpikePlatform.android,
      title: 'Powered-Off Hardware Reality',
      osMechanism:
          'AP and CPU powered down; third-party apps have zero public access to RTC power-on registers.',
      canDeliverReminders: false,
      recoveryTrigger:
          'BOOT_COMPLETED receiver execution upon user power-on and first unlock.',
      patientSafetyAdvice:
          'Advise patient to keep phone charged and maintain secondary physical pillbox backup.',
    ),
    const SpikePhysicalLimitation(
      id: 'LIM-02',
      limitationType: PhysicalLimitationType.forceStopQuarantine,
      platform: SpikePlatform.android,
      title: 'Force-Stop Quarantine Barrier',
      osMechanism:
          'OS sets pkg.stopped=true; attaches Intent.FLAG_EXCLUDE_STOPPED_PACKAGES to all broadcasts; cancels all AlarmManager alarms.',
      canDeliverReminders: false,
      recoveryTrigger: 'Explicit manual application launch by user.',
      patientSafetyAdvice:
          'Never swipe app from Settings > Force Stop. App surfaces explanatory warning dialog.',
    ),
    const SpikePhysicalLimitation(
      id: 'LIM-03',
      limitationType: PhysicalLimitationType.aggressiveOemKiller,
      platform: SpikePlatform.android,
      title: 'OEM Task Killer Daemons',
      osMechanism:
          'Vendor daemons (Samsung Smart Manager, Xiaomi MIUI Battery Saver) suppress background broadcasts and freeze processes.',
      canDeliverReminders: true,
      recoveryTrigger:
          'In-app guidance directs user to disable battery optimizations and toggle Autostart.',
      patientSafetyAdvice:
          'Follow manufacturer-specific battery exemption steps presented in Today view settings.',
    ),
    const SpikePhysicalLimitation(
      id: 'LIM-04',
      limitationType: PhysicalLimitationType.springBoardQuotaExhaustion,
      platform: SpikePlatform.ios,
      title: 'iOS 64-Alarm Ceiling Boundary',
      osMechanism:
          'SpringBoard caps total pending notifications at 64 across the application bundle.',
      canDeliverReminders: true,
      recoveryTrigger:
          'User opens application periodically to replenish future alarms.',
      patientSafetyAdvice:
          'Open the app at least once every 14-30 days to extend the reminder scheduling horizon.',
    ),
    const SpikePhysicalLimitation(
      id: 'LIM-05',
      limitationType: PhysicalLimitationType.clockTampering,
      platform: SpikePlatform.android,
      title: 'Clock Manipulation / Daylight Saving Shift',
      osMechanism:
          'Manual system clock adjustments or DST transitions alter delta between wall clock and monotonic uptime.',
      canDeliverReminders: true,
      recoveryTrigger:
          'ACTION_TIME_CHANGED / ACTION_TIMEZONE_CHANGED triggers WorkManager headless alarm repair.',
      patientSafetyAdvice:
          'System automatically repairs schedule without re-triggering taken doses or inventing missed events.',
    ),
  ];

  /// Empirical verification events logged during automated harness runs.
  static final List<SpikeEventLogRecord> empiricalEventLogs = [
    const SpikeEventLogRecord(
      id: 'EVT-01',
      event: 'TIMEZONE_CHANGED',
      trigger: 'Europe/London <-> America/New_York (cmd alarm set-timezone)',
      workerResult: 'SUCCESS',
      durationMs: 1223,
      verifiedAssertions: [
        'Worker result SUCCESS for dev.fluttercommunity.workmanager.BackgroundWorker',
        'Alarms shifted to match wall-clock time anchor',
        '0 duplicate alarm IDs generated',
        'Confirmed dose history completely unchanged',
      ],
      generationIncremented: true,
    ),
    const SpikeEventLogRecord(
      id: 'EVT-02',
      event: 'TIME_SET (Clock Forward)',
      trigger: '+7,200,000 ms manual clock adjustment (cmd alarm set-time)',
      workerResult: 'SUCCESS',
      durationMs: 1012,
      verifiedAssertions: [
        'Elapsed-vs-wall-clock drift detected (>120s threshold)',
        'Past alarms pruned cleanly',
        'Future alarms rescheduled with fresh timestamps',
        'Zero dose confirmations lost',
      ],
      generationIncremented: true,
    ),
    const SpikeEventLogRecord(
      id: 'EVT-03',
      event: 'TIME_SET (Clock Backward)',
      trigger: '-7,200,000 ms manual clock revert (cmd alarm set-time)',
      workerResult: 'SUCCESS',
      durationMs: 1145,
      verifiedAssertions: [
        'Negative wall-clock shift detected',
        'No re-triggering of already taken doses',
        'Stock balance unchanged (95000 units)',
        'Idempotent alarm IDs preserved',
      ],
      generationIncremented: true,
    ),
    const SpikeEventLogRecord(
      id: 'EVT-04',
      event: 'MY_PACKAGE_REPLACED',
      trigger: 'install -r -t recovery-system-fixture.apk (OTA simulation)',
      workerResult: 'SUCCESS',
      durationMs: 1438,
      verifiedAssertions: [
        'Receiver traps MY_PACKAGE_REPLACED broadcast',
        'Headless FlutterEngine boots in background',
        'SQLCipher schema v3 validated',
        'Active plans restored; paused and archived remain muted',
      ],
      generationIncremented: true,
    ),
    const SpikeEventLogRecord(
      id: 'EVT-05',
      event: 'BOOT_COMPLETED',
      trigger: 'adb reboot completed (sys.boot_completed=1)',
      workerResult: 'SUCCESS',
      durationMs: 1811,
      verifiedAssertions: [
        'Receiver traps BOOT_COMPLETED broadcast',
        'WorkManager enqueues medicine-system-recovery with backoff',
        'Generation incremented in shared_prefs/medicine_recovery.xml',
        'All 450 future alarms restored into AlarmManager RTC_WAKEUP',
      ],
      generationIncremented: true,
    ),
  ];

  /// Filter audited devices by platform.
  static List<SpikeDeviceRecord> devicesByPlatform(SpikePlatform platform) =>
      devices.where((d) => d.platform == platform).toList();

  /// Filter audited devices by verification status.
  static List<SpikeDeviceRecord> devicesByStatus(VerificationStatus status) =>
      devices.where((d) => d.status == status).toList();

  /// Verify that all permission scenarios maintain zero crashes.
  static bool get allZeroCrash =>
      permissionScenarios.every((p) => p.zeroCrashObserved);

  /// Verify that all storage architectures guarantee non-destructive recovery.
  static bool get allNonDestructive =>
      storageRecords.every((s) => s.nonDestructiveKeyRecovery);

  /// Total count of audited devices.
  static int get deviceCount => devices.length;

  /// Overall pass rate across audited devices.
  static double get passRate =>
      devices.where((d) => d.status == VerificationStatus.pass).length /
      devices.length *
      100.0;

  /// Computes the alarm scheduling ceiling for a given platform.
  static int maxAlarmsForPlatform(SpikePlatform platform) =>
      platform == SpikePlatform.android ? 450 : 60;

  /// SpringBoard hard system ceiling for iOS pending notifications.
  static const int iosSpringBoardCeiling = 64;

  /// Safety headroom reserved on iOS for refill notices and snoozes.
  static const int iosSafetyHeadroom = 4;

  /// Computes the effective scheduled horizon in days given daily dose frequency.
  static double computeHorizonDays({
    required SpikePlatform platform,
    required int dailyDoseFrequency,
    int maxLookaheadDays = 30,
  }) {
    if (dailyDoseFrequency <= 0) return 0.0;
    final platformLimit = maxAlarmsForPlatform(platform);
    final daysToLimit = platformLimit / dailyDoseFrequency;
    return daysToLimit < maxLookaheadDays
        ? daysToLimit
        : maxLookaheadDays.toDouble();
  }

  /// Calculates the number of alarms that will be scheduled given candidate count and platform.
  static int calculateScheduledAlarms({
    required SpikePlatform platform,
    required int candidateCount,
  }) {
    if (candidateCount <= 0) return 0;
    final limit = maxAlarmsForPlatform(platform);
    return candidateCount < limit ? candidateCount : limit;
  }
}
