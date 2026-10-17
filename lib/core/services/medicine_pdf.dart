import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as image_codec;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pdf;
import 'package:timezone/timezone.dart' as tz;

import '../l10n/app_copy.dart';
import '../models/medication.dart';
import 'medicine_reporting.dart';
import 'medicine_store.dart';

class MedicineReportRequest {
  final MedicineData data;
  final DateTime from, until, generatedAt;
  final String? medicineId;
  final String language;
  const MedicineReportRequest(
      {required this.data,
      required this.from,
      required this.until,
      required this.generatedAt,
      this.medicineId,
      this.language = 'en'});

  MedicineHistory get history =>
      MedicineHistory.build(data, from, until, generatedAt,
          medicineId: medicineId);

  List<String> paragraphs() {
    final report = history;
    final plans = data.medications
        .where((m) => medicineId == null || m.id == medicineId)
        .toList();
    if (report.doses.length > 2000 || plans.length > 100) {
      throw const FormatException(
          'Report is too large. Choose a smaller date range or one medicine.');
    }
    String copy(String value) => translateCopy(value, language);
    final lines = <String>[
      copy('Medicine record'),
      copy(
          'Self-reported records. This report does not prove that medicines were taken and does not infer a diagnosis.'),
      '${copy('Period')}: ${dateKey(from)} - ${dateKey(until.subtract(const Duration(days: 1)))} (${generatedAt.toLocal().timeZoneName})',
      '${copy('Generated')}: ${generatedAt.toUtc().toIso8601String()} (UTC)',
      '${copy('Recording completeness')}: ${report.taken}/${report.eligible}; ${copy('Taken')}: ${report.taken}; ${copy('Skipped')}: ${report.skipped}; ${copy('Unconfirmed')}: ${report.unconfirmed}.',
      '${copy('Unknown recording coverage excluded')}: ${report.coverageGaps}. ${copy('Future doses and canceled unconfirmed doses are excluded.')}',
      copy('Medicine plans'),
    ];
    for (final medicine in plans) {
      lines.add(
          '${medicine.name}\n${medicine.strength} | ${medicine.amount} ${medicine.unit} | ${medicine.form}\n'
          '${copy('Schedule timezone: ${medicine.timezone}')} | ${medicine.minutes.map(clockLabel).join(', ')} | ${medicine.weekdays.map((d) => copy(const [
                'Mon',
                'Tue',
                'Wed',
                'Thu',
                'Fri',
                'Sat',
                'Sun'
              ][d - 1])).join(', ')}\n'
          '${dateKey(medicine.startsOn)} - ${medicine.endsOn == null ? copy('No end date') : dateKey(medicine.endsOn!)} | ${copy(medicine.archived ? 'Archived' : medicine.paused ? 'Paused' : 'Active')} | ${copy('Revision')}: ${medicine.revision}');
      if (medicine.instructions.isNotEmpty) {
        lines.add(copy('Instructions'));
        lines.addAll(medicine.instructions.split('\n'));
      }
    }
    lines.add(copy('Dose records'));
    if (report.doses.isEmpty) {
      lines.add(copy('No eligible doses match this period and filter.'));
    }
    for (final dose in report.doses) {
      final medicine = dose.medication;
      final event = dose.latestEvent;
      final due =
          tz.TZDateTime.from(dose.dueAt, tz.getLocation(medicine.timezone));
      lines.add(
          '${medicine.name} | ${medicine.strength} | ${medicine.amount} ${medicine.unit}\n'
          '${copy('Scheduled')}: ${dateKey(due)} ${clockLabel(due.hour * 60 + due.minute)} (${medicine.timezone}, UTC${due.timeZoneOffset.isNegative ? '' : '+'}${due.timeZoneOffset.inMinutes / 60})\n'
          '${copy(dose.isTaken ? 'Taken' : dose.isSkipped ? 'Skipped' : 'Unconfirmed')} | ${copy('Revision')}: ${medicine.revision}'
          '${event == null ? '' : '\n${copy('Last record')}: ${copy(switch (event.action) {
              DoseAction.taken => 'Taken',
              DoseAction.skipped => 'Skipped',
              DoseAction.undo => 'Undo',
              DoseAction.snooze => 'Snooze 15 min'
            })} - ${event.recordedAt.toUtc().toIso8601String()} (UTC)'}');
    }
    return lines;
  }
}

class MedicinePdfResult {
  final Uint8List bytes;
  final List<Uint8List> pageImages;
  const MedicinePdfResult(this.bytes, this.pageImages);
}

/// Flutter shapes Indic text offline. Images retain exact displayed wording;
/// the resulting PDF is image-based, with no hidden prescription translation.
Future<MedicinePdfResult> buildMedicinePdf(MedicineReportRequest request,
    {bool keepPageImages = false}) async {
  const width = 595.0, height = 842.0, margin = 42.0, bottom = 790.0;
  final paragraphs = request.paragraphs();
  final document = pdf.Document(
      compress: true, title: 'Medicine record', author: 'Medicine Reminder');
  final images = <Uint8List>[];
  var recorder = ui.PictureRecorder();
  var canvas = Canvas(recorder);
  var y = margin;
  var page = 1;
  void background() => canvas.drawRect(
      const Rect.fromLTWH(0, 0, width, height), Paint()..color = Colors.white);
  background();
  Future<void> finish() async {
    if (page > 300) {
      throw const FormatException(
          'Report is too large. Choose a smaller date range or one medicine.');
    }
    final footer = TextPainter(
      text: TextSpan(
          text: '${translateCopy('Medicine record', request.language)} | $page',
          style: const TextStyle(
              color: Color(0xff526460),
              fontSize: 9,
              fontFamily: 'ReportHindi')),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width - 2 * margin);
    footer.paint(canvas, const Offset(margin, 812));
    final picture = recorder.endRecording();
    final raster =
        await picture.toImage((width * 2).round(), (height * 2).round());
    final encoded = await raster.toByteData(format: ui.ImageByteFormat.png);
    raster.dispose();
    picture.dispose();
    footer.dispose();
    if (encoded == null) throw StateError('Report rendering failed');
    final png = encoded.buffer.asUint8List();
    if (keepPageImages) images.add(png);
    // JPEG embeds directly instead of retaining full decoded RGB pages in the
    // PDF document, keeping long history exports within practical memory use.
    final pixels = image_codec.decodePng(png);
    if (pixels == null) throw StateError('Report image encoding failed');
    final jpeg = image_codec.encodeJpg(pixels, quality: 95);
    document.addPage(pdf.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pdf.EdgeInsets.zero,
        build: (_) => pdf.Image(pdf.MemoryImage(jpeg), fit: pdf.BoxFit.fill)));
  }

  // Draw using logical A4 coordinates at twice the raster resolution.
  canvas.scale(2);
  background();
  for (var index = 0; index < paragraphs.length; index++) {
    final text = paragraphs[index];
    final heading = index == 0 ||
        ['Medicine plans', 'Dose records']
            .any((h) => translateCopy(h, request.language) == text);
    final painter = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
            color: heading ? const Color(0xff156b60) : const Color(0xff18332e),
            fontSize: index == 0
                ? 23
                : heading
                    ? 16
                    : 11,
            height: 1.4,
            fontWeight: heading ? FontWeight.w600 : FontWeight.normal,
            fontFamily: 'ReportHindi',
          )),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width - 2 * margin);
    if (painter.height > bottom - margin) {
      painter.dispose();
      throw const FormatException(
          'A report entry is too long to fit. Shorten the medicine instructions.');
    }
    if (y + painter.height > bottom) {
      await finish();
      page++;
      recorder = ui.PictureRecorder();
      canvas = Canvas(recorder)..scale(2);
      background();
      y = margin;
    }
    painter.paint(canvas, Offset(margin, y));
    y += painter.height + (heading ? 14 : 12);
    painter.dispose();
  }
  await finish();
  return MedicinePdfResult(await document.save(), images);
}
