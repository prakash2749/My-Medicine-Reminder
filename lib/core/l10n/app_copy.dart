import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'hindi_catalog.dart';

String normalizeDigits(String value) =>
    String.fromCharCodes(value.runes.map((r) => r >= 0x966 && r <= 0x96f
        ? r - 0x966 + 48
        : r >= 0x660 && r <= 0x669
            ? r - 0x660 + 48
            : r));

class LocalizedNumberFormatter extends TextInputFormatter {
  const LocalizedNumberFormatter();
  @override
  TextEditingValue formatEditUpdate(
          TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: normalizeDigits(newValue.text));
}

final _patterns = hindiCatalog.entries
    .where((e) => e.key.contains('{0}'))
    .map((e) {
  final parts = e.key.split(RegExp(r'\{\d+\}'));
  return (
    pattern: RegExp('^${parts.map(RegExp.escape).join('(.*?)')}\$'),
    value: e.value
  );
}).toList()
  ..sort(
      (a, b) => b.pattern.pattern.length.compareTo(a.pattern.pattern.length));

/// Call only for application-owned copy; prescription text is never translated.
String translateCopy(String text, String language) {
  if (language != 'hi') return text;
  final exact = hindiCatalog[text];
  if (exact != null) return exact;
  for (final entry in _patterns) {
    final match = entry.pattern.firstMatch(text);
    if (match == null) continue;
    var result = entry.value;
    for (var i = 1; i <= match.groupCount; i++) {
      result = result.replaceAll('{${i - 1}}', match.group(i)!);
    }
    return result;
  }
  return text;
}

extension LocalCopy on BuildContext {
  String tr(String text) =>
      translateCopy(text, Localizations.localeOf(this).languageCode);
}

/// Keeps const UI declarations readable while resolving the current locale.
/// Do not use for medicine names, notes, or other user-entered text.
class AppText extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;
  final bool? softWrap;
  final String? semanticsLabel;
  final TextDirection? textDirection;
  const AppText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.overflow,
    this.maxLines,
    this.softWrap,
    this.semanticsLabel,
    this.textDirection,
  });
  @override
  Widget build(BuildContext context) => Text(
        context.tr(data),
        style: style,
        textAlign: textAlign,
        overflow: overflow,
        maxLines: maxLines,
        softWrap: softWrap,
        semanticsLabel:
            semanticsLabel == null ? null : context.tr(semanticsLabel!),
        textDirection: textDirection,
      );
}
