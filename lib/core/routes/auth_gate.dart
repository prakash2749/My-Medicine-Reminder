import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../components/views/auth/login_view.dart';
import '../components/views/auth/update_password_view.dart';
import '../components/views/medicine/medicine_view.dart';
import '../services/supabase_service.dart';
import '../../providers/auth_provider.dart';

/// Aliases supporting both naming conventions across architecture layers
typedef LoginScreen = LoginView;
typedef HomeScreen = MedicineView;

/// AuthGate widget: Stream-based session guard that automatically directs
/// unauthenticated users to the LoginScreen, authenticated users to HomeScreen,
/// and password recovery deep links to UpdatePasswordView.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    // If password recovery link was activated, show UpdatePasswordView
    if (authProvider.isPasswordRecovery) {
      return const UpdatePasswordView();
    }

    // Graceful fallback for offline, demo, or testing environments where
    // Supabase native instance initialization is bypassed.
    if (!SupabaseService.isInitialized) {
      if (!authProvider.isAuthenticated) {
        return const LoginScreen();
      }
      return const HomeScreen();
    }

    final client = Supabase.instance.client;

    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.hasData &&
            snapshot.data!.event == AuthChangeEvent.passwordRecovery) {
          return const UpdatePasswordView();
        }

        final session = snapshot.hasData
            ? snapshot.data!.session
            : (client.auth.currentSession ?? authProvider.session);

        if (session == null && !authProvider.isAuthenticated) {
          return const LoginScreen();
        }

        return const HomeScreen();
      },
    );
  }
}
