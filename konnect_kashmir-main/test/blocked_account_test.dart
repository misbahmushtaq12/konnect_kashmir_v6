import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/l10n/l10n.dart';
import 'package:konnect_kashmir/providers/auth_provider.dart';
import 'package:konnect_kashmir/screens/blocked_account_screen.dart';
import 'package:konnect_kashmir/services/api_service.dart';
import 'package:konnect_kashmir/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef _Flag = ({bool blocked, String? reason})?;

Future<AuthProvider> _signedIn(
  Future<_Flag> Function(String id, String token) lookup, {
  String id = 'user-1',
}) async {
  final a = AuthProvider()..blockLookup = lookup;
  await a.setSession('token-1', id, phone: '+91 1234567890', role: 'customer');
  return a;
}

Widget _app(Widget home, {Locale? locale, double scale = 1}) => MaterialApp(
  theme: AppTheme.light,
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: home,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the app asks whether the account is blocked', () {
    test('not blocked: nothing changes and nobody is told', () async {
      final calls = <String>[];
      final a = await _signedIn((id, token) async {
        calls.add('$id/$token');
        return (blocked: false, reason: null);
      });
      var told = 0;
      a.addListener(() => told++);
      await a.checkBlocked(force: true);
      expect(a.isBlocked, isFalse);
      expect(calls, ['user-1/token-1']);
      expect(told, 0);
      a.dispose();
    });

    test('blocked: the flag and the admin\'s reason are kept, listeners told once', () async {
      final a = await _signedIn(
        (_, __) async => (blocked: true, reason: '  Misuse of contacts  '),
      );
      var told = 0;
      a.addListener(() => told++);
      await a.checkBlocked(force: true);
      expect(a.isBlocked, isTrue);
      expect(a.blockedReason, 'Misuse of contacts');
      expect(told, 1);
      await a.checkBlocked(force: true); // same answer: nothing to tell
      expect(told, 1);
      a.dispose();
    });

    test('a blank reason is no reason', () async {
      final a = await _signedIn((_, __) async => (blocked: true, reason: null));
      await a.checkBlocked(force: true);
      expect(a.isBlocked, isTrue);
      expect(a.blockedReason, isNull);
      a.dispose();
    });

    test('unblocked later: the block goes away by itself', () async {
      var blocked = true;
      final a = await _signedIn(
        (_, __) async => (blocked: blocked, reason: blocked ? 'x' : null),
      );
      await a.checkBlocked(force: true);
      expect(a.isBlocked, isTrue);
      blocked = false;
      await a.checkBlocked(force: true);
      expect(a.isBlocked, isFalse);
      expect(a.blockedReason, isNull);
      a.dispose();
    });

    test('a lookup that fails neither blocks nor unblocks anyone', () async {
      var answer = (blocked: true, reason: 'x');
      var fail = false;
      final a = await _signedIn((_, __) async => fail ? null : answer);
      await a.checkBlocked(force: true);
      expect(a.isBlocked, isTrue);
      fail = true; // offline
      await a.checkBlocked(force: true);
      expect(a.isBlocked, isTrue, reason: 'still blocked when the answer is unknown');

      final b = await _signedIn((_, __) async => null);
      await b.checkBlocked(force: true);
      expect(b.isBlocked, isFalse, reason: 'an unknown answer never locks anyone out');
      a.dispose();
      b.dispose();
    });

    test('it is not asked more than once a minute, unless forced', () async {
      var n = 0;
      final a = await _signedIn((_, __) async {
        n++;
        return (blocked: false, reason: null);
      });
      await a.checkBlocked();
      await a.checkBlocked();
      await a.checkBlocked();
      expect(n, 1);
      await a.checkBlocked(force: true);
      expect(n, 2);
      a.dispose();
    });

    test('nobody signed in: nothing is asked', () async {
      var n = 0;
      final a = AuthProvider()
        ..blockLookup = (_, __) async {
          n++;
          return (blocked: true, reason: null);
        };
      await a.checkBlocked(force: true);
      expect(n, 0);
      expect(a.isBlocked, isFalse);
      a.dispose();
    });

    test('an answer for an account that has since been replaced is ignored', () async {
      final gate = Completer<_Flag>();
      final a = await _signedIn((id, _) => id == 'user-1'
          ? gate.future
          : Future<_Flag>.value((blocked: false, reason: null)));
      final pending = a.checkBlocked(force: true);
      await a.setSession('token-2', 'user-2', role: 'customer'); // another account
      gate.complete((blocked: true, reason: 'old account'));
      await pending;
      expect(a.isBlocked, isFalse);
      a.dispose();
    });
  });

  group('a lookup that failed is tried again', () {
    testWidgets('the retry finds a block that the first try could not see', (tester) async {
      var calls = 0;
      late AuthProvider a;
      await tester.runAsync(() async {
        a = await _signedIn((_, __) async {
          calls++;
          return calls == 1 ? null : (blocked: true, reason: 'x');
        });
      });
      await a.checkBlocked(force: true);
      expect(calls, 1);
      expect(a.isBlocked, isFalse);
      await tester.pump(const Duration(seconds: 31)); // the first retry is due after 30 s
      await tester.pump();
      expect(calls, 2);
      expect(a.isBlocked, isTrue);
      a.dispose();
    });

    testWidgets('it gives up after three retries', (tester) async {
      var calls = 0;
      late AuthProvider a;
      await tester.runAsync(() async {
        a = await _signedIn((_, __) async {
          calls++;
          return null;
        });
      });
      await a.checkBlocked(force: true);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 120));
        await tester.pump();
      }
      expect(calls, 4, reason: 'the first try and three retries');
      a.dispose();
    });
  });

  group('before an important action', () {
    test('nobody signed in: the action may go on, nothing is asked', () async {
      var n = 0;
      final a = AuthProvider()
        ..blockLookup = (_, __) async {
          n++;
          return (blocked: true, reason: null);
        };
      expect(await a.ensureNotBlocked(), isTrue);
      expect(n, 0);
      a.dispose();
    });

    test('a blocked account may not, and nothing more is asked', () async {
      var n = 0;
      final a = await _signedIn((_, __) async {
        n++;
        return (blocked: true, reason: 'x');
      });
      expect(await a.ensureNotBlocked(), isFalse);
      expect(await a.ensureNotBlocked(), isFalse);
      expect(n, 1);
      a.dispose();
    });

    test('an account that was blocked just now is stopped before the action', () async {
      var blocked = false;
      final a = await _signedIn((_, __) async => (blocked: blocked, reason: null));
      await a.checkBlocked(force: true);
      blocked = true; // an admin blocks it
      // Within 10 seconds of the last look the old answer stands...
      expect(await a.ensureNotBlocked(), isTrue);
      // ...after that the action looks again.
      await a.checkBlocked(force: true);
      expect(await a.ensureNotBlocked(), isFalse);
      a.dispose();
    });

    testWidgets('a lookup that hangs never holds the action up for more than 3 seconds', (tester) async {
      late AuthProvider a;
      await tester.runAsync(() async {
        a = await _signedIn((_, __) => Completer<_Flag>().future); // never answers
      });
      var done = false;
      bool? result;
      a.ensureNotBlocked().then((v) {
        result = v;
        done = true;
      });
      await tester.pump(const Duration(seconds: 2));
      expect(done, isFalse);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(done, isTrue);
      expect(result, isTrue, reason: 'unknown: the server decides');
      a.dispose();
    });
  });

  group('the app\'s actions are stopped for a blocked account', () {
    tearDown(() => ApiService.mayAct = null);

    test('all eight go no further than the check, and say why', () async {
      ApiService.mayAct = () async => false;
      final api = ApiService(token: 't', userId: 'u');
      final results = <String, Map<String, dynamic>>{
        'unlock': await api.unlockVendorContact('v'),
        'credits': await api.claimAdCredits('a'),
        'createVendor': await api.createVendor({}),
        'updateVendor': await api.updateVendor('v', {}),
        'review': await api.submitReview('v', 5, 'good'),
        'createJob': await api.createJob({}),
        'apply': await api.applyToJob('j', 'n', 'p', 'e', 'c'),
        'report': await api.submitReport(null, null, 'spam', 'text'),
      };
      for (final e in results.entries) {
        expect(e.value['success'], isFalse, reason: e.key);
        expect(e.value['error'], 'Your account has been blocked.', reason: e.key);
      }
    });

    test('a check that throws does not stop anything (the server decides)', () async {
      ApiService.mayAct = () async => throw Exception('boom');
      final api = ApiService(token: 't', userId: null);
      // userId null: submitReport stops at its own sign-in check, without any network.
      final r = await api.submitReport(null, null, 'spam', 'text');
      expect(r['error'], isNot('Your account has been blocked.'));
    });
  });

  group('the blocked screen', () {
    testWidgets('says so, shows the reason, offers support and sign out', (tester) async {
      var signedOut = 0;
      var contacted = 0;
      await tester.pumpWidget(
        _app(
          BlockedAccountScreen(
            reason: 'Misuse of contacts',
            onSignOut: () => signedOut++,
            onContact: () async => contacted++,
          ),
        ),
      );
      expect(find.text('Account Blocked'), findsOneWidget);
      expect(
        find.text('Your account has been blocked for misuse or policy violation.'),
        findsOneWidget,
      );
      expect(find.text('Reason: Misuse of contacts'), findsOneWidget);
      await tester.tap(find.text('Contact support'));
      await tester.tap(find.text('Sign out'));
      expect(contacted, 1);
      expect(signedOut, 1);
    });

    testWidgets('no reason, no reason line', (tester) async {
      await tester.pumpWidget(
        _app(BlockedAccountScreen(reason: null, onSignOut: () {}, onContact: () async {})),
      );
      expect(find.textContaining('Reason:'), findsNothing);
      expect(find.text('Account Blocked'), findsOneWidget);
    });

    testWidgets('fits in every language on a small screen with big text', (tester) async {
      tester.view.physicalSize = const Size(640, 1000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      for (final code in ['en', 'hi', 'ur']) {
        await tester.pumpWidget(
          _app(
            BlockedAccountScreen(
              reason: 'Misuse of contacts and repeated reports from other users',
              onSignOut: () {},
              onContact: () async {},
            ),
            locale: Locale(code),
            scale: 1.5,
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: code);
        expect(find.byIcon(Icons.block_rounded), findsOneWidget, reason: code);
      }
    });
  });

  group('the gate', () {
    testWidgets('shows the app until the account is blocked, then the blocked screen, and the app again when unblocked', (tester) async {
      var blocked = false;
      late AuthProvider auth;
      await tester.runAsync(() async {
        auth = await _signedIn(
          (_, __) async => (blocked: blocked, reason: blocked ? 'Misuse' : null),
        );
      });
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: _gatedApp(),
        ),
      );
      expect(find.text('THE APP'), findsOneWidget);
      expect(find.text('Account Blocked'), findsNothing);

      blocked = true;
      await tester.runAsync(() => auth.checkBlocked(force: true));
      await tester.pump();
      expect(find.text('Account Blocked'), findsOneWidget);
      expect(find.text('Reason: Misuse'), findsOneWidget);
      expect(find.text('THE APP'), findsNothing);

      blocked = false;
      await tester.runAsync(() => auth.checkBlocked(force: true));
      await tester.pump();
      expect(find.text('THE APP'), findsOneWidget);
      expect(find.text('Account Blocked'), findsNothing);
      auth.dispose();
    });
  });
}

/// An app whose navigator sits inside the gate, as main.dart builds it.
Widget _gatedApp() => MaterialApp(
  theme: AppTheme.light,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  builder: (context, child) => BlockedGate(child: child!),
  home: const Scaffold(body: Center(child: Text('THE APP'))),
);
