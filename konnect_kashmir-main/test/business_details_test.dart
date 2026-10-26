import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/l10n/l10n.dart';
import 'package:konnect_kashmir/screens/business_details/business_details_host.dart';
import 'package:konnect_kashmir/screens/business_details/business_details_screen.dart';
import 'package:konnect_kashmir/theme/app_theme.dart';

// Roboto from the Flutter SDK, so text is as wide as on a phone.
Future<void> _loadRoboto() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = Directory('$root/bin/cache/artifacts/material_fonts');
  if (!dir.existsSync()) return;
  final loader = FontLoader('Roboto');
  for (final name in ['Roboto-Regular', 'Roboto-Medium', 'Roboto-Bold']) {
    final file = File('${dir.path}/$name.ttf');
    if (file.existsSync()) {
      loader.addFont(
        Future.value(ByteData.view(file.readAsBytesSync().buffer)),
      );
    }
  }
  await loader.load();
}

class _FakeSource implements BusinessDetailsSource {
  _FakeSource({
    this.detail,
    this.categories = const [],
    this.reviewList = const [],
    this.failDetails = false,
  });
  Map<String, dynamic>? detail;
  List<String> categories;
  List<Map<String, dynamic>> reviewList;
  bool failDetails;

  /// While set, the details are not answered yet.
  Completer<void>? gate;
  int detailRequests = 0;

  @override
  Future<Map<String, dynamic>?> details(String id) async {
    detailRequests++;
    await gate?.future;
    if (failDetails) throw Exception('Network error');
    return detail;
  }

  @override
  Future<List<String>> categorySlugs(String id) async => categories;

  @override
  Future<List<Map<String, dynamic>>> reviews(String id) async => reviewList;
}

class _FakeHost implements BusinessDetailsHost {
  _FakeHost(this.src);
  final _FakeSource src;
  final ValueNotifier<int> tick = ValueNotifier<int>(0);
  final Set<String> unlocked = {};
  final Map<String, String> phones = {};
  final List<String> log = [];
  bool signedIn = true;
  int creditCount = 3;

  @override
  BusinessDetailsSource get source => src;
  @override
  Listenable get changes => tick;
  @override
  bool get isSignedIn => signedIn;
  @override
  int get credits => creditCount;
  @override
  bool isUnlocked(String id) => unlocked.contains(id);
  @override
  bool isUnlocking(String id) => false;
  @override
  String phoneOf(String id, Map<String, dynamic> vendor) =>
      phones[id] ?? (vendor['phone'] ?? '').toString();
  @override
  void resolvePhone(String id) => log.add('resolve $id');
  @override
  String categoryLabel(BuildContext context, String slug) =>
      const {
        'car_rental': 'Car Rental',
        'tour_travels': 'Tour & Travels',
        'plumber': 'Plumber',
      }[slug] ??
      slug;
  @override
  Future<void> unlock(Map<String, dynamic> vendor) async {
    log.add('unlock');
    final id = vendor['id'].toString();
    unlocked.add(id);
    phones[id] = '9876543210';
    tick.value++;
  }

  @override
  void signIn() => log.add('signIn');
  @override
  Future<void> call(String phone, String id) async =>
      log.add('call $phone $id');
  @override
  Future<void> whatsApp(String phone, String id) async =>
      log.add('whatsapp $phone $id');
  @override
  Future<void> openMap(Uri uri) async => log.add('map $uri');
  @override
  Widget reviewForm(String id) => const Text('REVIEW FORM');
  @override
  void report(Map<String, dynamic> vendor) => log.add('report');
}

Map<String, dynamic> _full() => {
  'id': 'b1',
  'business_name': 'Orchid Cab Services',
  'service_type': 'car_rental',
  'localities': {'name': 'Srinagar'},
  'description': 'Provides Tourist cabs services and Tour Packages.',
  'is_verified': true,
  'logo_url': null,
  'gallery_urls': <String>[],
  'working_hours': 'Mon to Sat, 9am to 7pm',
  'services_offered': ['Tour & Travels', 'Airport pickup'],
  'other_service_description': null,
  'min_price': 500,
  'max_price': 1500,
  'experience_years': 8,
  'provides_home_service': true,
  'accepts_online_payment': true,
  'phone': null,
  'address': 'Lane 4, Rajbagh',
};

Future<void> _show(
  WidgetTester tester,
  _FakeHost host, {
  Map<String, dynamic>? vendor,
  String? id,
  ThemeData? theme,
  double textScale = 1.0,
  Size size = const Size(390, 2400),
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: BusinessDetailsScreen(host: host, vendor: vendor, vendorId: id),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUpAll(_loadRoboto);

  group('what it shows', () {
    testWidgets('everything the business has, and nothing it does not', (
      tester,
    ) async {
      final host = _FakeHost(
        _FakeSource(
          detail: _full(),
          categories: ['car_rental', 'tour_travels'],
        ),
      );
      await _show(tester, host, id: 'b1');

      expect(find.text('Orchid Cab Services'), findsWidgets);
      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('Car Rental'), findsOneWidget);
      expect(find.text('Srinagar'), findsWidgets);
      expect(
        find.text('Provides Tourist cabs services and Tour Packages.'),
        findsOneWidget,
      );
      // The extra category and the offered services, without repeating any.
      expect(find.text('Tour & Travels'), findsOneWidget);
      expect(find.text('Airport pickup'), findsOneWidget);
      expect(find.text('Mon to Sat, 9am to 7pm'), findsOneWidget);
      expect(find.text('₹500 – 1,500'), findsOneWidget);
      expect(find.text('8 yrs'), findsOneWidget);
      expect(find.text('Home visit'), findsOneWidget);
      expect(find.text('Online pay'), findsOneWidget);
      expect(find.byTooltip('Share'), findsOneWidget);
    });

    testWidgets('a business with little information shows only that', (
      tester,
    ) async {
      final host = _FakeHost(
        _FakeSource(
          detail: {
            'id': 'b2',
            'business_name': 'Plain Plumbing',
            'service_type': 'plumber',
            'description': '  ',
            'services_offered': <String>[],
            'gallery_urls': null,
            'working_hours': null,
            'min_price': 0,
            'max_price': null,
            'is_verified': false,
          },
        ),
      );
      await _show(tester, host, id: 'b2');

      expect(find.text('Plain Plumbing'), findsWidgets);
      expect(find.text('Plumber'), findsOneWidget);
      for (final heading in ['About', 'Services', 'Working hours']) {
        expect(find.text(heading), findsNothing, reason: heading);
      }
      expect(find.text('Verified'), findsNothing);
      expect(find.textContaining('null'), findsNothing);
      expect(find.byIcon(Icons.currency_rupee_rounded), findsNothing);
      expect(find.text('No reviews yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows what the card knew at once, then fills in the rest', (
      tester,
    ) async {
      final src = _FakeSource(detail: _full())..gate = Completer<void>();
      final host = _FakeHost(src);
      final fromCard = {
        'id': 'b1',
        'business_name': 'Orchid Cab Services',
        'service_type': 'car_rental',
        'localities': {'name': 'Srinagar'},
      };
      await _show(tester, host, vendor: fromCard);
      expect(find.text('Orchid Cab Services'), findsWidgets);
      expect(find.text('Mon to Sat, 9am to 7pm'), findsNothing);

      src.gate!.complete();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Mon to Sat, 9am to 7pm'), findsOneWidget);
      expect(src.detailRequests, 1, reason: 'asked once');
    });
  });

  group('photos', () {
    testWidgets('several photos swipe, with a count', (tester) async {
      final v = _full()
        ..['logo_url'] = 'https://example.com/logo.png'
        ..['gallery_urls'] = [
          'https://example.com/a.jpg',
          'https://example.com/b.jpg',
          'https://example.com/a.jpg', // a repeat is shown once
        ];
      await _show(tester, _FakeHost(_FakeSource(detail: v)), id: 'b1');

      expect(find.text('1/3'), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('2/3'), findsOneWidget);
    });

    testWidgets('no photo: a picture for the category, nothing broken', (
      tester,
    ) async {
      await _show(tester, _FakeHost(_FakeSource(detail: _full())), id: 'b1');
      expect(find.byType(PageView), findsNothing);
      // (The faint leaf watermark behind every screen is an Image too, so look
      // only inside the photo area.)
      expect(
        find.descendant(
          of: find.byType(AspectRatio),
          matching: find.byType(Image),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a photo that cannot load falls back to the picture', (
      tester,
    ) async {
      final v = _full()..['logo_url'] = 'https://example.com/missing.png';
      await _show(tester, _FakeHost(_FakeSource(detail: v)), id: 'b1');
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(find.text('Orchid Cab Services'), findsWidgets);
    });
  });

  group('contact and the actions', () {
    testWidgets(
      'locked: says so, shows no number or address, offers to unlock',
      (tester) async {
        final host = _FakeHost(_FakeSource(detail: _full()));
        await _show(tester, host, id: 'b1');

        expect(find.textContaining('Unlock this business'), findsOneWidget);
        expect(find.text('Unlock Contact'), findsOneWidget);
        expect(find.textContaining('Lane 4'), findsNothing);
        expect(find.textContaining('9876543210'), findsNothing);
        expect(find.text('Call Now'), findsNothing);
        expect(find.text('Report this business'), findsNothing);
        expect(find.text('REVIEW FORM'), findsNothing);
      },
    );

    testWidgets('unlocking shows the number, the address and the call button', (
      tester,
    ) async {
      final host = _FakeHost(_FakeSource(detail: _full()));
      await _show(tester, host, id: 'b1');

      await tester.tap(find.text('Unlock Contact'));
      await tester.pump(const Duration(milliseconds: 50));

      expect(host.log, contains('unlock'));
      expect(find.text('+91 9876543210'), findsNWidgets(2)); // phone, WhatsApp
      expect(find.text('Lane 4, Rajbagh'), findsOneWidget);
      expect(find.text('Call Now'), findsOneWidget);
      expect(find.text('Unlock Contact'), findsNothing);
      // Reviews and reporting are for someone who unlocked it.
      expect(find.text('REVIEW FORM'), findsOneWidget);
      expect(find.text('Report this business'), findsOneWidget);
    });

    testWidgets('with no credit it offers to watch an ad instead', (
      tester,
    ) async {
      final host = _FakeHost(_FakeSource(detail: _full()))..creditCount = 0;
      await _show(tester, host, id: 'b1');
      expect(find.text('Watch ad to unlock'), findsOneWidget);
      expect(find.text('Unlock Contact'), findsNothing);
    });

    testWidgets('signed out: asks to sign in', (tester) async {
      final host = _FakeHost(_FakeSource(detail: _full()))..signedIn = false;
      await _show(tester, host, id: 'b1');
      await tester.tap(find.text('Sign in to unlock'));
      await tester.pump();
      expect(host.log, ['signIn']);
      expect(find.text('Report this business'), findsNothing);
    });

    testWidgets('call, WhatsApp and directions each do their own thing', (
      tester,
    ) async {
      final host = _FakeHost(_FakeSource(detail: _full()))
        ..unlocked.add('b1')
        ..phones['b1'] = '9876543210';
      await _show(tester, host, id: 'b1');

      await tester.tap(find.text('Call Now'));
      await tester.tap(find.byTooltip('WhatsApp').first);
      await tester.tap(find.byTooltip('Directions').first);
      await tester.pump();

      expect(host.log, contains('call 9876543210 b1'));
      expect(host.log, contains('whatsapp 9876543210 b1'));
      final map = host.log.firstWhere((l) => l.startsWith('map '));
      expect(map, contains('google'));
      expect(
        Uri.parse(map.substring(4)).queryParameters['query'],
        contains('Lane 4'),
      );
    });

    testWidgets('unlocked but no number yet: it asks for it, no dead buttons', (
      tester,
    ) async {
      final host = _FakeHost(_FakeSource(detail: _full()))..unlocked.add('b1');
      await _show(tester, host, id: 'b1');
      expect(host.log, contains('resolve b1'));
      expect(find.text('Call Now'), findsNothing);
      expect(find.text('Phone not available'), findsOneWidget);
      // The address can still be opened in the map.
      expect(find.byTooltip('Directions'), findsWidgets);
    });

    testWidgets(
      'a change in the host (unlocking elsewhere) updates the screen',
      (tester) async {
        final host = _FakeHost(_FakeSource(detail: _full()));
        await _show(tester, host, id: 'b1');
        expect(find.text('Unlock Contact'), findsOneWidget);

        host.unlocked.add('b1');
        host.phones['b1'] = '9111111111';
        host.tick.value++;
        await tester.pump();
        expect(find.text('Call Now'), findsOneWidget);
        expect(find.text('+91 9111111111'), findsWidgets);
      },
    );
  });

  group('reviews', () {
    testWidgets('no reviews: says so and shows no rating', (tester) async {
      await _show(tester, _FakeHost(_FakeSource(detail: _full())), id: 'b1');
      expect(find.text('No reviews yet'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
    });

    testWidgets('real reviews give the average and the count', (tester) async {
      final src = _FakeSource(
        detail: _full(),
        reviewList: [
          {
            'id': 1,
            'rating': 5,
            'review_text': 'Very good',
            'created_at': '2026-10-01T10:00:00Z',
          },
          {
            'id': 2,
            'rating': 4,
            'review_text': 'Fine',
            'created_at': '2026-10-02T10:00:00Z',
          },
        ],
      );
      await _show(tester, _FakeHost(src), id: 'b1');
      expect(find.textContaining('4.5'), findsOneWidget);
      expect(find.textContaining('2 reviews'), findsOneWidget);
      expect(find.text('Very good'), findsOneWidget);
      expect(find.text('No reviews yet'), findsNothing);
    });

    testWidgets('more than three: the rest are behind "Show all"', (
      tester,
    ) async {
      final src = _FakeSource(
        detail: _full(),
        reviewList: [
          for (var i = 1; i <= 5; i++)
            {
              'id': i,
              'rating': 5,
              'review_text': 'Review $i',
              'created_at': '2026-10-0${i}T10:00:00Z',
            },
        ],
      );
      await _show(tester, _FakeHost(src), id: 'b1');
      expect(find.text('Review 4'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Show all 5 reviews'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Show all 5 reviews'));
      await tester.pump();
      expect(find.text('Review 5'), findsOneWidget);
      expect(find.text('Show fewer'), findsOneWidget);
    });
  });

  group('loading, error and gone', () {
    testWidgets('while loading from a link it shows placeholders', (
      tester,
    ) async {
      final src = _FakeSource(detail: _full())..gate = Completer<void>();
      await _show(tester, _FakeHost(src), id: 'b1');
      expect(find.byType(ListView), findsOneWidget);
      expect(find.text('Orchid Cab Services'), findsNothing);
      src.gate!.complete();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Orchid Cab Services'), findsWidgets);
    });

    testWidgets('no internet from a link: offers a retry', (tester) async {
      final src = _FakeSource(detail: _full(), failDetails: true);
      await _show(tester, _FakeHost(src), id: 'b1');
      expect(find.text('Retry'), findsOneWidget);

      src.failDetails = false;
      await tester.tap(find.text('Retry'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Orchid Cab Services'), findsWidgets);
    });

    testWidgets('no internet from a card: keeps what the card knew', (
      tester,
    ) async {
      final src = _FakeSource(failDetails: true);
      await _show(
        tester,
        _FakeHost(src),
        vendor: {
          'id': 'b1',
          'business_name': 'Orchid Cab Services',
          'service_type': 'car_rental',
        },
      );
      expect(find.text('Orchid Cab Services'), findsWidgets);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('a business that is gone says so', (tester) async {
      await _show(tester, _FakeHost(_FakeSource()), id: 'gone');
      expect(
        find.text('This business is not available any more.'),
        findsOneWidget,
      );
    });
  });

  group('fits every phone and theme', () {
    testWidgets('dark theme, a small screen, large text, long words', (
      tester,
    ) async {
      final v = _full()
        ..['business_name'] =
            'The Very Long Named Orchid Cab Services And Tour Packages Of Srinagar'
        ..['working_hours'] =
            'Monday to Saturday 9 in the morning until 7 in the evening, Sunday by appointment only'
        ..['services_offered'] = [
          for (var i = 0; i < 12; i++) 'Service number $i',
        ]
        ..['description'] = 'A very long description. ' * 20;
      for (final theme in [AppTheme.dark, AppTheme.light]) {
        final host =
            _FakeHost(
                _FakeSource(
                  detail: v,
                  categories: ['car_rental', 'tour_travels'],
                ),
              )
              ..unlocked.add('b1')
              ..phones['b1'] = '9876543210';
        await _show(
          tester,
          host,
          id: 'b1',
          theme: theme,
          textScale: 1.5,
          size: const Size(320, 640),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Call Now'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      }
    });
  });
}
