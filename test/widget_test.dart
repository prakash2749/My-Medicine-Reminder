import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_reminder/main.dart';
import 'package:medicine_reminder/providers/app_providers.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('App smoke test loads Notify Splash and Get Started screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(providers: AppProviders.providers, child: const MyApp()),
    );

    // Initial frame shows Splash
    expect(find.text('Notify'), findsOneWidget);

    // Pump past splash timer & settle
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    // Verify presence of Get Started screen elements
    expect(find.textContaining('Less to remember'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);

    // Tapping 'Log in' navigates to LoginView
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Medicine Assistant'), findsOneWidget);

    // Tapping 'Create account' on LoginView redirects back to Get Started screen
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Less to remember'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
  });
}
