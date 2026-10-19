import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/l10n/l10n.dart';
import 'package:konnect_kashmir/providers/auth_provider.dart';
import 'package:konnect_kashmir/screens/deen/deen_tab.dart';
import 'package:konnect_kashmir/screens/deen/prayer_service.dart';
import 'package:konnect_kashmir/screens/main_shell.dart';
import 'package:konnect_kashmir/services/live_sync.dart';
import 'package:konnect_kashmir/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// A saved place and today's saved prayer times for it, so the screen shows real
// (cached) data without a network or a GPS.
const _lat = 34.1, _lng = 74.8;

Map<String, Object> _saved() {
  final d = DateTime.now();
  return {
    'cust_lat': _lat,
    'cust_lng': _lng,
    'cust_loc_at': d.millisecondsSinceEpoch,
    'place_${_lat.toStringAsFixed(1)}_${_lng.toStringAsFixed(1)}':
        'Srinagar, Jammu & Kashmir',
    'prayer_${d.year}${d.month}${d.day}_34.1_74.8_m1_s1': jsonEncode({
      'fajr': '05:15',
      'dhuhr': '12:16',
      'asr': '16:13',
      'maghrib': '17:52',
      'isha': '19:16',
      'hijri': '8 Jumādá al-ūlá 1448',
    }),
  };
}

Widget _app(Widget home,
    {ThemeData? theme, double textScale = 1.0, Locale? locale}) {
  final auth = AuthProvider();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider<LiveSync>.value(value: LiveSync(auth)),
    ],
    child: MaterialApp(
      theme: theme,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(body: home),
    ),
  );
}

void _phone(WidgetTester tester, {double w = 360, double h = 800}) {
  tester.view.physicalSize = Size(w * 2, h * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

// Roboto from the Flutter SDK, so text is as wide as on a phone (the default test
// font is far wider and would report overflows that do not happen).
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

void main() {
  setUpAll(_loadRoboto);

  setUp(() {
    SharedPreferences.setMockInitialValues(_saved());
    MainShell.tabRequest.value = null;
  });

  group('the Deen screen shows the real saved data in the new layout', () {
    testWidgets('light theme', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(const DeenTab(), theme: AppTheme.light));
      await _settle(tester);

      // Header: logo, place (first part of the saved name), title.
      expect(find.byType(Image), findsWidgets);
      expect(find.text('Srinagar'), findsOneWidget);
      expect(find.text('Deen'), findsOneWidget);

      // Qibla banner with the angle worked out from the saved place.
      final qibla = qiblaBearing(_lat, _lng).toStringAsFixed(1);
      expect(find.text('Qibla: $qibla° from North'), findsOneWidget);
      // The big dial is no longer on the page itself.
      expect(find.textContaining('Hold your phone flat'), findsNothing);

      // Prayer times: five prayers with the saved times, the countdown, Filter.
      for (final n in ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
        expect(find.text(n), findsWidgets, reason: n);
      }
      for (final t in ['5:15 AM', '12:16 PM', '4:13 PM', '5:52 PM', '7:16 PM']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(find.textContaining('Next:'), findsOneWidget);
      expect(find.text('Filter'), findsOneWidget);
      expect(find.text('View All'), findsNothing);

      // Continue Reading is still there.
      expect(find.text('Continue Reading'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('dark theme', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(const DeenTab(), theme: AppTheme.dark));
      await _settle(tester);
      expect(find.text('Srinagar'), findsOneWidget);
      expect(find.text('5:15 AM'), findsOneWidget);
      expect(find.text('Continue Reading'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('the three shortcuts', () {
    testWidgets('sit in one row, in order, inside the screen', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(const DeenTab(), theme: AppTheme.light));
      await _settle(tester);

      final icons = [
        Icons.menu_book_rounded, // Quran
        Icons.headphones_rounded, // Audio
        Icons.volunteer_activism_rounded, // Duas
      ];
      // .first: the book icon appears again, faintly, on the Continue card.
      final centers = [for (final i in icons) tester.getCenter(find.byIcon(i).first)];
      for (final c in centers) {
        expect((c.dy - centers.first.dy).abs(), lessThan(1), reason: 'one row');
        expect(c.dx, inInclusiveRange(0, 360));
      }
      for (var i = 1; i < centers.length; i++) {
        expect(centers[i].dx, greaterThan(centers[i - 1].dx), reason: 'in order');
      }
      for (final label in ['Quran', 'Audio', 'Duas']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      // Islamic Audio has been taken off this screen.
      expect(find.text('Islamic Audio'), findsNothing);
      expect(find.byIcon(Icons.library_music_rounded), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('fit a small screen with big text', (tester) async {
      _phone(tester, w: 320, h: 640);
      await tester.pumpWidget(
          _app(const DeenTab(), theme: AppTheme.light, textScale: 1.6));
      await _settle(tester);
      // The shortcuts are below the fold on this screen: scroll to them.
      await tester.scrollUntilVisible(find.text('Quran'), 200);
      expect(find.text('Quran'), findsOneWidget);
      // Nothing overflowed (an overflow would be reported as an exception).
      expect(tester.takeException(), isNull);
    });

    testWidgets('fit a small screen in Hindi, to the very bottom', (tester) async {
      _phone(tester, w: 320, h: 640);
      await tester.pumpWidget(_app(const DeenTab(),
          theme: AppTheme.dark, textScale: 1.3, locale: const Locale('hi')));
      await _settle(tester);
      for (var i = 0; i < 6; i++) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -400));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('the Qibla banner', () {
    testWidgets('opens the full compass when tapped', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(const DeenTab(), theme: AppTheme.light));
      await _settle(tester);

      final qibla = qiblaBearing(_lat, _lng).toStringAsFixed(1);
      await tester.tap(find.text('Qibla: $qibla° from North'));
      await tester.pumpAndSettle();

      // The sheet has the angle line and the hint of the old dial card.
      expect(find.text('Qibla angle: $qibla° from North'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('leaving the screen', () {
    testWidgets('the back arrow calls onBack', (tester) async {
      _phone(tester);
      var taps = 0;
      await tester.pumpWidget(_app(DeenTab(onBack: () => taps++), theme: AppTheme.light));
      await _settle(tester);

      await tester.tap(find.byTooltip('Home'));
      expect(taps, 1);
    });

    testWidgets('no back arrow when nothing can be gone back to', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(const DeenTab(), theme: AppTheme.light));
      await _settle(tester);
      expect(find.byTooltip('Home'), findsNothing);
    });
  });

  group('the bottom bar', () {
    testWidgets('is hidden on Deen only, and the arrow goes back to Home',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(const MainShell(), theme: AppTheme.light));
      await _settle(tester);

      // Home: the bar is there, with its four items.
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationDestination), findsNWidgets(4));

      // Open Deen as a tapped notification or link would.
      MainShell.tabRequest.value = MainShell.tabDeen;
      await _settle(tester);
      expect(find.byType(DeenTab), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Deen'), findsWidgets);

      // The header arrow returns to Home, and the bar comes back.
      await tester.tap(find.byTooltip('Home'));
      await _settle(tester);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
          MainShell.tabHome);
      expect(tester.takeException(), isNull);
    });
  });
}
