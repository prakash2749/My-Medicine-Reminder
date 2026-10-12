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
              surfaceTintColor: Colors.transparent,
            ),
            iconTheme: const IconThemeData(color: AppColors.textPrimaryDark),
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
              headerHeadlineStyle: const TextStyle(
                color: AppColors.textPrimaryDark,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
              headerHelpStyle: const TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: AppColors.borderDark),
              ),
              weekdayStyle: const TextStyle(
                color: AppColors.textSecondaryDark,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              dayStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.backgroundDark;
                }
                if (states.contains(WidgetState.disabled)) {
                  return AppColors.textSecondaryDark.withValues(alpha: 0.35);
                }
                return AppColors.textPrimaryDark;
              }),
              dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.accent;
                }
                return Colors.transparent;
              }),
              todayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.backgroundDark;
                }
                return AppColors.accent;
              }),
              todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.accent;
                }
                return Colors.transparent;
              }),
              todayBorder: const BorderSide(
                color: AppColors.accent,
                width: 1.5,
              ),
              yearStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
              yearForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.backgroundDark;
                }
                if (states.contains(WidgetState.disabled)) {
                  return AppColors.textSecondaryDark.withValues(alpha: 0.35);
                }
                return AppColors.textPrimaryDark;
              }),
              yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.accent;
                }
                return Colors.transparent;
              }),
              dividerColor: AppColors.borderDark,
              cancelButtonStyle: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondaryDark,
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
              confirmButtonStyle: TextButton.styleFrom(
                foregroundColor: AppColors.accent,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
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
          dialogTheme: const DialogThemeData(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
          ),
          iconTheme: const IconThemeData(color: AppColors.textPrimaryLight),
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
            headerHeadlineStyle: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
            headerHelpStyle: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: AppColors.borderLight),
            ),
            weekdayStyle: const TextStyle(
              color: AppColors.textSecondaryLight,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            dayStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            dayForegroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return Colors.white;
              }
              if (states.contains(WidgetState.disabled)) {
                return AppColors.textSecondaryLight.withValues(alpha: 0.35);
              }
              return AppColors.textPrimaryLight;
            }),
            dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return AppColors.primary;
              }
              return Colors.transparent;
            }),
            todayForegroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return Colors.white;
              }
              return AppColors.primary;
            }),
            todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return AppColors.primary;
              }
              return Colors.transparent;
            }),
            todayBorder: const BorderSide(color: AppColors.primary, width: 1.5),
            yearStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
            yearForegroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return Colors.white;
              }
              if (states.contains(WidgetState.disabled)) {
                return AppColors.textSecondaryLight.withValues(alpha: 0.35);
              }
              return AppColors.textPrimaryLight;
            }),
            yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return AppColors.primary;
              }
              return Colors.transparent;
            }),
            dividerColor: AppColors.borderLight,
            cancelButtonStyle: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondaryLight,
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
            confirmButtonStyle: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        child: child,
      );
    },
  );
}

/// Shows a time picker styled specifically for dark and light theme palettes.
Future<TimeOfDay?> showAppTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  String? helpText,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return showTimePicker(
    context: context,
    initialTime: initialTime,
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
              surfaceTintColor: Colors.transparent,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent,
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: AppColors.cardDark,
              hourMinuteColor: AppColors.surfaceDark,
              hourMinuteTextColor: AppColors.textPrimaryDark,
              dayPeriodColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.accent.withValues(alpha: 0.2);
                }
                return AppColors.surfaceDark;
              }),
              dayPeriodTextColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.accent;
                }
                return AppColors.textSecondaryDark;
              }),
              dialHandColor: AppColors.accent,
              dialBackgroundColor: AppColors.surfaceDark,
              dialTextColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.backgroundDark;
                }
                return AppColors.textPrimaryDark;
              }),
              entryModeIconColor: AppColors.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: AppColors.borderDark),
              ),
              cancelButtonStyle: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondaryDark,
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
              confirmButtonStyle: TextButton.styleFrom(
                foregroundColor: AppColors.accent,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
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
          dialogTheme: const DialogThemeData(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          timePickerTheme: TimePickerThemeData(
            backgroundColor: Colors.white,
            hourMinuteColor: AppColors.backgroundLight,
            hourMinuteTextColor: AppColors.primary,
            dayPeriodColor: WidgetStateColor.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return AppColors.primary.withValues(alpha: 0.15);
              }
              return AppColors.backgroundLight;
            }),
            dayPeriodTextColor: WidgetStateColor.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return AppColors.primary;
              }
              return AppColors.textSecondaryLight;
            }),
            dialHandColor: AppColors.primary,
            dialBackgroundColor: AppColors.backgroundLight,
            dialTextColor: WidgetStateColor.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return Colors.white;
              }
              return AppColors.textPrimaryLight;
            }),
            entryModeIconColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: AppColors.borderLight),
            ),
            cancelButtonStyle: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondaryLight,
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
            confirmButtonStyle: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
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
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 20,
                  color: isDark ? AppColors.accent : AppColors.primary,
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
