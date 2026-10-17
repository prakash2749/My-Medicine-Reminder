import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../../providers/app_preferences.dart';
import '../../../../l10n/app_copy.dart';
import '../../../../routes/app_routes.dart';
import '../../../continue_guest_button.dart';
import '../../policy_view.dart';

class LocalWelcomeView extends StatelessWidget {
  const LocalWelcomeView({super.key});
  @override
  Widget build(BuildContext context) {
    final preferences = context.watch<AppPreferences>();
    return Scaffold(
      appBar: AppBar(title: const Text('Medicine Reminder')),
      body: SafeArea(
          child: ListView(
        padding: const EdgeInsets.all(28),
        children: [
          const SizedBox(height: 32),
          Icon(Icons.medication_outlined,
              size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 24),
          AppText('Your medicines, on your device',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          const AppText(
              'Record the medicine plan you already follow. Set reminders, record doses, and keep track of stock. No account is needed.'),
          const SizedBox(height: 12),
          const AppText(
              'For adults managing their own fixed daily or weekday schedules. This app does not calculate doses or provide treatment advice.'),
          const PolicyLink(),
          const SizedBox(height: 28),
          DropdownButtonFormField<String>(
            key: ValueKey(preferences.language),
            initialValue: preferences.language,
            decoration: InputDecoration(
                labelText: context.tr('Language'),
                border: const OutlineInputBorder()),
            items: const [
              DropdownMenuItem(
                  value: 'device', child: AppText('Device language')),
              DropdownMenuItem(value: 'en', child: Text('English')),
              DropdownMenuItem(value: 'hi', child: Text('हिन्दी')),
            ],
            onChanged: (value) => preferences.setLanguage(value!),
          ),
          const SizedBox(height: 24),
          const ContinueGuestButton(),
          const SizedBox(height: 16),
          TextButton(
              onPressed: () => context.go(AppRoutes.login),
              child: const AppText('Sign in to an existing account')),
          TextButton(
              onPressed: () => context.go(AppRoutes.accountWelcome),
              child: const AppText('Create an optional account')),
          if (preferences.error != null) AppText(preferences.error!),
        ],
      )),
    );
  }
}
