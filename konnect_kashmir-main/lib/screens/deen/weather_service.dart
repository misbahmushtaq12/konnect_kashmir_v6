import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/shared_http.dart';
import '../../services/weather_config.dart';

/// What the sky is doing, in the few kinds the app shows (OpenWeather has about
/// fifty condition codes).
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

/// The kind for an OpenWeather condition code
/// (https://openweathermap.org/weather-conditions).
WeatherKind weatherKindOf(int id) {
  if (id >= 200 && id < 300) return WeatherKind.thunderstorm;
  if (id >= 300 && id < 400) return WeatherKind.drizzle;
  if (id >= 500 && id < 600) return WeatherKind.rain;
  if (id >= 600 && id < 700) return WeatherKind.snow;
  switch (id) {
    case 701: // mist
    case 741: // fog
      return WeatherKind.fog;
    case 711: // smoke
    case 721: // haze
      return WeatherKind.haze;
    case 731: // dust whirls
    case 751: // sand
    case 761: // dust
    case 762: // volcanic ash
      return WeatherKind.dust;
    case 771: // squalls
    case 781: // tornado
      return WeatherKind.storm;
    case 800:
      return WeatherKind.clear;
    case 801: // 11-25% clouds
    case 802: // 25-50%
      return WeatherKind.partlyCloudy;
  }
  return WeatherKind.cloudy; // 803, 804 and anything new
}

/// The weather now at a place.
class WeatherNow {
  final double tempC;
  final double feelsLikeC;

  /// Relative humidity, percent.
  final int humidity;

  /// Wind speed in km/h (OpenWeather gives m/s).
  final double windKmh;

  /// The OpenWeather condition code, and the kind it stands for.
  final int conditionId;
  final bool isNight;

  /// Sunrise and sunset as minutes after midnight, on the clock of the place.
  /// Null where the sun does not rise or set (polar places).
  final int? sunriseMin;
  final int? sunsetMin;

  /// When this reading was fetched.
  final DateTime fetchedAt;

  const WeatherNow({
    required this.tempC,
    required this.feelsLikeC,
    required this.humidity,
    required this.windKmh,
    required this.conditionId,
    required this.isNight,
    required this.fetchedAt,
    this.sunriseMin,
    this.sunsetMin,
  });

  WeatherKind get kind => weatherKindOf(conditionId);

  /// Parses OpenWeather's `/data/2.5/weather` answer. Throws [FormatException]
  /// when the parts that matter are missing.
  factory WeatherNow.fromApi(Map<String, dynamic> j, {required DateTime fetchedAt}) {
    try {
      final main = j['main'] as Map;
      final w = (j['weather'] as List).first as Map;
      final wind = (j['wind'] as Map?) ?? const {};
      final sys = (j['sys'] as Map?) ?? const {};
      final tz = (j['timezone'] as num?)?.toInt() ?? 0;

      // A unix time as minutes after midnight on the place's own clock.
      int? minutesOfDay(Object? unix) {
        if (unix is! num || unix <= 0) return null;
        final local = DateTime.fromMillisecondsSinceEpoch(unix.toInt() * 1000, isUtc: true)
            .add(Duration(seconds: tz));
        return local.hour * 60 + local.minute;
      }

      return WeatherNow(
        tempC: (main['temp'] as num).toDouble(),
        feelsLikeC: ((main['feels_like'] ?? main['temp']) as num).toDouble(),
        humidity: ((main['humidity'] ?? 0) as num).round(),
        windKmh: ((wind['speed'] ?? 0) as num).toDouble() * 3.6,
        conditionId: (w['id'] as num).toInt(),
        isNight: (w['icon']?.toString() ?? '').endsWith('n'),
        sunriseMin: minutesOfDay(sys['sunrise']),
        sunsetMin: minutesOfDay(sys['sunset']),
        fetchedAt: fetchedAt,
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
        'id': conditionId,
        'night': isNight,
        'sunrise': sunriseMin,
        'sunset': sunsetMin,
        'at': fetchedAt.millisecondsSinceEpoch,
      };

  factory WeatherNow.fromJson(Map<String, dynamic> j) => WeatherNow(
        tempC: (j['temp'] as num).toDouble(),
        feelsLikeC: (j['feels'] as num).toDouble(),
        humidity: (j['humidity'] as num).toInt(),
        windKmh: (j['wind'] as num).toDouble(),
        conditionId: (j['id'] as num).toInt(),
        isNight: j['night'] == true,
        sunriseMin: (j['sunrise'] as num?)?.toInt(),
        sunsetMin: (j['sunset'] as num?)?.toInt(),
        fetchedAt: DateTime.fromMillisecondsSinceEpoch((j['at'] as num).toInt()),
      );
}

/// Current weather from OpenWeather for the Deen tab.
///
/// A reading is kept on the phone: the card opens with it straight away, and no
/// new request is made for [fresh] (the free plan is limited, and weather does not
/// change that fast). A failed request never shows an error; the card simply keeps
/// the last reading, or stays away if there is none.
class WeatherService {
  /// No new request while the saved reading is younger than this.
  static const Duration fresh = Duration(minutes: 20);

  /// A saved reading older than this is not shown any more.
  static const Duration usable = Duration(hours: 3);

  /// How the answer is fetched. Tests replace it.
  @visibleForTesting
  static Future<http.Response> Function(Uri uri) get = (uri) => sharedHttp.get(uri);

  /// The key sent with every request. Tests replace it.
  @visibleForTesting
  static String apiKey = kOpenWeatherKey;

  /// The clock. Tests replace it.
  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  /// Requests under way, so two callers asking for the same place share one.
  static final Map<String, Future<WeatherNow?>> _inFlight = {};

  /// Puts back what tests replaced.
  @visibleForTesting
  static void reset() {
    get = (uri) => sharedHttp.get(uri);
    apiKey = kOpenWeatherKey;
    now = DateTime.now;
    _inFlight.clear();
  }

  /// The area (about 11 km) a reading stands for.
  static String cell(double lat, double lng) =>
      '${lat.toStringAsFixed(1)}_${lng.toStringAsFixed(1)}';

  static String _cacheKey(double lat, double lng) => 'weather_${cell(lat, lng)}';

  static Uri uriFor(double lat, double lng) => Uri.https(
        'api.openweathermap.org',
        '/data/2.5/weather',
        {
          'lat': lat.toStringAsFixed(4),
          'lon': lng.toStringAsFixed(4),
          'units': 'metric',
          'appid': apiKey,
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

  /// The weather for this place: the saved reading while it is still [fresh]
  /// (unless [force]), otherwise a new one. Null if there is nothing to show.
  static Future<WeatherNow?> fetch(double lat, double lng, {bool force = false}) {
    final key = _cacheKey(lat, lng);
    return _inFlight[key] ??= _fetch(lat, lng, force: force).whenComplete(() {
      _inFlight.remove(key);
    });
  }

  static Future<WeatherNow?> _fetch(double lat, double lng, {required bool force}) async {
    final saved = await cached(lat, lng);
    if (!force && saved != null && now().difference(saved.fetchedAt) < fresh) {
      return saved;
    }
    try {
      final res = await get(uriFor(lat, lng)).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        debugPrint('[Weather] unavailable (${res.statusCode})');
        return saved;
      }
      final w = WeatherNow.fromApi(
        jsonDecode(res.body) as Map<String, dynamic>,
        fetchedAt: now(),
      );
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cacheKey(lat, lng), jsonEncode(w.toJson()));
      } catch (e) {
        debugPrint('[Weather] cache: $e');
      }
      return w;
    } catch (e) {
      debugPrint('[Weather] $e');
      return saved;
    }
  }
}
