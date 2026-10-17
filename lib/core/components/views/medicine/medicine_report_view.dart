import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../../../providers/medicine_reminder_provider.dart';
import '../../../l10n/app_copy.dart';
import '../../../services/medicine_pdf.dart';

class MedicineReportView extends StatefulWidget {
  final MedicineReportRequest request;
  final String fingerprint;
  const MedicineReportView(
      {super.key, required this.request, required this.fingerprint});
  @override
  State<MedicineReportView> createState() => _MedicineReportViewState();
}

class _MedicineReportViewState extends State<MedicineReportView> {
  Uint8List? _bytes;
  String? _error;
  bool _sharing = false;
  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    try {
      final result = await buildMedicinePdf(widget.request);
      if (mounted) setState(() => _bytes = result.bytes);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not prepare the report. Choose a smaller date range or retry.');
      }
    }
  }

  Future<void> _share() async {
    final provider = context.read<MedicineReminderProvider>();
    if (_bytes == null ||
        _sharing ||
        provider.reportFingerprint != widget.fingerprint) {
      return;
    }
    setState(() => _sharing = true);
    try {
      final box = context.findRenderObject() as RenderBox?;
      await Printing.sharePdf(
          bytes: _bytes!,
          filename: 'medicine-report-records.pdf',
          bounds:
              box == null ? null : box.localToGlobal(Offset.zero) & box.size);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: AppText('Could not open sharing. Please retry.')));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final valid = context.watch<MedicineReminderProvider>().reportFingerprint ==
        widget.fingerprint;
    return Scaffold(
      appBar: AppBar(title: const AppText('Report preview')),
      body: Column(children: [
        const Padding(
            padding: EdgeInsets.all(16),
            child: AppText(
                'Sharing opens your system share sheet. Copies you save or share leave this app and cannot be recalled.')),
        if (!valid)
          const Expanded(
              child: Center(
                  child: Padding(
                      padding: EdgeInsets.all(24),
                      child: AppText(
                          'The records changed. Close this preview and export again.'))))
        else if (_error != null)
          Expanded(
              child: Center(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: AppText(_error!))))
        else if (_bytes == null)
          const Expanded(
              child: Center(
                  child: CircularProgressIndicator(
                      semanticsLabel: 'Preparing report')))
        else
          Expanded(
              child: PdfPreview(
            build: (_) async => _bytes!,
            allowPrinting: false,
            allowSharing: false,
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
          )),
        SafeArea(
            top: false,
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed:
                      valid && _bytes != null && !_sharing ? _share : null,
                  icon: const Icon(Icons.ios_share),
                  label: const AppText('Share PDF'),
                ))),
      ]),
    );
  }
}
