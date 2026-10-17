import 'package:flutter/material.dart';
import 'package:medicine_reminder/core/constants/app_colors.dart';

/// Central reusable Autocomplete field supporting searchable suggestions
/// with theme-matched dropdown overlays.
class AppAutocompleteField<T extends Object> extends StatelessWidget {
  final String? label;
  final String? hintText;
  final Widget? prefixIcon;
  final String? initialValue;
  final Iterable<T> Function(TextEditingValue) optionsBuilder;
  final void Function(T) onSelected;
  final String Function(T) displayStringForOption;
  final String? errorText;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  const AppAutocompleteField({
    super.key,
    this.label,
    this.hintText,
    this.prefixIcon,
    this.initialValue,
    required this.optionsBuilder,
    required this.onSelected,
    this.displayStringForOption = RawAutocomplete.defaultStringForOption,
    this.errorText,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final bgCol = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final cardBg = isDark ? AppColors.cardDark : Colors.white;
    final borderCol = isDark ? AppColors.borderDark : AppColors.borderLight;

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
        Autocomplete<T>(
          initialValue: initialValue != null
              ? TextEditingValue(text: initialValue!)
              : null,
          optionsBuilder: optionsBuilder,
          displayStringForOption: displayStringForOption,
          onSelected: onSelected,
          fieldViewBuilder:
              (context, textEditingController, focusNode, onFieldSubmitted) {
            return TextFormField(
              controller: textEditingController,
              focusNode: focusNode,
              validator: validator,
              onChanged: onChanged,
              onFieldSubmitted: (String value) => onFieldSubmitted(),
              style: TextStyle(
                color: textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(
                  color: textSecondary.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
                filled: true,
                fillColor: bgCol,
                prefixIcon: prefixIcon,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: borderCol, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: borderCol, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: AppColors.error,
                    width: 1,
                  ),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: AppColors.error,
                    width: 1.5,
                  ),
                ),
                errorText: errorText,
              ),
            );
          },
          optionsViewBuilder: (context, onSelectedOption, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 6,
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: MediaQuery.of(context).size.width - 48,
                  constraints: const BoxConstraints(maxHeight: 220),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderCol),
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: borderCol.withValues(alpha: 0.5),
                    ),
                    itemBuilder: (BuildContext context, int index) {
                      final T option = options.elementAt(index);
                      final title = displayStringForOption(option);
                      return InkWell(
                        onTap: () => onSelectedOption(option),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 12.0,
                          ),
                          child: Text(
                            title,
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
