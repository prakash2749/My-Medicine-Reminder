class ReminderContext {
  final String timezone;
  final DateTime wallTime;
  final int? elapsedMillis, bootCount, generation;
  const ReminderContext({
    required this.timezone,
    required this.wallTime,
    this.elapsedMillis,
    this.bootCount,
    this.generation,
  });

  bool clockChangedSince(ReminderContext old) {
    if (elapsedMillis == null || old.elapsedMillis == null) {
      return wallTime.isBefore(old.wallTime);
    }
    if (bootCount != old.bootCount || elapsedMillis! < old.elapsedMillis!) {
      return false;
    }
    final wallDelta = wallTime.difference(old.wallTime).inMilliseconds;
    return (wallDelta - (elapsedMillis! - old.elapsedMillis!)).abs() > 120000;
  }

  bool needsRebuild(ReminderContext? old) =>
      old == null ||
      timezone != old.timezone ||
      generation != old.generation ||
      bootCount != old.bootCount ||
      clockChangedSince(old) ||
      (elapsedMillis != null &&
          old.elapsedMillis != null &&
          elapsedMillis! < old.elapsedMillis!);

  Map<String, dynamic> toJson() => {
        'timezone': timezone,
        'wallTime': wallTime.toUtc().toIso8601String(),
        'elapsedMillis': elapsedMillis,
        'bootCount': bootCount,
        'generation': generation,
      };
  factory ReminderContext.fromJson(Map<String, dynamic> j) => ReminderContext(
        timezone: j['timezone'] as String,
        wallTime: DateTime.parse((j['wallTime'] ??
            j['lastReconciledAt'] ??
            DateTime.now().toUtc().toIso8601String()) as String),
        elapsedMillis: j['elapsedMillis'] as int?,
        bootCount: j['bootCount'] as int?,
        generation: j['generation'] as int?,
      );
}
