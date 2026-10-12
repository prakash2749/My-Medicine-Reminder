import 'package:flutter/material.dart';

/// Centralized utility helpers for DateTime and TimeOfDay formatting.
class DateTimeUtils {
  DateTimeUtils._();

  /// Converts Flutter TimeOfDay to SQL TIME string 'HH:mm:00'
  static String formatTimeOfDayToSql(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  /// Converts TimeOfDay to human-readable 12-hour format, e.g. '7:00 AM'
  static String formatTimeOfDayTo12Hour(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  /// Formats DateTime to clean readable string, e.g. '09 Nov 2000'
  static String formatDateToDisplay(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year.toString();
    return '$day $month $year';
  }

  /// Formats DateTime to SQL DATE string 'YYYY-MM-DD'
  static String formatDateToSql(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
