import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_reminder/main.dart';
import 'package:medicine_reminder/providers/app_providers.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('App smoke test loads Notify Splash and Login screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(providers: AppProviders.providers, child: const MyApp()),
    );

    // Initial frame shows Splash
    expect(find.text('Notify'), findsOneWidget);

    // Pump past the splash screen timer (2 seconds)
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // Verify presence of Notify Login screen brand and form elements
    expect(find.text('Notify'), findsOneWidget);
    expect(find.text('Medicine Assistant'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
  });
}
