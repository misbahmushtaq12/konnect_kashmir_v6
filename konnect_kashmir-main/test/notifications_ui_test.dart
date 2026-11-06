import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/l10n/l10n.dart';
import 'package:konnect_kashmir/screens/notifications_screen.dart';
import 'package:konnect_kashmir/services/notifications/inbox_service.dart';
import 'package:konnect_kashmir/theme/app_theme.dart';
import 'package:konnect_kashmir/widgets/notification_bell.dart';
import 'package:provider/provider.dart';

import 'support/fake_inbox_backend.dart';

late FakeInboxBackend _backend;
late InboxController _inbox;

Future<void> _show(
  WidgetTester tester, {
  Widget? home,
  ThemeData? theme,
  Locale locale = const Locale('en'),
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<InboxController>.value(
      value: _inbox,
      child: MaterialApp(
        theme: theme ?? AppTheme.light,
        locale: locale,
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
        home:
            home ??
            Scaffold(
              body: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: const [NotificationBell()],
                ),
              ),
            ),
      ),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// A few messages the way the server writes them.
void _threeMessages() {
  _backend.rows.addAll([
    note(
      'pending',
      type: 'photo_pending',
      title: 'Photo submitted',
      body: 'Your photo for Orchid Cab Services is under review.',
      at: DateTime.now().subtract(const Duration(days: 2)),
    ),
    note(
      'rejected',
      type: 'photo_rejected',
      title: 'Photo not approved',
      body:
          'Your photo for Orchid Cab Services was not approved: Not a photo of this business.',
      at: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    note(
      'approved',
      type: 'photo_approved',
      title: 'Photo approved',
      body: 'Your photo for Orchid Cab Services is now live.',
      at: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
  ]);
}

void main() {
  setUp(() {
    _backend = FakeInboxBackend();
    _inbox = InboxController(backend: _backend);
  });

  tearDown(() => _inbox.dispose());

  group('the bell', () {
    testWidgets('is not drawn for a signed-out user', (tester) async {
      await _show(tester);
      expect(find.byType(NotificationBell), findsOneWidget);
      expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);
      expect(find.byIcon(Icons.notifications_rounded), findsNothing);
    });

    testWidgets(
      'on a screen that has no notifications at all it draws nothing, '
      'and does not fail',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: NotificationBell())),
        );
        await tester.pump();
        expect(find.byType(NotificationBell), findsOneWidget);
        expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('is not drawn when the server has no notifications', (
      tester,
    ) async {
      _backend.unavailable = true;
      _inbox.setUser('u1');
      await _show(tester);
      expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);
    });

    testWidgets('with nothing unread: a quiet bell, no number', (tester) async {
      _inbox.setUser('u1');
      await _show(tester);
      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('with unread messages: the number on it', (tester) async {
      _threeMessages();
      _inbox.setUser('u1');
      await _show(tester);
      expect(find.byIcon(Icons.notifications_rounded), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('a hundred or more shows 99+', (tester) async {
      for (var i = 0; i < 120; i++) {
        _backend.rows.add(note('n$i'));
      }
      _inbox.setUser('u1');
      await _show(tester);
      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('is an easy target and is read out with its count', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      _threeMessages();
      _inbox.setUser('u1');
      await _show(tester);
      expect(tester.getSize(find.byType(NotificationBell)), const Size(44, 44));
      expect(find.bySemanticsLabel('Notifications, 3 unread'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a tap opens the list; coming back asks for the count again', (
      tester,
    ) async {
      _threeMessages();
      _inbox.setUser('u1');
      await _show(tester);
      await tester.tap(find.byType(NotificationBell));
      await _settle(tester);
      expect(find.byType(NotificationsScreen), findsOneWidget);
      expect(find.text('Photo approved'), findsOneWidget);

      _backend.rows.add(note('more', title: 'Another one'));
      _backend.calls.clear();
      await tester.pageBack();
      await _settle(tester);
      expect(find.byType(NotificationsScreen), findsNothing);
      expect(_backend.calls.where((c) => c.startsWith('count')), isNotEmpty);
    });
  });

  group('the list', () {
    Future<void> open(
      WidgetTester tester, {
      Size size = const Size(390, 844),
      ThemeData? theme,
      Locale locale = const Locale('en'),
      double textScale = 1,
    }) async {
      _inbox.setUser('u1');
      await _show(
        tester,
        home: const NotificationsScreen(),
        size: size,
        theme: theme,
        locale: locale,
        textScale: textScale,
      );
      await _settle(tester);
    }

    testWidgets('has the newest first, each naming the business', (
      tester,
    ) async {
      _threeMessages();
      await open(tester);
      final titles = [
        'Photo approved',
        'Photo not approved',
        'Photo submitted',
      ];
      final ys = [for (final t in titles) tester.getTopLeft(find.text(t)).dy];
      expect(ys[0], lessThan(ys[1]));
      expect(ys[1], lessThan(ys[2]));
      expect(find.textContaining('Orchid Cab Services'), findsNWidgets(3));
      expect(
        find.text(
          'Your photo for Orchid Cab Services was not approved: Not a photo of this business.',
        ),
        findsOneWidget,
      );
      expect(find.text('5 min ago'), findsOneWidget);
      expect(find.text('3 hours ago'), findsOneWidget);
      expect(find.text('2 days ago'), findsOneWidget);
    });

    testWidgets(
      'unread ones are marked; a tap reads one and the bell follows',
      (tester) async {
        _threeMessages();
        await open(tester);
        expect(find.byKey(const ValueKey('unread-dot')), findsNWidgets(3));

        await tester.tap(find.text('Photo approved'));
        await _settle(tester);
        expect(find.byKey(const ValueKey('unread-dot')), findsNWidgets(2));
        expect(_inbox.unread, 2);
        expect(_backend.rows.where((n) => n.isRead).map((n) => n.id), [
          'approved',
        ]);
      },
    );

    testWidgets(
      '"Mark all as read" is there while something is unread, and clears all',
      (tester) async {
        _threeMessages();
        await open(tester);
        expect(find.text('Mark all as read'), findsOneWidget);
        await tester.tap(find.text('Mark all as read'));
        await _settle(tester);
        expect(find.byKey(const ValueKey('unread-dot')), findsNothing);
        expect(find.text('Mark all as read'), findsNothing);
        expect(_inbox.unread, 0);
      },
    );

    testWidgets('read ones are not marked, and need no "mark all"', (
      tester,
    ) async {
      _backend.rows.add(note('a', read: true));
      await open(tester);
      expect(find.byKey(const ValueKey('unread-dot')), findsNothing);
      expect(find.text('Mark all as read'), findsNothing);
    });

    testWidgets(
      'a tap on a photo message in a test (no app shell) just marks it read',
      (tester) async {
        _threeMessages();
        await open(tester);
        await tester.tap(find.text('Photo not approved'));
        await _settle(tester);
        expect(tester.takeException(), isNull);
        expect(find.byType(NotificationsScreen), findsOneWidget);
      },
    );

    testWidgets('empty: says so', (tester) async {
      await open(tester);
      expect(find.text('No notifications yet'), findsOneWidget);
      expect(
        find.text(
          'When something changes for your business, you will see it here.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('while loading: a spinner', (tester) async {
      _backend.gate = Completer<void>();
      _inbox.setUser('u1');
      await _show(tester, home: const NotificationsScreen());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      _backend.gate!.complete();
      await _settle(tester);
    });

    testWidgets('trouble: Retry loads again', (tester) async {
      _threeMessages();
      _backend.failList = true;
      await open(tester);
      expect(find.text('Retry'), findsOneWidget);
      _backend.failList = false;
      await tester.tap(find.text('Retry'));
      await _settle(tester);
      expect(find.text('Photo approved'), findsOneWidget);
    });

    testWidgets('pulling down loads it again', (tester) async {
      await open(tester);
      _backend.rows.add(note('late', title: 'A late one'));
      await tester.fling(
        find.byType(Scrollable).first,
        const Offset(0, 400),
        1000,
      );
      await _settle(tester);
      expect(find.text('A late one'), findsOneWidget);
    });

    for (final (w, h) in [
      (375.0, 667.0),
      (390.0, 844.0),
      (768.0, 1024.0),
      (1024.0, 768.0),
      (1440.0, 900.0),
    ]) {
      for (final dark in [false, true]) {
        testWidgets(
          '${w.toInt()}px, ${dark ? 'dark' : 'light'}: fits, no overlap, easy to tap',
          (tester) async {
            for (var i = 0; i < 12; i++) {
              _backend.rows.add(
                note(
                  'n$i',
                  type: [
                    'photo_pending',
                    'photo_approved',
                    'photo_rejected',
                    'other',
                  ][i % 4],
                  title: 'Photo not approved',
                  body:
                      'Your photo for Sheikh Mohammad Abdullah and Sons General Merchants and Tour Operators was not approved: Contains text or logo not allowed.',
                  at: DateTime.now().subtract(Duration(hours: i + 1)),
                  read: i.isOdd,
                ),
              );
            }
            await open(
              tester,
              size: Size(w, h),
              theme: dark ? AppTheme.dark : AppTheme.light,
            );
            expect(tester.takeException(), isNull);

            final tiles = find.byKey(const ValueKey('notification-n0'));
            expect(tiles, findsOneWidget);
            final screen = Rect.fromLTWH(0, 0, w, h);
            for (final id in ['n0', 'n1', 'n2']) {
              final r = tester.getRect(
                find.byKey(ValueKey('notification-$id')),
              );
              expect(screen.contains(r.topLeft), isTrue);
              expect(
                r.right,
                lessThanOrEqualTo(w),
                reason: 'no sideways scroll',
              );
              expect(r.height, greaterThanOrEqualTo(44));
              expect(r.width, lessThanOrEqualTo(680));
            }
            // The title, text and time sit inside their tile, one above the other.
            final tile = tester.getRect(
              find.byKey(const ValueKey('notification-n0')),
            );
            for (final t in tester.widgetList<Text>(
              find.descendant(
                of: find.byKey(const ValueKey('notification-n0')),
                matching: find.byType(Text),
              ),
            )) {
              final r = tester.getRect(find.byWidget(t));
              expect(r.left, greaterThanOrEqualTo(tile.left));
              expect(r.right, lessThanOrEqualTo(tile.right));
            }
            final first = tester.getRect(
              find.byKey(const ValueKey('notification-n0')),
            );
            final second = tester.getRect(
              find.byKey(const ValueKey('notification-n1')),
            );
            expect(
              second.top,
              greaterThanOrEqualTo(first.bottom),
              reason: 'no overlap',
            );
            // "Mark all as read" is a proper button.
            final button = tester.getSize(
              find.ancestor(
                of: find.text('Mark all as read'),
                matching: find.byType(TextButton),
              ),
            );
            expect(button.height, greaterThanOrEqualTo(48));
            expect(button.width, greaterThanOrEqualTo(48));
            // On a wide screen the list keeps a readable width, in the middle.
            if (w > 700) {
              expect(first.center.dx, closeTo(w / 2, 1));
            }
          },
        );
      }
    }

    for (final code in ['hi', 'ur']) {
      testWidgets('$code, a small phone with large text: fits', (tester) async {
        _threeMessages();
        await open(
          tester,
          size: const Size(320, 568),
          locale: Locale(code),
          textScale: 1.6,
        );
        expect(tester.takeException(), isNull);
        final l = AppLocalizations.of(
          tester.element(find.byType(NotificationsScreen)),
        );
        expect(find.text(l.notificationsTitle), findsOneWidget);
        expect(find.text(l.markAllRead), findsOneWidget);
      });
    }
  });
}
