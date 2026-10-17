import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';
import '../config/app_config.dart';

/// Result container for authentication operations with email verification metadata.
class AuthResult {
  final bool success;
  final User? user;
  final Session? session;
  final bool needsEmailVerification;
  final String? errorMessage;

  const AuthResult({
    required this.success,
    this.user,
    this.session,
    this.needsEmailVerification = false,
    this.errorMessage,
  });

  factory AuthResult.success({
    User? user,
    Session? session,
    bool needsEmailVerification = false,
  }) {
    return AuthResult(
      success: true,
      user: user,
      session: session,
      needsEmailVerification: needsEmailVerification,
    );
  }

  factory AuthResult.failure(
    String errorMessage, {
    bool needsEmailVerification = false,
  }) {
    return AuthResult(
      success: false,
      needsEmailVerification: needsEmailVerification,
      errorMessage: errorMessage,
    );
  }
}

/// Dedicated page-wise authentication service managing all Supabase Auth interactions.
class AuthService {
  final SupabaseClient? _customClient;

  AuthService({SupabaseClient? client}) : _customClient = client;

  SupabaseClient? get client => _customClient ?? SupabaseService.client;

  Stream<AuthState>? get onAuthStateChange => client?.auth.onAuthStateChange;

  User? get currentUser => client?.auth.currentUser;

  Session? get currentSession => client?.auth.currentSession;

  bool get isAuthenticated => currentUser != null;

  bool get isEmailVerified => currentUser?.emailConfirmedAt != null;

  /// Sign in with email and password.
  /// Handles unconfirmed email exceptions cleanly.
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final supabase = client;
      if (supabase == null) {
        return AuthResult.failure('Supabase client is not initialized.');
      }

      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      return AuthResult.success(user: response.user, session: response.session);
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      final isUnconfirmed = msg.contains('email not confirmed') ||
          msg.contains('not verified') ||
          e.statusCode == 'email_not_confirmed';

      return AuthResult.failure(
        isUnconfirmed
            ? 'Your email has not been verified yet. Please check your inbox or click resend below.'
            : e.message,
        needsEmailVerification: isUnconfirmed,
      );
    } catch (e) {
      return AuthResult.failure(e.toString());
    }
  }

  /// Sign up with email, password, and optional full name.
  /// Detects whether Supabase requires email verification.
  Future<AuthResult> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    try {
      final supabase = client;
      if (supabase == null) {
        return AuthResult.failure('Supabase client is not initialized.');
      }

      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: AppConfig.authRedirectUrl,
        data: fullName != null && fullName.isNotEmpty
            ? {'full_name': fullName, 'name': fullName}
            : null,
      );

      final user = response.user;
      final session = response.session;

      // When Supabase has email confirmation enabled, session is null
      // and user's emailConfirmedAt is null.
      final bool requiresVerification =
          session == null && user != null && user.emailConfirmedAt == null;

      return AuthResult.success(
        user: user,
        session: session,
        needsEmailVerification: requiresVerification,
      );
    } on AuthException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure(e.toString());
    }
  }

  /// Resends the verification email for the given email address.
  Future<bool> resendVerificationEmail({required String email}) async {
    try {
      final supabase = client;
      if (supabase == null) return false;

      await supabase.auth.resend(type: OtpType.signup, email: email);
      return true;
    } catch (e) {
      debugPrint('Error resending verification email.');
      return false;
    }
  }

  /// Sends a password recovery email using Supabase Auth.
  Future<AuthResult> sendPasswordResetEmail({
    required String email,
    String? redirectTo,
  }) async {
    try {
      final supabase = client;
      if (supabase == null) {
        return AuthResult.failure('Supabase client is not initialized.');
      }

      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: redirectTo ?? AppConfig.resetPasswordRedirectUrl,
      );
      return AuthResult.success();
    } on AuthException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure(e.toString());
    }
  }

  /// Updates the user's password once recovery session is active.
  Future<AuthResult> updatePassword({required String newPassword}) async {
    try {
      final supabase = client;
      if (supabase == null) {
        return AuthResult.failure('Supabase client is not initialized.');
      }

      final response = await supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      return AuthResult.success(user: response.user);
    } on AuthException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure(e.toString());
    }
  }

  /// Signs out the current user session.
  Future<void> signOut() async {
    try {
      final supabase = client;
      if (supabase != null) {
        await supabase.auth.signOut();
      }
    } catch (e) {
      debugPrint('Error signing out.');
    }
  }
}
