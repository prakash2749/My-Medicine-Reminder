import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'auth_provider.dart';
import 'medicine_reminder_provider.dart';
import 'signup_provider.dart';
import 'theme_provider.dart';

/// Centralized registry for all Provider state management classes.
/// Used directly by MultiProvider at the root of the application widget tree.
class AppProviders {
  AppProviders._();

  static List<SingleChildWidget> get providers => [
    // Core Application Providers
    ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),

    // Feature / Domain Providers
    ChangeNotifierProvider<AuthProvider>(
      lazy: false,
      create: (_) => AuthProvider(),
    ),
    ChangeNotifierProvider<SignupProvider>(create: (_) => SignupProvider()),
    ChangeNotifierProvider<MedicineReminderProvider>(
      create: (_) => MedicineReminderProvider(),
    ),
  ];
}
