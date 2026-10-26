import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/screens/deen/prayer_service.dart';
import 'package:konnect_kashmir/services/prayer_alarm/prayer_alarm_planner.dart';
import 'package:konnect_kashmir/services/prayer_alarm/prayer_alarm_prefs.dart';
import 'package:konnect_kashmir/services/prayer_alarm/prayer_alarm_scheduler.dart';
import 'package:konnect_kashmir/services/prayer_alarm/prayer_alarm_service.dart';
import 'package:konnect_kashmir/services/prayer_alarm/prayer_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_aladhan.dart';
import 'support/fake_alarm_scheduler.dart';

/// 24 October 2026, 07:30 in Srinagar (02:00 UTC). Fajr (05:10) has passed.
final _start = DateTime.utc(2026, 10, 24, 2);

/// A moment given on the Indian clock (UTC+5:30).
DateTime _ist(int y, int m, int d, int h, [int mi = 0]) => DateTime.utc(
  y,
  m,
  d,
  h,
  mi,
).subtract(const Duration(hours: 5, minutes: 30));

class _FakeMaintenance implements PrayerAlarmMaintenance {
  final List<bool> calls = [];
  @override
  Future<void> sync({required bool enabled}) async => calls.add(enabled);
}

/// A phone, an Aladhan, a place and a clock, and a service wired to them.
class _Rig {
  _Rig({int? limit, FakeAladhan? api})
    : scheduler = FakeAlarmScheduler(limit: limit),
      api = api ?? FakeAladhan() {
    now = _start;
    service = PrayerAlarmService(
      scheduler: scheduler,
      calendar: PrayerCalendarSource(fetch: this.api.fetch),
      location: ({required foreground, required ask}) async {
        lookups.add((foreground: foreground, ask: ask));
        return place;
      },
      clock: () => now,
      language: () async => lang,
      text: (p, l) => (title: '$l:${p.name}', body: 'Time for ${p.name}'),
      maintenance: maintenance,
    );
  }

  final FakeAlarmScheduler scheduler;
  final FakeAladhan api;
  final _FakeMaintenance maintenance = _FakeMaintenance();
  late final PrayerAlarmService service;
  late DateTime now;
  ({double lat, double lng})? place = (lat: 34.08, lng: 74.80);
  String lang = 'en';
  final List<({bool foreground, bool ask})> lookups = [];

  Future<void> switchOn() => const PrayerAlarmPrefs(enabled: true).save();

  /// Switched on and planned once; the counters are then reset.
  Future<void> running() async {
    await switchOn();
    await service.refresh(reason: 'test');
    scheduler.resetCalls();
  }

  Set<int> get alarmIds => scheduler.alarms.map((a) => a.id).toSet();
  List<DateTime> get alarmTimes =>
      scheduler.alarms.map(FakeAlarmScheduler.atOf).toList();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('switching on and off', () {
    test(
      'is off to begin with: nothing is scheduled and nothing is asked',
      () async {
        final rig = _Rig();
        final st = await rig.service.refresh();
        expect(st.enabled, isFalse);
        expect(rig.scheduler.pendingById, isEmpty);
        expect(rig.scheduler.permissionRequests, 0);
        expect(rig.lookups, isEmpty);
        expect(rig.api.calls, isEmpty);
      },
    );

    test(
      'turning on asks for permission and the place, then plans ten days',
      () async {
        final rig = _Rig();
        final st = await rig.service.setEnabled(true);

        expect(rig.scheduler.permissionRequests, 1);
        expect(rig.lookups.single.ask, isTrue);
        // Today's four prayers still to come, then nine full days of five.
        expect(rig.scheduler.alarms.length, 4 + 9 * 5);
        expect(st.enabled, isTrue);
        expect(st.scheduled, 49);
        expect(st.through, _ist(2026, 11, 2, 19, 5));
        expect(st.issues, isEmpty);
        expect(rig.alarmIds.every(isPrayerAlarmId), isTrue);
        expect(rig.alarmTimes.every((t) => t.isAfter(rig.now)), isTrue);
        expect(rig.alarmTimes.first, _ist(2026, 10, 24, 12, 15)); // Dhuhr
        expect(rig.maintenance.calls.last, isTrue);
      },
    );

    test(
      'the text is in the app language and the payload says which prayer',
      () async {
        final rig = _Rig();
        await rig.service.setEnabled(true);
        final first = rig.scheduler.alarms.first;
        expect(first.title, 'en:dhuhr');
        expect(first.body, 'Time for dhuhr');
        expect(FakeAlarmScheduler.prayerOf(first), 'dhuhr');
      },
    );

    test('turning off cancels our alarms and only ours', () async {
      final rig = _Rig();
      rig.scheduler
        ..addForeign(42)
        ..addForeign(kPrayerIdBase - 1) // just below our block
        ..addForeign(kPrayerIdBase + kPrayerIdSpan); // just above it
      await rig.service.setEnabled(true);
      expect(rig.scheduler.alarms, isNotEmpty);

      final st = await rig.service.setEnabled(false);
      expect(rig.scheduler.alarms, isEmpty);
      expect(rig.scheduler.foreignIds.toSet(), {
        42,
        kPrayerIdBase - 1,
        kPrayerIdBase + kPrayerIdSpan,
      });
      expect(st.enabled, isFalse);
      expect(rig.maintenance.calls.last, isFalse);
      expect(rig.scheduler.cancelCalls.every(isPrayerAlarmId), isTrue);
    });

  });

  group('one switch for all five prayers', () {
    test('turning it on plans all five prayers, together', () async {
      final rig = _Rig();
      rig.scheduler.addForeign(42);
      await rig.service.setEnabled(true);
      expect(rig.scheduler.alarms.map(FakeAlarmScheduler.prayerOf).toSet(), {
        'fajr',
        'dhuhr',
        'asr',
        'maghrib',
        'isha',
      });
      expect(rig.scheduler.alarms.length, 49);
      expect(rig.scheduler.foreignIds, [42]);
    });

    test('turning it off takes down every one of them and only them', () async {
      final rig = _Rig();
      rig.scheduler.addForeign(42);
      await rig.service.setEnabled(true);
      await rig.service.setEnabled(false);
      expect(rig.scheduler.alarms, isEmpty);
      expect(rig.scheduler.foreignIds, [42]);
    });

    test('per-prayer choices saved by an earlier version are ignored', () async {
      SharedPreferences.setMockInitialValues({
        'prayer_alarm_enabled': true,
        'prayer_alarm_asr': false,
        'prayer_alarm_isha': false,
      });
      final rig = _Rig();
      await rig.service.refresh();
      expect(rig.scheduler.alarms.map(FakeAlarmScheduler.prayerOf).toSet(), {
        'fajr',
        'dhuhr',
        'asr',
        'maghrib',
        'isha',
      });
    });

    test('the choice is remembered', () async {
      final rig = _Rig();
      await rig.service.setEnabled(true);
      expect((await PrayerAlarmPrefs.load()).enabled, isTrue);
      await rig.service.setEnabled(false);
      expect((await PrayerAlarmPrefs.load()).enabled, isFalse);
    });
  });

  group('no duplicates', () {
    test('planning again changes nothing', () async {
      final rig = _Rig();
      await rig.running();
      final before = rig.alarmIds;
      await rig.service.refresh();
      expect(rig.scheduler.scheduleCalls, isEmpty);
      expect(rig.scheduler.cancelCalls, isEmpty);
      expect(rig.alarmIds, before);
      expect(rig.scheduler.alarms.length, 49);
    });

    test('several plannings at once still give one alarm per prayer', () async {
      final rig = _Rig();
      await rig.switchOn();
      await Future.wait([
        rig.service.refresh(),
        rig.service.refresh(),
        rig.service.refresh(),
      ]);
      expect(rig.scheduler.alarms.length, 49);
      expect(
        rig.scheduler.scheduleCalls.length,
        49,
        reason: 'the later ones found it all done',
      );
      expect(rig.alarmIds.length, 49);
    });
  });

  group('dates', () {
    test('after Isha the next alarm is tomorrow\'s Fajr', () async {
      final rig = _Rig();
      rig.now = _ist(2026, 10, 24, 20, 30);
      await rig.running();
      expect(rig.alarmTimes.first, _ist(2026, 10, 25, 5, 10));
    });

    test('plans across the end of the month, downloading next month', () async {
      final rig = _Rig();
      rig.now = _ist(2026, 10, 28, 7);
      await rig.running();
      expect(rig.alarmTimes.last, _ist(2026, 11, 6, 19, 5));
      expect(rig.api.calls.map((u) => u.path), [
        '/v1/calendar/2026/10',
        '/v1/calendar/2026/11',
      ]);
    });

    test('plans across the end of the year', () async {
      final rig = _Rig();
      rig.now = _ist(2026, 12, 29, 7);
      await rig.running();
      expect(rig.alarmTimes.last, _ist(2027, 1, 7, 19, 5));
      expect(rig.api.calls.map((u) => u.path), [
        '/v1/calendar/2026/12',
        '/v1/calendar/2027/1',
      ]);
    });

    test(
      'as days pass the window moves forward, fired alarms are gone, none are doubled',
      () async {
        final rig = _Rig();
        await rig.running();
        final firstLast = rig.alarmTimes.last;

        rig.now = _ist(2026, 10, 30, 7);
        rig.scheduler.fireDue(rig.now); // the phone has sounded the old ones
        await rig.service.refresh(reason: 'opened');

        expect(rig.alarmTimes.last.isAfter(firstLast), isTrue);
        expect(rig.alarmTimes.last, _ist(2026, 11, 8, 19, 5));
        expect(rig.scheduler.alarms.length, 4 + 9 * 5);
        expect(rig.alarmIds.length, rig.scheduler.alarms.length);
        expect(rig.alarmTimes.every((t) => t.isAfter(rig.now)), isTrue);
      },
    );

    test(
      'if the app is never opened the alarms simply run out, and come back when it is',
      () async {
        final rig = _Rig();
        await rig.running();
        rig.now = _ist(2026, 11, 20, 7); // three weeks later, app never opened
        rig.scheduler.fireDue(rig.now);
        expect(
          rig.scheduler.alarms,
          isEmpty,
          reason: 'nothing on the phone can add more',
        );

        await rig.service.refresh(reason: 'opened at last');
        expect(rig.scheduler.alarms.length, 4 + 9 * 5);
        expect(rig.alarmTimes.first, _ist(2026, 11, 20, 12, 15));
      },
    );
  });

  group('place, zone and settings', () {
    test('a new place replaces the alarms with ones for that place', () async {
      final api = FakeAladhan(
        respond: (uri, y, m) => aladhanMonthJson(
          y,
          m,
          zone: uri.queryParameters['latitude'] == '40.71'
              ? 'America/New_York'
              : 'Asia/Kolkata',
        ),
      );
      final rig = _Rig(api: api);
      await rig.running();
      expect(rig.alarmTimes.first, _ist(2026, 10, 24, 12, 15));

      rig.place = (
        lat: 40.71,
        lng: -74.0,
      ); // New York, EDT (UTC-4) until 1 November
      await rig.service.refresh(reason: 'moved');
      expect(
        rig.alarmTimes.first,
        DateTime.utc(2026, 10, 24, 9, 10),
      ); // 05:10 EDT
      // It is still the evening of 23 October there (22:00): today is over, then nine days.
      expect(rig.scheduler.alarms.length, 9 * 5);
      expect(rig.alarmIds.length, rig.scheduler.alarms.length);
      expect(
        rig.alarmTimes.where((t) => t == _ist(2026, 10, 24, 12, 15)),
        isEmpty,
        reason: 'none of the old place\'s alarms are left',
      );
    });

    test('a few metres of movement does not replan anything', () async {
      final rig = _Rig();
      await rig.running();
      rig.place = (lat: 34.0804, lng: 74.8003);
      await rig.service.refresh();
      expect(rig.scheduler.scheduleCalls, isEmpty);
      expect(rig.scheduler.cancelCalls, isEmpty);
    });

    test('another madhhab moves only Asr', () async {
      final api = FakeAladhan(
        respond: (uri, y, m) => aladhanMonthJson(
          y,
          m,
          times: [
            '05:10',
            '12:15',
            uri.queryParameters['school'] == '1' ? '16:15' : '15:30',
            '17:45',
            '19:05',
          ],
        ),
      );
      final rig = _Rig(api: api);
      await rig.running(); // Hanafi by default: Asr at 16:15
      expect(
        rig.scheduler.alarms
            .where((a) => FakeAlarmScheduler.prayerOf(a) == 'asr')
            .map(FakeAlarmScheduler.atOf)
            .first,
        _ist(2026, 10, 24, 16, 15),
      );

      await const PrayerSettings(madhhab: Madhhab.shafi).save();
      await rig.service.onPrayerSettingsChanged();

      final asr = rig.scheduler.alarms.where(
        (a) => FakeAlarmScheduler.prayerOf(a) == 'asr',
      );
      expect(asr.length, 10);
      expect(
        asr.map(FakeAlarmScheduler.atOf).first,
        _ist(2026, 10, 24, 15, 30),
      );
      expect(rig.scheduler.alarms.length, 49);
      expect(
        rig.scheduler.cancelCalls.length,
        10,
        reason: 'only the Asr alarms were replaced',
      );
      expect(rig.alarmIds.length, 49);
    });

    test('another language rewrites the text of every alarm', () async {
      final rig = _Rig();
      await rig.running();
      await rig.service.onLanguageChanged('ur');
      expect(rig.scheduler.alarms.length, 49);
      expect(
        rig.scheduler.alarms.every((a) => a.title!.startsWith('ur:')),
        isTrue,
      );
      expect(rig.alarmIds.length, 49);
    });
  });

  group('capacity (iOS keeps 64 notifications for the whole app)', () {
    test(
      'uses what is free: 64 minus other notifications minus the reserve',
      () async {
        final rig = _Rig(limit: 64);
        for (var i = 0; i < 20; i++) {
          rig.scheduler.addForeign(100 + i);
        }
        await rig.running();
        expect(rig.scheduler.alarms.length, 64 - 20 - 14);
        expect(
          rig.scheduler.dropped,
          0,
          reason: 'the system never had to throw one away',
        );
        expect(rig.scheduler.foreignIds.length, 20);
        // The ones kept are the soonest.
        expect(rig.alarmTimes.first, _ist(2026, 10, 24, 12, 15));
      },
    );

    test(
      'with nothing else waiting it plans the whole window and stays under 64',
      () async {
        final rig = _Rig(limit: 64);
        await rig.running();
        expect(rig.scheduler.alarms.length, 49);
        expect(rig.scheduler.pendingById.length, lessThanOrEqualTo(64 - 14));
        expect(rig.scheduler.dropped, 0);
      },
    );

    test(
      'when other features use all the room it says so and adds nothing',
      () async {
        final rig = _Rig(limit: 64);
        for (var i = 0; i < 55; i++) {
          rig.scheduler.addForeign(100 + i);
        }
        await rig.switchOn();
        final st = await rig.service.refresh();
        expect(st.issues, contains(PrayerAlarmIssue.noRoom));
        expect(rig.scheduler.alarms, isEmpty);
        expect(rig.scheduler.foreignIds.length, 55);
        expect(st.hasWarning, isTrue, reason: 'on, but nothing was set');
      },
    );

    test(
      'if another feature takes room later, the farthest alarms give way',
      () async {
        final rig = _Rig(limit: 64);
        await rig.running();
        for (var i = 0; i < 10; i++) {
          rig.scheduler.addForeign(100 + i);
        }
        await rig.service.refresh();
        expect(rig.scheduler.alarms.length, 64 - 10 - 14);
        expect(rig.scheduler.pendingById.length, lessThanOrEqualTo(64 - 14));
        expect(rig.scheduler.dropped, 0);
        expect(rig.alarmTimes.first, _ist(2026, 10, 24, 12, 15));
      },
    );

    test('Android has no small limit: the whole window is planned', () async {
      final rig = _Rig(limit: null);
      for (var i = 0; i < 80; i++) {
        rig.scheduler.addForeign(100 + i);
      }
      await rig.running();
      expect(rig.scheduler.alarms.length, 49);
    });
  });

  group('permissions', () {
    test(
      'notifications blocked: says so, schedules nothing, keeps what is there',
      () async {
        final rig = _Rig();
        await rig.running();
        final before = rig.alarmIds;
        rig.scheduler.perms = const AlarmPermissions(
          notifications: false,
          exactAlarms: true,
        );
        rig.now = _ist(2026, 10, 25, 7);
        final st = await rig.service.refresh();
        expect(st.issues, contains(PrayerAlarmIssue.notificationsBlocked));
        expect(rig.scheduler.scheduleCalls, isEmpty);
        expect(rig.scheduler.cancelCalls, isEmpty);
        expect(rig.alarmIds, before);

        // The user allows notifications in Settings; the next planning catches up.
        rig.scheduler.perms = const AlarmPermissions(
          notifications: true,
          exactAlarms: true,
        );
        final ok = await rig.service.refresh();
        expect(ok.issues, isEmpty);
        expect(rig.scheduler.scheduleCalls, isNotEmpty);
      },
    );

    test(
      'notifications refused: it does not switch on and says which permission is missing',
      () async {
        final rig = _Rig();
        rig.scheduler.perms = const AlarmPermissions(
          notifications: false,
          exactAlarms: true,
        );
        final st = await rig.service.setEnabled(true);

        expect(st.enabled, isFalse);
        expect(st.missingPermission, PrayerAlarmPermission.notifications);
        expect(st.issues, {PrayerAlarmIssue.notificationsBlocked});
        expect(st.justEnabled, isFalse);
        expect((await PrayerAlarmPrefs.load()).enabled, isFalse);
        expect(rig.scheduler.alarms, isEmpty);
      },
    );

    test(
      'notifications: the user opens the settings, allows them, comes back: on and confirmed',
      () async {
        final rig = _Rig();
        rig.scheduler.perms = const AlarmPermissions(
          notifications: false,
          exactAlarms: true,
        );
        await rig.service.setEnabled(true);

        final confirmations = <bool>[];
        rig.service.status.addListener(
          () => confirmations.add(rig.service.status.value.justEnabled),
        );
        rig.scheduler.onSettingsScreen = () async {
          rig.scheduler.perms = const AlarmPermissions(
            notifications: true,
            exactAlarms: true,
          ); // switched on in the settings
          rig.service.appPaused();
          await rig.service.appResumed(); // and the app is back
        };
        final st = await rig.service.openNotificationSettings();

        expect(rig.scheduler.settingsOpened, 1);
        expect(st.enabled, isTrue);
        expect(st.issues, isEmpty);
        expect(confirmations, contains(true));
        expect((await PrayerAlarmPrefs.load()).enabled, isTrue);
        expect(rig.scheduler.alarms.length, 49);
        expect(rig.alarmIds.length, 49, reason: 'none doubled');
      },
    );

    test(
      'notifications: back from the settings without allowing: still off, nothing set, not switched on later by itself',
      () async {
        final rig = _Rig();
        rig.scheduler.perms = const AlarmPermissions(
          notifications: false,
          exactAlarms: true,
        );
        await rig.service.setEnabled(true);
        rig.scheduler.onSettingsScreen = () async {
          rig.service.appPaused();
          await rig.service.appResumed(); // came back, changed nothing
        };
        final st = await rig.service.openNotificationSettings();

        expect(st.enabled, isFalse);
        expect(st.missingPermission, PrayerAlarmPermission.notifications);
        expect(st.justEnabled, isFalse);
        expect(rig.scheduler.alarms, isEmpty);

        rig.scheduler.perms = const AlarmPermissions(
          notifications: true,
          exactAlarms: true,
        );
        await rig.service.onResume();
        expect((await PrayerAlarmPrefs.load()).enabled, isFalse);
        expect(rig.scheduler.alarms, isEmpty);
      },
    );

    test(
      'both missing: notifications first, then exact alarms, then it is on',
      () async {
        final rig = _Rig();
        rig.scheduler.perms = const AlarmPermissions(
          notifications: false,
          exactAlarms: false,
        );
        var st = await rig.service.setEnabled(true);
        expect(st.missingPermission, PrayerAlarmPermission.notifications);

        rig.scheduler.onSettingsScreen = () async {
          rig.scheduler.perms = const AlarmPermissions(
            notifications: true,
            exactAlarms: false,
          ); // notifications on, exact alarms still off
          rig.service.appPaused();
          await rig.service.appResumed();
        };
        st = await rig.service.openNotificationSettings();
        expect(st.enabled, isFalse);
        expect(
          st.missingPermission,
          PrayerAlarmPermission.exactAlarms,
          reason: 'progress: the next one',
        );

        rig.scheduler.onExactScreen = () async => rig.scheduler.perms =
            const AlarmPermissions(notifications: true, exactAlarms: true);
        st = await rig.service.openExactAlarmSettings();
        expect(st.enabled, isTrue);
        expect(rig.scheduler.alarms.length, 49);
        expect(st.issues, isEmpty);
      },
    );

    test(
      'allowed in the settings while the app was closed: it finishes turning on when the app is back',
      () async {
        final rig = _Rig();
        rig.scheduler.perms = const AlarmPermissions(
          notifications: false,
          exactAlarms: true,
        );
        await rig.service.setEnabled(true);
        rig.scheduler.perms = const AlarmPermissions(
          notifications: true,
          exactAlarms: true,
        );
        await rig.service.onResume();
        expect((await PrayerAlarmPrefs.load()).enabled, isTrue);
        expect(rig.scheduler.alarms.length, 49);
      },
    );

    test(
      'without exact alarms, turning on does not switch it on and says what is needed',
      () async {
        final rig = _Rig();
        rig.scheduler.perms = const AlarmPermissions(
          notifications: true,
          exactAlarms: false,
        );
        final st = await rig.service.setEnabled(true);

        expect(st.enabled, isFalse);
        expect(st.missingPermission, PrayerAlarmPermission.exactAlarms);
        expect(st.justEnabled, isFalse, reason: 'no success message');
        expect(st.issues, {PrayerAlarmIssue.exactAlarmsOff});
        expect((await PrayerAlarmPrefs.load()).enabled, isFalse);
        expect(rig.scheduler.alarms, isEmpty);
        expect(
          rig.scheduler.scheduleCalls,
          isEmpty,
          reason: 'never an inexact one',
        );
        expect(
          rig.scheduler.exactRequests,
          0,
          reason: 'the screen explains first',
        );
      },
    );

    test(
      'the user agrees and allows it: switched on, all five prayers set, confirmed once',
      () async {
        final rig = _Rig();
        rig.scheduler.perms = const AlarmPermissions(
          notifications: true,
          exactAlarms: false,
        );
        await rig.service.setEnabled(true);

        final confirmations = <bool>[];
        rig.service.status.addListener(
          () => confirmations.add(rig.service.status.value.justEnabled),
        );
        // On Android's screen the user switches the permission on.
        rig.scheduler.onExactScreen = () async => rig.scheduler.perms =
            const AlarmPermissions(notifications: true, exactAlarms: true);
        final st = await rig.service.openExactAlarmSettings();

        expect(rig.scheduler.exactRequests, 1);
        expect(st.enabled, isTrue);
        expect(st.issues, isEmpty);
        expect(confirmations, contains(true));
        expect((await PrayerAlarmPrefs.load()).enabled, isTrue);
        expect(rig.scheduler.alarms.length, 49);
        expect(rig.scheduler.alarms.map(FakeAlarmScheduler.prayerOf).toSet(), {
          'fajr',
          'dhuhr',
          'asr',
          'maghrib',
          'isha',
        });

        // Planning again changes nothing and does not confirm a second time.
        rig.scheduler.resetCalls();
        final again = await rig.service.refresh();
        expect(again.justEnabled, isFalse);
        expect(rig.scheduler.scheduleCalls, isEmpty);
        expect(rig.scheduler.cancelCalls, isEmpty);
        expect(rig.alarmIds.length, 49);
      },
    );

    test(
      'allowed while the app was closed: it finishes turning on when the app is back',
      () async {
        final rig = _Rig();
        rig.scheduler.perms = const AlarmPermissions(
          notifications: true,
          exactAlarms: false,
        );
        await rig.service.setEnabled(true);
        // The user went to the system settings, allowed it, and the app came back
        // (or was opened again) on its own.
        rig.scheduler.perms = const AlarmPermissions(
          notifications: true,
          exactAlarms: true,
        );
        await rig.service.onResume();

        expect((await PrayerAlarmPrefs.load()).enabled, isTrue);
        expect(rig.scheduler.alarms.length, 49);
        expect(rig.service.status.value.enabled, isTrue);
      },
    );

    test(
      'the user comes back without allowing it: still off, still needed, nothing set',
      () async {
        final rig = _Rig();
        rig.scheduler.perms = const AlarmPermissions(
          notifications: true,
          exactAlarms: false,
        );
        await rig.service.setEnabled(true);
        final st = await rig.service
            .openExactAlarmSettings(); // nothing changes there

        expect(rig.scheduler.exactRequests, 1);
        expect(st.enabled, isFalse);
        expect(st.missingPermission, PrayerAlarmPermission.exactAlarms);
        expect(st.justEnabled, isFalse);
        expect(st.issues, {PrayerAlarmIssue.exactAlarmsOff});
        expect(rig.scheduler.alarms, isEmpty);
        expect(rig.scheduler.scheduleCalls, isEmpty);

        // Allowing it much later, by itself, must not switch the beep on behind the
        // user's back: they have to turn it on again.
        rig.scheduler.perms = const AlarmPermissions(
          notifications: true,
          exactAlarms: true,
        );
        await rig.service.onResume();
        expect((await PrayerAlarmPrefs.load()).enabled, isFalse);
        expect(rig.scheduler.alarms, isEmpty);
      },
    );

    test('Cancel leaves it off, with nothing remembered', () async {
      final rig = _Rig();
      rig.scheduler.perms = const AlarmPermissions(
        notifications: true,
        exactAlarms: false,
      );
      await rig.service.setEnabled(true);
      await rig.service.cancelPendingEnable();
      expect(rig.service.status.value.missingPermission, isNull);
      expect(rig.service.status.value.enabled, isFalse);

      rig.scheduler.perms = const AlarmPermissions(
        notifications: true,
        exactAlarms: true,
      );
      await rig.service.onResume();
      expect((await PrayerAlarmPrefs.load()).enabled, isFalse);
      expect(rig.scheduler.alarms, isEmpty);
    });

    test(
      'with exact alarms already allowed it switches on at once, with no extra screen',
      () async {
        final rig = _Rig();
        final st = await rig.service.setEnabled(true);
        expect(rig.scheduler.exactRequests, 0);
        expect(st.enabled, isTrue);
        expect(rig.scheduler.alarms.length, 49);
      },
    );

    test(
      'permission taken back later: warning, nothing left to ring late; restored: set again, no duplicates',
      () async {
        final rig = _Rig();
        await rig.running();
        expect(rig.scheduler.alarms.length, 49);
        expect(rig.service.status.value.hasWarning, isFalse);

        // Taken back in the system settings; the app resumes soon after (inside the
        // ten minutes in which a resume is normally ignored): it is still noticed.
        rig.scheduler.perms = const AlarmPermissions(
          notifications: true,
          exactAlarms: false,
        );
        rig.now = rig.now.add(const Duration(minutes: 3));
        await rig.service.onResume();
        var st = rig.service.status.value;
        expect(st.hasWarning, isTrue);
        expect(
          st.enabled,
          isTrue,
          reason: 'still wanted; it comes back by itself',
        );
        expect(st.issues, {PrayerAlarmIssue.exactAlarmsOff});
        expect(rig.scheduler.alarms, isEmpty);

        // Given back: planned again, every alarm once.
        rig.scheduler.perms = const AlarmPermissions(
          notifications: true,
          exactAlarms: true,
        );
        rig.now = rig.now.add(const Duration(minutes: 3));
        await rig.service.onResume();
        st = rig.service.status.value;
        expect(st.hasWarning, isFalse);
        expect(st.issues, isEmpty);
        expect(rig.scheduler.alarms.length, 49);
        expect(rig.alarmIds.length, 49);
        expect(
          rig.scheduler.scheduleCalls.toSet().length,
          rig.scheduler.scheduleCalls.length,
          reason: 'no alarm was set twice',
        );
      },
    );

    test(
      'notifications taken back later also give the warning, and the alarms come back with them',
      () async {
        final rig = _Rig();
        await rig.running();
        rig.scheduler.perms = const AlarmPermissions(
          notifications: false,
          exactAlarms: true,
        );
        rig.now = rig.now.add(const Duration(minutes: 3));
        await rig.service.onResume();
        var st = rig.service.status.value;
        expect(st.hasWarning, isTrue);
        expect(
          st.enabled,
          isTrue,
          reason: 'still wanted; it comes back by itself',
        );
        expect(st.issues, {PrayerAlarmIssue.notificationsBlocked});

        rig.scheduler.perms = const AlarmPermissions(
          notifications: true,
          exactAlarms: true,
        );
        rig.now = rig.now.add(const Duration(minutes: 3));
        await rig.service.onResume();
        st = rig.service.status.value;
        expect(st.hasWarning, isFalse);
        expect(rig.scheduler.alarms.length, 49);
        expect(rig.alarmIds.length, 49);
      },
    );

    test(
      'coming back with nothing on and nothing waiting does not touch the phone',
      () async {
        final rig = _Rig();
        await rig.service.onResume();
        expect(rig.scheduler.ensureReadyCalls, 0);
        expect(rig.scheduler.permissionRequests, 0);
      },
    );

    test('asking again for permissions plans again', () async {
      final rig = _Rig();
      await rig.running();
      final before = rig.scheduler.permissionRequests;
      await rig.service.requestPermissions(exactAlarms: true);
      expect(rig.scheduler.permissionRequests, before + 1);
    });
  });

  group('no place, no internet, errors', () {
    test(
      'no place known: asks for one (it is not guessed) and plans nothing',
      () async {
        final rig = _Rig();
        rig.place = null;
        await rig.switchOn();
        final st = await rig.service.refresh();
        expect(st.issues, contains(PrayerAlarmIssue.noLocation));
        expect(rig.scheduler.alarms, isEmpty);
        expect(rig.api.calls, isEmpty);
        expect(st.enabled, isTrue);
        expect(st.hasWarning, isTrue, reason: 'on, but nothing was set');
        expect(st.needsPermission, isFalse, reason: 'it is not a permission');
      },
    );

    test('turned on with no place: stays on, with the warning', () async {
      final rig = _Rig();
      rig.place = null;
      final st = await rig.service.setEnabled(true);
      expect(st.enabled, isTrue);
      expect(st.scheduled, 0);
      expect(st.hasWarning, isTrue);
      expect(st.justEnabled, isFalse, reason: 'no confirmation: nothing is set');
    });

    test(
      'the place cannot be found now: the last place used is used',
      () async {
        final rig = _Rig();
        await rig.running();
        rig.place = null;
        rig.now = _ist(2026, 10, 26, 7);
        final st = await rig.service.refresh();
        expect(st.issues, isEmpty);
        expect(rig.alarmTimes.last, _ist(2026, 11, 4, 19, 5));
      },
    );

    test('no internet and nothing saved: says so and plans nothing', () async {
      final api = FakeAladhan()..fail = true;
      final rig = _Rig(api: api);
      await rig.switchOn();
      final st = await rig.service.refresh();
      expect(st.issues, contains(PrayerAlarmIssue.noTimes));
      expect(rig.scheduler.alarms, isEmpty);
      expect(st.hasWarning, isTrue, reason: 'on, but nothing was set');
    });

    test('works offline from saved months, with no request at all', () async {
      final rig = _Rig();
      await rig.running();
      final requests = rig.api.calls.length;
      rig.api.fail = true;

      rig.now = _ist(2026, 10, 27, 7);
      rig.scheduler.fireDue(rig.now);
      final st = await rig.service.refresh();
      expect(st.issues, isEmpty);
      expect(rig.api.calls.length, requests);
      expect(rig.alarmTimes.last, _ist(2026, 11, 5, 19, 5));
    });

    test(
      'a failed download does not cancel alarms that are still good',
      () async {
        final rig = _Rig();
        await rig.running();
        final before = rig.alarmIds;
        rig.api.fail = true;
        // A new method has no saved months, so it needs the internet.
        await const PrayerSettings(method: 3).save();
        final st = await rig.service.refresh();
        expect(st.issues, contains(PrayerAlarmIssue.noTimes));
        expect(rig.scheduler.cancelCalls, isEmpty);
        expect(rig.alarmIds, before);
        expect(st.scheduled, before.length);
        expect(
          st.hasWarning,
          isFalse,
          reason: 'the alarms that are waiting are good; only a note',
        );
      },
    );

    test(
      'the system refusing one alarm does not stop the others; it is retried',
      () async {
        final rig = _Rig();
        await rig.switchOn();
        final refused = prayerAlarmId(2026, 10, 25, Prayer.fajr);
        rig.scheduler.failIds = {refused};
        final st = await rig.service.refresh();
        expect(st.issues, contains(PrayerAlarmIssue.failed));
        expect(rig.scheduler.alarms.length, 48);
        expect(st.hasWarning, isTrue, reason: 'one alarm is missing');

        rig.scheduler.failIds = {};
        rig.scheduler.resetCalls();
        final again = await rig.service.refresh();
        expect(again.issues, isEmpty);
        expect(again.hasWarning, isFalse);
        expect(rig.scheduler.scheduleCalls, [refused]);
        expect(rig.scheduler.alarms.length, 49);
      },
    );

    test(
      'the notification system not answering is reported, not thrown',
      () async {
        final rig = _Rig();
        await rig.switchOn();
        rig.scheduler.failPending = true;
        final st = await rig.service.refresh();
        expect(st.issues, contains(PrayerAlarmIssue.failed));
        expect(st.hasWarning, isTrue);
      },
    );

    test('a note about a place or times that cannot be refreshed is only a warning '
        'while nothing is waiting on the phone', () {
      const waiting = PrayerAlarmStatus(
        enabled: true,
        scheduled: 40,
        issues: {PrayerAlarmIssue.noLocation},
      );
      const empty = PrayerAlarmStatus(
        enabled: true,
        issues: {PrayerAlarmIssue.noLocation},
      );
      const off = PrayerAlarmStatus(issues: {PrayerAlarmIssue.failed});
      expect(waiting.hasWarning, isFalse);
      expect(empty.hasWarning, isTrue);
      expect(off.hasWarning, isFalse, reason: 'the beep is off');
    });
  });

  group('coming back to the app, restarts and time changes', () {
    test('coming back soon after planning does nothing', () async {
      final rig = _Rig();
      await rig.running();
      rig.now = rig.now.add(const Duration(minutes: 3));
      await rig.service.onResume();
      expect(rig.scheduler.scheduleCalls, isEmpty);
      expect(rig.scheduler.cancelCalls, isEmpty);
      expect(rig.lookups.length, 1);
    });

    test('coming back later tops the window up', () async {
      final rig = _Rig();
      await rig.running();
      rig.now = _ist(2026, 10, 27, 7);
      rig.scheduler.fireDue(rig.now);
      await rig.service.onResume();
      expect(rig.alarmTimes.last, _ist(2026, 11, 5, 19, 5));
    });

    test(
      'alarms lost by the system (a restart that did not restore them) come back',
      () async {
        final rig = _Rig();
        await rig.running();
        rig.scheduler.pendingById.clear();
        rig.scheduler.order.clear();
        rig.now = rig.now.add(const Duration(minutes: 30));
        await rig.service.onResume();
        expect(rig.scheduler.alarms.length, 49);
      },
    );

    test(
      'a changed time zone on the phone plans again even straight away',
      () async {
        final rig = _Rig();
        await rig.running();
        final state = await PrayerAlarmState.load();
        // The phone says it used to be on another offset.
        await PrayerAlarmState(
          lat: state.lat,
          lng: state.lng,
          deviceOffsetMinutes: -9999,
          lang: state.lang,
          scheduledThrough: state.scheduledThrough,
          lastRefresh: state.lastRefresh,
        ).save();
        rig.scheduler.pendingById.clear();
        rig.scheduler.order.clear();
        await rig.service.onResume();
        expect(rig.scheduler.alarms.length, 49);
        expect(
          (await PrayerAlarmState.load()).deviceOffsetMinutes,
          isNot(-9999),
        );
      },
    );

    test(
      'coming back from the system settings plans again straight away',
      () async {
        final rig = _Rig();
        await rig.running();
        await rig.service.openSystemSettings();
        expect(rig.scheduler.settingsOpened, 1);
        rig.scheduler.pendingById.clear();
        rig.scheduler.order.clear();
        await rig.service.onResume();
        expect(rig.scheduler.alarms.length, 49);
      },
    );

    test(
      'the background top-up uses no GPS and does not register itself again',
      () async {
        final rig = _Rig();
        await rig.running();
        final syncs = rig.maintenance.calls.length;
        await rig.service.refresh(reason: 'background', foreground: false);
        expect(rig.lookups.last.foreground, isFalse);
        expect(rig.maintenance.calls.length, syncs);
      },
    );
  });

  group('the saved state', () {
    test(
      'remembers the place, the language and how far the alarms go',
      () async {
        final rig = _Rig();
        await rig.running();
        final s = await PrayerAlarmState.load();
        expect(s.lat, 34.08);
        expect(s.lng, 74.8);
        expect(s.lang, 'en');
        expect(s.scheduledThrough, _ist(2026, 11, 2, 19, 5));
        expect(s.lastRefresh, _start);
      },
    );
  });
}
