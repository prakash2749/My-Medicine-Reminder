import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'auth_gate.dart';
import '../components/views/auth/forgot_password_view.dart';
import '../components/views/auth/login_view.dart';
import '../components/views/auth/update_password_view.dart';
import '../components/views/auth/onboarding/care_circle_step_view.dart';
import '../components/views/auth/onboarding/create_account_step_view.dart';
import '../components/views/auth/onboarding/local_welcome_view.dart';
import '../components/views/auth/onboarding/get_started_view.dart';
import '../components/views/auth/onboarding/my_day_step_view.dart';
import '../components/views/auth/onboarding/personal_info_step_view.dart';
import '../components/views/auth/onboarding/purpose_step_view.dart';
import '../components/views/auth/onboarding/verify_email_step_view.dart';
import '../components/views/splash/splash_view.dart';

class AppRoutes {
  AppRoutes._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const String initial = '/';
  static const String splash = '/splash';
  static const String getStarted = '/get-started';
  static const String accountWelcome = '/account-welcome';
  static const String personalInfo = '/signup/personal-info';
  static const String purpose = '/signup/purpose';
  static const String myDay = '/signup/my-day';
  static const String careCircle = '/signup/care-circle';
  static const String createAccount = '/signup/create-account';
  static const String verifyEmail = '/signup/verify-email';
  static const String authGate = '/auth_gate';
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';
  static const String updatePassword = '/update-password';
  static const String resetCallback = '/reset-callback';
  static const String home = '/home';
  static const String medicines = '/medicines';

  /// Central GoRouter configuration
  static final GoRouter router = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: initial,
    routes: [
      GoRoute(path: initial, builder: (context, state) => const SplashView()),
      GoRoute(path: splash, builder: (context, state) => const SplashView()),
      GoRoute(
        path: getStarted,
        builder: (context, state) => const LocalWelcomeView(),
      ),
      GoRoute(
          path: accountWelcome,
          builder: (context, state) => const GetStartedView()),
      GoRoute(path: login, builder: (context, state) => const LoginView()),
      GoRoute(
        path: forgotPassword,
        builder: (context, state) => const ForgotPasswordView(),
      ),
      GoRoute(
        path: updatePassword,
        builder: (context, state) => const UpdatePasswordView(),
      ),
      GoRoute(
        path: resetCallback,
        builder: (context, state) => const UpdatePasswordView(),
      ),
      GoRoute(path: authGate, builder: (context, state) => const AuthGate()),
      GoRoute(path: home, builder: (context, state) => const AuthGate()),
      GoRoute(path: medicines, builder: (context, state) => const AuthGate()),
      // Onboarding flows
      GoRoute(
        path: personalInfo,
        builder: (context, state) => const PersonalInfoStepView(),
      ),
      GoRoute(
        path: purpose,
        builder: (context, state) => const PurposeStepView(),
      ),
      GoRoute(path: myDay, builder: (context, state) => const MyDayStepView()),
      GoRoute(
        path: careCircle,
        builder: (context, state) => const CareCircleStepView(),
      ),
      GoRoute(
        path: createAccount,
        builder: (context, state) => const CreateAccountStepView(),
      ),
      GoRoute(
        path: verifyEmail,
        builder: (context, state) => const VerifyEmailStepView(),
      ),
    ],
  );

  /// Backwards-compatible legacy route map for widget test harnesses
  static Map<String, WidgetBuilder> get routes => {
        initial: (context) => const SplashView(),
        splash: (context) => const SplashView(),
        getStarted: (context) => const LocalWelcomeView(),
        accountWelcome: (context) => const GetStartedView(),
        personalInfo: (context) => const PersonalInfoStepView(),
        purpose: (context) => const PurposeStepView(),
        myDay: (context) => const MyDayStepView(),
        careCircle: (context) => const CareCircleStepView(),
        createAccount: (context) => const CreateAccountStepView(),
        verifyEmail: (context) => const VerifyEmailStepView(),
        authGate: (context) => const AuthGate(),
        login: (context) => const LoginView(),
        forgotPassword: (context) => const ForgotPasswordView(),
        updatePassword: (context) => const UpdatePasswordView(),
        resetCallback: (context) => const UpdatePasswordView(),
        'reset-callback': (context) => const UpdatePasswordView(),
        home: (context) => const AuthGate(),
        medicines: (context) => const AuthGate(),
      };

  /// Backwards-compatible legacy route generator
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final rawName = settings.name ?? '';
    final uri = Uri.tryParse(rawName);
    final path = (uri != null && uri.path.isNotEmpty) ? uri.path : rawName;

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
      case getStarted:
        return MaterialPageRoute(
          builder: (_) => const LocalWelcomeView(),
          settings: settings,
        );
      case accountWelcome:
        return MaterialPageRoute(
            builder: (_) => const GetStartedView(), settings: settings);
      case personalInfo:
        return MaterialPageRoute(
          builder: (_) => const PersonalInfoStepView(),
          settings: settings,
        );
      case purpose:
        return MaterialPageRoute(
          builder: (_) => const PurposeStepView(),
          settings: settings,
        );
      case myDay:
        return MaterialPageRoute(
          builder: (_) => const MyDayStepView(),
          settings: settings,
        );
      case careCircle:
        return MaterialPageRoute(
          builder: (_) => const CareCircleStepView(),
          settings: settings,
        );
      case createAccount:
        return MaterialPageRoute(
          builder: (_) => const CreateAccountStepView(),
          settings: settings,
        );
      case verifyEmail:
        return MaterialPageRoute(
          builder: (_) => const VerifyEmailStepView(),
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
          builder: (_) => const AuthGate(),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const AuthGate(),
          settings: settings,
        );
    }
  }
}
