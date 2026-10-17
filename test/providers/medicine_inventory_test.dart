import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_reminder/core/models/inventory.dart';
import 'package:medicine_reminder/core/models/medication.dart';
import 'package:medicine_reminder/core/services/medicine_store.dart';
import 'package:medicine_reminder/providers/medicine_reminder_provider.dart';

import '../support/medicine_fakes.dart';

void main() {
  late MedicineReminderProvider provider;
  late MemoryMedicineStore store;
  late DateTime now;
  Future<void> setupStock({
    String amount = '10',
    String threshold = '2',
  }) async {
    expect(
      await provider.startStock(
        provider.medications.single,
        amount,
        threshold,
        requestId: 'initial',
      ),
      isTrue,
    );
  }

  StockAccount stock() => provider.stockFor('med-1')!;
  int balance() => provider.stockBalance(stock().id);
  setUp(() async {
    now = DateTime(2026, 10, 17, 10);
    store = MemoryMedicineStore();
    provider = MedicineReminderProvider(
      store: store,
      notifications: FakeNotifications(),
      clock: () => now,
    );
    provider.bindUser('alice');
    await provider.ready;
    await provider.addMedication(testMedication(amount: '0.1'));
  });
  tearDown(() => provider.dispose());

  test('decimal quantities are exact and round-trip negative balances', () {
    expect(parseQuantity('0.1') + parseQuantity('0.2'), parseQuantity('0.3'));
    expect(quantityLabel(-12345), '-1.2345');
    expect(quantityLabel(parseQuantity('0.5000')), '0.5');
    expect(() => parseQuantity('0'), throwsFormatException);
    expect(parseQuantity('0', allowZero: true), 0);
    for (final value in [
      '-1',
      '1e3',
      'NaN',
      '0.00001',
      '1000000',
      '2 tablets',
    ]) {
      expect(() => parseQuantity(value), throwsFormatException);
    }
  });

  test(
    'Taken decrements once and Undo restores once, including repeat taps',
    () async {
      await setupStock(amount: '1');
      final dose = provider.todayDoses.first;
      await Future.wait([
        provider.act(dose, DoseAction.taken),
        provider.act(dose, DoseAction.taken),
      ]);
      expect(balance(), 9000);
      await provider.act(dose, DoseAction.undo);
      await provider.act(dose, DoseAction.undo);
      expect(balance(), 10000);
      await provider.act(dose, DoseAction.taken);
      expect(balance(), 9000);
      expect(
        provider
            .stockLedger('med-1')
            .where((e) => e.kind == StockEntryKind.consumption),
        hasLength(2),
      );
    },
  );

  test(
    'skip, unconfirmed, snooze, and undo snooze do not consume stock',
    () async {
      await setupStock();
      final dose = provider.todayDoses.first;
      await provider.act(dose, DoseAction.snooze);
      await provider.act(dose, DoseAction.undo);
      await provider.act(dose, DoseAction.skipped);
      await provider.act(dose, DoseAction.undo);
      expect(balance(), 100000);
      expect(provider.stockLedger('med-1'), hasLength(1));
    },
  );

  test(
      'initial stock is a current baseline and prior Taken undo cannot invent stock',
      () async {
    final dose = provider.todayDoses.first;
    await provider.act(dose, DoseAction.taken);
    await setupStock(amount: '5');
    expect(balance(), 50000);
    await provider.act(dose, DoseAction.undo);
    expect(balance(), 50000);
  });

  test(
    'insufficient stock remains negative and dose confirmation is retained',
    () async {
      await setupStock(amount: '0.05');
      expect(
        await provider.act(provider.todayDoses.first, DoseAction.taken),
        isTrue,
      );
      expect(balance(), -500);
      expect(provider.todayDoses.first.isTaken, isTrue);
      final before = List.of(provider.events);
      final account = stock();
      expect(
        await provider.updateStock(
          account,
          quantity: '3',
          refill: false,
          expectedBalance: balance(),
          requestId: 'count',
        ),
        isTrue,
      );
      expect(balance(), 30000);
      expect(provider.events, before);
    },
  );

  test(
    'refill is additive, idempotent and resets the low-stock episode',
    () async {
      await setupStock(amount: '1');
      final account = stock();
      await provider.updateStock(
        account,
        quantity: '0.5',
        refill: true,
        requestId: 'refill',
      );
      await provider.updateStock(
        account,
        quantity: '0.5',
        refill: true,
        requestId: 'refill',
      );
      expect(balance(), 15000);
      expect(stock().episode, account.episode + 1);
      expect(provider.stockLedger('med-1'), hasLength(2));
    },
  );

  test(
    'stale physical count cannot overwrite newly recorded consumption',
    () async {
      await setupStock();
      final account = stock(), oldBalance = balance();
      await provider.act(provider.todayDoses.first, DoseAction.taken);
      expect(
        await provider.updateStock(
          account,
          quantity: '7',
          refill: false,
          expectedBalance: oldBalance,
          requestId: 'stale',
        ),
        isFalse,
      );
      expect(provider.errorMessage, contains('count was open'));
      expect(balance(), 99000);
      expect(
        await provider.updateStock(
          stock(),
          quantity: '7',
          refill: false,
          expectedBalance: balance(),
          requestId: 'fresh',
          note: 'Physical count',
        ),
        isTrue,
      );
      expect(balance(), 70000);
    },
  );

  test(
    'threshold changes are checked against current stock revision',
    () async {
      await setupStock();
      final old = stock();
      expect(await provider.setStockThreshold(old, '3.5'), isTrue);
      expect(stock().threshold, 35000);
      expect(await provider.setStockThreshold(old, '6'), isFalse);
      expect(balance(), 100000);
    },
  );

  test('tracked units cannot change and no conversions are guessed', () async {
    await setupStock();
    final changed = Medication.fromJson(
      provider.medications.single.toJson()..['unit'] = 'mg',
    );
    expect(await provider.editMedication(changed), isFalse);
    expect(provider.errorMessage, contains('Stop stock tracking'));
    expect(provider.medications.single.unit, 'tablet');
    await provider.stopStock(stock());
    expect(await provider.editMedication(changed), isTrue);
    expect(provider.stockFor('med-1'), isNull);
    expect(provider.stockLedger('med-1'), hasLength(1));
    expect(
      await provider.startStock(
        provider.medications.single,
        '100',
        '10',
        requestId: 'new-unit',
      ),
      isTrue,
    );
    expect(stock().unit, 'mg');
    expect(provider.stockLedger('med-1'), hasLength(2));
    expect(
      provider
          .stockLedger('med-1')
          .map((e) => provider.stockUnitFor(e.accountId))
          .toSet(),
      {'tablet', 'mg'},
    );
  });

  test(
    'name changes and archive preserve stock identity and original consumption',
    () async {
      await setupStock();
      final account = stock();
      await provider.act(provider.todayDoses.first, DoseAction.taken);
      final changed = Medication.fromJson(
        provider.medications.single.toJson()
          ..['name'] = 'Renamed'
          ..['amount'] = '2',
      );
      await provider.editMedication(changed);
      expect(stock().id, account.id);
      expect(balance(), 99000);
      await provider.archiveMedication(provider.medications.single);
      expect(provider.stockLedger('med-1'), hasLength(2));
      expect(
        await provider.updateStock(
          stock(),
          quantity: '2',
          refill: true,
          requestId: 'archived',
        ),
        isFalse,
      );
    },
  );

  test(
    'old Taken undo reverses its original quantity after dose edits',
    () async {
      await setupStock();
      final original = provider.todayDoses.first;
      await provider.act(original, DoseAction.taken);
      await provider.editMedication(
        Medication.fromJson(
          provider.medications.single.toJson()..['amount'] = '2',
        ),
      );
      await provider.act(original, DoseAction.undo);
      expect(balance(), 100000);
      await provider.act(original, DoseAction.taken);
      expect(balance(), 99000);
    },
  );

  test('failed dose/stock writes preserve ledger and event history', () async {
    await setupStock();
    store.failWrites = true;
    expect(
      await provider.act(provider.todayDoses.first, DoseAction.taken),
      isFalse,
    );
    expect(
      await provider.updateStock(
        stock(),
        quantity: '20',
        refill: true,
        requestId: 'failed',
      ),
      isFalse,
    );
    expect(balance(), 100000);
    expect(provider.events, isEmpty);
    expect(provider.stockLedger('med-1'), hasLength(1));
  });

  test('invalid quantities do not change stock', () async {
    expect(
      await provider.startStock(
        provider.medications.single,
        '-1',
        '3',
        requestId: 'bad',
      ),
      isFalse,
    );
    expect(provider.stockFor('med-1'), isNull);
    await setupStock();
    expect(
      await provider.updateStock(
        stock(),
        quantity: '0',
        refill: true,
        requestId: 'zero',
      ),
      isFalse,
    );
    expect(await provider.setStockThreshold(stock(), 'NaN'), isFalse);
    expect(balance(), 100000);
  });

  test('queued refill and inventory never cross accounts', () async {
    await setupStock();
    final action = provider.updateStock(
      stock(),
      quantity: '5',
      refill: true,
      requestId: 'queued',
    );
    provider.bindUser('bob');
    expect(await action, isFalse);
    await provider.ready;
    expect(provider.stockFor('med-1'), isNull);
    expect((await store.load('bob')).stockEntries, isEmpty);
    provider.bindUser('alice');
    await provider.ready;
    expect(balance(), 100000);
  });

  test(
    'v3 restores decimal ledger and v2 migration leaves stock unknown',
    () async {
      await setupStock(amount: '0.3');
      await provider.act(provider.todayDoses.first, DoseAction.taken);
      final data = await store.load('alice');
      final decoded = MedicineData.decode(jsonEncode(data.toJson()));
      expect(decoded.balance(decoded.stockFor('med-1')!.id), 2000);
      final old = data.toJson()
        ..['version'] = 2
        ..remove('stockAccounts')
        ..remove('stockEntries')
        ..remove('reminderContext');
      final migrated = MedicineData.decode(jsonEncode(old));
      expect(migrated.stockAccounts, isEmpty);
      expect(migrated.events.single.action, DoseAction.taken);
      expect(migrated.medications.single.name, 'Test medicine');
    },
  );

  test(
    'supply estimate uses current dose quantity and excludes completed doses',
    () async {
      await setupStock(amount: '0.2');
      final firstEstimate = provider.supplyEstimate(
        provider.medications.single,
      )!;
      expect(firstEstimate.depletionAt, DateTime.utc(2026, 10, 18, 2, 30));
      await provider.act(provider.todayDoses.last, DoseAction.taken);
      expect(balance(), 1000);
      expect(
        provider.supplyEstimate(provider.medications.single)!.depletionAt,
        DateTime.utc(2026, 10, 18, 2, 30),
      );
      await provider.setPaused(provider.medications.single, true);
      expect(provider.supplyEstimate(provider.medications.single), isNull);
    },
  );

  test(
    'delete removes only this medicine inventory and keeps other accounts',
    () async {
      await setupStock();
      final other = testMedication(id: 'other');
      await provider.addMedication(other);
      await provider.startStock(other, '4', '1', requestId: 'other-initial');
      await provider.deleteMedication('med-1');
      final data = await store.load('alice');
      expect(data.stockAccounts.single.medicineId, 'other');
      expect(data.stockEntries.single.delta, 40000);
    },
  );
}
