import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/l10n/l10n.dart';
import 'package:konnect_kashmir/providers/auth_provider.dart';
import 'package:konnect_kashmir/screens/my_business_tab.dart';
import 'package:konnect_kashmir/services/live_sync.dart';
import 'package:konnect_kashmir/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── A fake network: the app's own HTTP client talks to this, nothing goes out ──────────

/// Answers every request from [respond] (status, body) and remembers what was asked.
class _FakeHttp extends HttpOverrides {
  _FakeHttp(this.respond);
  final (int, String) Function(String method, Uri url) respond;
  final List<String> calls = [];

  int count(String what) => calls.where((c) => c == what).length;

  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeClient(this);
}

class _FakeClient implements HttpClient {
  _FakeClient(this._net);
  final _FakeHttp _net;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async => _FakeRequest(_net, method, url);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeRequest implements HttpClientRequest {
  _FakeRequest(this._net, this.method, this.uri);
  final _FakeHttp _net;
  @override
  final String method;
  @override
  final Uri uri;

  @override
  HttpHeaders get headers => _FakeHeaders();

  @override
  void add(List<int> data) {}

  @override
  Future addStream(Stream<List<int>> stream) => stream.drain<void>();

  @override
  Future<HttpClientResponse> close() async {
    _net.calls.add('$method ${uri.path}');
    final (status, body) = _net.respond(method, uri);
    return _FakeResponse(status, body);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHeaders implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void forEach(void Function(String name, List<String> values) action) {}

  @override
  String? value(String name) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeResponse extends Stream<List<int>> implements HttpClientResponse {
  _FakeResponse(this.statusCode, String body) : _bytes = utf8.encode(body);
  final List<int> _bytes;

  @override
  final int statusCode;

  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream<List<int>>.value(_bytes)
          .listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  int get contentLength => -1;
  @override
  bool get isRedirect => false;
  @override
  bool get persistentConnection => true;
  @override
  String get reasonPhrase => 'OK';
  @override
  HttpHeaders get headers => _FakeHeaders();
  @override
  List<RedirectInfo> get redirects => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ── The data: two businesses; Alpha has two leads (one already revealed), Beta has one ──

(int, String) _server(String method, Uri url) {
  if (method == 'GET' && url.path == '/rest/v1/vendors') {
    return (
      200,
      jsonEncode([
        {
          'id': 'b1',
          'business_name': 'Alpha Bakery',
          'service_type': 'bakery',
          'is_approved': true,
          'localities': {'name': 'Rajbagh'},
        },
        {
          'id': 'b2',
          'business_name': 'Beta Tailors',
          'service_type': 'tailor',
          'is_approved': true,
          'localities': {'name': 'Lal Chowk'},
        },
      ])
    );
  }
  if (url.path == '/functions/v1/get-lead-names') {
    return (
      200,
      jsonEncode({
        'success': true,
        'leads': [
          {'id': 'l1', 'user_id': 'u1', 'user_name': 'Asif', 'vendor_id': 'b1', 'created_at': '2026-11-01T08:00:00Z', 'revealed': false},
          {'id': 'l2', 'user_id': 'u2', 'user_name': 'Bilal', 'vendor_id': 'b1', 'created_at': '2026-11-01T09:00:00Z', 'revealed': true, 'phone': '9876543210'},
          {'id': 'l3', 'user_id': 'u3', 'user_name': 'Chand', 'vendor_id': 'b2', 'created_at': '2026-11-01T10:00:00Z', 'revealed': false},
        ],
      })
    );
  }
  return (404, '{}');
}

/// The tab as the bottom bar keeps it: always built, hidden while another tab shows.
class _Host extends StatelessWidget {
  const _Host(this.active);
  final ValueNotifier<bool> active;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: active,
        builder: (_, on, __) => Offstage(offstage: !on, child: MyBusinessTab(isActive: on)),
      );
}

Future<ValueNotifier<bool>> _open(WidgetTester tester) async {
  // A wide phone / small tablet (560 x 800): this test is about open and closed, not about how
  // the cards fit a narrow screen.
  tester.view.physicalSize = const Size(1120, 1600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final auth = AuthProvider();
  await auth.setSession('token', 'user-1', phone: '9999999999', role: 'vendor');
  final active = ValueNotifier<bool>(true);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      // (Its live updates are kept on a separate signed-out auth, so no Supabase is needed.)
      ChangeNotifierProvider<LiveSync>.value(value: LiveSync(AuthProvider())),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: _Host(active)),
    ),
  ));
  await _settle(tester);
  return active;
}

// Roboto from the Flutter SDK, so text is as wide as on a phone (the default test font is
// far wider and would report overflows that do not happen).
Future<void> _loadRoboto() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = Directory('$root/bin/cache/artifacts/material_fonts');
  if (!dir.existsSync()) return;
  final loader = FontLoader('Roboto');
  for (final name in ['Roboto-Regular', 'Roboto-Medium', 'Roboto-Bold']) {
    final file = File('${dir.path}/$name.ttf');
    if (file.existsSync()) {
      loader.addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer)));
    }
  }
  await loader.load();
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

/// The "Leads" buttons of the business cards, first business first.
Finder get _leadsButtons => find.ancestor(
      of: find.text('Leads'),
      matching: find.byType(ElevatedButton),
    );

void main() {
  late _FakeHttp net;

  setUpAll(() async {
    await _loadRoboto();
    net = _FakeHttp(_server);
    HttpOverrides.global = net;
  });
  setUp(() => net.calls.clear());

  /// True while a business's leads are showing (its lead names are on the page).
  bool open(String leadName) => find.text(leadName, skipOffstage: false).evaluate().isNotEmpty;

  testWidgets('opening the leads shows them (as before)', (tester) async {
    await _open(tester);
    expect(find.text('Alpha Bakery'), findsOneWidget);
    expect(find.text('Beta Tailors'), findsOneWidget);
    expect(open('Asif'), isFalse, reason: 'collapsed to begin with');

    await tester.tap(_leadsButtons.first);
    await _settle(tester);
    expect(open('Asif'), isTrue);
    expect(open('Bilal'), isTrue);
    expect(open('Chand'), isFalse, reason: 'that is the other business');
    expect(find.byIcon(Icons.expand_less), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('leave the tab and come back: the leads are collapsed again', (tester) async {
    final active = await _open(tester);
    await tester.tap(_leadsButtons.first);
    await _settle(tester);
    expect(open('Asif'), isTrue);

    // To another tab: already closed while out of sight, so nothing flashes open on return.
    active.value = false;
    await _settle(tester);
    expect(open('Asif'), isFalse, reason: 'closed as soon as the tab is left');

    active.value = true;
    await _settle(tester);
    expect(open('Asif'), isFalse);
    expect(open('Bilal'), isFalse);
    expect(find.byIcon(Icons.expand_less), findsNothing);
    expect(find.byIcon(Icons.expand_more), findsNWidgets(2), reason: 'both Leads buttons point down');
    expect(tester.takeException(), isNull);
  });

  testWidgets('every time: open, leave, come back, again and again', (tester) async {
    final active = await _open(tester);
    for (var round = 1; round <= 4; round++) {
      await tester.tap(_leadsButtons.at(round.isEven ? 1 : 0)); // the businesses in turn
      await _settle(tester);
      expect(find.byIcon(Icons.expand_less), findsOneWidget, reason: 'round $round: opened');

      active.value = false;
      await _settle(tester);
      active.value = true;
      await _settle(tester);
      expect(find.byIcon(Icons.expand_less), findsNothing, reason: 'round $round: collapsed on return');
      expect(open('Asif') || open('Chand'), isFalse, reason: 'round $round');
    }
  });

  testWidgets('whichever business is open is collapsed, and opening works again after', (tester) async {
    final active = await _open(tester);
    await tester.tap(_leadsButtons.first);
    await _settle(tester);
    await tester.tap(_leadsButtons.last); // the other one: the first closes (one at a time, as before)
    await _settle(tester);
    expect(open('Chand'), isTrue);
    expect(open('Asif'), isFalse);

    active.value = false;
    await _settle(tester);
    active.value = true;
    await _settle(tester);
    expect(open('Chand'), isFalse);

    await tester.tap(_leadsButtons.last);
    await _settle(tester);
    expect(open('Chand'), isTrue, reason: 'it opens again');
  });

  testWidgets('only the open/closed mark is reset: the leads and the revealed number are kept', (tester) async {
    final active = await _open(tester);
    // The lead count on the button, before and after.
    expect(find.descendant(of: _leadsButtons.first, matching: find.text('2')), findsOneWidget);

    await tester.tap(_leadsButtons.first);
    await _settle(tester);
    expect(find.text('+91  9876543210'), findsOneWidget, reason: 'Bilal was already revealed');

    active.value = false;
    await _settle(tester);
    active.value = true;
    await _settle(tester);
    expect(find.descendant(of: _leadsButtons.first, matching: find.text('2')), findsOneWidget,
        reason: 'the lead count is unchanged');
    expect(find.descendant(of: _leadsButtons.last, matching: find.text('1')), findsOneWidget);

    await tester.tap(_leadsButtons.first);
    await _settle(tester);
    expect(open('Asif'), isTrue);
    expect(find.text('+91  9876543210'), findsOneWidget, reason: 'the revealed number is still there, not charged again');
  });

  testWidgets('leaving asks the server for nothing; coming back does only the refresh it always did', (tester) async {
    final active = await _open(tester);
    await tester.tap(_leadsButtons.first);
    await _settle(tester);

    final before = List.of(net.calls);
    active.value = false;
    await _settle(tester);
    expect(net.calls, before, reason: 'leaving: no request at all');

    active.value = true;
    await _settle(tester);
    final added = net.calls.sublist(before.length);
    expect(added.where((c) => c == 'GET /rest/v1/vendors'), hasLength(1));
    expect(added.where((c) => c == 'POST /functions/v1/get-lead-names'), hasLength(1));
    expect(added.length, lessThanOrEqualTo(4), reason: 'the one quiet refresh (and the balance), nothing more');
  });

  testWidgets('staying on the tab, or a rebuild of it, does not close anything', (tester) async {
    final active = await _open(tester);
    await tester.tap(_leadsButtons.first);
    await _settle(tester);

    active.value = true; // no change
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(open('Asif'), isTrue);
    expect(find.byIcon(Icons.expand_less), findsOneWidget);
  });
}
