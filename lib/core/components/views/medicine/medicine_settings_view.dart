import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../providers/app_preferences.dart';
import '../../../../providers/medicine_reminder_provider.dart';
import '../../../l10n/app_copy.dart';
import '../../../services/medicine_diagnostics.dart';
import '../../../services/medicine_notifications.dart';
import '../policy_view.dart';

class MedicineSettingsView extends StatefulWidget {
  const MedicineSettingsView({super.key});
  @override
  State<MedicineSettingsView> createState() => _MedicineSettingsViewState();
}

class _MedicineSettingsViewState extends State<MedicineSettingsView> {
  bool _busy = false;
  bool _reviewingDiagnostics = false;

  Future<void> _reviewDiagnostics() async {
    if (_busy || _reviewingDiagnostics) return;
    final bundle = reminderDiagnosticBundle(
        context.read<MedicineReminderProvider>().readiness);
    setState(() => _reviewingDiagnostics = true);
    try {
      final copy = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: const AppText('Review diagnostics'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppText(
                  'This snapshot contains reminder settings only. It excludes medicine names, dose records, account details and exact times. It does not prove reminder delivery.'),
              const SizedBox(height: 12),
              const AppText(
                  'Copy puts this text on your system clipboard, where other apps may access it. Paste it only into a support conversation you choose. Nothing is sent automatically.'),
              const SizedBox(height: 16),
              SelectableText(bundle,
                  key: const Key('diagnostic-preview'),
                  textDirection: TextDirection.ltr),
            ],
          ),
          actions: [
            TextButton(
                key: const Key('cancel-diagnostics'),
                onPressed: () => Navigator.pop(context, false),
                child: const AppText('Cancel')),
            FilledButton(
                key: const Key('copy-diagnostics'),
                onPressed: () => Navigator.pop(context, true),
                child: const AppText('Copy diagnostics')),
          ],
        ),
      );
      if (copy != true || !mounted) return;
      var copied = false;
      try {
        await Clipboard.setData(ClipboardData(text: bundle));
        copied = true;
      } catch (_) {
        // Platform errors can contain private details; never display them.
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: AppText(copied
              ? 'Diagnostics copied. Choose where to paste them.'
              : 'Could not copy diagnostics. Please retry.')));
    } finally {
      if (mounted) setState(() => _reviewingDiagnostics = false);
    }
  }

  Future<void> _erase() async {
    final provider = context.read<MedicineReminderProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText('Erase all local medicine data?'),
        content: const SingleChildScrollView(
            child: AppText(
          'This removes every local medicine profile, schedule, dose record, stock entry, pending reminder, and temporary report. Your sign-in and language settings remain. Copies saved or shared outside this app cannot be recalled. This does not delete an online account.',
        )),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const AppText('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const AppText('Erase data')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final success = await provider.resetLocalData();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: AppText(
      success ? 'All local medicine data erased.' : provider.errorMessage!,
    )));
  }

  Future<void> _test() async {
    final notifications =
        context.read<MedicineReminderProvider>().notifications;
    setState(() => _busy = true);
    var message =
        'Test notification requested. Check your notification shade; this does not prove delivery.';
    try {
      if (notifications is! LocalMedicineNotifications) {
        throw UnsupportedError('Native notifications required');
      }
      await notifications.showTest();
    } catch (_) {
      message =
          'Could not request the test notification. Check permissions and retry.';
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: AppText(message)));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppPreferences>();
    final medicines = context.watch<MedicineReminderProvider>();
    return Scaffold(
      appBar: AppBar(title: const AppText('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const AppText('Language',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey(settings.language),
            initialValue: settings.language,
            isExpanded: true,
            decoration: InputDecoration(
                labelText: context.tr('Language'),
                border: const OutlineInputBorder()),
            items: const [
              DropdownMenuItem(
                  value: 'device', child: AppText('Device language')),
              DropdownMenuItem(value: 'en', child: Text('English')),
              DropdownMenuItem(value: 'hi', child: Text('हिन्दी')),
            ],
            onChanged: _busy
                ? null
                : (value) async {
                    setState(() => _busy = true);
                    final saved = await settings.setLanguage(value!);
                    if (saved) await medicines.refresh();
                    if (mounted) setState(() => _busy = false);
                  },
          ),
          if (settings.error != null) AppText(settings.error!),
          const SizedBox(height: 28),
          const AppText('Reminder health',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          AppText(medicines.readiness.message),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton(
                onPressed: _busy ? null : _test,
                child: const AppText('Test reminder')),
            OutlinedButton(
                onPressed: _busy ? null : medicines.openNotificationSettings,
                child: const AppText('Reminder settings')),
          ]),
          const SizedBox(height: 24),
          const AppText('Offline help',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(Localizations.localeOf(context).languageCode == 'hi'
              ? _hindiHelp
              : _help),
          const SizedBox(height: 24),
          const AppText('Local data and privacy',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(Localizations.localeOf(context).languageCode == 'hi'
              ? _hindiPrivacy
              : _privacy),
          const Align(
              alignment: AlignmentDirectional.centerStart, child: PolicyLink()),
          const SizedBox(height: 12),
          const AppText(
              'No remote analytics or crash reporting is enabled. Nothing on this screen is sent automatically.'),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const AppText('Local diagnostics'),
            children: [
              SelectableText(reminderDiagnosticBundle(medicines.readiness),
                  textDirection: TextDirection.ltr)
            ],
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              key: const Key('review-diagnostics'),
              onPressed:
                  _busy || _reviewingDiagnostics ? null : _reviewDiagnostics,
              icon: const Icon(Icons.support_agent),
              label: const AppText('Review diagnostics'),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            key: const Key('erase-local-data'),
            onPressed: _busy ? null : _erase,
            icon: const Icon(Icons.delete_forever),
            label: const AppText('Erase local medicine data'),
          ),
          if (_busy)
            const Padding(
                padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
        ],
      ),
    );
  }
}

const _help =
    'Taken records a dose. Snooze only delays its reminder by 15 minutes. Undo corrects a record; it does not advise another dose. Follow your existing treatment instructions.\n\nIf reminders are missing: check notification permission, the medicine channel and sound, precise alarms, Do Not Disturb, and battery restrictions in system Settings. Keep the phone charged. A powered-off or force-stopped app cannot reliably remind you. After reboot, unlock the phone and reopen this app to check readiness.\n\nSchedules keep their saved timezone when you travel. Only future alerts are rebuilt after clock changes. Open the app regularly to extend the scheduling horizon. A scheduled alert does not prove that it was seen or heard.';
const _privacy =
    'Medicine plans, dose actions and stock records are encrypted on this device. Guest use has no expiry. Signing in does not back up or merge medicine records. Optional sign-in uses Supabase and sends account credentials to that service; local medicine records are not uploaded.\n\nLock-screen notifications use generic text and require opening the app for actions. Use a device screen lock on shared or lost phones. Reports are created locally. Sharing opens the OS chooser; recipients and saved copies are outside the app’s control. App-owned report copies are removed on the next launch, deletion or reset. Uninstalling can remove local records; there is no key recovery or cloud restore.';
const _hindiHelp =
    'ले ली दबाने से खुराक दर्ज होती है। 15 मिनट बाद याद दिलाएँ केवल रिमाइंडर टालता है। वापस लें से रिकॉर्ड सुधरता है; इसका मतलब दूसरी खुराक लेना नहीं है। उपचार के मौजूदा निर्देशों का पालन करें।\n\nरिमाइंडर न आने पर: सिस्टम सेटिंग्स में नोटिफ़िकेशन अनुमति, दवा का चैनल और आवाज़, सटीक अलार्म, डू नॉट डिस्टर्ब और बैटरी पाबंदियाँ जाँचें। फ़ोन चार्ज रखें। बंद फ़ोन या फ़ोर्स-स्टॉप किया ऐप भरोसेमंद रिमाइंडर नहीं दे सकता। रीस्टार्ट के बाद फ़ोन अनलॉक करके ऐप खोलें और स्थिति जाँचें।\n\nयात्रा में शेड्यूल अपना सहेजा समय क्षेत्र रखता है। घड़ी बदलने पर केवल आने वाले रिमाइंडर फिर बनते हैं। आगे के रिमाइंडर तय करने के लिए ऐप नियमित रूप से खोलें। रिमाइंडर तय होना उसके देखे या सुने जाने का प्रमाण नहीं है।';
const _hindiPrivacy =
    'दवा के शेड्यूल, खुराकें और स्टॉक रिकॉर्ड इस डिवाइस पर एन्क्रिप्टेड रहते हैं। अतिथि इस्तेमाल की समय सीमा नहीं है। साइन इन करने से दवा रिकॉर्ड का बैकअप या विलय नहीं होता। वैकल्पिक साइन-इन Supabase को खाते की जानकारी भेजता है; स्थानीय दवा रिकॉर्ड अपलोड नहीं होते।\n\nलॉक स्क्रीन पर सामान्य सूचना दिखती है और कार्रवाई के लिए ऐप खुलता है। साझा या खोए फ़ोन पर सुरक्षा के लिए स्क्रीन लॉक रखें। रिपोर्ट स्थानीय रूप से बनती है। साझा करने पर डिवाइस की शेयर शीट खुलती है; सहेजी गई प्रतियाँ और प्राप्तकर्ता ऐप के नियंत्रण से बाहर हैं। ऐप की अस्थायी प्रतियाँ अगली बार ऐप खोलने, दवा मिटाने या रीसेट करने पर हटती हैं। ऐप हटाने से स्थानीय रिकॉर्ड मिट सकते हैं; कुंजी वापस पाने या क्लाउड से बहाल करने की सुविधा नहीं है।';
