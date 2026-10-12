import 'package:flutter/material.dart';
import 'package:medicine_reminder/core/constants/app_colors.dart';
import 'package:medicine_reminder/providers/medicine_reminder_provider.dart';
import 'package:provider/provider.dart';

import '../models/medicine_reminder_model.dart';

class MedicineCard extends StatelessWidget {
  final MedicineReminder reminder;

  const MedicineCard({super.key, required this.reminder});

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'capsule':
        return Icons.medication_liquid;
      case 'syrup':
        return Icons.local_drink;
      case 'injection':
        return Icons.vaccines;
      case 'pill':
      default:
        return Icons.medication;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.surfaceDark : Colors.white;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: reminder.isTaken
              ? AppColors.success.withValues(alpha: 0.4)
              : (isDark ? AppColors.borderDark : AppColors.borderLight),
          width: reminder.isTaken ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Category Icon Badge
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: reminder.isTaken
                    ? AppColors.success.withValues(alpha: 0.15)
                    : AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getCategoryIcon(reminder.category),
                color: reminder.isTaken ? AppColors.success : AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),

            // Medicine Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          reminder.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            decoration: reminder.isTaken
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                            color: reminder.isTaken
                                ? (isDark ? Colors.grey[400] : Colors.grey[600])
                                : null,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white10 : Colors.grey[100]),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 12,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              reminder.time,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${reminder.dosage} • ${reminder.frequency}',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  if (reminder.notes != null && reminder.notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      reminder.notes!,
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: isDark ? Colors.grey[500] : Colors.grey[500],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Toggle Taken Button
            IconButton(
              icon: Icon(
                reminder.isTaken
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: reminder.isTaken ? AppColors.success : Colors.grey[400],
                size: 28,
              ),
              tooltip: reminder.isTaken ? 'Mark as pending' : 'Mark as taken',
              onPressed: () {
                context.read<MedicineReminderProvider>().toggleTaken(
                  reminder.id,
                );
              },
            ),

            // Popup menu for Delete
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 20, color: Colors.grey[400]),
              onSelected: (value) {
                if (value == 'delete') {
                  context.read<MedicineReminderProvider>().deleteReminder(
                    reminder.id,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${reminder.name} removed'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        color: AppColors.error,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: AppColors.error)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
