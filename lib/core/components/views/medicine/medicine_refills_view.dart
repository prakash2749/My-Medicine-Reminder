import 'package:medicine_reminder/core/l10n/app_copy.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../models/inventory.dart';
import '../../../models/medication.dart';
import '../../../../providers/medicine_reminder_provider.dart';

String stockState(MedicineReminderProvider provider, Medication medicine,
    {String language = 'en'}) {
  final account = provider.stockFor(medicine.id);
  final balance = account == null ? null : provider.stockBalance(account.id);
  final stock = balance == null
      ? 'Unknown stock'
      : balance < 0
          ? 'Needs correction'
          : balance <= account!.threshold
              ? 'Low stock'
              : 'Stock available';
  return '${medicine.archived ? '${translateCopy('Archived', language)} · ' : medicine.paused ? '${translateCopy('Paused', language)} · ' : ''}${translateCopy(stock, language)}';
}

class MedicineRefillsView extends StatefulWidget {
  final String? focusMedicineId;
  const MedicineRefillsView({super.key, this.focusMedicineId});
  @override
  State<MedicineRefillsView> createState() => _MedicineRefillsViewState();
}

class _MedicineRefillsViewState extends State<MedicineRefillsView> {
  bool _includeArchived = false;
  @override
  void initState() {
    super.initState();
    if (widget.focusMedicineId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) =>
                  MedicineStockView(medicineId: widget.focusMedicineId!),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MedicineReminderProvider>();
    final medicines = provider.medications
        .where((m) => _includeArchived || !m.archived)
        .toList();
    medicines.sort((a, b) {
      int priority(Medication m) {
        final s = provider.stockFor(m.id);
        return s == null
            ? 2
            : provider.stockBalance(s.id) <= s.threshold
                ? 0
                : 1;
      }

      final order = priority(a).compareTo(priority(b));
      return order == 0 ? a.name.compareTo(b.name) : order;
    });
    return Scaffold(
      appBar: AppBar(title: const AppText('Refills')),
      body: RefreshIndicator(
        onRefresh: provider.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            AppText(
              'Medicine stock',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const AppText(
              'Track what you have. Refill or correct a count without changing dose records.',
            ),
            if (!provider.readiness.supported ||
                !provider.readiness.notifications ||
                provider.readiness.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: AppText(provider.readiness.message),
              ),
            if (provider.readiness.supported &&
                !provider.readiness.refillNotifications)
              TextButton(
                onPressed: provider.openNotificationSettings,
                child: const AppText(
                  'Refill notifications are off · Open Settings',
                ),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const AppText('Include archived medicines'),
              value: _includeArchived,
              onChanged: (v) => setState(() => _includeArchived = v),
            ),
            if (medicines.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: AppText('Add a medicine to start tracking stock.'),
              ),
            for (final m in medicines)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(m.name),
                subtitle: Text(
                  '${stockState(provider, m, language: Localizations.localeOf(context).languageCode)}${provider.stockFor(m.id) == null ? '' : '\n${context.tr('${quantityLabel(provider.stockBalance(provider.stockFor(m.id)!.id))} ${provider.stockFor(m.id)!.unit} remaining')}'}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => MedicineStockView(medicineId: m.id),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum StockEdit { setup, refill, count, threshold }

class MedicineStockView extends StatelessWidget {
  final String medicineId;
  const MedicineStockView({super.key, required this.medicineId});
  Future<void> _edit(
    BuildContext context,
    Medication medicine,
    StockEdit mode,
  ) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => _StockEditor(medicine: medicine, mode: mode),
      );
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MedicineReminderProvider>();
    final medicine =
        provider.medications.where((m) => m.id == medicineId).firstOrNull;
    if (medicine == null) {
      return Scaffold(
        appBar: AppBar(title: const AppText('Stock')),
        body: const Center(
          child: AppText('This medicine is no longer available.'),
        ),
      );
    }
    final stock = provider.stockFor(medicineId);
    final estimate = provider.supplyEstimate(medicine);
    final entries = provider.stockLedger(medicineId);
    return Scaffold(
      appBar: AppBar(title: Text(medicine.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          Text(
            stockState(provider, medicine,
                language: Localizations.localeOf(context).languageCode),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            stock == null
                ? context.tr('Stock not tracked')
                : '${quantityLabel(provider.stockBalance(stock.id))} ${stock.unit}',
            key: const Key('stock-balance'),
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          if (stock != null)
            AppText(
              'Refill notice at ${quantityLabel(stock.threshold)} ${stock.unit} or less',
            ),
          if (estimate != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: AppText(
                estimate.depletionAt != null
                    ? 'Estimated supply runs out ${dateKey(estimate.depletionAt!.toLocal())}. Based on your current schedule.'
                    : 'Stock covers the next 90 days of scheduled doses (estimate).',
              ),
            ),
          if (medicine.paused)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: AppText(
                'Reminders are paused. Supply estimates and refill alerts resume with the schedule.',
              ),
            ),
          if (stock != null && provider.stockBalance(stock.id) < 0)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: AppText(
                'Recorded consumption exceeds your stock. Check your physical count and reconcile it. Your dose record has been kept.',
              ),
            ),
          const SizedBox(height: 20),
          if (!medicine.archived)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (stock == null)
                  FilledButton(
                    onPressed: () => _edit(context, medicine, StockEdit.setup),
                    child: const AppText('Set stock'),
                  ),
                if (stock != null) ...[
                  FilledButton(
                    onPressed: () => _edit(context, medicine, StockEdit.refill),
                    child: const AppText('Add refill'),
                  ),
                  OutlinedButton(
                    onPressed: () => _edit(context, medicine, StockEdit.count),
                    child: const AppText('Reconcile stock'),
                  ),
                  TextButton(
                    onPressed: () =>
                        _edit(context, medicine, StockEdit.threshold),
                    child: const AppText('Refill threshold'),
                  ),
                  TextButton(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const AppText('Stop stock tracking?'),
                          content: const AppText(
                            'The inventory ledger is kept. New dose records will no longer change stock. You can set a new baseline later.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const AppText('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const AppText('Stop tracking'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        final saved = await provider.stopStock(stock);
                        if (!saved && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: AppText(
                                provider.errorMessage ?? 'Could not save.',
                              ),
                            ),
                          );
                        }
                      }
                    },
                    child: const AppText('Stop tracking'),
                  ),
                ],
              ],
            ),
          const Divider(height: 36),
          AppText(
            'Inventory ledger',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const AppText(
            'Initial stock starts a new baseline. Only confirmed Taken records consume stock; corrections remain visible.',
          ),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: AppText('No stock entries yet.'),
            ),
          for (final entry in entries)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${entry.delta > 0 ? '+' : ''}${quantityLabel(entry.delta)} ${provider.stockUnitFor(entry.accountId)} · ${context.tr(switch (entry.kind) {
                  StockEntryKind.initial => 'Initial stock',
                  StockEntryKind.refill => 'Refill',
                  StockEntryKind.count => 'Count correction',
                  StockEntryKind.consumption => 'Taken',
                  StockEntryKind.reversal => 'Undo taken',
                })}',
              ),
              subtitle: Text(
                '${dateKey(entry.recordedAt.toLocal())} ${TimeOfDay.fromDateTime(entry.recordedAt.toLocal()).format(context)}${entry.note.isEmpty ? '' : '\n${entry.note}'}',
              ),
            ),
        ],
      ),
    );
  }
}

class _StockEditor extends StatefulWidget {
  final Medication medicine;
  final StockEdit mode;
  const _StockEditor({required this.medicine, required this.mode});
  @override
  State<_StockEditor> createState() => _StockEditorState();
}

class _StockEditorState extends State<_StockEditor> {
  final _form = GlobalKey<FormState>();
  final _quantity = TextEditingController(),
      _threshold = TextEditingController(),
      _note = TextEditingController();
  final _requestId = const Uuid().v4();
  late final StockAccount? _stock;
  late final int? _balance;
  bool _saving = false;
  String? _error;
  String get _title => switch (widget.mode) {
        StockEdit.setup => 'Set stock',
        StockEdit.refill => 'Add refill',
        StockEdit.count => 'Reconcile stock',
        StockEdit.threshold => 'Refill threshold',
      };
  @override
  void initState() {
    super.initState();
    final provider = context.read<MedicineReminderProvider>();
    _stock = provider.stockFor(widget.medicine.id);
    _balance = _stock == null ? null : provider.stockBalance(_stock.id);
    _threshold.text = _stock == null ? '7' : quantityLabel(_stock.threshold);
    if (widget.mode == StockEdit.count && _balance! >= 0) {
      _quantity.text = quantityLabel(_balance);
    }
  }

  String? _validate(String? text, {bool zero = false}) {
    try {
      parseQuantity(text ?? '', allowZero: zero);
      return null;
    } on FormatException catch (e) {
      return context.tr(e.message);
    }
  }

  Future<void> _save() async {
    if (_saving || !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final provider = context.read<MedicineReminderProvider>();
    final saved = switch (widget.mode) {
      StockEdit.setup => await provider.startStock(
          widget.medicine,
          _quantity.text,
          _threshold.text,
          requestId: _requestId,
        ),
      StockEdit.threshold => await provider.setStockThreshold(
          _stock!,
          _threshold.text,
        ),
      StockEdit.refill || StockEdit.count => await provider.updateStock(
          _stock!,
          quantity: _quantity.text,
          refill: widget.mode == StockEdit.refill,
          requestId: _requestId,
          expectedBalance: _balance,
          note: _note.text,
        ),
    };
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
    } else {
      setState(() {
        _saving = false;
        _error = provider.errorMessage ?? 'Could not save. Please retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_saving,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
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
                        _title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: context.tr('Close'),
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                AppText(
                  'Unit: ${_stock?.unit ?? widget.medicine.unit}. Quantities use this unit; no conversion is applied.',
                ),
                if (widget.mode == StockEdit.setup)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: AppText(
                      'Enter what you have now. Earlier Taken records will not be subtracted from this baseline.',
                    ),
                  ),
                if (widget.mode == StockEdit.count)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: AppText(
                      'Enter your physical count, including any outside purchase or missed log. This adds an inventory correction and keeps dose history unchanged.',
                    ),
                  ),
                const SizedBox(height: 20),
                if (widget.mode != StockEdit.threshold)
                  TextFormField(
                    key: const Key('stock-quantity'),
                    controller: _quantity,
                    inputFormatters: const [LocalizedNumberFormatter()],
                    decoration: InputDecoration(
                      labelText: context.tr(widget.mode == StockEdit.refill
                          ? 'Quantity added'
                          : 'Current quantity'),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (text) =>
                        _validate(text, zero: widget.mode != StockEdit.refill),
                  ),
                if (widget.mode == StockEdit.setup ||
                    widget.mode == StockEdit.threshold) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('stock-threshold'),
                    controller: _threshold,
                    inputFormatters: const [LocalizedNumberFormatter()],
                    decoration: InputDecoration(
                      labelText: context.tr('Low-stock threshold'),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (text) => _validate(text, zero: true),
                  ),
                ],
                if (widget.mode == StockEdit.refill ||
                    widget.mode == StockEdit.count) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _note,
                    maxLength: 500,
                    maxLines: 2,
                    decoration: InputDecoration(
                        labelText: context.tr('Note (optional)')),
                  ),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: AppText(
                      _error!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                const SizedBox(height: 20),
                FilledButton(
                  key: const Key('save-stock'),
                  onPressed: _saving ? null : _save,
                  child: AppText(_saving ? 'Saving…' : _title),
                ),
              ],
            ),
          ),
        ),
      );
  @override
  void dispose() {
    _quantity.dispose();
    _threshold.dispose();
    _note.dispose();
    super.dispose();
  }
}
