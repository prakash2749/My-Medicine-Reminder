import 'package:flutter/material.dart';
import 'package:medicine_reminder/core/components/custom_button.dart';
import 'package:medicine_reminder/core/constants/app_assets.dart';
import 'package:medicine_reminder/core/constants/app_colors.dart';
import 'package:medicine_reminder/core/components/shared/shared.dart';
import 'package:medicine_reminder/providers/medicine_reminder_provider.dart';
import 'package:provider/provider.dart';

import '../models/medicine_reminder_model.dart';

class AddMedicineSheet extends StatefulWidget {
  const AddMedicineSheet({super.key});

  @override
  State<AddMedicineSheet> createState() => _AddMedicineSheetState();
}

class _AddMedicineSheetState extends State<AddMedicineSheet> {
  static const List<String> _commonMedicines = [
    'Paracetamol',
    'Amoxicillin',
    'Metformin',
    'Atorvastatin',
    'Omeprazole',
    'Amlodipine',
    'Losartan',
    'Ibuprofen',
    'Cetirizine',
    'Azithromycin',
    'Pantoprazole',
    'Aspirin',
    'Metoprolol',
    'Levothyroxine',
    'Vitamin D3',
    'Multivitamin',
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _notesController = TextEditingController();

  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);
  String _selectedCategory = 'Pill';
  String _selectedFrequency = 'Daily';

  final List<String> _categories = ['Pill', 'Capsule', 'Syrup', 'Injection'];
  final List<String> _frequencies = [
    'Daily',
    'Twice a day',
    'Thrice a day',
    'Weekly',
    'As needed',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showAppTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final hourStr = _selectedTime.hourOfPeriod.toString().padLeft(2, '0');
      final minuteStr = _selectedTime.minute.toString().padLeft(2, '0');
      final periodStr = _selectedTime.period == DayPeriod.am ? 'AM' : 'PM';
      final formattedTime = '$hourStr:$minuteStr $periodStr';

      final reminder = MedicineReminder(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        dosage: _dosageController.text.trim(),
        time: formattedTime,
        category: _selectedCategory,
        frequency: _selectedFrequency,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        isTaken: false,
        createdAt: DateTime.now(),
      );

      // Mutate state through Provider
      context.read<MedicineReminderProvider>().addReminder(reminder);

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${reminder.name} reminder scheduled!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomInset + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.surfaceDark
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Image.asset(
                          AppAssets.appIcon,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.medication,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'New Medicine Reminder',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Medicine Name Autocomplete
              AppAutocompleteField<String>(
                label: 'Medicine Name *',
                hintText: 'e.g. Paracetamol, Metformin',
                prefixIcon: const Icon(Icons.medication_outlined),
                initialValue: _nameController.text.isNotEmpty
                    ? _nameController.text
                    : null,
                optionsBuilder: (textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<String>.empty();
                  }
                  return _commonMedicines.where(
                    (med) => med.toLowerCase().contains(
                      textEditingValue.text.toLowerCase(),
                    ),
                  );
                },
                onSelected: (val) => _nameController.text = val,
                onChanged: (val) => _nameController.text = val,
                validator: (val) => (val == null || val.trim().isEmpty)
                    ? 'Please enter a name'
                    : null,
              ),
              const SizedBox(height: 12),

              // Dosage
              AppTextField(
                controller: _dosageController,
                label: 'Dosage / Strength *',
                hintText: 'e.g. 500 mg, 1 tablet, 10 ml',
                prefixIcon: const Icon(Icons.scale_outlined),
                validator: (val) => (val == null || val.trim().isEmpty)
                    ? 'Please enter dosage'
                    : null,
              ),
              const SizedBox(height: 12),

              // Time & Category Row
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickTime,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.surfaceDark
                              : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? AppColors.borderDark
                                : AppColors.borderLight,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 20,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Time',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight,
                                  ),
                                ),
                                Text(
                                  _selectedTime.format(context),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppColors.textPrimaryDark
                                        : AppColors.textPrimaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Form',
                        prefixIcon: const Icon(Icons.category_outlined),
                        filled: true,
                        fillColor: isDark
                            ? AppColors.surfaceDark
                            : AppColors.surfaceLight,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: isDark
                                ? AppColors.borderDark
                                : AppColors.borderLight,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: isDark
                                ? AppColors.borderDark
                                : AppColors.borderLight,
                          ),
                        ),
                      ),
                      items: _categories
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedCategory = val);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Frequency
              DropdownButtonFormField<String>(
                initialValue: _selectedFrequency,
                decoration: InputDecoration(
                  labelText: 'Frequency',
                  prefixIcon: const Icon(Icons.repeat),
                  filled: true,
                  fillColor: isDark
                      ? AppColors.surfaceDark
                      : AppColors.surfaceLight,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: isDark
                          ? AppColors.borderDark
                          : AppColors.borderLight,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: isDark
                          ? AppColors.borderDark
                          : AppColors.borderLight,
                    ),
                  ),
                ),
                items: _frequencies
                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedFrequency = val);
                },
              ),
              const SizedBox(height: 12),

              // Notes
              AppTextField(
                controller: _notesController,
                label: 'Instructions / Notes (optional)',
                hintText: 'e.g. After breakfast with warm water',
                prefixIcon: const Icon(Icons.notes_outlined),
                maxLines: 2,
              ),
              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  label: 'Schedule Reminder',
                  icon: Icons.check,
                  onPressed: _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
