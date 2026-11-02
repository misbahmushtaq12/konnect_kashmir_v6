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

PrayerAlarmService _service(
  FakeAlarmScheduler scheduler, {
  bool noPlace = false,
}) => PrayerAlarmService(
  scheduler: scheduler,
  calendar: PrayerCalendarSource(fetch: FakeAladhan().fetch),
  location: ({required foreground, required ask}) async =>
      noPlace ? null : (lat: 34.08, lng: 74.8),
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

  testWidgets('starts off, with just the one switch', (tester) async {
    _phone(tester);
    final scheduler = FakeAlarmScheduler();
    await _open(tester, _service(scheduler));

    expect(find.text('Prayer alarms'), findsOneWidget);
    expect(find.text('Beep at prayer times'), findsOneWidget);
    // The "set for 10 days" note is gone: the last days' alarms say it themselves.
    expect(find.textContaining('10 days'), findsNothing);
    expect(find.textContaining('keep them going'), findsNothing);
    expect(find.byType(Switch), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(find.text('Fajr'), findsNothing);
    expect(scheduler.pendingById, isEmpty);
  });

  testWidgets(
    'the one switch plans all five prayers and there is no switch per prayer',
    (tester) async {
      _phone(tester);
      final scheduler = FakeAlarmScheduler();
      await _open(tester, _service(scheduler));

      await tester.tap(find.byType(Switch));
      await _settle(tester);

      expect(scheduler.alarms.length, 49);
      expect(scheduler.alarms.map(FakeAlarmScheduler.prayerOf).toSet(), {
        'fajr',
        'dhuhr',
        'asr',
        'maghrib',
        'isha',
      });
      expect(find.byType(Switch), findsOneWidget);
      for (final name in ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
        expect(find.text(name), findsNothing);
      }
      // The two lines that were taken out.
      expect(find.textContaining('Alarms are set through'), findsNothing);
      expect(
        find.textContaining('A short beep at each prayer time'),
        findsNothing,
      );
      expect((await PrayerAlarmPrefs.load()).enabled, isTrue);
    },
  );

  testWidgets('the switch off cancels everything and the extras go', (
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

  testWidgets('notifications refused: explains first and Cancel keeps it off', (
    tester,
  ) async {
    _phone(tester);
    final scheduler = FakeAlarmScheduler()
      ..perms = const AlarmPermissions(notifications: false, exactAlarms: true);
    await _open(tester, _service(scheduler));
    await tester.tap(find.byType(Switch));
    await _settle(tester);

    expect(find.text('Allow notifications'), findsOneWidget);
    expect(
      find.textContaining('Tap Open settings'),
      findsOneWidget,
    );
    expect(find.text('Open settings'), findsOneWidget);
    expect(scheduler.settingsOpened, 0, reason: 'the explanation comes first');

    await tester.tap(find.text('Cancel'));
    await _settle(tester);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(find.text('Fajr'), findsNothing);
    expect(scheduler.alarms, isEmpty);
    expect(find.textContaining('Prayer alarms are on'), findsNothing);
    expect((await PrayerAlarmPrefs.load()).enabled, isFalse);
  });

  testWidgets(
    'notifications: Open settings, allowed there: switched on and confirmed',
    (tester) async {
      _phone(tester);
      final scheduler = FakeAlarmScheduler()
        ..perms = const AlarmPermissions(
          notifications: false,
          exactAlarms: true,
        );
      final service = _service(scheduler);
      scheduler.onSettingsScreen = () async {
        scheduler.perms = const AlarmPermissions(
          notifications: true,
          exactAlarms: true,
        );
        service.appPaused();
        await service.appResumed();
      };
      await _open(tester, service);
      await tester.tap(find.byType(Switch));
      await _settle(tester);
      await tester.tap(find.text('Open settings'));
      await _settle(tester);

      expect(scheduler.settingsOpened, 1);
      expect(tester.widget<Switch>(find.byType(Switch).first).value, isTrue);
      expect(
        find.text('Prayer alarms are on. They will ring at the exact time.'),
        findsOneWidget,
      );
      expect(scheduler.alarms.length, 49);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    },
  );

  testWidgets(
    'notifications: back from the settings without allowing: off, the note, one button, no success',
    (tester) async {
      _phone(tester);
      final scheduler = FakeAlarmScheduler()
        ..perms = const AlarmPermissions(
          notifications: false,
          exactAlarms: true,
        );
      final service = _service(scheduler);
      scheduler.onSettingsScreen = () async {
        service.appPaused();
        await service.appResumed(); // came back, changed nothing
      };
      await _open(tester, service);
      await tester.tap(find.byType(Switch));
      await _settle(tester);
      await tester.tap(find.text('Open settings'));
      await _settle(tester);

      expect(tester.widget<Switch>(find.byType(Switch).first).value, isFalse);
      expect(find.textContaining('notifications are off or silent'), findsOneWidget);
      expect(
        find.text('Open settings'),
        findsOneWidget,
        reason: 'the one button that always works',
      );
      expect(
        find.text('Allow notifications'),
        findsNothing,
        reason: 'no button that does nothing',
      );
      expect(find.textContaining('Prayer alarms are on'), findsNothing);
      expect(scheduler.alarms, isEmpty);
      expect((await PrayerAlarmPrefs.load()).enabled, isFalse);
    },
  );

  testWidgets('both missing: notifications first, then exact alarms, then on', (
    tester,
  ) async {
    _phone(tester);
    final scheduler = FakeAlarmScheduler()
      ..perms = const AlarmPermissions(
        notifications: false,
        exactAlarms: false,
      );
    final service = _service(scheduler);
    scheduler.onSettingsScreen = () async {
      scheduler.perms = const AlarmPermissions(
        notifications: true,
        exactAlarms: false,
      );
      service.appPaused();
      await service.appResumed();
    };
    scheduler.onExactScreen = () async => scheduler.perms =
        const AlarmPermissions(notifications: true, exactAlarms: true);
    await _open(tester, service);
    await tester.tap(find.byType(Switch));
    await _settle(tester);

    expect(find.text('Allow notifications'), findsOneWidget);
    await tester.tap(find.text('Open settings'));
    await _settle(tester);
    // Progress was made, so the next permission is explained straight away.
    expect(find.text('Allow exact alarms'), findsOneWidget);
    await tester.tap(find.text('Grant permission'));
    await _settle(tester);

    expect(tester.widget<Switch>(find.byType(Switch).first).value, isTrue);
    expect(
      find.text('Prayer alarms are on. They will ring at the exact time.'),
      findsOneWidget,
    );
    expect(scheduler.alarms.length, 49);
  });

  testWidgets(
    'notifications taken back while on: a warning and one button; restored: gone',
    (tester) async {
      _phone(tester);
      final scheduler = FakeAlarmScheduler();
      final service = _service(scheduler);
      await _open(tester, service);
      await tester.tap(find.byType(Switch));
      await _settle(tester);
      expect(scheduler.alarms.length, 49);

      scheduler.perms = const AlarmPermissions(
        notifications: false,
        exactAlarms: true,
      );
      await service.onResume();
      await _settle(tester);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.textContaining('notifications are off or silent'), findsOneWidget);
      expect(find.text('Open settings'), findsOneWidget);
      expect(find.text('Allow notifications'), findsNothing);
      expect(tester.widget<Switch>(find.byType(Switch).first).value, isTrue);

      scheduler.perms = const AlarmPermissions(
        notifications: true,
        exactAlarms: true,
      );
      await service.onResume();
      await _settle(tester);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      expect(scheduler.alarms.length, 49);
      expect(scheduler.alarms.map((a) => a.id).toSet().length, 49);
    },
  );

  testWidgets('Android: the words name the "Prayer alarms" category', (
    tester,
  ) async {
    _phone(tester);
    final scheduler = FakeAlarmScheduler()
      ..perms = const AlarmPermissions(notifications: false, exactAlarms: true);
    await _open(tester, _service(scheduler));
    await tester.tap(find.byType(Switch));
    await _settle(tester);
    expect(find.textContaining('switch on “Prayer alarms”'), findsOneWidget);
    expect(find.textContaining('Sounds'), findsNothing);
  });

  testWidgets('iPhone: the words name Notifications and Sounds', (tester) async {
    _phone(tester);
    final scheduler = FakeAlarmScheduler()
      ..perms = const AlarmPermissions(notifications: false, exactAlarms: true);
    await _open(
      tester,
      _service(scheduler),
      theme: AppTheme.light.copyWith(platform: TargetPlatform.iOS),
    );
    await tester.tap(find.byType(Switch));
    await _settle(tester);
    expect(
      find.textContaining('switch on Notifications (and Sounds)'),
      findsOneWidget,
    );
    expect(find.textContaining('“Prayer alarms” category'), findsNothing);
  });

  testWidgets(
    'without exact alarms, turning on explains first and Cancel keeps it off',
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

      // The explanation, with both choices; the system screen is not opened yet.
      expect(find.text('Allow exact alarms'), findsOneWidget);
      expect(
        find.textContaining('To ring at the exact prayer time'),
        findsOneWidget,
      );
      expect(find.text('Grant permission'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(scheduler.exactRequests, 0);

      await tester.tap(find.text('Cancel'));
      await _settle(tester);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      expect(find.text('Fajr'), findsNothing);
      expect(scheduler.alarms, isEmpty);
      expect(scheduler.exactRequests, 0);
      expect(find.textContaining('Prayer alarms are on'), findsNothing);
      expect((await PrayerAlarmPrefs.load()).enabled, isFalse);
    },
  );

  testWidgets(
    'Grant permission opens the system screen; once allowed, the alarms are set and confirmed',
    (tester) async {
      _phone(tester);
      final scheduler = FakeAlarmScheduler()
        ..perms = const AlarmPermissions(
          notifications: true,
          exactAlarms: false,
        );
      scheduler.onExactScreen = () async => scheduler.perms =
          const AlarmPermissions(notifications: true, exactAlarms: true);
      await _open(tester, _service(scheduler));
      await tester.tap(find.byType(Switch));
      await _settle(tester);
      await tester.tap(find.text('Grant permission'));
      await _settle(tester);

      expect(scheduler.exactRequests, 1);
      expect(tester.widget<Switch>(find.byType(Switch).first).value, isTrue);
      expect(
        find.text('Prayer alarms are on. They will ring at the exact time.'),
        findsOneWidget,
      );
      expect(scheduler.alarms.length, 49);
      expect(find.byType(Switch), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      expect((await PrayerAlarmPrefs.load()).enabled, isTrue);
    },
  );

  testWidgets(
    'back without allowing it: off, says it is still needed, no success message, easy to try again',
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
      await tester.tap(find.text('Grant permission'));
      await _settle(tester);

      expect(scheduler.exactRequests, 1);
      expect(tester.widget<Switch>(find.byType(Switch).first).value, isFalse);
      expect(find.textContaining('still needed'), findsOneWidget);
      expect(find.textContaining('Prayer alarms are on'), findsNothing);
      expect(scheduler.alarms, isEmpty);

      // The button in the note tries again, and this time the user allows it.
      scheduler.onExactScreen = () async => scheduler.perms =
          const AlarmPermissions(notifications: true, exactAlarms: true);
      await tester.tap(find.text('Grant permission'));
      await _settle(tester);
      expect(scheduler.exactRequests, 2);
      expect(tester.widget<Switch>(find.byType(Switch).first).value, isTrue);
      expect(find.textContaining('still needed'), findsNothing);
      expect(scheduler.alarms.length, 49);
    },
  );

  testWidgets(
    'permission taken back while on: a warning beside the switch, and it clears when restored',
    (tester) async {
      _phone(tester);
      final scheduler = FakeAlarmScheduler();
      final service = _service(scheduler);
      await _open(tester, service);
      await tester.tap(find.byType(Switch));
      await _settle(tester);
      expect(scheduler.alarms.length, 49);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);

      // Taken back in the system settings; the app resumes.
      scheduler.perms = const AlarmPermissions(
        notifications: true,
        exactAlarms: false,
      );
      await service.onResume();
      await _settle(tester);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(
        find.textContaining('may not ring until you allow it'),
        findsOneWidget,
      );
      expect(find.text('Allow exact alarms'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch).first).value, isTrue);

      // Restored: the warning goes and the alarms are back, once each.
      scheduler.perms = const AlarmPermissions(
        notifications: true,
        exactAlarms: true,
      );
      await service.onResume();
      await _settle(tester);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      expect(find.textContaining('may not ring'), findsNothing);
      expect(scheduler.alarms.length, 49);
      expect(scheduler.alarms.map((a) => a.id).toSet().length, 49);
    },
  );

  testWidgets(
    'on, but no place known so nothing was set: a warning beside the switch, the reason under it',
    (tester) async {
      _phone(tester);
      final scheduler = FakeAlarmScheduler();
      await _open(tester, _service(scheduler, noPlace: true));
      await tester.tap(find.byType(Switch));
      await _settle(tester);

      expect(tester.widget<Switch>(find.byType(Switch).first).value, isTrue);
      expect(scheduler.alarms, isEmpty);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(
        find.byTooltip('Prayer alarms could not be set'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Allow location once so we can work out prayer times for where you are.',
        ),
        findsOneWidget,
      );
      // Nothing was set, so no "alarms are on" confirmation.
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    },
  );

  testWidgets(
    'the system refused an alarm: a warning until Refresh sets it, then it is gone',
    (tester) async {
      _phone(tester);
      final scheduler = FakeAlarmScheduler()
        ..failIds = {prayerAlarmId(2026, 10, 25, Prayer.fajr)};
      await _open(tester, _service(scheduler));
      await tester.tap(find.byType(Switch));
      await _settle(tester);

      expect(scheduler.alarms.length, 48);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(
        find.byTooltip('Prayer alarms could not be set'),
        findsOneWidget,
      );
      expect(
        find.text('Some alarms could not be set. Try Refresh alarms.'),
        findsOneWidget,
      );

      scheduler.failIds = {};
      await tester.ensureVisible(find.text('Refresh alarms'));
      await tester.tap(find.text('Refresh alarms'));
      await _settle(tester);
      expect(scheduler.alarms.length, 49);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      expect(find.textContaining('could not be set'), findsNothing);
    },
  );

  testWidgets(
    'the footer is honest about silent mode, and there is no "10 days" note',
    (tester) async {
      _phone(tester);
      await _open(tester, _service(FakeAlarmScheduler()));
      await tester.tap(find.byType(Switch));
      await _settle(tester);
      expect(find.textContaining('Do Not Disturb'), findsOneWidget);
      // Nor once the alarms are on.
      expect(find.textContaining('10 days'), findsNothing);
      expect(find.textContaining('keep them going'), findsNothing);
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
    'dark theme, Urdu, Hindi, a small screen and large text: the warning and notes fit',
    (tester) async {
      for (final (theme, locale) in [
        (AppTheme.dark, const Locale('en')),
        (AppTheme.light, const Locale('ur')),
        (AppTheme.light, const Locale('hi')),
      ]) {
        SharedPreferences.setMockInitialValues({});
        _phone(tester, w: 320, h: 640);
        final scheduler = FakeAlarmScheduler();
        final service = _service(scheduler);
        await _open(
          tester,
          service,
          theme: theme,
          textScale: 1.3,
          locale: locale,
        );
        await tester.tap(find.byType(Switch));
        await _settle(tester);
        scheduler.perms = const AlarmPermissions(
          notifications: false,
          exactAlarms: true,
        ); // taken back
        await service.onResume();
        await _settle(tester);
        expect(find.byType(Switch), findsOneWidget);
        expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
        expect(tester.takeException(), isNull, reason: '$locale');
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets(
    'the explanation dialogs fit in every language, dark theme, small screen, large text',
    (tester) async {
      for (final missing in [
        const AlarmPermissions(notifications: false, exactAlarms: true),
        const AlarmPermissions(notifications: true, exactAlarms: false),
      ]) {
        for (final (theme, locale) in [
          (AppTheme.dark, const Locale('en')),
          (AppTheme.light, const Locale('ur')),
          (AppTheme.light, const Locale('hi')),
        ]) {
          SharedPreferences.setMockInitialValues({});
          _phone(tester, w: 320, h: 640);
          final scheduler = FakeAlarmScheduler()..perms = missing;
          await _open(
            tester,
            _service(scheduler),
            theme: theme,
            textScale: 1.3,
            locale: locale,
          );
          await tester.tap(find.byType(Switch));
          await _settle(tester);
          expect(find.byType(AlertDialog), findsOneWidget, reason: '$locale');
          expect(tester.takeException(), isNull, reason: '$locale');
          await tester.pumpWidget(const SizedBox());
        }
      }
    },
  );
}
