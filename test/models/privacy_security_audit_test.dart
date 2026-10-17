import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_reminder/core/models/privacy_security_audit.dart';

void main() {
  group(
      'Stored Fields Data Dictionary & Data Map Invariants (Issue #38 / MED-028)',
      () {
    test('Dictionary contains all storage silos and stored attributes', () {
      final fields = PrivacySecurityAuditFixtures.storedFieldsDictionary;
      expect(fields.isNotEmpty, isTrue);

      final silos = fields.map((f) => f.storageSilo).toSet();
      expect(silos, contains(StorageSiloType.sqlCipherDatabase));
      expect(silos, contains(StorageSiloType.hardwareKeystore));
      expect(silos, contains(StorageSiloType.plaintextPreferences));
      expect(silos, contains(StorageSiloType.osNotificationCenter));
      expect(silos, contains(StorageSiloType.tempFileSystem));
      expect(silos, contains(StorageSiloType.volatileMemory));
    });

    test(
        'Strict Invariant: All High & Medium SPDI fields are encrypted at rest and excluded from backup',
        () {
      expect(PrivacySecurityAuditFixtures.validateStoredFieldsCompliance(),
          isTrue);

      for (final field in PrivacySecurityAuditFixtures.storedFieldsDictionary) {
        if (field.containsPhiOrSpdi) {
          // If stored on disk permanently (SQLCipher DB), it MUST be encrypted at rest and excluded from backup
          if (field.storageSilo == StorageSiloType.sqlCipherDatabase) {
            expect(field.isEncryptedAtRest, isTrue,
                reason:
                    'Field ${field.fieldPath} contains health data but is not encrypted at rest');
            expect(field.isExcludedFromBackup, isTrue,
                reason:
                    'Field ${field.fieldPath} contains health data but is not excluded from backup');
          }
        }
      }
    });

    test('Plaintext Preferences strictly prohibit health data and PHI', () {
      final plaintextFields = PrivacySecurityAuditFixtures
          .storedFieldsDictionary
          .where((f) => f.storageSilo == StorageSiloType.plaintextPreferences)
          .toList();

      expect(plaintextFields.isNotEmpty, isTrue);
      for (final field in plaintextFields) {
        expect(field.containsPhiOrSpdi, isFalse,
            reason:
                'Plaintext preference ${field.fieldPath} must not contain health data');
        expect(field.sensitivity, DataSensitivityLevel.low);
        expect(field.isExcludedFromBackup, isTrue);
      }

      final keys = plaintextFields.map((f) => f.fieldPath).toSet();
      expect(keys, contains('medicine_app_language_override'));
      expect(keys, contains('is_guest_mode'));
      expect(keys, contains('onboarding_completed_local'));
    });

    test(
        'Hardware Keystore keys are strictly categorized and excluded from backup',
        () {
      final keystoreFields = PrivacySecurityAuditFixtures.storedFieldsDictionary
          .where((f) => f.storageSilo == StorageSiloType.hardwareKeystore)
          .toList();

      final paths = keystoreFields.map((f) => f.fieldPath).toSet();
      expect(paths, contains('medicine.database.key.v1'));
      expect(paths, contains('medicine.active.v1'));
      expect(paths, contains('medicine.reset.pending.v1'));
      expect(paths, contains('sb-<id>-auth-token'));

      final dbKey = keystoreFields
          .firstWhere((f) => f.fieldPath == 'medicine.database.key.v1');
      expect(dbKey.sensitivity, DataSensitivityLevel.criticalSecret);
      expect(dbKey.isEncryptedAtRest, isTrue);
      expect(dbKey.isExcludedFromBackup, isTrue);
    });

    test(
        'Diagnostic allowlist invariant: strictly the 11 allowlisted readiness flags',
        () {
      final diagFields = PrivacySecurityAuditFixtures.storedFieldsDictionary
          .where((f) => f.allowlistedInDiagnostics)
          .toList();

      expect(diagFields.length,
          12); // 1 schema + 1 scope + 1 remoteTelemetry + 9 operational flags

      final canonicalKeys =
          PrivacySecurityAuditFixtures.diagnosticAllowlistKeys;
      expect(canonicalKeys.length, 12);

      for (final field in diagFields) {
        final keyName =
            field.fieldPath.replaceFirst('reminderDiagnostics.', '');
        expect(canonicalKeys.contains(keyName), isTrue,
            reason: 'Diagnostic key $keyName not in canonical allowlist');
        expect(field.sensitivity, DataSensitivityLevel.low,
            reason: 'Diagnostic fields must have low sensitivity and zero PHI');
        expect(field.containsPhiOrSpdi, isFalse);
      }
    });

    test(
        'StoredFieldRecord JSON round-trip serialization preserves all attributes',
        () {
      for (final field in PrivacySecurityAuditFixtures.storedFieldsDictionary) {
        final json = field.toJson();
        final reconstituted = StoredFieldRecord.fromJson(json);

        expect(reconstituted.fieldPath, field.fieldPath);
        expect(reconstituted.storageSilo, field.storageSilo);
        expect(reconstituted.tableNameOrKey, field.tableNameOrKey);
        expect(reconstituted.dataType, field.dataType);
        expect(reconstituted.sensitivity, field.sensitivity);
        expect(reconstituted.rationale, field.rationale);
        expect(reconstituted.isEncryptedAtRest, field.isEncryptedAtRest);
        expect(reconstituted.isExcludedFromBackup, field.isExcludedFromBackup);
        expect(reconstituted.allowlistedInDiagnostics,
            field.allowlistedInDiagnostics);
      }
    });
  });

  group('Audited Dependency & SDK Inventory (Issue #38 / MED-028)', () {
    test('Complete inventory contains exactly 20 audited dependencies', () {
      final deps = PrivacySecurityAuditFixtures.auditedDependencies;
      expect(deps.length, 20);

      final names = deps.map((d) => d.packageName).toSet();
      expect(
          names,
          containsAll([
            'flutter',
            'provider',
            'go_router',
            'sqflite_sqlcipher',
            'flutter_secure_storage',
            'flutter_local_notifications',
            'flutter_timezone',
            'timezone',
            'workmanager',
            'pdf',
            'printing',
            'image',
            'shared_preferences',
            'path_provider',
            'crypto',
            'uuid',
            'cupertino_icons',
            'country_code_picker',
            'app_links',
            'supabase_flutter',
          ]));
    });

    test(
        'Zero-Telemetry Invariant: 100% of dependencies have zero commercial tracking SDKs',
        () {
      expect(
          PrivacySecurityAuditFixtures.validateNoTelemetryTrackers(), isTrue);

      final prohibitedTrackers = [
        'firebase',
        'appsflyer',
        'facebook',
        'mixpanel',
        'sentry',
        'flurry',
        'braze',
      ];

      for (final dep in PrivacySecurityAuditFixtures.auditedDependencies) {
        expect(dep.hasThirdPartyTelemetry, isFalse,
            reason:
                'Dependency ${dep.packageName} must not have third-party telemetry');
        expect(dep.isTelemetryFree, isTrue);

        for (final tracker in prohibitedTrackers) {
          expect(dep.packageName.toLowerCase().contains(tracker), isFalse,
              reason:
                  'Prohibited tracker found in dependency: ${dep.packageName}');
        }
      }
    });

    test('Local engine dependencies have zero network egress', () {
      final localDeps = PrivacySecurityAuditFixtures.auditedDependencies
          .where((d) => d.isLocalEngineDependency)
          .toList();

      expect(localDeps.isNotEmpty, isTrue);
      for (final dep in localDeps) {
        expect(dep.hasNetworkAccess, isFalse,
            reason:
                'Local engine dependency ${dep.packageName} must not have network access');
      }

      // Only cloud-optional dependencies may declare network access
      final cloudDeps = PrivacySecurityAuditFixtures.auditedDependencies
          .where((d) => !d.isLocalEngineDependency)
          .toList();
      final networkCloudDeps =
          cloudDeps.where((d) => d.hasNetworkAccess).toList();
      expect(networkCloudDeps.length, 1);
      expect(networkCloudDeps.single.packageName, 'supabase_flutter');
    });

    test('AuditedDependency JSON round-trip serialization preserves all fields',
        () {
      for (final dep in PrivacySecurityAuditFixtures.auditedDependencies) {
        final json = dep.toJson();
        final reconstituted = AuditedDependency.fromJson(json);

        expect(reconstituted.packageName, dep.packageName);
        expect(reconstituted.version, dep.version);
        expect(reconstituted.license, dep.license);
        expect(reconstituted.functionalPurpose, dep.functionalPurpose);
        expect(reconstituted.hasNetworkAccess, dep.hasNetworkAccess);
        expect(
            reconstituted.hasThirdPartyTelemetry, dep.hasThirdPartyTelemetry);
        expect(reconstituted.dataAccessed, dep.dataAccessed);
        expect(
            reconstituted.isLocalEngineDependency, dep.isLocalEngineDependency);
      }
    });
  });

  group(
      'Manifest Permissions, Backup Exclusions & Lock-Screen Privacy (Issue #38 / MED-028)',
      () {
    test(
        'Manifest permission audit: 4 declared minimal permissions + prohibited list',
        () {
      final perms = PrivacySecurityAuditFixtures.manifestPermissions;
      expect(perms.isNotEmpty, isTrue);

      final declared = perms.where((p) => !p.isProhibited).toList();
      expect(declared.length, 4);

      final declaredNames = declared.map((p) => p.permissionName).toSet();
      expect(
          declaredNames,
          containsAll([
            'android.permission.POST_NOTIFICATIONS',
            'android.permission.SCHEDULE_EXACT_ALARM',
            'android.permission.RECEIVE_BOOT_COMPLETED',
            'android.permission.INTERNET',
          ]));

      final prohibited = perms.where((p) => p.isProhibited).toList();
      expect(prohibited.length, 4);
      final prohibitedNames = prohibited.map((p) => p.permissionName).toSet();
      expect(
          prohibitedNames, contains('android.permission.ACCESS_FINE_LOCATION'));
      expect(prohibitedNames, contains('android.permission.READ_CONTACTS'));
      expect(prohibitedNames, contains('android.permission.CAMERA'));
      expect(prohibitedNames,
          contains('android.permission.READ_EXTERNAL_STORAGE'));
    });

    test('OS Backup extraction prevention covers both Android and iOS', () {
      final rules = PrivacySecurityAuditFixtures.dataExtractionRules;
      expect(rules.length, 2);

      final androidRule =
          rules.firstWhere((r) => r.targetPlatform == 'Android');
      expect(androidRule.cloudBackupExcluded, isTrue);
      expect(androidRule.deviceTransferExcluded, isTrue);
      expect(androidRule.hardwareKeyBound, isTrue);
      expect(androidRule.excludedDomains,
          containsAll(['root', 'file', 'database', 'sharedpref', 'external']));
      expect(androidRule.providesCompleteExtractionDefense, isTrue);

      final iosRule = rules.firstWhere((r) => r.targetPlatform == 'iOS');
      expect(iosRule.cloudBackupExcluded, isTrue);
      expect(iosRule.deviceTransferExcluded, isTrue);
      expect(iosRule.hardwareKeyBound, isTrue);
      expect(iosRule.providesCompleteExtractionDefense, isTrue);
    });

    test(
        'Notification channels guarantee lock-screen privacy and zero PHI disclosure',
        () {
      expect(PrivacySecurityAuditFixtures.validateNotificationChannelsPrivacy(),
          isTrue);

      for (final channel in PrivacySecurityAuditFixtures.notificationChannels) {
        expect(channel.lockScreenGuaranteesZeroPhi, isTrue);
        expect(channel.payloadContainsMedicineName, isFalse);
        expect(channel.payloadContainsDosage, isFalse);
        expect(channel.visibility, 'NotificationVisibility.private');
        expect(channel.isPrivateVisibility, isTrue);
        expect(channel.compliesWithLockScreenPrivacy, isTrue);
        expect(channel.deviceAuthRequiredForActions, isTrue);
      }
    });

    test(
        'Serialization round-trip for permissions, extraction rules, and channels',
        () {
      final perm = PrivacySecurityAuditFixtures.manifestPermissions.first;
      expect(ManifestPermissionRecord.fromJson(perm.toJson()).permissionName,
          perm.permissionName);

      final rule = PrivacySecurityAuditFixtures.dataExtractionRules.first;
      expect(DataExtractionRule.fromJson(rule.toJson()).targetPlatform,
          rule.targetPlatform);

      final channel = PrivacySecurityAuditFixtures.notificationChannels.first;
      expect(NotificationChannelRecord.fromJson(channel.toJson()).channelId,
          channel.channelId);
    });
  });

  group(
      'Comprehensive STRIDE Threat Models TH-01 to TH-08 (Issue #38 / MED-028)',
      () {
    test('STRIDE matrix contains exactly 8 defined threat models', () {
      final threats = PrivacySecurityAuditFixtures.strideThreatModels;
      expect(threats.length, 8);

      final ids = threats.map((t) => t.threatId).toList();
      for (var i = 1; i <= 8; i++) {
        final expectedId = 'TH-${i.toString().padLeft(2, '0')}';
        expect(ids.contains(expectedId), isTrue,
            reason: 'Threat ID $expectedId missing');
      }
    });

    test(
        'All STRIDE threats have acceptable residual risks (Residual Risk <= Low)',
        () {
      expect(
          PrivacySecurityAuditFixtures.validateStrideResidualRisks(), isTrue);

      for (final threat in PrivacySecurityAuditFixtures.strideThreatModels) {
        expect(threat.isResidualRiskAcceptable, isTrue,
            reason:
                'Threat ${threat.threatId} has unacceptable residual risk: ${threat.residualRisk.label}');
        expect(threat.technicalMitigations.isNotEmpty, isTrue);
        expect(threat.verificationMethod.isNotEmpty, isTrue);
      }

      // TH-05 (Notification eavesdropping) and TH-06 (Clipboard snooping) must achieve zero residual risk
      final th05 = PrivacySecurityAuditFixtures.strideThreatModels
          .firstWhere((t) => t.threatId == 'TH-05');
      expect(th05.residualRisk, RiskLevel.zero);

      final th06 = PrivacySecurityAuditFixtures.strideThreatModels
          .firstWhere((t) => t.threatId == 'TH-06');
      expect(th06.residualRisk, RiskLevel.zero);
    });

    test(
        'STRIDE Threat Model JSON round-trip serialization preserves all fields',
        () {
      for (final threat in PrivacySecurityAuditFixtures.strideThreatModels) {
        final json = threat.toJson();
        final reconstituted = StrideThreatModel.fromJson(json);

        expect(reconstituted.threatId, threat.threatId);
        expect(reconstituted.strideCategory, threat.strideCategory);
        expect(reconstituted.title, threat.title);
        expect(reconstituted.scenario, threat.scenario);
        expect(reconstituted.inherentRisk, threat.inherentRisk);
        expect(reconstituted.residualRisk, threat.residualRisk);
        expect(reconstituted.technicalMitigations, threat.technicalMitigations);
        expect(reconstituted.verificationMethod, threat.verificationMethod);
      }
    });
  });

  group(
      'India DPDP Act 2023 & Regulatory Compliance Baseline (Issue #38 / MED-028)',
      () {
    test(
        'Official Gazette G.S.R. 843(E) staged commencement timeline has 3 stages',
        () {
      final stages = PrivacySecurityAuditFixtures.dpdpCommencementStages;
      expect(stages.length, 3);

      final stage1 = stages.firstWhere((s) => s.stageNumber == 1);
      expect(stage1.effectiveDate, DateTime.utc(2025, 11, 13));
      expect(stage1.gazetteNotification, contains('G.S.R. 843(E)'));
      expect(stage1.isMandatoryBeforeProduction, isTrue);

      final stage2 = stages.firstWhere((s) => s.stageNumber == 2);
      expect(stage2.effectiveDate, DateTime.utc(2026, 11, 13));
      expect(stage2.statutorySections, contains('Section 6(9)'));

      final stage3 = stages.firstWhere((s) => s.stageNumber == 3);
      expect(stage3.effectiveDate, DateTime.utc(2027, 5, 13));
      expect(
          stage3.statutorySections.any((s) => s.contains('Schedule')), isTrue);
    });

    test(
        'DPDP statutory obligations analyze domestic exemption, notice, consent, children, and rights',
        () {
      final obligations = PrivacySecurityAuditFixtures.dpdpObligations;
      expect(obligations.length, 7);

      final sections = obligations.map((o) => o.sectionRef).toSet();
      expect(sections, contains('Section 3(c)(i)'));
      expect(sections, contains('Section 5'));
      expect(sections, contains('Section 6'));
      expect(sections, contains('Section 8(5)'));
      expect(sections, contains('Section 9'));
      expect(sections, contains('Sections 11-14'));
      expect(sections, contains('Section 16'));

      final sec8 =
          obligations.firstWhere((o) => o.sectionRef == 'Section 8(5)');
      expect(sec8.maximumPenaltyInrCrore, 250.0);

      final sec9 = obligations.firstWhere((o) => o.sectionRef == 'Section 9');
      expect(sec9.maximumPenaltyInrCrore, 200.0);
    });

    test(
        'Regulatory disclaimers strictly prohibit fraudulent claims and define CERT-In 6-hour mandate',
        () {
      final disclaimers = PrivacySecurityAuditFixtures.regulatoryDisclaimers;
      expect(disclaimers.hipaaCompliantClaimProhibited, isTrue);
      expect(disclaimers.gdprCertifiedClaimProhibited, isTrue);
      expect(disclaimers.fdaApprovedClaimProhibited, isTrue);
      expect(disclaimers.certInReportingWindowHours, 6);
      expect(disclaimers.certInReportingEmail, 'incident@cert-in.org.in');
      expect(disclaimers.samdClassification, contains('Non-Device'));
      expect(disclaimers.approvedClinicalDisclaimer,
          contains('Self-reported records'));
    });

    test(
        'Serialization round-trip for DPDP commencement stages and obligations',
        () {
      final stage = PrivacySecurityAuditFixtures.dpdpCommencementStages.first;
      expect(DpdpCommencementStage.fromJson(stage.toJson()).stageNumber,
          stage.stageNumber);

      final obligation = PrivacySecurityAuditFixtures.dpdpObligations.first;
      expect(DpdpComplianceObligation.fromJson(obligation.toJson()).sectionRef,
          obligation.sectionRef);

      final disclaimers = PrivacySecurityAuditFixtures.regulatoryDisclaimers;
      expect(
          RegulatoryDisclaimerSpecification.fromJson(disclaimers.toJson())
              .certInReportingWindowHours,
          6);
    });
  });

  group(
      'Mitigation RACI Governance & Operational Pillars (Issue #38 / MED-028)',
      () {
    test('Governance roles cover 6 functional positions', () {
      final roles = PrivacySecurityAuditFixtures.governanceRoles;
      expect(roles.length, 6);

      final codes = roles.map((r) => r.code).toSet();
      expect(codes, containsAll(['PSL', 'MPL', 'PLO', 'PO', 'CSO', 'QAL']));
    });

    test('RACI matrix defines exactly 9 operational governance areas', () {
      final matrix = PrivacySecurityAuditFixtures.raciMatrix;
      expect(matrix.length, 9);

      final areas = matrix.map((m) => m.governanceArea).toSet();
      expect(areas, contains('Pillar 1: Encryption Architecture'));
      expect(areas, contains('Pillar 2: Key Recovery & Data Loss Policy'));
      expect(areas, contains('Pillar 3: Consent & Notice Management'));
      expect(areas, contains('Pillar 4: Data Retention & Atomic Erasure'));
      expect(areas, contains('Pillar 5: Breach Handling & CERT-In Protocol'));
      expect(
          areas, contains('Pillar 6: Future Cloud Access Governance (E2EE)'));
      expect(areas, contains('Manifest & Permission Minimization'));
      expect(areas, contains('Diagnostic Bundle Redaction & Auditing'));
      expect(areas, contains('Clinical Disclaimer & SaMD Boundaries'));
    });

    test(
        'Single Accountability Invariant: each area has exactly one Accountable role',
        () {
      final validRoleCodes = PrivacySecurityAuditFixtures.governanceRoles
          .map((r) => r.code)
          .toSet();

      for (final assignment in PrivacySecurityAuditFixtures.raciMatrix) {
        expect(assignment.accountableRoleCode.isNotEmpty, isTrue);
        expect(validRoleCodes.contains(assignment.accountableRoleCode), isTrue);
        expect(assignment.responsibleRoleCodes.isNotEmpty, isTrue);
        expect(assignment.operationalSpecifications.isNotEmpty, isTrue);
      }
    });

    test('Serialization round-trip for GovernanceRole and RaciAssignment', () {
      final role = PrivacySecurityAuditFixtures.governanceRoles.first;
      expect(GovernanceRole.fromJson(role.toJson()).code, role.code);

      final assignment = PrivacySecurityAuditFixtures.raciMatrix.first;
      final reconstituted = RaciAssignment.fromJson(assignment.toJson());
      expect(reconstituted.governanceArea, assignment.governanceArea);
      expect(reconstituted.accountableRoleCode, assignment.accountableRoleCode);
    });
  });
}
