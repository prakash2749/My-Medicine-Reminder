import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_reminder/core/services/auth_service.dart';
import 'package:medicine_reminder/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockTestAuthService extends AuthService {
  User? _mockCurrentUser;
  bool shouldFail = false;
  String? failureMessage;
  bool mockNeedsEmailVerification = false;

  @override
  User? get currentUser => _mockCurrentUser;

  @override
  Stream<AuthState>? get onAuthStateChange => null;

  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    if (shouldFail) {
      return AuthResult.failure(failureMessage ?? 'Invalid credentials');
    }
    _mockCurrentUser = User(
      id: 'mock-user-1',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      email: email,
    );
    return AuthResult.success(user: _mockCurrentUser);
  }

  @override
  Future<AuthResult> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    if (shouldFail) {
      return AuthResult.failure(failureMessage ?? 'Sign up failed');
    }
    _mockCurrentUser = User(
      id: 'mock-user-2',
      appMetadata: {},
      userMetadata: {'full_name': fullName},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      email: email,
    );
    return AuthResult.success(
      user: _mockCurrentUser,
      needsEmailVerification: mockNeedsEmailVerification,
    );
  }

  @override
  Future<AuthResult> sendPasswordResetEmail({
    required String email,
    String? redirectTo,
  }) async {
    if (shouldFail) {
      return AuthResult.failure(failureMessage ?? 'Reset failed');
    }
    return AuthResult.success();
  }

  @override
  Future<AuthResult> updatePassword({required String newPassword}) async {
    if (shouldFail) {
      return AuthResult.failure(failureMessage ?? 'Update password failed');
    }
    return AuthResult.success(user: _mockCurrentUser);
  }

  @override
  Future<void> signOut() async {
    _mockCurrentUser = null;
  }
}

void main() {
  group('AuthProvider', () {
    late MockTestAuthService authService;
    late AuthProvider authProvider;

    setUp(() {
      authService = MockTestAuthService();
      authProvider = AuthProvider(authService: authService);
    });

    test('initial state is unauthenticated and not loading', () {
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.isLoading, isFalse);
      expect(authProvider.errorMessage, isNull);
      expect(authProvider.user, isNull);
    });

    test('signIn succeeds and sets user', () async {
      final result = await authProvider.signIn(
        email: 'test@example.com',
        password: 'password123',
      );

      expect(result.success, isTrue);
      expect(authProvider.isAuthenticated, isTrue);
      expect(authProvider.user?.email, 'test@example.com');
      expect(authProvider.errorMessage, isNull);
      expect(authProvider.isLoading, isFalse);
    });

    test(
      'signIn failure sets errorMessage and user remains unauthenticated',
      () async {
        authService.shouldFail = true;
        authService.failureMessage = 'Invalid email or password';

        final result = await authProvider.signIn(
          email: 'wrong@example.com',
          password: 'wrongpassword',
        );

        expect(result.success, isFalse);
        expect(authProvider.isAuthenticated, isFalse);
        expect(authProvider.user, isNull);
        expect(authProvider.errorMessage, 'Invalid email or password');
        expect(authProvider.isLoading, isFalse);
      },
    );

    test('signUp handles email verification requirement', () async {
      authService.mockNeedsEmailVerification = true;

      final result = await authProvider.signUp(
        email: 'newuser@example.com',
        password: 'password123',
        fullName: 'New User',
      );

      expect(result.success, isTrue);
      expect(authProvider.needsEmailVerification, isTrue);
      expect(authProvider.pendingVerificationEmail, 'newuser@example.com');
    });

    test('signOut clears user and authentication state', () async {
      // First sign in
      await authProvider.signIn(
        email: 'test@example.com',
        password: 'password123',
      );
      expect(authProvider.isAuthenticated, isTrue);

      // Sign out
      await authProvider.signOut();
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.user, isNull);
      expect(authProvider.isLoading, isFalse);
    });

    test('sendPasswordResetEmail success and failure handling', () async {
      final success = await authProvider.sendPasswordResetEmail(
        'test@example.com',
      );
      expect(success.success, isTrue);
      expect(authProvider.errorMessage, isNull);

      authService.shouldFail = true;
      authService.failureMessage = 'Network error';
      final fail = await authProvider.sendPasswordResetEmail(
        'test@example.com',
      );
      expect(fail.success, isFalse);
      expect(authProvider.errorMessage, 'Network error');
    });

    test('clearError resets error message', () async {
      authService.shouldFail = true;
      authService.failureMessage = 'Sample error';
      await authProvider.signIn(email: 'a@b.com', password: '123');
      expect(authProvider.errorMessage, 'Sample error');

      authProvider.clearError();
      expect(authProvider.errorMessage, isNull);
    });
  });
}
