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

void _tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('address box shows the address only; the pin has no box',
      (tester) async {
    _tallScreen(tester);
    await tester.pumpWidget(_app(ListBusinessScreen(existingVendor: {
      'id': '1',
      'business_name': 'Test Shop',
      'address': 'Lal Chowk, Srinagar $_pin',
    })));
    await tester.pump(const Duration(milliseconds: 100));

    // The stored pin is split off the text, and nothing shows it.
    expect(find.widgetWithText(TextFormField, 'Lal Chowk, Srinagar'), findsOneWidget);
    expect(find.textContaining('maps.app.goo.gl'), findsNothing);

    // Only the location button is left; the link box and "Check on map" are gone.
    expect(find.text('Use my current location'), findsOneWidget);
    expect(find.text('Check on map'), findsNothing);
    expect(find.textContaining('Google Maps link'), findsNothing);
  });

  testWidgets('the WhatsApp tick sits to the right of the WhatsApp label',
      (tester) async {
    _tallScreen(tester);
    await tester.pumpWidget(_app(const ListBusinessScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    final label = find.text('WhatsApp');
    final same = find.text('Same as business number');
    final box = find.byType(Checkbox);
    expect(label, findsOneWidget);
    expect(same, findsOneWidget);
    expect(box, findsOneWidget);

    // Same line (not a line below), and to the right of the label.
    expect((tester.getCenter(box).dy - tester.getCenter(label).dy).abs(), lessThan(20));
    expect(tester.getCenter(box).dx, greaterThan(tester.getCenter(label).dx));
    expect(tester.getCenter(same).dx, greaterThan(tester.getCenter(box).dx));
  });

  testWidgets('the tick still switches "same as business number"',
      (tester) async {
    _tallScreen(tester);
    await tester.pumpWidget(_app(const ListBusinessScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    await tester.tap(find.text('Same as business number'));
    await tester.pump();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
  });
}
