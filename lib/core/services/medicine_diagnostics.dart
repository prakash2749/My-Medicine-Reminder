import 'dart:convert';

import 'medicine_notifications.dart';

/// The same immutable text is previewed and copied after explicit user action.
/// Keep this on the allowlist path; readiness.toJson() contains sensitive data.
String reminderDiagnosticBundle(ReminderReadiness status) =>
    const JsonEncoder.withIndent('  ').convert(reminderDiagnostics(status));

/// Allowlisted readiness only. No raw exceptions, timestamps, IDs or health data.
Map<String, Object> reminderDiagnostics(ReminderReadiness status) => {
      'schema': 1,
      'scope': 'local-readiness',
      'remoteTelemetry': false,
      'schedulingSupported': status.supported,
      'notificationPermission': status.notifications,
      'preciseAlarmPermission': status.exact,
      'refillChannelEnabled': status.refillNotifications,
      'futureSchedulePresent': status.scheduledThrough != null,
      'reconciliationFailed': status.error != null,
      'callbackObserved': 'not measured',
      'posted': 'not measured',
      'humanReceipt': 'not measured',
    };
