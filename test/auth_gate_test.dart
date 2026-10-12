import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_reminder/core/routes/auth_gate.dart';
import 'package:medicine_reminder/core/services/auth_service.dart';
import 'package:medicine_reminder/providers/app_providers.dart';
import 'package:medicine_reminder/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeAuthService extends AuthService {
  User? _mockUser;

  @override
  User? get currentUser => _mockUser;

  @override
  bool get isAuthenticated => _mockUser != null;

  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    _mockUser = User(
      id: 'test-user',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      email: email,
    );
    final mockSession = Session(
      accessToken: 'test-token',
      tokenType: 'bearer',
      user: _mockUser!,
    );
    return AuthResult.success(user: _mockUser, session: mockSession);
  }
}

void main() {
  testWidgets('AuthGate renders LoginScreen when user is unauthenticated', (
    tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: AppProviders.providers,
        child: const MaterialApp(home: AuthGate()),
      ),
    );

    await tester.pumpAndSettle();

    // Verify LoginScreen is displayed
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('AuthGate renders HomeScreen when user signs in', (tester) async {
    final fakeService = FakeAuthService();
    final authProvider = AuthProvider(authService: fakeService);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ...AppProviders.providers.where(
            (p) => p is! ChangeNotifierProvider<AuthProvider>,
          ),
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ],
        child: const MaterialApp(home: AuthGate()),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    // Simulate successful sign-in
    await authProvider.signIn(
      email: 'user@example.com',
      password: 'password123',
    );
    await tester.pumpAndSettle();

    // Verify HomeScreen is now rendered
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets(
    'AuthGate transitions to HomeScreen when refreshOrCheckSession succeeds',
    (tester) async {
      final fakeService = FakeAuthService();
      final authProvider = AuthProvider(authService: fakeService);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ...AppProviders.providers.where(
              (p) => p is! ChangeNotifierProvider<AuthProvider>,
            ),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: const MaterialApp(home: AuthGate()),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);

      // Verify email verification session check
      final verified = await authProvider.refreshOrCheckSession(
        email: 'user@example.com',
        password: 'password123',
      );
      expect(verified, isTrue);

      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    },
  );
}
