import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_reminder/core/components/views/auth/forgot_password_view.dart';
import 'package:medicine_reminder/core/services/auth_service.dart';
import 'package:medicine_reminder/providers/app_providers.dart';
import 'package:medicine_reminder/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class ResetMockAuthService extends AuthService {
  String? lastResetEmail;

  @override
  Future<AuthResult> sendPasswordResetEmail({
    required String email,
    String? redirectTo,
  }) async {
    lastResetEmail = email;
    return AuthResult.success();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('ForgotPasswordView sends password recovery email successfully', (
    tester,
  ) async {
    final mockService = ResetMockAuthService();
    final authProvider = AuthProvider(authService: mockService);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ...AppProviders.providers.where(
            (p) => p is! ChangeNotifierProvider<AuthProvider>,
          ),
        ],
        child: const MaterialApp(home: ForgotPasswordView()),
      ),
    );

    await tester.pumpAndSettle();

    // Verify UI title and elements
    expect(find.text('Reset password'), findsOneWidget);
    expect(find.text('Send reset link'), findsOneWidget);

    // Enter email
    await tester.enterText(find.byType(TextFormField), 'test@example.com');
    await tester.pumpAndSettle();

    // Tap send reset link
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();

    // Verify service was called
    expect(mockService.lastResetEmail, 'test@example.com');
    // Verify success banner is shown
    expect(find.text('Reset link sent'), findsOneWidget);
  });
}
