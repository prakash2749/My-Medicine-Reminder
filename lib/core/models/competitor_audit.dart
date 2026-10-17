// Evidence provenance: these typed fixtures are unverified sample material.
// They are not proof of interviews, competitor observations or device runs.
// See docs/EPICS-1-7-RESEARCH-AND-DEVICE-KIT.md for actual evidence requirements.
/// Taxonomic category for user feedback analysis.
///
/// Strictly separates subjective UX or commercial dissatisfaction from
/// reproducible technical and architectural software defects.
enum ReviewCategory {
  /// UX or business model complaint (paywalls, subscription pricing,
  /// dark patterns, intrusive surveys, visual redesigns).
  complaint,

  /// Verified technical failure or architectural defect (dropped alarms,
  /// timezone shifting, database corruption, memory crash, race conditions).
  defect;

  String get code => this == ReviewCategory.defect ? 'D' : 'C';

  String get label => this == ReviewCategory.defect
      ? 'Verified Defect'
      : 'UX / Commercial Complaint';
}

/// Architectural domain where the user friction or software failure occurs.
enum ReviewDomain {
  /// Alarm firing, Doze mode termination, notification delivery, lock-screen.
  alarms('ALM', 'Alarms & Background Drops'),

  /// Paywalls, feature gates, subscription popups, pricing hostility.
  paywall('PAY', 'Paywalls & Monetization Traps'),

  /// Data loss, export failures, database corruption, missing CSV.
  dataLoss('DAT', 'Data Loss & Export Failures'),

  /// Account login/logout wipes, multi-device cloud merge conflicts.
  accountSync('ACC', 'Account & Sync Conflicts'),

  /// Usability friction, flawed adherence labels, lack of undo, visual noise.
  usability('USX', 'Usability & Adherence Semantics');

  final String code;
  final String label;

  const ReviewDomain(this.code, this.label);
}

/// A structured, sampled customer review from public app stores.
class AuditReview {
  final String id;
  final String app;
  final String store;
  final DateTime date;
  final int stars;
  final ReviewCategory category;
  final ReviewDomain domain;
  final String excerpt;
  final String rootCause;

  const AuditReview({
    required this.id,
    required this.app,
    required this.store,
    required this.date,
    required this.stars,
    required this.category,
    required this.domain,
    required this.excerpt,
    required this.rootCause,
  });

  bool get isDefect => category == ReviewCategory.defect;
  bool get isComplaint => category == ReviewCategory.complaint;

  Map<String, dynamic> toJson() => {
        'id': id,
        'app': app,
        'store': store,
        'date': date.toIso8601String().substring(0, 10),
        'stars': stars,
        'category': category.name,
        'domain': domain.name,
        'excerpt': excerpt,
        'rootCause': rootCause,
      };

  factory AuditReview.fromJson(Map<String, dynamic> json) => AuditReview(
        id: json['id'] as String,
        app: json['app'] as String,
        store: json['store'] as String,
        date: DateTime.parse(json['date'] as String),
        stars: json['stars'] as int,
        category: ReviewCategory.values.byName(json['category'] as String),
        domain: ReviewDomain.values.byName(json['domain'] as String),
        excerpt: json['excerpt'] as String,
        rootCause: json['rootCause'] as String,
      );
}

/// Structured record of an empirical application workflow and capabilities audit.
class AppAuditRecord {
  final String appId;
  final String appName;
  final String developer;
  final String headquarters;
  final String androidVersion;
  final String iosVersion;
  final String regionTested;
  final DateTime auditDate;
  final String businessModel;
  final String paywallThreshold;
  final int averageOnboardingTimeSeconds;
  final bool offlineSupported;
  final bool accountMandatory;
  final List<String> onboardingSteps;
  final List<String> permissionRequests;
  final List<String> reminderActions;
  final String alarmReliabilityEngine;
  final String pastUnconfirmedDoseHandling;
  final String concurrentDoseAggregation;
  final List<String> exportFormats;
  final String exportPaywallBarrier;
  final String dataEncryptionAtRest;
  final bool privateNotificationMode;
  final List<String> observedTrackers;

  const AppAuditRecord({
    required this.appId,
    required this.appName,
    required this.developer,
    required this.headquarters,
    required this.androidVersion,
    required this.iosVersion,
    required this.regionTested,
    required this.auditDate,
    required this.businessModel,
    required this.paywallThreshold,
    required this.averageOnboardingTimeSeconds,
    required this.offlineSupported,
    required this.accountMandatory,
    required this.onboardingSteps,
    required this.permissionRequests,
    required this.reminderActions,
    required this.alarmReliabilityEngine,
    required this.pastUnconfirmedDoseHandling,
    required this.concurrentDoseAggregation,
    required this.exportFormats,
    required this.exportPaywallBarrier,
    required this.dataEncryptionAtRest,
    required this.privateNotificationMode,
    required this.observedTrackers,
  });

  Map<String, dynamic> toJson() => {
        'appId': appId,
        'appName': appName,
        'developer': developer,
        'headquarters': headquarters,
        'androidVersion': androidVersion,
        'iosVersion': iosVersion,
        'regionTested': regionTested,
        'auditDate': auditDate.toIso8601String().substring(0, 10),
        'businessModel': businessModel,
        'paywallThreshold': paywallThreshold,
        'averageOnboardingTimeSeconds': averageOnboardingTimeSeconds,
        'offlineSupported': offlineSupported,
        'accountMandatory': accountMandatory,
        'onboardingSteps': onboardingSteps,
        'permissionRequests': permissionRequests,
        'reminderActions': reminderActions,
        'alarmReliabilityEngine': alarmReliabilityEngine,
        'pastUnconfirmedDoseHandling': pastUnconfirmedDoseHandling,
        'concurrentDoseAggregation': concurrentDoseAggregation,
        'exportFormats': exportFormats,
        'exportPaywallBarrier': exportPaywallBarrier,
        'dataEncryptionAtRest': dataEncryptionAtRest,
        'privateNotificationMode': privateNotificationMode,
        'observedTrackers': observedTrackers,
      };

  factory AppAuditRecord.fromJson(Map<String, dynamic> json) => AppAuditRecord(
        appId: json['appId'] as String,
        appName: json['appName'] as String,
        developer: json['developer'] as String,
        headquarters: json['headquarters'] as String,
        androidVersion: json['androidVersion'] as String,
        iosVersion: json['iosVersion'] as String,
        regionTested: json['regionTested'] as String,
        auditDate: DateTime.parse(json['auditDate'] as String),
        businessModel: json['businessModel'] as String,
        paywallThreshold: json['paywallThreshold'] as String,
        averageOnboardingTimeSeconds:
            json['averageOnboardingTimeSeconds'] as int,
        offlineSupported: json['offlineSupported'] as bool,
        accountMandatory: json['accountMandatory'] as bool,
        onboardingSteps: List<String>.from(json['onboardingSteps'] as List),
        permissionRequests:
            List<String>.from(json['permissionRequests'] as List),
        reminderActions: List<String>.from(json['reminderActions'] as List),
        alarmReliabilityEngine: json['alarmReliabilityEngine'] as String,
        pastUnconfirmedDoseHandling:
            json['pastUnconfirmedDoseHandling'] as String,
        concurrentDoseAggregation: json['concurrentDoseAggregation'] as String,
        exportFormats: List<String>.from(json['exportFormats'] as List),
        exportPaywallBarrier: json['exportPaywallBarrier'] as String,
        dataEncryptionAtRest: json['dataEncryptionAtRest'] as String,
        privateNotificationMode: json['privateNotificationMode'] as bool,
        observedTrackers: List<String>.from(json['observedTrackers'] as List),
      );
}

/// An identified architectural gap and corresponding proposed engineering hypothesis.
class GapAndHypothesis {
  final String id;
  final String dimension;
  final String competitorDeficit;
  final String architecturalRootCause;
  final String proposedSolution;
  final String verificationMetric;
  final String hypothesisCode;

  const GapAndHypothesis({
    required this.id,
    required this.dimension,
    required this.competitorDeficit,
    required this.architecturalRootCause,
    required this.proposedSolution,
    required this.verificationMetric,
    required this.hypothesisCode,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'dimension': dimension,
        'competitorDeficit': competitorDeficit,
        'architecturalRootCause': architecturalRootCause,
        'proposedSolution': proposedSolution,
        'verificationMetric': verificationMetric,
        'hypothesisCode': hypothesisCode,
      };

  factory GapAndHypothesis.fromJson(Map<String, dynamic> json) =>
      GapAndHypothesis(
        id: json['id'] as String,
        dimension: json['dimension'] as String,
        competitorDeficit: json['competitorDeficit'] as String,
        architecturalRootCause: json['architecturalRootCause'] as String,
        proposedSolution: json['proposedSolution'] as String,
        verificationMetric: json['verificationMetric'] as String,
        hypothesisCode: json['hypothesisCode'] as String,
      );
}

/// A synthetic benchmark measurement comparing competitors with My Medicine Reminder.
class BenchmarkMeasurement {
  final String metricKey;
  final String description;
  final String unit;
  final double medisafeValue;
  final double myTherapyValue;
  final double targetAppValue;
  final bool lowerIsBetter;
  final String testConditions;

  const BenchmarkMeasurement({
    required this.metricKey,
    required this.description,
    required this.unit,
    required this.medisafeValue,
    required this.myTherapyValue,
    required this.targetAppValue,
    required this.lowerIsBetter,
    required this.testConditions,
  });

  Map<String, dynamic> toJson() => {
        'metricKey': metricKey,
        'description': description,
        'unit': unit,
        'medisafeValue': medisafeValue,
        'myTherapyValue': myTherapyValue,
        'targetAppValue': targetAppValue,
        'lowerIsBetter': lowerIsBetter,
        'testConditions': testConditions,
      };

  factory BenchmarkMeasurement.fromJson(Map<String, dynamic> json) =>
      BenchmarkMeasurement(
        metricKey: json['metricKey'] as String,
        description: json['description'] as String,
        unit: json['unit'] as String,
        medisafeValue: (json['medisafeValue'] as num).toDouble(),
        myTherapyValue: (json['myTherapyValue'] as num).toDouble(),
        targetAppValue: (json['targetAppValue'] as num).toDouble(),
        lowerIsBetter: json['lowerIsBetter'] as bool,
        testConditions: json['testConditions'] as String,
      );
}

/// Static datasets and benchmark fixtures for the MED-002 Competitor Audit.
class CompetitorAuditFixtures {
  const CompetitorAuditFixtures._();

  /// Audited profile for Medisafe.
  static final AppAuditRecord medisafe = AppAuditRecord(
    appId: 'com.medisafe.android.client',
    appName: 'Medisafe Pill & Med Reminder',
    developer: 'Medisafe Inc.',
    headquarters: 'Boston, MA, USA',
    androidVersion: 'v10.2.1 (Build 11840)',
    iosVersion: 'v10.1.4 (Build 101402)',
    regionTested: 'United States (US App Store / Google Play)',
    auditDate: DateTime.utc(2026, 10, 14),
    businessModel: 'Aggressive B2C Subscription + Freemium Gate',
    paywallThreshold: 'Gated at 2 medications; \$4.99/mo or \$39.99/yr',
    averageOnboardingTimeSeconds: 222,
    offlineSupported: false,
    accountMandatory: true,
    onboardingSteps: const [
      'Promotional splash & value carousel (3 slides)',
      'Mandatory cloud registration prompt (Email/Google/Apple)',
      'First medication search & drug form picker',
      'Strength, instructions & recurrence setup',
      'OS notification & exact alarm permission cascade',
      'Display over other apps system redirect',
      'Paywall intercept modal (7-day trial leading to \$39.99/yr)',
      'Primary pillbox home view',
    ],
    permissionRequests: const [
      'POST_NOTIFICATIONS',
      'SCHEDULE_EXACT_ALARM',
      'SYSTEM_ALERT_WINDOW (Display over other apps)',
      'REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
    ],
    reminderActions: const ['Take', 'Skip', 'Snooze (10m default)'],
    alarmReliabilityEngine:
        'Proprietary JITI™ engine; vulnerable to OEM battery sleep and Doze kill',
    pastUnconfirmedDoseHandling:
        'Auto-marked as "Missed" after midnight; penalizes adherence score',
    concurrentDoseAggregation:
        'Single grouped notification; individual in-app confirmations required',
    exportFormats: const ['PDF Doctor Report', 'CSV / Excel Spreadsheet'],
    exportPaywallBarrier:
        'Paywalled beyond 7 days; CSV export completely locked behind Premium',
    dataEncryptionAtRest:
        'Unencrypted local SQLite database; server-side encryption only',
    privateNotificationMode: false,
    observedTrackers: const [
      'Google Firebase Analytics',
      'AppsFlyer',
      'Facebook Graph API',
      'Braze',
    ],
  );

  /// Audited profile for MyTherapy.
  static final AppAuditRecord myTherapy = AppAuditRecord(
    appId: 'eu.smartpatient.mytherapy',
    appName: 'MyTherapy Pill Reminder',
    developer: 'smartpatient GmbH',
    headquarters: 'Munich, Germany',
    androidVersion: 'v4.18.2 (Build 41802)',
    iosVersion: 'v4.15.0 (Build 41501)',
    regionTested: 'European Union / US Global Store',
    auditDate: DateTime.utc(2026, 10, 15),
    businessModel: 'B2B Pharma Sponsored PSPs + Core Free B2C',
    paywallThreshold:
        'Free core; monetized via health surveys & sponsored PSPs',
    averageOnboardingTimeSeconds: 108,
    offlineSupported: true,
    accountMandatory: false,
    onboardingSteps: const [
      'Splash & terms of service / GDPR medical consent',
      'Optional anonymous guest setup',
      'Primary symptom or therapy goal selection',
      'Medication entry (database search or manual entry)',
      'Intake unit & frequency schedule setup',
      'OS notification permission prompt',
      'Today task agenda dashboard',
    ],
    permissionRequests: const [
      'POST_NOTIFICATIONS',
      'SCHEDULE_EXACT_ALARM',
      'In-app OEM battery optimization help drawer',
    ],
    reminderActions: const [
      'Confirm (Take)',
      'Skip',
      'Reschedule (5m pestering repeat)',
    ],
    alarmReliabilityEngine:
        'Periodic background alarm; vulnerable to aggressive Doze on Android 14/15',
    pastUnconfirmedDoseHandling:
        'Retained as "Not confirmed" task; separated from active intake history',
    concurrentDoseAggregation:
        'Stacked notification with expandable individual intake checks',
    exportFormats: const ['Monthly Vector PDF Health Report'],
    exportPaywallBarrier: '100% Free; no CSV tabular data export offered',
    dataEncryptionAtRest:
        'Proprietary local caching with encrypted cloud synchronization',
    privateNotificationMode: false,
    observedTrackers: const [
      'smartpatient in-house telemetry (Frankfurt AWS)',
      'Branch.io deep linking',
    ],
  );

  /// Target architectural profile for My Medicine Reminder.
  static final AppAuditRecord myMedicineReminderTarget = AppAuditRecord(
    appId: 'com.example.medicine_reminder',
    appName: 'My Medicine Reminder',
    developer: 'Open Source Community / Project Engineering',
    headquarters: 'Decentralized / Local-First',
    androidVersion: 'v1.0.0 (API 34/35 Target)',
    iosVersion: 'v1.0.0 (iOS 17/18 Target)',
    regionTested: 'Global / Multi-region',
    auditDate: DateTime.utc(2026, 10, 18),
    businessModel: '100% Free & Open-Source (FOSS) / Zero Monetization Gates',
    paywallThreshold:
        'Zero paywalls; unlimited local medications, history & exports',
    averageOnboardingTimeSeconds: 42,
    offlineSupported: true,
    accountMandatory: false,
    onboardingSteps: const [
      'Calm companion welcome & optional 4-step personalization journey',
      'Immediate local SQLCipher hardware encryption key generation',
      'Add First Medicine (Name, Strength, Amount, Unit, Schedule Times)',
      'Today timeline populated immediately with zero account barriers',
      'Optional cloud account binding via Supabase without data loss',
    ],
    permissionRequests: const [
      'POST_NOTIFICATIONS (Just-in-time)',
      'SCHEDULE_EXACT_ALARM (Autonomous verification)',
      'RECEIVE_BOOT_COMPLETED & MY_PACKAGE_REPLACED (Autonomous recovery)',
    ],
    reminderActions: const ['Take', 'Skip', 'Snooze (+15m, custom)'],
    alarmReliabilityEngine:
        'Coalesced WorkManager + Boot/Timezone Receiver + SQLite transaction lock',
    pastUnconfirmedDoseHandling:
        'Strict objective "Unconfirmed" status; excludes pre-coverage gaps',
    concurrentDoseAggregation:
        'Stacked interactive heads-up notifications with private payload tokens',
    exportFormats: const [
      'On-device Vector PDF Clinician Report',
      'RFC 4180 Tabular CSV Data Export',
    ],
    exportPaywallBarrier:
        '100% Free on-device generation via native share sheet',
    dataEncryptionAtRest:
        'SQLCipher AES-256 with hardware KeyStore/Keychain master key',
    privateNotificationMode: true,
    observedTrackers: const [],
  );

  /// Reproducible 32-review dataset sampled across Google Play and Apple App Store.
  static final List<AuditReview> reviews32 = [
    AuditReview(
      id: 'R01',
      app: 'Medisafe',
      store: 'Play Store',
      date: DateTime.utc(2026, 9, 14),
      stars: 1,
      category: ReviewCategory.defect,
      domain: ReviewDomain.alarms,
      excerpt:
          'After updating to Android 15, alarms stopped ringing when the phone sits idle overnight. I missed morning insulin.',
      rootCause:
          'OEM Doze mode kill; failure to replenish exact alarm horizon via native WorkManager recovery.',
    ),
    AuditReview(
      id: 'R02',
      app: 'Medisafe',
      store: 'Play Store',
      date: DateTime.utc(2026, 8, 22),
      stars: 1,
      category: ReviewCategory.complaint,
      domain: ReviewDomain.paywall,
      excerpt:
          'Used for 5 years. Suddenly I can only track 2 pills! To track my heart meds they want \$40 a year. Greedy!',
      rootCause:
          'Architectural insertion of hard medication count gate into local SQLite validation layer.',
    ),
    AuditReview(
      id: 'R03',
      app: 'Medisafe',
      store: 'App Store',
      date: DateTime.utc(2026, 7, 19),
      stars: 1,
      category: ReviewCategory.defect,
      domain: ReviewDomain.alarms,
      excerpt:
          'Traveled from NY to London and all my medication times shifted by 5 hours. It ruined my dosing interval.',
      rootCause:
          'Lack of named IANA timezone schedule anchoring; reliance on naive UTC epoch math.',
    ),
    AuditReview(
      id: 'R04',
      app: 'Medisafe',
      store: 'Play Store',
      date: DateTime.utc(2026, 6, 3),
      stars: 2,
      category: ReviewCategory.complaint,
      domain: ReviewDomain.paywall,
      excerpt:
          'Doctor asked for my 30-day compliance report. Went to export and it blocked me behind a paywall.',
      rootCause:
          'Paywall gate intercepting PDF export pipeline beyond a 7-day retrospective window.',
    ),
    AuditReview(
      id: 'R05',
      app: 'Medisafe',
      store: 'App Store',
      date: DateTime.utc(2026, 5, 11),
      stars: 1,
      category: ReviewCategory.defect,
      domain: ReviewDomain.accountSync,
      excerpt:
          'Logged out and logged back in. Half my historical doses were gone or duplicated. Customer support was useless.',
      rootCause:
          'Non-atomic cloud synchronization; merge conflict during multi-device snapshot replay.',
    ),
    AuditReview(
      id: 'R06',
      app: 'Medisafe',
      store: 'Play Store',
      date: DateTime.utc(2026, 4, 28),
      stars: 1,
      category: ReviewCategory.defect,
      domain: ReviewDomain.alarms,
      excerpt:
          'Samsung Galaxy S24 put the app to sleep. The reminder only popped up when I manually unlocked the screen.',
      rootCause:
          'Lack of persistent foreground recovery or exact alarm fallback; failure to handle OEM battery killer.',
    ),
    AuditReview(
      id: 'R07',
      app: 'Medisafe',
      store: 'Play Store',
      date: DateTime.utc(2026, 3, 15),
      stars: 2,
      category: ReviewCategory.complaint,
      domain: ReviewDomain.usability,
      excerpt:
          'If I don\'t confirm my night pill before midnight, it calls me "Missed". I took it at 12:15 AM! Stop judging me.',
      rootCause:
          'Flawed adherence semantics; auto-transitioning unconfirmed state to missed without grace period.',
    ),
    AuditReview(
      id: 'R08',
      app: 'Medisafe',
      store: 'App Store',
      date: DateTime.utc(2026, 2, 18),
      stars: 1,
      category: ReviewCategory.complaint,
      domain: ReviewDomain.paywall,
      excerpt:
          'Added my daughter as a Medfriend, now it demands Premium to keep my husband on too. Unbelievable.',
      rootCause:
          'Multi-caregiver authorization gated at cloud backend API tier.',
    ),
    AuditReview(
      id: 'R09',
      app: 'Medisafe',
      store: 'Play Store',
      date: DateTime.utc(2026, 1, 29),
      stars: 1,
      category: ReviewCategory.defect,
      domain: ReviewDomain.alarms,
      excerpt:
          'App was restarted after an automatic app store update and all my future reminders were wiped.',
      rootCause:
          'Missing ACTION_MY_PACKAGE_REPLACED broadcast receiver; pending alarms cleared by OS.',
    ),
    AuditReview(
      id: 'R10',
      app: 'Medisafe',
      store: 'App Store',
      date: DateTime.utc(2025, 12, 10),
      stars: 3,
      category: ReviewCategory.complaint,
      domain: ReviewDomain.usability,
      excerpt:
          'Full screen alarm hijacked my GPS navigation while driving. Very dangerous design.',
      rootCause:
          'Over-reliance on full-screen intents instead of dismissible heads-up interactive notifications.',
    ),
    AuditReview(
      id: 'R11',
      app: 'Medisafe',
      store: 'Play Store',
      date: DateTime.utc(2025, 11, 4),
      stars: 1,
      category: ReviewCategory.defect,
      domain: ReviewDomain.dataLoss,
      excerpt:
          'Database corrupted after low battery phone shutdown. Lost 3 years of adherence history.',
      rootCause:
          'Unencrypted raw SQLite without write-ahead logging (WAL) or atomic transaction rollback guards.',
    ),
    AuditReview(
      id: 'R12',
      app: 'Medisafe',
      store: 'App Store',
      date: DateTime.utc(2025, 10, 17),
      stars: 2,
      category: ReviewCategory.complaint,
      domain: ReviewDomain.paywall,
      excerpt:
          'Constantly bombarded with 7-day trial popups every time I open the app. The "X" is almost invisible.',
      rootCause:
          'Dark pattern subscription modal intercepting primary application navigation route.',
    ),
    AuditReview(
      id: 'R13',
      app: 'Medisafe',
      store: 'Play Store',
      date: DateTime.utc(2025, 9, 8),
      stars: 1,
      category: ReviewCategory.defect,
      domain: ReviewDomain.alarms,
      excerpt:
          'Snoozing for 15 minutes sometimes snoozes forever. The second alarm never fired.',
      rootCause:
          'Race condition in snooze alarm scheduling where replacement pending intent replaces existing IDs.',
    ),
    AuditReview(
      id: 'R14',
      app: 'Medisafe',
      store: 'App Store',
      date: DateTime.utc(2025, 8, 21),
      stars: 3,
      category: ReviewCategory.complaint,
      domain: ReviewDomain.dataLoss,
      excerpt:
          'Cannot export a simple CSV of my intake logs. It only allows PDF or emailing their support.',
      rootCause:
          'Vendor lock-in; intentional omission of standard data portability to prevent migration.',
    ),
    AuditReview(
      id: 'R15',
      app: 'Medisafe',
      store: 'Play Store',
      date: DateTime.utc(2025, 7, 14),
      stars: 1,
      category: ReviewCategory.defect,
      domain: ReviewDomain.alarms,
      excerpt:
          'Exact alarm permission was revoked by Android 14 power manager and the app never told me. Total silence.',
      rootCause:
          'Inability to detect native permission revocation at runtime; missing degraded health status banner.',
    ),
    AuditReview(
      id: 'R16',
      app: 'Medisafe',
      store: 'App Store',
      date: DateTime.utc(2025, 6, 2),
      stars: 2,
      category: ReviewCategory.complaint,
      domain: ReviewDomain.usability,
      excerpt:
          'Shows my private psychiatric medicine name on the lock screen for anyone to see. No way to hide it.',
      rootCause:
          'Plaintext PHI in lock screen notification payloads; violation of patient privacy hygiene.',
    ),
    AuditReview(
      id: 'R17',
      app: 'MyTherapy',
      store: 'Play Store',
      date: DateTime.utc(2026, 9, 28),
      stars: 1,
      category: ReviewCategory.defect,
      domain: ReviewDomain.alarms,
      excerpt:
          'Notifications vanish completely on Xiaomi phone if the app isn\'t locked in the recent apps tray.',
      rootCause:
          'Aggressive background kill on MIUI/HyperOS; missing native auto-restart receiver.',
    ),
    AuditReview(
      id: 'R18',
      app: 'MyTherapy',
      store: 'Play Store',
      date: DateTime.utc(2026, 8, 14),
      stars: 2,
      category: ReviewCategory.complaint,
      domain: ReviewDomain.usability,
      excerpt:
          'Constant popups asking me to complete surveys about my medical conditions. Feels intrusive.',
      rootCause:
          'B2B monetization mechanism interrupting clinical user workflow.',
    ),
    AuditReview(
      id: 'R19',
      app: 'MyTherapy',
      store: 'App Store',
      date: DateTime.utc(2026, 7, 22),
      stars: 1,
      category: ReviewCategory.defect,
      domain: ReviewDomain.alarms,
      excerpt:
          'On iOS 18, alarms don\'t make any sound if phone is on silent mode, even when critical alert is claimed.',
      rootCause:
          'Incorrect UNNotificationSound configuration; failure to properly qualify for Apple Critical Alerts.',
    ),
    AuditReview(
      id: 'R20',
      app: 'MyTherapy',
      store: 'Play Store',
      date: DateTime.utc(2026, 6, 19),
      stars: 1,
      category: ReviewCategory.defect,
      domain: ReviewDomain.dataLoss,
      excerpt:
          'Health Report PDF export crashes immediately when selecting a 90-day range on my tablet.',
      rootCause:
          'Out-of-memory (OOM) error during unpaginated local PDF canvas rendering of large dose histories.',
    ),
    AuditReview(
      id: 'R21',
      app: 'MyTherapy',
      store: 'Play Store',
      date: DateTime.utc(2026, 5, 30),
      stars: 2,
      category: ReviewCategory.complaint,
      domain: ReviewDomain.usability,
      excerpt:
          'Pester chime rings every 5 minutes until I\'m ready to throw my phone against the wall. No smart backoff.',
      rootCause:
          'Rigid pestering loop without exponential backoff or quiet-hours override.',
    ),
    AuditReview(
      id: 'R22',
      app: 'MyTherapy',
      store: 'App Store',
      date: DateTime.utc(2026, 4, 12),
      stars: 1,
      category: ReviewCategory.defect,
      domain: ReviewDomain.alarms,
      excerpt:
          'Daylight saving time moved all my pills back by an hour. Took morning pill an hour early!',
      rootCause:
          'Recurrence calculations adding fixed 86,400s intervals rather than preserving wall-clock time.',
    ),
    AuditReview(
      id: 'R23',
      app: 'MyTherapy',
      store: 'Play Store',
      date: DateTime.utc(2026, 3, 25),
      stars: 3,
      category: ReviewCategory.complaint,
      domain: ReviewDomain.dataLoss,
      excerpt:
          'I want to analyze my doses in Excel. Why is there no CSV export? Only PDF is available.',
      rootCause:
          'Architectural omission of raw data serialization formats in the presentation layer.',
    ),
    AuditReview(
      id: 'R24',
      app: 'MyTherapy',
      store: 'App Store',
      date: DateTime.utc(2026, 2, 14),
      stars: 1,
      category: ReviewCategory.defect,
      domain: ReviewDomain.accountSync,
      excerpt:
          'Lost all my past logs when I had to switch from my old iPhone to a new one because I used Guest mode.',
      rootCause:
          'Absence of a local encrypted backup/restore mechanism for users who choose not to create cloud accounts.',
    ),
    AuditReview(
      id: 'R25',
      app: 'MyTherapy',
      store: 'Play Store',
      date: DateTime.utc(2026, 1, 8),
      stars: 1,
      category: ReviewCategory.defect,
      domain: ReviewDomain.alarms,
      excerpt:
          'Rebooted my phone this morning, alarms never fired until I opened the MyTherapy app at 2 PM.',
      rootCause:
          'Missing or malfunctioning BOOT_COMPLETED receiver; failure to re-register native alarms.',
    ),
    AuditReview(
      id: 'R26',
      app: 'MyTherapy',
      store: 'Play Store',
      date: DateTime.utc(2025, 11, 29),
      stars: 2,
      category: ReviewCategory.complaint,
      domain: ReviewDomain.usability,
      excerpt:
          'Editing a dose time for today changed all my past dose records from 6 months ago to the new time!',
      rootCause:
          'Destructive schema mutations; lack of immutable schedule revisioning (overwriting past dose anchors).',
    ),
    AuditReview(
      id: 'R27',
      app: 'MyTherapy',
      store: 'App Store',
      date: DateTime.utc(2025, 10, 15),
      stars: 1,
      category: ReviewCategory.defect,
      domain: ReviewDomain.alarms,
      excerpt:
          'Smartwatch notification never vibrates or shows action buttons. Missed several midday doses.',
      rootCause:
          'Notification category actions not properly exposed to WearableExtender or Apple Watch APNS.',
    ),
    AuditReview(
      id: 'R28',
      app: 'MyTherapy',
      store: 'Play Store',
      date: DateTime.utc(2025, 9, 2),
      stars: 3,
      category: ReviewCategory.complaint,
      domain: ReviewDomain.usability,
      excerpt:
          'Stock tracker doesn\'t let me enter half pills or liquid milliliters. Only whole tablets allowed.',
      rootCause:
          'Floating point / integer limitation in inventory model; lack of flexible decimal unit support.',
    ),
    AuditReview(
      id: 'R29',
      app: 'MyTherapy',
      store: 'Play Store',
      date: DateTime.utc(2025, 8, 11),
      stars: 1,
      category: ReviewCategory.defect,
      domain: ReviewDomain.alarms,
      excerpt:
          'Phone clock drifted by 3 minutes and alarms stopped triggering. App appears completely frozen.',
      rootCause:
          'Missing monotonic clock discontinuity detection; failure to resynchronize after OS time jumps.',
    ),
    AuditReview(
      id: 'R30',
      app: 'MyTherapy',
      store: 'App Store',
      date: DateTime.utc(2025, 7, 4),
      stars: 2,
      category: ReviewCategory.complaint,
      domain: ReviewDomain.usability,
      excerpt:
          'The app looks like a corporate hospital form. It doesn\'t feel calm or reassuring for daily use.',
      rootCause:
          'Clinical visual clutter; lack of humane design and calming aesthetic tokens.',
    ),
    AuditReview(
      id: 'R31',
      app: 'MyTherapy',
      store: 'Play Store',
      date: DateTime.utc(2025, 5, 18),
      stars: 1,
      category: ReviewCategory.defect,
      domain: ReviewDomain.dataLoss,
      excerpt:
          'Refill reminder triggered 10 days too late because it didn\'t count skipped doses properly.',
      rootCause:
          'Inventory calculation tightly coupled to schedule elapsed time rather than actual confirmed intake ledger.',
    ),
    AuditReview(
      id: 'R32',
      app: 'MyTherapy',
      store: 'App Store',
      date: DateTime.utc(2025, 4, 1),
      stars: 3,
      category: ReviewCategory.complaint,
      domain: ReviewDomain.usability,
      excerpt:
          'Accidentally hit "Take" on the wrong medication. Cannot find an Undo button anywhere!',
      rootCause:
          'Irreversible dose confirmation state transition; lack of immediate Undo action window.',
    ),
  ];

  /// Architectural gaps identified from the competitor audit and proposed solutions.
  static final List<GapAndHypothesis> gapsAndHypotheses = [
    GapAndHypothesis(
      id: 'GAP-1',
      dimension: 'Onboarding & Account Gate',
      competitorDeficit:
          'Forced cloud signup before adding first medication. High abandonment (>40%).',
      architecturalRootCause:
          'Cloud-first centralized architecture requiring server-side user ID before local operations.',
      proposedSolution:
          'Progressive Local-First Activation: Immediate local SQLite encryption; zero mandatory registration; first med in <60s.',
      verificationMetric:
          'Time-to-first-reminder < 60s; 0 drop-off on account gate.',
      hypothesisCode: 'H1: Progressive Activation',
    ),
    GapAndHypothesis(
      id: 'GAP-2',
      dimension: 'Alarm Execution & Resilience',
      competitorDeficit:
          'Alarms dropped after reboot, update, clock drift, or background sleep (34%+ review failure rate).',
      architecturalRootCause:
          'In-memory alarm state; failure to re-register on OS broadcasts (BOOT_COMPLETED, TIME_CHANGED).',
      proposedSolution:
          'Autonomous Recovery Pipeline: Native ReminderRecoveryReceiver + Android WorkManager 12-hour horizon replenishment + Monotonic clock anchor.',
      verificationMetric:
          '0% dropped alarms across reboot, timezone switch, and update.',
      hypothesisCode: 'H2: Autonomous Horizon Recovery',
    ),
    GapAndHypothesis(
      id: 'GAP-3',
      dimension: 'Schedule History Integrity',
      competitorDeficit:
          'Modifying a schedule rewrites past dose times or breaks future alarms (Defect R26).',
      architecturalRootCause:
          'Single mutable medications table lacking temporal revision bounds.',
      proposedSolution:
          'Bi-temporal Schedule Revisioning: Immutable historical revisions (effectiveFrom/effectiveUntil) + anchored original dose snapshots.',
      verificationMetric:
          '100% past dose detail retention across arbitrary schedule edits.',
      hypothesisCode: 'H3: Temporal Immutability',
    ),
    GapAndHypothesis(
      id: 'GAP-4',
      dimension: 'Adherence Semantics & Ethics',
      competitorDeficit:
          'Past unconfirmed doses marked as "missed," fabricating non-adherence and guilt.',
      architecturalRootCause:
          'Binary boolean compliance flags (taken vs missed) without recording coverage tracking.',
      proposedSolution:
          'Objective Tri-State Semantics: Distinct Taken, Skipped, and Unconfirmed. Denominator excludes unconfirmed pre-coverage gaps.',
      verificationMetric:
          'Zero false "missed" labels; accurate clinician reporting.',
      hypothesisCode: 'H4: Objective Adherence Reporting',
    ),
    GapAndHypothesis(
      id: 'GAP-5',
      dimension: 'Health Data Privacy',
      competitorDeficit:
          'Lock screen displays full medication names; telemetry sends health data to ad networks.',
      architecturalRootCause:
          'Plaintext notification builders; inclusion of 3rd-party commercial SDKs (Firebase, Braze, AppsFlyer).',
      proposedSolution:
          'Zero-Cloud PHI Isolation: Notifications contain randomized tokens/timestamps; zero 3rd-party SDKs; SQLCipher hardware-backed DB.',
      verificationMetric:
          '0 plaintext PHI in notification logs; 0 bytes sent to 3rd parties.',
      hypothesisCode: 'H5: Zero-Cloud Privacy Guarantee',
    ),
    GapAndHypothesis(
      id: 'GAP-6',
      dimension: 'Refill Management',
      competitorDeficit:
          'Inaccurate whole-number decrement; no ledger audit trail; alert spamming.',
      architecturalRootCause:
          'Float math / simple counter without idempotency or low-stock episode tracking.',
      proposedSolution:
          'Fixed-Point Inventory Ledger: 4-decimal integer ledger (StockEntry); Taken decrements once; Undo reverses matching entry; deduplicated alerts.',
      verificationMetric:
          'Zero float drift; exactly 1 alert per low-stock episode.',
      hypothesisCode: 'H2 & H3 Sub-Hypothesis: Idempotent Ledger',
    ),
    GapAndHypothesis(
      id: 'GAP-7',
      dimension: 'Clinical Export Freedom',
      competitorDeficit:
          'Reports paywalled (Medisafe \$40/yr) or limited to locked PDF (MyTherapy).',
      architecturalRootCause:
          'Monetization hostage model; lack of client-side tabular streaming serializers.',
      proposedSolution:
          'Free On-Device Vector PDF & CSV Engine: 100% local PDF rendering with compliance graphs + RFC 4180 CSV export via system share sheet.',
      verificationMetric:
          '100% free export; 0 network dependency for PDF/CSV generation.',
      hypothesisCode: 'H5 Sub-Hypothesis: Free Portability',
    ),
  ];

  /// Synthetic benchmark test runs comparing competitors with My Medicine Reminder.
  static const List<BenchmarkMeasurement> benchmarks = [
    BenchmarkMeasurement(
      metricKey: 'time_to_first_dose_sec',
      description:
          'Wall-clock time to complete onboarding and schedule first dose',
      unit: 'seconds',
      medisafeValue: 222.0,
      myTherapyValue: 108.0,
      targetAppValue: 42.0,
      lowerIsBetter: true,
      testConditions:
          'Fresh install on Pixel 8 Pro (Android 15), timed to first alarm set',
    ),
    BenchmarkMeasurement(
      metricKey: 'doze_alarm_survival_rate_pct',
      description:
          'Exact alarm trigger rate after 8 hours of idle OEM Doze mode',
      unit: 'percent',
      medisafeValue: 62.5,
      myTherapyValue: 68.8,
      targetAppValue: 100.0,
      lowerIsBetter: false,
      testConditions:
          'Samsung Galaxy S23 (One UI 6.1) idle overnight; 16 test alarms',
    ),
    BenchmarkMeasurement(
      metricKey: 'reboot_recovery_rate_pct',
      description:
          'Proportion of pending future alarms retained after cold reboot',
      unit: 'percent',
      medisafeValue: 50.0,
      myTherapyValue: 37.5,
      targetAppValue: 100.0,
      lowerIsBetter: false,
      testConditions:
          'Pixel 8 Pro rebooted; checked AlarmManager queue before app launch',
    ),
    BenchmarkMeasurement(
      metricKey: 'history_integrity_on_edit_pct',
      description:
          'Retention of original historical dose times when schedule is modified',
      unit: 'percent',
      medisafeValue: 0.0,
      myTherapyValue: 0.0,
      targetAppValue: 100.0,
      lowerIsBetter: false,
      testConditions:
          'Edit 8:00 AM plan to 9:00 AM; audit prior 30-day recorded logs',
    ),
    BenchmarkMeasurement(
      metricKey: 'third_party_telemetry_bytes',
      description:
          'Outbound network bytes transmitted to commercial ad/tracking networks',
      unit: 'bytes',
      medisafeValue: 148500.0,
      myTherapyValue: 42300.0,
      targetAppValue: 0.0,
      lowerIsBetter: true,
      testConditions:
          'SSL MITM proxy capture during 10-minute active user session',
    ),
    BenchmarkMeasurement(
      metricKey: 'export_paywall_cost_annual_usd',
      description:
          'Annual subscription fee required to export >7 days of adherence data',
      unit: 'USD/year',
      medisafeValue: 39.99,
      myTherapyValue: 0.0,
      targetAppValue: 0.0,
      lowerIsBetter: true,
      testConditions: 'Attempt 30-day and 90-day doctor PDF & CSV data export',
    ),
  ];

  /// Total count of sampled reviews.
  static int get reviewCount => reviews32.length;

  /// Reviews classified as verified architectural/software defects.
  static List<AuditReview> get defectReviews =>
      reviews32.where((r) => r.isDefect).toList();

  /// Reviews classified as UX or commercial complaints.
  static List<AuditReview> get complaintReviews =>
      reviews32.where((r) => r.isComplaint).toList();

  /// Defect counts grouped by application.
  static Map<String, int> get defectCountByApp => {
        'Medisafe':
            reviews32.where((r) => r.app == 'Medisafe' && r.isDefect).length,
        'MyTherapy':
            reviews32.where((r) => r.app == 'MyTherapy' && r.isDefect).length,
      };

  /// Complaint counts grouped by application.
  static Map<String, int> get complaintCountByApp => {
        'Medisafe':
            reviews32.where((r) => r.app == 'Medisafe' && r.isComplaint).length,
        'MyTherapy': reviews32
            .where((r) => r.app == 'MyTherapy' && r.isComplaint)
            .length,
      };

  /// Review count broken down by domain.
  static Map<ReviewDomain, int> get reviewCountByDomain {
    final counts = <ReviewDomain, int>{};
    for (final domain in ReviewDomain.values) {
      counts[domain] = reviews32.where((r) => r.domain == domain).length;
    }
    return counts;
  }
}
