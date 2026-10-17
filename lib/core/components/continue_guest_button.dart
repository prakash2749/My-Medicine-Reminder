import 'package:medicine_reminder/core/l10n/app_copy.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/app_preferences.dart';
import '../routes/app_routes.dart';

class ContinueGuestButton extends StatelessWidget {
  const ContinueGuestButton({super.key});
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        key: const Key('continue-guest'),
        icon: const Icon(Icons.phonelink_lock),
        label: const AppText('Continue as guest'),
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const AppText('Use this device without an account'),
              content: const SingleChildScrollView(
                child: AppText(
                  'Unlimited offline use. Medicine plans and records stay encrypted on this device. There is no cloud backup or caregiver sharing. Uninstalling or resetting can remove them. Keep a separate copy of important records. Notifications hide medicine details. You can enable reminders after adding a medicine.',
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const AppText('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const AppText('Continue as guest')),
              ],
            ),
          );
          if (confirmed != true || !context.mounted) return;
          final settings = context.read<AppPreferences>();
          final saved = await settings.setGuest(true);
          if (!context.mounted) return;
          if (saved) {
            context.go(AppRoutes.authGate);
          } else {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(settings.error!)));
          }
        },
      );
}
