import 'prayer_calendar.dart';
import 'prayer_zone.dart';

/// The five daily prayers, in the order they come in the day.
enum Prayer { fajr, dhuhr, asr, maghrib, isha }

/// How many days the alarms are planned ahead (today counts as the first). A
/// week to ten days keeps the phone's pending list small, and every time the app
/// opens the window moves forward again.
const int kDefaultWindowDays = 10;

/// An alarm is never planned for a moment closer than this to "now": by the time
/// it reached the system it would already be in the past.
const Duration kMinLead = Duration(seconds: 5);

/// Notification ids that belong to the prayer alarms live in one block, far above
/// the ids the app's other notifications use, so cancelling or counting "our"
/// notifications can never touch anything else.
const int kPrayerIdBase = 1500000000;
const int kPrayerIdSpan = 1000000;

bool isPrayerAlarmId(int id) =>
    id >= kPrayerIdBase && id < kPrayerIdBase + kPrayerIdSpan;

/// The same day and prayer always give the same id, so planning twice can never
/// leave two alarms for one prayer.
int prayerAlarmId(int y, int m, int d, Prayer p) {
  final days =
      DateTime.utc(y, m, d).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
  return kPrayerIdBase + days * 8 + p.index;
}

/// One alarm to put on the phone.
class PlannedAlarm {
  final int id;
  final Prayer prayer;

  /// When it should sound (UTC).
  final DateTime at;
  const PlannedAlarm(this.id, this.prayer, this.at);

  @override
  String toString() =>
      'PlannedAlarm(${prayer.name} $id ${at.toIso8601String()})';
}

({int h, int mi})? _parse(String hm) {
  final p = hm.split(':');
  if (p.length != 2) return null;
  final h = int.tryParse(p[0]);
  final mi = int.tryParse(p[1]);
  if (h == null || mi == null || h < 0 || h > 23 || mi < 0 || mi > 59) {
    return null;
  }
  return (h: h, mi: mi);
}

/// The alarms to have on the phone, soonest first: every enabled prayer from now
/// until [windowDays] days ahead, never more than [maxAlarms].
///
/// * Moments that have already passed are left out.
/// * A day the calendar has no times for is skipped (nothing is guessed).
/// * If a prayer's clock time comes before the one before it (Isha at "00:20" in
///   far-north summers) it belongs to the next morning, so it is moved a day on.
/// * The next [windowDays] days start with today; yesterday's row is also read
///   so a prayer moved past midnight is still found.
List<PlannedAlarm> planAlarms({
  required DateTime now,
  required PrayerCalendar calendar,
  required PrayerZone zone,
  required Set<Prayer> enabled,
  required int maxAlarms,
  int windowDays = kDefaultWindowDays,
}) {
  if (enabled.isEmpty ||
      maxAlarms <= 0 ||
      windowDays <= 0 ||
      calendar.isEmpty) {
    return const [];
  }
  final earliest = now.toUtc().add(kMinLead);
  final today = zone.dateOf(now);
  final byId = <int, PlannedAlarm>{};

  for (var offset = -1; offset < windowDays; offset++) {
    // DateTime.utc rolls over month and year ends for us.
    final row = DateTime.utc(today.y, today.m, today.d + offset);
    final times = calendar.days[dayKey(row.year, row.month, row.day)];
    if (times == null || times.length != 5) continue;

    var shift = 0;
    DateTime? previous;
    for (final p in Prayer.values) {
      final hm = _parse(times[p.index]);
      if (hm == null) continue;
      var at = zone.instant(row.year, row.month, row.day + shift, hm.h, hm.mi);
      if (previous != null && !at.isAfter(previous)) {
        shift++;
        at = zone.instant(row.year, row.month, row.day + shift, hm.h, hm.mi);
      }
      previous = at;
      if (!enabled.contains(p) || at.isBefore(earliest)) continue;
      final id = prayerAlarmId(row.year, row.month, row.day, p);
      byId[id] = PlannedAlarm(id, p, at);
    }
  }

  final all = byId.values.toList()..sort((a, b) => a.at.compareTo(b.at));
  return all.length <= maxAlarms ? all : all.sublist(0, maxAlarms);
}
