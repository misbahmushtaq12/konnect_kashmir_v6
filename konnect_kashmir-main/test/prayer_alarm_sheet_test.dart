import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/l10n/l10n.dart';
import 'package:konnect_kashmir/screens/deen/prayer_alarm_sheet.dart';
import 'package:konnect_kashmir/services/prayer_alarm/prayer_alarm_planner.dart';
import 'package:konnect_kashmir/services/prayer_alarm/prayer_alarm_prefs.dart';
import 'package:konnect_kashmir/services/prayer_alarm/prayer_alarm_scheduler.dart';
import 'package:konnect_kashmir/services/prayer_alarm/prayer_alarm_service.dart';
import 'package:konnect_kashmir/services/prayer_alarm/prayer_calendar.dart';
import 'package:konnect_kashmir/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_aladhan.dart';
import 'support/fake_alarm_scheduler.dart';

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

final _now = DateTime.utc(2026, 10, 24, 2); // 07:30 in Srinagar

PrayerAlarmService _service(FakeAlarmScheduler scheduler) => PrayerAlarmService(
  scheduler: scheduler,
  calendar: PrayerCalendarSource(fetch: FakeAladhan().fetch),
  location: ({required foreground, required ask}) async =>
      (lat: 34.08, lng: 74.8),
  clock: () => _now,
  language: () async => 'en',
);

Widget _app(
  PrayerAlarmService service, {
  ThemeData? theme,
  double textScale = 1.0,
  Locale? locale,
}) => MaterialApp(
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
  home: Scaffold(
    body: Builder(
      builder: (context) => Center(
        child: TextButton(
          onPressed: () => showPrayerAlarmSheet(context, service: service),
          child: const Text('open'),
        ),
      ),
    ),
  ),
);

void _phone(WidgetTester tester, {double w = 360, double h = 800}) {
  tester.view.physicalSize = Size(w * 2, h * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

Future<void> _open(
  WidgetTester tester,
  PrayerAlarmService s, {
  ThemeData? theme,
  double textScale = 1.0,
  Locale? locale,
}) async {
  await tester.pumpWidget(
    _app(s, theme: theme, textScale: textScale, locale: locale),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// A few frames so the service's work (all instant, in memory) finishes.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(_loadRoboto);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('starts off, with no prayer rows', (tester) async {
    _phone(tester);
    final scheduler = FakeAlarmScheduler();
    await _open(tester, _service(scheduler));

    expect(find.text('Prayer alarms'), findsOneWidget);
    expect(find.text('Beep at prayer times'), findsOneWidget);
    // The 10-day note is there before the alarms are switched on.
    expect(
      find.text(
        'Alarms are set for 10 days at a time. After that, open the app to keep them going.',
      ),
      findsOneWidget,
    );
    expect(find.byType(Switch), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(find.text('Fajr'), findsNothing);
    expect(scheduler.pendingById, isEmpty);
  });

  testWidgets(
    'the master switch plans the alarms and shows one switch per prayer',
    (tester) async {
      _phone(tester);
      final scheduler = FakeAlarmScheduler();
      await _open(tester, _service(scheduler));

      await tester.tap(find.byType(Switch));
      await _settle(tester);

      expect(scheduler.alarms.length, 49);
      expect(find.byType(Switch), findsNWidgets(6));
      for (final name in ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
        expect(find.text(name), findsOneWidget);
      }
      expect(find.textContaining('Alarms are set through'), findsOneWidget);
      expect((await PrayerAlarmPrefs.load()).enabled, isTrue);
    },
  );

  testWidgets('a prayer switch cancels just that prayer', (tester) async {
    _phone(tester);
    final scheduler = FakeAlarmScheduler();
    scheduler.addForeign(42);
    await _open(tester, _service(scheduler));
    await tester.tap(find.byType(Switch));
    await _settle(tester);

    // Switches: master, Fajr, Dhuhr, Asr, ...
    await tester.tap(find.byType(Switch).at(3));
    await _settle(tester);

    expect(
      scheduler.alarms.map(FakeAlarmScheduler.prayerOf),
      isNot(contains('asr')),
    );
    expect(scheduler.alarms.length, 39);
    expect(scheduler.foreignIds, [42]);
    expect(
      (await PrayerAlarmPrefs.load()).prayers,
      isNot(contains(Prayer.asr)),
    );
  });

  testWidgets('the master switch off cancels everything and hides the rows', (
    tester,
  ) async {
    _phone(tester);
    final scheduler = FakeAlarmScheduler();
    await _open(tester, _service(scheduler));
    await tester.tap(find.byType(Switch));
    await _settle(tester);
    await tester.tap(find.byType(Switch).first);
    await _settle(tester);

    expect(scheduler.alarms, isEmpty);
    expect(find.text('Fajr'), findsNothing);
  });

  testWidgets('blocked notifications: explains, and the buttons work', (
    tester,
  ) async {
    _phone(tester);
    final scheduler = FakeAlarmScheduler()
      ..perms = const AlarmPermissions(notifications: false, exactAlarms: true);
    await _open(tester, _service(scheduler));
    await tester.tap(find.byType(Switch));
    await _settle(tester);

    expect(find.textContaining('Notifications are off'), findsOneWidget);
    final before = scheduler.permissionRequests;
    await tester.tap(find.text('Allow notifications'));
    await _settle(tester);
    expect(scheduler.permissionRequests, before + 1);

    await tester.tap(find.text('Open settings'));
    await tester.pump();
    expect(scheduler.settingsOpened, 1);
  });

  testWidgets(
    'exact alarms off: says a beep may be late and offers to allow them',
    (tester) async {
      _phone(tester);
      final scheduler = FakeAlarmScheduler()
        ..perms = const AlarmPermissions(
          notifications: true,
          exactAlarms: false,
        );
      await _open(tester, _service(scheduler));
      await tester.tap(find.byType(Switch));
      await _settle(tester);

      expect(find.textContaining('a few minutes late'), findsOneWidget);
      expect(scheduler.alarms.length, 49, reason: 'planned anyway');
      await tester.tap(find.text('Allow exact alarms'));
      await _settle(tester);
      expect(scheduler.permissionRequests, 2); // once on turning on, once here
    },
  );

  testWidgets(
    'the footer is honest about silent mode and the app being opened',
    (tester) async {
      _phone(tester);
      await _open(tester, _service(FakeAlarmScheduler()));
      await tester.tap(find.byType(Switch));
      await _settle(tester);
      expect(find.textContaining('Do Not Disturb'), findsOneWidget);
      // Still one note about the 10 days once the alarms are on.
      expect(
        find.textContaining('open the app to keep them going'),
        findsOneWidget,
      );
    },
  );

  testWidgets('Refresh alarms plans again', (tester) async {
    _phone(tester);
    final scheduler = FakeAlarmScheduler();
    await _open(tester, _service(scheduler));
    await tester.tap(find.byType(Switch));
    await _settle(tester);
    scheduler.pendingById.clear();
    scheduler.order.clear();

    await tester.tap(find.text('Refresh alarms'));
    await _settle(tester);
    expect(scheduler.alarms.length, 49);
  });

  testWidgets(
    'dark theme, Urdu, a small screen and large text, without overflow',
    (tester) async {
      for (final (theme, locale) in [
        (AppTheme.dark, const Locale('en')),
        (AppTheme.light, const Locale('ur')),
        (AppTheme.light, const Locale('hi')),
      ]) {
        SharedPreferences.setMockInitialValues({}); // switched off again
        _phone(tester, w: 320, h: 640);
        final scheduler = FakeAlarmScheduler()
          ..perms = const AlarmPermissions(
            notifications: false,
            exactAlarms: false,
          );
        await _open(
          tester,
          _service(scheduler),
          theme: theme,
          textScale: 1.3,
          locale: locale,
        );
        await tester.tap(find.byType(Switch));
        await _settle(tester);
        expect(find.byType(Switch), findsNWidgets(6));
        expect(tester.takeException(), isNull, reason: '$locale');
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
}
