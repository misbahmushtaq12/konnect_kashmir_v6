import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/l10n/l10n.dart';
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
  testWidgets('Sign-in screen stays English and left-to-right in Urdu',
      (tester) async {
    await tester.pumpWidget(_app(const Locale('ur'), const LoginScreen()));
    await tester.pump();

    expect(find.text('Sign In / Register'), findsOneWidget);
    final ctx = tester.element(find.text('Sign In / Register'));
    expect(Directionality.of(ctx), TextDirection.ltr);
  });

  testWidgets('Sign-in screen stays English in Hindi too', (tester) async {
    await tester.pumpWidget(_app(const Locale('hi'), const LoginScreen()));
    await tester.pump();

    expect(find.text('Sign In / Register'), findsOneWidget);
    expect(find.text('साइन इन / रजिस्टर'), findsNothing);
  });

  testWidgets('OTP screen stays English and left-to-right in Urdu',
      (tester) async {
    await tester.pumpWidget(
        _app(const Locale('ur'), const OTPVerificationScreen(phoneNumber: '9999999999')));
    await tester.pump();

    expect(find.text('OTP Verification'), findsOneWidget);
    final ctx = tester.element(find.text('OTP Verification'));
    expect(Directionality.of(ctx), TextDirection.ltr);
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

  testWidgets('Language picker after sign-in is always English, even if Urdu was chosen',
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
