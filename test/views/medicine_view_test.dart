import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_reminder/core/components/views/medicine/medicine_view.dart';
import 'package:medicine_reminder/core/components/views/medicine/widgets/medicine_card.dart';
import 'package:medicine_reminder/core/services/auth_service.dart';
import 'package:medicine_reminder/providers/auth_provider.dart';
import 'package:medicine_reminder/providers/medicine_reminder_provider.dart';
import 'package:medicine_reminder/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockViewAuthService extends AuthService {
  @override
  Stream<AuthState>? get onAuthStateChange => null;
}

Widget createTestMedicineView() {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(authService: MockViewAuthService()),
      ),
      ChangeNotifierProvider<MedicineReminderProvider>(
        create: (_) => MedicineReminderProvider(),
      ),
    ],
    child: const MaterialApp(home: MedicineView()),
  );
}

void main() {
  group('MedicineView Widget Tests', () {
    testWidgets('renders adherence header and default reminder cards', (
      tester,
    ) async {
      await tester.pumpWidget(createTestMedicineView());
      await tester.pumpAndSettle();

      // Check header stats
      expect(find.text('Daily Adherence'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);

      // Check initial sample medicine items appear in MedicineCard
      expect(find.widgetWithText(MedicineCard, 'Amoxicillin'), findsOneWidget);
      expect(find.widgetWithText(MedicineCard, 'Metformin'), findsOneWidget);
      expect(
        find.widgetWithText(MedicineCard, 'Vitamin D3 & Calcium'),
        findsOneWidget,
      );
    });

    testWidgets('search field filters list of reminders', (tester) async {
      await tester.pumpWidget(createTestMedicineView());
      await tester.pumpAndSettle();

      // Enter search query
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'Metformin');
      await tester.pumpAndSettle();

      // Only Metformin card should remain
      expect(find.widgetWithText(MedicineCard, 'Metformin'), findsOneWidget);
      expect(find.widgetWithText(MedicineCard, 'Amoxicillin'), findsNothing);
      expect(
        find.widgetWithText(MedicineCard, 'Vitamin D3 & Calcium'),
        findsNothing,
      );
    });

    testWidgets('tapping filter chips toggles active filter', (tester) async {
      await tester.pumpWidget(createTestMedicineView());
      await tester.pumpAndSettle();

      // Tap 'Pending' filter chip
      final pendingChip = find.widgetWithText(InkWell, 'Pending');
      expect(pendingChip, findsOneWidget);
      await tester.tap(pendingChip);
      await tester.pumpAndSettle();

      // Amoxicillin is 'Taken' by default, so it shouldn't show in Pending
      expect(find.widgetWithText(MedicineCard, 'Amoxicillin'), findsNothing);
      expect(find.widgetWithText(MedicineCard, 'Metformin'), findsOneWidget);

      // Tap 'Taken' filter chip
      final takenChip = find.widgetWithText(InkWell, 'Taken');
      expect(takenChip, findsOneWidget);
      await tester.tap(takenChip);
      await tester.pumpAndSettle();

      // Only taken reminders show
      expect(find.widgetWithText(MedicineCard, 'Amoxicillin'), findsOneWidget);
      expect(find.widgetWithText(MedicineCard, 'Metformin'), findsNothing);
    });
  });
}
