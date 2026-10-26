import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/l10n/app_localizations.dart';
import 'package:konnect_kashmir/l10n/app_localizations_en.dart';
import 'package:konnect_kashmir/l10n/app_localizations_hi.dart';
import 'package:konnect_kashmir/l10n/app_localizations_ur.dart';
import 'package:konnect_kashmir/services/business_share.dart';
import 'package:konnect_kashmir/widgets/share_business_button.dart';
import 'package:share_plus/share_plus.dart';

const _id = '3f2a9c1e-7b64-4d0a-9e55-1c2d3e4f5a6b';

void main() {
  final en = AppLocalizationsEn();

  group('the link', () {
    test('is the website page of that business', () {
      expect(businessUrl(_id), 'https://konnectkashmir.com/business/$_id');
      expect(businessUrl(42), 'https://konnectkashmir.com/business/42');
    });

    test('is never made up when there is no id', () {
      expect(businessUrl(null), isNull);
      expect(businessUrl(''), isNull);
      expect(businessUrl('  '), isNull);
      expect(businessUrl('null'), isNull);
    });

    test('an id is made safe for an address', () {
      expect(
        businessUrl('a b/c'),
        'https://konnectkashmir.com/business/a%20b%2Fc',
      );
    });
  });

  group('the message', () {
    test(
      'has the name, category, address, phone and the link, from the data',
      () {
        final text = businessShareText(
          en,
          const BusinessShareData(
            id: _id,
            name: 'Sajad Khatmband',
            category: 'Carpenter',
            locality: 'Noorbagh',
            address: 'Lane 4, Noorbagh, Srinagar',
            phone: '9876543210',
          ),
        );
        expect(
          text,
          'Check out Sajad Khatmband on Konnect Kashmir\n'
          'Category: Carpenter\n'
          'Address: Lane 4, Noorbagh, Srinagar\n'
          'Phone: +91 9876543210\n'
          '\n'
          'View details: https://konnectkashmir.com/business/$_id',
        );
      },
    );

    test('is different for a different business (nothing is fixed)', () {
      final a = businessShareText(
        en,
        const BusinessShareData(
          id: 'a1',
          name: 'Alpha Plumbing',
          category: 'Plumber',
        ),
      );
      final b = businessShareText(
        en,
        const BusinessShareData(
          id: 'b2',
          name: 'Beta Bakery',
          category: 'Bakery',
        ),
      );
      expect(a, contains('Alpha Plumbing'));
      expect(a, contains('/business/a1'));
      expect(a, isNot(contains('Beta')));
      expect(b, contains('Beta Bakery'));
      expect(b, contains('/business/b2'));
      expect(b, isNot(contains('Alpha')));
    });

    test(
      'a locked contact: only the area is shared, no address and no number',
      () {
        final text = businessShareText(
          en,
          const BusinessShareData(
            id: _id,
            name: 'Sajad Khatmband',
            category: 'Carpenter',
            locality: 'Noorbagh',
          ),
        );
        expect(text, contains('Area: Noorbagh'));
        expect(text, isNot(contains('Address')));
        expect(text, isNot(contains('Phone')));
        expect(text, isNot(contains('+91')));
      },
    );

    test('the area is added to an address that does not say it', () {
      final text = businessShareText(
        en,
        const BusinessShareData(
          id: _id,
          name: 'X',
          locality: 'Rajbagh',
          address: 'Near the old bridge',
        ),
      );
      expect(text, contains('Address: Near the old bridge, Rajbagh'));
      // ...and not repeated when it does.
      final again = businessShareText(
        en,
        const BusinessShareData(
          id: _id,
          name: 'X',
          locality: 'rajbagh',
          address: 'Lane 2, Rajbagh',
        ),
      );
      expect(again, contains('Address: Lane 2, Rajbagh\n'));
      expect(again, isNot(contains('Rajbagh, rajbagh')));
    });

    test('missing parts are left out, not shown as blanks', () {
      final text = businessShareText(
        en,
        const BusinessShareData(id: _id, name: 'Only Name'),
      );
      expect(
        text,
        'Check out Only Name on Konnect Kashmir\n\n'
        'View details: https://konnectkashmir.com/business/$_id',
      );
      expect(text, isNot(contains('Category')));
      expect(text, isNot(contains('null')));
    });

    test('whitespace is trimmed', () {
      final text = businessShareText(
        en,
        const BusinessShareData(
          id: _id,
          name: '  Spaced Name ',
          category: ' Tailor ',
          phone: ' 9000000000 ',
        ),
      );
      expect(text, contains('Check out Spaced Name on'));
      expect(text, contains('Category: Tailor'));
      expect(text, contains('Phone: +91 9000000000'));
    });

    test('a phone that already has a country code is kept as it is', () {
      final text = businessShareText(
        en,
        const BusinessShareData(id: _id, name: 'X', phone: '+971501234567'),
      );
      expect(text, contains('Phone: +971501234567'));
      expect(text, isNot(contains('+91 +971')));
    });

    test(
      'with no id there is no link, and no fake one: just the information',
      () {
        final text = businessShareText(
          en,
          const BusinessShareData(
            id: null,
            name: 'No Id Co',
            category: 'Painter',
            locality: 'Lal Chowk',
          ),
        );
        expect(text, contains('No Id Co'));
        expect(text, contains('Area: Lal Chowk'));
        expect(text, isNot(contains('http')));
        expect(text, isNot(contains('View details')));
      },
    );

    test('is written in the app language', () {
      const data = BusinessShareData(
        id: _id,
        name: 'Sajad',
        category: 'बढ़ई',
        locality: 'नूरबाग़',
      );
      final hi = businessShareText(AppLocalizationsHi(), data);
      expect(hi, contains('Konnect Kashmir पर Sajad देखें'));
      expect(hi, contains('श्रेणी: बढ़ई'));
      expect(hi, contains('इलाका: नूरबाग़'));
      expect(
        hi,
        contains('विवरण देखें: https://konnectkashmir.com/business/$_id'),
      );

      final ur = businessShareText(AppLocalizationsUr(), data);
      expect(ur, contains('Konnect Kashmir پر Sajad دیکھیں'));
      expect(ur, contains('زمرہ: बढ़ई'));
      expect(
        ur,
        contains('تفصیلات دیکھیں: https://konnectkashmir.com/business/$_id'),
      );
    });
  });

  group('opening the share sheet', () {
    Widget app(Widget child) => MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: Center(child: child)),
    );

    testWidgets(
      'sends the message and the name (as the subject) to the share sheet',
      (tester) async {
        ShareParams? sent;
        await tester.pumpWidget(
          app(
            Builder(
              builder: (context) => TextButton(
                onPressed: () => shareBusiness(
                  context,
                  const BusinessShareData(
                    id: _id,
                    name: 'Sajad Khatmband',
                    category: 'Carpenter',
                  ),
                  sender: (p) async {
                    sent = p;
                    return const ShareResult('', ShareResultStatus.success);
                  },
                ),
                child: const Text('go'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('go'));
        await tester.pump();

        expect(sent, isNotNull);
        expect(sent!.text, contains('Sajad Khatmband'));
        expect(
          sent!.text,
          contains('https://konnectkashmir.com/business/$_id'),
        );
        expect(sent!.subject, 'Sajad Khatmband');
        expect(
          sent!.sharePositionOrigin,
          isNotNull,
          reason: 'an iPad popover needs it',
        );
      },
    );

    testWidgets(
      'if the share sheet cannot open, says so instead of failing silently',
      (tester) async {
        bool? opened;
        await tester.pumpWidget(
          app(
            Builder(
              builder: (context) => TextButton(
                onPressed: () async => opened = await shareBusiness(
                  context,
                  const BusinessShareData(id: _id, name: 'X'),
                  sender: (p) async => throw Exception('no share targets'),
                ),
                child: const Text('go'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('go'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(opened, isFalse);
        expect(
          find.text("Couldn't open the share sheet. Please try again."),
          findsOneWidget,
        );
      },
    );

    for (final (platform, icon) in [
      (TargetPlatform.android, Icons.share_rounded),
      (TargetPlatform.iOS, Icons.ios_share_rounded),
    ]) {
      testWidgets('the button shows the $platform share symbol and a tooltip', (
        tester,
      ) async {
        debugDefaultTargetPlatformOverride = platform;
        try {
          await tester.pumpWidget(
            app(
              const ShareBusinessButton(
                data: BusinessShareData(id: _id, name: 'X'),
              ),
            ),
          );
          expect(find.byIcon(icon), findsOneWidget);
          expect(find.byTooltip('Share'), findsOneWidget);
          // A comfortable touch target without crowding the card.
          final size = tester.getSize(find.byType(IconButton));
          expect(size.width, greaterThanOrEqualTo(36));
          expect(size.height, greaterThanOrEqualTo(36));
        } finally {
          // Must be back to normal before the test ends.
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }
  });
}
