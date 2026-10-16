import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/main.dart';
import 'package:konnect_kashmir/providers/auth_provider.dart';
import 'package:konnect_kashmir/providers/locale_provider.dart';
import 'package:konnect_kashmir/providers/theme_provider.dart';
import 'package:konnect_kashmir/screens/leads_link_screen.dart';
import 'package:konnect_kashmir/screens/login_screen.dart';
import 'package:konnect_kashmir/screens/main_shell.dart';
import 'package:konnect_kashmir/screens/splash_screen.dart';
import 'package:konnect_kashmir/services/app_links.dart';
import 'package:konnect_kashmir/services/live_sync.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The link in the new-lead message.
const _smsLink = '/go?utm_campaign=new_lead';

/// The whole app. [signedIn] gives the app a signed-in user; its live-updates
/// service is kept on a separate signed-out auth so no Supabase is needed.
Future<Widget> _app({bool signedIn = false}) async {
  final auth = AuthProvider();
  if (signedIn) {
    await auth.setSession('token', 'user-1',
        phone: '9999999999', role: 'customer');
  }
  return KonnectKashmirApp(
    authProvider: auth,
    themeProvider: await ThemeProvider.load(),
    localeProvider: await LocaleProvider.load(),
    liveSync: LiveSync(AuthProvider()),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MainShell.tabRequest.value = null;
  });

  group('which links count', () {
    test('links that take the app to My Business', () {
      for (final ok in [
        _smsLink,
        '/go?utm_source=sms&utm_campaign=new_lead',
        'https://konnectkashmir.com/go?utm_campaign=new_lead',
        '/go/?utm_campaign=new_lead',
        // the older dashboard link
        '/vendor/dashboard',
        '/vendor/dashboard/',
        '/vendor/dashboard?src=sms',
        '/vendor/dashboard/leads',
        'https://www.konnectkashmir.com/vendor/dashboard',
        'https://konnectkashmir.com/vendor/dashboard?x=1#top',
      ]) {
        expect(AppLinks.isLeadsLink(ok), isTrue, reason: ok);
      }
    });

    test('other links do not ask for My Business', () {
      for (final no in [
        null,
        '',
        '/',
        '/home',
        '/go', // opens the app, but nothing says "leads"
        '/go?utm_campaign=promo',
        '/gone?utm_campaign=new_lead',
        '/vendor',
        '/vendor/dashboardx',
        '/vendors',
        '/dashboard',
        'https://konnectkashmir.com/',
      ]) {
        expect(AppLinks.isLeadsLink(no), isFalse, reason: '$no');
      }
    });

    test('every /go link and the old dashboard link open the app', () {
      for (final yes in [
        '/go',
        '/go?utm_campaign=promo',
        _smsLink,
        'https://konnectkashmir.com/go',
        '/vendor/dashboard',
      ]) {
        expect(AppLinks.isAppLink(yes), isTrue, reason: yes);
      }
      for (final no in [null, '', '/', '/home', '/gone', '/browse', '/dashboard']) {
        expect(AppLinks.isAppLink(no), isFalse, reason: '$no');
      }
    });
  });

  group('app started by the link, signed out', () {
    testWidgets('the SMS link: splash, then sign-in, and nothing is kept for '
        'after sign-in (so the user sees Home)', (tester) async {
      tester.platformDispatcher.defaultRouteNameTestValue = _smsLink;
      addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);

      await tester.pumpWidget(await _app());
      await tester.pump();

      // Only the splash is on the stack: the link does not pile a page on it.
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(LeadsLinkScreen), findsNothing);
      expect(Navigator.of(tester.element(find.byType(SplashScreen))).canPop(), isFalse);
      expect(MainShell.tabRequest.value, isNull);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(MainShell.tabRequest.value, isNull);
    });

    testWidgets('the older dashboard link behaves the same', (tester) async {
      tester.platformDispatcher.defaultRouteNameTestValue = '/vendor/dashboard';
      addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);

      await tester.pumpWidget(await _app());
      await tester.pump();
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(MainShell.tabRequest.value, isNull);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('a plain /go link just opens the app', (tester) async {
      tester.platformDispatcher.defaultRouteNameTestValue = '/go?utm_source=instagram';
      addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);

      await tester.pumpWidget(await _app());
      await tester.pump();
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(Navigator.of(tester.element(find.byType(SplashScreen))).canPop(), isFalse);
      expect(MainShell.tabRequest.value, isNull);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('a normal start asks for nothing special', (tester) async {
      await tester.pumpWidget(await _app());
      await tester.pump();
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(MainShell.tabRequest.value, isNull);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });

  group('app started by the link, signed in', () {
    testWidgets('the SMS link asks for My Business; a plain /go link does not',
        (tester) async {
      tester.platformDispatcher.defaultRouteNameTestValue = _smsLink;
      addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);

      await tester.pumpWidget(await _app(signedIn: true));
      await tester.pump();
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(MainShell.tabRequest.value, MainShell.tabMyBusiness);
      // Let the splash finish so no timer is left behind.
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('link arrives while the app is open, signed out', () {
    testWidgets('stays where it is and keeps nothing', (tester) async {
      await tester.pumpWidget(await _app());
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(LoginScreen), findsOneWidget);

      // What the phone does with an incoming link: push its address.
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      nav.pushNamed(_smsLink);
      await tester.pumpAndSettle();

      expect(find.byType(LeadsLinkScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(MainShell.tabRequest.value, isNull);
    });

    testWidgets('a plain /go link changes nothing', (tester) async {
      await tester.pumpWidget(await _app());
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 1));

      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      nav.pushNamed('/go?utm_source=instagram');
      await tester.pumpAndSettle();

      expect(find.byType(LeadsLinkScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(MainShell.tabRequest.value, isNull);
    });
  });

  // The signed-in route is checked on a small stand-in app: the real one builds
  // the whole main screen, which needs network and a running Supabase.
  group('link arrives while the app is open (stand-in app)', () {
    Future<void> pump(WidgetTester tester, AuthProvider auth, String link) async {
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
          home: const Text('splash'),
          onGenerateRoute: (s) => AppLinks.isAppLink(s.name)
              ? MaterialPageRoute<void>(
                  settings: s, builder: (_) => LeadsLinkScreen(route: s.name ?? ''))
              : null,
          routes: {'/home': (_) => const Text('the shell')},
        ),
      ));
      tester.state<NavigatorState>(find.byType(Navigator)).pushNamed(link);
      await tester.pumpAndSettle();
    }

    testWidgets('signed in, SMS link: goes to /home, My Business requested',
        (tester) async {
      final auth = AuthProvider();
      await auth.setSession('token', 'user-1',
          phone: '9999999999', role: 'customer');
      await pump(tester, auth, _smsLink);

      expect(find.text('the shell'), findsOneWidget);
      expect(find.byType(LeadsLinkScreen), findsNothing);
      expect(MainShell.tabRequest.value, MainShell.tabMyBusiness);
    });

    testWidgets('signed in, plain /go link: goes to /home, no tab asked for',
        (tester) async {
      final auth = AuthProvider();
      await auth.setSession('token', 'user-1',
          phone: '9999999999', role: 'customer');
      await pump(tester, auth, '/go');

      expect(find.text('the shell'), findsOneWidget);
      expect(MainShell.tabRequest.value, isNull);
    });

    testWidgets('signed out, SMS link: leaves, keeps nothing', (tester) async {
      await pump(tester, AuthProvider(), _smsLink);

      expect(find.text('splash'), findsOneWidget);
      expect(find.byType(LeadsLinkScreen), findsNothing);
      expect(MainShell.tabRequest.value, isNull);
    });
  });
}
