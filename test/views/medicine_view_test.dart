import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:medicine_reminder/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_reminder/core/components/views/medicine/medicine_view.dart';
import 'package:medicine_reminder/core/components/views/medicine/medicine_history_view.dart';
import 'package:medicine_reminder/core/components/views/medicine/medicine_refills_view.dart';
import 'package:medicine_reminder/core/components/views/medicine/widgets/add_medicine_sheet.dart';
import 'package:medicine_reminder/core/components/views/medicine/widgets/medicine_card.dart';
import 'package:medicine_reminder/core/models/medication.dart';
import 'package:medicine_reminder/core/services/auth_service.dart';
import 'package:medicine_reminder/core/services/medicine_store.dart';
import 'package:medicine_reminder/providers/auth_provider.dart';
import 'package:medicine_reminder/providers/medicine_reminder_provider.dart';
import 'package:medicine_reminder/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/medicine_fakes.dart';

class MockViewAuthService extends AuthService {
  @override
  Stream<AuthState>? get onAuthStateChange => null;
}

void main() {
  late MedicineReminderProvider provider;
  final captureKey = GlobalKey();
  var initialized = false;
  setUp(() {
    initialized = false;
  });
  Future<void> initialize() async {
    if (initialized) return;
    initialized = true;
    provider = MedicineReminderProvider(
      store: MemoryMedicineStore(),
      notifications: FakeNotifications(),
      clock: () => DateTime(2026, 10, 17, 10),
    );
    provider.bindUser('test');
    await provider.ready;
  }

  tearDown(() {
    if (initialized) provider.dispose();
  });
  Future<void> mount(
    WidgetTester tester, {
    Widget child = const MedicineView(),
    double scale = 1,
    bool dark = false,
  }) async {
    await initialize();
    if (const bool.fromEnvironment('CAPTURE_MEDICINE_UI')) {
      await tester.runAsync(() async {
        final fonts =
            '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts';
        final regular = FontLoader('Roboto')
          ..addFont(
            File('$fonts/roboto-regular.ttf')
                .readAsBytes()
                .then((b) => ByteData.sublistView(b)),
          );
        final icons = FontLoader('MaterialIcons')
          ..addFont(
            File('$fonts/materialicons-regular.otf')
                .readAsBytes()
                .then((b) => ByteData.sublistView(b)),
          );
        await regular.load();
        await icons.load();
      });
    }
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
          ChangeNotifierProvider<AuthProvider>(
            create: (_) => AuthProvider(authService: MockViewAuthService()),
          ),
          ChangeNotifierProvider<MedicineReminderProvider>.value(
            value: provider,
          ),
        ],
        child: RepaintBoundary(
          key: captureKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
            builder: (_, child) => MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(body: child),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'new accounts have an accurate empty state without sample medicines',
    (tester) async {
      await mount(tester);
      await tester.scrollUntilVisible(
        find.text('Add your first medicine'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Add your first medicine'), findsOneWidget);
      expect(find.byType(MedicineCard), findsNothing);
      expect(find.text('0 of 0 doses recorded as taken'), findsOneWidget);
    },
  );
  testWidgets('dose action saves per-dose state and can be undone', (
    tester,
  ) async {
    await initialize();
    await provider.addMedication(testMedication(times: [480]));
    await mount(tester);
    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, 'Taken'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -100));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Taken'));
    await tester.pumpAndSettle();
    expect(provider.takenCount, 1);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(provider.takenCount, 0);
    expect(provider.events, hasLength(2));
  });
  testWidgets(
    'form validates name and quantity before saving a real schedule',
    (tester) async {
      await mount(tester, child: const AddMedicineSheet());
      await tester.enterText(
        find.byKey(const Key('medicine-name')),
        'My medicine',
      );
      await tester.enterText(find.byKey(const Key('dose-amount')), '0');
      await tester.ensureVisible(find.byKey(const Key('save-medicine')));
      await tester.tap(find.byKey(const Key('save-medicine')));
      await tester.pumpAndSettle();
      expect(provider.medications, isEmpty);
      await tester.ensureVisible(find.byKey(const Key('dose-amount')));
      expect(find.text('Enter a positive quantity'), findsOneWidget);
    },
  );
  testWidgets('form supports multiple times, weekdays and schedule preview', (
    tester,
  ) async {
    await mount(tester, child: const AddMedicineSheet());
    await tester.ensureVisible(find.text('Add time'));
    await tester.tap(find.text('Add time'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Mon'));
    await tester.tap(find.text('Mon'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Mon'))
          .selected,
      isFalse,
    );
    await tester.ensureVisible(find.text('Next 7 days'));
    expect(find.text('Next 7 days'), findsOneWidget);
  });
  testWidgets('dose details show instructions and saved action time', (
    tester,
  ) async {
    await initialize();
    await provider.addMedication(testMedication(times: [480]));
    await provider.act(provider.todayDoses.first, DoseAction.skipped);
    await mount(tester);
    await tester.scrollUntilVisible(
      find.byType(MedicineCard),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MedicineCard));
    await tester.pumpAndSettle();
    expect(find.text('Strength: 500 mg'), findsOneWidget);
    expect(find.textContaining('Recorded 2026-10-17'), findsOneWidget);
  });
  testWidgets('small screen and large text keep dose controls usable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await initialize();
    await provider.addMedication(
      testMedication(times: [480, 1200], name: 'A medicine with a longer name'),
    );
    await mount(tester, scale: 1.6);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.byKey(ValueKey(provider.todayDoses.first.id)),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('medicine form saves and returns to Today', (tester) async {
    await mount(tester);
    await tester.tap(find.text('Add medicine'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('medicine-name')),
      'My saved medicine',
    );
    await tester.enterText(find.byKey(const Key('dose-amount')), '0.5');
    await tester.ensureVisible(find.byKey(const Key('save-medicine')));
    await tester.tap(find.byKey(const Key('save-medicine')));
    await tester.pumpAndSettle();
    expect(find.byType(AddMedicineSheet), findsNothing);
    expect(provider.medications.single.name, 'My saved medicine');
    expect(provider.medications.single.amount, '0.5');
    expect(find.text('Medicine and schedule saved.'), findsOneWidget);
  });
  Future<void> medicineOptions(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('Medicines'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Medicines'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Medicines'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byTooltip('Medicine options'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byTooltip('Medicine options'));
    await tester.tap(find.byTooltip('Medicine options'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'edit preloads the plan, preserves timezone and saves changed fields and dates',
    (tester) async {
      await initialize();
      final medicine = testMedication(
        name: 'Original',
        amount: '0.5',
        zone: 'UTC',
        days: [1, 3, 5],
        end: DateTime(2026, 12, 31),
      );
      await provider.addMedication(medicine);
      await mount(tester);
      await medicineOptions(tester);
      await tester.tap(find.text('Edit medicine'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('medicine-name')))
            .controller!
            .text,
        'Original',
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('dose-amount')))
            .controller!
            .text,
        '0.5',
      );
      expect(find.textContaining('Effective on save'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('medicine-name')), 'Renamed');
      await tester.enterText(find.byKey(const Key('dose-amount')), '2');
      await tester.ensureVisible(find.text('Mon'));
      await tester.tap(find.text('Mon'));
      await tester.ensureVisible(find.byTooltip('Remove end date'));
      await tester.tap(find.byTooltip('Remove end date'));
      await tester.ensureVisible(find.byKey(const Key('save-medicine')));
      await tester.tap(find.byKey(const Key('save-medicine')));
      await tester.pumpAndSettle();
      expect(find.byType(AddMedicineSheet), findsNothing);
      final updated = provider.medications.single;
      expect(updated.name, 'Renamed');
      expect(updated.amount, '2');
      expect(updated.timezone, 'UTC');
      expect(updated.minutes, medicine.minutes);
      expect(updated.weekdays, [3, 5]);
      expect(updated.endsOn, isNull);
      expect(updated.revision, 2);
    },
  );

  testWidgets('failed edit keeps draft open and supports retry', (
    tester,
  ) async {
    await initialize();
    await provider.addMedication(testMedication());
    await mount(tester);
    await medicineOptions(tester);
    await tester.tap(find.text('Edit medicine'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('medicine-name')),
      'Retry draft',
    );
    (provider.store as MemoryMedicineStore).failWrites = true;
    await tester.ensureVisible(find.byKey(const Key('save-medicine')));
    await tester.tap(find.byKey(const Key('save-medicine')));
    await tester.pumpAndSettle();
    expect(find.byType(AddMedicineSheet), findsOneWidget);
    expect(find.textContaining('Could not save this change'), findsWidgets);
    expect(provider.medications.single.revision, 1);
    (provider.store as MemoryMedicineStore).failWrites = false;
    await tester.ensureVisible(find.byKey(const Key('save-medicine')));
    await tester.tap(find.byKey(const Key('save-medicine')));
    await tester.pumpAndSettle();
    expect(find.byType(AddMedicineSheet), findsNothing);
    expect(provider.medications.single.name, 'Retry draft');
  });

  testWidgets(
    'archive keeps original dose details accessible without edit controls',
    (tester) async {
      await initialize();
      await provider.addMedication(testMedication(times: [480]));
      await provider.act(provider.todayDoses.first, DoseAction.taken);
      await mount(tester);
      await medicineOptions(tester);
      await tester.tap(find.text('Archive medicine'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('recorded doses stay available'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Archive medicine'));
      await tester.pumpAndSettle();
      expect(provider.medications.single.archived, isTrue);
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Archived'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Archived'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Medicine options'));
      await tester.tap(find.byTooltip('Medicine options'));
      await tester.pumpAndSettle();
      expect(find.text('Edit medicine'), findsNothing);
      expect(find.text('Resume reminders'), findsNothing);
      await tester.tap(find.text('View recorded doses'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test medicine · 1 tablet'));
      await tester.pumpAndSettle();
      expect(find.text('Strength: 500 mg'), findsOneWidget);
      expect(
        find.text('Previous schedule · reminders canceled'),
        findsOneWidget,
      );
      expect(find.text('Undo'), findsOneWidget);
    },
  );

  testWidgets('edit and archive controls fit small screen with enlarged text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await initialize();
    await provider.addMedication(
      testMedication(name: 'A long medicine name', times: [480]),
    );
    await mount(tester, scale: 1.6);
    await medicineOptions(tester);
    await tester.tap(find.text('Edit medicine'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('save-medicine')));
    expect(tester.takeException(), isNull);
    expect(find.text('Save changes'), findsOneWidget);
  });

  testWidgets(
    'history shows due recording summary, filters and original details',
    (tester) async {
      await initialize();
      await provider.addMedication(testMedication(times: [480, 540, 1200]));
      await provider.act(provider.todayDoses[0], DoseAction.taken);
      await provider.act(provider.todayDoses[1], DoseAction.skipped);
      await provider.act(
        provider.todayDoses[2],
        DoseAction.taken,
      ); // Future dose excluded.
      await mount(tester, child: const MedicineHistoryView());
      expect(
        find.text('1 of 2 eligible due doses recorded as taken'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Skipped'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Skipped'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.widgetWithText(ListTile, 'Test medicine · 1 tablet'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Skipped'), findsWidgets);
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Taken'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Taken'));
      await tester.pumpAndSettle();
      final record = find.widgetWithText(ListTile, 'Test medicine · 1 tablet');
      await tester.scrollUntilVisible(
        record,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(record);
      await tester.tap(record);
      await tester.pumpAndSettle();
      expect(find.text('Strength: 500 mg'), findsOneWidget);
      expect(find.text('Snooze 15 min'), findsNothing);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(
        provider.takenCount,
        1,
      ); // Only the early future record remains taken.
    },
  );

  testWidgets(
    'history shows unknown recording coverage without inventing missed doses',
    (tester) async {
      await initialize();
      await provider.addMedication(testMedication(times: [480]));
      await mount(tester, child: const MedicineHistoryView());
      expect(
        find.text('0 of 0 eligible due doses recorded as taken'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('history-gaps')), findsOneWidget);
      expect(find.textContaining('definitely missed'), findsNothing);
    },
  );

  Future<void> saveStockForm(
    WidgetTester tester,
    String quantity, {
    String? threshold,
  }) async {
    await tester.enterText(find.byKey(const Key('stock-quantity')), quantity);
    if (threshold != null) {
      await tester.enterText(
        find.byKey(const Key('stock-threshold')),
        threshold,
      );
    }
    await tester.ensureVisible(find.byKey(const Key('save-stock')));
    await tester.tap(find.byKey(const Key('save-stock')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'refill flow sets baseline, adds purchase and reconciles a physical count',
    (tester) async {
      await initialize();
      await provider.addMedication(testMedication(amount: '0.5'));
      await mount(tester, child: const MedicineRefillsView());
      expect(find.text('Unknown stock'), findsOneWidget);
      await tester.tap(find.text('Test medicine'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set stock'));
      await tester.pumpAndSettle();
      await saveStockForm(tester, '10', threshold: '2');
      expect(find.text('10 tablet'), findsOneWidget);
      await provider.act(provider.todayDoses.first, DoseAction.taken);
      await tester.pumpAndSettle();
      expect(find.text('9.5 tablet'), findsOneWidget);
      await tester.tap(find.text('Add refill'));
      await tester.pumpAndSettle();
      await saveStockForm(tester, '3');
      expect(find.text('12.5 tablet'), findsOneWidget);
      final eventCount = provider.events.length;
      await tester.tap(find.text('Reconcile stock'));
      await tester.pumpAndSettle();
      await saveStockForm(tester, '4');
      expect(find.text('4 tablet'), findsOneWidget);
      expect(provider.events, hasLength(eventCount));
      expect(provider.stockLedger('med-1'), hasLength(4));
    },
  );

  testWidgets(
    'negative stock requests correction and failed writes retain the draft',
    (tester) async {
      await initialize();
      await provider.addMedication(testMedication());
      await provider.startStock(
        provider.medications.single,
        '0',
        '2',
        requestId: 'initial',
      );
      await provider.act(provider.todayDoses.first, DoseAction.taken);
      await mount(tester, child: const MedicineStockView(medicineId: 'med-1'));
      expect(find.text('Needs correction'), findsOneWidget);
      expect(find.text('-1 tablet'), findsOneWidget);
      await tester.ensureVisible(find.text('Reconcile stock'));
      await tester.tap(find.text('Reconcile stock'));
      await tester.pumpAndSettle();
      (provider.store as MemoryMedicineStore).failWrites = true;
      await saveStockForm(tester, '5');
      expect(find.textContaining('Could not save this change'), findsOneWidget);
      expect(provider.stockBalance(provider.stockFor('med-1')!.id), -10000);
      (provider.store as MemoryMedicineStore).failWrites = false;
      await tester.ensureVisible(find.byKey(const Key('save-stock')));
      await tester.tap(find.byKey(const Key('save-stock')));
      await tester.pumpAndSettle();
      expect(provider.stockBalance(provider.stockFor('med-1')!.id), 50000);
      await tester.drag(find.byType(ListView).first, const Offset(0, 500));
      await tester.pumpAndSettle();
      expect(find.text('5 tablet'), findsOneWidget);
    },
  );

  testWidgets(
    'archived stock remains visible with ledger and without mutation controls',
    (tester) async {
      await initialize();
      await provider.addMedication(testMedication());
      await provider.startStock(
        provider.medications.single,
        '10',
        '2',
        requestId: 'initial',
      );
      await provider.archiveMedication(provider.medications.single);
      await mount(tester, child: const MedicineRefillsView());
      expect(find.text('Test medicine'), findsNothing);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test medicine'));
      await tester.pumpAndSettle();
      expect(find.text('Archived · Stock available'), findsOneWidget);
      expect(find.text('Add refill'), findsNothing);
      expect(find.textContaining('Initial stock'), findsWidgets);
    },
  );

  testWidgets('Today opens History and Refills through visible navigation', (
    tester,
  ) async {
    await mount(tester);
    await tester.ensureVisible(find.byKey(const Key('open-history')));
    await tester.tap(find.byKey(const Key('open-history')));
    await tester.pumpAndSettle();
    expect(find.byType(MedicineHistoryView), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('open-refills')));
    await tester.tap(find.byKey(const Key('open-refills')));
    await tester.pumpAndSettle();
    expect(find.byType(MedicineRefillsView), findsOneWidget);
  });

  testWidgets(
    'history and stock forms fit small screens and large text in both themes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await initialize();
      await provider.addMedication(
        testMedication(name: 'Medicine with a long name'),
      );
      for (final dark in [false, true]) {
        await mount(
          tester,
          child: const MedicineHistoryView(),
          scale: 1.6,
          dark: dark,
        );
        await tester.scrollUntilVisible(
          find.text('Dose records'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
        await mount(
          tester,
          child: const MedicineStockView(medicineId: 'med-1'),
          scale: 1.6,
          dark: dark,
        );
        await tester.ensureVisible(find.text('Set stock'));
        await tester.tap(find.text('Set stock'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('save-stock')));
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byTooltip('Close'));
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets('light and dark Today screens render without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await initialize();
    await provider.addMedication(testMedication(times: [480, 1200]));
    for (final dark in [false, true]) {
      await mount(tester, dark: dark);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_MEDICINE_UI')) {
        final boundary = captureKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('build/medicine-today-${dark ? 'dark' : 'light'}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
  });
}
