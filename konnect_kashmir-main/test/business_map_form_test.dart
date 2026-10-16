import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/l10n/l10n.dart';
import 'package:konnect_kashmir/providers/auth_provider.dart';
import 'package:konnect_kashmir/screens/vendor_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget home) => ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: home,
      ),
    );

const _pin = 'https://maps.app.goo.gl/AbCdEf';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('business form: address and Google Maps link are two boxes',
      (tester) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(ListBusinessScreen(existingVendor: {
      'id': '1',
      'business_name': 'Test Shop',
      'address': 'Lal Chowk, Srinagar $_pin',
    })));
    await tester.pump(const Duration(milliseconds: 100));

    // The stored address comes apart into the text and the pin.
    expect(find.widgetWithText(TextFormField, 'Lal Chowk, Srinagar'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, _pin), findsOneWidget);

    // The two helper buttons and the optional link box are there.
    expect(find.text('Use my current location'), findsOneWidget);
    expect(find.text('Check on map'), findsOneWidget);
    expect(find.text('Google Maps link (optional)'), findsOneWidget);
  });

  testWidgets('a link that is not Google Maps is refused, a real one passes',
      (tester) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(const ListBusinessScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    final linkBox = find.widgetWithText(
        TextFormField, 'Paste the link from Google Maps → Share');
    expect(linkBox, findsOneWidget);
    final form = tester.state<FormState>(find.byType(Form));

    await tester.enterText(linkBox, 'https://evil.example.com/maps');
    form.validate();
    await tester.pump();
    expect(find.text('Enter a valid Google Maps link'), findsOneWidget);

    await tester.enterText(linkBox, 'See $_pin please');
    form.validate();
    await tester.pump();
    expect(find.text('Enter a valid Google Maps link'), findsNothing);

    await tester.enterText(linkBox, '');
    form.validate();
    await tester.pump();
    expect(find.text('Enter a valid Google Maps link'), findsNothing);
  });

  testWidgets('Check on map is disabled until there is something to look for',
      (tester) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(const ListBusinessScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    Finder check() => find.widgetWithText(FilledButton, 'Check on map');
    expect(tester.widget<FilledButton>(check()).onPressed, isNull);

    final addressBox =
        find.widgetWithText(TextFormField, 'Shop/Office address');
    await tester.enterText(addressBox, 'Rajbagh');
    await tester.pump();
    expect(tester.widget<FilledButton>(check()).onPressed, isNotNull);
  });
}
