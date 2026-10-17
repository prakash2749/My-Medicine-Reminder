import 'package:medicine_reminder/core/l10n/app_copy.dart';
import 'medicine_settings_view.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/medication.dart';
import '../../custom_app_bar.dart';
import '../../../../providers/medicine_reminder_provider.dart';
import 'widgets/add_medicine_sheet.dart';
import 'widgets/medicine_card.dart';
import 'medicine_history_view.dart';
import 'medicine_refills_view.dart';

class MedicineView extends StatefulWidget {
  const MedicineView({super.key});
  @override
  State<MedicineView> createState() => _MedicineViewState();
}

class _MedicineViewState extends State<MedicineView>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _medicinesTab = false;
  bool _archived = false, _changing = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        unawaited(context.read<MedicineReminderProvider>().refresh());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(context.read<MedicineReminderProvider>().refresh());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _add() => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        builder: (_) => const AddMedicineSheet(),
      );

  void _edit(Medication medicine) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        builder: (_) => AddMedicineSheet(medicine: medicine),
      );

  void _records(Medication medicine) {
    final records = context.read<MedicineReminderProvider>().recordedHistory(
          medicine.id,
        );
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(24),
        children: [
          AppText(
            'Recorded doses · ${medicine.name}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (records.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: AppText('No recorded doses for this medicine.'),
            ),
          for (final dose in records)
            ListTile(
              title: Text(
                '${dose.medication.name} · ${dose.medication.amount} ${dose.medication.unit}',
              ),
              subtitle: AppText(
                '${dateKey(dose.dueAt.toLocal())} · ${doseTime(context, dose.dueAt)} · ${context.tr(dose.status(context.read<MedicineReminderProvider>().clock()))}',
              ),
              onTap: () {
                Navigator.pop(context);
                showDoseDetails(context, dose);
              },
            ),
        ],
      ),
    );
  }

  Future<void> _changePlan(Medication medicine, String action) async {
    if (_changing) return;
    final provider = context.read<MedicineReminderProvider>();
    final archive = action == 'archive';
    final pause = !medicine.paused;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: AppText(
          archive
              ? 'Archive ${medicine.name}?'
              : pause
                  ? 'Pause reminders?'
                  : 'Resume reminders?',
        ),
        content: AppText(
          archive
              ? 'Future reminders, including snoozed alerts, will be canceled. Your previous schedules and recorded doses stay available in Archived medicines.'
              : pause
                  ? 'This pauses app reminders only. Follow your existing treatment instructions. Previous dose records are kept.'
                  : 'Reminders restart from now. Past reminders and old snoozes will not be replayed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: AppText(
              archive
                  ? 'Archive medicine'
                  : pause
                      ? 'Pause reminders'
                      : 'Resume reminders',
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _changing) return;
    setState(() => _changing = true);
    final saved = archive
        ? await provider.archiveMedication(medicine)
        : await provider.setPaused(medicine, pause);
    if (!mounted) return;
    setState(() => _changing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: AppText(
          saved
              ? archive
                  ? 'Medicine archived. Records kept.'
                  : pause
                      ? 'Reminders paused.'
                      : 'Reminders resumed from now.'
              : provider.errorMessage ?? 'Could not save. Please retry.',
        ),
      ),
    );
  }

  Future<void> _delete(Medication medicine) async {
    final provider = context.read<MedicineReminderProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: AppText('Delete ${medicine.name}?'),
        content: const AppText(
          'This permanently removes this medicine, its dose records, stock records, temporary reports, and future reminders from this device. Archive it instead to keep your records. Copies already saved or shared outside the app cannot be recalled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const AppText('Delete medicine'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted && !_changing) {
      setState(() => _changing = true);
      final saved = await provider.deleteMedication(medicine.id);
      if (!mounted) return;
      setState(() => _changing = false);
      if (!saved) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: AppText(
              provider.errorMessage ?? 'Could not delete. Please retry.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MedicineReminderProvider>();
    final refillFocus = provider.focusedRefill;
    if (refillFocus != null) {
      provider.focusedRefill = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => MedicineRefillsView(focusMedicineId: refillFocus),
            ),
          );
        }
      });
    }
    final focus = provider.focusedDose;
    if (focus != null) {
      provider.clearFocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showDoseDetails(context, focus);
      });
    }
    final next = provider.nextDoses;
    final doses = provider.filteredDoses;
    final theme = Theme.of(context);
    final medicines = provider.medications
        .where(
          (m) =>
              m.archived == _archived &&
              '${m.name} ${m.strength}'.toLowerCase().contains(
                    provider.searchQuery.toLowerCase(),
                  ),
        )
        .toList();
    return Scaffold(
      appBar: CustomAppBar(actions: [
        IconButton(
            tooltip: context.tr('Settings'),
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => const MedicineSettingsView())))
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: provider.isLoading || !provider.hasAccount ? null : _add,
        icon: const Icon(Icons.add),
        label: const AppText('Add medicine'),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: provider.refresh,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 100),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          'Today',
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          dateKey(provider.clock()),
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 16),
                        AppText(
                          '${provider.takenCount} of ${provider.totalCount} doses recorded as taken',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: provider.adherenceRate,
                          backgroundColor: theme.colorScheme.onSurface
                              .withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          minHeight: 6,
                        ),
                        const SizedBox(height: 8),
                        AppText(
                          '${provider.pendingCount} pending · ${provider.skippedCount} skipped',
                        ),
                      ],
                    ),
                  ),
                  if (provider.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: MaterialBanner(
                        content: AppText(provider.errorMessage!),
                        actions: [
                          TextButton(
                            onPressed: provider.refresh,
                            child: const AppText('Retry'),
                          ),
                          TextButton(
                            onPressed: provider.clearError,
                            child: const AppText('Dismiss'),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          key: const Key('open-history'),
                          icon: const Icon(Icons.history, size: 18),
                          label: const AppText('History'),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const MedicineHistoryView(),
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          key: const Key('open-refills'),
                          icon: const Icon(
                            Icons.inventory_2_outlined,
                            size: 18,
                          ),
                          label: const AppText('Refills'),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const MedicineRefillsView(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (provider.travelNotice != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(provider.travelNotice!),
                          TextButton(
                            onPressed: provider.acknowledgeTimezone,
                            child: const AppText('Keep plan timezone'),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2, right: 10),
                              child: Icon(
                                Icons.notifications_outlined,
                                size: 20,
                              ),
                            ),
                            Expanded(
                                child: AppText(provider.readiness.message)),
                            if (provider.readiness.supported &&
                                provider.readiness.notifications &&
                                provider.readiness.exact &&
                                provider.readiness.error == null)
                              IconButton(
                                tooltip: context.tr('Reminder settings'),
                                icon: const Icon(
                                  Icons.settings_outlined,
                                  size: 20,
                                ),
                                onPressed: provider.openNotificationSettings,
                              ),
                          ],
                        ),
                        if (provider.lastReminderCheckAt != null)
                          AppText(
                            'Last checked ${dateKey(provider.lastReminderCheckAt!.toLocal())} at ${doseTime(context, provider.lastReminderCheckAt!)}',
                          ),
                        TextButton(
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const AppText('Reminder delivery limits'),
                              content: const SingleChildScrollView(
                                child: AppText(
                                  'A powered-off device cannot deliver reminders. Force-stop can block background work until you reopen the app. After reboot, saved schedules may be unavailable until the first unlock. Notification permissions, channels, precise-alarm access, and battery restrictions can also affect delivery. Reopen the app or use Check again after restoring access. Only eligible future reminders are rebuilt; past doses are never marked taken automatically.',
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const AppText('Close'),
                                ),
                              ],
                            ),
                          ),
                          child: const AppText('Delivery limits'),
                        ),
                        if (provider.readiness.supported &&
                            (!provider.readiness.notifications ||
                                !provider.readiness.exact ||
                                provider.readiness.error != null))
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: provider.enableReminders,
                                child: const AppText('Enable reminders'),
                              ),
                              TextButton(
                                onPressed: provider.openNotificationSettings,
                                child: const AppText('Settings'),
                              ),
                              TextButton(
                                onPressed: provider.refresh,
                                child: const AppText('Check again'),
                              ),
                            ],
                          ),
                        const SizedBox(height: 12),
                        if (next.isNotEmpty)
                          InkWell(
                            onTap: () => _showNext(next),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  const Icon(Icons.schedule, size: 28),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        AppText(
                                          context.tr('Next scheduled dose') +
                                              (next.length > 1
                                                  ? ' (${next.length})'
                                                  : ''),
                                          style: theme.textTheme.labelLarge,
                                        ),
                                        Text(
                                          next
                                              .map(
                                                (d) =>
                                                    '${d.medication.name} · ${d.medication.amount} ${d.medication.unit}',
                                              )
                                              .join('\n'),
                                          style: theme.textTheme.titleMedium,
                                        ),
                                        AppText(
                                          '${dateKey(next.first.dueAt.toLocal())} · ${doseTime(context, next.first.dueAt)}',
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                            ),
                          ),
                        const Divider(height: 28),
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                              value: false,
                              label: AppText('Today’s doses'),
                            ),
                            ButtonSegment(
                              value: true,
                              label: AppText('Medicines'),
                            ),
                          ],
                          selected: {_medicinesTab},
                          onSelectionChanged: (values) =>
                              setState(() => _medicinesTab = values.single),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          key: const Key('search-medicine'),
                          decoration: InputDecoration(
                            hintText: context.tr('Search medicine…'),
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: provider.setSearchQuery,
                        ),
                        if (!_medicinesTab)
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (final filter in MedicineFilter.values)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: FilterChip(
                                      label: AppText(switch (filter) {
                                        MedicineFilter.all => 'All',
                                        MedicineFilter.pending => 'Pending',
                                        MedicineFilter.taken => 'Taken',
                                        MedicineFilter.skipped => 'Skipped',
                                      }),
                                      selected:
                                          provider.currentFilter == filter,
                                      onSelected: (_) =>
                                          provider.setFilter(filter),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _medicinesTab
                        ? Column(
                            key: const ValueKey('medicines'),
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ChoiceChip(
                                      label: const AppText('Active'),
                                      selected: !_archived,
                                      onSelected: (_) =>
                                          setState(() => _archived = false),
                                    ),
                                    ChoiceChip(
                                      label: const AppText('Archived'),
                                      selected: _archived,
                                      onSelected: (_) =>
                                          setState(() => _archived = true),
                                    ),
                                  ],
                                ),
                              ),
                              if (medicines.isEmpty)
                                _empty(
                                  _archived
                                      ? 'No archived medicines'
                                      : 'No active medicines',
                                  provider.searchQuery.isNotEmpty
                                      ? 'Try another search.'
                                      : _archived
                                          ? 'Archived medicines and their records will appear here.'
                                          : 'Add a medicine to see its upcoming doses.',
                                ),
                              for (final m in medicines)
                                ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 8,
                                  ),
                                  title: Text(m.name),
                                  subtitle: Text(
                                    '${m.amount} ${m.unit}${m.strength.isEmpty ? '' : ' · ${m.strength}'}\n${m.minutes.map(clockLabel).join(', ')} · ${context.tr(m.archived ? 'Archived' : m.paused ? 'Paused' : 'Active')}${m.effectiveFrom == null ? '' : '\n${context.tr('Effective ${dateKey(m.effectiveFrom!.toLocal())} at ${doseTime(context, m.effectiveFrom!)}')}'}',
                                  ),
                                  isThreeLine: true,
                                  trailing: PopupMenuButton<String>(
                                    enabled: !_changing,
                                    tooltip: context.tr('Medicine options'),
                                    onSelected: (action) {
                                      if (action == 'delete') {
                                        _delete(m);
                                      } else if (action == 'edit') {
                                        _edit(m);
                                      } else if (action == 'records') {
                                        _records(m);
                                      } else {
                                        _changePlan(m, action);
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      if (!m.archived)
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: AppText('Edit medicine'),
                                        ),
                                      const PopupMenuItem(
                                        value: 'records',
                                        child: AppText('View recorded doses'),
                                      ),
                                      if (!m.archived)
                                        PopupMenuItem(
                                          value: 'pause',
                                          child: AppText(
                                            m.paused
                                                ? 'Resume reminders'
                                                : 'Pause reminders',
                                          ),
                                        ),
                                      if (!m.archived)
                                        const PopupMenuItem(
                                          value: 'archive',
                                          child: AppText('Archive medicine'),
                                        ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: AppText('Delete medicine'),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          )
                        : Column(
                            key: const ValueKey('today'),
                            children: [
                              if (doses.isEmpty)
                                _empty(
                                  provider.medications.isEmpty
                                      ? 'Add your first medicine'
                                      : 'No doses to show',
                                  provider.medications.isEmpty
                                      ? 'Save its schedule to see your upcoming doses.'
                                      : provider.searchQuery.isNotEmpty ||
                                              provider.currentFilter !=
                                                  MedicineFilter.all
                                          ? 'Try another search or filter.'
                                          : provider.medications.every(
                                              (m) => m.paused,
                                            )
                                              ? 'Your medicine reminders are paused.'
                                              : 'There are no scheduled doses for today.',
                                ),
                              for (final dose in doses)
                                MedicineCard(
                                  key: ValueKey(dose.id),
                                  dose: dose,
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _empty(String title, String message) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.medication_outlined, size: 40),
            const SizedBox(height: 12),
            AppText(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            AppText(message, textAlign: TextAlign.center),
          ],
        ),
      );

  void _showNext(List<DoseOccurrence> doses) {
    if (doses.length == 1) {
      showDoseDetails(context, doses.single);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final dose in doses)
              ListTile(
                title: Text(dose.medication.name),
                subtitle: Text(
                  '${dose.medication.amount} ${dose.medication.unit}',
                ),
                onTap: () {
                  Navigator.pop(context);
                  showDoseDetails(this.context, dose);
                },
              ),
          ],
        ),
      ),
    );
  }
}
