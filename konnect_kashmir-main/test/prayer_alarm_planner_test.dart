import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/services/prayer_alarm/prayer_alarm_planner.dart';
import 'package:konnect_kashmir/services/prayer_alarm/prayer_calendar.dart';
import 'package:konnect_kashmir/services/prayer_alarm/prayer_zone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

const _ist = FixedOffsetZone(Duration(hours: 5, minutes: 30));
const _daily = ['05:10', '12:15', '15:30', '17:45', '19:05'];

/// The same five times on every day from [from] for [days] days.
PrayerCalendar _calendar(
  DateTime from,
  int days, {
  List<String> times = _daily,
}) {
  return PrayerCalendar(
    days: {
      for (var i = 0; i < days; i++)
        dayKey(
          DateTime.utc(from.year, from.month, from.day + i).year,
          DateTime.utc(from.year, from.month, from.day + i).month,
          DateTime.utc(from.year, from.month, from.day + i).day,
        ): times,
    },
  );
}

/// A moment given on the Indian clock (UTC+5:30).
DateTime _at(int y, int m, int d, int h, [int mi = 0]) => DateTime.utc(
  y,
  m,
  d,
  h,
  mi,
).subtract(const Duration(hours: 5, minutes: 30));

List<PlannedAlarm> _plan(
  DateTime now,
  PrayerCalendar cal, {
  Set<Prayer> enabled = const {...Prayer.values},
  int max = 100,
  int window = 10,
  PrayerZone zone = _ist,
}) => planAlarms(
  now: now,
  calendar: cal,
  zone: zone,
  enabled: enabled,
  maxAlarms: max,
  windowDays: window,
);

void main() {
  // Before the groups below build their zones.
  tzdata.initializeTimeZones();

  group('notification ids', () {
    test('the same day and prayer always give the same id', () {
      expect(
        prayerAlarmId(2026, 10, 24, Prayer.asr),
        prayerAlarmId(2026, 10, 24, Prayer.asr),
      );
    });

    test(
      'every prayer of every day for years has its own id, inside our block',
      () {
        final seen = <int>{};
        for (
          var d = DateTime.utc(2025, 1, 1);
          d.isBefore(DateTime.utc(2035, 1, 1));
          d = d.add(const Duration(days: 1))
        ) {
          for (final p in Prayer.values) {
            final id = prayerAlarmId(d.year, d.month, d.day, p);
            expect(isPrayerAlarmId(id), isTrue);
            expect(seen.add(id), isTrue, reason: 'duplicate id for $d $p');
          }
        }
      },
    );

    test(
      'ids are positive 32-bit numbers, far above the ids other features use',
      () {
        final id = prayerAlarmId(2099, 12, 31, Prayer.isha);
        expect(id, lessThan(2147483647));
        expect(
          kPrayerIdBase,
          greaterThan(1 << 30),
        ); // beyond any message hashCode
        expect(isPrayerAlarmId(12345), isFalse);
        expect(isPrayerAlarmId(kPrayerIdBase - 1), isFalse);
        expect(isPrayerAlarmId(kPrayerIdBase + kPrayerIdSpan), isFalse);
      },
    );
  });

  group('the plan', () {
    final now = _at(2026, 10, 24, 6); // 06:00 IST: Fajr (05:10) has passed

    test('has all five prayers of a day, in order, at the right moments', () {
      final plan = _plan(
        _at(2026, 10, 24, 0, 5),
        _calendar(DateTime.utc(2026, 10, 24), 1),
      );
      expect(plan.map((a) => a.prayer), Prayer.values);
      expect(plan.map((a) => a.at), [
        _at(2026, 10, 24, 5, 10),
        _at(2026, 10, 24, 12, 15),
        _at(2026, 10, 24, 15, 30),
        _at(2026, 10, 24, 17, 45),
        _at(2026, 10, 24, 19, 5),
      ]);
      expect(plan.every((a) => a.at.isUtc), isTrue);
    });

    test('leaves out prayers that have already passed today', () {
      final plan = _plan(now, _calendar(DateTime.utc(2026, 10, 24), 1));
      expect(plan.map((a) => a.prayer), [
        Prayer.dhuhr,
        Prayer.asr,
        Prayer.maghrib,
        Prayer.isha,
      ]);
      expect(plan.every((a) => a.at.isAfter(now)), isTrue);
    });

    test('never plans a moment that is not at least a few seconds away', () {
      final fajr = _at(2026, 10, 24, 5, 10);
      final cal = _calendar(DateTime.utc(2026, 10, 24), 1);
      expect(
        _plan(
          fajr.subtract(const Duration(seconds: 2)),
          cal,
        ).map((a) => a.prayer),
        isNot(contains(Prayer.fajr)),
      );
      expect(
        _plan(
          fajr.subtract(const Duration(seconds: 30)),
          cal,
        ).map((a) => a.prayer),
        contains(Prayer.fajr),
      );
    });

    test('covers the window: today and the days after it', () {
      final cal = _calendar(DateTime.utc(2026, 10, 20), 30);
      final plan = _plan(_at(2026, 10, 24, 0, 5), cal, window: 10);
      expect(plan.length, 50);
      expect(plan.last.at, _at(2026, 11, 2, 19, 5)); // 24 Oct + 9 days
      expect(_plan(_at(2026, 10, 24, 0, 5), cal, window: 3).length, 15);
    });

    test('is sorted soonest first and has no duplicate ids', () {
      final plan = _plan(
        _at(2026, 10, 24, 0, 5),
        _calendar(DateTime.utc(2026, 10, 24), 20),
      );
      for (var i = 1; i < plan.length; i++) {
        expect(plan[i].at.isAfter(plan[i - 1].at), isTrue);
      }
      expect(plan.map((a) => a.id).toSet().length, plan.length);
    });

    test('only the prayers that are switched on', () {
      final cal = _calendar(DateTime.utc(2026, 10, 24), 5);
      final start = _at(2026, 10, 24, 0, 5);
      expect(
        _plan(start, cal, enabled: {Prayer.fajr}).map((a) => a.prayer).toSet(),
        {Prayer.fajr},
      );
      expect(_plan(start, cal, enabled: {Prayer.fajr, Prayer.isha}).length, 10);
      expect(_plan(start, cal, enabled: {}), isEmpty);
    });

    test('is cut to the room available, keeping the soonest', () {
      final cal = _calendar(DateTime.utc(2026, 10, 24), 20);
      final full = _plan(_at(2026, 10, 24, 0, 5), cal);
      final cut = _plan(_at(2026, 10, 24, 0, 5), cal, max: 12);
      expect(cut.map((a) => a.id), full.take(12).map((a) => a.id));
      expect(_plan(_at(2026, 10, 24, 0, 5), cal, max: 0), isEmpty);
    });

    test(
      'skips a day the calendar does not have, and a time that is not a time',
      () {
        final cal = PrayerCalendar(
          days: {
            '2026-10-24': ['05:10', 'garbage', '15:30', '17:45', '19:05'],
            // 25th is missing
            '2026-10-26': _daily,
          },
        );
        final plan = _plan(_at(2026, 10, 24, 0, 5), cal);
        expect(
          plan
              .where((a) => a.at.isBefore(_at(2026, 10, 26, 0)))
              .map((a) => a.prayer),
          [Prayer.fajr, Prayer.asr, Prayer.maghrib, Prayer.isha],
        );
        expect(plan.length, 4 + 5);
      },
    );

    test('an empty calendar gives nothing', () {
      expect(_plan(now, const PrayerCalendar()), isEmpty);
    });
  });

  group('midnight and the end of the month or year', () {
    test('after Isha the next alarm is tomorrow\'s Fajr', () {
      final plan = _plan(
        _at(2026, 10, 24, 22),
        _calendar(DateTime.utc(2026, 10, 24), 3),
      );
      expect(plan.first.prayer, Prayer.fajr);
      expect(plan.first.at, _at(2026, 10, 25, 5, 10));
    });

    test('the window crosses a month end and a year end', () {
      final cal = _calendar(DateTime.utc(2026, 12, 28), 10);
      final plan = _plan(_at(2026, 12, 30, 0, 5), cal, window: 5);
      expect(plan.map((a) => a.at).last, _at(2027, 1, 3, 19, 5));
      expect(plan.length, 25);
      expect(plan.map((a) => a.id).toSet().length, 25);
    });

    test(
      'the day is the place\'s day, not the phone\'s: 23:30 UTC is already tomorrow in India',
      () {
        // 24 Oct 23:30 UTC = 25 Oct 05:00 IST, just before Fajr at 05:10.
        final plan = _plan(
          DateTime.utc(2026, 10, 24, 23, 30),
          _calendar(DateTime.utc(2026, 10, 24), 4),
        );
        expect(plan.first.prayer, Prayer.fajr);
        expect(plan.first.at, _at(2026, 10, 25, 5, 10));
      },
    );

    test(
      'a prayer written as after midnight (far-north Isha) belongs to the next morning',
      () {
        final cal = _calendar(
          DateTime.utc(2026, 6, 20),
          3,
          times: ['02:30', '13:30', '18:30', '22:45', '00:20'],
        );
        final plan = _plan(_at(2026, 6, 20, 0, 5), cal, window: 1);
        final isha = plan.firstWhere((a) => a.prayer == Prayer.isha);
        expect(isha.at, _at(2026, 6, 21, 0, 20));
        // Its id is still the day of the row it came from, so it cannot clash.
        expect(isha.id, prayerAlarmId(2026, 6, 20, Prayer.isha));
        expect(plan.map((a) => a.id).toSet().length, plan.length);
      },
    );
  });

  group('daylight saving', () {
    final ny = TzPrayerZone(tz.getLocation('America/New_York'));
    final cal = PrayerCalendar(
      timeZone: 'America/New_York',
      days: {
        for (final d in ['2026-03-07', '2026-03-08', '2026-03-09'])
          d: ['05:30', '12:00', '15:30', '18:00', '19:30'],
      },
    );

    test('a prayer keeps its clock time when the clocks change', () {
      final plan = planAlarms(
        now: DateTime.utc(2026, 3, 7, 0),
        calendar: cal,
        zone: ny,
        enabled: {Prayer.fajr},
        maxAlarms: 10,
        windowDays: 4,
      );
      final byDay = {for (final a in plan) a.id: a.at};
      expect(
        byDay[prayerAlarmId(2026, 3, 7, Prayer.fajr)],
        DateTime.utc(2026, 3, 7, 10, 30),
      ); // EST
      expect(
        byDay[prayerAlarmId(2026, 3, 8, Prayer.fajr)],
        DateTime.utc(2026, 3, 8, 9, 30),
      ); // EDT
      expect(
        byDay[prayerAlarmId(2026, 3, 9, Prayer.fajr)],
        DateTime.utc(2026, 3, 9, 9, 30),
      );
    });

    test('knows which local day a moment is on', () {
      // 03:30 UTC on 8 March is still the evening of the 7th in New York.
      expect(ny.dateOf(DateTime.utc(2026, 3, 8, 3, 30)), (y: 2026, m: 3, d: 7));
      expect(ny.dateOf(DateTime.utc(2026, 3, 8, 12)), (y: 2026, m: 3, d: 8));
    });

    test('an unknown zone name falls back to the phone\'s offset', () {
      final z = prayerZoneFor(
        'Mars/Olympus',
        const Duration(hours: 5, minutes: 30),
      );
      expect(z.instant(2026, 10, 24, 5, 10), _at(2026, 10, 24, 5, 10));
      expect(
        prayerZoneFor(null, const Duration(hours: 1)),
        isA<FixedOffsetZone>(),
      );
      expect(prayerZoneFor('Asia/Kolkata', Duration.zero), isA<TzPrayerZone>());
    });
  });
}
