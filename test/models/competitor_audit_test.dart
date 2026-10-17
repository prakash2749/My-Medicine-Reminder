import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_reminder/core/models/competitor_audit.dart';

void main() {
  group('Competitor Audit Model & Fixture Verification (Issue #12 / MED-002)',
      () {
    test('AC2 Review Sampling: Ledger contains ≥30 reviews with unique IDs',
        () {
      final reviews = CompetitorAuditFixtures.reviews32;
      expect(reviews.length, greaterThanOrEqualTo(30));
      expect(reviews.length, 32);

      final ids = reviews.map((r) => r.id).toSet();
      expect(ids.length, 32);
      for (var i = 1; i <= 32; i++) {
        final expectedId = 'R${i.toString().padLeft(2, '0')}';
        expect(ids.contains(expectedId), isTrue,
            reason: 'Review ID $expectedId missing');
      }
    });

    test(
        'AC2 Review Sampling: Strict taxonomic separation between defects and complaints',
        () {
      final reviews = CompetitorAuditFixtures.reviews32;
      final defects = CompetitorAuditFixtures.defectReviews;
      final complaints = CompetitorAuditFixtures.complaintReviews;

      // Every review must be either a defect or complaint (disjoint partition)
      expect(defects.length + complaints.length, reviews.length);

      // Verify specific distributions matching MED-002 Design section 4.3
      final defectCounts = CompetitorAuditFixtures.defectCountByApp;
      final complaintCounts = CompetitorAuditFixtures.complaintCountByApp;

      expect(defectCounts['Medisafe'], 8);
      expect(complaintCounts['Medisafe'], 8);
      expect(defectCounts['MyTherapy'], 9);
      expect(complaintCounts['MyTherapy'], 7);

      expect(defects.length, 17); // 8 + 9 = 17
      expect(complaints.length, 15); // 8 + 7 = 15
    });

    test('AC2 Review Quality: Ratings between 1-5, valid non-empty fields', () {
      for (final r in CompetitorAuditFixtures.reviews32) {
        expect(r.stars, inInclusiveRange(1, 5));
        expect(r.excerpt.trim().isNotEmpty, isTrue);
        expect(r.rootCause.trim().isNotEmpty, isTrue);
        expect(r.store, anyOf('Play Store', 'App Store'));
        expect(r.app, anyOf('Medisafe', 'MyTherapy'));
      }
    });

    test(
        'AC1 Audit Records: Medisafe, MyTherapy, and Target App profiles record all mandatory fields',
        () {
      final records = [
        CompetitorAuditFixtures.medisafe,
        CompetitorAuditFixtures.myTherapy,
        CompetitorAuditFixtures.myMedicineReminderTarget,
      ];

      for (final record in records) {
        expect(record.appId.isNotEmpty, isTrue);
        expect(record.appName.isNotEmpty, isTrue);
        expect(record.androidVersion.isNotEmpty, isTrue);
        expect(record.iosVersion.isNotEmpty, isTrue);
        expect(record.regionTested.isNotEmpty, isTrue);
        expect(record.businessModel.isNotEmpty, isTrue);
        expect(record.paywallThreshold.isNotEmpty, isTrue);
        expect(record.onboardingSteps.isNotEmpty, isTrue);
        expect(record.permissionRequests.isNotEmpty, isTrue);
        expect(record.reminderActions.isNotEmpty, isTrue);
        expect(record.alarmReliabilityEngine.isNotEmpty, isTrue);
        expect(record.pastUnconfirmedDoseHandling.isNotEmpty, isTrue);
        expect(record.exportFormats.isNotEmpty, isTrue);
        expect(record.exportPaywallBarrier.isNotEmpty, isTrue);
      }

      // Specific AC1 assertions
      expect(CompetitorAuditFixtures.medisafe.paywallThreshold,
          contains('2 medications'));
      expect(CompetitorAuditFixtures.medisafe.observedTrackers.length,
          greaterThanOrEqualTo(4));
      expect(CompetitorAuditFixtures.myMedicineReminderTarget.observedTrackers,
          isEmpty);
      expect(
          CompetitorAuditFixtures
              .myMedicineReminderTarget.privateNotificationMode,
          isTrue);
    });

    test(
        'AC3 Gaps & Hypotheses: Matrix contains 7 key dimensions and links to hypotheses',
        () {
      final gaps = CompetitorAuditFixtures.gapsAndHypotheses;
      expect(gaps.length, 7);

      final dimensions = gaps.map((g) => g.dimension).toSet();
      expect(dimensions, contains('Onboarding & Account Gate'));
      expect(dimensions, contains('Alarm Execution & Resilience'));
      expect(dimensions, contains('Schedule History Integrity'));
      expect(dimensions, contains('Adherence Semantics & Ethics'));
      expect(dimensions, contains('Health Data Privacy'));
      expect(dimensions, contains('Refill Management'));
      expect(dimensions, contains('Clinical Export Freedom'));

      for (final gap in gaps) {
        expect(gap.id.startsWith('GAP-'), isTrue);
        expect(gap.competitorDeficit.isNotEmpty, isTrue);
        expect(gap.architecturalRootCause.isNotEmpty, isTrue);
        expect(gap.proposedSolution.isNotEmpty, isTrue);
        expect(gap.verificationMetric.isNotEmpty, isTrue);
        expect(gap.hypothesisCode.isNotEmpty, isTrue);
      }
    });

    test(
        'Benchmark Measurements: Target App outperforms or meets all reliability and privacy metrics',
        () {
      final benchmarks = CompetitorAuditFixtures.benchmarks;
      expect(benchmarks.isNotEmpty, isTrue);

      final onboarding =
          benchmarks.firstWhere((b) => b.metricKey == 'time_to_first_dose_sec');
      expect(onboarding.targetAppValue, lessThan(onboarding.medisafeValue));
      expect(onboarding.targetAppValue, lessThan(onboarding.myTherapyValue));

      final doze = benchmarks
          .firstWhere((b) => b.metricKey == 'doze_alarm_survival_rate_pct');
      expect(doze.targetAppValue, 100.0);
      expect(doze.medisafeValue, lessThan(100.0));

      final privacy = benchmarks
          .firstWhere((b) => b.metricKey == 'third_party_telemetry_bytes');
      expect(privacy.targetAppValue, 0.0);
      expect(privacy.medisafeValue, greaterThan(0.0));
    });

    test('JSON Serialization / Deserialization roundtrip works flawlessly', () {
      // AuditReview serialization round-trip
      final sampleReview = CompetitorAuditFixtures.reviews32.first;
      final reviewJson = sampleReview.toJson();
      final roundTripReview = AuditReview.fromJson(reviewJson);
      expect(roundTripReview.id, sampleReview.id);
      expect(roundTripReview.app, sampleReview.app);
      expect(roundTripReview.stars, sampleReview.stars);
      expect(roundTripReview.category, sampleReview.category);
      expect(roundTripReview.domain, sampleReview.domain);

      // AppAuditRecord serialization round-trip
      final appRecord = CompetitorAuditFixtures.medisafe;
      final appJson = appRecord.toJson();
      final roundTripApp = AppAuditRecord.fromJson(appJson);
      expect(roundTripApp.appId, appRecord.appId);
      expect(roundTripApp.appName, appRecord.appName);
      expect(roundTripApp.onboardingSteps.length,
          appRecord.onboardingSteps.length);

      // GapAndHypothesis serialization round-trip
      final gap = CompetitorAuditFixtures.gapsAndHypotheses.first;
      final gapJson = gap.toJson();
      final roundTripGap = GapAndHypothesis.fromJson(gapJson);
      expect(roundTripGap.id, gap.id);
      expect(roundTripGap.dimension, gap.dimension);

      // BenchmarkMeasurement serialization round-trip
      final bm = CompetitorAuditFixtures.benchmarks.first;
      final bmJson = bm.toJson();
      final roundTripBm = BenchmarkMeasurement.fromJson(bmJson);
      expect(roundTripBm.metricKey, bm.metricKey);
      expect(roundTripBm.medisafeValue, bm.medisafeValue);
    });
  });

  group('Taxonomic Enums & Domain Mapping Edge Cases', () {
    test('ReviewCategory codes, labels, and names match specification', () {
      expect(ReviewCategory.defect.code, 'D');
      expect(ReviewCategory.defect.label, 'Verified Defect');
      expect(ReviewCategory.defect.name, 'defect');

      expect(ReviewCategory.complaint.code, 'C');
      expect(ReviewCategory.complaint.label, 'UX / Commercial Complaint');
      expect(ReviewCategory.complaint.name, 'complaint');

      expect(ReviewCategory.values.length, 2);
    });

    test(
        'ReviewDomain codes, labels, and byName resolution cover all 5 failure domains',
        () {
      final expectedDomains = {
        ReviewDomain.alarms: ('ALM', 'Alarms & Background Drops'),
        ReviewDomain.paywall: ('PAY', 'Paywalls & Monetization Traps'),
        ReviewDomain.dataLoss: ('DAT', 'Data Loss & Export Failures'),
        ReviewDomain.accountSync: ('ACC', 'Account & Sync Conflicts'),
        ReviewDomain.usability: ('USX', 'Usability & Adherence Semantics'),
      };

      expect(ReviewDomain.values.length, 5);
      for (final entry in expectedDomains.entries) {
        expect(entry.key.code, entry.value.$1);
        expect(entry.key.label, entry.value.$2);
        expect(ReviewDomain.values.byName(entry.key.name), entry.key);
      }
    });
  });

  group('AC1: Detailed Competitor Workflow & Profile Validation', () {
    test(
        'Medisafe profile strictly captures observed monetization and permission anti-patterns',
        () {
      final medisafe = CompetitorAuditFixtures.medisafe;
      expect(medisafe.appId, 'com.medisafe.android.client');
      expect(medisafe.developer, contains('Medisafe'));
      expect(medisafe.accountMandatory, isTrue);
      expect(medisafe.paywallThreshold, contains('2 medications'));
      expect(medisafe.paywallThreshold, contains('39.99'));
      expect(medisafe.averageOnboardingTimeSeconds, 222);
      expect(medisafe.exportPaywallBarrier, contains('Paywalled'));
      expect(medisafe.dataEncryptionAtRest, contains('Unencrypted'));
      expect(medisafe.privateNotificationMode, isFalse);
      expect(
          medisafe.observedTrackers,
          containsAll([
            contains('Firebase'),
            contains('AppsFlyer'),
            contains('Facebook'),
            contains('Braze'),
          ]));
    });

    test(
        'MyTherapy profile captures B2B PSP model, guest mode, and export deficits',
        () {
      final myTherapy = CompetitorAuditFixtures.myTherapy;
      expect(myTherapy.appId, 'eu.smartpatient.mytherapy');
      expect(myTherapy.developer, contains('smartpatient'));
      expect(myTherapy.accountMandatory, isFalse);
      expect(myTherapy.offlineSupported, isTrue);
      expect(myTherapy.paywallThreshold, contains('Free core'));
      expect(myTherapy.paywallThreshold, contains('sponsored PSPs'));
      expect(myTherapy.averageOnboardingTimeSeconds, 108);
      expect(myTherapy.exportPaywallBarrier, contains('no CSV'));
      expect(myTherapy.privateNotificationMode, isFalse);
      expect(
          myTherapy.observedTrackers,
          containsAll([
            contains('smartpatient'),
            contains('Branch.io'),
          ]));
    });

    test(
        'Target App profile enforces local-first, zero-cloud PHI, and zero-paywall invariants',
        () {
      final target = CompetitorAuditFixtures.myMedicineReminderTarget;
      expect(target.appId, 'com.example.medicine_reminder');
      expect(target.accountMandatory, isFalse);
      expect(target.offlineSupported, isTrue);
      expect(target.privateNotificationMode, isTrue);
      expect(target.observedTrackers, isEmpty);
      expect(target.averageOnboardingTimeSeconds, lessThan(60));
      expect(target.averageOnboardingTimeSeconds, 42);
      expect(target.exportPaywallBarrier, contains('100% Free'));
      expect(target.dataEncryptionAtRest, contains('SQLCipher AES-256'));
      expect(
          target.exportFormats,
          containsAll([
            contains('PDF'),
            contains('CSV'),
          ]));
    });
  });

  group('AC2: Review Sampling Protocol, Deduplication & Boundary Analysis', () {
    test(
        'Sampling window constraint: every review date is between 2025-01-01 and 2026-10-15',
        () {
      final windowStart = DateTime.utc(2025, 1, 1);
      final windowEnd = DateTime.utc(2026, 10, 15, 23, 59, 59);

      for (final r in CompetitorAuditFixtures.reviews32) {
        expect(
          !r.date.isBefore(windowStart) && !r.date.isAfter(windowEnd),
          isTrue,
          reason: 'Review ${r.id} date ${r.date} falls outside sampling window',
        );
      }
    });

    test('Star ratings distribution covers boundary conditions (1 to 3 stars)',
        () {
      final starCounts = <int, int>{};
      for (final r in CompetitorAuditFixtures.reviews32) {
        starCounts[r.stars] = (starCounts[r.stars] ?? 0) + 1;
      }

      // Check boundary presence
      expect(starCounts[1], greaterThan(0), reason: 'Expected 1-star reviews');
      expect(starCounts[2], greaterThan(0), reason: 'Expected 2-star reviews');
      expect(starCounts[3], greaterThan(0), reason: 'Expected 3-star reviews');

      final totalStars = starCounts.values.reduce((a, b) => a + b);
      expect(totalStars, 32);
    });

    test(
        'Deduplication invariant: zero duplicate review excerpts or root causes',
        () {
      final excerpts = <String>{};
      final rootCauses = <String>{};

      for (final r in CompetitorAuditFixtures.reviews32) {
        expect(excerpts.add(r.excerpt.trim()), isTrue,
            reason: 'Duplicate review excerpt found in ${r.id}');
        expect(rootCauses.add(r.rootCause.trim()), isTrue,
            reason: 'Duplicate root cause found in ${r.id}');
      }
    });

    test('Disjoint mathematical partitioning of defects and complaints', () {
      final defectIds =
          CompetitorAuditFixtures.defectReviews.map((r) => r.id).toSet();
      final complaintIds =
          CompetitorAuditFixtures.complaintReviews.map((r) => r.id).toSet();

      // Intersection must be empty (disjoint)
      expect(defectIds.intersection(complaintIds), isEmpty);

      // Union must equal total review IDs
      expect(defectIds.union(complaintIds),
          CompetitorAuditFixtures.reviews32.map((r) => r.id).toSet());

      // reviewCount getter matches length
      expect(CompetitorAuditFixtures.reviewCount, 32);
    });

    test('Domain distribution matches empirical ledger totals', () {
      final domainCounts = CompetitorAuditFixtures.reviewCountByDomain;

      expect(domainCounts[ReviewDomain.alarms], 12);
      expect(domainCounts[ReviewDomain.paywall], 4);
      expect(domainCounts[ReviewDomain.dataLoss], 5);
      expect(domainCounts[ReviewDomain.accountSync], 2);
      expect(domainCounts[ReviewDomain.usability], 9);

      final totalCount = domainCounts.values.reduce((a, b) => a + b);
      expect(totalCount, 32);
    });

    test('Boolean helper flags isDefect and isComplaint are mutually exclusive',
        () {
      for (final r in CompetitorAuditFixtures.reviews32) {
        expect(r.isDefect ^ r.isComplaint, isTrue);
        if (r.category == ReviewCategory.defect) {
          expect(r.isDefect, isTrue);
          expect(r.isComplaint, isFalse);
        } else {
          expect(r.isDefect, isFalse);
          expect(r.isComplaint, isTrue);
        }
      }
    });
  });

  group('AC3: Gap Analysis & Hypotheses Formal Verification', () {
    test('Gap IDs are sequentially indexed from GAP-1 to GAP-7', () {
      final gaps = CompetitorAuditFixtures.gapsAndHypotheses;
      for (var i = 1; i <= 7; i++) {
        expect(gaps[i - 1].id, 'GAP-$i');
      }
    });

    test('Hypothesis mapping covers all architectural hypotheses H1 through H5',
        () {
      final gaps = CompetitorAuditFixtures.gapsAndHypotheses;
      final hypothesisCodes = gaps.map((g) => g.hypothesisCode).toList();

      expect(hypothesisCodes.any((h) => h.contains('H1')), isTrue);
      expect(hypothesisCodes.any((h) => h.contains('H2')), isTrue);
      expect(hypothesisCodes.any((h) => h.contains('H3')), isTrue);
      expect(hypothesisCodes.any((h) => h.contains('H4')), isTrue);
      expect(hypothesisCodes.any((h) => h.contains('H5')), isTrue);
    });

    test('All gap fields satisfy minimum documentation thresholds', () {
      for (final gap in CompetitorAuditFixtures.gapsAndHypotheses) {
        expect(gap.competitorDeficit.length, greaterThan(20));
        expect(gap.architecturalRootCause.length, greaterThan(20));
        expect(gap.proposedSolution.length, greaterThan(20));
        expect(gap.verificationMetric.length, greaterThan(10));
      }
    });
  });

  group('Synthetic Benchmark Computations & Directional Invariants', () {
    test('Benchmark suite contains exactly 6 standardized KPI measurements',
        () {
      final benchmarks = CompetitorAuditFixtures.benchmarks;
      expect(benchmarks.length, 6);

      final keys = benchmarks.map((b) => b.metricKey).toSet();
      expect(
          keys,
          containsAll([
            'time_to_first_dose_sec',
            'doze_alarm_survival_rate_pct',
            'reboot_recovery_rate_pct',
            'history_integrity_on_edit_pct',
            'third_party_telemetry_bytes',
            'export_paywall_cost_annual_usd',
          ]));
    });

    test(
        'Target App satisfies directional superiority on every benchmark metric',
        () {
      for (final bm in CompetitorAuditFixtures.benchmarks) {
        if (bm.lowerIsBetter) {
          expect(bm.targetAppValue, lessThanOrEqualTo(bm.medisafeValue),
              reason: 'Target App should be <= Medisafe for ${bm.metricKey}');
          expect(bm.targetAppValue, lessThanOrEqualTo(bm.myTherapyValue),
              reason: 'Target App should be <= MyTherapy for ${bm.metricKey}');
        } else {
          expect(bm.targetAppValue, greaterThanOrEqualTo(bm.medisafeValue),
              reason: 'Target App should be >= Medisafe for ${bm.metricKey}');
          expect(bm.targetAppValue, greaterThanOrEqualTo(bm.myTherapyValue),
              reason: 'Target App should be >= MyTherapy for ${bm.metricKey}');
        }
      }
    });

    test('Benchmark numeric integer coercion in fromJson works smoothly', () {
      final json = {
        'metricKey': 'custom_metric',
        'description': 'Test metric',
        'unit': 'units',
        'medisafeValue': 100, // integer
        'myTherapyValue': 50, // integer
        'targetAppValue': 0, // integer
        'lowerIsBetter': true,
        'testConditions': 'Automated unit test conditions',
      };

      final parsed = BenchmarkMeasurement.fromJson(json);
      expect(parsed.medisafeValue, 100.0);
      expect(parsed.myTherapyValue, 50.0);
      expect(parsed.targetAppValue, 0.0);
    });
  });

  group('JSON Deserialization Boundary Conditions & Error Handling', () {
    test(
        'Exhaustive JSON round-trip for all 32 review records preserves all fields',
        () {
      for (final review in CompetitorAuditFixtures.reviews32) {
        final json = review.toJson();
        final reconstituted = AuditReview.fromJson(json);

        expect(reconstituted.id, review.id);
        expect(reconstituted.app, review.app);
        expect(reconstituted.store, review.store);
        expect(reconstituted.date.year, review.date.year);
        expect(reconstituted.date.month, review.date.month);
        expect(reconstituted.date.day, review.date.day);
        expect(reconstituted.stars, review.stars);
        expect(reconstituted.category, review.category);
        expect(reconstituted.domain, review.domain);
        expect(reconstituted.excerpt, review.excerpt);
        expect(reconstituted.rootCause, review.rootCause);
      }
    });

    test(
        'Exhaustive JSON round-trip for all AppAuditRecords preserves all fields',
        () {
      final records = [
        CompetitorAuditFixtures.medisafe,
        CompetitorAuditFixtures.myTherapy,
        CompetitorAuditFixtures.myMedicineReminderTarget,
      ];

      for (final record in records) {
        final json = record.toJson();
        final reconstituted = AppAuditRecord.fromJson(json);

        expect(reconstituted.appId, record.appId);
        expect(reconstituted.appName, record.appName);
        expect(reconstituted.developer, record.developer);
        expect(reconstituted.headquarters, record.headquarters);
        expect(reconstituted.androidVersion, record.androidVersion);
        expect(reconstituted.iosVersion, record.iosVersion);
        expect(reconstituted.regionTested, record.regionTested);
        expect(reconstituted.auditDate.year, record.auditDate.year);
        expect(reconstituted.auditDate.month, record.auditDate.month);
        expect(reconstituted.auditDate.day, record.auditDate.day);
        expect(reconstituted.businessModel, record.businessModel);
        expect(reconstituted.paywallThreshold, record.paywallThreshold);
        expect(reconstituted.averageOnboardingTimeSeconds,
            record.averageOnboardingTimeSeconds);
        expect(reconstituted.offlineSupported, record.offlineSupported);
        expect(reconstituted.accountMandatory, record.accountMandatory);
        expect(reconstituted.onboardingSteps, record.onboardingSteps);
        expect(reconstituted.permissionRequests, record.permissionRequests);
        expect(reconstituted.reminderActions, record.reminderActions);
        expect(reconstituted.alarmReliabilityEngine,
            record.alarmReliabilityEngine);
        expect(reconstituted.pastUnconfirmedDoseHandling,
            record.pastUnconfirmedDoseHandling);
        expect(reconstituted.concurrentDoseAggregation,
            record.concurrentDoseAggregation);
        expect(reconstituted.exportFormats, record.exportFormats);
        expect(reconstituted.exportPaywallBarrier, record.exportPaywallBarrier);
        expect(reconstituted.dataEncryptionAtRest, record.dataEncryptionAtRest);
        expect(reconstituted.privateNotificationMode,
            record.privateNotificationMode);
        expect(reconstituted.observedTrackers, record.observedTrackers);
      }
    });

    test('Exhaustive JSON round-trip for all GapAndHypothesis records', () {
      for (final gap in CompetitorAuditFixtures.gapsAndHypotheses) {
        final json = gap.toJson();
        final reconstituted = GapAndHypothesis.fromJson(json);

        expect(reconstituted.id, gap.id);
        expect(reconstituted.dimension, gap.dimension);
        expect(reconstituted.competitorDeficit, gap.competitorDeficit);
        expect(
            reconstituted.architecturalRootCause, gap.architecturalRootCause);
        expect(reconstituted.proposedSolution, gap.proposedSolution);
        expect(reconstituted.verificationMetric, gap.verificationMetric);
        expect(reconstituted.hypothesisCode, gap.hypothesisCode);
      }
    });

    test(
        'AuditReview.fromJson throws TypeError on missing or null mandatory field',
        () {
      final invalidJson = {
        'id': 'R99',
        // 'app' missing
        'store': 'Play Store',
        'date': '2026-01-01',
        'stars': 1,
        'category': 'defect',
        'domain': 'alarms',
        'excerpt': 'Sample excerpt text',
        'rootCause': 'Sample root cause text',
      };

      expect(
          () => AuditReview.fromJson(invalidJson), throwsA(isA<TypeError>()));
    });

    test('AuditReview.fromJson throws ArgumentError on unknown category enum',
        () {
      final invalidJson = {
        'id': 'R99',
        'app': 'Medisafe',
        'store': 'Play Store',
        'date': '2026-01-01',
        'stars': 1,
        'category': 'not_a_valid_category',
        'domain': 'alarms',
        'excerpt': 'Sample excerpt text',
        'rootCause': 'Sample root cause text',
      };

      expect(() => AuditReview.fromJson(invalidJson),
          throwsA(isA<ArgumentError>()));
    });

    test('AuditReview.fromJson throws ArgumentError on unknown domain enum',
        () {
      final invalidJson = {
        'id': 'R99',
        'app': 'Medisafe',
        'store': 'Play Store',
        'date': '2026-01-01',
        'stars': 1,
        'category': 'defect',
        'domain': 'UNKNOWN_DOMAIN_123',
        'excerpt': 'Sample excerpt text',
        'rootCause': 'Sample root cause text',
      };

      expect(() => AuditReview.fromJson(invalidJson),
          throwsA(isA<ArgumentError>()));
    });

    test('AuditReview.fromJson throws FormatException on invalid date string',
        () {
      final invalidJson = {
        'id': 'R99',
        'app': 'Medisafe',
        'store': 'Play Store',
        'date': 'not-a-valid-date',
        'stars': 1,
        'category': 'defect',
        'domain': 'alarms',
        'excerpt': 'Sample excerpt text',
        'rootCause': 'Sample root cause text',
      };

      expect(() => AuditReview.fromJson(invalidJson),
          throwsA(isA<FormatException>()));
    });

    test('BenchmarkMeasurement.fromJson throws TypeError on non-numeric value',
        () {
      final invalidJson = {
        'metricKey': 'test_metric',
        'description': 'Test metric',
        'unit': 'seconds',
        'medisafeValue': 'not-a-number', // invalid type
        'myTherapyValue': 100.0,
        'targetAppValue': 50.0,
        'lowerIsBetter': true,
        'testConditions': 'Test conditions',
      };

      expect(() => BenchmarkMeasurement.fromJson(invalidJson),
          throwsA(isA<TypeError>()));
    });

    test('AppAuditRecord.fromJson throws TypeError on missing list field', () {
      final invalidJson = {
        'appId': 'test.app',
        'appName': 'Test App',
        'developer': 'Developer',
        'headquarters': 'City',
        'androidVersion': '1.0',
        'iosVersion': '1.0',
        'regionTested': 'US',
        'auditDate': '2026-10-18',
        'businessModel': 'Free',
        'paywallThreshold': 'None',
        'averageOnboardingTimeSeconds': 30,
        'offlineSupported': true,
        'accountMandatory': false,
        // 'onboardingSteps' missing
        'permissionRequests': ['POST_NOTIFICATIONS'],
        'reminderActions': ['Take'],
        'alarmReliabilityEngine': 'Engine',
        'pastUnconfirmedDoseHandling': 'Handling',
        'concurrentDoseAggregation': 'Aggregation',
        'exportFormats': ['PDF'],
        'exportPaywallBarrier': 'None',
        'dataEncryptionAtRest': 'Encrypted',
        'privateNotificationMode': true,
        'observedTrackers': [],
      };

      expect(() => AppAuditRecord.fromJson(invalidJson),
          throwsA(isA<TypeError>()));
    });
  });
}
