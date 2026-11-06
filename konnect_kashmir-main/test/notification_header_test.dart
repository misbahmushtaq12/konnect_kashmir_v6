import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/l10n/l10n.dart';
import 'package:konnect_kashmir/providers/auth_provider.dart';
import 'package:konnect_kashmir/providers/locale_provider.dart';
import 'package:konnect_kashmir/providers/theme_provider.dart';
import 'package:konnect_kashmir/screens/deen/weather_service.dart';
import 'package:konnect_kashmir/screens/main_shell.dart';
import 'package:konnect_kashmir/screens/my_business_tab.dart';
import 'package:konnect_kashmir/services/live_sync.dart';
import 'package:konnect_kashmir/services/notifications/inbox_service.dart';
import 'package:konnect_kashmir/theme/app_theme.dart';
import 'package:konnect_kashmir/widgets/floating_nav_bar.dart';
import 'package:konnect_kashmir/widgets/notification_bell.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_inbox_backend.dart';

void main() {
  late FakeInboxBackend backend;
  late InboxController inbox;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MainShell.tabRequest.value = null;
    WeatherService.reset();
    WeatherService.get = (_) async => throw Exception('offline');
    backend = FakeInboxBackend();
    inbox = InboxController(backend: backend);
  });

  tearDown(() {
    inbox.dispose();
    WeatherService.reset();
  });

  Future<void> shell(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final auth = AuthProvider();
    final locale = await tester.runAsync(LocaleProvider.load);
    final themes = await tester.runAsync(ThemeProvider.load);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<LocaleProvider>.value(value: locale!),
          ChangeNotifierProvider<ThemeProvider>.value(value: themes!),
          ChangeNotifierProvider<LiveSync>.value(value: LiveSync(auth)),
          ChangeNotifierProvider<InboxController>.value(value: inbox),
        ],
        child: MaterialApp(
          theme: theme ?? AppTheme.dark,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const MainShell(),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> openMyBusiness(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(FloatingNavBar),
        matching: find.byTooltip('My Business'),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets('My Business: the bell is in the header, with the unread count', (
    tester,
  ) async {
    backend.rows.addAll([note('a'), note('b')]);
    inbox.setUser('u1');
    await shell(tester);
    await openMyBusiness(tester);

    expect(find.byType(MyBusinessTab), findsOneWidget);
    expect(find.byType(NotificationBell), findsOneWidget);
    expect(find.byIcon(Icons.notifications_rounded), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    // The title of the header is where it was.
    expect(find.text('My Business'), findsWidgets);
    final bell = tester.getRect(find.byType(NotificationBell));
    expect(bell.size, const Size(44, 44));
    expect(bell.top, lessThan(120), reason: 'in the header, at the top');
    expect(bell.right, lessThanOrEqualTo(390));
    expect(tester.takeException(), isNull);
  });

  testWidgets('no bell, and nothing else changed, for a signed-out user', (
    tester,
  ) async {
    await shell(tester);
    await openMyBusiness(tester);
    expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);
    expect(find.byIcon(Icons.notifications_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no bell when the server has no notifications yet', (
    tester,
  ) async {
    backend.unavailable = true;
    inbox.setUser('u1');
    await shell(tester);
    await openMyBusiness(tester);
    expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);
  });

  for (final (w, h) in [(375.0, 667.0), (768.0, 1024.0), (1440.0, 900.0)]) {
    for (final dark in [false, true]) {
      testWidgets(
        '${w.toInt()}px ${dark ? 'dark' : 'light'}: the header fits with the bell',
        (tester) async {
          backend.rows.add(note('a'));
          inbox.setUser('u1');
          await shell(
            tester,
            size: Size(w, h),
            theme: dark ? AppTheme.dark : AppTheme.light,
          );
          await openMyBusiness(tester);
          expect(find.byType(NotificationBell), findsOneWidget);
          expect(tester.takeException(), isNull);
          expect(
            tester.getRect(find.byType(NotificationBell)).right,
            lessThanOrEqualTo(w),
          );
        },
      );
    }
  }
}
