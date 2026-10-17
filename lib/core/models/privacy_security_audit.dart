// Fixture assertions for planning/serialization tests, not empirical security,
// language, legal-compliance or device evidence. See PLAY-LAUNCH-REVIEW.md and
// EPICS-1-7-PRIVACY-REVIEW.md for observed scope and outstanding human review.
/// Taxonomic sensitivity classification for stored attributes.
///
/// Follows Digital Personal Data Protection Act 2023 (DPDP Act) and IT Act 2000
/// SPDI Rules classification schemes.
enum DataSensitivityLevel {
  /// Master encryption keys, authentication tokens, hardware session seeds.
  criticalSecret('Critical Secret', 'Direct cryptographic risk if compromised'),

  /// Highly sensitive health data (medication names, clinical instructions,
  /// dose logs, schedules, clock times, days of administration).
  highSpdi(
      'High SPDI', 'Protected Health Information / Sensitive Personal Data'),

  /// Regimen metadata, dosing formulations, units, stock ledger counts.
  mediumSpdi('Medium SPDI', 'Clinical inventory and formulation attributes'),

  /// Non-sensitive operational metadata (IANA timezone name, revision counter).
  low('Low Sensitivity', 'Operational metadata devoid of PHI'),

  /// Pseudonymous identifiers (isolated profile hash, guest marker).
  pseudonymous('Pseudonymous Identifier', 'Opaque partition token'),

  /// Database singleton keys, schema counters, crash-recovery markers.
  internal(
      'Internal Operational', 'Internal state machine and engine sentinel');

  final String label;
  final String description;

  const DataSensitivityLevel(this.label, this.description);
}

/// Physical and logical storage boundaries on client platforms.
enum StorageSiloType {
  /// SQLCipher AES-256 encrypted SQLite database (`medicines-v1.db`).
  sqlCipherDatabase('SQLCipher DB',
      'Local encrypted SQLite database with PRAGMA secure_delete'),

  /// Platform Hardware Keystore / Secure Enclave (`flutter_secure_storage`).
  hardwareKeystore(
      'Hardware Keystore', 'Android Keystore (TEE/StrongBox) & iOS Keychain'),

  /// Platform plaintext preferences (`shared_preferences`).
  plaintextPreferences('Plaintext Preferences',
      'Unencrypted SharedPreferences / NSUserDefaults'),

  /// Operating System Notification Center & Alarm Payloads.
  osNotificationCenter('OS Notification Shade',
      'System notification tray and pending alarm intents'),

  /// Temporary storage for on-demand generated consultation PDFs.
  tempFileSystem(
      'Temporary Filesystem', 'App-private temporary cache directory'),

  /// In-memory volatile heap state.
  volatileMemory(
      'Volatile Memory', 'Volatile RAM buffers cleared upon process death'),

  /// Cloud database (Supabase PostgreSQL - decoupled from local engine in M0).
  cloudOptional('Cloud Optional (Supabase)',
      'Remote PostgreSQL backend (isolated in M0)');

  final String label;
  final String description;

  const StorageSiloType(this.label, this.description);
}

/// STRIDE threat classification category.
enum StrideCategory {
  spoofing('S', 'Spoofing', 'Impersonating an entity or process'),
  tampering('T', 'Tampering', 'Modifying data or code maliciously'),
  repudiation(
      'R', 'Repudiation', 'Denying performed actions without auditability'),
  informationDisclosure('I', 'Information Disclosure',
      'Exposing sensitive PHI/SPDI to unauthorized actors'),
  denialOfService(
      'D', 'Denial of Service', 'Preventing alarms or application execution'),
  elevationOfPrivilege('E', 'Elevation of Privilege',
      'Gaining unauthorized administrative or OS capabilities');

  final String code;
  final String label;
  final String definition;

  const StrideCategory(this.code, this.label, this.definition);
}

/// Standardized security risk rating.
enum RiskLevel {
  zero(0, 'Zero', 'Completely eliminated by architectural boundary'),
  veryLow(1, 'Very Low', 'Negligible residual impact under standard operation'),
  low(2, 'Low', 'Tolerable risk with active layered mitigations'),
  medium(3, 'Medium', 'Requires technical and operational monitoring'),
  high(4, 'High', 'Severe risk requiring mandatory architectural controls'),
  critical(5, 'Critical', 'Catastrophic risk; blocks production deployment');

  final int score;
  final String label;
  final String description;

  const RiskLevel(this.score, this.label, this.description);

  bool get isAcceptableResidual => score <= 2;
}

/// Data dictionary entry mapping an individual field, attribute, or key.
class StoredFieldRecord {
  final String fieldPath;
  final StorageSiloType storageSilo;
  final String tableNameOrKey;
  final String dataType;
  final DataSensitivityLevel sensitivity;
  final String rationale;
  final bool isEncryptedAtRest;
  final bool isExcludedFromBackup;
  final bool allowlistedInDiagnostics;

  const StoredFieldRecord({
    required this.fieldPath,
    required this.storageSilo,
    required this.tableNameOrKey,
    required this.dataType,
    required this.sensitivity,
    required this.rationale,
    required this.isEncryptedAtRest,
    required this.isExcludedFromBackup,
    required this.allowlistedInDiagnostics,
  });

  bool get containsPhiOrSpdi =>
      sensitivity == DataSensitivityLevel.highSpdi ||
      sensitivity == DataSensitivityLevel.mediumSpdi;

  bool get isCompliantAtRest {
    if (!containsPhiOrSpdi) return true;
    if (storageSilo == StorageSiloType.tempFileSystem) {
      return isExcludedFromBackup;
    }
    return isEncryptedAtRest && isExcludedFromBackup;
  }

  Map<String, dynamic> toJson() => {
        'fieldPath': fieldPath,
        'storageSilo': storageSilo.name,
        'tableNameOrKey': tableNameOrKey,
        'dataType': dataType,
        'sensitivity': sensitivity.name,
        'rationale': rationale,
        'isEncryptedAtRest': isEncryptedAtRest,
        'isExcludedFromBackup': isExcludedFromBackup,
        'allowlistedInDiagnostics': allowlistedInDiagnostics,
      };

  factory StoredFieldRecord.fromJson(Map<String, dynamic> json) =>
      StoredFieldRecord(
        fieldPath: json['fieldPath'] as String,
        storageSilo:
            StorageSiloType.values.byName(json['storageSilo'] as String),
        tableNameOrKey: json['tableNameOrKey'] as String,
        dataType: json['dataType'] as String,
        sensitivity:
            DataSensitivityLevel.values.byName(json['sensitivity'] as String),
        rationale: json['rationale'] as String,
        isEncryptedAtRest: json['isEncryptedAtRest'] as bool,
        isExcludedFromBackup: json['isExcludedFromBackup'] as bool,
        allowlistedInDiagnostics: json['allowlistedInDiagnostics'] as bool,
      );
}

/// Operating system notification channel configuration and lock-screen privacy guarantee.
class NotificationChannelRecord {
  final String channelId;
  final String channelName;
  final String importance;
  final String priority;
  final String visibility;
  final bool lockScreenGuaranteesZeroPhi;
  final bool payloadContainsMedicineName;
  final bool payloadContainsDosage;
  final bool deviceAuthRequiredForActions;
  final Map<String, dynamic> sampleIntentPayload;

  const NotificationChannelRecord({
    required this.channelId,
    required this.channelName,
    required this.importance,
    required this.priority,
    required this.visibility,
    required this.lockScreenGuaranteesZeroPhi,
    required this.payloadContainsMedicineName,
    required this.payloadContainsDosage,
    required this.deviceAuthRequiredForActions,
    required this.sampleIntentPayload,
  });

  bool get isPrivateVisibility =>
      visibility == 'NotificationVisibility.private';

  bool get compliesWithLockScreenPrivacy =>
      lockScreenGuaranteesZeroPhi &&
      !payloadContainsMedicineName &&
      !payloadContainsDosage &&
      isPrivateVisibility;

  Map<String, dynamic> toJson() => {
        'channelId': channelId,
        'channelName': channelName,
        'importance': importance,
        'priority': priority,
        'visibility': visibility,
        'lockScreenGuaranteesZeroPhi': lockScreenGuaranteesZeroPhi,
        'payloadContainsMedicineName': payloadContainsMedicineName,
        'payloadContainsDosage': payloadContainsDosage,
        'deviceAuthRequiredForActions': deviceAuthRequiredForActions,
        'sampleIntentPayload': sampleIntentPayload,
      };

  factory NotificationChannelRecord.fromJson(Map<String, dynamic> json) =>
      NotificationChannelRecord(
        channelId: json['channelId'] as String,
        channelName: json['channelName'] as String,
        importance: json['importance'] as String,
        priority: json['priority'] as String,
        visibility: json['visibility'] as String,
        lockScreenGuaranteesZeroPhi:
            json['lockScreenGuaranteesZeroPhi'] as bool,
        payloadContainsMedicineName:
            json['payloadContainsMedicineName'] as bool,
        payloadContainsDosage: json['payloadContainsDosage'] as bool,
        deviceAuthRequiredForActions:
            json['deviceAuthRequiredForActions'] as bool,
        sampleIntentPayload:
            Map<String, dynamic>.from(json['sampleIntentPayload'] as Map),
      );
}

/// Platform backup and physical device-transfer extraction prevention rule.
class DataExtractionRule {
  final String targetPlatform;
  final String mechanism;
  final bool cloudBackupExcluded;
  final bool deviceTransferExcluded;
  final List<String> excludedDomains;
  final bool hardwareKeyBound;

  const DataExtractionRule({
    required this.targetPlatform,
    required this.mechanism,
    required this.cloudBackupExcluded,
    required this.deviceTransferExcluded,
    required this.excludedDomains,
    required this.hardwareKeyBound,
  });

  bool get providesCompleteExtractionDefense =>
      cloudBackupExcluded && deviceTransferExcluded && hardwareKeyBound;

  Map<String, dynamic> toJson() => {
        'targetPlatform': targetPlatform,
        'mechanism': mechanism,
        'cloudBackupExcluded': cloudBackupExcluded,
        'deviceTransferExcluded': deviceTransferExcluded,
        'excludedDomains': excludedDomains,
        'hardwareKeyBound': hardwareKeyBound,
      };

  factory DataExtractionRule.fromJson(Map<String, dynamic> json) =>
      DataExtractionRule(
        targetPlatform: json['targetPlatform'] as String,
        mechanism: json['mechanism'] as String,
        cloudBackupExcluded: json['cloudBackupExcluded'] as bool,
        deviceTransferExcluded: json['deviceTransferExcluded'] as bool,
        excludedDomains: List<String>.from(json['excludedDomains'] as List),
        hardwareKeyBound: json['hardwareKeyBound'] as bool,
      );
}

/// Audited dependency and third-party software supply chain component.
class AuditedDependency {
  final String packageName;
  final String version;
  final String license;
  final String functionalPurpose;
  final bool hasNetworkAccess;
  final bool hasThirdPartyTelemetry;
  final String dataAccessed;
  final bool isLocalEngineDependency;

  const AuditedDependency({
    required this.packageName,
    required this.version,
    required this.license,
    required this.functionalPurpose,
    required this.hasNetworkAccess,
    required this.hasThirdPartyTelemetry,
    required this.dataAccessed,
    required this.isLocalEngineDependency,
  });

  bool get isTelemetryFree => !hasThirdPartyTelemetry;

  Map<String, dynamic> toJson() => {
        'packageName': packageName,
        'version': version,
        'license': license,
        'functionalPurpose': functionalPurpose,
        'hasNetworkAccess': hasNetworkAccess,
        'hasThirdPartyTelemetry': hasThirdPartyTelemetry,
        'dataAccessed': dataAccessed,
        'isLocalEngineDependency': isLocalEngineDependency,
      };

  factory AuditedDependency.fromJson(Map<String, dynamic> json) =>
      AuditedDependency(
        packageName: json['packageName'] as String,
        version: json['version'] as String,
        license: json['license'] as String,
        functionalPurpose: json['functionalPurpose'] as String,
        hasNetworkAccess: json['hasNetworkAccess'] as bool,
        hasThirdPartyTelemetry: json['hasThirdPartyTelemetry'] as bool,
        dataAccessed: json['dataAccessed'] as String,
        isLocalEngineDependency: json['isLocalEngineDependency'] as bool,
      );
}

/// Audited OS manifest or runtime permission declaration.
class ManifestPermissionRecord {
  final String platform;
  final String permissionName;
  final String protectionLevel;
  final String operationalJustification;
  final String privacyRiskAndMitigation;
  final String gracefulDegradationMode;
  final bool isStrictlyRequired;
  final bool isProhibited;

  const ManifestPermissionRecord({
    required this.platform,
    required this.permissionName,
    required this.protectionLevel,
    required this.operationalJustification,
    required this.privacyRiskAndMitigation,
    required this.gracefulDegradationMode,
    required this.isStrictlyRequired,
    required this.isProhibited,
  });

  Map<String, dynamic> toJson() => {
        'platform': platform,
        'permissionName': permissionName,
        'protectionLevel': protectionLevel,
        'operationalJustification': operationalJustification,
        'privacyRiskAndMitigation': privacyRiskAndMitigation,
        'gracefulDegradationMode': gracefulDegradationMode,
        'isStrictlyRequired': isStrictlyRequired,
        'isProhibited': isProhibited,
      };

  factory ManifestPermissionRecord.fromJson(Map<String, dynamic> json) =>
      ManifestPermissionRecord(
        platform: json['platform'] as String,
        permissionName: json['permissionName'] as String,
        protectionLevel: json['protectionLevel'] as String,
        operationalJustification: json['operationalJustification'] as String,
        privacyRiskAndMitigation: json['privacyRiskAndMitigation'] as String,
        gracefulDegradationMode: json['gracefulDegradationMode'] as String,
        isStrictlyRequired: json['isStrictlyRequired'] as bool,
        isProhibited: json['isProhibited'] as bool,
      );
}

/// Comprehensive STRIDE threat model entry with risk scores and mitigations.
class StrideThreatModel {
  final String threatId;
  final StrideCategory strideCategory;
  final String title;
  final String scenario;
  final RiskLevel inherentRisk;
  final RiskLevel residualRisk;
  final List<String> technicalMitigations;
  final String verificationMethod;

  const StrideThreatModel({
    required this.threatId,
    required this.strideCategory,
    required this.title,
    required this.scenario,
    required this.inherentRisk,
    required this.residualRisk,
    required this.technicalMitigations,
    required this.verificationMethod,
  });

  bool get isResidualRiskAcceptable => residualRisk.isAcceptableResidual;

  Map<String, dynamic> toJson() => {
        'threatId': threatId,
        'strideCategory': strideCategory.name,
        'title': title,
        'scenario': scenario,
        'inherentRisk': inherentRisk.name,
        'residualRisk': residualRisk.name,
        'technicalMitigations': technicalMitigations,
        'verificationMethod': verificationMethod,
      };

  factory StrideThreatModel.fromJson(Map<String, dynamic> json) =>
      StrideThreatModel(
        threatId: json['threatId'] as String,
        strideCategory:
            StrideCategory.values.byName(json['strideCategory'] as String),
        title: json['title'] as String,
        scenario: json['scenario'] as String,
        inherentRisk: RiskLevel.values.byName(json['inherentRisk'] as String),
        residualRisk: RiskLevel.values.byName(json['residualRisk'] as String),
        technicalMitigations:
            List<String>.from(json['technicalMitigations'] as List),
        verificationMethod: json['verificationMethod'] as String,
      );
}

/// Staged statutory commencement milestone under India DPDP Act 2023 Gazette G.S.R. 843(E).
class DpdpCommencementStage {
  final int stageNumber;
  final String gazetteNotification;
  final DateTime publicationDate;
  final DateTime effectiveDate;
  final List<String> statutorySections;
  final String description;
  final bool isMandatoryBeforeProduction;

  const DpdpCommencementStage({
    required this.stageNumber,
    required this.gazetteNotification,
    required this.publicationDate,
    required this.effectiveDate,
    required this.statutorySections,
    required this.description,
    required this.isMandatoryBeforeProduction,
  });

  Map<String, dynamic> toJson() => {
        'stageNumber': stageNumber,
        'gazetteNotification': gazetteNotification,
        'publicationDate': publicationDate.toIso8601String().substring(0, 10),
        'effectiveDate': effectiveDate.toIso8601String().substring(0, 10),
        'statutorySections': statutorySections,
        'description': description,
        'isMandatoryBeforeProduction': isMandatoryBeforeProduction,
      };

  factory DpdpCommencementStage.fromJson(Map<String, dynamic> json) =>
      DpdpCommencementStage(
        stageNumber: json['stageNumber'] as int,
        gazetteNotification: json['gazetteNotification'] as String,
        publicationDate: DateTime.parse(json['publicationDate'] as String),
        effectiveDate: DateTime.parse(json['effectiveDate'] as String),
        statutorySections: List<String>.from(json['statutorySections'] as List),
        description: json['description'] as String,
        isMandatoryBeforeProduction:
            json['isMandatoryBeforeProduction'] as bool,
      );
}

/// Statutory obligation analysis under India DPDP Act 2023.
class DpdpComplianceObligation {
  final String sectionRef;
  final String title;
  final String statutoryRequirement;
  final String architecturalImplementation;
  final bool appliesToLocalOfflineMode;
  final List<String> verifiedLanguages;
  final double maximumPenaltyInrCrore;

  const DpdpComplianceObligation({
    required this.sectionRef,
    required this.title,
    required this.statutoryRequirement,
    required this.architecturalImplementation,
    required this.appliesToLocalOfflineMode,
    required this.verifiedLanguages,
    required this.maximumPenaltyInrCrore,
  });

  Map<String, dynamic> toJson() => {
        'sectionRef': sectionRef,
        'title': title,
        'statutoryRequirement': statutoryRequirement,
        'architecturalImplementation': architecturalImplementation,
        'appliesToLocalOfflineMode': appliesToLocalOfflineMode,
        'verifiedLanguages': verifiedLanguages,
        'maximumPenaltyInrCrore': maximumPenaltyInrCrore,
      };

  factory DpdpComplianceObligation.fromJson(Map<String, dynamic> json) =>
      DpdpComplianceObligation(
        sectionRef: json['sectionRef'] as String,
        title: json['title'] as String,
        statutoryRequirement: json['statutoryRequirement'] as String,
        architecturalImplementation:
            json['architecturalImplementation'] as String,
        appliesToLocalOfflineMode: json['appliesToLocalOfflineMode'] as bool,
        verifiedLanguages: List<String>.from(json['verifiedLanguages'] as List),
        maximumPenaltyInrCrore:
            (json['maximumPenaltyInrCrore'] as num).toDouble(),
      );
}

/// Legal, clinical, and regulatory boundary specifications.
class RegulatoryDisclaimerSpecification {
  final String approvedClinicalDisclaimer;
  final String samdClassification;
  final bool hipaaCompliantClaimProhibited;
  final bool gdprCertifiedClaimProhibited;
  final bool fdaApprovedClaimProhibited;
  final int certInReportingWindowHours;
  final String certInReportingEmail;

  const RegulatoryDisclaimerSpecification({
    required this.approvedClinicalDisclaimer,
    required this.samdClassification,
    required this.hipaaCompliantClaimProhibited,
    required this.gdprCertifiedClaimProhibited,
    required this.fdaApprovedClaimProhibited,
    required this.certInReportingWindowHours,
    required this.certInReportingEmail,
  });

  Map<String, dynamic> toJson() => {
        'approvedClinicalDisclaimer': approvedClinicalDisclaimer,
        'samdClassification': samdClassification,
        'hipaaCompliantClaimProhibited': hipaaCompliantClaimProhibited,
        'gdprCertifiedClaimProhibited': gdprCertifiedClaimProhibited,
        'fdaApprovedClaimProhibited': fdaApprovedClaimProhibited,
        'certInReportingWindowHours': certInReportingWindowHours,
        'certInReportingEmail': certInReportingEmail,
      };

  factory RegulatoryDisclaimerSpecification.fromJson(
          Map<String, dynamic> json) =>
      RegulatoryDisclaimerSpecification(
        approvedClinicalDisclaimer:
            json['approvedClinicalDisclaimer'] as String,
        samdClassification: json['samdClassification'] as String,
        hipaaCompliantClaimProhibited:
            json['hipaaCompliantClaimProhibited'] as bool,
        gdprCertifiedClaimProhibited:
            json['gdprCertifiedClaimProhibited'] as bool,
        fdaApprovedClaimProhibited: json['fdaApprovedClaimProhibited'] as bool,
        certInReportingWindowHours: json['certInReportingWindowHours'] as int,
        certInReportingEmail: json['certInReportingEmail'] as String,
      );
}

/// Operational role in the mitigation governance framework.
class GovernanceRole {
  final String code;
  final String title;
  final String primaryResponsibilities;

  const GovernanceRole({
    required this.code,
    required this.title,
    required this.primaryResponsibilities,
  });

  Map<String, dynamic> toJson() => {
        'code': code,
        'title': title,
        'primaryResponsibilities': primaryResponsibilities,
      };

  factory GovernanceRole.fromJson(Map<String, dynamic> json) => GovernanceRole(
        code: json['code'] as String,
        title: json['title'] as String,
        primaryResponsibilities: json['primaryResponsibilities'] as String,
      );
}

/// Individual RACI row assigning operational accountability across 6 pillars.
class RaciAssignment {
  final String governanceArea;
  final String accountableRoleCode;
  final List<String> responsibleRoleCodes;
  final List<String> consultedRoleCodes;
  final List<String> informedRoleCodes;
  final List<String> operationalSpecifications;

  const RaciAssignment({
    required this.governanceArea,
    required this.accountableRoleCode,
    required this.responsibleRoleCodes,
    required this.consultedRoleCodes,
    required this.informedRoleCodes,
    required this.operationalSpecifications,
  });

  Map<String, dynamic> toJson() => {
        'governanceArea': governanceArea,
        'accountableRoleCode': accountableRoleCode,
        'responsibleRoleCodes': responsibleRoleCodes,
        'consultedRoleCodes': consultedRoleCodes,
        'informedRoleCodes': informedRoleCodes,
        'operationalSpecifications': operationalSpecifications,
      };

  factory RaciAssignment.fromJson(Map<String, dynamic> json) => RaciAssignment(
        governanceArea: json['governanceArea'] as String,
        accountableRoleCode: json['accountableRoleCode'] as String,
        responsibleRoleCodes:
            List<String>.from(json['responsibleRoleCodes'] as List),
        consultedRoleCodes:
            List<String>.from(json['consultedRoleCodes'] as List),
        informedRoleCodes: List<String>.from(json['informedRoleCodes'] as List),
        operationalSpecifications:
            List<String>.from(json['operationalSpecifications'] as List),
      );
}

/// Static datasets, formal inventories, and test fixtures for MED-028.
class PrivacySecurityAuditFixtures {
  const PrivacySecurityAuditFixtures._();

  /// Complete stored fields dictionary auditing all local silos and schemas.
  static final List<StoredFieldRecord> storedFieldsDictionary = [
    // 1. SQLCipher Table: medicine_settings
    const StoredFieldRecord(
      fieldPath: 'medicine_settings.id',
      storageSilo: StorageSiloType.sqlCipherDatabase,
      tableNameOrKey: 'medicine_settings',
      dataType: 'INTEGER PRIMARY KEY CHECK(id=1)',
      sensitivity: DataSensitivityLevel.internal,
      rationale: 'Singleton configuration table row identifier',
      isEncryptedAtRest: true,
      isExcludedFromBackup: true,
      allowlistedInDiagnostics: false,
    ),
    const StoredFieldRecord(
      fieldPath: 'medicine_settings.owner',
      storageSilo: StorageSiloType.sqlCipherDatabase,
      tableNameOrKey: 'medicine_settings',
      dataType: 'TEXT',
      sensitivity: DataSensitivityLevel.pseudonymous,
      rationale: 'Active owner partition key ("guest" or sha256 user id hash)',
      isEncryptedAtRest: true,
      isExcludedFromBackup: true,
      allowlistedInDiagnostics: false,
    ),

    // 2. SQLCipher Table: medicine_data
    const StoredFieldRecord(
      fieldPath: 'medicine_data.owner',
      storageSilo: StorageSiloType.sqlCipherDatabase,
      tableNameOrKey: 'medicine_data',
      dataType: 'TEXT PRIMARY KEY',
      sensitivity: DataSensitivityLevel.pseudonymous,
      rationale: 'Isolated owner partition key for profile records',
      isEncryptedAtRest: true,
      isExcludedFromBackup: true,
      allowlistedInDiagnostics: false,
    ),
    const StoredFieldRecord(
      fieldPath: 'medicine_data.payload',
      storageSilo: StorageSiloType.sqlCipherDatabase,
      tableNameOrKey: 'medicine_data',
      dataType: 'TEXT NOT NULL',
      sensitivity: DataSensitivityLevel.highSpdi,
      rationale:
          'Encrypted JSON document containing medications, events, stock',
      isEncryptedAtRest: true,
      isExcludedFromBackup: true,
      allowlistedInDiagnostics: false,
    ),

    // 3. Schema Version 3 Payload Attributes
    const StoredFieldRecord(
      fieldPath: 'medications[].name',
      storageSilo: StorageSiloType.sqlCipherDatabase,
      tableNameOrKey: 'medicine_data.payload',
      dataType: 'String',
      sensitivity: DataSensitivityLevel.highSpdi,
      rationale: 'Patient medication name; discloses clinical conditions',
      isEncryptedAtRest: true,
      isExcludedFromBackup: true,
      allowlistedInDiagnostics: false,
    ),
    const StoredFieldRecord(
      fieldPath: 'medications[].strength',
      storageSilo: StorageSiloType.sqlCipherDatabase,
      tableNameOrKey: 'medicine_data.payload',
      dataType: 'String',
      sensitivity: DataSensitivityLevel.highSpdi,
      rationale: 'Dosage active ingredient strength (e.g., "500 mg")',
      isEncryptedAtRest: true,
      isExcludedFromBackup: true,
      allowlistedInDiagnostics: false,
    ),
    const StoredFieldRecord(
      fieldPath: 'medications[].amount',
      storageSilo: StorageSiloType.sqlCipherDatabase,
      tableNameOrKey: 'medicine_data.payload',
      dataType: 'Integer',
      sensitivity: DataSensitivityLevel.highSpdi,
      rationale: 'Fixed-point administration quantity (10^4 = 1.0)',
      isEncryptedAtRest: true,
      isExcludedFromBackup: true,
      allowlistedInDiagnostics: false,
    ),
    const StoredFieldRecord(
      fieldPath: 'medications[].unit',
      storageSilo: StorageSiloType.sqlCipherDatabase,
      tableNameOrKey: 'medicine_data.payload',
      dataType: 'String',
      sensitivity: DataSensitivityLevel.mediumSpdi,
      rationale: 'Unit of measure (tablet, capsule, drops)',
      isEncryptedAtRest: true,
      isExcludedFromBackup: true,
      allowlistedInDiagnostics: false,
    ),
    const StoredFieldRecord(
      fieldPath: 'medications[].form',
      storageSilo: StorageSiloType.sqlCipherDatabase,
      tableNameOrKey: 'medicine_data.payload',
      dataType: 'String',
      sensitivity: DataSensitivityLevel.mediumSpdi,
      rationale: 'Formulation category (oral, topical, injection)',
      isEncryptedAtRest: true,
      isExcludedFromBackup: true,
      allowlistedInDiagnostics: false,
    ),
    const StoredFieldRecord(
      fieldPath: 'medications[].instructions',
      storageSilo: StorageSiloType.sqlCipherDatabase,
      tableNameOrKey: 'medicine_data.payload',
      dataType: 'String',
      sensitivity: DataSensitivityLevel.highSpdi,
      rationale: 'Prescription instructions (e.g., "Take with food")',
      isEncryptedAtRest: true,
      isExcludedFromBackup: true,
      allowlistedInDiagnostics: false,
    ),
    const StoredFieldRecord(
      fieldPath: 'medications[].timezone',
      storageSilo: StorageSiloType.sqlCipherDatabase,
      tableNameOrKey: 'medicine_data.payload',
      dataType: 'String',
      sensitivity: DataSensitivityLevel.low,
      rationale: 'IANA timezone identifier for schedule anchoring',
      isEncryptedAtRest: true,
      isExcludedFromBackup: true,
      allowlistedInDiagnostics: false,
    ),
    const StoredFieldRecord(
      fieldPath: 'medications[].minutes',
      storageSilo: StorageSiloType.sqlCipherDatabase,
      tableNameOrKey: 'medicine_data.payload',
      dataType: 'List<int>',
      sensitivity: DataSensitivityLevel.highSpdi,
      rationale: 'Prescribed intake clock times (minutes from midnight)',
      isEncryptedAtRest: true,
      isExcludedFromBackup: true,
      allowlistedInDiagnostics: false,
    ),
    const StoredFieldRecord(
      fieldPath: 'medications[].weekdays',
      storageSilo: StorageSiloType.sqlCipherDatabase,
      tableNameOrKey: 'medicine_data.payload',
      dataType: 'List<int>',
      sensitivity: DataSensitivityLevel.highSpdi,
      rationale: 'Days of recurrence schedule (1=Mon ... 7=Sun)',
      isEncryptedAtRest: true,
      isExcludedFromBackup: true,
      allowlistedInDiagnostics: false,
    ),
    const StoredFieldRecord(
      fieldPath: 'medications[].revision',
      storageSilo: StorageSiloType.sqlCipherDatabase,
      tableNameOrKey: 'medicine_data.payload',
      dataType: 'Integer',
      sensitivity: DataSensitivityLevel.low,
      rationale: 'Monotonically increasing schedule revision index',
      isEncryptedAtRest: true,
      isExcludedFromBackup: true,
      allowlistedInDiagnostics: false,
    ),
    const StoredFieldRecord(
      fieldPath: 'events[].action',
      storageSilo: StorageSiloType.sqlCipherDatabase,
      tableNameOrKey: 'medicine_data.payload',
      dataType: 'String',
      sensitivity: DataSensitivityLevel.highSpdi,
      rationale: 'Adherence action confirmation (taken, skipped, snooze, undo)',
      isEncryptedAtRest: true,
      isExcludedFromBackup: true,
      allowlistedInDiagnostics: false,
    ),
    const StoredFieldRecord(
      fieldPath: 'events[].recordedAt',
      storageSilo: StorageSiloType.sqlCipherDatabase,
      tableNameOrKey: 'medicine_data.payload',
      dataType: 'String (ISO 8601 UTC)',
      sensitivity: DataSensitivityLevel.highSpdi,
      rationale: 'Exact clinical timestamp of patient dose confirmation',
      isEncryptedAtRest: true,
      isExcludedFromBackup: true,
      allowlistedInDiagnostics: false,
    ),
    const StoredFieldRecord(
      fieldPath: 'stockAccounts[].threshold',
      storageSilo: StorageSiloType.sqlCipherDatabase,
      tableNameOrKey: 'medicine_data.payload',
      dataType: 'Integer',
      sensitivity: DataSensitivityLevel.mediumSpdi,
      rationale: 'Inventory low-stock refill warning threshold',
      isEncryptedAtRest: true,
      isExcludedFromBackup: true,
      allowlistedInDiagnostics: false,
    ),
    const StoredFieldRecord(
      fieldPath: 'stockEntries[].delta',
      storageSilo: StorageSiloType.sqlCipherDatabase,
      tableNameOrKey: 'medicine_data.payload',
      dataType: 'Integer',
      sensitivity: DataSensitivityLevel.mediumSpdi,
      rationale: 'Double-entry inventory ledger consumption / refill amount',
      isEncryptedAtRest: true,
      isExcludedFromBackup: true,
      allowlistedInDiagnostics: false,
    ),

    // 4. Hardware Keystore Keys (FlutterSecureStorage)
    const StoredFieldRecord(
      fieldPath: 'medicine.database.key.v1',
      storageSilo: StorageSiloType.hardwareKeystore,
      tableNameOrKey: 'FlutterSecureStorage',
      dataType: '256-bit Key (base64url)',
      sensitivity: DataSensitivityLevel.criticalSecret,
      rationale: 'Random.secure() master key for SQLCipher database encryption',
      isEncryptedAtRest: true,
      isExcludedFromBackup: true,
      allowlistedInDiagnostics: false,
    ),
    const StoredFieldRecord(
      fieldPath: 'medicine.active.v1',
      storageSilo: StorageSiloType.hardwareKeystore,
      tableNameOrKey: 'FlutterSecureStorage',
      dataType: 'String',
      sensitivity: DataSensitivityLevel.low,
      rationale: 'Fallback active profile pointer for testing and recovery',
      isEncryptedAtRest: true,
      isExcludedFromBackup: true,
      allowlistedInDiagnostics: false,
    ),
    const StoredFieldRecord(
      fieldPath: 'medicine.reset.pending.v1',
      storageSilo: StorageSiloType.hardwareKeystore,
      tableNameOrKey: 'FlutterSecureStorage',
      dataType: 'String ("requested")',
      sensitivity: DataSensitivityLevel.internal,
      rationale:
          'Durable atomic reset marker ensuring cleanup completes after crash',
      isEncryptedAtRest: true,
      isExcludedFromBackup: true,
      allowlistedInDiagnostics: false,
    ),
    const StoredFieldRecord(
      fieldPath: 'sb-<id>-auth-token',
      storageSilo: StorageSiloType.hardwareKeystore,
      tableNameOrKey: 'FlutterSecureStorage',
      dataType: 'JSON Web Token (JWT)',
      sensitivity: DataSensitivityLevel.criticalSecret,
      rationale:
          'Supabase cloud authentication session credentials (optional login)',
      isEncryptedAtRest: true,
      isExcludedFromBackup: true,
      allowlistedInDiagnostics: false,
    ),

    // 5. Plaintext Preferences (SharedPreferences)
    const StoredFieldRecord(
      fieldPath: 'medicine_app_language_override',
      storageSilo: StorageSiloType.plaintextPreferences,
      tableNameOrKey: 'shared_preferences',
      dataType: 'String ("en" / "hi")',
      sensitivity: DataSensitivityLevel.low,
      rationale: 'User interface language preference selection',
      isEncryptedAtRest: false,
      isExcludedFromBackup: true,
      allowlistedInDiagnostics: false,
    ),
    const StoredFieldRecord(
      fieldPath: 'is_guest_mode',
      storageSilo: StorageSiloType.plaintextPreferences,
      tableNameOrKey: 'shared_preferences',
      dataType: 'Boolean',
      sensitivity: DataSensitivityLevel.low,
      rationale: 'Flag indicating local offline guest session',
      isEncryptedAtRest: false,
      isExcludedFromBackup: true,
      allowlistedInDiagnostics: false,
    ),
    const StoredFieldRecord(
      fieldPath: 'onboarding_completed_local',
      storageSilo: StorageSiloType.plaintextPreferences,
      tableNameOrKey: 'shared_preferences',
      dataType: 'Boolean',
      sensitivity: DataSensitivityLevel.low,
      rationale: 'Flag recording completion of local first-launch journey',
      isEncryptedAtRest: false,
      isExcludedFromBackup: true,
      allowlistedInDiagnostics: false,
    ),

    // 6. Temporary Report Cache
    const StoredFieldRecord(
      fieldPath: '<temp>/medicine-report-*.pdf',
      storageSilo: StorageSiloType.tempFileSystem,
      tableNameOrKey: 'FileSystem',
      dataType: 'PDF Binary',
      sensitivity: DataSensitivityLevel.highSpdi,
      rationale:
          'On-demand consultation PDF export; purged on startup and reset',
      isEncryptedAtRest: false,
      isExcludedFromBackup: true,
      allowlistedInDiagnostics: false,
    ),

    // 7. Notification Intent Payload
    const StoredFieldRecord(
      fieldPath: 'notification.intent.dose',
      storageSilo: StorageSiloType.osNotificationCenter,
      tableNameOrKey: 'OS Alarm Intent',
      dataType: 'String (Occurrence UUID)',
      sensitivity: DataSensitivityLevel.low,
      rationale: 'Composite occurrence ID for in-app dose routing',
      isEncryptedAtRest: false,
      isExcludedFromBackup: true,
      allowlistedInDiagnostics: false,
    ),
    const StoredFieldRecord(
      fieldPath: 'notification.intent.due',
      storageSilo: StorageSiloType.osNotificationCenter,
      tableNameOrKey: 'OS Alarm Intent',
      dataType: 'String (ISO 8601 UTC)',
      sensitivity: DataSensitivityLevel.low,
      rationale: 'Scheduled timestamp for exact alarm routing',
      isEncryptedAtRest: false,
      isExcludedFromBackup: true,
      allowlistedInDiagnostics: false,
    ),

    // 8. Allowlisted Diagnostics Fields (11 Fields Only)
    const StoredFieldRecord(
      fieldPath: 'reminderDiagnostics.schema',
      storageSilo: StorageSiloType.volatileMemory,
      tableNameOrKey: 'DiagnosticsAllowlist',
      dataType: 'Integer (1)',
      sensitivity: DataSensitivityLevel.low,
      rationale: 'Diagnostic bundle format version schema',
      isEncryptedAtRest: false,
      isExcludedFromBackup: true,
      allowlistedInDiagnostics: true,
    ),
    const StoredFieldRecord(
      fieldPath: 'reminderDiagnostics.scope',
      storageSilo: StorageSiloType.volatileMemory,
      tableNameOrKey: 'DiagnosticsAllowlist',
      dataType: 'String ("local-readiness")',
      sensitivity: DataSensitivityLevel.low,
      rationale: 'Operational diagnostic boundary scope identifier',
      isEncryptedAtRest: false,
      isExcludedFromBackup: true,
      allowlistedInDiagnostics: true,
    ),
    const StoredFieldRecord(
      fieldPath: 'reminderDiagnostics.remoteTelemetry',
      storageSilo: StorageSiloType.volatileMemory,
      tableNameOrKey: 'DiagnosticsAllowlist',
      dataType: 'Boolean (false)',
      sensitivity: DataSensitivityLevel.low,
      rationale: 'Verification of zero-remote-telemetry guarantee',
      isEncryptedAtRest: false,
      isExcludedFromBackup: true,
      allowlistedInDiagnostics: true,
    ),
    const StoredFieldRecord(
      fieldPath: 'reminderDiagnostics.schedulingSupported',
      storageSilo: StorageSiloType.volatileMemory,
      tableNameOrKey: 'DiagnosticsAllowlist',
      dataType: 'Boolean',
      sensitivity: DataSensitivityLevel.low,
      rationale: 'Platform notification scheduling capability flag',
      isEncryptedAtRest: false,
      isExcludedFromBackup: true,
      allowlistedInDiagnostics: true,
    ),
    const StoredFieldRecord(
      fieldPath: 'reminderDiagnostics.notificationPermission',
      storageSilo: StorageSiloType.volatileMemory,
      tableNameOrKey: 'DiagnosticsAllowlist',
      dataType: 'Boolean',
      sensitivity: DataSensitivityLevel.low,
      rationale: 'OS notification posting permission grant status',
      isEncryptedAtRest: false,
      isExcludedFromBackup: true,
      allowlistedInDiagnostics: true,
    ),
    const StoredFieldRecord(
      fieldPath: 'reminderDiagnostics.preciseAlarmPermission',
      storageSilo: StorageSiloType.volatileMemory,
      tableNameOrKey: 'DiagnosticsAllowlist',
      dataType: 'Boolean',
      sensitivity: DataSensitivityLevel.low,
      rationale: 'Android exact alarm permission grant status',
      isEncryptedAtRest: false,
      isExcludedFromBackup: true,
      allowlistedInDiagnostics: true,
    ),
    const StoredFieldRecord(
      fieldPath: 'reminderDiagnostics.refillChannelEnabled',
      storageSilo: StorageSiloType.volatileMemory,
      tableNameOrKey: 'DiagnosticsAllowlist',
      dataType: 'Boolean',
      sensitivity: DataSensitivityLevel.low,
      rationale: 'Notification channel enablement status for stock refills',
      isEncryptedAtRest: false,
      isExcludedFromBackup: true,
      allowlistedInDiagnostics: true,
    ),
    const StoredFieldRecord(
      fieldPath: 'reminderDiagnostics.futureSchedulePresent',
      storageSilo: StorageSiloType.volatileMemory,
      tableNameOrKey: 'DiagnosticsAllowlist',
      dataType: 'Boolean',
      sensitivity: DataSensitivityLevel.low,
      rationale: 'Indicator whether future alarms are scheduled',
      isEncryptedAtRest: false,
      isExcludedFromBackup: true,
      allowlistedInDiagnostics: true,
    ),
    const StoredFieldRecord(
      fieldPath: 'reminderDiagnostics.reconciliationFailed',
      storageSilo: StorageSiloType.volatileMemory,
      tableNameOrKey: 'DiagnosticsAllowlist',
      dataType: 'Boolean',
      sensitivity: DataSensitivityLevel.low,
      rationale: 'Indicator whether background alarm sync encountered error',
      isEncryptedAtRest: false,
      isExcludedFromBackup: true,
      allowlistedInDiagnostics: true,
    ),
    const StoredFieldRecord(
      fieldPath: 'reminderDiagnostics.callbackObserved',
      storageSilo: StorageSiloType.volatileMemory,
      tableNameOrKey: 'DiagnosticsAllowlist',
      dataType: 'String ("not measured")',
      sensitivity: DataSensitivityLevel.low,
      rationale: 'Diagnostic callback execution measurement sentinel',
      isEncryptedAtRest: false,
      isExcludedFromBackup: true,
      allowlistedInDiagnostics: true,
    ),
    const StoredFieldRecord(
      fieldPath: 'reminderDiagnostics.posted',
      storageSilo: StorageSiloType.volatileMemory,
      tableNameOrKey: 'DiagnosticsAllowlist',
      dataType: 'String ("not measured")',
      sensitivity: DataSensitivityLevel.low,
      rationale: 'Diagnostic alarm posting measurement sentinel',
      isEncryptedAtRest: false,
      isExcludedFromBackup: true,
      allowlistedInDiagnostics: true,
    ),
    const StoredFieldRecord(
      fieldPath: 'reminderDiagnostics.humanReceipt',
      storageSilo: StorageSiloType.volatileMemory,
      tableNameOrKey: 'DiagnosticsAllowlist',
      dataType: 'String ("not measured")',
      sensitivity: DataSensitivityLevel.low,
      rationale: 'Diagnostic human confirmation measurement sentinel',
      isEncryptedAtRest: false,
      isExcludedFromBackup: true,
      allowlistedInDiagnostics: true,
    ),
  ];

  /// The 11 canonical diagnostic allowlist keys.
  static const List<String> diagnosticAllowlistKeys = [
    'schema',
    'scope',
    'remoteTelemetry',
    'schedulingSupported',
    'notificationPermission',
    'preciseAlarmPermission',
    'refillChannelEnabled',
    'futureSchedulePresent',
    'reconciliationFailed',
    'callbackObserved',
    'posted',
    'humanReceipt',
  ];

  /// Audited notification channels ensuring lock-screen privacy.
  static final List<NotificationChannelRecord> notificationChannels = [
    NotificationChannelRecord(
      channelId: 'medicine_doses_v1',
      channelName: 'Medicine reminders',
      importance: 'Importance.high',
      priority: 'Priority.high',
      visibility: 'NotificationVisibility.private',
      lockScreenGuaranteesZeroPhi: true,
      payloadContainsMedicineName: false,
      payloadContainsDosage: false,
      deviceAuthRequiredForActions: true,
      sampleIntentPayload: {
        'owner': 'guest',
        'dose': 'med-uuid:1:2026-10-18:480',
        'due': '2026-10-18T08:00:00.000Z',
        'alert': '2026-10-18T08:00:00.000Z',
        'exact': true,
        'language': 'en',
      },
    ),
    NotificationChannelRecord(
      channelId: 'medicine_refills_v1',
      channelName: 'Refill reminders',
      importance: 'Importance.defaultImportance',
      priority: 'Priority.defaultPriority',
      visibility: 'NotificationVisibility.private',
      lockScreenGuaranteesZeroPhi: true,
      payloadContainsMedicineName: false,
      payloadContainsDosage: false,
      deviceAuthRequiredForActions: true,
      sampleIntentPayload: {
        'owner': 'guest',
        'refill': 'med-uuid',
      },
    ),
  ];

  /// OS backup extraction prevention and anti-exfiltration rules.
  static final List<DataExtractionRule> dataExtractionRules = [
    const DataExtractionRule(
      targetPlatform: 'Android',
      mechanism:
          'android:allowBackup="false" & data_extraction_rules.xml exclusions',
      cloudBackupExcluded: true,
      deviceTransferExcluded: true,
      excludedDomains: ['root', 'file', 'database', 'sharedpref', 'external'],
      hardwareKeyBound: true,
    ),
    const DataExtractionRule(
      targetPlatform: 'iOS',
      mechanism:
          'NSURLIsExcludedFromBackupKey & kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly',
      cloudBackupExcluded: true,
      deviceTransferExcluded: true,
      excludedDomains: ['Application Support', 'Documents', 'Caches'],
      hardwareKeyBound: true,
    ),
  ];

  /// Fully audited inventory of 20 dependencies from pubspec.yaml.
  static final List<AuditedDependency> auditedDependencies = [
    const AuditedDependency(
      packageName: 'flutter',
      version: 'SDK',
      license: 'BSD-3-Clause',
      functionalPurpose: 'Core UI framework, Skia rendering & widgets',
      hasNetworkAccess: false,
      hasThirdPartyTelemetry: false,
      dataAccessed: 'Local UI widget tree state',
      isLocalEngineDependency: true,
    ),
    const AuditedDependency(
      packageName: 'provider',
      version: '^6.1.5+1',
      license: 'MIT',
      functionalPurpose: 'In-memory state management & change notification',
      hasNetworkAccess: false,
      hasThirdPartyTelemetry: false,
      dataAccessed: 'In-memory models',
      isLocalEngineDependency: true,
    ),
    const AuditedDependency(
      packageName: 'go_router',
      version: '^14.8.1',
      license: 'BSD-3-Clause',
      functionalPurpose: 'Declarative URL routing & deep link dispatch',
      hasNetworkAccess: false,
      hasThirdPartyTelemetry: false,
      dataAccessed: 'Navigation route stack',
      isLocalEngineDependency: true,
    ),
    const AuditedDependency(
      packageName: 'sqflite_sqlcipher',
      version: '^3.4.1',
      license: 'MIT / BSD',
      functionalPurpose:
          'AES-256 encrypted SQLite database with PRAGMA secure_delete',
      hasNetworkAccess: false,
      hasThirdPartyTelemetry: false,
      dataAccessed: 'Encrypted medicine database payload',
      isLocalEngineDependency: true,
    ),
    const AuditedDependency(
      packageName: 'flutter_secure_storage',
      version: '^11.2.0',
      license: 'BSD-3-Clause',
      functionalPurpose:
          'Hardware Keystore (TEE/StrongBox) & iOS Keychain bridge',
      hasNetworkAccess: false,
      hasThirdPartyTelemetry: false,
      dataAccessed: 'Master database encryption key & reset sentinel',
      isLocalEngineDependency: true,
    ),
    const AuditedDependency(
      packageName: 'flutter_local_notifications',
      version: '^21.0.0',
      license: 'BSD-3-Clause',
      functionalPurpose:
          'Local AlarmManager & UNUserNotificationCenter scheduling',
      hasNetworkAccess: false,
      hasThirdPartyTelemetry: false,
      dataAccessed: 'Generic notification copy and occurrence IDs',
      isLocalEngineDependency: true,
    ),
    const AuditedDependency(
      packageName: 'flutter_timezone',
      version: '^5.1.1',
      license: 'Apache 2.0',
      functionalPurpose: 'System IANA timezone name resolution',
      hasNetworkAccess: false,
      hasThirdPartyTelemetry: false,
      dataAccessed: 'System timezone string (e.g., "Asia/Kolkata")',
      isLocalEngineDependency: true,
    ),
    const AuditedDependency(
      packageName: 'timezone',
      version: '^0.11.2',
      license: 'BSD-2-Clause',
      functionalPurpose: 'Offline Olson timezone database & chronobiology',
      hasNetworkAccess: false,
      hasThirdPartyTelemetry: false,
      dataAccessed: 'Local wall-clock datetimes',
      isLocalEngineDependency: true,
    ),
    const AuditedDependency(
      packageName: 'workmanager',
      version: '^0.10.10',
      license: 'MIT',
      functionalPurpose: 'Native periodic background alarm recovery',
      hasNetworkAccess: false,
      hasThirdPartyTelemetry: false,
      dataAccessed: 'Background execution trigger callback',
      isLocalEngineDependency: true,
    ),
    const AuditedDependency(
      packageName: 'pdf',
      version: '^3.12.0',
      license: 'Apache 2.0',
      functionalPurpose: 'Vector PDF clinical report generation',
      hasNetworkAccess: false,
      hasThirdPartyTelemetry: false,
      dataAccessed: 'Rasterized report canvas pages',
      isLocalEngineDependency: true,
    ),
    const AuditedDependency(
      packageName: 'printing',
      version: '^5.14.3',
      license: 'Apache 2.0',
      functionalPurpose: 'Native system share sheet PDF handoff',
      hasNetworkAccess: false,
      hasThirdPartyTelemetry: false,
      dataAccessed: 'Temporary PDF file URI',
      isLocalEngineDependency: true,
    ),
    const AuditedDependency(
      packageName: 'image',
      version: '4.8.0',
      license: 'Apache 2.0',
      functionalPurpose: 'Bitmap image encoding for multi-page PDF generation',
      hasNetworkAccess: false,
      hasThirdPartyTelemetry: false,
      dataAccessed: 'Raw pixel buffers in memory',
      isLocalEngineDependency: true,
    ),
    const AuditedDependency(
      packageName: 'shared_preferences',
      version: '^2.5.6',
      license: 'BSD-3-Clause',
      functionalPurpose: 'Plaintext settings storage (language & guest flag)',
      hasNetworkAccess: false,
      hasThirdPartyTelemetry: false,
      dataAccessed: 'Language code ("en", "hi") and guest boolean',
      isLocalEngineDependency: true,
    ),
    const AuditedDependency(
      packageName: 'path_provider',
      version: '^2.1.6',
      license: 'BSD-3-Clause',
      functionalPurpose: 'App-private sandbox directory resolution',
      hasNetworkAccess: false,
      hasThirdPartyTelemetry: false,
      dataAccessed: 'Filesystem directory paths',
      isLocalEngineDependency: true,
    ),
    const AuditedDependency(
      packageName: 'crypto',
      version: '^3.0.7',
      license: 'BSD-3-Clause',
      functionalPurpose: 'SHA-256 deterministic hashing for notification IDs',
      hasNetworkAccess: false,
      hasThirdPartyTelemetry: false,
      dataAccessed: 'Occurrence ID strings',
      isLocalEngineDependency: true,
    ),
    const AuditedDependency(
      packageName: 'uuid',
      version: '^4.5.3',
      license: 'MIT',
      functionalPurpose: 'UUID v4 identifier generation for records',
      hasNetworkAccess: false,
      hasThirdPartyTelemetry: false,
      dataAccessed: 'Pseudo-random UUID generation',
      isLocalEngineDependency: true,
    ),
    const AuditedDependency(
      packageName: 'cupertino_icons',
      version: '^1.0.8',
      license: 'MIT',
      functionalPurpose: 'Standard iOS iconography assets',
      hasNetworkAccess: false,
      hasThirdPartyTelemetry: false,
      dataAccessed: 'None',
      isLocalEngineDependency: true,
    ),
    const AuditedDependency(
      packageName: 'country_code_picker',
      version: '^3.3.0',
      license: 'MIT',
      functionalPurpose: 'Country dialing code dropdown selector',
      hasNetworkAccess: false,
      hasThirdPartyTelemetry: false,
      dataAccessed: 'UI selection state',
      isLocalEngineDependency: false,
    ),
    const AuditedDependency(
      packageName: 'app_links',
      version: '^6.3.3',
      license: 'MIT',
      functionalPurpose: 'Deep linking handler for Supabase auth callbacks',
      hasNetworkAccess: false,
      hasThirdPartyTelemetry: false,
      dataAccessed: 'Incoming URL intent',
      isLocalEngineDependency: false,
    ),
    const AuditedDependency(
      packageName: 'supabase_flutter',
      version: '^2.18.2',
      license: 'MIT',
      functionalPurpose: 'Optional cloud authentication & remote database SDK',
      hasNetworkAccess: true,
      hasThirdPartyTelemetry: false,
      dataAccessed: 'Account credentials (when explicitly signed in)',
      isLocalEngineDependency: false,
    ),
  ];

  /// Audited Android manifest permissions and prohibited permissions.
  static final List<ManifestPermissionRecord> manifestPermissions = [
    const ManifestPermissionRecord(
      platform: 'Android',
      permissionName: 'android.permission.POST_NOTIFICATIONS',
      protectionLevel: 'Runtime (Dangerous, API 33+)',
      operationalJustification:
          'Post dose and refill reminders to system notification shade',
      privacyRiskAndMitigation:
          'High visibility; mitigated via generic private notification copy',
      gracefulDegradationMode:
          'In-app banner warns reminders inactive; app functions normally',
      isStrictlyRequired: true,
      isProhibited: false,
    ),
    const ManifestPermissionRecord(
      platform: 'Android',
      permissionName: 'android.permission.SCHEDULE_EXACT_ALARM',
      protectionLevel: 'Special App Access (API 31+)',
      operationalJustification:
          'Fire dose alerts at exact prescribed clock times via setExactAndAllowWhileIdle',
      privacyRiskAndMitigation:
          'None; app does not abuse alarms, restricts strictly to prescribed doses',
      gracefulDegradationMode:
          'Degrades to AndroidScheduleMode.inexactAllowWhileIdle; warns of delay',
      isStrictlyRequired: true,
      isProhibited: false,
    ),
    const ManifestPermissionRecord(
      platform: 'Android',
      permissionName: 'android.permission.RECEIVE_BOOT_COMPLETED',
      protectionLevel: 'Normal',
      operationalJustification:
          'Restore scheduled alarms after device reboot via ReminderRecoveryReceiver',
      privacyRiskAndMitigation:
          'Zero external leakage; receiver reads encrypted DB after first unlock',
      gracefulDegradationMode:
          'Alarms fail to fire after reboot until user opens the app manually',
      isStrictlyRequired: true,
      isProhibited: false,
    ),
    const ManifestPermissionRecord(
      platform: 'Android',
      permissionName: 'android.permission.INTERNET',
      protectionLevel: 'Normal',
      operationalJustification:
          'Optional cloud authentication & password reset via Supabase',
      privacyRiskAndMitigation:
          'Local medicine engine never uses network; Guest mode is 100% offline',
      gracefulDegradationMode:
          'App operates with 100% offline functionality in Guest Mode',
      isStrictlyRequired: false,
      isProhibited: false,
    ),
    // Explicitly prohibited permissions
    const ManifestPermissionRecord(
      platform: 'Android',
      permissionName: 'android.permission.ACCESS_FINE_LOCATION',
      protectionLevel: 'Runtime (Dangerous)',
      operationalJustification:
          'PROHIBITED: App uses IANA timezone, not GPS coordinates',
      privacyRiskAndMitigation: 'Rejected by privacy policy',
      gracefulDegradationMode: 'N/A - Never requested',
      isStrictlyRequired: false,
      isProhibited: true,
    ),
    const ManifestPermissionRecord(
      platform: 'Android',
      permissionName: 'android.permission.READ_CONTACTS',
      protectionLevel: 'Runtime (Dangerous)',
      operationalJustification:
          'PROHIBITED: Care circle entries require manual phone entry',
      privacyRiskAndMitigation: 'Rejected by privacy policy',
      gracefulDegradationMode: 'N/A - Never requested',
      isStrictlyRequired: false,
      isProhibited: true,
    ),
    const ManifestPermissionRecord(
      platform: 'Android',
      permissionName: 'android.permission.CAMERA',
      protectionLevel: 'Runtime (Dangerous)',
      operationalJustification:
          'PROHIBITED: No OCR or pill scanning in release M0',
      privacyRiskAndMitigation: 'Rejected by privacy policy',
      gracefulDegradationMode: 'N/A - Never requested',
      isStrictlyRequired: false,
      isProhibited: true,
    ),
    const ManifestPermissionRecord(
      platform: 'Android',
      permissionName: 'android.permission.READ_EXTERNAL_STORAGE',
      protectionLevel: 'Runtime (Dangerous)',
      operationalJustification:
          'PROHIBITED: Storage is confined strictly to app-private sandbox',
      privacyRiskAndMitigation: 'Rejected by privacy policy',
      gracefulDegradationMode: 'N/A - Never requested',
      isStrictlyRequired: false,
      isProhibited: true,
    ),
  ];

  /// Comprehensive STRIDE threat models TH-01 through TH-08.
  static final List<StrideThreatModel> strideThreatModels = [
    const StrideThreatModel(
      threatId: 'TH-01',
      strideCategory: StrideCategory.informationDisclosure,
      title: 'Lost / stolen unlocked phone inspection',
      scenario:
          'Opportunistic bystander or thief accesses unlocked device and attempts to view prescriptions',
      inherentRisk: RiskLevel.high,
      residualRisk: RiskLevel.low,
      technicalMitigations: [
        'Generic lock-screen notification text ("Medicine reminder")',
        'NotificationVisibility.private prevents preview on lock screen',
        'Notification interactive action buttons ("Taken", "Snooze") require unlocking the device',
        'In-memory clinical models cleared upon process termination',
      ],
      verificationMethod:
          'Simulated lock-screen inspection and notification listener audit',
    ),
    const StrideThreatModel(
      threatId: 'TH-02',
      strideCategory: StrideCategory.informationDisclosure,
      title: 'Shared family and multi-user device snooping',
      scenario:
          'Family member or child sharing household tablet opens app and reads private medical history',
      inherentRisk: RiskLevel.high,
      residualRisk: RiskLevel.low,
      technicalMitigations: [
        'Guest mode isolated to dedicated "guest" profile key',
        'Multi-account segregation keys records by unique SHA-256 owner hash',
        'Switching accounts purges in-memory state and reloads from scratch',
        'Local reset requires explicit multi-step confirmation dialog',
      ],
      verificationMethod:
          'Multi-profile database partition test and session boundary tests',
    ),
    const StrideThreatModel(
      threatId: 'TH-03',
      strideCategory: StrideCategory.tampering,
      title: 'Malicious dependency / software supply chain compromise',
      scenario:
          'Hostile actor compromises open-source Flutter dependency and injects data exfiltration spyware',
      inherentRisk: RiskLevel.critical,
      residualRisk: RiskLevel.veryLow,
      technicalMitigations: [
        'Exact dependency version pinning in pubspec.lock',
        'Zero network access or dependencies in local medicine core engine',
        'Minimal audited dependency tree with zero commercial ad trackers',
        'Automated CI build verification and merged manifest audit',
      ],
      verificationMethod:
          'Dependency tree audit and network socket listener monitoring',
    ),
    const StrideThreatModel(
      threatId: 'TH-04',
      strideCategory: StrideCategory.spoofing,
      title: 'Android Intent spoofing and broadcast interception',
      scenario:
          'Malicious background app sends synthetic broadcast intents to fake compliance or disrupt alarms',
      inherentRisk: RiskLevel.high,
      residualRisk: RiskLevel.veryLow,
      technicalMitigations: [
        'Non-exported notification receivers (android:exported="false")',
        'Authoritative validation of occurrence ID and owner partition key',
        'State verification rejecting actions on completed or archived doses',
        'Unparseable or spoofed payloads are silently dropped without data mutation',
      ],
      verificationMethod:
          'Synthetic intent broadcast testing and AndroidManifest receiver audit',
    ),
    const StrideThreatModel(
      threatId: 'TH-05',
      strideCategory: StrideCategory.informationDisclosure,
      title: 'Notification Listener service eavesdropping',
      scenario:
          'Rogue utility app requests BIND_NOTIFICATION_LISTENER_SERVICE to spy on reminder text',
      inherentRisk: RiskLevel.critical,
      residualRisk: RiskLevel.zero,
      technicalMitigations: [
        'Notification titles contain zero medicine names ("Medicine reminder")',
        'Notification bodies contain zero dosages or instructions',
        'All visible text is strictly generic and identical across all medications',
      ],
      verificationMethod:
          'Notification payload inspection and string assertion tests',
    ),
    const StrideThreatModel(
      threatId: 'TH-06',
      strideCategory: StrideCategory.informationDisclosure,
      title: 'Clipboard snooping during diagnostic export',
      scenario:
          'Malicious clipboard manager logs copied diagnostic bundle to exfiltrate patient data',
      inherentRisk: RiskLevel.medium,
      residualRisk: RiskLevel.zero,
      technicalMitigations: [
        'Diagnostic bundle strictly restricted to 11 allowlisted readiness keys',
        'Zero PHI, medicine names, occurrence IDs, dates, or error strings',
        'Preview dialog is read-only; clipboard write occurs only on explicit button tap',
      ],
      verificationMethod:
          'Allowlist property verification test and clipboard mutation tests',
    ),
    const StrideThreatModel(
      threatId: 'TH-07',
      strideCategory: StrideCategory.informationDisclosure,
      title: 'OS backup extraction and cloud sync leakage',
      scenario:
          'Extraction of unencrypted database via ADB backup, migration cables, or Google Drive sync',
      inherentRisk: RiskLevel.critical,
      residualRisk: RiskLevel.veryLow,
      technicalMitigations: [
        'android:allowBackup="false" and android:fullBackupContent="false"',
        'data_extraction_rules.xml excludes all 5 storage domains',
        'SQLCipher AES-256-GCM database encryption with 256,000 PBKDF2 iterations',
        'Master key anchored in hardware Keystore/Keychain with ThisDeviceOnly attribute',
      ],
      verificationMethod:
          'ADB backup trial execution and data extraction rules XML verification',
    ),
    const StrideThreatModel(
      threatId: 'TH-08',
      strideCategory: StrideCategory.informationDisclosure,
      title: 'Forensic flash memory extraction and cold-boot attacks',
      scenario:
          'Adversary desolders NAND flash memory chip or executes DRAM cold-boot attack in lab',
      inherentRisk: RiskLevel.high,
      residualRisk: RiskLevel.low,
      technicalMitigations: [
        'SQLCipher page-level encryption prevents plaintext database carving',
        'PRAGMA secure_delete = ON actively overwrites deleted rows with zeroes',
        'Hardware Keystore keys inaccessible from raw flash memory chips',
        'Volatile in-memory key buffers held only during active database session',
      ],
      verificationMethod:
          'SQLite pragma configuration inspection and secure delete unit tests',
    ),
  ];

  /// Staged commencement schedule under MeitY Gazette Notification G.S.R. 843(E).
  static final List<DpdpCommencementStage> dpdpCommencementStages = [
    DpdpCommencementStage(
      stageNumber: 1,
      gazetteNotification: 'G.S.R. 843(E) dated 13 November 2025',
      publicationDate: DateTime.utc(2025, 11, 13),
      effectiveDate: DateTime.utc(2025, 11, 13),
      statutorySections: [
        'Section 1',
        'Section 2',
        'Sections 18-26 (DPBI Establishment)',
        'Section 40 (Rulemaking)',
      ],
      description:
          'Institutional framework commencement: establishment and composition of Data Protection Board of India (DPBI), definitions, and rulemaking powers.',
      isMandatoryBeforeProduction: true,
    ),
    DpdpCommencementStage(
      stageNumber: 2,
      gazetteNotification: 'G.S.R. 843(E) dated 13 November 2025',
      publicationDate: DateTime.utc(2025, 11, 13),
      effectiveDate: DateTime.utc(2026, 11, 13),
      statutorySections: [
        'Section 6(9)',
        'Section 27(1)(d)',
      ],
      description:
          'Consent Managers regulatory framework commencement (12 months post-publication).',
      isMandatoryBeforeProduction: true,
    ),
    DpdpCommencementStage(
      stageNumber: 3,
      gazetteNotification: 'G.S.R. 843(E) dated 13 November 2025',
      publicationDate: DateTime.utc(2025, 11, 13),
      effectiveDate: DateTime.utc(2027, 5, 13),
      statutorySections: [
        'Sections 4-17 (Data Fiduciary obligations, Rights of Data Principals)',
        'Sections 27-34 (Adjudication, Appeals, Penalties)',
        'Schedule (Financial penalties up to ₹250 crore)',
      ],
      description:
          'Substantive compliance mandates, Data Fiduciary obligations, Data Principal rights, and statutory penalties (18 months post-publication).',
      isMandatoryBeforeProduction: true,
    ),
  ];

  /// Comprehensive India DPDP Act compliance obligations and architectural mappings.
  static final List<DpdpComplianceObligation> dpdpObligations = [
    const DpdpComplianceObligation(
      sectionRef: 'Section 3(c)(i)',
      title:
          'Domestic & Personal Purpose Exemption vs Developer Fiduciary Status',
      statutoryRequirement:
          'Act does not apply to processing by an individual for personal or domestic purposes.',
      architecturalImplementation:
          'Local-only zero-cloud architecture means patient processes data purely domestically. Developer does not receive, access, or store PHI, preventing developer from becoming a Data Fiduciary for local clinical regimens.',
      appliesToLocalOfflineMode: false,
      verifiedLanguages: ['en', 'hi'],
      maximumPenaltyInrCrore: 0.0,
    ),
    const DpdpComplianceObligation(
      sectionRef: 'Section 5',
      title: 'Itemized Multilingual Notice Prior to Processing',
      statutoryRequirement:
          'Notice must explain personal data to be processed, purpose, and rights, available in English or 8th Schedule languages.',
      architecturalImplementation:
          'Local Welcome Card and in-app privacy notices provided in verified English and Hindi (8th Schedule language) using bundled Noto Sans Devanagari.',
      appliesToLocalOfflineMode: true,
      verifiedLanguages: ['en', 'hi'],
      maximumPenaltyInrCrore: 50.0,
    ),
    const DpdpComplianceObligation(
      sectionRef: 'Section 6',
      title: 'Specific, Informed & Unambiguous Affirmative Consent',
      statutoryRequirement:
          'Consent must be unconditional, clear affirmative action, and freely revocable.',
      architecturalImplementation:
          'Zero pre-checked consent boxes; guest mode provides 100% utility without requiring identity registration or account consent.',
      appliesToLocalOfflineMode: true,
      verifiedLanguages: ['en', 'hi'],
      maximumPenaltyInrCrore: 50.0,
    ),
    const DpdpComplianceObligation(
      sectionRef: 'Section 8(5)',
      title: 'Reasonable Security Safeguards to Prevent Data Breach',
      statutoryRequirement:
          'Data Fiduciary must implement reasonable security safeguards to prevent personal data breach.',
      architecturalImplementation:
          'SQLCipher AES-256 database encryption, hardware Keystore key protection, disabled OS backups, and generic notification text.',
      appliesToLocalOfflineMode: true,
      verifiedLanguages: ['en', 'hi'],
      maximumPenaltyInrCrore: 250.0,
    ),
    const DpdpComplianceObligation(
      sectionRef: 'Section 9',
      title: 'Processing of Personal Data of Children',
      statutoryRequirement:
          'Requires verifiable parental consent; strictly prohibits behavioral tracking and targeted advertising directed at children.',
      architecturalImplementation:
          'Zero ad trackers, zero telemetry SDKs, and zero profiling guarantee 100% compliance with Section 9(3). Pediatric doses remain on local device under domestic parental control.',
      appliesToLocalOfflineMode: true,
      verifiedLanguages: ['en', 'hi'],
      maximumPenaltyInrCrore: 200.0,
    ),
    const DpdpComplianceObligation(
      sectionRef: 'Sections 11-14',
      title:
          'Rights of Data Principals (Access, Correction, Erasure, Grievance)',
      statutoryRequirement:
          'Data Principals have statutory rights to access summary, correct inaccuracies, erase data, and access grievance redressal.',
      architecturalImplementation:
          'Direct UI access to all regimens and dose history; full editing and bi-temporal revisions; cascading deletion of individual medications; atomic resetAll() local erasure; Grievance Officer contact in notice.',
      appliesToLocalOfflineMode: true,
      verifiedLanguages: ['en', 'hi'],
      maximumPenaltyInrCrore: 50.0,
    ),
    const DpdpComplianceObligation(
      sectionRef: 'Section 16',
      title: 'Cross-Border Personal Data Transfer Governance',
      statutoryRequirement:
          'Personal data transfers outside India subject to Central Government negative list.',
      architecturalImplementation:
          'Zero cross-border transfer in local mode; all data resides on device flash memory. Future cloud Supabase cluster must reside in AWS Mumbai (ap-south-1).',
      appliesToLocalOfflineMode: true,
      verifiedLanguages: ['en', 'hi'],
      maximumPenaltyInrCrore: 50.0,
    ),
  ];

  /// Approved legal and clinical disclaimers and regulatory prohibitions.
  static const RegulatoryDisclaimerSpecification regulatoryDisclaimers =
      RegulatoryDisclaimerSpecification(
    approvedClinicalDisclaimer:
        'Self-reported records. This software provides reminders and record-keeping only. '
        'It does not provide medical advice, diagnosis, or treatment recommendations. '
        'Always consult a qualified healthcare professional regarding medication regimens.',
    samdClassification:
        'Non-Device / Class A Passive Adherence Log (CDSCO Medical Devices Rules 2017)',
    hipaaCompliantClaimProhibited: true,
    gdprCertifiedClaimProhibited: true,
    fdaApprovedClaimProhibited: true,
    certInReportingWindowHours: 6,
    certInReportingEmail: 'incident@cert-in.org.in',
  );

  /// The 6 operational governance roles.
  static final List<GovernanceRole> governanceRoles = [
    const GovernanceRole(
      code: 'PSL',
      title: 'Platform Security Lead',
      primaryResponsibilities:
          'Cryptographic architecture, hardware Keystore integration, database encryption, and OS security boundaries.',
    ),
    const GovernanceRole(
      code: 'MPL',
      title: 'Mobile Platform Lead',
      primaryResponsibilities:
          'Android & iOS native bridges, manifest permissions, background alarms, and build configuration hardening.',
    ),
    const GovernanceRole(
      code: 'PLO',
      title: 'Privacy & Legal Officer',
      primaryResponsibilities:
          'Statutory compliance (DPDP Act, IT Act, SPDI Rules), privacy notices, and CERT-In regulatory breach reporting.',
    ),
    const GovernanceRole(
      code: 'PO',
      title: 'Product Owner',
      primaryResponsibilities:
          'Product scope governance, zero-cloud feature boundary preservation, and user experience.',
    ),
    const GovernanceRole(
      code: 'CSO',
      title: 'Clinical Safety Officer',
      primaryResponsibilities:
          'Clinical disclaimer verification, medical terminology validation, and SaMD non-device boundary preservation.',
    ),
    const GovernanceRole(
      code: 'QAL',
      title: 'QA & Reliability Lead',
      primaryResponsibilities:
          'Verification test suites, hardware security audits, regression test gates, and pre-flight release readiness.',
    ),
  ];

  /// The 9 core RACI governance assignments covering all operational pillars.
  static final List<RaciAssignment> raciMatrix = [
    const RaciAssignment(
      governanceArea: 'Pillar 1: Encryption Architecture',
      accountableRoleCode: 'PSL',
      responsibleRoleCodes: ['PSL'],
      consultedRoleCodes: ['MPL', 'PLO', 'QAL'],
      informedRoleCodes: ['PO', 'CSO'],
      operationalSpecifications: [
        'SQLCipher AES-256-GCM database encryption with 256,000 PBKDF2 iterations',
        '256-bit cryptographically secure database key generated via Random.secure()',
        'Master key anchored in hardware Keystore/Keychain, never logged to disk or console',
        'All write transactions enforce PRAGMA secure_delete = ON to overwrite freed pages',
        'Memory buffers held in volatile RAM only during active store session',
      ],
    ),
    const RaciAssignment(
      governanceArea: 'Pillar 2: Key Recovery & Data Loss Policy',
      accountableRoleCode: 'PSL',
      responsibleRoleCodes: ['PSL', 'MPL'],
      consultedRoleCodes: ['PLO', 'PO', 'QAL'],
      informedRoleCodes: ['CSO'],
      operationalSpecifications: [
        'Zero backdoor / zero cloud escrow policy for local master keys',
        'Transparent user notification: device loss means local data cannot be recovered',
        'Corrupt database files must never be silently wiped or overwritten',
        'Halt mutations upon database error, preserving file for triage',
        'Deletion occurs only upon explicit user confirmation of "Erase all data"',
      ],
    ),
    const RaciAssignment(
      governanceArea: 'Pillar 3: Consent & Notice Management',
      accountableRoleCode: 'PLO',
      responsibleRoleCodes: ['PLO'],
      consultedRoleCodes: ['PSL', 'MPL', 'CSO', 'QAL'],
      informedRoleCodes: ['PO'],
      operationalSpecifications: [
        'Itemized layered privacy notice accessible in-app and on website',
        'Notices provided in English and Hindi matching DPDP Act Section 5(3)',
        'Runtime permission prompts include pre-permission educational dialogs',
        'Guest mode preserved as equal-first-class citizen without registration gates',
      ],
    ),
    const RaciAssignment(
      governanceArea: 'Pillar 4: Data Retention & Atomic Erasure',
      accountableRoleCode: 'MPL',
      responsibleRoleCodes: ['MPL', 'PSL'],
      consultedRoleCodes: ['PLO', 'PO'],
      informedRoleCodes: ['CSO', 'QAL'],
      operationalSpecifications: [
        'Data minimization: no demographic attributes or diagnostic codes stored',
        'Cascading deletion of individual medications, historical revisions, and alarms',
        'Atomic reset writes durable marker medicine.reset.pending.v1 in secure storage',
        'Reset cancels all alarms, drops tables with secure_delete, deletes DB & Keystore keys',
        'Crash recovery: next app launch detects marker and finishes reset before opening data',
      ],
    ),
    const RaciAssignment(
      governanceArea: 'Pillar 5: Breach Handling & CERT-In Protocol',
      accountableRoleCode: 'PLO',
      responsibleRoleCodes: ['PLO', 'PSL'],
      consultedRoleCodes: ['MPL', 'PO'],
      informedRoleCodes: ['CSO', 'QAL'],
      operationalSpecifications: [
        'Statutory personal data breach definition under DPDP Act Section 2(u)',
        'Mandatory reporting to CERT-In (incident@cert-in.org.in) within 6 hours of detection',
        'Incident Commander notifies PLO within 1 hour of breach triage',
        'Data Protection Board of India (DPBI) and user breach advisory protocol',
        'Integration with SUPPORT-RUNBOOK.md and SUPPORT-INCIDENT-TEMPLATE.md',
      ],
    ),
    const RaciAssignment(
      governanceArea: 'Pillar 6: Future Cloud Access Governance (E2EE)',
      accountableRoleCode: 'PSL',
      responsibleRoleCodes: ['PSL', 'MPL'],
      consultedRoleCodes: ['PLO', 'PO'],
      informedRoleCodes: ['CSO', 'QAL'],
      operationalSpecifications: [
        'Client-side key derivation using Argon2id with unique local salt',
        'Zero plaintext health data stored in Supabase cloud PostgreSQL backend',
        'Zero-knowledge architecture: server providers cannot decrypt patient health data',
        'Caregiver sharing uses asymmetric public-key cryptography (X25519/Libsodium)',
      ],
    ),
    const RaciAssignment(
      governanceArea: 'Manifest & Permission Minimization',
      accountableRoleCode: 'MPL',
      responsibleRoleCodes: ['MPL'],
      consultedRoleCodes: ['PSL', 'PLO', 'PO'],
      informedRoleCodes: ['CSO', 'QAL'],
      operationalSpecifications: [
        'Audit Android manifest for strict minimal permissions (POST_NOTIFICATIONS, EXACT_ALARM, BOOT_COMPLETED)',
        'Strictly prohibit location, camera, contacts, and external storage permissions',
        'Verify iOS Info.plist contains zero sensitive permission usage descriptions',
        'Verify Apple Privacy Manifest declares zero tracking and zero collected data types',
      ],
    ),
    const RaciAssignment(
      governanceArea: 'Diagnostic Bundle Redaction & Auditing',
      accountableRoleCode: 'PSL',
      responsibleRoleCodes: ['PSL', 'MPL'],
      consultedRoleCodes: ['PLO', 'QAL'],
      informedRoleCodes: ['PO', 'CSO'],
      operationalSpecifications: [
        'reminderDiagnostics() strictly restricted to 11 allowlisted readiness flags',
        'Zero medication names, doses, occurrence IDs, or stack traces serialized',
        'On-demand user mediation in Settings; read-only preview before copy',
      ],
    ),
    const RaciAssignment(
      governanceArea: 'Clinical Disclaimer & SaMD Boundaries',
      accountableRoleCode: 'CSO',
      responsibleRoleCodes: ['CSO'],
      consultedRoleCodes: ['PLO', 'PO', 'QAL'],
      informedRoleCodes: ['PSL', 'MPL'],
      operationalSpecifications: [
        'Display approved clinical disclaimer on onboarding, PDF reports, and settings',
        'Enforce passive adherence logging classification (CDSCO Medical Devices Rules 2017)',
        'Strictly prohibit false marketing claims of HIPAA Compliance or GDPR Certification',
      ],
    ),
  ];

  /// Validates that all stored fields dictionary records meet encryption and backup standards.
  static bool validateStoredFieldsCompliance() {
    for (final field in storedFieldsDictionary) {
      if (field.containsPhiOrSpdi && !field.isCompliantAtRest) {
        return false;
      }
    }
    return true;
  }

  /// Validates that all audited dependencies are free of commercial third-party telemetry.
  static bool validateNoTelemetryTrackers() {
    for (final dep in auditedDependencies) {
      if (dep.hasThirdPartyTelemetry) {
        return false;
      }
    }
    return true;
  }

  /// Validates that all notification channels enforce lock-screen privacy.
  static bool validateNotificationChannelsPrivacy() {
    for (final channel in notificationChannels) {
      if (!channel.compliesWithLockScreenPrivacy) {
        return false;
      }
    }
    return true;
  }

  /// Validates that all STRIDE threats have acceptable residual risk.
  static bool validateStrideResidualRisks() {
    for (final threat in strideThreatModels) {
      if (!threat.isResidualRiskAcceptable) {
        return false;
      }
    }
    return true;
  }
}
