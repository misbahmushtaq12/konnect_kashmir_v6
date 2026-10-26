import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/l10n/l10n.dart';
import 'package:konnect_kashmir/providers/auth_provider.dart';
import 'package:konnect_kashmir/screens/business_details/business_details_screen.dart';
import 'package:konnect_kashmir/screens/customer_screen.dart';
import 'package:konnect_kashmir/services/app_links.dart';
import 'package:konnect_kashmir/services/live_sync.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── A fake network: only the providers list answers; every other request fails
// the way it does in any widget test. ─────────────────────────────────────────

typedef _Reply = ({int status, String body});

class _FakeOverrides extends HttpOverrides {
  final _Reply Function(Uri uri) respond;
  _FakeOverrides(this.respond);
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeClient(respond);
}

class _FakeClient implements HttpClient {
  _FakeClient(this.respond);
  final _Reply Function(Uri uri) respond;
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _FakeRequest(respond(url));
  @override
  void close({bool force = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeRequest implements HttpClientRequest {
  _FakeRequest(this.reply);
  final _Reply reply;
  @override
  HttpHeaders get headers => _FakeHeaders(const {});
  @override
  void add(List<int> data) {}
  @override
  Future<void> addStream(Stream<List<int>> stream) => stream.drain<void>();
  @override
  Future<HttpClientResponse> close() async => _FakeResponse(reply);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHeaders implements HttpHeaders {
  _FakeHeaders(this.values);
  final Map<String, String> values;
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void forEach(void Function(String name, List<String> values) action) =>
      values.forEach((k, v) => action(k, [v]));
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeResponse extends Stream<List<int>> implements HttpClientResponse {
  _FakeResponse(this.reply) : _bytes = utf8.encode(reply.body);
  final _Reply reply;
  final List<int> _bytes;
  @override
  int get statusCode => reply.status;
  @override
  String get reasonPhrase => reply.status == 200 ? 'OK' : 'Error';
  @override
  int get contentLength => _bytes.length;
  @override
  bool get isRedirect => false;
  @override
  bool get persistentConnection => false;
  @override
  List<RedirectInfo> get redirects => const [];
  @override
  HttpHeaders get headers =>
      _FakeHeaders(const {'content-type': 'application/json; charset=utf-8'});
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(_bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ── Test data ────────────────────────────────────────────────────────────────

Map<String, dynamic> _vendor(
  String id,
  String name, {
  String type = 'carpenter',
  String locality = 'Noorbagh',
  String address = 'Lane 4, Noorbagh, Srinagar',
  String phone = '9876543210',
}) => {
  'id': id,
  'business_name': name,
  'service_type': type,
  'locality_id': 'loc-1',
  'localities': {'name': locality},
  'description': 'Fine woodwork.',
  'is_verified': false,
  'logo_url': null,
  'created_at': '2026-01-01T00:00:00Z',
  'min_price': null,
  'max_price': null,
  'experience_years': null,
  'provides_home_service': false,
  'accepts_online_payment': false,
  'phone': phone,
  'address': address,
};

/// The providers list answers with [list]. A request for particular ids (a shared
/// link) is answered from [byId] and recorded in [asked].
class _Backend {
  _Backend({
    this.list = const [],
    this.byId = const {},
    this.failShared = false,
  });
  final List<Map<String, dynamic>> list;
  final Map<String, Map<String, dynamic>> byId;
  bool failShared;
  final List<String> asked = [];

  _Reply respond(Uri uri) {
    if (uri.path.endsWith('/service_categories')) {
      return (
        status: 200,
        body: jsonEncode([
          {'slug': 'carpenter', 'name': 'Carpenter'},
          {'slug': 'bakery', 'name': 'Bakery'},
          {'slug': 'plumber', 'name': 'Plumber'},
          {'slug': 'electrician', 'name': 'Electrician'},
        ]),
      );
    }
    if (uri.path.endsWith('/vendor_categories') ||
        uri.path.endsWith('/vendor_reviews_public')) {
      return (status: 200, body: '[]');
    }
    if (!uri.path.endsWith('/vendors_public')) return (status: 404, body: '{}');
    final idFilter = uri.queryParameters['id'];
    // The details screen asks for one business by its id.
    if (idFilter != null && idFilter.startsWith('eq.')) {
      asked.add(idFilter);
      if (failShared) return (status: 500, body: '{}');
      final found =
          byId[idFilter.substring(3)] ??
          {for (final v in list) v['id'] as String: v}[idFilter.substring(3)];
      return (status: 200, body: jsonEncode([?found]));
    }
    if (idFilter != null && idFilter.startsWith('in.(')) {
      asked.add(idFilter);
      if (failShared) return (status: 500, body: '{}');
      final ids = idFilter.substring(4, idFilter.length - 1).split(',');
      return (
        status: 200,
        body: jsonEncode([
          for (final i in ids)
            if (byId[i] != null) byId[i],
        ]),
      );
    }
    return (status: 200, body: jsonEncode(list));
  }
}

const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

// The app's shared HTTP client is created once per process, with the first fake
// it meets. So the fake is installed once and answers from whichever backend the
// current test set.
_Backend _current = _Backend();
bool _installed = false;

Future<void> _pumpHome(WidgetTester tester, _Backend backend) async {
  _current = backend;
  if (!_installed) {
    HttpOverrides.global = _FakeOverrides((uri) => _current.respond(uri));
    _installed = true;
  }
  tester.view.physicalSize = const Size(900, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final auth = AuthProvider();
  final live = LiveSync(auth);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<LiveSync>.value(value: live),
      ],
      child: MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const CustomerScreen(),
      ),
    ),
  );
  await _settle(tester);
}

/// Lets the (instant) fake answers arrive and the screen rebuild.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The text of the share-sheet calls the phone received.
List<MethodCall> _watchShare(WidgetTester tester) {
  final calls = <MethodCall>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    _shareChannel,
    (call) async {
      calls.add(call);
      return 'dev.fluttercommunity.plus/share/unavailable';
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _shareChannel,
      null,
    ),
  );
  return calls;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLinks.businessRequest.value = null;
  });
  tearDownAll(() => HttpOverrides.global = null);

  group('business cards', () {
    testWidgets('every card has a share icon', (tester) async {
      await _pumpHome(
        tester,
        _Backend(
          list: [
            _vendor('v1', 'Sajad Khatmband'),
            _vendor('v2', 'Beta Bakery', type: 'bakery'),
          ],
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Beta Bakery'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Sajad Khatmband'), findsOneWidget);
      expect(find.byTooltip('Share'), findsNWidgets(2));
    });

    testWidgets(
      'a locked card shares the business and its link, not the number or address',
      (tester) async {
        final shared = _watchShare(tester);
        await _pumpHome(
          tester,
          _Backend(list: [_vendor('v1', 'Sajad Khatmband')]),
        );
        await tester.scrollUntilVisible(
          find.byTooltip('Share'),
          400,
          scrollable: find.byType(Scrollable).first,
        );

        await tester.tap(find.byTooltip('Share'));
        await tester.pump(const Duration(milliseconds: 100));

        expect(shared, hasLength(1));
        expect(shared.single.method, 'share');
        final text = (shared.single.arguments as Map)['text'] as String;
        expect(text, contains('Check out Sajad Khatmband on Konnect Kashmir'));
        expect(text, contains('Category: Carpenter'));
        expect(text, contains('Area: Noorbagh'));
        expect(text, contains('https://konnectkashmir.com/business/v1'));
        expect(
          text,
          isNot(contains('9876543210')),
          reason: 'a locked number is not given away',
        );
        expect(text, isNot(contains('Lane 4')), reason: 'nor a locked address');
        expect((shared.single.arguments as Map)['subject'], 'Sajad Khatmband');
      },
    );

    testWidgets('an unlocked card also shares its address and number', (
      tester,
    ) async {
      final shared = _watchShare(tester);
      await _pumpHome(
        tester,
        _Backend(list: [_vendor('v1', 'Sajad Khatmband')]),
      );
      await tester.scrollUntilVisible(
        find.byTooltip('Share'),
        400,
        scrollable: find.byType(Scrollable).first,
      );

      // The user has unlocked this contact.
      final state = tester.state(find.byType(CustomerScreen)) as dynamic;
      // ignore: avoid_dynamic_calls
      state.setState(() => state.revealedVendors['v1'] = true);
      await tester.pump();

      await tester.tap(find.byTooltip('Share'));
      await tester.pump(const Duration(milliseconds: 100));

      final text = (shared.single.arguments as Map)['text'] as String;
      expect(text, contains('Address: Lane 4, Noorbagh, Srinagar'));
      expect(text, contains('Phone: +91 9876543210'));
      expect(text, contains('/business/v1'));
    });

    testWidgets('each business shares its own details', (tester) async {
      final shared = _watchShare(tester);
      await _pumpHome(
        tester,
        _Backend(
          list: [
            _vendor('v1', 'Sajad Khatmband'),
            _vendor('v2', 'Beta Bakery', type: 'bakery', locality: 'Rajbagh'),
          ],
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Beta Bakery'),
        400,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.tap(find.byTooltip('Share').last);
      await tester.pump(const Duration(milliseconds: 100));
      final text = (shared.single.arguments as Map)['text'] as String;
      expect(text, contains('Beta Bakery'));
      expect(text, contains('/business/v2'));
      expect(text, contains('Area: Rajbagh'));
      expect(text, isNot(contains('Sajad')));
    });

    testWidgets('a missing locality and category do not break it', (
      tester,
    ) async {
      final shared = _watchShare(tester);
      final v = _vendor('v3', 'Gamma Works', type: '', locality: '');
      v['localities'] = null;
      v['address'] = null;
      v['phone'] = null;
      await _pumpHome(tester, _Backend(list: [v]));
      await tester.scrollUntilVisible(
        find.byTooltip('Share'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byTooltip('Share'));
      await tester.pump(const Duration(milliseconds: 100));

      final text = (shared.single.arguments as Map)['text'] as String;
      expect(text, contains('Gamma Works'));
      expect(text, contains('/business/v3'));
      expect(text, isNot(contains('null')));
      expect(text, isNot(contains('Area')));
    });
  });

  group('a shared business link', () {
    testWidgets('opens the business details screen', (tester) async {
      AppLinks.businessRequest.value = 'shared-1';
      final backend = _Backend(
        list: [_vendor('v9', 'Filler Co')],
        byId: {
          'shared-1': _vendor('shared-1', 'Shared Plumbing', type: 'plumber'),
        },
      );
      await _pumpHome(tester, backend);

      expect(find.byType(BusinessDetailsScreen), findsOneWidget);
      expect(find.text('Shared Plumbing'), findsWidgets);
      expect(backend.asked, ['eq.shared-1']);
      expect(find.text('Fine woodwork.'), findsOneWidget);
      expect(
        AppLinks.businessRequest.value,
        isNull,
        reason: 'taken, so it is shown once',
      );
    });

    testWidgets('a link that arrives while Home is open opens it too', (
      tester,
    ) async {
      final backend = _Backend(
        list: [_vendor('v9', 'Filler Co')],
        byId: {
          'shared-2': _vendor(
            'shared-2',
            'Later Electric',
            type: 'electrician',
          ),
        },
      );
      await _pumpHome(tester, backend);
      expect(find.byType(BusinessDetailsScreen), findsNothing);

      AppLinks.businessRequest.value = 'shared-2';
      await _settle(tester);
      expect(find.byType(BusinessDetailsScreen), findsOneWidget);
      expect(find.text('Later Electric'), findsWidgets);
    });

    testWidgets('back returns to Home', (tester) async {
      AppLinks.businessRequest.value = 'shared-1';
      await _pumpHome(
        tester,
        _Backend(
          list: [_vendor('v9', 'Filler Co')],
          byId: {'shared-1': _vendor('shared-1', 'Shared Plumbing')},
        ),
      );
      expect(find.byType(BusinessDetailsScreen), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await _settle(tester);
      expect(find.byType(BusinessDetailsScreen), findsNothing);
      expect(find.text('Filler Co'), findsOneWidget);
    });

    testWidgets('a business that is gone says so', (tester) async {
      AppLinks.businessRequest.value = 'gone-1';
      await _pumpHome(tester, _Backend(list: [_vendor('v9', 'Filler Co')]));
      expect(find.byType(BusinessDetailsScreen), findsOneWidget);
      expect(
        find.text('This business is not available any more.'),
        findsOneWidget,
      );
    });

    testWidgets('a network error can be retried', (tester) async {
      AppLinks.businessRequest.value = 'shared-1';
      final backend = _Backend(
        failShared: true,
        byId: {'shared-1': _vendor('shared-1', 'Shared Plumbing')},
      );
      await _pumpHome(tester, backend);
      expect(find.text('Shared Plumbing'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);

      backend.failShared = false;
      await tester.tap(find.text('Retry'));
      await _settle(tester);
      expect(find.text('Shared Plumbing'), findsWidgets);
      expect(backend.asked, hasLength(2));
    });
  });

  group('a card opens the details', () {
    testWidgets('tapping the name opens that business, and back returns', (
      tester,
    ) async {
      await _pumpHome(
        tester,
        _Backend(
          list: [
            _vendor('v1', 'Sajad Khatmband'),
            _vendor('v2', 'Beta Bakery', type: 'bakery', locality: 'Rajbagh'),
          ],
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Beta Bakery'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Beta Bakery'));
      await _settle(tester);

      expect(find.byType(BusinessDetailsScreen), findsOneWidget);
      expect(find.text('Beta Bakery'), findsWidgets);
      expect(find.text('Sajad Khatmband'), findsNothing);
      expect(find.text('Rajbagh'), findsWidgets);

      await tester.tap(find.byType(BackButton));
      await _settle(tester);
      expect(find.byType(BusinessDetailsScreen), findsNothing);
      expect(
        find.text('Beta Bakery'),
        findsOneWidget,
        reason: 'same place in the list',
      );
    });

    testWidgets('tapping anywhere on the card, not only the name, opens it', (
      tester,
    ) async {
      await _pumpHome(
        tester,
        _Backend(list: [_vendor('v1', 'Sajad Khatmband')]),
      );
      await tester.scrollUntilVisible(
        find.text('Contact'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Contact'));
      await _settle(tester);
      expect(find.byType(BusinessDetailsScreen), findsOneWidget);
    });

    testWidgets('the share icon shares and does not open the details', (
      tester,
    ) async {
      final shared = _watchShare(tester);
      await _pumpHome(
        tester,
        _Backend(list: [_vendor('v1', 'Sajad Khatmband')]),
      );
      await tester.scrollUntilVisible(
        find.byTooltip('Share'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byTooltip('Share'));
      await _settle(tester);
      expect(shared, hasLength(1));
      expect(find.byType(BusinessDetailsScreen), findsNothing);
    });

    testWidgets('"See more" still opens the card in place', (tester) async {
      await _pumpHome(
        tester,
        _Backend(list: [_vendor('v1', 'Sajad Khatmband')]),
      );
      expect(find.text('Fine woodwork.'), findsNothing);
      await tester.tap(find.text('See more'));
      await _settle(tester);
      expect(find.text('Fine woodwork.'), findsOneWidget);
      expect(find.byType(BusinessDetailsScreen), findsNothing);
    });

    testWidgets(
      'a signed-out visitor sees the business and is asked to sign in',
      (tester) async {
        await _pumpHome(
          tester,
          _Backend(list: [_vendor('v1', 'Sajad Khatmband')]),
        );
        await tester.tap(find.text('Sajad Khatmband'));
        await _settle(tester);
        expect(find.byType(BusinessDetailsScreen), findsOneWidget);
        expect(find.text('Sign in to unlock'), findsWidgets);
        expect(find.textContaining('9876543210'), findsNothing);
      },
    );
  });
}
