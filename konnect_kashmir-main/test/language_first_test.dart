import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/l10n/l10n.dart';
import 'package:konnect_kashmir/providers/auth_provider.dart';
import 'package:konnect_kashmir/providers/locale_provider.dart';
import 'package:konnect_kashmir/screens/splash_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app as it starts: the splash, with the language and sign-in state it finds.
Widget _app(LocaleProvider locale, AuthProvider auth) => MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<LocaleProvider>.value(value: locale),
      ],
      child: Consumer<LocaleProvider>(
        builder: (_, l, __) => MaterialApp(
          locale: l.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const SplashScreen(),
        ),
      ),
    );

/// Lets the splash play and hand over to the next screen.
Future<void> _pastSplash(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 2500));
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  testWidgets('first launch: the language comes first, then the sign-in in that language',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final locale = await LocaleProvider.load();
    expect(locale.hasChosen, isFalse);

    await tester.pumpWidget(_app(locale, AuthProvider()));
    await _pastSplash(tester);

    // The picker, in English, with every language's own name.
    expect(find.text('Choose your language'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('اردو'), findsOneWidget);
    expect(find.text('हिन्दी'), findsOneWidget);
    expect(find.text('Sign In / Register'), findsNothing);

    // It cannot be skipped: the sign-in is not reachable around it.
    await tester.tap(find.text('اردو'));
    await _settle(tester);
    await tester.tap(find.text('Continue'));
    await _settle(tester);

    // The sign-in is already in Urdu, and the picker is gone.
    final ur = lookupAppLocalizations(const Locale('ur'));
    expect(find.text(ur.signInRegister), findsOneWidget);
    expect(find.text(ur.mobileNumber), findsOneWidget);
    expect(find.text('Choose your language'), findsNothing);
    expect(locale.locale.languageCode, 'ur');
    expect(locale.hasChosen, isTrue);
    expect((await SharedPreferences.getInstance()).getBool('app_locale_chosen'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('first launch: Hindi too, and English as it is', (tester) async {
    for (final (code, tile) in [('hi', 'हिन्दी'), ('en', 'English')]) {
      SharedPreferences.setMockInitialValues({});
      final locale = await LocaleProvider.load();
      await tester.pumpWidget(_app(locale, AuthProvider()));
      await _pastSplash(tester);

      // (English has its name twice: the language and its own name.)
      await tester.tap(find.text(tile).first);
      await _settle(tester);
      await tester.tap(find.text('Continue'));
      await _settle(tester);

      final l = lookupAppLocalizations(Locale(code));
      expect(find.text(l.signInRegister), findsOneWidget, reason: code);
      expect(find.text('Choose your language'), findsNothing, reason: code);
      expect(locale.locale.languageCode, code);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('a language already chosen: straight to the sign-in in it, no picker',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'app_locale': 'hi',
      'app_locale_chosen': true,
    });
    final locale = await LocaleProvider.load();
    expect(locale.hasChosen, isTrue);

    await tester.pumpWidget(_app(locale, AuthProvider()));
    await _pastSplash(tester);

    expect(find.text('Choose your language'), findsNothing);
    expect(find.text(lookupAppLocalizations(const Locale('hi')).signInRegister),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the sign-in stays left to right in Urdu', (tester) async {
    SharedPreferences.setMockInitialValues({
      'app_locale': 'ur',
      'app_locale_chosen': true,
    });
    final locale = await LocaleProvider.load();
    await tester.pumpWidget(_app(locale, AuthProvider()));
    await _pastSplash(tester);

    final ur = lookupAppLocalizations(const Locale('ur'));
    final ctx = tester.element(find.text(ur.signInRegister));
    expect(Directionality.of(ctx), TextDirection.ltr);
  });
}
