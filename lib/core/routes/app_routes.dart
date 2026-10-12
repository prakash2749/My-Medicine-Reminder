import 'package:flutter/material.dart';

import 'auth_gate.dart';
import '../components/views/auth/forgot_password_view.dart';
import '../components/views/auth/login_view.dart';
import '../components/views/auth/update_password_view.dart';
import '../components/views/medicine/medicine_view.dart';
import '../components/views/splash/splash_view.dart';

class AppRoutes {
  AppRoutes._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const String initial = '/';
  static const String splash = '/splash';
  static const String authGate = '/auth_gate';
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';
  static const String updatePassword = '/update-password';
  static const String resetCallback = '/reset-callback';
  static const String home = '/home';
  static const String medicines = '/medicines';

  static Map<String, WidgetBuilder> get routes => {
    initial: (context) => const SplashView(),
    splash: (context) => const SplashView(),
    authGate: (context) => const AuthGate(),
    login: (context) => const LoginView(),
    forgotPassword: (context) => const ForgotPasswordView(),
    updatePassword: (context) => const UpdatePasswordView(),
    resetCallback: (context) => const UpdatePasswordView(),
    'reset-callback': (context) => const UpdatePasswordView(),
    home: (context) => const AuthGate(),
    medicines: (context) => const MedicineView(),
  };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final rawName = settings.name ?? '';
    final uri = Uri.tryParse(rawName);
    final path = (uri != null && uri.path.isNotEmpty) ? uri.path : rawName;

    // Handle deep link callback from password recovery email
    if (rawName.contains('reset-callback') ||
        path.contains('reset-callback') ||
        rawName.contains('update-password') ||
        path.contains('update-password')) {
      return MaterialPageRoute(
        builder: (_) => const UpdatePasswordView(),
        settings: settings,
      );
    }

    switch (path) {
      case initial:
      case splash:
        return MaterialPageRoute(
          builder: (_) => const SplashView(),
          settings: settings,
        );
      case authGate:
      case home:
        return MaterialPageRoute(
          builder: (_) => const AuthGate(),
          settings: settings,
        );
      case login:
        return MaterialPageRoute(
          builder: (_) => const LoginView(),
          settings: settings,
        );
      case forgotPassword:
        return MaterialPageRoute(
          builder: (_) => const ForgotPasswordView(),
          settings: settings,
        );
      case updatePassword:
      case resetCallback:
      case 'reset-callback':
        return MaterialPageRoute(
          builder: (_) => const UpdatePasswordView(),
          settings: settings,
        );
      case medicines:
        return MaterialPageRoute(
          builder: (_) => const MedicineView(),
          settings: settings,
        );
      default:
        // Graceful fallback: Redirect unknown or deep-link routes to AuthGate
        return MaterialPageRoute(
          builder: (_) => const AuthGate(),
          settings: settings,
        );
    }
  }
}
