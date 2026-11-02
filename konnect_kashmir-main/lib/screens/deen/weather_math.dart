import 'dart:math' as math;

/// Sunrise and sunset, worked out on the phone (NOAA's solar calculation, good to
/// about a minute), so no weather service has to supply them.
///
/// Returned as minutes after midnight on the clock of the place ([utcOffset] is
/// that clock's difference from UTC). Null where the sun does not rise or set that
/// day (polar day or night).
({int rise, int set})? sunTimes(
  double lat,
  double lng,
  int year,
  int month,
  int day,
  Duration utcOffset,
) {
  final jd = _julianDay(year, month, day);
  int? at(bool rise) {
    // A second pass with the first answer moves the sun to where it really is then.
    final first = _sunUtcMinutes(rise, jd, lat, lng);
    if (first == null) return null;
    final second = _sunUtcMinutes(rise, jd + first / 1440.0, lat, lng);
    if (second == null) return null;
    final local = (second + utcOffset.inMinutes) % 1440;
    return local.round() % 1440;
  }

  final r = at(true);
  final s = at(false);
  if (r == null || s == null) return null;
  return (rise: r, set: s);
}

double _rad(double d) => d * math.pi / 180;
double _deg(double r) => r * 180 / math.pi;

/// Julian day number at 0h UT of the date.
double _julianDay(int year, int month, int day) {
  var y = year;
  var m = month;
  if (m <= 2) {
    y -= 1;
    m += 12;
  }
  final a = (y / 100).floor();
  final b = 2 - a + (a / 4).floor();
  return (365.25 * (y + 4716)).floorToDouble() +
      (30.6001 * (m + 1)).floorToDouble() +
      day +
      b -
      1524.5;
}

/// UTC minutes after midnight of the sunrise ([rise]) or sunset, or null when the
/// sun never crosses the horizon.
double? _sunUtcMinutes(bool rise, double jd, double lat, double lng) {
  final t = (jd - 2451545.0) / 36525.0;
  final l0 = (280.46646 + t * (36000.76983 + t * 0.0003032)) % 360;
  final m = 357.52911 + t * (35999.05029 - 0.0001537 * t);
  final e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t);
  final mr = _rad(m);
  final c = math.sin(mr) * (1.914602 - t * (0.004817 + 0.000014 * t)) +
      math.sin(2 * mr) * (0.019993 - 0.000101 * t) +
      math.sin(3 * mr) * 0.000289;
  final trueLong = l0 + c;
  final omega = 125.04 - 1934.136 * t;
  final lambda = trueLong - 0.00569 - 0.00478 * math.sin(_rad(omega));
  final seconds = 21.448 - t * (46.8150 + t * (0.00059 - t * 0.001813));
  final meanObliq = 23.0 + (26.0 + seconds / 60.0) / 60.0;
  final obliq = meanObliq + 0.00256 * math.cos(_rad(omega));
  final decl = math.asin(math.sin(_rad(obliq)) * math.sin(_rad(lambda)));

  // The equation of time: how far the sun runs ahead of or behind the clock.
  final y = math.pow(math.tan(_rad(obliq) / 2), 2).toDouble();
  final l0r = _rad(l0);
  final eqTime = _deg(y * math.sin(2 * l0r) -
          2 * e * math.sin(mr) +
          4 * e * y * math.sin(mr) * math.cos(2 * l0r) -
          0.5 * y * y * math.sin(4 * l0r) -
          1.25 * e * e * math.sin(2 * mr)) *
      4;

  final latr = _rad(lat);
  final arg = math.cos(_rad(90.833)) / (math.cos(latr) * math.cos(decl)) -
      math.tan(latr) * math.tan(decl);
  if (arg < -1 || arg > 1) return null;
  var hourAngle = math.acos(arg);
  if (!rise) hourAngle = -hourAngle;
  return 720 - 4 * (lng + _deg(hourAngle)) - eqTime;
}

/// How the air feels, from the temperature ([tempC]), relative humidity
/// ([humidity], percent) and wind ([windKmh]), by the two official indexes, each
/// only where it is defined:
///
/// * cold (10 °C or less) with some wind (over 4.8 km/h): the wind chill;
/// * hot (27 °C or more) and humid (40 % or more): the heat index.
///
/// Null anywhere else. No index is defined there, and the weather service gives no
/// "feels like" either, so nothing is made up: the card shows no such line then.
double? feelsLikeC(double tempC, double humidity, double windKmh) {
  if (tempC <= 10 && windKmh > 4.8) {
    final v = math.pow(windKmh, 0.16).toDouble();
    return 13.12 + 0.6215 * tempC - 11.37 * v + 0.3965 * tempC * v;
  }
  if (tempC >= 27 && humidity >= 40) {
    final t = tempC * 9 / 5 + 32;
    final r = humidity;
    final hi = -42.379 +
        2.04901523 * t +
        10.14333127 * r -
        0.22475541 * t * r -
        0.00683783 * t * t -
        0.05481717 * r * r +
        0.00122874 * t * t * r +
        0.00085282 * t * r * r -
        0.00000199 * t * t * r * r;
    return (hi - 32) * 5 / 9;
  }
  return null;
}
