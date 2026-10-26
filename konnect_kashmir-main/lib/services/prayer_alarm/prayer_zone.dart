import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;

/// Turns a prayer time written on a wall clock ("05:12 on 24 Oct") into the real
/// moment it happens, and finds which calendar day a moment falls on.
///
/// Aladhan gives times in the clock of the place they were worked out for, so
/// that place's zone (not the phone's) is what must be used. It also keeps a
/// daylight-saving change from moving an alarm by an hour.
abstract class PrayerZone {
  /// The moment (UTC) of [h]:[mi] on the calendar day [y]-[m]-[d] in this zone.
  /// A day past the end of the month (for example `d = 32`) rolls over.
  DateTime instant(int y, int m, int d, int h, int mi);

  /// The calendar day, in this zone, that [at] falls on.
  ({int y, int m, int d}) dateOf(DateTime at);
}

/// A zone with one fixed offset from UTC. Used when no zone name is known.
class FixedOffsetZone implements PrayerZone {
  final Duration offset;
  const FixedOffsetZone(this.offset);

  @override
  DateTime instant(int y, int m, int d, int h, int mi) =>
      DateTime.utc(y, m, d, h, mi).subtract(offset);

  @override
  ({int y, int m, int d}) dateOf(DateTime at) {
    final l = at.toUtc().add(offset);
    return (y: l.year, m: l.month, d: l.day);
  }
}

/// A named zone from the time-zone database ("Asia/Kolkata", "America/New_York").
class TzPrayerZone implements PrayerZone {
  final tz.Location location;
  const TzPrayerZone(this.location);

  @override
  DateTime instant(int y, int m, int d, int h, int mi) =>
      tz.TZDateTime(location, y, m, d, h, mi).toUtc();

  @override
  ({int y, int m, int d}) dateOf(DateTime at) {
    final l = tz.TZDateTime.from(at, location);
    return (y: l.year, m: l.month, d: l.day);
  }
}

/// The zone for [name] (needs `tz.initializeTimeZones()` to have run), or a fixed
/// [fallback] offset when the name is missing or unknown.
PrayerZone prayerZoneFor(String? name, Duration fallback) {
  if (name != null && name.isNotEmpty) {
    try {
      return TzPrayerZone(tz.getLocation(name));
    } catch (e) {
      debugPrint('[PrayerAlarm] unknown time zone "$name": $e');
    }
  }
  return FixedOffsetZone(fallback);
}
