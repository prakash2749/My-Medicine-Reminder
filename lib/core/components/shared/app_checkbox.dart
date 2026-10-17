import 'package:flutter/material.dart';
import 'package:medicine_reminder/core/constants/app_colors.dart';

/// Central reusable CheckboxListTile with modern rounded box and theme awareness.
class AppCheckboxTile extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final Widget? title;
  final String? titleText;
  final Widget? subtitle;
  final String? subtitleText;
  final String? errorText;
  final EdgeInsetsGeometry contentPadding;

  const AppCheckboxTile({
    super.key,
    required this.value,
    required this.onChanged,
    this.title,
    this.titleText,
    this.subtitle,
    this.subtitleText,
    this.errorText,
    this.contentPadding = EdgeInsets.zero,
  }) : assert(
          title != null || titleText != null,
          'Either title or titleText must be provided',
        );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Theme(
          data: Theme.of(context).copyWith(
            checkboxTheme: CheckboxThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              side: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                width: 1.5,
              ),
            ),
          ),
          child: CheckboxListTile(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
            checkColor: Colors.white,
            contentPadding: contentPadding,
            controlAffinity: ListTileControlAffinity.leading,
            title: title ??
                Text(
                  titleText!,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: textPrimary,
                  ),
                ),
            subtitle: subtitle ??
                (subtitleText != null
                    ? Text(
                        subtitleText!,
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      )
                    : null),
          ),
        ),
        if (errorText != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 12.0, top: 2.0),
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
