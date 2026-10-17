import 'package:medicine_reminder/core/l10n/app_copy.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../models/medication.dart';
import '../../../../../providers/medicine_reminder_provider.dart';

class AddMedicineSheet extends StatefulWidget {
  final Medication? medicine;
  const AddMedicineSheet({super.key, this.medicine});
  @override
  State<AddMedicineSheet> createState() => _AddMedicineSheetState();
}

class _AddMedicineSheetState extends State<AddMedicineSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _strength = TextEditingController(),
      _amount = TextEditingController(),
      _instructions = TextEditingController();
  late final String _id;
  final _times = <int>[480];
  final _days = <int>{1, 2, 3, 4, 5, 6, 7};
  String _unit = 'tablet', _type = 'Tablet';
  String? _zone, _error;
  late DateTime _start;
  DateTime? _end;
  bool _saving = false;
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _start = calendarDate(context.read<MedicineReminderProvider>().clock());
    final existing = widget.medicine;
    _id = existing?.id ?? const Uuid().v4();
    if (existing == null) {
      _loadZone();
    } else {
      _name.text = existing.name;
      _strength.text = existing.strength;
      _amount.text = existing.amount;
      _instructions.text = existing.instructions;
      _unit = existing.unit;
      _type = existing.form;
      _zone = existing.timezone;
      _times
        ..clear()
        ..addAll(existing.minutes);
      _days
        ..clear()
        ..addAll(existing.weekdays);
      _start = existing.startsOn;
      _end = existing.endsOn;
    }
  }

  Future<void> _loadZone() async {
    try {
      final zone = await context
          .read<MedicineReminderProvider>()
          .notifications
          .deviceTimezone();
      tz.getLocation(zone);
      if (mounted) {
        setState(() {
          _zone = zone;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not detect your timezone. Retry before saving.',
        );
      }
    }
  }

  Medication _medicine() => Medication(
        id: _id,
        name: _name.text.trim(),
        strength: _strength.text.trim(),
        amount: _amount.text.trim(),
        unit: _unit,
        form: _type,
        instructions: _instructions.text.trim(),
        timezone: _zone!,
        minutes: List.of(_times)..sort(),
        weekdays: _days.toList()..sort(),
        startsOn: _start,
        endsOn: _end,
        revision: widget.medicine?.revision ?? 1,
        paused: widget.medicine?.paused ?? false,
      );

  Future<void> _time([int? index]) async {
    final old = index == null ? 480 : _times[index];
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: old ~/ 60, minute: old % 60),
    );
    if (picked == null || !mounted) return;
    final minute = picked.hour * 60 + picked.minute;
    if (_times.contains(minute) && (index == null || _times[index] != minute)) {
      setState(() => _error = 'This reminder time is already selected.');
      return;
    }
    setState(() {
      _error = null;
      if (index == null) {
        _times.add(minute);
      } else {
        _times[index] = minute;
      }
      _times.sort();
    });
  }

  Future<void> _date(bool end) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: end ? _end ?? _start : _start,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        if (end) {
          _end = picked;
        } else {
          _start = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_saving ||
        _zone == null ||
        !(_form.currentState?.validate() ?? false)) {
      return;
    }
    final medicine = _medicine();
    try {
      medicine.validate();
    } catch (e) {
      setState(
        () => _error = e is FormatException
            ? e.message
            : 'Check the schedule and timezone.',
      );
      return;
    }
    final provider = context.read<MedicineReminderProvider>();
    if (provider.medications.any(
      (m) =>
          m.id != medicine.id &&
          !m.archived &&
          m.name.toLowerCase() == medicine.name.toLowerCase(),
    )) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const AppText('A medicine with this name exists'),
          content: const AppText(
            'Check that you are adding a separate medicine or strength before continuing.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const AppText('Go back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const AppText('Add separate medicine'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final saved = widget.medicine == null
        ? await provider.addMedication(medicine)
        : await provider.editMedication(medicine);
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
            widget.medicine == null
                ? 'Medicine and schedule saved.'
                : 'Changes saved. Previous dose records kept.',
          ),
        ),
      );
    } else {
      setState(() {
        _saving = false;
        _error = provider.errorMessage ?? 'Could not save. Please retry.';
      });
    }
  }

  InputDecoration _decoration(String label, [String? hint]) => InputDecoration(
      labelText: context.tr(label),
      hintText: hint == null ? null : context.tr(hint));

  @override
  Widget build(BuildContext context) {
    final now = context.read<MedicineReminderProvider>().clock();
    final preview = _zone == null
        ? <DoseOccurrence>[]
        : const ScheduleEngine().generate(
            [_medicine()],
            [],
            now,
            now.add(const Duration(days: 7)),
          );
    return PopScope(
      canPop: !_saving,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            12,
            24,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AppText(
                          widget.medicine == null
                              ? 'Add medicine'
                              : 'Edit medicine',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      IconButton(
                        tooltip: context.tr('Close'),
                        onPressed:
                            _saving ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AppText(
                    widget.medicine == null
                        ? 'Enter the medicine and schedule you already follow.'
                        : 'Changes apply when you save. Earlier doses and recorded details stay unchanged.',
                  ),
                  if (widget.medicine != null) ...[
                    const SizedBox(height: 8),
                    AppText(
                      'Effective on save, from ${dateKey(now)} at ${TimeOfDay.fromDateTime(now).format(context)} (device time).${widget.medicine!.paused ? context.tr(' Reminders will stay paused.') : ''}',
                    ),
                  ],
                  const SizedBox(height: 20),
                  TextFormField(
                    key: const Key('medicine-name'),
                    controller: _name,
                    maxLength: 120,
                    decoration: _decoration('Medicine name *'),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? context.tr('Enter a medicine name')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _strength,
                    maxLength: 100,
                    decoration: _decoration(
                      'Strength (optional)',
                      'e.g. 500 mg',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: const Key('dose-amount'),
                          controller: _amount,
                          inputFormatters: const [LocalizedNumberFormatter()],
                          decoration: _decoration(
                            'Quantity per dose *',
                            'e.g. 1',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) => v == null ||
                                  !RegExp(r'^\d{1,6}(\.\d{1,4})?$')
                                      .hasMatch(v.trim()) ||
                                  (double.tryParse(v.trim()) ?? 0) <= 0
                              ? context.tr('Enter a positive quantity')
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _unit,
                          decoration: _decoration('Dose unit'),
                          isExpanded: true,
                          items: [
                            'tablet',
                            'capsule',
                            'mL',
                            'mg',
                            'g',
                            'mcg',
                            'drop',
                            'puff',
                            'unit',
                            'sachet',
                            'patch',
                          ]
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: AppText(s),
                                ),
                              )
                              .toList(),
                          onChanged: _saving
                              ? null
                              : (v) => setState(() => _unit = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    isExpanded: true,
                    decoration: _decoration('Medicine form'),
                    items: [
                      'Tablet',
                      'Capsule',
                      'Liquid',
                      'Drops',
                      'Inhaler',
                      'Injection',
                      'Patch',
                      'Other',
                    ]
                        .map(
                          (s) => DropdownMenuItem(value: s, child: AppText(s)),
                        )
                        .toList(),
                    onChanged:
                        _saving ? null : (v) => setState(() => _type = v!),
                  ),
                  const SizedBox(height: 20),
                  AppText(
                    'Reminder times',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (var i = 0; i < _times.length; i++)
                        InputChip(
                          label: Text(clockLabel(_times[i])),
                          onPressed: _saving ? null : () => _time(i),
                          onDeleted: _times.length == 1 || _saving
                              ? null
                              : () => setState(() => _times.removeAt(i)),
                        ),
                      if (_times.length < 8)
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 18),
                          label: const AppText('Add time'),
                          onPressed: _saving ? null : () => _time(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AppText(
                    'Repeat on',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (var i = 0; i < 7; i++)
                        FilterChip(
                          label: AppText(_weekdays[i]),
                          selected: _days.contains(i + 1),
                          onSelected: _saving
                              ? null
                              : (v) => setState(() {
                                    v ? _days.add(i + 1) : _days.remove(i + 1);
                                  }),
                        ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: AppText('Starts ${dateKey(_start)}'),
                        onPressed: _saving ? null : () => _date(false),
                      ),
                      TextButton(
                        onPressed: _saving ? null : () => _date(true),
                        child: AppText(
                          _end == null
                              ? 'Set end date'
                              : 'Ends ${dateKey(_end!)}',
                        ),
                      ),
                      if (_end != null)
                        IconButton(
                          tooltip: context.tr('Remove end date'),
                          onPressed: _saving
                              ? null
                              : () => setState(() => _end = null),
                          icon: const Icon(Icons.clear),
                        ),
                    ],
                  ),
                  AppText(
                    _zone == null
                        ? 'Detecting timezone…'
                        : 'Schedule timezone: $_zone. Times stay in this timezone when you travel.',
                  ),
                  if (_zone == null)
                    TextButton(
                      onPressed: _loadZone,
                      child: const AppText('Retry timezone'),
                    ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _instructions,
                    maxLength: 1000,
                    maxLines: 3,
                    decoration: _decoration(
                      'Instructions (optional)',
                      'Enter your existing instructions',
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppText(
                    'Next 7 days',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (preview.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: AppText(
                        'No doses in the next seven days. Check days and dates.',
                      ),
                    ),
                  if (preview.isNotEmpty)
                    Text(
                      preview.map((d) {
                        final local = tz.TZDateTime.from(
                          d.dueAt,
                          tz.getLocation(_zone!),
                        );
                        return '${dateKey(local)} ${clockLabel(local.hour * 60 + local.minute)}';
                      }).join('  ·  '),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: AppText(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    key: const Key('save-medicine'),
                    onPressed: _saving || _zone == null ? null : _submit,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: AppText(
                      _saving
                          ? 'Saving…'
                          : widget.medicine == null
                              ? 'Save medicine'
                              : 'Save changes',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _strength.dispose();
    _amount.dispose();
    _instructions.dispose();
    super.dispose();
  }
}
