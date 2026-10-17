import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:timezone/timezone.dart' as tz;

import 'local_data_cleanup.dart';
import '../models/medication.dart';
import '../models/inventory.dart';
import '../models/reminder_context.dart';

class MedicineData {
  final List<Medication> medications;
  final List<DoseEvent> events;
  final List<Medication> previousRevisions;
  final List<DoseOccurrence> recordedDoses;
  final List<StockAccount> stockAccounts;
  final List<StockEntry> stockEntries;
  final ReminderContext? reminderContext;
  final String? acknowledgedTimezone;
  const MedicineData({
    this.medications = const [],
    this.events = const [],
    this.previousRevisions = const [],
    this.recordedDoses = const [],
    this.stockAccounts = const [],
    this.stockEntries = const [],
    this.reminderContext,
    this.acknowledgedTimezone,
  });

  MedicineData copyWith({
    List<Medication>? medications,
    List<DoseEvent>? events,
    List<Medication>? previousRevisions,
    List<DoseOccurrence>? recordedDoses,
    List<StockAccount>? stockAccounts,
    List<StockEntry>? stockEntries,
    ReminderContext? reminderContext,
    String? acknowledgedTimezone,
  }) =>
      MedicineData(
        medications: medications ?? this.medications,
        events: events ?? this.events,
        previousRevisions: previousRevisions ?? this.previousRevisions,
        recordedDoses: recordedDoses ?? this.recordedDoses,
        stockAccounts: stockAccounts ?? this.stockAccounts,
        stockEntries: stockEntries ?? this.stockEntries,
        reminderContext: reminderContext ?? this.reminderContext,
        acknowledgedTimezone: acknowledgedTimezone ?? this.acknowledgedTimezone,
      );

  StockAccount? stockFor(String medicineId) => stockAccounts
      .where((s) => s.medicineId == medicineId && s.active)
      .firstOrNull;
  int balance(String accountId) => stockEntries
      .where((e) => e.accountId == accountId)
      .fold(0, (sum, e) => sum + e.delta);
  MedicineData replaceStock(
    StockAccount account, {
    List<StockEntry>? entries,
  }) =>
      copyWith(
        stockAccounts: [
          ...stockAccounts.where((a) => a.id != account.id),
          account
        ],
        stockEntries: entries ?? stockEntries,
      );

  DoseEvent? latestEvent(String id) =>
      events.where((e) => e.occurrenceId == id).lastOrNull;

  DoseOccurrence recordedDose(DoseOccurrence snapshot) {
    final active =
        medications.where((m) => m.id == snapshot.medication.id).firstOrNull;
    final closed = previousRevisions
        .where(
          (m) =>
              m.id == snapshot.medication.id &&
              m.revision == snapshot.medication.revision,
        )
        .firstOrNull;
    return DoseOccurrence(
      medication: snapshot.medication,
      dueAt: snapshot.dueAt,
      id: snapshot.id,
      latestEvent: latestEvent(snapshot.id),
      canceled: closed?.effectiveUntil != null &&
          !snapshot.dueAt.isBefore(closed!.effectiveUntil!),
      remindersAllowed: active != null &&
          !active.paused &&
          !active.archived &&
          active.revision == snapshot.medication.revision,
    );
  }

  /// A single read projection for UI and native scheduling. Historical records
  /// own their original slot, even after an early confirmation or later undo.
  List<DoseOccurrence> doses(
    DateTime from,
    DateTime until, {
    bool remindersOnly = false,
  }) {
    final result = <String, DoseOccurrence>{};
    for (final dose in const ScheduleEngine().generate(
      [...medications, if (!remindersOnly) ...previousRevisions],
      events,
      from,
      until,
    )) {
      final current =
          medications.where((m) => m.id == dose.medication.id).firstOrNull;
      result[dose.id] = DoseOccurrence(
        medication: dose.medication,
        dueAt: dose.dueAt,
        id: dose.id,
        latestEvent: dose.latestEvent,
        remindersAllowed: current?.revision == dose.medication.revision &&
            current?.paused == false &&
            current?.archived == false,
      );
    }
    for (final snapshot in recordedDoses) {
      if (snapshot.dueAt.isBefore(from) || !snapshot.dueAt.isBefore(until)) {
        continue;
      }
      final dose = recordedDose(snapshot);
      final wasConfirmed = events.any(
        (e) =>
            e.occurrenceId == dose.id &&
            (e.action == DoseAction.taken || e.action == DoseAction.skipped),
      );
      // Unconfirmed obsolete future snoozes are canceled, not carried forward.
      if (!dose.remindersAllowed &&
          !wasConfirmed &&
          !result.containsKey(dose.id)) {
        continue;
      }
      result.removeWhere(
        (id, other) =>
            id != dose.id &&
            other.medication.id == dose.medication.id &&
            other.dueAt.isAtSameMomentAs(dose.dueAt),
      );
      result[dose.id] = dose;
    }
    final sorted = result.values
        .where((d) => !remindersOnly || d.remindersAllowed)
        .toList()
      ..sort((a, b) {
        final order = a.dueAt.compareTo(b.dueAt);
        return order == 0 ? a.id.compareTo(b.id) : order;
      });
    return sorted;
  }

  Map<String, dynamic> toJson() => {
        'version': 3,
        'medications': medications.map((m) => m.toJson()).toList(),
        'events': events.map((e) => e.toJson()).toList(),
        'previousRevisions': previousRevisions.map((m) => m.toJson()).toList(),
        'recordedDoses': recordedDoses.map((d) => d.toJson()).toList(),
        'stockAccounts': stockAccounts.map((a) => a.toJson()).toList(),
        'stockEntries': stockEntries.map((e) => e.toJson()).toList(),
        'reminderContext': reminderContext?.toJson(),
        'acknowledgedTimezone': acknowledgedTimezone,
      };
  factory MedicineData.decode(String value) {
    final j = jsonDecode(value) as Map<String, dynamic>;
    if (![1, 2, 3].contains(j['version'])) {
      throw const FormatException('Unsupported medicine data version.');
    }
    final data = MedicineData(
      medications: (j['medications'] as List)
          .map(
            (m) => Medication.fromJson(Map<String, dynamic>.from(m as Map))
              ..validate(),
          )
          .toList(),
      events: (j['events'] as List)
          .map((e) => DoseEvent.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      previousRevisions: (j['previousRevisions'] as List? ?? [])
          .map(
            (m) => Medication.fromJson(Map<String, dynamic>.from(m as Map))
              ..validate(),
          )
          .toList(),
      recordedDoses: (j['recordedDoses'] as List? ?? [])
          .map(
            (d) => DoseOccurrence.fromJson(Map<String, dynamic>.from(d as Map)),
          )
          .toList(),
      stockAccounts: (j['stockAccounts'] as List? ?? [])
          .map(
            (a) => StockAccount.fromJson(Map<String, dynamic>.from(a as Map)),
          )
          .toList(),
      stockEntries: (j['stockEntries'] as List? ?? [])
          .map((e) => StockEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      reminderContext: j['reminderContext'] == null
          ? null
          : ReminderContext.fromJson(
              Map<String, dynamic>.from(j['reminderContext'] as Map),
            ),
      acknowledgedTimezone: j['acknowledgedTimezone'] as String?,
    );
    if (j['version'] != 1) return data;
    final snapshots = <String, DoseOccurrence>{};
    for (final event in data.events) {
      final parts = event.occurrenceId.split(':');
      if (parts.length < 4) {
        throw const FormatException('Invalid saved dose identity.');
      }
      final date = DateTime.parse(parts[parts.length - 2]);
      final plan = data.medications
          .where((m) => event.occurrenceId.startsWith('${m.id}:${m.revision}:'))
          .firstOrNull;
      if (plan == null) continue;
      // v1 pause hid recurrence but did not remove recorded occurrences.
      final zone = tz.getLocation(plan.timezone);
      for (final dose in const ScheduleEngine().generate(
        [plan.copyWith(paused: false, archived: false)],
        [],
        tz.TZDateTime(zone, date.year, date.month, date.day),
        tz.TZDateTime(zone, date.year, date.month, date.day + 1),
      )) {
        if (dose.id == event.occurrenceId) snapshots[dose.id] = dose;
      }
    }
    return data.copyWith(recordedDoses: snapshots.values.toList());
  }
}

abstract class MedicineStore {
  Future<void> activate(String? owner);
  Future<MedicineData> load(String owner);

  /// Mutations read and commit together, preventing UI/background lost updates.
  Future<MedicineData> change(
    String owner,
    MedicineData Function(MedicineData) transform,
  );

  /// Serializes native alarm reconciliation with account switches and mutations.
  Future<void> reconcile(
    Future<MedicineData?> Function(String? owner, MedicineData data) sync,
  );

  /// Erases all local health profiles; authentication/preferences are retained.
  Future<void> resetAll();
  Future<void> close();
}

class EncryptedMedicineStore implements MedicineStore {
  static const _secure = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  Database? _database;
  Future<Database>? _opening;
  bool get _sqlite =>
      !kIsWeb &&
      const [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      ].contains(defaultTargetPlatform);
  Future<void> _tail = Future.value();

  Future<T> _serial<T>(Future<T> Function() body) {
    final result = _tail.then((_) => body());
    _tail = result.then<void>((_) {},
        onError: (Object error, StackTrace stackTrace) {});
    return result;
  }

  Future<Database> _open() async {
    try {
      if (await _secure.read(key: 'medicine.reset.pending.v1') != null) {
        await _database?.close();
        _database = null;
        _opening = null;
      }
      return await (_opening ??= _openDatabase());
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<Database> _openDatabase() async {
    final directory = defaultTargetPlatform == TargetPlatform.iOS
        ? await const MethodChannel('medicine_reminder/settings')
            .invokeMethod<String>('medicineStorageDirectory')
        : await getDatabasesPath();
    if (directory == null) {
      throw StateError('Private medicine directory unavailable');
    }
    final databasePath = p.join(directory, 'medicines-v1.db');
    if (await _secure.read(key: 'medicine.reset.pending.v1') != null) {
      await _finishReset(databasePath);
    }
    var key = await _secure.read(key: 'medicine.database.key.v1');
    if (key == null) {
      if (await databaseExists(databasePath)) {
        throw StateError('The existing medicine database key is unavailable.');
      }
      key = base64UrlEncode(
        List<int>.generate(32, (_) => Random.secure().nextInt(256)),
      );
      await _secure.write(key: 'medicine.database.key.v1', value: key);
    }
    _database = await openDatabase(
      databasePath,
      password: key,
      singleInstance: false,
      onConfigure: (db) async {
        // Android SQLCipher returns a row for this PRAGMA.
        await db.rawQuery('PRAGMA secure_delete = ON');
      },
      version: 1,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE medicine_data (owner TEXT PRIMARY KEY, payload TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE medicine_settings (id INTEGER PRIMARY KEY CHECK(id=1), owner TEXT)',
        );
        await db.insert('medicine_settings', {'id': 1, 'owner': null});
      },
    );
    return _database!;
  }

  String _ownerKey(String owner) =>
      'medicine.data.v1.${sha256.convert(utf8.encode(owner))}';
  Future<MedicineData> _read(DatabaseExecutor db, String owner) async {
    final rows = await db.query(
      'medicine_data',
      where: 'owner = ?',
      whereArgs: [owner],
    );
    return rows.isEmpty
        ? const MedicineData()
        : MedicineData.decode(rows.single['payload'] as String);
  }

  Future<String?> _active(DatabaseExecutor db) async =>
      (await db.query('medicine_settings')).single['owner'] as String?;

  @override
  Future<void> activate(String? owner) => _serial(() async {
        if (_sqlite) {
          final db = await _open();
          await db.transaction((tx) async {
            await tx.update('medicine_settings', {'owner': owner},
                where: 'id = 1');
          });
        } else {
          if (await _secure.read(key: 'medicine.reset.pending.v1') != null) {
            await _finishReset(null);
          }
          await _secure.write(key: 'medicine.active.v1', value: owner);
        }
      });

  @override
  Future<MedicineData> load(String owner) => _serial(() async {
        if (_sqlite) return _read(await _open(), owner);
        final value = await _secure.read(key: _ownerKey(owner));
        return value == null
            ? const MedicineData()
            : MedicineData.decode(value);
      });

  @override
  Future<MedicineData> change(
    String owner,
    MedicineData Function(MedicineData) transform,
  ) =>
      _serial(() async {
        if (_sqlite) {
          final db = await _open();
          return db.transaction((tx) async {
            if (await _active(tx) != owner) {
              throw StateError('Account changed. Please try again.');
            }
            final next = transform(await _read(tx, owner));
            await tx.insert(
                'medicine_data',
                {
                  'owner': owner,
                  'payload': jsonEncode(next.toJson()),
                },
                conflictAlgorithm: ConflictAlgorithm.replace);
            return next;
          });
        }
        if (await _secure.read(key: 'medicine.active.v1') != owner) {
          throw StateError('Account changed. Please try again.');
        }
        final raw = await _secure.read(key: _ownerKey(owner));
        final next = transform(
          raw == null ? const MedicineData() : MedicineData.decode(raw),
        );
        await _secure.write(
          key: _ownerKey(owner),
          value: jsonEncode(next.toJson()),
        );
        return next;
      });

  @override
  Future<void> reconcile(
    Future<MedicineData?> Function(String?, MedicineData) sync,
  ) =>
      _serial(() async {
        if (_sqlite) {
          final db = await _open();
          await db.transaction((tx) async {
            final owner = await _active(tx);
            final next = await sync(
              owner,
              owner == null ? const MedicineData() : await _read(tx, owner),
            );
            if (owner != null && next != null) {
              await tx.insert(
                  'medicine_data',
                  {
                    'owner': owner,
                    'payload': jsonEncode(next.toJson()),
                  },
                  conflictAlgorithm: ConflictAlgorithm.replace);
            }
          });
        } else {
          final owner = await _secure.read(key: 'medicine.active.v1');
          final raw =
              owner == null ? null : await _secure.read(key: _ownerKey(owner));
          final next = await sync(
            owner,
            raw == null ? const MedicineData() : MedicineData.decode(raw),
          );
          if (owner != null && next != null) {
            await _secure.write(
              key: _ownerKey(owner),
              value: jsonEncode(next.toJson()),
            );
          }
        }
      });

  Future<void> _finishReset(String? databasePath) async {
    // The marker survives cancellation/storage failure. Never open health data
    // until every cleanup step completes, including native alarms and exports.
    // Hold the same SQLite write lock used by background reconciliation.
    // A worker that ran first is canceled here; one that runs later sees no rows.
    Database? resetDb = _database;
    if (resetDb == null &&
        databasePath != null &&
        await databaseExists(databasePath)) {
      final key = await _secure.read(key: 'medicine.database.key.v1');
      if (key != null) {
        try {
          resetDb = await openDatabase(databasePath,
              password: key, singleInstance: false);
        } on DatabaseException {
          // An explicitly requested reset also handles a corrupt/unreadable DB.
          // Normal opens still preserve and report such data, never erase it.
          resetDb = null;
        }
      }
    }
    if (resetDb != null) {
      await resetDb.transaction((tx) async {
        await tx.rawQuery('PRAGMA secure_delete = ON');
        final tables = (await tx.rawQuery(
                "SELECT name FROM sqlite_master WHERE type = 'table'"))
            .map((row) => row['name'])
            .toSet();
        if (tables.contains('medicine_data')) await tx.delete('medicine_data');
        if (tables.contains('medicine_settings')) {
          await tx.update('medicine_settings', {'owner': null},
              where: 'id = 1');
        }
        await clearLocalMedicineArtifacts();
      });
    } else {
      await clearLocalMedicineArtifacts();
    }
    await resetDb?.close();
    _database = null;
    _opening = null;
    if (databasePath != null) await deleteDatabase(databasePath);
    for (final key in (await _secure.readAll()).keys) {
      if (key == 'medicine.database.key.v1' ||
          key == 'medicine.active.v1' ||
          key.startsWith('medicine.data.v1.')) {
        await _secure.delete(key: key);
      }
    }
    await _secure.delete(key: 'medicine.reset.pending.v1');
  }

  @override
  Future<void> resetAll() => _serial(() async {
        await _secure.write(
            key: 'medicine.reset.pending.v1', value: 'requested');
        final directory = !_sqlite
            ? null
            : defaultTargetPlatform == TargetPlatform.iOS
                ? await const MethodChannel('medicine_reminder/settings')
                    .invokeMethod<String>('medicineStorageDirectory')
                : await getDatabasesPath();
        if (_sqlite && directory == null) {
          throw StateError('Private medicine directory unavailable');
        }
        await _finishReset(
            directory == null ? null : p.join(directory, 'medicines-v1.db'));
        _opening = null;
      });

  @override
  Future<void> close() => _serial(() async {
        await _database?.close();
        _database = null;
        _opening = null;
      });
}

/// Test adapter; production never silently falls back to volatile storage.
class MemoryMedicineStore implements MedicineStore {
  final Map<String, MedicineData> records = {};
  String? activeOwner;
  bool failWrites = false;
  @override
  Future<void> activate(String? owner) async {
    activeOwner = owner;
  }

  @override
  Future<MedicineData> load(String owner) async =>
      records[owner] ?? const MedicineData();
  @override
  Future<MedicineData> change(
    String owner,
    MedicineData Function(MedicineData) transform,
  ) async {
    if (failWrites) throw StateError('Storage unavailable');
    if (activeOwner != owner) throw StateError('Account changed');
    return records[owner] = transform(await load(owner));
  }

  @override
  Future<void> reconcile(
    Future<MedicineData?> Function(String?, MedicineData) sync,
  ) async {
    final owner = activeOwner;
    final next = await sync(
      owner,
      owner == null ? const MedicineData() : await load(owner),
    );
    if (owner != null && next != null) {
      if (failWrites) throw StateError('Storage unavailable');
      records[owner] = next;
    }
  }

  @override
  Future<void> resetAll() async {
    if (failWrites) throw StateError('Storage unavailable');
    records.clear();
    activeOwner = null;
  }

  @override
  Future<void> close() async {}
}
