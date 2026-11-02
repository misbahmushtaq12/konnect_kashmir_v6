import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/l10n/l10n.dart';
import 'package:konnect_kashmir/widgets/force_ltr.dart';
import 'package:konnect_kashmir/widgets/expandable_text.dart';
import 'package:konnect_kashmir/screens/login_screen.dart';
import 'package:konnect_kashmir/screens/otp_ver.dart';
import 'package:konnect_kashmir/screens/language_screen.dart';
import 'package:konnect_kashmir/providers/locale_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Locale locale, Widget home) => MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );

void main() {
  layoutTests();
  expandableTests();
  testWidgets('Sign-in screen follows the chosen language but stays left-to-right (Urdu)',
      (tester) async {
    await tester.pumpWidget(_app(const Locale('ur'), const LoginScreen()));
    await tester.pump();

    final ur = lookupAppLocalizations(const Locale('ur'));
    expect(find.text(ur.signInRegister), findsOneWidget);
    expect(find.text('Sign In / Register'), findsNothing);
    final ctx = tester.element(find.text(ur.signInRegister));
    expect(Directionality.of(ctx), TextDirection.ltr);
  });

  testWidgets('Sign-in screen follows the chosen language (Hindi)', (tester) async {
    await tester.pumpWidget(_app(const Locale('hi'), const LoginScreen()));
    await tester.pump();

    expect(find.text('साइन इन / रजिस्टर'), findsOneWidget);
    expect(find.text('Sign In / Register'), findsNothing);
  });

  testWidgets('Sign-in screen is in English when English is chosen', (tester) async {
    await tester.pumpWidget(_app(const Locale('en'), const LoginScreen()));
    await tester.pump();

    expect(find.text('Sign In / Register'), findsOneWidget);
  });

  testWidgets('OTP screen follows the chosen language but stays left-to-right (Urdu)',
      (tester) async {
    await tester.pumpWidget(
        _app(const Locale('ur'), const OTPVerificationScreen(phoneNumber: '9999999999')));
    await tester.pump();

    final ur = lookupAppLocalizations(const Locale('ur'));
    expect(find.text(ur.otpVerification), findsOneWidget);
    expect(find.text('OTP Verification'), findsNothing);
    final ctx = tester.element(find.text(ur.otpVerification));
    expect(Directionality.of(ctx), TextDirection.ltr);
  });

  testWidgets('OTP screen follows the chosen language (Hindi)', (tester) async {
    await tester.pumpWidget(
        _app(const Locale('hi'), const OTPVerificationScreen(phoneNumber: '9999999999')));
    await tester.pump();

    expect(find.text(lookupAppLocalizations(const Locale('hi')).otpVerification),
        findsOneWidget);
    expect(find.text('OTP Verification'), findsNothing);
  });

  testWidgets('Other screens follow the chosen language (Urdu = RTL)',
      (tester) async {
    await tester.pumpWidget(_app(
        const Locale('ur'), Builder(builder: (c) => Text(c.l10n.navHome))));

    expect(find.text('ہوم'), findsOneWidget);
    final ctx = tester.element(find.text('ہوم'));
    expect(Directionality.of(ctx), TextDirection.rtl);
  });

  testWidgets('Other screens follow the chosen language (Hindi)',
      (tester) async {
    await tester.pumpWidget(_app(
        const Locale('hi'), Builder(builder: (c) => Text(c.l10n.navHome))));

    expect(find.text('होम'), findsOneWidget);
  });

  testWidgets('The first-run language picker is always English, even if Urdu was chosen',
      (tester) async {
    SharedPreferences.setMockInitialValues({'app_locale': 'ur'});
    final locale = await LocaleProvider.load();
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: locale,
      child: _app(const Locale('ur'), const LanguageScreen()),
    ));
    await tester.pump();

    expect(find.text('Choose your language'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    final ctx = tester.element(find.text('Choose your language'));
    expect(Directionality.of(ctx), TextDirection.ltr);
  });

  testWidgets('Language picker opened from Profile follows the app language',
      (tester) async {
    SharedPreferences.setMockInitialValues({'app_locale': 'ur'});
    final locale = await LocaleProvider.load();
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: locale,
      child: _app(const Locale('ur'), const LanguageScreen(isSettings: true)),
    ));
    await tester.pump();

    expect(find.text('Choose your language'), findsNothing);
    expect(find.text('اپنی زبان منتخب کریں'), findsOneWidget);
  });
}

void layoutTests() {
  testWidgets('Urdu text, but the layout stays left-to-right (nothing mirrors)',
      (tester) async {
    Directionality? seen;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ur'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => ForceLtr(child: child!),
      home: Builder(builder: (c) {
        seen = c.findAncestorWidgetOfExactType<Directionality>();
        return Row(children: [
          const Icon(Icons.home, key: Key('first')),
          Text(c.l10n.navHome, key: const Key('second')),
        ]);
      }),
    ));

    expect(find.text('ہوم'), findsOneWidget); // Urdu is still shown
    expect(seen!.textDirection, TextDirection.ltr);
    // The icon stays on the left of the label, as in English.
    expect(tester.getTopLeft(find.byKey(const Key('first'))).dx,
        lessThan(tester.getTopLeft(find.byKey(const Key('second'))).dx));
  });
}

void expandableTests() {
  testWidgets('long descriptions get See more / See less', (tester) async {
    await tester.pumpWidget(MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(
            width: 200,
            child: ExpandableText(
              List.filled(40, 'plumber').join(' '),
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ),
      ),
    ));
    expect(find.text('See more'), findsOneWidget);
    await tester.tap(find.text('See more'));
    await tester.pump();
    expect(find.text('See less'), findsOneWidget);
  });

  testWidgets('short descriptions have no link', (tester) async {
    await tester.pumpWidget(MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Scaffold(
        body: SizedBox(
          width: 300,
          child: ExpandableText('Short text', style: TextStyle(fontSize: 14)),
        ),
      ),
    ));
    expect(find.text('See more'), findsNothing);
  });
}
