import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:app_links/app_links.dart';

import 'core/config/app_config.dart';
import 'core/constants/app_strings.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'providers/app_providers.dart';
import 'providers/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    AppConfig.validate();
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabasePublishableKey,
    );

    // 1. Supabase auth stream listener: Capture recovery auth state
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        AppRoutes.router.go(AppRoutes.updatePassword);
      }
    });

    // 2. Direct deep link handler: Guarantees cold-start & warm-start link handling
    _setupDeepLinkHandler();
  } catch (e) {
    debugPrint('Supabase initialization skipped or error: $e');
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
    debugPrint('Received incoming deep link: $uriString');

    if (uriString.contains('reset-callback') ||
        uriString.contains('update-password') ||
        uriString.contains('type=recovery')) {
      try {
        await Supabase.instance.client.auth.getSessionFromUrl(uri);
      } catch (e) {
        debugPrint('getSessionFromUrl error: $e');
      }

      AppRoutes.router.go(AppRoutes.updatePassword);
    }
  }

  // Handle initial link (cold start when app was terminated)
  appLinks
      .getInitialLink()
      .then((uri) {
        if (uri != null) {
          handleUri(uri);
        }
      })
      .catchError((e) {
        debugPrint('getInitialLink error: $e');
      });

  // Handle incoming link stream (warm start when app was in background)
  appLinks.uriLinkStream.listen(
    (uri) => handleUri(uri),
    onError: (e) => debugPrint('uriLinkStream error: $e'),
  );
}
