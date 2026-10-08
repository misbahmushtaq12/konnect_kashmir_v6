import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// The Kaaba, Makkah.
const double kKaabaLat = 21.4225;
const double kKaabaLng = 39.8262;

/// Qibla bearing in degrees clockwise from true North, for a place at
/// ([lat], [lng]):
///
///   qibla = atan2(sin(Δλ), cos(φ1)·tan(φ2) − sin(φ1)·cos(Δλ))
///
/// with φ1 = the user's latitude, φ2 = 21.4225 and Δλ = 39.8262 − the user's
/// longitude. Worked out on the phone, no web service involved.
double qiblaBearing(double lat, double lng) {
  final phi1 = lat * math.pi / 180;
  final phi2 = kKaabaLat * math.pi / 180;
  final dLambda = (kKaabaLng - lng) * math.pi / 180;
  final y = math.sin(dLambda);
  final x = math.cos(phi1) * math.tan(phi2) - math.sin(phi1) * math.cos(dLambda);
  final deg = math.atan2(y, x) * 180 / math.pi;
  return (deg + 360) % 360;
}

/// How far (degrees, -180..180) the Qibla indicator must turn from the top of
/// the phone: qibla − device heading.
double qiblaTurn(double qibla, double heading) {
  var d = (qibla - heading) % 360;
  if (d > 180) d -= 360;
  if (d < -180) d += 360;
  return d;
}

class PrayerDay {
  /// 24-hour "HH:mm" as returned by Aladhan.
  final String fajr, dhuhr, asr, maghrib, isha;

  /// e.g. "17 Rabi' al-thani 1448" (from `data.date.hijri`).
  final String hijri;

  const PrayerDay({
    required this.fajr,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.hijri,
  });

  List<String> get times => [fajr, dhuhr, asr, maghrib, isha];

  factory PrayerDay.fromApi(Map<String, dynamic> data) {
    final t = Map<String, dynamic>.from(data['timings'] as Map);
    // Aladhan may add a zone suffix such as "05:12 (IST)"; keep just HH:mm.
    String hm(dynamic v) => v.toString().trim().split(' ').first;
    String hijri = '';
    try {
      final h = data['date']['hijri'] as Map;
      hijri = '${h['day']} ${h['month']['en']} ${h['year']}';
    } catch (_) {}
    return PrayerDay(
      fajr: hm(t['Fajr']),
      dhuhr: hm(t['Dhuhr']),
      asr: hm(t['Asr']),
      maghrib: hm(t['Maghrib']),
      isha: hm(t['Isha']),
      hijri: hijri,
    );
  }

  Map<String, dynamic> toJson() => {
        'fajr': fajr,
        'dhuhr': dhuhr,
        'asr': asr,
        'maghrib': maghrib,
        'isha': isha,
        'hijri': hijri,
      };

  factory PrayerDay.fromJson(Map<String, dynamic> j) => PrayerDay(
        fajr: j['fajr'],
        dhuhr: j['dhuhr'],
        asr: j['asr'],
        maghrib: j['maghrib'],
        isha: j['isha'],
        hijri: j['hijri'] ?? '',
      );
}

enum Madhhab { hanafi, shafi, maliki, hanbali, jafari }

/// AlAdhan calculation methods (ids as the AlAdhan API defines them).
const List<(int, String)> kPrayerMethods = [
  (1, 'University of Islamic Sciences, Karachi'),
  (3, 'Muslim World League'),
  (2, 'Islamic Society of North America (ISNA)'),
  (4, 'Umm Al-Qura University, Makkah'),
  (5, 'Egyptian General Authority of Survey'),
  (7, 'Institute of Geophysics, University of Tehran'),
  (0, 'Jafari / Shia Ithna-Ashari'),
  (8, 'Gulf Region'),
  (9, 'Kuwait'),
  (10, 'Qatar'),
  (11, 'Singapore'),
  (13, 'Turkey / Diyanet'),
  (15, 'Moonsighting Committee'),
  (16, 'Dubai'),
  (17, 'JAKIM'),
  (18, 'Tunisia'),
  (19, 'Algeria'),
  (20, 'Indonesia'),
  (21, 'Morocco'),
  (22, 'Portugal'),
  (23, 'Jordan'),
];

/// The user's two independent choices. Madhhab sets the AlAdhan `school`
/// (it moves Asr only); the calculation method sets the astronomical
/// parameters (Fajr, Isha...). Defaults: Hanafi + Karachi = method 1, school 1.
class PrayerSettings {
  final Madhhab madhhab;
  final int method;
  const PrayerSettings({this.madhhab = Madhhab.hanafi, this.method = 1});

  /// AlAdhan `school`: 1 = Hanafi, 0 = the standard (Shafi, Maliki, Hanbali,
  /// Ja'fari) Asr.
  int get school => madhhab == Madhhab.hanafi ? 1 : 0;

  /// Ja'fari prayer times use the Jafari method (id 0); the chosen method is
  /// kept and comes back when another madhhab is picked.
  int get effectiveMethod => madhhab == Madhhab.jafari ? 0 : method;

  PrayerSettings copyWith({Madhhab? madhhab, int? method}) =>
      PrayerSettings(madhhab: madhhab ?? this.madhhab, method: method ?? this.method);

  static Future<PrayerSettings> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final m = p.getInt('prayer_madhhab') ?? Madhhab.hanafi.index;
      final method = p.getInt('prayer_method') ?? 1;
      return PrayerSettings(
        madhhab: Madhhab.values[m.clamp(0, Madhhab.values.length - 1)],
        method: kPrayerMethods.any((e) => e.$1 == method) ? method : 1,
      );
    } catch (_) {
      return const PrayerSettings();
    }
  }

  Future<void> save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt('prayer_madhhab', madhhab.index);
      await p.setInt('prayer_method', method);
    } catch (_) {}
  }
}

enum LocationProblem { servicesOff, denied, deniedForever }

class LocationException implements Exception {
  final LocationProblem problem;
  LocationException(this.problem);
}

class PrayerService {
  /// The device position. [ask] shows the system permission dialog if needed.
  static Future<Position> position({bool ask = true}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationException(LocationProblem.servicesOff);
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied && ask) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) {
      throw LocationException(LocationProblem.denied);
    }
    if (perm == LocationPermission.deniedForever) {
      throw LocationException(LocationProblem.deniedForever);
    }
    // Prayer times and Qibla do not need GPS precision, so use the fast
    // low-accuracy fix and fall back to the last known one.
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 12),
        ),
      );
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
      rethrow;
    }
  }

  /// A short place name ("Srinagar, Jammu & Kashmir"), or null if unavailable.
  static Future<String?> placeName(double lat, double lng) async {
    try {
      final p = (await Geocoding().placemarkFromCoordinates(lat, lng)).firstOrNull;
      if (p == null) return null;
      final parts = <String>[
        if ((p.locality ?? '').isNotEmpty) p.locality!,
        if ((p.administrativeArea ?? '').isNotEmpty) p.administrativeArea!,
      ];
      if (parts.isEmpty && (p.country ?? '').isNotEmpty) parts.add(p.country!);
      return parts.isEmpty ? null : parts.join(', ');
    } catch (_) {
      return null;
    }
  }

  static String _cacheKey(double lat, double lng, PrayerSettings st) {
    final d = DateTime.now();
    return 'prayer_${d.year}${d.month}${d.day}_${lat.toStringAsFixed(1)}_${lng.toStringAsFixed(1)}'
        '_m${st.effectiveMethod}_s${st.school}';
  }

  /// Today's timings from Aladhan (method=1, school=1). Today's result for the
  /// same area is kept on the phone so the screen opens instantly.
  static Future<PrayerDay?> cached(double lat, double lng,
      [PrayerSettings st = const PrayerSettings()]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey(lat, lng, st));
      if (raw == null) return null;
      return PrayerDay.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<PrayerDay> fetch(double lat, double lng,
      [PrayerSettings st = const PrayerSettings()]) async {
    final uri = Uri.parse('https://api.aladhan.com/v1/timings'
        '?latitude=$lat&longitude=$lng'
        '&method=${st.effectiveMethod}&school=${st.school}');
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('Prayer times unavailable (${res.statusCode})');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final day = PrayerDay.fromApi(Map<String, dynamic>.from(body['data'] as Map));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey(lat, lng, st), jsonEncode(day.toJson()));
    } catch (e) {
      debugPrint('[Deen] cache: $e');
    }
    return day;
  }
}
