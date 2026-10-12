import 'package:flutter/material.dart';
import 'package:medicine_reminder/core/constants/app_colors.dart';

/// Shows a date picker styled specifically for dark and light theme palettes.
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? helpText,
  DatePickerMode initialDatePickerMode = DatePickerMode.day,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final clampedInitial = initialDate.isAfter(lastDate)
      ? lastDate
      : (initialDate.isBefore(firstDate) ? firstDate : initialDate);

  return showDatePicker(
    context: context,
    initialDate: clampedInitial,
    firstDate: firstDate,
    lastDate: lastDate,
    initialDatePickerMode: initialDatePickerMode,
    helpText: helpText,
    builder: (context, child) {
      if (child == null) return const SizedBox.shrink();

      if (isDark) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.accent,
              onPrimary: AppColors.backgroundDark,
              surface: AppColors.cardDark,
              onSurface: AppColors.textPrimaryDark,
              secondary: AppColors.accent,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: AppColors.cardDark,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent,
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: AppColors.cardDark,
              headerBackgroundColor: AppColors.surfaceDark,
              headerForegroundColor: AppColors.textPrimaryDark,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: AppColors.borderDark),
              ),
              dayStyle: const TextStyle(fontWeight: FontWeight.w500),
              yearStyle: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          child: child,
        );
      }

      return Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: AppColors.textPrimaryLight,
            secondary: AppColors.primary,
          ),
          dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          datePickerTheme: DatePickerThemeData(
            backgroundColor: Colors.white,
            headerBackgroundColor: AppColors.primary,
            headerForegroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: AppColors.borderLight),
            ),
          ),
        ),
        child: child,
      );
    },
  );
}

/// Reusable Date Picker Form Field that visually displays selected date
/// with calendar icon, label, and onTap opening [showAppDatePicker].
class AppDatePickerField extends StatelessWidget {
  final String? label;
  final String hintText;
  final String? value;
  final String? errorText;
  final VoidCallback onTap;
  final bool enabled;

  const AppDatePickerField({
    super.key,
    this.label,
    required this.hintText,
    this.value,
    this.errorText,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final borderCol = isDark ? AppColors.borderDark : AppColors.borderLight;
    final bgCol = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;

    final hasValue = value != null && value!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
        ],
        InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              color: bgCol,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: errorText != null ? AppColors.error : borderCol,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasValue ? value! : hintText,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: hasValue ? FontWeight.w500 : FontWeight.w400,
                      color: hasValue ? textPrimary : textSecondary,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  color: textSecondary,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Text(
              errorText!,
              style: const TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ),
        ],
      ],
    );
  }
}
