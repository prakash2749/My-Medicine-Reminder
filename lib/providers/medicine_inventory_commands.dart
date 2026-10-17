part of 'medicine_reminder_provider.dart';

MedicineData applyStockAction(
  MedicineData data,
  DoseOccurrence dose,
  DoseEvent event,
) {
  final stock = data.stockFor(dose.medication.id);
  if (stock == null) return data;
  var delta = 0;
  final outstanding = data.stockEntries
      .where((e) => e.accountId == stock.id && e.occurrenceId == dose.id)
      .fold(0, (sum, e) => sum + e.delta);
  if (event.action == DoseAction.taken && !dose.isTaken) {
    if (dose.medication.unit != stock.unit) {
      throw const FormatException(
        'This historical dose uses a different stock unit. Reconcile or stop stock tracking first.',
      );
    }
    delta = -parseQuantity(dose.medication.amount);
  } else if (event.action == DoseAction.undo &&
      dose.isTaken &&
      outstanding < 0) {
    delta = -outstanding;
  }
  if (delta == 0) return data;
  final oldBalance = data.balance(stock.id);
  final episode =
      oldBalance <= stock.threshold && oldBalance + delta > stock.threshold
          ? stock.episode + 1
          : stock.episode;
  return data.replaceStock(
    stock.copyWith(revision: stock.revision + 1, episode: episode),
    entries: [
      ...data.stockEntries,
      StockEntry(
        id: 'dose:${event.id}',
        accountId: stock.id,
        delta: delta,
        kind: delta < 0 ? StockEntryKind.consumption : StockEntryKind.reversal,
        recordedAt: event.recordedAt,
        occurrenceId: dose.id,
      ),
    ],
  );
}

extension MedicineInventoryCommands on MedicineReminderProvider {
  StockAccount? stockFor(String medicineId) => _data.stockFor(medicineId);
  int stockBalance(String accountId) => _data.balance(accountId);
  List<StockEntry> stockLedger(String medicineId) {
    final ids = _data.stockAccounts
        .where((s) => s.medicineId == medicineId)
        .map((s) => s.id)
        .toSet();
    return _data.stockEntries.where((e) => ids.contains(e.accountId)).toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  }

  String stockUnitFor(String accountId) =>
      _data.stockAccounts.firstWhere((a) => a.id == accountId).unit;
  SupplyEstimate? supplyEstimate(Medication medicine) =>
      estimateSupply(_data, medicine, clock());
  MedicineHistory history(
    DateTime from,
    DateTime until, {
    String? medicineId,
  }) =>
      MedicineHistory.build(
        _data,
        from,
        until,
        clock(),
        medicineId: medicineId,
      );

  Future<bool> startStock(
    Medication medicine,
    String initial,
    String threshold, {
    required String requestId,
  }) =>
      _change((data) {
        if (data.stockEntries.any((e) => e.id == requestId)) return data;
        final current = data.medications
            .where((m) => m.id == medicine.id && !m.archived)
            .firstOrNull;
        if (current == null || current.revision != medicine.revision) {
          throw const FormatException(
            'This medicine changed. Reopen stock settings.',
          );
        }
        if (data.stockFor(medicine.id) != null) {
          throw const FormatException(
            'Stock is already tracked. Reopen stock settings.',
          );
        }
        final quantity = parseQuantity(initial, allowZero: true),
            limit = parseQuantity(threshold, allowZero: true);
        final stock = StockAccount(
          id: const Uuid().v4(),
          medicineId: medicine.id,
          unit: current.unit,
          threshold: limit,
          openedAt: clock().toUtc(),
        );
        return data.copyWith(
          stockAccounts: [...data.stockAccounts, stock],
          stockEntries: [
            ...data.stockEntries,
            StockEntry(
              id: requestId,
              accountId: stock.id,
              delta: quantity,
              kind: StockEntryKind.initial,
              recordedAt: clock(),
            ),
          ],
        );
      });

  Future<bool> updateStock(
    StockAccount submitted, {
    required String quantity,
    required bool refill,
    required String requestId,
    int? expectedBalance,
    String note = '',
  }) =>
      _change((data) {
        if (data.stockEntries.any((e) => e.id == requestId)) return data;
        final current = data.stockAccounts
            .where((s) => s.id == submitted.id && s.active)
            .firstOrNull;
        if (current == null ||
            !data.medications.any(
              (m) => m.id == current.medicineId && !m.archived,
            )) {
          throw const FormatException(
              'This stock account is no longer active.');
        }
        final balance = data.balance(current.id);
        if (!refill &&
            (expectedBalance != balance ||
                current.revision != submitted.revision)) {
          throw const FormatException(
            'Stock changed while this count was open. Reopen and count again.',
          );
        }
        if (note.length > 500) {
          throw const FormatException('Use up to 500 characters for the note.');
        }
        final amount = parseQuantity(quantity, allowZero: !refill);
        final delta = refill ? amount : amount - balance;
        final nextBalance = balance + delta;
        final resetEpisode = refill ||
            (balance <= current.threshold && nextBalance > current.threshold);
        return data.replaceStock(
          current.copyWith(
            revision: current.revision + 1,
            episode: current.episode + (resetEpisode ? 1 : 0),
          ),
          entries: [
            ...data.stockEntries,
            StockEntry(
              id: requestId,
              accountId: current.id,
              delta: delta,
              kind: refill ? StockEntryKind.refill : StockEntryKind.count,
              recordedAt: clock(),
              note: note.trim(),
            ),
          ],
        );
      });

  Future<bool> setStockThreshold(StockAccount submitted, String threshold) =>
      _change((data) {
        final stock = data.stockAccounts
            .where((s) => s.id == submitted.id && s.active)
            .firstOrNull;
        if (!data.medications.any(
          (m) => m.id == submitted.medicineId && !m.archived,
        )) {
          throw const FormatException('Archived stock is read-only.');
        }
        if (stock == null || stock.revision != submitted.revision) {
          throw const FormatException('Stock changed. Reopen its settings.');
        }
        final limit = parseQuantity(threshold, allowZero: true);
        if (limit == stock.threshold) return data;
        return data.replaceStock(
          stock.copyWith(
            threshold: limit,
            revision: stock.revision + 1,
            episode: stock.episode + 1,
          ),
        );
      });

  Future<bool> stopStock(StockAccount submitted) => _change((data) {
        final current = data.stockAccounts
            .where((s) => s.id == submitted.id && s.active)
            .firstOrNull;
        if (current == null) return data;
        if (current.revision != submitted.revision) {
          throw const FormatException('Stock changed. Reopen its settings.');
        }
        return data.replaceStock(
          current.copyWith(active: false, revision: current.revision + 1),
        );
      });
}
