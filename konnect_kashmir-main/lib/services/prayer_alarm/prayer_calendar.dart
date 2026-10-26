import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../screens/deen/prayer_service.dart';
import '../shared_http.dart';

/// "2026-10-24": the key of one day in a [PrayerCalendar].
String dayKey(int y, int m, int d) =>
    '$y-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';

final RegExp _hm = RegExp(r'^\d{1,2}:\d{2}$');

/// Several days of prayer times for one place: for each date the five times
/// (Fajr, Dhuhr, Asr, Maghrib, Isha) as "HH:mm" on that place's own clock.
class PrayerCalendar {
  /// The place's time-zone name ("Asia/Kolkata"), when Aladhan gave one.
  final String? timeZone;
  final Map<String, List<String>> days;
  const PrayerCalendar({this.timeZone, this.days = const {}});

  bool get isEmpty => days.isEmpty;

  PrayerCalendar merge(PrayerCalendar other) => PrayerCalendar(
    timeZone: timeZone ?? other.timeZone,
    days: {...days, ...other.days},
  );

  Map<String, dynamic> toJson() => {'tz': timeZone, 'days': days};

  factory PrayerCalendar.fromJson(Map<String, dynamic> j) {
    final days = <String, List<String>>{};
    (j['days'] as Map).forEach((k, v) {
      final list = (v as List).map((e) => e.toString()).toList();
      if (list.length == 5 && list.every(_hm.hasMatch)) {
        days[k as String] = list;
      }
    });
    return PrayerCalendar(timeZone: j['tz'] as String?, days: days);
  }

  /// Reads Aladhan's `/calendar/{year}/{month}` answer. Days that are missing a
  /// time are left out rather than guessed.
  factory PrayerCalendar.fromApi(Map<String, dynamic> body) {
    final days = <String, List<String>>{};
    String? zone;
    for (final raw in (body['data'] as List)) {
      try {
        final e = raw as Map;
        final t = Map<String, dynamic>.from(e['timings'] as Map);
        // Aladhan may add a zone suffix such as "05:12 (IST)"; keep just HH:mm.
        String hm(dynamic v) => v.toString().trim().split(' ').first;
        final times = [
          hm(t['Fajr']),
          hm(t['Dhuhr']),
          hm(t['Asr']),
          hm(t['Maghrib']),
          hm(t['Isha']),
        ];
        if (!times.every(_hm.hasMatch)) continue;
        final g = (e['date'] as Map)['gregorian'] as Map; // "dd-MM-yyyy"
        final parts = g['date'].toString().split('-');
        days[dayKey(
              int.parse(parts[2]),
              int.parse(parts[1]),
              int.parse(parts[0]),
            )] =
            times;
        zone ??= (e['meta'] as Map?)?['timezone']?.toString();
      } catch (_) {
        // One odd day must not lose the rest of the month.
      }
    }
    return PrayerCalendar(timeZone: zone, days: days);
  }
}

/// Gets whole months of prayer times from Aladhan and keeps each month on the
/// phone, so the alarms can be planned (and topped up) with no internet.
class PrayerCalendarSource {
  /// Returns the response body for [uri], or throws.
  final Future<String> Function(Uri uri) _fetch;

  PrayerCalendarSource({Future<String> Function(Uri uri)? fetch})
    : _fetch = fetch ?? _defaultFetch;

  static Future<String> _defaultFetch(Uri uri) async {
    final res = await sharedHttp.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('Prayer times unavailable (${res.statusCode})');
    }
    return res.body;
  }

  static const String _prefix = 'prayer_cal_';

  /// Places 0.01° apart (about a kilometre) share one saved month.
  static String _key(int y, int m, double lat, double lng, PrayerSettings s) =>
      '$_prefix$y${m.toString().padLeft(2, '0')}'
      '_${lat.toStringAsFixed(2)}_${lng.toStringAsFixed(2)}'
      '_m${s.effectiveMethod}_s${s.school}';

  /// The saved month, or null.
  Future<PrayerCalendar?> cached(
    int y,
    int m,
    double lat,
    double lng,
    PrayerSettings s,
  ) async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(
        _key(y, m, lat, lng, s),
      );
      if (raw == null) return null;
      final cal = PrayerCalendar.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      return cal.isEmpty ? null : cal;
    } catch (_) {
      return null;
    }
  }

  Future<PrayerCalendar> _download(
    int y,
    int m,
    double lat,
    double lng,
    PrayerSettings s,
  ) async {
    final uri = Uri.parse(
      'https://api.aladhan.com/v1/calendar/$y/$m'
      '?latitude=${lat.toStringAsFixed(2)}&longitude=${lng.toStringAsFixed(2)}'
      '&method=${s.effectiveMethod}&school=${s.school}',
    );
    final body = jsonDecode(await _fetch(uri)) as Map<String, dynamic>;
    final cal = PrayerCalendar.fromApi(body);
    if (cal.isEmpty) throw Exception('Prayer times for $y-$m were empty');
    return cal;
  }

  /// The prayer times of each month in [months] (year, month) for this place and
  /// settings, merged into one calendar. A saved month is used as it is; a month
  /// that is not saved is downloaded when [allowNetwork] is true. A month that can
  /// be neither read nor downloaded is simply missing from the result.
  Future<PrayerCalendar> load({
    required double lat,
    required double lng,
    required PrayerSettings settings,
    required List<({int y, int m})> months,
    bool allowNetwork = true,
  }) async {
    var out = const PrayerCalendar();
    for (final mo in months) {
      var cal = await cached(mo.y, mo.m, lat, lng, settings);
      if (cal == null && allowNetwork) {
        try {
          cal = await _download(mo.y, mo.m, lat, lng, settings);
          await _save(mo.y, mo.m, lat, lng, settings, cal);
        } catch (e) {
          debugPrint('[PrayerAlarm] ${mo.y}-${mo.m} not downloaded: $e');
        }
      }
      if (cal != null) out = out.merge(cal);
    }
    return out;
  }

  Future<void> _save(
    int y,
    int m,
    double lat,
    double lng,
    PrayerSettings s,
    PrayerCalendar cal,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(y, m, lat, lng, s), jsonEncode(cal.toJson()));
      await _prune(prefs, y, m);
    } catch (e) {
      debugPrint('[PrayerAlarm] cache: $e');
    }
  }

  /// Forgets saved months older than last month so the phone does not collect
  /// them (every place, method and school has its own).
  Future<void> _prune(SharedPreferences prefs, int y, int m) async {
    final keep = (y * 12 + m) - 1;
    for (final k
        in prefs.getKeys().where((k) => k.startsWith(_prefix)).toList()) {
      final stamp = int.tryParse(
        k.substring(_prefix.length, _prefix.length + 6),
      );
      if (stamp == null) continue;
      final month = (stamp ~/ 100) * 12 + stamp % 100;
      if (month < keep) await prefs.remove(k);
    }
  }
}
