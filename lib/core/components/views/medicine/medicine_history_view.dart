import 'medicine_report_view.dart';
import '../../../services/medicine_pdf.dart';
import 'package:medicine_reminder/core/l10n/app_copy.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/medication.dart';
import '../../../services/medicine_reporting.dart';
import '../../../../providers/medicine_reminder_provider.dart';
import 'widgets/medicine_card.dart';

class MedicineHistoryView extends StatefulWidget {
  const MedicineHistoryView({super.key});
  @override
  State<MedicineHistoryView> createState() => _MedicineHistoryViewState();
}

class _MedicineHistoryViewState extends State<MedicineHistoryView> {
  late DateTimeRange _period;
  String? _medicineId;
  HistoryFilter _filter = HistoryFilter.all;
  @override
  void initState() {
    super.initState();
    final today = calendarDate(
      context.read<MedicineReminderProvider>().clock().toLocal(),
    );
    _period = DateTimeRange(
      start: DateTime(today.year, today.month, today.day - 6),
      end: today,
    );
  }

  Future<void> _dates() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: calendarDate(
        context.read<MedicineReminderProvider>().clock().toLocal(),
      ),
      initialDateRange: _period,
      helpText: context.tr('History period · up to 366 days'),
    );
    if (picked == null || !mounted) return;
    if (picked.end.difference(picked.start).inDays >= 366) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
          const SnackBar(content: AppText('Choose up to 366 days.')));
      return;
    }
    setState(() => _period = picked);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MedicineReminderProvider>();
    final until = DateTime(
      _period.end.year,
      _period.end.month,
      _period.end.day + 1,
    );
    final report = provider.history(
      _period.start,
      until,
      medicineId: _medicineId,
    );
    final filtered = report.doses
        .where(
          (d) => switch (_filter) {
            HistoryFilter.all => true,
            HistoryFilter.taken => d.isTaken,
            HistoryFilter.skipped => d.isSkipped,
            HistoryFilter.unconfirmed => !d.isComplete,
          },
        )
        .toList();
    final daily = <String, List<DoseOccurrence>>{};
    for (final dose in report.doses) {
      daily.putIfAbsent(dateKey(dose.dueAt.toLocal()), () => []).add(dose);
    }
    final dates = daily.keys.toList()..sort((a, b) => b.compareTo(a));
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const AppText('History'), actions: [
        IconButton(
            tooltip: context.tr('Export PDF'),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) => MedicineReportView(
                            fingerprint: provider.reportFingerprint,
                            request: MedicineReportRequest(
                                data: provider.reportData,
                                from: _period.start,
                                until: until,
                                generatedAt: provider.clock(),
                                medicineId: _medicineId,
                                language: Localizations.localeOf(context)
                                    .languageCode),
                          )));
            }),
      ]),
      body: RefreshIndicator(
        onRefresh: provider.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            OutlinedButton.icon(
              key: const Key('history-period'),
              onPressed: _dates,
              icon: const Icon(Icons.date_range),
              label: AppText(
                '${dateKey(_period.start)} – ${dateKey(_period.end)}',
              ),
            ),
            const SizedBox(height: 16),
            AppText(
              'Recording completeness',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            AppText(
              '${report.taken} of ${report.eligible} eligible due doses recorded as taken',
              key: const Key('history-summary'),
              style: theme.textTheme.titleMedium,
            ),
            if (report.eligible > 0) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: report.recordedTakenFraction,
                minHeight: 6,
                semanticsLabel: 'Recorded taken',
                semanticsValue:
                    '${(report.recordedTakenFraction * 100).round()}',
              ),
            ],
            const SizedBox(height: 12),
            AppText(
              '${report.taken} taken · ${report.skipped} skipped · ${report.unconfirmed} unconfirmed',
            ),
            const SizedBox(height: 8),
            const AppText(
              'Self-reported records, not proof of adherence. Future doses, paused intervals, canceled unconfirmed doses, and unknown recording coverage are excluded.',
            ),
            if (report.coverageGaps > 0)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: AppText(
                  '${report.coverageGaps} earlier planned doses have unknown recording coverage and are excluded.',
                  key: const Key('history-gaps'),
                ),
              ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              key: ValueKey('history-medicine-$_medicineId'),
              initialValue: _medicineId ?? '',
              isExpanded: true,
              decoration: InputDecoration(labelText: context.tr('Medicine')),
              items: [
                const DropdownMenuItem(
                    value: '', child: AppText('All medicines')),
                for (final m in provider.medications)
                  DropdownMenuItem(
                    value: m.id,
                    child: Text(
                      '${m.name}${m.archived ? ' (${context.tr('Archived')})' : ''}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) =>
                  setState(() => _medicineId = value == '' ? null : value),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final filter in HistoryFilter.values)
                  ChoiceChip(
                    label: AppText(switch (filter) {
                      HistoryFilter.all => 'All',
                      HistoryFilter.taken => 'Taken',
                      HistoryFilter.skipped => 'Skipped',
                      HistoryFilter.unconfirmed => 'Unconfirmed',
                    }),
                    selected: _filter == filter,
                    onSelected: (_) => setState(() => _filter = filter),
                  ),
              ],
            ),
            if (dates.isNotEmpty) ...[
              const Divider(height: 32),
              AppText(
                dates.length > 14
                    ? 'Daily recording · latest 14 days with eligible doses'
                    : 'Daily recording',
                style: theme.textTheme.titleMedium,
              ),
              for (final date in dates.take(14))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        '$date · ${daily[date]!.where((d) => d.isTaken).length}/${daily[date]!.length} recorded taken',
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: daily[date]!.where((d) => d.isTaken).length /
                            daily[date]!.length,
                      ),
                    ],
                  ),
                ),
            ],
            const Divider(height: 32),
            AppText('Dose records', style: theme.textTheme.titleLarge),
            if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child:
                    AppText('No eligible doses match this period and filter.'),
              ),
            for (final dose in filtered)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${dose.medication.name} · ${dose.medication.amount} ${dose.medication.unit}',
                ),
                subtitle: AppText(
                  '${dateKey(dose.dueAt.toLocal())} · ${doseTime(context, dose.dueAt)} · ${context.tr(dose.isTaken ? 'Taken' : dose.isSkipped ? 'Skipped' : 'Unconfirmed')}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showDoseDetails(context, dose, allowSnooze: false),
              ),
          ],
        ),
      ),
    );
  }
}
