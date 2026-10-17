import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/routes/app_routes.dart';
import '../core/services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  User? _user;
  Session? _session;
  bool _isLoading = false;
  String? _errorMessage;
  bool _needsEmailVerification = false;
  bool _isPasswordRecovery = false;
  String? _pendingVerificationEmail;
  StreamSubscription<AuthState>? _authSubscription;

  AuthProvider({AuthService? authService})
      : _authService = authService ?? AuthService() {
    _initAuthListener();
  }

  User? get user => _user;
  Session? get session => _session;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get needsEmailVerification => _needsEmailVerification;
  bool get isPasswordRecovery => _isPasswordRecovery;
  String? get pendingVerificationEmail => _pendingVerificationEmail;
  AuthService get authService => _authService;

  void clearPasswordRecovery() {
    _isPasswordRecovery = false;
    notifyListeners();
  }

  void _initAuthListener() {
    try {
      _user = _authService.currentUser;
      _session = _authService.currentSession;
      final stream = _authService.onAuthStateChange;
      if (stream != null) {
        _authSubscription = stream.listen((data) {
          _user = data.session?.user ?? _authService.currentUser;
          _session = data.session ?? _authService.currentSession;
          if (_user != null) {
            _needsEmailVerification = false;
          }
          if (data.event == AuthChangeEvent.passwordRecovery) {
            _isPasswordRecovery = true;
            AppRoutes.router.go(AppRoutes.updatePassword);
          } else if (data.event == AuthChangeEvent.signedOut) {
            _isPasswordRecovery = false;
          }
          notifyListeners();
        });
      }
    } catch (e) {
      debugPrint('Supabase auth listener initialization skipped.');
    }
  }

  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    _needsEmailVerification = false;

    final result = await _authService.signIn(email: email, password: password);
    _user = result.user;
    _session = result.session;
    _needsEmailVerification = result.needsEmailVerification;
    if (_needsEmailVerification) {
      _pendingVerificationEmail = email;
    }
    _errorMessage = result.errorMessage;
    _setLoading(false);
    return result;
  }

  Future<AuthResult> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    _needsEmailVerification = false;

    final result = await _authService.signUp(
      email: email,
      password: password,
      fullName: fullName,
    );
    _user = result.user;
    _session = result.session;
    _needsEmailVerification = result.needsEmailVerification;
    if (_needsEmailVerification) {
      _pendingVerificationEmail = email;
    }
    _errorMessage = result.errorMessage;
    _setLoading(false);
    return result;
  }

  Future<bool> resendVerificationEmail([String? email]) async {
    final targetEmail = email ?? _pendingVerificationEmail ?? _user?.email;
    if (targetEmail == null || targetEmail.isEmpty) return false;

    _setLoading(true);
    final success = await _authService.resendVerificationEmail(
      email: targetEmail,
    );
    _setLoading(false);
    return success;
  }

  /// Verifies or establishes an active session after email verification.
  /// Checks active client session, refreshes if possible, or signs in using credentials.
  Future<bool> refreshOrCheckSession({String? email, String? password}) async {
    _setLoading(true);
    try {
      // 1. Check existing session on Supabase client
      final current = _authService.currentSession;
      if (current != null) {
        _session = current;
        _user = current.user;
        _needsEmailVerification = false;
        _setLoading(false);
        notifyListeners();
        return true;
      }

      // 2. Try refreshing if credentials/tokens exist
      final client = _authService.client;
      if (client != null) {
        try {
          final refreshed = await client.auth.refreshSession();
          if (refreshed.session != null) {
            _session = refreshed.session;
            _user = refreshed.user;
            _needsEmailVerification = false;
            _setLoading(false);
            notifyListeners();
            return true;
          }
        } catch (_) {}
      }

      // 3. If credentials provided, sign in directly to create session
      if (email != null &&
          password != null &&
          email.isNotEmpty &&
          password.isNotEmpty) {
        final result = await _authService.signIn(
          email: email,
          password: password,
        );
        if (result.success && (result.session != null || result.user != null)) {
          _session = result.session;
          _user = result.user;
          _needsEmailVerification = false;
          _setLoading(false);
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      debugPrint('refreshOrCheckSession error.');
    }
    _setLoading(false);
    return false;
  }

  Future<AuthResult> sendPasswordResetEmail(
    String email, {
    String? redirectTo,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    final result = await _authService.sendPasswordResetEmail(
      email: email,
      redirectTo: redirectTo,
    );
    _errorMessage = result.errorMessage;
    _setLoading(false);
    return result;
  }

  Future<AuthResult> updatePassword(String newPassword) async {
    _setLoading(true);
    _errorMessage = null;
    final result = await _authService.updatePassword(newPassword: newPassword);
    if (result.success) {
      _isPasswordRecovery = false;
    }
    _errorMessage = result.errorMessage;
    _setLoading(false);
    return result;
  }

  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _authService.signOut();
      _user = null;
      _session = null;
      _needsEmailVerification = false;
      _pendingVerificationEmail = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
