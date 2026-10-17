import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_reminder/main.dart';
import 'package:medicine_reminder/providers/app_providers.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:medicine_reminder/core/routes/app_routes.dart';
import 'package:medicine_reminder/core/services/medicine_store.dart';
import 'support/medicine_fakes.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppRoutes.router.go(AppRoutes.initial);
  });
  testWidgets(
      'offline guest can create a first medicine and return after restart',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MemoryMedicineStore();
    Future<void> launch() async {
      await tester.pumpWidget(MultiProvider(
          providers: AppProviders.create(
            medicineStore: store,
            medicineNotifications: FakeNotifications(),
          ),
          child: const MyApp()));
      await tester.pumpAndSettle();
    }

    AppRoutes.router.go(AppRoutes.getStarted);
    await launch();
    await tester.scrollUntilVisible(find.text('Continue as guest'), 150);
    await tester.tap(find.text('Continue as guest'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue as guest'));
    await tester.pumpAndSettle();
    expect(find.text('Local guest'), findsOneWidget);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('medicine-name')), 'Offline demo');
    await tester.enterText(find.byKey(const Key('dose-amount')), '0.5');
    await tester.ensureVisible(find.byKey(const Key('save-medicine')));
    await tester.tap(find.byKey(const Key('save-medicine')));
    await tester.pumpAndSettle();
    expect(store.records.values.single.medications.single.name, 'Offline demo');
    await tester.pumpWidget(const SizedBox.shrink());
    AppRoutes.router.go(AppRoutes.authGate);
    await launch();
    expect(find.text('Local guest'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Offline demo'), 150,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Offline demo'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
  });
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
    expect(find.text('Your medicines, on your device'), findsOneWidget);
    expect(find.text('Continue as guest'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.text('Sign in to an existing account'), 150);
    expect(find.text('Sign in to an existing account'), findsOneWidget);

    // Tapping 'Log in' navigates to LoginView
    await tester.tap(find.text('Sign in to an existing account'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Medicine Assistant'), findsOneWidget);

    // The existing account onboarding remains reachable from login.
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Less to remember'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
  });
}
