import '../models/medication.dart';
import '../models/inventory.dart';
import 'medicine_store.dart';

enum HistoryFilter { all, taken, skipped, unconfirmed }

class MedicineHistory {
  final List<DoseOccurrence> doses;
  final int coverageGaps;
  const MedicineHistory(this.doses, this.coverageGaps);
  int get eligible => doses.length;
  int get taken => doses.where((d) => d.isTaken).length;
  int get skipped => doses.where((d) => d.isSkipped).length;
  int get unconfirmed => eligible - taken - skipped;
  double get recordedTakenFraction => eligible == 0 ? 0 : taken / eligible;

  factory MedicineHistory.build(
    MedicineData data,
    DateTime from,
    DateTime until,
    DateTime now, {
    String? medicineId,
  }) {
    if (until.isBefore(from) || until.difference(from).inDays > 366) {
      throw const FormatException('Choose a date range of at most 366 days.');
    }
    var gaps = 0;
    final eligible = <DoseOccurrence>[];
    for (final dose in data.doses(from, until)) {
      if (medicineId != null && dose.medication.id != medicineId) continue;
      if (dose.dueAt.isAfter(now) || (dose.canceled && !dose.isComplete)) {
        continue;
      }
      final coverage = dose.medication.recordingStartedAt;
      if (dose.latestEvent == null &&
          (coverage == null || dose.dueAt.isBefore(coverage))) {
        gaps++;
      } else {
        eligible.add(dose);
      }
    }
    return MedicineHistory(eligible.reversed.toList(), gaps);
  }
}

class SupplyEstimate {
  final DateTime? depletionAt;
  final bool beyondHorizon;
  const SupplyEstimate({this.depletionAt, this.beyondHorizon = false});
}

SupplyEstimate? estimateSupply(
  MedicineData data,
  Medication medicine,
  DateTime now,
) {
  final stock = data.stockFor(medicine.id);
  if (stock == null ||
      stock.unit != medicine.unit ||
      medicine.paused ||
      medicine.archived) {
    return null;
  }
  var remaining = data.balance(stock.id);
  if (remaining <= 0) return SupplyEstimate(depletionAt: now);
  final quantity = parseQuantity(medicine.amount);
  final future = data
      .doses(now, now.add(const Duration(days: 90)), remindersOnly: true)
      .where((d) => d.medication.id == medicine.id && !d.isComplete);
  for (final dose in future) {
    remaining -= quantity;
    if (remaining <= 0) return SupplyEstimate(depletionAt: dose.dueAt);
  }
  return const SupplyEstimate(beyondHorizon: true);
}
