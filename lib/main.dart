import 'package:flutter_localizations/flutter_localizations.dart';
import 'providers/app_preferences.dart';
import 'core/services/local_data_cleanup.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:app_links/app_links.dart';

import 'core/config/app_config.dart';
import 'core/constants/app_strings.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'core/services/medicine_notifications.dart';
import 'core/services/reminder_background.dart';
import 'providers/app_providers.dart';
import 'providers/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await clearMedicineReports();
  } catch (_) {
    debugPrint('Temporary report cleanup is unavailable.');
  }

  LocalMedicineNotifications.instance.onOpen =
      () => AppRoutes.router.go(AppRoutes.authGate);
  try {
    await initializeReminderBackground();
  } catch (_) {
    debugPrint('Background reminder maintenance is unavailable.');
  }

  try {
    AppConfig.validate();
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabasePublishableKey,
    );

    // 1. Supabase auth stream listener: Capture recovery auth state and signedIn state
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        AppRoutes.router.go(AppRoutes.updatePassword);
      } else if (data.event == AuthChangeEvent.signedIn) {
        // Automatically route to Dashboard when authenticated (e.g. from email verification link)
        final uri =
            AppRoutes.router.routerDelegate.currentConfiguration.uri.toString();
        final isOnboardingOrAuth = uri.contains('signup') ||
            uri.contains('login') ||
            uri.contains('verify-email') ||
            uri.contains('get-started');
        if (isOnboardingOrAuth) {
          AppRoutes.router.go(AppRoutes.authGate);
        }
      }
    });

    // 2. Direct deep link handler: Guarantees cold-start & warm-start link handling
    _setupDeepLinkHandler();
  } catch (e) {
    debugPrint('Supabase initialization skipped or error.');
  }

  runApp(
    MultiProvider(providers: AppProviders.providers, child: const MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp.router(
      routerConfig: AppRoutes.router,
      locale: context.watch<AppPreferences>().locale,
      supportedLocales: const [Locale('en'), Locale('hi')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
    );
  }
}

void _setupDeepLinkHandler() {
  final appLinks = AppLinks();

  Future<void> handleUri(Uri uri) async {
    final uriString = uri.toString();
    debugPrint('Received authentication link.');

    if (uriString.contains('reset-callback') ||
        uriString.contains('update-password') ||
        uriString.contains('type=recovery')) {
      try {
        await Supabase.instance.client.auth.getSessionFromUrl(uri);
      } catch (e) {
        debugPrint('Authentication link could not be processed.');
      }

      AppRoutes.router.go(AppRoutes.updatePassword);
    } else if (uriString.contains('login-callback') ||
        uriString.contains('signup-callback') ||
        uriString.contains('type=signup') ||
        uriString.contains('type=email_confirmation') ||
        uriString.contains('code=') ||
        uriString.contains('access_token')) {
      try {
        await Supabase.instance.client.auth.getSessionFromUrl(uri);
      } catch (e) {
        debugPrint('Authentication link could not be processed.');
      }

      AppRoutes.router.go(AppRoutes.authGate);
    }
  }

  // Handle initial link (cold start when app was terminated)
  appLinks.getInitialLink().then((uri) {
    if (uri != null) {
      handleUri(uri);
    }
  }).catchError((e) {
    debugPrint('getInitialLink error.');
  });

  // Handle incoming link stream (warm start when app was in background)
  appLinks.uriLinkStream.listen(
    (uri) => handleUri(uri),
    onError: (e) => debugPrint('uriLinkStream error.'),
  );
}
