import 'package:medicine_reminder/core/l10n/app_copy.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../models/medication.dart';
import '../../../../../providers/medicine_reminder_provider.dart';

String doseTime(BuildContext context, DateTime time) =>
    TimeOfDay.fromDateTime(time.toLocal()).format(context);

Future<void> showDoseDetails(
  BuildContext context,
  DoseOccurrence dose, {
  bool allowSnooze = true,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DoseDetails(dose: dose, allowSnooze: allowSnooze),
    );

class MedicineCard extends StatelessWidget {
  final DoseOccurrence dose;
  const MedicineCard({super.key, required this.dose});
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MedicineReminderProvider>();
    final m = dose.medication;
    final status = dose.status(provider.clock());
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showDoseDetails(context, dose),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 82,
                      child: Text(
                        doseTime(context, dose.dueAt),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${m.amount} ${m.unit}${m.strength.isEmpty ? '' : ' · ${m.strength}'}',
                          ),
                          const SizedBox(height: 4),
                          AppText(
                            status,
                            style: TextStyle(
                              color: dose.isTaken
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                            ),
                          ),
                          if (status == 'Snoozed')
                            AppText(
                              'Next alert ${doseTime(context, dose.alertAt)}',
                            ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                const SizedBox(height: 8),
                _DoseActions(dose: dose),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DoseActions extends StatefulWidget {
  final DoseOccurrence dose;
  final bool allowSnooze;
  const _DoseActions({required this.dose, this.allowSnooze = true});
  @override
  State<_DoseActions> createState() => _DoseActionsState();
}

class _DoseActionsState extends State<_DoseActions> {
  bool _busy = false;
  Future<void> _act(DoseAction action) async {
    if (_busy) return;
    final provider = context.read<MedicineReminderProvider>();
    setState(() => _busy = true);
    final success = await provider.act(widget.dose, action);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              AppText(provider.errorMessage ?? 'Could not save this action.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          if (widget.dose.isComplete)
            TextButton.icon(
              onPressed: _busy ? null : () => _act(DoseAction.undo),
              icon: const Icon(Icons.undo, size: 18),
              label: const AppText('Undo'),
            )
          else if (!widget.dose.canceled &&
              (widget.dose.remindersAllowed ||
                  !widget.dose.dueAt.isAfter(
                    context.read<MedicineReminderProvider>().clock(),
                  ))) ...[
            FilledButton.tonalIcon(
              onPressed: _busy ? null : () => _act(DoseAction.taken),
              icon: const Icon(Icons.check, size: 18),
              label: const AppText('Taken'),
            ),
            TextButton(
              onPressed: _busy ? null : () => _act(DoseAction.skipped),
              child: const AppText('Skip'),
            ),
            if (widget.allowSnooze && widget.dose.remindersAllowed)
              TextButton(
                onPressed: _busy ? null : () => _act(DoseAction.snooze),
                child: const AppText('Snooze 15 min'),
              ),
            if (widget.allowSnooze &&
                widget.dose.remindersAllowed &&
                widget.dose.latestEvent?.action == DoseAction.snooze)
              TextButton(
                onPressed: _busy ? null : () => _act(DoseAction.undo),
                child: const AppText('Undo snooze'),
              ),
          ],
        ],
      );
}

class _DoseDetails extends StatelessWidget {
  final DoseOccurrence dose;
  final bool allowSnooze;
  const _DoseDetails({required this.dose, this.allowSnooze = true});
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MedicineReminderProvider>();
    final current = provider
            .dosesBetween(
              dose.dueAt.subtract(const Duration(seconds: 1)),
              dose.dueAt.add(const Duration(seconds: 1)),
            )
            .where((d) => d.id == dose.id)
            .firstOrNull ??
        provider
            .recordedHistory(dose.medication.id)
            .where((d) => d.id == dose.id)
            .firstOrNull;
    if (current == null) {
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: AppText('This dose is no longer active.'),
        ),
      );
    }
    final medicine = current.medication;
    final event = current.latestEvent;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              medicine.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text('${medicine.amount} ${medicine.unit} · ${medicine.form}'),
            if (medicine.strength.isNotEmpty)
              AppText('Strength: ${medicine.strength}'),
            AppText(
              'Scheduled ${dateKey(current.dueAt.toLocal())} at ${doseTime(context, current.dueAt)}',
            ),
            AppText('Schedule timezone: ${medicine.timezone}'),
            const SizedBox(height: 16),
            AppText(
              current.status(provider.clock()),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (event != null)
              AppText(
                'Recorded ${dateKey(event.recordedAt.toLocal())} at ${doseTime(context, event.recordedAt)}',
              ),
            if (!current.remindersAllowed)
              const AppText('Previous schedule · reminders canceled'),
            if (current.remindersAllowed &&
                current.latestEvent?.action == DoseAction.snooze)
              AppText(
                'Next alert ${dateKey(current.alertAt.toLocal())} at ${doseTime(context, current.alertAt)}',
              ),
            if (medicine.instructions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(medicine.instructions),
            ],
            const SizedBox(height: 20),
            _DoseActions(dose: current, allowSnooze: allowSnooze),
          ],
        ),
      ),
    );
  }
}
