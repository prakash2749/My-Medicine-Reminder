import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_reminder/core/components/views/policy_view.dart';
import 'package:medicine_reminder/core/components/views/auth/onboarding/personal_info_step_view.dart';
import 'package:medicine_reminder/core/l10n/app_copy.dart';
import 'package:medicine_reminder/core/models/policy_content.dart';
import 'package:medicine_reminder/providers/signup_provider.dart';
import 'package:provider/provider.dart';

class _PolicyBundle extends CachingAssetBundle {
  final String text;
  bool fail = false;
  _PolicyBundle(this.text);
  @override
  Future<String> loadString(String key, {bool cache = true}) {
    if (key != PolicyContent.assetPath) {
      return rootBundle.loadString(key, cache: cache);
    }
    if (fail) return Future.error(StateError('PRIVATE LOAD DETAILS'));
    return SynchronousFuture(text);
  }

  @override
  Future<ByteData> load(String key) {
    if (key != PolicyContent.assetPath) return rootBundle.load(key);
    if (fail) return Future.error(StateError('PRIVATE LOAD DETAILS'));
    return rootBundle.load(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String bundledText;
  setUpAll(() async {
    bundledText = await rootBundle.loadString(PolicyContent.assetPath);
  });

  Future<void> showPolicy(WidgetTester tester,
      {String language = 'en', AssetBundle? bundle, double scale = 1}) async {
    await tester.pumpWidget(MaterialApp(
      locale: Locale(language),
      supportedLocales: const [Locale('en'), Locale('hi')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: DefaultAssetBundle(
          bundle: bundle ?? _PolicyBundle(bundledText),
          child: const PolicyView()),
    ));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  test('bundled notice covers remote accounts and local deletion honestly',
      () async {
    final text = await rootBundle.loadString(PolicyContent.assetPath);
    final content = PolicyContent.decode(text);
    expect(content.pages.keys, unorderedEquals(['privacy', 'support']));
    expect(content.revision, contains('draft'));
    final privacy = content.pages['privacy']!.sections;
    expect(privacy.singleWhere((s) => s.id == 'purpose').body['en'],
        contains('not a medical device'));
    final account =
        privacy.singleWhere((s) => s.id == 'optional-account').body['en']!;
    for (final field in [
      'Supabase',
      'date of birth',
      'routine',
      'contact',
      'password'
    ]) {
      expect(account, contains(field));
    }
    expect(
        privacy.singleWhere((s) => s.id == 'retention-and-deletion').body['en'],
        contains('does not delete a Supabase account'));
    final json = jsonDecode(text) as Map<String, dynamic>;
    json['schema'] = 2;
    expect(() => PolicyContent.decode(jsonEncode(json)), throwsFormatException);
    json['schema'] = 1;
    (json['pages']['privacy']['sections'][0]['body'] as Map).remove('hi');
    expect(() => PolicyContent.decode(jsonEncode(json)), throwsFormatException);
  });

  testWidgets('offline load failure is safe and retry opens bundled content',
      (tester) async {
    final bundle = _PolicyBundle(bundledText)..fail = true;
    await showPolicy(tester, bundle: bundle);
    expect(find.text('Could not open the offline notice. Please retry.'),
        findsOneWidget);
    expect(find.textContaining('PRIVATE LOAD'), findsNothing);
    bundle.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('Purpose and limits'), findsOneWidget);
    expect(find.text('Could not open the offline notice. Please retry.'),
        findsNothing);
  });

  testWidgets(
      'reading the notice preserves entered profile data and navigation',
      (tester) async {
    final signup = SignupProvider();
    addTearDown(signup.dispose);
    await tester.pumpWidget(DefaultAssetBundle(
        bundle: _PolicyBundle(bundledText),
        child: ChangeNotifierProvider<SignupProvider>.value(
            value: signup,
            child: const MaterialApp(home: PersonalInfoStepView()))));
    await tester.enterText(find.byType(TextField).first, 'Synthetic name');
    await tester.tap(find.byKey(const Key('privacy-support-link')));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('Purpose and limits'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Synthetic name'), findsOneWidget);
    expect(signup.name, 'Synthetic name');
    expect(signup.agreedToTerms, isFalse);
  });

  for (final language in ['en', 'hi']) {
    testWidgets('$language privacy and support scroll at narrow 200% text',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await showPolicy(tester, language: language, scale: 2);
      expect(find.text(translateCopy('Privacy and support', language)),
          findsOneWidget);
      final content = PolicyContent.decode(bundledText);
      for (final page in ['privacy', 'support']) {
        if (page == 'support') {
          await tester.tap(find.byKey(const ValueKey('policy-support')));
          await tester.pumpAndSettle();
        }
        final last = content.pages[page]!.sections.last.title[language]!;
        await tester.scrollUntilVisible(find.text(last), 400);
        await tester.pumpAndSettle();
        expect(find.text(last), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  }
}
