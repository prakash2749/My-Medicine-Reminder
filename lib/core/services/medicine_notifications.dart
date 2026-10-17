import '../l10n/app_copy.dart';
import 'notification_language.dart';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/medication.dart';
import 'medicine_store.dart';

class ReminderIntent {
  final String owner, occurrenceId;
  final DateTime dueAt;
  final String? action;
  final String? alertKey;
  final String? refillMedicineId;
  const ReminderIntent(
    this.owner,
    this.occurrenceId,
    this.dueAt,
    this.action, {
    this.alertKey,
    this.refillMedicineId,
  });
}

class ReminderReadiness {
  final bool supported, notifications, exact;
  final DateTime? scheduledThrough;
  final String? error;
  final List<String> refillAlertsSent;
  final bool refillNotifications;
  const ReminderReadiness({
    this.supported = false,
    this.notifications = false,
    this.exact = false,
    this.scheduledThrough,
    this.error,
    this.refillAlertsSent = const [],
    this.refillNotifications = true,
  });
  String get message =>
      error ??
      (!supported
          ? 'Local reminders are available on Android and iOS. Your medicines are still saved here.'
          : !notifications
              ? 'Notifications are off. Enable them in Settings to receive reminders.'
              : !exact
                  ? 'Reminders may arrive late. Allow precise alarms in Settings.'
                  : scheduledThrough == null
                      ? 'Reminders are ready.'
                      : 'Reminders scheduled through ${dateKey(scheduledThrough!.toLocal())}.');

  ReminderReadiness copyWith({
    bool? supported,
    bool? notifications,
    bool? exact,
    DateTime? scheduledThrough,
    String? error,
    List<String>? refillAlertsSent,
    bool? refillNotifications,
  }) =>
      ReminderReadiness(
        supported: supported ?? this.supported,
        notifications: notifications ?? this.notifications,
        exact: exact ?? this.exact,
        scheduledThrough: scheduledThrough ?? this.scheduledThrough,
        error: error ?? this.error,
        refillAlertsSent: refillAlertsSent ?? this.refillAlertsSent,
        refillNotifications: refillNotifications ?? this.refillNotifications,
      );

  Map<String, dynamic> toJson() => {
        'supported': supported,
        'notifications': notifications,
        'exact': exact,
        if (scheduledThrough != null)
          'scheduledThrough': scheduledThrough!.toUtc().toIso8601String(),
        if (error != null) 'error': error,
        'refillAlertsSent': refillAlertsSent,
        'refillNotifications': refillNotifications,
      };

  factory ReminderReadiness.fromJson(Map<String, dynamic> json) =>
      ReminderReadiness(
        supported: json['supported'] as bool? ?? false,
        notifications: json['notifications'] as bool? ?? false,
        exact: json['exact'] as bool? ?? false,
        scheduledThrough: json['scheduledThrough'] == null
            ? null
            : DateTime.parse(json['scheduledThrough'] as String),
        error: json['error'] as String?,
        refillAlertsSent: (json['refillAlertsSent'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        refillNotifications: json['refillNotifications'] as bool? ?? true,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderReadiness &&
          runtimeType == other.runtimeType &&
          supported == other.supported &&
          notifications == other.notifications &&
          exact == other.exact &&
          scheduledThrough == other.scheduledThrough &&
          error == other.error &&
          refillNotifications == other.refillNotifications &&
          listEquals(refillAlertsSent, other.refillAlertsSent);

  @override
  int get hashCode => Object.hash(
        supported,
        notifications,
        exact,
        scheduledThrough,
        error,
        refillNotifications,
        Object.hashAll(refillAlertsSent),
      );

  @override
  String toString() =>
      'ReminderReadiness(supported: $supported, notifications: $notifications, '
      'exact: $exact, scheduledThrough: $scheduledThrough, error: $error, '
      'refillNotifications: $refillNotifications, refillAlertsSent: $refillAlertsSent)';
}

abstract class MedicineNotifications {
  ValueNotifier<ReminderIntent?> get intent;
  Future<void> initialize();
  Future<ReminderReadiness> sync(
    String? owner,
    MedicineData data,
    DateTime now, {
    bool forceRebuild = false,
  });
  Future<void> requestPermissions();
  Future<void> openSettings();
  Future<void> clear();
  Future<void> cancelDose(String occurrenceId);
  Future<String> deviceTimezone();
}

class LocalMedicineNotifications implements MedicineNotifications {
  static const _settings = MethodChannel('medicine_reminder/settings');
  static final instance = LocalMedicineNotifications();
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _initializing;
  VoidCallback? onOpen;
  String _language = 'en';
  String _copy(String value) => translateCopy(value, _language);
  @override
  final intent = ValueNotifier<ReminderIntent?>(null);
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  bool get _android => defaultTargetPlatform == TargetPlatform.android;
  AndroidFlutterLocalNotificationsPlugin? get _androidPlugin =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  static int notificationId(String id) {
    final b = sha256.convert(utf8.encode(id)).bytes;
    return ((b[0] << 24) | (b[1] << 16) | (b[2] << 8) | b[3]) & 0x7fffffff;
  }

  @override
  Future<void> initialize() async {
    try {
      await (_initializing ??= _initialize());
    } catch (_) {
      _initializing = null;
      rethrow;
    }
  }

  Future<void> _initialize() async {
    _language = await notificationLanguage();
    tzdata.initializeTimeZones();
    if (!supported) return;
    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          notificationCategories: [
            DarwinNotificationCategory(
              'dose',
              actions: [
                DarwinNotificationAction.plain(
                  'taken',
                  _copy('Taken'),
                  options: {DarwinNotificationActionOption.foreground},
                ),
                DarwinNotificationAction.plain(
                  'snooze',
                  _copy('Snooze 15 min'),
                  options: {DarwinNotificationActionOption.foreground},
                ),
              ],
            ),
          ],
        ),
      ),
      onDidReceiveNotificationResponse: _receive,
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      final response = launch?.notificationResponse;
      if (response != null) _receive(response);
    }
  }

  void _receive(NotificationResponse response) {
    try {
      final payload = jsonDecode(response.payload!) as Map<String, dynamic>;
      if (payload['refill'] is String) {
        intent.value = ReminderIntent(
          payload['owner'] as String,
          '',
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          null,
          refillMedicineId: payload['refill'] as String,
        );
        onOpen?.call();
        return;
      }
      intent.value = ReminderIntent(
        payload['owner'] as String,
        payload['dose'] as String,
        DateTime.parse(payload['due'] as String),
        response.actionId,
        alertKey: payload['alert'] as String?,
      );
      onOpen?.call();
    } catch (_) {
      /* Invalid or obsolete notification payloads cannot mutate data. */
    }
  }

  @override
  Future<String> deviceTimezone() async =>
      (await FlutterTimezone.getLocalTimezone()).identifier;

  @override
  Future<void> clear() async {
    await initialize();
    if (supported) await _plugin.cancelAll();
  }

  @override
  Future<void> cancelDose(String occurrenceId) async {
    if (supported) await _plugin.cancel(id: notificationId(occurrenceId));
  }

  @override
  Future<void> requestPermissions() async {
    await initialize();
    if (!supported) return;
    if (_android) {
      await _androidPlugin?.requestNotificationsPermission();
      await _androidPlugin?.requestExactAlarmsPermission();
    } else {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  Future<void> showTest() async {
    await initialize();
    if (!supported) throw UnsupportedError('Native reminders unavailable');
    await _plugin.show(
      id: notificationId('medicine:test'),
      title: _copy('Reminder test'),
      body: _copy('This is a test notification. It does not record a dose.'),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
            'medicine_doses_v1', 'Medicine reminders',
            importance: Importance.high,
            visibility: NotificationVisibility.private),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  @override
  Future<void> openSettings() async {
    // Permission recovery uses an explicit native app-settings link.
    if (!supported) return;
    await _settings.invokeMethod<void>('openNotificationSettings');
  }

  @override
  Future<ReminderReadiness> sync(
    String? owner,
    MedicineData data,
    DateTime now, {
    bool forceRebuild = false,
  }) async {
    final language = await notificationLanguage();
    if (language != _language) {
      _language = language;
      _initializing = null;
      forceRebuild = true;
    }
    await initialize();
    if (!supported) return const ReminderReadiness();
    if (owner == null) {
      await clear();
      return const ReminderReadiness(supported: true);
    }
    var allowed = _android
        ? await _androidPlugin?.areNotificationsEnabled() ?? false
        : (await _plugin
                    .resolvePlatformSpecificImplementation<
                        IOSFlutterLocalNotificationsPlugin>()
                    ?.checkPermissions())
                ?.isEnabled ??
            false;
    final appAllowed = allowed;
    var refillAllowed = allowed;
    if (_android && allowed) {
      final channels = await _androidPlugin?.getNotificationChannels();
      final channel =
          channels?.where((c) => c.id == 'medicine_doses_v1').firstOrNull;
      if (channel?.importance == Importance.none) allowed = false;
      refillAllowed = !(channels ?? []).any(
        (c) => c.id == 'medicine_refills_v1' && c.importance == Importance.none,
      );
    }
    final exact = !_android ||
        (await _androidPlugin?.canScheduleExactNotifications() ?? false);
    if (!appAllowed) {
      await clear();
      return ReminderReadiness(
        supported: true,
        notifications: false,
        exact: exact,
        refillNotifications: false,
      );
    }
    final occurrences = !allowed
        ? <DoseOccurrence>[]
        : data.doses(
            now.subtract(const Duration(days: 1)),
            now.add(const Duration(days: 30)),
            remindersOnly: true,
          );
    final lowStock = data.stockAccounts.where((stock) {
      final medicine =
          data.medications.where((m) => m.id == stock.medicineId).firstOrNull;
      return stock.active &&
          medicine != null &&
          !medicine.paused &&
          !medicine.archived &&
          data.balance(stock.id) <= stock.threshold;
    }).toList();
    final refillIds = {
      for (final stock in lowStock)
        notificationId('refill:$owner:${stock.id}:${stock.episode}'),
    };
    final liveIds = occurrences
        .where((d) => !d.isComplete)
        .map((d) => notificationId(d.id))
        .toSet();
    for (final active in await _plugin.getActiveNotifications()) {
      if (active.id != null &&
          !liveIds.contains(active.id) &&
          !refillIds.contains(active.id)) {
        await _plugin.cancel(id: active.id!);
      }
    }
    final candidates = occurrences
        .where((dose) => !dose.isComplete && dose.alertAt.isAfter(now))
        .toList()
      ..sort((a, b) => a.alertAt.compareTo(b.alertAt));
    final limit = _android ? 450 : 60;
    final desired = <int, ({DoseOccurrence dose, String payload})>{};
    for (final dose in candidates.take(limit)) {
      final id = notificationId(dose.id);
      if (desired.containsKey(id)) {
        throw StateError(
          'Reminder ID collision. Please recreate this schedule.',
        );
      }
      desired[id] = (
        dose: dose,
        payload: jsonEncode({
          'owner': owner,
          'dose': dose.id,
          'due': dose.dueAt.toUtc().toIso8601String(),
          'alert': dose.alertAt.toUtc().toIso8601String(),
          'exact': exact,
          'language': _language,
        }),
      );
    }
    final pending = await _plugin.pendingNotificationRequests();
    for (final old in pending) {
      if (forceRebuild ||
          !desired.containsKey(old.id) ||
          old.payload != desired[old.id]!.payload) {
        await _plugin.cancel(id: old.id);
      }
    }
    for (final entry in desired.entries) {
      if (!forceRebuild &&
          pending.any(
            (p) => p.id == entry.key && p.payload == entry.value.payload,
          )) {
        continue;
      }
      final dose = entry.value.dose;
      // Private lock-screen text; users unlock the app to record any action.
      await _plugin.zonedSchedule(
        id: entry.key,
        title: _copy('Medicine reminder'),
        body: _copy('Open the app to view and record your scheduled dose.'),
        scheduledDate: tz.TZDateTime.from(dose.alertAt, tz.UTC),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'medicine_doses_v1',
            'Medicine reminders',
            channelDescription: 'Scheduled medicine reminders',
            importance: Importance.high,
            priority: Priority.high,
            visibility: NotificationVisibility.private,
            actions: [
              AndroidNotificationAction(
                'taken',
                _copy('Taken'),
                showsUserInterface: true,
                cancelNotification: false,
              ),
              AndroidNotificationAction(
                'snooze',
                _copy('Snooze 15 min'),
                showsUserInterface: true,
                cancelNotification: false,
              ),
            ],
          ),
          iOS: DarwinNotificationDetails(
            categoryIdentifier: 'dose',
            presentSound: true,
          ),
        ),
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: entry.value.payload,
      );
    }
    final sent = <String>[];
    for (final stock in lowStock) {
      if (!refillAllowed) continue;
      if (stock.alertedEpisode == stock.episode) continue;
      final id = notificationId('refill:$owner:${stock.id}:${stock.episode}');
      if (liveIds.contains(id)) {
        throw StateError('Refill notification ID collision.');
      }
      await _plugin.show(
        id: id,
        title: _copy('Refill reminder'),
        body: _copy('Open the app to check your medicine stock.'),
        payload: jsonEncode({'owner': owner, 'refill': stock.medicineId}),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'medicine_refills_v1',
            'Refill reminders',
            channelDescription: 'Low medicine stock',
            importance: Importance.defaultImportance,
            visibility: NotificationVisibility.private,
            onlyAlertOnce: true,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
      sent.add(stock.id);
    }
    final through =
        candidates.isEmpty ? null : candidates.take(limit).last.alertAt;
    return ReminderReadiness(
      supported: true,
      notifications: allowed,
      exact: exact,
      scheduledThrough: through,
      refillAlertsSent: sent,
      refillNotifications: refillAllowed,
    );
  }
}
