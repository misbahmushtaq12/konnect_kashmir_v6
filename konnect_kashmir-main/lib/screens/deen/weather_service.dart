import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpDate;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/shared_http.dart';
import 'weather_math.dart' as calc; // (WeatherNow has its own feelsLikeC)

/// What the sky is doing, in the few kinds the app shows.
enum WeatherKind {
  clear,
  partlyCloudy,
  cloudy,
  drizzle,
  rain,
  thunderstorm,
  snow,
  fog,
  haze,
  dust,
  storm,
}

/// The kind for a MET Norway symbol ("clearsky_day", "lightrainshowers_night"...).
/// MET Norway has no symbols for haze, dust or storm winds.
WeatherKind metKindOf(String symbol) {
  final s = symbol.split('_').first; // without _day / _night / _polartwilight
  if (s.contains('thunder')) return WeatherKind.thunderstorm;
  if (s.contains('snow') || s.contains('sleet')) return WeatherKind.snow;
  if (s.startsWith('lightrain')) return WeatherKind.drizzle; // a light rain
  if (s.contains('rain')) return WeatherKind.rain;
  switch (s) {
    case 'clearsky':
      return WeatherKind.clear;
    case 'fair': // slightly cloudy
    case 'partlycloudy':
      return WeatherKind.partlyCloudy;
    case 'fog':
      return WeatherKind.fog;
  }
  return WeatherKind.cloudy; // "cloudy" and anything new
}

/// The weather now at a place.
class WeatherNow {
  final double tempC;

  /// How the air feels, when an official index applies (wind chill when it is cold
  /// and windy, heat index when it is hot and humid). MET Norway gives none itself,
  /// so it is null the rest of the time and the card shows no "Feels like".
  final double? feelsLikeC;

  /// Relative humidity, percent.
  final int humidity;

  /// Wind speed in km/h (MET Norway gives m/s).
  final double windKmh;

  final WeatherKind kind;
  final bool isNight;

  /// Cloud cover in percent, and the rain or snow expected in the coming hour in
  /// millimetres, where MET Norway gives them.
  final double? cloudPercent;
  final double? precipitationMm;

  /// Sunrise and sunset as minutes after midnight, on the clock of the place.
  /// Null where the sun does not rise or set (polar places).
  final int? sunriseMin;
  final int? sunsetMin;

  /// When this reading was fetched.
  final DateTime fetchedAt;

  /// No new request before this: MET Norway's own cache time. Null:
  /// [WeatherService.defaultCache] after [fetchedAt].
  final DateTime? freshUntil;

  const WeatherNow({
    required this.tempC,
    required this.humidity,
    required this.windKmh,
    required this.kind,
    required this.isNight,
    required this.fetchedAt,
    this.feelsLikeC,
    this.cloudPercent,
    this.precipitationMm,
    this.sunriseMin,
    this.sunsetMin,
    this.freshUntil,
  });

  DateTime get validUntil => freshUntil ?? fetchedAt.add(WeatherService.defaultCache);

  /// Parses MET Norway's `locationforecast/2.0/compact` answer for the moment [now].
  ///
  /// The answer is a list of points, one an hour at first. The reading is the
  /// current one: the latest point that is not after [now], never a later one (those
  /// are forecasts). It must be recent: an answer that does not reach [now], or whose
  /// latest point is over two hours old, is refused rather than shown as live.
  ///
  /// MET Norway gives no sunrise or sunset, so they are worked out from the place
  /// ([lat], [lng]) and its clock ([utcOffset]). Throws [FormatException] when the
  /// parts that matter are missing.
  factory WeatherNow.fromMet(
    Map<String, dynamic> j, {
    required DateTime now,
    required double lat,
    required double lng,
    required Duration utcOffset,
    DateTime? freshUntil,
  }) {
    try {
      final series = ((j['properties'] as Map)['timeseries'] as List).cast<Map>();
      if (series.isEmpty) throw const FormatException('no time series');
      final nowUtc = now.toUtc();
      DateTime timeOf(Map p) => DateTime.parse(p['time'] as String).toUtc();

      Map? current;
      for (final p in series) {
        if (timeOf(p).isAfter(nowUtc)) break;
        current = p;
      }
      // A clock a little behind: the first point may start within the hour.
      if (current == null && timeOf(series.first).difference(nowUtc) <= const Duration(hours: 1)) {
        current = series.first;
      }
      if (current == null) throw const FormatException('the forecast starts later');
      if (nowUtc.difference(timeOf(current)) > const Duration(hours: 2)) {
        throw const FormatException('the latest point is too old');
      }

      final data = current['data'] as Map;
      final details = (data['instant'] as Map)['details'] as Map;
      final temp = (details['air_temperature'] as num).toDouble();
      final rh = (details['relative_humidity'] as num).toDouble();
      final windKmh = (details['wind_speed'] as num).toDouble() * 3.6;
      if (!temp.isFinite || !rh.isFinite || !windKmh.isFinite) {
        throw const FormatException('not a number');
      }

      final next1 = data['next_1_hours'] as Map?;
      final summary = (next1 ?? data['next_6_hours'] ?? data['next_12_hours']) as Map?;
      final symbol = ((summary?['summary'] as Map?)?['symbol_code'] as String?) ?? 'cloudy';
      final precip = ((next1?['details'] as Map?)?['precipitation_amount'] as num?)?.toDouble();

      final local = nowUtc.add(utcOffset);
      final sun = calc.sunTimes(lat, lng, local.year, local.month, local.day, utcOffset);
      final minuteNow = local.hour * 60 + local.minute;
      // "_night" and "_day" say it; the symbols without them (rain, snow...) do not.
      final isNight = symbol.endsWith('_night')
          ? true
          : symbol.endsWith('_day')
              ? false
              : (sun != null && (minuteNow < sun.rise || minuteNow >= sun.set));

      return WeatherNow(
        tempC: temp,
        feelsLikeC: calc.feelsLikeC(temp, rh, windKmh),
        humidity: rh.round(),
        windKmh: windKmh,
        kind: metKindOf(symbol),
        isNight: isNight,
        cloudPercent: (details['cloud_area_fraction'] as num?)?.toDouble(),
        precipitationMm: precip,
        sunriseMin: sun?.rise,
        sunsetMin: sun?.set,
        fetchedAt: now,
        freshUntil: freshUntil,
      );
    } catch (e) {
      throw FormatException('Unexpected weather answer: $e');
    }
  }

  Map<String, dynamic> toJson() => {
        'temp': tempC,
        'feels': feelsLikeC,
        'humidity': humidity,
        'wind': windKmh,
        'kind': kind.name,
        'night': isNight,
        'cloud': cloudPercent,
        'precip': precipitationMm,
        'sunrise': sunriseMin,
        'sunset': sunsetMin,
        'at': fetchedAt.millisecondsSinceEpoch,
        if (freshUntil != null) 'until': freshUntil!.millisecondsSinceEpoch,
      };

  factory WeatherNow.fromJson(Map<String, dynamic> j) => WeatherNow(
        tempC: (j['temp'] as num).toDouble(),
        feelsLikeC: (j['feels'] as num?)?.toDouble(),
        humidity: (j['humidity'] as num).toInt(),
        windKmh: (j['wind'] as num).toDouble(),
        kind: WeatherKind.values.byName(j['kind'] as String),
        isNight: j['night'] == true,
        cloudPercent: (j['cloud'] as num?)?.toDouble(),
        precipitationMm: (j['precip'] as num?)?.toDouble(),
        sunriseMin: (j['sunrise'] as num?)?.toInt(),
        sunsetMin: (j['sunset'] as num?)?.toInt(),
        fetchedAt: DateTime.fromMillisecondsSinceEpoch((j['at'] as num).toInt()),
        freshUntil: j['until'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch((j['until'] as num).toInt()),
      );
}

/// Current weather for the Deen tab, from MET Norway's Locationforecast 2.0
/// (https://api.met.no/weatherapi/locationforecast/2.0/documentation).
///
/// Its terms: every request names the app and a way to reach us ([userAgent]),
/// coordinates have at most four decimals, the data is credited (the card shows
/// "Data from MET Norway"), and an answer is not asked for again before its Expires
/// time. A reading is kept on the phone and the card opens with it straight away; a
/// failed request is not repeated for [retryAfterFailure], and never shows an error:
/// the card keeps the last reading for up to [usable], or stays away if there is none.
class WeatherService {
  /// A saved reading older than this is not shown any more: an hour-old temperature
  /// is the most the card may present as the weather now.
  static const Duration usable = Duration(hours: 1);

  /// How long an answer is kept when MET Norway does not say (Expires).
  static const Duration defaultCache = Duration(minutes: 30);

  /// After a failed request, no new one for this long.
  static const Duration retryAfterFailure = Duration(minutes: 5);

  /// Names the app to MET Norway, with a website to reach us on, as its terms ask.
  static const String userAgent = 'KonnectKashmir/1.0 (+https://konnectkashmir.com)';

  /// The headers a request needs.
  static Map<String, String>? headersFor(Uri uri) =>
      uri.host == 'api.met.no' ? {'User-Agent': userAgent} : null;

  /// How the answer is fetched. Tests replace it.
  @visibleForTesting
  static Future<http.Response> Function(Uri uri) get =
      (uri) => sharedHttp.get(uri, headers: headersFor(uri));

  /// The clock. Tests replace it.
  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  /// The place's clock against UTC, for sunrise and sunset: the phone's own (the
  /// phone is where the person is, and in Kashmir that is India Standard Time).
  /// Tests replace it.
  @visibleForTesting
  static Duration Function() utcOffset = () => now().timeZoneOffset;

  /// Requests under way, so two callers asking for the same place share one.
  static final Map<String, Future<WeatherNow?>> _inFlight = {};

  /// Places whose last request failed: no new request before the time given.
  static final Map<String, DateTime> _retryAfter = {};

  /// Puts back what tests replaced.
  @visibleForTesting
  static void reset() {
    get = (uri) => sharedHttp.get(uri, headers: headersFor(uri));
    now = DateTime.now;
    utcOffset = () => now().timeZoneOffset;
    _inFlight.clear();
    _retryAfter.clear();
  }

  /// The area (about 11 km) a reading stands for.
  static String cell(double lat, double lng) =>
      '${lat.toStringAsFixed(1)}_${lng.toStringAsFixed(1)}';

  // (Readings saved by the OpenWeather version were under "weather_<cell>": never read.)
  static String _cacheKey(double lat, double lng) => 'weather_met_${cell(lat, lng)}';

  /// MET Norway's forecast at the place: four decimals at most, as its terms say.
  /// It gives degrees Celsius, m/s and percent, and finds the place's height itself.
  static Uri uriFor(double lat, double lng) => Uri.https(
        'api.met.no',
        '/weatherapi/locationforecast/2.0/compact',
        {
          'lat': lat.toStringAsFixed(4),
          'lon': lng.toStringAsFixed(4),
        },
      );

  /// The saved reading for this area, if it is not too old to show.
  static Future<WeatherNow?> cached(double lat, double lng) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey(lat, lng));
      if (raw == null) return null;
      final w = WeatherNow.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      return now().difference(w.fetchedAt) <= usable ? w : null;
    } catch (_) {
      return null;
    }
  }

  /// The weather for this place: the saved reading until MET Norway's cache time has
  /// passed, then a new one. Null if there is nothing to show.
  static Future<WeatherNow?> fetch(double lat, double lng) {
    final key = _cacheKey(lat, lng);
    return _inFlight[key] ??= _fetch(lat, lng).whenComplete(() {
      _inFlight.remove(key);
    });
  }

  static Future<WeatherNow?> _fetch(double lat, double lng) async {
    final key = _cacheKey(lat, lng);
    final saved = await cached(lat, lng);
    if (saved != null && now().isBefore(saved.validUntil)) return saved;
    final wait = _retryAfter[key];
    if (wait != null && now().isBefore(wait)) return saved;

    try {
      final res = await get(uriFor(lat, lng)).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        throw Exception('MET Norway answered ${res.statusCode}');
      }
      final t = now();
      final w = WeatherNow.fromMet(
        jsonDecode(res.body) as Map<String, dynamic>,
        now: t,
        lat: lat,
        lng: lng,
        utcOffset: utcOffset(),
        freshUntil: _freshUntil(res.headers['expires'], t),
      );
      _retryAfter.remove(key);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(key, jsonEncode(w.toJson()));
      } catch (e) {
        debugPrint('[Weather] cache: $e');
      }
      return w;
    } catch (e) {
      debugPrint('[Weather] $e');
      _retryAfter[key] = now().add(retryAfterFailure);
      return saved;
    }
  }

  /// MET Norway says (Expires) when its answer changes next, and asks not to be asked
  /// sooner. [defaultCache] when it does not say; never less than five minutes and
  /// never beyond the hour a reading may be shown for.
  static DateTime _freshUntil(String? expires, DateTime t) {
    var until = t.add(defaultCache);
    if (expires != null) {
      try {
        until = HttpDate.parse(expires);
      } catch (_) {}
    }
    final soonest = t.add(const Duration(minutes: 5));
    final latest = t.add(usable - const Duration(minutes: 5));
    if (until.isBefore(soonest)) return soonest;
    if (until.isAfter(latest)) return latest;
    return until;
  }
}
