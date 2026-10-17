import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../core/services/local_data_cleanup.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import '../core/models/medication.dart';
import '../core/services/medicine_notifications.dart';
import '../core/services/medicine_store.dart';
import '../core/models/inventory.dart';
import '../core/models/reminder_context.dart';
import '../core/services/medicine_reporting.dart';
import '../core/services/reminder_recovery.dart';

part 'medicine_inventory_commands.dart';

enum MedicineFilter { all, pending, taken, skipped }

class MedicineReminderProvider extends ChangeNotifier {
  final MedicineStore store;
  final MedicineNotifications notifications;
  final DateTime Function() clock;
  final Future<ReminderContext?> Function()? recoveryProbe;
  MedicineData _data = const MedicineData();
  String? _owner;
  int _generation = 0;
  bool _isLoading = false, _disposed = false, _resetIncomplete = false;
  String? _errorMessage;
  String _searchQuery = '';
  MedicineFilter _filter = MedicineFilter.all;
  Future<void> _queue = Future.value();
  Future<void> ready = Future.value();
  ReminderReadiness readiness = const ReminderReadiness();
  DoseOccurrence? focusedDose;
  String? focusedRefill;
  DateTime? lastReminderCheckAt;

  MedicineReminderProvider({
    MedicineStore? store,
    MedicineNotifications? notifications,
    DateTime Function()? clock,
    this.recoveryProbe,
  })  : store = store ?? EncryptedMedicineStore(),
        notifications = notifications ?? LocalMedicineNotifications.instance,
        clock = clock ?? DateTime.now {
    tzdata.initializeTimeZones();
    this.notifications.intent.addListener(_onIntent);
  }

  MedicineData get reportData =>
      MedicineData.decode(jsonEncode(_data.toJson()));
  String get reportFingerprint {
    final json = _data.toJson()
      ..remove('reminderContext')
      ..remove('acknowledgedTimezone');
    return sha256
        .convert(utf8.encode('$_owner:$_generation:${jsonEncode(json)}'))
        .toString();
  }

  Future<bool> resetLocalData() {
    final generation = ++_generation;
    _resetIncomplete = true;
    _data = const MedicineData();
    focusedDose = null;
    focusedRefill = null;
    return _serial(() async {
      _isLoading = true;
      _notify();
      try {
        await notifications.clear();
        await store.resetAll();
        if (generation != _generation) return false;
        _data = const MedicineData();
        await store.activate(_owner);
        _resetIncomplete = false;
        await _sync();
        _errorMessage = null;
        return true;
      } catch (_) {
        _errorMessage = 'Reset could not finish. Retry before using reminders.';
        return false;
      } finally {
        _isLoading = false;
        _notify();
      }
    });
  }

  bool get isLoading => _isLoading;
  bool get hasAccount => _owner != null;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  MedicineFilter get currentFilter => _filter;
  List<Medication> get medications => List.unmodifiable(_data.medications);
  List<DoseEvent> get events => List.unmodifiable(_data.events);
  String? get travelNotice {
    final zoneName = _data.reminderContext?.timezone;
    if (zoneName == null || zoneName == _data.acknowledgedTimezone) return null;
    final zone = tz.getLocation(zoneName);
    final offset = tz.TZDateTime.from(clock(), zone).timeZoneOffset;
    final different = medications
        .where(
          (m) =>
              !m.archived &&
              !m.paused &&
              tz.TZDateTime.from(
                    clock(),
                    tz.getLocation(m.timezone),
                  ).timeZoneOffset !=
                  offset,
        )
        .map((m) => m.timezone)
        .toSet();
    if (different.isEmpty) return null;
    return 'Device timezone: $zoneName. Reminders stay in ${different.join(', ')}. Verify medicine timing with your clinician when you travel.';
  }

  Future<bool> acknowledgeTimezone() => _change(
        (data) =>
            data.copyWith(acknowledgedTimezone: data.reminderContext?.timezone),
      );
  List<DoseOccurrence> dosesBetween(DateTime from, DateTime until) =>
      _data.doses(from, until);
  List<DoseOccurrence> recordedHistory(String medicineId) => _data.recordedDoses
      .where((d) => d.medication.id == medicineId)
      .map(_data.recordedDose)
      .toList()
    ..sort((a, b) => b.dueAt.compareTo(a.dueAt));
  List<DoseOccurrence> get todayDoses {
    final day = calendarDate(clock());
    return _data.doses(day, DateTime(day.year, day.month, day.day + 1));
  }

  List<DoseOccurrence> get filteredDoses => todayDoses.where((dose) {
        final m = dose.medication;
        final matches = '${m.name} ${m.strength}'.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            );
        return matches &&
            switch (_filter) {
              MedicineFilter.all => true,
              MedicineFilter.pending => !dose.isComplete && !dose.canceled,
              MedicineFilter.taken => dose.isTaken,
              MedicineFilter.skipped => dose.isSkipped,
            };
      }).toList();
  List<DoseOccurrence> get nextDoses {
    final now = clock();
    final future = <DoseOccurrence>[];
    for (final medicine in _data.medications) {
      final zone = tz.getLocation(medicine.timezone);
      final start = tz.TZDateTime(
        zone,
        medicine.startsOn.year,
        medicine.startsOn.month,
        medicine.startsOn.day,
      );
      final from = start.isAfter(now) ? start : now;
      future.addAll(
        _data.doses(from, from.add(const Duration(days: 8))).where(
              (d) =>
                  d.medication.id == medicine.id &&
                  d.remindersAllowed &&
                  !d.isComplete,
            ),
      );
    }
    future.sort((a, b) => a.dueAt.compareTo(b.dueAt));
    if (future.isEmpty) return [];
    return future
        .where((d) => d.dueAt.isAtSameMomentAs(future.first.dueAt))
        .toList();
  }

  int get totalCount =>
      todayDoses.where((d) => !d.canceled || d.isComplete).length;
  int get takenCount => todayDoses.where((d) => d.isTaken).length;
  int get pendingCount =>
      todayDoses.where((d) => !d.isComplete && !d.canceled).length;
  int get skippedCount => todayDoses.where((d) => d.isSkipped).length;
  double get adherenceRate => totalCount == 0 ? 0 : takenCount / totalCount;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<T> _serial<T>(Future<T> Function() work) {
    final next = _queue.then((_) => work());
    _queue = next.then<void>((_) {},
        onError: (Object error, StackTrace stackTrace) {});
    return next;
  }

  /// Hide the previous account immediately; durable switches run in order.
  void bindUser(String? owner) {
    if (_owner == owner && _generation > 0) return;
    _owner = owner;
    final generation = ++_generation;
    _data = const MedicineData();
    _searchQuery = '';
    _filter = MedicineFilter.all;
    focusedDose = null;
    focusedRefill = null;
    lastReminderCheckAt = null;
    _errorMessage = null;
    _isLoading = true;
    scheduleMicrotask(() {
      if (generation == _generation) _notify();
    });
    ready = _serial(() async {
      try {
        // Reminder-plugin failure must not hide otherwise readable medicines.
        try {
          await notifications.initialize();
          await notifications.clear();
        } catch (_) {
          /* _sync exposes reminder recovery after loading records. */
        }
        await store.activate(owner);
        final loaded =
            owner == null ? const MedicineData() : await store.load(owner);
        if (generation != _generation) return;
        _data = loaded;
        await _sync();
      } catch (_) {
        if (generation == _generation) {
          _errorMessage =
              'Could not open your saved medicines. Retry to recover them; existing data has been preserved.';
        }
      } finally {
        if (generation == _generation) {
          _isLoading = false;
          _notify();
        }
      }
    });
    unawaited(ready.then((_) => _onIntent()));
  }

  Future<void> _sync() async {
    final generation = _generation;
    try {
      final now = clock();
      final context = recoveryProbe == null
          ? await readReminderContext(notifications, now)
          : await recoveryProbe!();
      final result = await reconcileReminders(
        store,
        notifications,
        now,
        context: context,
      );
      if (generation == _generation) {
        readiness = result.readiness;
        _data = result.data;
        lastReminderCheckAt = now;
      }
    } catch (_) {
      if (generation == _generation) {
        readiness = const ReminderReadiness(
          supported: true,
          error:
              'Your records are saved, but reminders could not be scheduled. Retry or check notification settings.',
        );
      }
    }
  }

  Future<void> refresh() => _resetIncomplete
      ? resetLocalData().then((_) {})
      : _serial(() async {
          final owner = _owner, generation = _generation;
          try {
            await store.activate(owner);
            if (owner != null) {
              final loaded = await store.load(owner);
              if (generation != _generation) return;
              _data = loaded;
            }
            await _sync();
            _errorMessage = null;
          } catch (_) {
            _errorMessage = 'Could not read your medicines. Please retry.';
          }
          _notify();
        });

  Future<bool> _change(
    MedicineData Function(MedicineData) transform, {
    String? cancelDose,
  }) {
    final owner = _owner, generation = _generation;
    return _serial(() async {
      if (owner == null ||
          generation != _generation ||
          _isLoading ||
          _resetIncomplete) {
        return false;
      }
      try {
        final next = await store.change(owner, transform);
        if (generation != _generation) return false;
        _data = next;
        _errorMessage = null;
        if (cancelDose != null) {
          try {
            await notifications.cancelDose(cancelDose);
          } catch (_) {
            /* Reconciliation will retry. */
          }
        }
        await _sync();
        _notify();
        return true;
      } on FormatException catch (e) {
        _errorMessage = e.message;
      } catch (_) {
        _errorMessage =
            'Could not save this change. Your previous records are unchanged. Please retry.';
      }
      _notify();
      return false;
    });
  }

  Future<bool> addMedication(Medication medicine) => _change((data) {
        medicine.validate();
        if (data.medications.any((m) => m.id == medicine.id)) return data;
        return data.copyWith(
          medications: [
            ...data.medications,
            medicine.copyWith(recordingStartedAt: clock().toUtc()),
          ],
        );
      });

  MedicineData _revise(
    MedicineData data,
    Medication submitted,
    Medication Function(Medication current, DateTime effective) build, {
    bool Function(Medication)? isNoop,
  }) {
    final current =
        data.medications.where((m) => m.id == submitted.id).firstOrNull;
    if (current == null) {
      throw const FormatException('This medicine no longer exists.');
    }
    if (isNoop?.call(current) == true) return data;
    if (current.archived) {
      throw const FormatException('Archived medicines cannot be changed.');
    }
    if (current.revision != submitted.revision) {
      throw const FormatException(
        'This medicine changed while you were editing. Reopen it and try again.',
      );
    }
    final effective = clock().toUtc();
    if (current.effectiveFrom != null &&
        effective.isBefore(current.effectiveFrom!)) {
      throw const FormatException(
        'Your device clock moved backwards. Correct it before changing this schedule.',
      );
    }
    final next = build(
      current,
      effective,
    ).copyWith(recordingStartedAt: current.recordingStartedAt);
    final stock = data.stockFor(current.id);
    if (stock != null && next.unit != stock.unit) {
      throw const FormatException(
        'Stop stock tracking before changing the dose unit. Units are never converted automatically.',
      );
    }
    next.validate();
    return data.copyWith(
      medications:
          data.medications.map((m) => m.id == current.id ? next : m).toList(),
      previousRevisions: [
        ...data.previousRevisions,
        current.copyWith(effectiveUntil: effective),
      ],
    );
  }

  Future<bool> editMedication(Medication draft) => _change(
        (data) => _revise(
          data,
          draft,
          (current, effective) => draft.copyWith(
            paused: current.paused,
            archived: false,
            revision: current.revision + 1,
            effectiveFrom: effective,
          ),
        ),
      );

  Future<bool> setPaused(Medication medicine, bool paused) => _change(
        (data) => _revise(
          data,
          medicine,
          (current, effective) => current.copyWith(
            paused: paused,
            revision: current.revision + 1,
            effectiveFrom: effective,
          ),
          isNoop: (m) => !m.archived && m.paused == paused,
        ),
      );

  Future<bool> archiveMedication(Medication medicine) => _change(
        (data) => _revise(
          data,
          medicine,
          (current, effective) => current.copyWith(
            archived: true,
            revision: current.revision + 1,
            effectiveFrom: effective,
          ),
          isNoop: (m) => m.archived,
        ),
      );

  Future<bool> deleteMedication(String id) async {
    final saved = await _change(
      (data) => data.copyWith(
        medications: data.medications.where((m) => m.id != id).toList(),
        events: data.events
            .where((e) => !e.occurrenceId.startsWith('$id:'))
            .toList(),
        previousRevisions:
            data.previousRevisions.where((m) => m.id != id).toList(),
        recordedDoses:
            data.recordedDoses.where((d) => d.medication.id != id).toList(),
        stockAccounts:
            data.stockAccounts.where((a) => a.medicineId != id).toList(),
        stockEntries: data.stockEntries
            .where(
              (e) => !data.stockAccounts.any(
                (a) => a.medicineId == id && a.id == e.accountId,
              ),
            )
            .toList(),
      ),
    );
    if (saved && store is EncryptedMedicineStore) {
      try {
        await clearMedicineReports();
      } catch (_) {
        _errorMessage =
            'Medicine deleted. Temporary report cleanup failed; retry deletion to clean up.';
        _notify();
        return false;
      }
    }
    return saved;
  }

  Future<bool> act(
    DoseOccurrence dose,
    DoseAction action, {
    String? requestId,
    bool requireActive = false,
  }) =>
      _change((data) {
        final candidates = data.doses(
          dose.dueAt.subtract(const Duration(seconds: 1)),
          dose.dueAt.add(const Duration(seconds: 1)),
        );
        final current = candidates.where((d) => d.id == dose.id).firstOrNull;
        if (current == null) {
          throw const FormatException('This dose is no longer active.');
        }
        // Recheck under the mutation lock: an edit can run after an intent is read
        // but before its action commits. Manual historical corrections stay valid.
        if (requireActive && !current.remindersAllowed) {
          throw const FormatException('This reminder is no longer active.');
        }
        if (current.canceled && action != DoseAction.undo) {
          throw const FormatException(
            'This dose was canceled by a schedule change.',
          );
        }
        if (!current.remindersAllowed &&
            (action == DoseAction.snooze ||
                (!current.dueAt.isBefore(clock()) &&
                    action != DoseAction.undo))) {
          throw const FormatException(
            'This reminder was canceled by a schedule change.',
          );
        }
        if (requestId != null && data.events.any((e) => e.id == requestId)) {
          return data;
        }
        if ((current.isComplete && action != DoseAction.undo) ||
            (action == DoseAction.undo &&
                (current.latestEvent == null ||
                    current.latestEvent!.action == DoseAction.undo))) {
          return data;
        }
        final now = clock();
        final event = DoseEvent(
          id: requestId ?? const Uuid().v4(),
          occurrenceId: dose.id,
          action: action,
          recordedAt: now,
          snoozedUntil: action == DoseAction.snooze
              ? (dose.dueAt.isAfter(now) ? dose.dueAt : now).add(
                  const Duration(minutes: 15),
                )
              : null,
        );
        final updated = data.copyWith(
          events: [...data.events, event],
          recordedDoses: data.recordedDoses.any((d) => d.id == dose.id)
              ? data.recordedDoses
              : [...data.recordedDoses, current],
        );
        return applyStockAction(updated, current, event);
      }, cancelDose: dose.id);

  Future<void> enableReminders() async {
    try {
      await notifications.requestPermissions();
      await refresh();
    } catch (_) {
      _errorMessage =
          'Could not request notification access. Open device Settings and retry.';
      _notify();
    }
  }

  Future<void> openNotificationSettings() async {
    try {
      await notifications.openSettings();
    } catch (_) {
      _errorMessage =
          'Open your device Settings, then Medicine Reminder, then Notifications.';
      _notify();
    }
  }

  void _onIntent() {
    final pending = notifications.intent.value;
    if (pending == null || _isLoading || _owner == null) return;
    notifications.intent.value = null;
    unawaited(_handleIntent(pending));
  }

  Future<void> _handleIntent(ReminderIntent pending) async {
    await ready;
    if (pending.owner != _owner) {
      _errorMessage = 'This reminder belongs to another account.';
      _notify();
      return;
    }
    if (pending.refillMedicineId != null) {
      if (_data.stockFor(pending.refillMedicineId!) != null &&
          medications.any(
            (m) => m.id == pending.refillMedicineId && !m.archived,
          )) {
        focusedRefill = pending.refillMedicineId;
        _notify();
      }
      return;
    }
    final matches = _data
        .doses(
          pending.dueAt.subtract(const Duration(seconds: 1)),
          pending.dueAt.add(const Duration(seconds: 1)),
        )
        .where((d) => d.id == pending.occurrenceId);
    if (matches.isEmpty || !matches.first.remindersAllowed) {
      _errorMessage = 'This reminder is no longer active.';
      _notify();
      return;
    }
    final dose = matches.first;
    if (pending.action == 'taken' || pending.action == 'snooze') {
      await act(
        dose,
        pending.action == 'taken' ? DoseAction.taken : DoseAction.snooze,
        requestId:
            'notification:${dose.id}:${pending.action}:${pending.alertKey ?? pending.dueAt.toUtc().toIso8601String()}',
        requireActive: true,
      );
    } else {
      focusedDose = dose;
      _notify();
    }
  }

  void clearFocus() {
    focusedDose = null;
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _notify();
  }

  void setFilter(MedicineFilter filter) {
    _filter = filter;
    _notify();
  }

  void clearError() {
    _errorMessage = null;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    notifications.intent.removeListener(_onIntent);
    unawaited(_queue.then((_) => store.close()));
    super.dispose();
  }
}
