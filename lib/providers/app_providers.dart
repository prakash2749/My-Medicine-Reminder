import 'app_preferences.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'auth_provider.dart';
import 'medicine_reminder_provider.dart';
import 'signup_provider.dart';
import 'theme_provider.dart';
import '../core/services/medicine_store.dart';
import '../core/services/medicine_notifications.dart';

/// Centralized registry for all Provider state management classes.
/// Used directly by MultiProvider at the root of the application widget tree.
class AppProviders {
  AppProviders._();

  static List<SingleChildWidget> get providers => create();

  static List<SingleChildWidget> create({
    AuthProvider? auth,
    MedicineStore? medicineStore,
    MedicineNotifications? medicineNotifications,
    AppPreferences? preferences,
  }) =>
      [
        ChangeNotifierProvider<AppPreferences>(
            lazy: false, create: (_) => preferences ?? AppPreferences()),
        // Core Application Providers
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),

        // Feature / Domain Providers
        ChangeNotifierProvider<AuthProvider>(
          lazy: false,
          create: (_) => auth ?? AuthProvider(),
        ),
        ChangeNotifierProvider<SignupProvider>(create: (_) => SignupProvider()),
        ChangeNotifierProxyProvider2<AuthProvider, AppPreferences,
            MedicineReminderProvider>(
          lazy: false,
          create: (_) => MedicineReminderProvider(
            store: medicineStore,
            notifications: medicineNotifications,
          ),
          update: (_, auth, settings, medicines) => medicines!
            ..bindUser(auth.user?.id ??
                (settings.guestEnabled ? AppPreferences.guestOwner : null)),
        ),
      ];
}
