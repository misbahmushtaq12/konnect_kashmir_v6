import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/services/app_analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Sink implements AnalyticsSink {
  final events = <({String name, Map<String, Object> params})>[];
  final screens = <String>[];
  final userIds = <String?>[];
  final props = <String, String?>{};
  bool throws = false;

  @override
  Future<void> logEvent(String name, Map<String, Object> params) async {
    if (throws) throw Exception('no network');
    events.add((name: name, params: params));
  }

  @override
  Future<void> logScreen(String name) async {
    if (throws) throw Exception('no network');
    screens.add(name);
  }

  @override
  Future<void> setUserId(String? id) async => userIds.add(id);

  @override
  Future<void> setUserProperty(String name, String? value) async =>
      props[name] = value;

  List<String> names([String? only]) => [
    for (final e in events)
      if (only == null || e.name == only) e.name,
  ];

  Map<String, Object> last(String name) =>
      events.lastWhere((e) => e.name == name).params;
}

class DemoSettingsScreen extends StatelessWidget {
  const DemoSettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('settings'));
}

class DemoWalletTab extends StatelessWidget {
  const DemoWalletTab({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('wallet'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('nothing is sent until it is started', () {
    test('events, screens and users before start are dropped', () async {
      final sink = _Sink();
      final a = AppAnalytics(sink: sink);
      a.event('share');
      a.screen('home');
      a.setUser('u1', 'customer');
      await pumpEventQueue();
      expect(sink.events, isEmpty);
      expect(sink.screens, isEmpty);
      expect(sink.userIds, isEmpty);
    });
  });

  group('opens', () {
    test('the first start logs app_open and one daily_open', () async {
      final sink = _Sink();
      AppAnalytics(sink: sink, clock: () => DateTime(2026, 10, 27, 9)).start();
      await pumpEventQueue();
      expect(sink.names(), ['app_open', 'daily_open']);
      expect(sink.last('app_open'), {'how': 'launch'});
      expect(sink.last('daily_open'), {'streak': 1, 'days_since_first': 0});
    });

    test('coming back within 30 minutes is not a new open', () async {
      final sink = _Sink();
      var now = DateTime(2026, 10, 27, 9);
      final a = AppAnalytics(sink: sink, clock: () => now)..start();
      await pumpEventQueue();
      now = now.add(const Duration(minutes: 20));
      a.resumed();
      await pumpEventQueue();
      expect(sink.names('app_open').length, 1);
    });

    test(
      'after 30 minutes it is an open again, but not a second daily_open',
      () async {
        final sink = _Sink();
        var now = DateTime(2026, 10, 27, 9);
        final a = AppAnalytics(sink: sink, clock: () => now)..start();
        await pumpEventQueue();
        now = now.add(const Duration(minutes: 45));
        a.resumed();
        await pumpEventQueue();
        expect(sink.names('app_open').length, 2);
        expect(sink.last('app_open'), {'how': 'resume'});
        expect(sink.names('daily_open').length, 1, reason: 'same day');
      },
    );

    test(
      'daily_open counts the days in a row and the age of the install',
      () async {
        final sink = _Sink();
        var now = DateTime(2026, 10, 27, 23, 50);
        final a = AppAnalytics(sink: sink, clock: () => now)..start();
        await pumpEventQueue();

        now = DateTime(2026, 10, 28, 0, 20); // just after midnight: a new day
        a.resumed();
        await pumpEventQueue();
        expect(sink.last('daily_open'), {'streak': 2, 'days_since_first': 1});

        now = DateTime(2026, 10, 29, 8);
        a.resumed();
        await pumpEventQueue();
        expect(sink.last('daily_open'), {'streak': 3, 'days_since_first': 2});

        now = DateTime(2026, 11, 2, 8); // days missed: the streak starts again
        a.resumed();
        await pumpEventQueue();
        expect(sink.last('daily_open'), {'streak': 1, 'days_since_first': 6});
        expect(sink.names('daily_open').length, 4);
      },
    );

    test('the day is remembered across app restarts', () async {
      final sink = _Sink();
      final now = DateTime(2026, 10, 27, 9);
      AppAnalytics(sink: sink, clock: () => now).start();
      await pumpEventQueue();
      // A second process the same day.
      AppAnalytics(sink: sink, clock: () => now).start();
      await pumpEventQueue();
      expect(sink.names('daily_open').length, 1);
      expect(sink.names('app_open').length, 2);
    });
  });

  group('screens', () {
    test(
      'the same screen twice in a row is one view; tabs set the current tab',
      () async {
        final sink = _Sink();
        final a = AppAnalytics(sink: sink, started: true);
        a.screen('login');
        a.screen('login');
        a.tab('deen');
        a.tab('deen');
        a.screen('login');
        await pumpEventQueue();
        expect(sink.screens, ['login', 'deen', 'login']);
        expect(a.currentTab, 'deen');
      },
    );

    test('screen names come from routes and widget names', () {
      expect(
        AppRouteObserver.screenNameFromType('BusinessDetailsScreen'),
        'business_details',
      );
      expect(AppRouteObserver.screenNameFromType('MyBusinessTab'), 'my_business');
      expect(AppRouteObserver.screenNameFromType('RefundPage'), 'refund');
      expect(AppRouteObserver.screenNameFromType('MainShell'), 'main_shell');
      expect(AppRouteObserver.screenNameFromType('Scaffold'), isNull);
      expect(AppRouteObserver.screenNameFromType('Tab'), isNull);
      expect(
        AppRouteObserver.screenNameFromType('aB'),
        isNull,
        reason: 'obfuscated',
      );
      expect(AppRouteObserver.routeScreenName('/login'), 'login');
      expect(
        AppRouteObserver.routeScreenName('/register-vendor'),
        'register_vendor',
      );
      expect(AppRouteObserver.routeScreenName('/'), 'splash');
      expect(
        AppRouteObserver.routeScreenName('/vendor/dashboard?x=1'),
        'vendor_dashboard',
      );
      expect(AppRouteObserver.routeScreenName(null), isNull);
    });

    testWidgets('pushing and going back are logged; dialogs are not', (
      tester,
    ) async {
      final sink = _Sink();
      final a = AppAnalytics(sink: sink, started: true);
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          navigatorObservers: [AppRouteObserver(analytics: () => a)],
          home: const Scaffold(body: Text('start')),
        ),
      );
      await tester.pump();
      expect(sink.screens, ['splash'], reason: 'the first route is named /');

      nav.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const DemoSettingsScreen()),
      );
      await tester.pumpAndSettle();
      expect(sink.screens, ['splash', 'demo_settings']);

      nav.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const DemoWalletTab()),
      );
      await tester.pumpAndSettle();
      expect(sink.screens.last, 'demo_wallet');

      showDialog<void>(
        context: nav.currentContext!,
        builder: (_) => const AlertDialog(title: Text('hi')),
      );
      await tester.pumpAndSettle();
      expect(
        sink.screens.last,
        'demo_wallet',
        reason: 'a dialog is not a screen',
      );
      nav.currentState!.pop(); // the dialog
      await tester.pumpAndSettle();
      expect(sink.screens.last, 'demo_wallet');

      nav.currentState!.pop(); // back to settings
      await tester.pumpAndSettle();
      expect(sink.screens.last, 'demo_settings');
    });

    testWidgets('the shell route logs whichever tab is showing', (
      tester,
    ) async {
      final sink = _Sink();
      final a = AppAnalytics(sink: sink, started: true)..tab('profile');
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          navigatorObservers: [AppRouteObserver(analytics: () => a)],
          routes: {'/home': (_) => const Scaffold(body: Text('shell'))},
          home: const Scaffold(body: Text('start')),
        ),
      );
      a.tab('deen');
      nav.currentState!.pushNamed('/home');
      await tester.pumpAndSettle();
      expect(sink.screens.last, 'deen');
    });
  });

  group('who', () {
    test(
      'signing in sets the id and role; signing out logs logout and clears them',
      () async {
        final sink = _Sink();
        final a = AppAnalytics(sink: sink, started: true);
        a.setUser('u-1', 'customer');
        a.setUser('u-1', 'customer'); // a repeat changes nothing
        await pumpEventQueue();
        expect(sink.userIds, ['u-1']);
        expect(sink.props['user_role'], 'customer');

        a.setUser('u-1', 'vendor'); // the role changed
        await pumpEventQueue();
        expect(sink.userIds, ['u-1']);
        expect(sink.props['user_role'], 'vendor');

        a.setUser(null, null);
        await pumpEventQueue();
        expect(sink.userIds, ['u-1', null]);
        expect(sink.props['user_role'], isNull);
        expect(sink.names('logout').length, 1);
      },
    );

    test('the language is a user property', () async {
      final sink = _Sink();
      AppAnalytics(sink: sink, started: true).setLanguage('ur');
      await pumpEventQueue();
      expect(sink.props['app_language'], 'ur');
    });
  });

  group('events', () {
    test(
      'empty values are left out, long text is cut, bools become 1 and 0',
      () async {
        final sink = _Sink();
        final a = AppAnalytics(sink: sink, started: true);
        a.event('x', {
          'a': 'ok',
          'b': null,
          'c': '   ',
          'd': 'z' * 150,
          'e': true,
          'f': false,
          'g': 7,
          'h': ['not', 'allowed'],
        });
        await pumpEventQueue();
        final p = sink.last('x');
        expect(p.keys.toSet(), {'a', 'd', 'e', 'f', 'g'});
        expect((p['d'] as String).length, 100);
        expect(p['e'], 1);
        expect(p['f'], 0);
      },
    );

    test('the key actions use the agreed names and fields', () async {
      final sink = _Sink();
      final a = AppAnalytics(sink: sink, started: true);
      a.signedIn(newUser: false);
      a.signedIn(newUser: true);
      a.viewBusiness('b1', category: 'plumber');
      a.contactBusiness('call', 'b1');
      a.unlockContact('b1');
      a.shareBusiness('b1');
      a.search(category: 'plumber', results: 12, hasText: true);
      a.prayerAlarm(enabled: true);
      await pumpEventQueue();
      expect(sink.names(), [
        'login',
        'sign_up',
        'view_business',
        'contact_business',
        'unlock_contact',
        'share',
        'search',
        'prayer_alarm_toggle',
      ]);
      expect(sink.last('contact_business'), {
        'method': 'call',
        'business_id': 'b1',
      });
      expect(sink.last('search'), {
        'category': 'plumber',
        'results_count': 12,
        'has_text': 1,
      });
      expect(sink.last('share'), {
        'content_type': 'business',
        'item_id': 'b1',
        'method': 'share_sheet',
      });
    });

    test('the words that were searched for are never sent', () async {
      final sink = _Sink();
      AppAnalytics(
        sink: sink,
        started: true,
      ).search(category: 'plumber', results: 3, hasText: true);
      await pumpEventQueue();
      expect(sink.last('search').containsKey('search_term'), isFalse);
    });

    test('a failing network never throws into the app', () async {
      final sink = _Sink()..throws = true;
      final a = AppAnalytics(sink: sink, started: true);
      a.event('x');
      a.screen('login');
      a.setUser('u', 'customer');
      await pumpEventQueue();
      expect(true, isTrue); // reaching here is the test
    });
  });
}
