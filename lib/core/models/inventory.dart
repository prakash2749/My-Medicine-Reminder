/// Four decimal places, shared by doses, stock counts, and adjustments.
const quantityScale = 10000;

int parseQuantity(String value, {bool allowZero = false}) {
  final text = value.trim();
  if (!RegExp(r'^\d{1,6}(\.\d{1,4})?$').hasMatch(text)) {
    throw const FormatException(
      'Use up to 6 whole digits and 4 decimal places.',
    );
  }
  final parts = text.split('.');
  final amount = int.parse(parts.first) * quantityScale +
      (parts.length == 1 ? 0 : int.parse(parts.last.padRight(4, '0')));
  if (amount == 0 && !allowZero) {
    throw const FormatException('Enter a positive quantity.');
  }
  return amount;
}

String quantityLabel(int value) {
  final absolute = value.abs();
  final fraction = (absolute % quantityScale)
      .toString()
      .padLeft(4, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  return '${value < 0 ? '-' : ''}${absolute ~/ quantityScale}${fraction.isEmpty ? '' : '.$fraction'}';
}

enum StockEntryKind { initial, refill, count, consumption, reversal }

class StockAccount {
  final String id, medicineId, unit;
  final int threshold, revision, episode;
  final int? alertedEpisode;
  final DateTime openedAt;
  final bool active;
  const StockAccount({
    required this.id,
    required this.medicineId,
    required this.unit,
    required this.threshold,
    required this.openedAt,
    this.active = true,
    this.revision = 1,
    this.episode = 1,
    this.alertedEpisode,
  });

  StockAccount copyWith({
    int? threshold,
    int? revision,
    int? episode,
    int? alertedEpisode,
    bool? active,
  }) =>
      StockAccount(
        id: id,
        medicineId: medicineId,
        unit: unit,
        threshold: threshold ?? this.threshold,
        openedAt: openedAt,
        active: active ?? this.active,
        revision: revision ?? this.revision,
        episode: episode ?? this.episode,
        alertedEpisode: alertedEpisode ?? this.alertedEpisode,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'medicineId': medicineId,
        'unit': unit,
        'threshold': threshold,
        'openedAt': openedAt.toUtc().toIso8601String(),
        'active': active,
        'revision': revision,
        'episode': episode,
        'alertedEpisode': alertedEpisode,
      };
  factory StockAccount.fromJson(Map<String, dynamic> j) => StockAccount(
        id: j['id'] as String,
        medicineId: (j['medicineId'] ?? j['medicine_id'] ?? '') as String,
        unit: (j['unit'] ?? '') as String,
        threshold: (j['threshold'] ?? j['targetThreshold'] ?? 0) as int,
        openedAt: DateTime.parse((j['openedAt'] ??
            j['startedAt'] ??
            DateTime.now().toUtc().toIso8601String()) as String),
        active: j['active'] as bool? ?? true,
        revision: j['revision'] as int? ?? 1,
        episode: j['episode'] as int? ?? 1,
        alertedEpisode: j['alertedEpisode'] as int?,
      );
}

class StockEntry {
  final String id, accountId, note;
  final String? occurrenceId;
  final int delta;
  final StockEntryKind kind;
  final DateTime recordedAt;
  const StockEntry({
    required this.id,
    required this.accountId,
    required this.delta,
    required this.kind,
    required this.recordedAt,
    this.occurrenceId,
    this.note = '',
  });
  Map<String, dynamic> toJson() => {
        'id': id,
        'accountId': accountId,
        'delta': delta,
        'kind': kind.name,
        'recordedAt': recordedAt.toUtc().toIso8601String(),
        'occurrenceId': occurrenceId,
        'note': note,
      };
  factory StockEntry.fromJson(Map<String, dynamic> j) {
    final rawKind = (j['kind'] ?? j['type'] ?? 'initial') as String;
    final normalized = rawKind == 'baseline' ? 'initial' : rawKind;
    final matchedKind = StockEntryKind.values.firstWhere(
      (k) => k.name == normalized,
      orElse: () => StockEntryKind.initial,
    );
    return StockEntry(
      id: j['id'] as String,
      accountId: j['accountId'] as String,
      delta: j['delta'] as int,
      kind: matchedKind,
      recordedAt: DateTime.parse(j['recordedAt'] as String),
      occurrenceId: j['occurrenceId'] as String?,
      note: (j['note'] ?? '') as String,
    );
  }
}
