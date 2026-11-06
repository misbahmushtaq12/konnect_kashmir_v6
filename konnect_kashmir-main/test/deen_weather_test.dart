import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:konnect_kashmir/l10n/l10n.dart';
import 'package:konnect_kashmir/providers/auth_provider.dart';
import 'package:konnect_kashmir/screens/deen/deen_tab.dart';
import 'package:konnect_kashmir/screens/deen/weather_card.dart';
import 'package:konnect_kashmir/screens/deen/weather_service.dart';
import 'package:konnect_kashmir/services/live_sync.dart';
import 'package:konnect_kashmir/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _lat = 34.0575, _lng = 74.8236; // Balgarden, Srinagar (about)
const _ist = Duration(hours: 5, minutes: 30);

/// 13:40 IST on 2 November 2026: the moment of the real answer below.
final _t1340 = DateTime.utc(2026, 11, 2, 8, 10);

/// The first points of MET Norway's real answer for Balgarden, Srinagar (asked at 13:40
/// IST): time, air temperature, humidity, wind (m/s), the next hour's symbol, cloud
/// cover (%), rain expected in the next hour (mm).
const List<List<Object?>> _realPoints = [
  ['2026-11-02T08:00:00Z', 18.0, 38.1, 3.2, 'fair_day', 25.0, 0.0],
  ['2026-11-02T09:00:00Z', 18.1, 35.0, 3.1, 'fair_day', 30.5, 0.0],
  ['2026-11-02T10:00:00Z', 18.1, 34.8, 3.7, 'fair_day', 28.0, 0.0],
  ['2026-11-02T11:00:00Z', 16.6, 41.6, 4.2, 'lightrainshowers_day', 70.0, 0.3],
];

/// MET Norway's `locationforecast/2.0/compact` answer (the parts the app reads).
String _met({List<List<Object?>>? points}) => jsonEncode({
      'type': 'Feature',
      'geometry': {'type': 'Point', 'coordinates': [74.8236, 34.0575, 1584]},
      'properties': {
        'meta': {'updated_at': '2026-11-02T07:17:20Z'},
        'timeseries': [
          for (final p in points ?? _realPoints)
            {
              'time': p[0],
              'data': {
                'instant': {
                  'details': {
                    'air_pressure_at_sea_level': 1018.0,
                    'air_temperature': p[1],
                    'relative_humidity': p[2],
                    'wind_speed': p[3],
                    if (p.length > 5 && p[5] != null) 'cloud_area_fraction': p[5],
                  }
                },
                if (p[4] != null)
                  'next_1_hours': {
                    'summary': {'symbol_code': p[4]},
                    'details': {if (p.length > 6 && p[6] != null) 'precipitation_amount': p[6]}
                  },
                'next_6_hours': {
                  'summary': {'symbol_code': 'lightrainshowers_day'},
                  'details': {}
                },
              },
            },
        ],
      },
    });

WeatherNow _metAt(DateTime now, {String? body, DateTime? freshUntil}) => WeatherNow.fromMet(
      jsonDecode(body ?? _met()) as Map<String, dynamic>,
      now: now,
      lat: _lat,
      lng: _lng,
      utcOffset: _ist,
      freshUntil: freshUntil,
    );

/// A reading with one point only, for the symbol, temperature and wind a test needs.
WeatherNow _one(String symbol, {double temp = 18, double rh = 38, double wind = 3, DateTime? now}) =>
    _metAt(now ?? _t1340, body: _met(points: [
      ['2026-11-02T08:00:00Z', temp, rh, wind, symbol, null, null],
    ]));

/// A saved reading for the area of [_lat], [_lng].
Map<String, Object> _saved(WeatherNow w) =>
    {'weather_met_${WeatherService.cell(_lat, _lng)}': jsonEncode(w.toJson())};

Widget _app(Widget home, {ThemeData? theme, double textScale = 1.0, Locale? locale}) {
  final auth = AuthProvider();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider<LiveSync>.value(value: LiveSync(auth)),
    ],
    child: MaterialApp(
      theme: theme,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(body: home),
    ),
  );
}

void _phone(WidgetTester tester, {double w = 360, double h = 800}) {
  tester.view.physicalSize = Size(w * 2, h * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

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
      loader.addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer)));
    }
  }
  await loader.load();
}

// The Deen tab opens on a saved place (Srinagar) with today's saved prayer times,
// so it shows real data without a GPS or a network.
Map<String, Object> _deenSaved() {
  final d = DateTime.now();
  return {
    'cust_lat': 34.1,
    'cust_lng': 74.8,
    'cust_loc_at': d.millisecondsSinceEpoch,
    'place_34.1_74.8': 'Srinagar, Jammu & Kashmir',
    'prayer_${d.year}${d.month}${d.day}_34.1_74.8_m1_s1': jsonEncode({
      'fajr': '05:15',
      'dhuhr': '12:16',
      'asr': '16:13',
      'maghrib': '17:52',
      'isha': '19:16',
      'hijri': '8 Jumādá al-ūlá 1448',
    }),
  };
}

void main() {
  setUpAll(_loadRoboto);

  setUp(() {
    WeatherService.reset();
    // The clock the readings are made at, so the tests do not depend on today's date.
    WeatherService.now = () => _t1340;
    WeatherService.utcOffset = () => _ist;
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(WeatherService.reset);

  group('WeatherNow.fromMet', () {
    test('reads the real answer: the 13:30 point is the current one', () {
      final w = _metAt(_t1340);
      expect(w.tempC, 18.0);
      expect(w.humidity, 38, reason: '38.1 rounds to 38');
      expect(w.windKmh, closeTo(11.52, 0.001), reason: '3.2 m/s');
      expect(w.kind, WeatherKind.partlyCloudy, reason: '"fair": slightly cloudy');
      expect(w.isNight, isFalse);
      expect(w.fetchedAt, _t1340);
    });

    test('cloud cover and the rain expected are kept; missing ones are null', () {
      final w = _metAt(_t1340);
      expect(w.cloudPercent, 25.0);
      expect(w.precipitationMm, 0.0);
      final rainy = _metAt(DateTime.utc(2026, 11, 2, 11, 5));
      expect(rainy.cloudPercent, 70.0);
      expect(rainy.precipitationMm, 0.3);
      final bare = _one('cloudy');
      expect(bare.cloudPercent, isNull);
      expect(bare.precipitationMm, isNull);
    });

    test('the current point is the latest one that is not after now, never a forecast hour', () {
      expect(_metAt(DateTime.utc(2026, 11, 2, 8)).tempC, 18.0);
      expect(_metAt(DateTime.utc(2026, 11, 2, 8, 59, 59)).tempC, 18.0, reason: 'not the 09:00 point');
      expect(_metAt(DateTime.utc(2026, 11, 2, 9)).humidity, 35);
      expect(_metAt(DateTime.utc(2026, 11, 2, 10, 59)).humidity, 35);
      expect(_metAt(DateTime.utc(2026, 11, 2, 11, 30)).tempC, 16.6);
      // Later points (the answer goes days ahead) are never used while an earlier one fits.
      final far = _met(points: [
        ['2026-11-02T08:00:00Z', 18.0, 38.0, 3.0, 'fair_day'],
        ['2026-11-03T08:00:00Z', 5.0, 90.0, 3.0, 'snow'],
      ]);
      expect(_metAt(DateTime.utc(2026, 11, 2, 8, 30), body: far).tempC, 18.0);
    });

    test('a clock a little behind uses the first point; a long way behind is refused', () {
      expect(_metAt(DateTime.utc(2026, 11, 2, 7, 30)).tempC, 18.0);
      expect(() => _metAt(DateTime.utc(2026, 11, 2, 6, 30)), throwsFormatException);
    });

    test('an answer whose latest point is over two hours old is not shown as the weather now', () {
      final old = _met(points: [
        ['2026-11-02T08:00:00Z', 18.0, 38.0, 3.0, 'fair_day'],
      ]);
      expect(_metAt(DateTime.utc(2026, 11, 2, 9, 59), body: old).tempC, 18.0);
      expect(() => _metAt(DateTime.utc(2026, 11, 2, 10, 1), body: old), throwsFormatException);
    });

    test('the time zone: point times are UTC instants; the place\'s clock is only for the sun', () {
      // The same instant gives the same reading whatever the phone's clock says.
      WeatherNow at(Duration offset) => WeatherNow.fromMet(
            jsonDecode(_met()) as Map<String, dynamic>,
            now: _t1340,
            lat: _lat,
            lng: _lng,
            utcOffset: offset,
          );
      expect(at(_ist).tempC, at(Duration.zero).tempC);
      expect(at(_ist).sunriseMin! - at(Duration.zero).sunriseMin!, 330);
      // A local (not UTC) "now" is the same instant.
      final local = DateTime.fromMillisecondsSinceEpoch(_t1340.millisecondsSinceEpoch);
      expect(_metAt(local).tempC, 18.0);
    });

    test('sunrise and sunset are worked out for the place and the day', () {
      final w = _metAt(_t1340);
      expect(w.sunriseMin, closeTo(6 * 60 + 51, 2));
      expect(w.sunsetMin, closeTo(17 * 60 + 38, 2));
    });

    test('feels like: none for mild air (MET Norway has none and nothing is made up)', () {
      expect(_metAt(_t1340).feelsLikeC, isNull);
      expect(_one('cloudy', temp: 15, wind: 8).feelsLikeC, isNull);
    });

    test('feels like: the official index where one applies', () {
      final cold = _one('cloudy', temp: 2, rh: 60, wind: 6); // 21.6 km/h: wind chill
      expect(cold.feelsLikeC, isNotNull);
      expect(cold.feelsLikeC!, lessThan(cold.tempC - 4));
      final hot = _one('clearsky_day', temp: 35, rh: 60, wind: 1.4); // heat index
      expect(hot.feelsLikeC!, greaterThan(40));
    });

    test('the symbols become the kinds the card knows', () {
      const expected = {
        'clearsky_day': WeatherKind.clear,
        'clearsky_night': WeatherKind.clear,
        'fair_day': WeatherKind.partlyCloudy,
        'fair_night': WeatherKind.partlyCloudy,
        'partlycloudy_night': WeatherKind.partlyCloudy,
        'cloudy': WeatherKind.cloudy,
        'fog': WeatherKind.fog,
        'lightrain': WeatherKind.drizzle,
        'lightrainshowers_day': WeatherKind.drizzle,
        'rain': WeatherKind.rain,
        'rainshowers_day': WeatherKind.rain,
        'heavyrain': WeatherKind.rain,
        'heavyrainshowers_night': WeatherKind.rain,
        'rainandthunder': WeatherKind.thunderstorm,
        'lightrainshowersandthunder_day': WeatherKind.thunderstorm,
        'heavysnowandthunder': WeatherKind.thunderstorm,
        'lightsnow': WeatherKind.snow,
        'snowshowers_day': WeatherKind.snow,
        'sleet': WeatherKind.snow,
        'lightsleetshowers_night': WeatherKind.snow,
        'something_new': WeatherKind.cloudy,
      };
      expected.forEach((symbol, kind) {
        expect(metKindOf(symbol), kind, reason: symbol);
        expect(_one(symbol).kind, kind, reason: symbol);
      });
    });

    test('night: from the symbol, or from the sun when the symbol has no word for it', () {
      // The answer's current point is the hour that [now] is in.
      WeatherNow at(DateTime now, String symbol) {
        final hour = DateTime.utc(now.year, now.month, now.day, now.hour).toIso8601String();
        return _metAt(now, body: _met(points: [[hour, 10.0, 50.0, 1.0, symbol]]));
      }
      expect(at(_t1340, 'clearsky_night').isNight, isTrue);
      expect(at(_t1340, 'clearsky_day').isNight, isFalse);
      // No _day or _night: 13:40 is day; midnight, early morning and evening are night.
      expect(at(_t1340, 'rain').isNight, isFalse);
      expect(at(DateTime.utc(2026, 11, 2, 18, 30), 'rain').isNight, isTrue, reason: '00:00 IST');
      expect(at(DateTime.utc(2026, 11, 2, 0, 30), 'rain').isNight, isTrue, reason: '06:00 IST, before sunrise');
      expect(at(DateTime.utc(2026, 11, 2, 12, 30), 'rain').isNight, isTrue, reason: '18:00 IST, after sunset');
    });

    test('with no symbol for the next hour, the next six hours give it', () {
      final w = _metAt(_t1340, body: _met(points: [
        ['2026-11-02T08:00:00Z', 18.0, 38.0, 3.0, null],
      ]));
      expect(w.kind, WeatherKind.drizzle);
    });

    test('an answer without the points is an error', () {
      expect(() => WeatherNow.fromMet({'cod': 1}, now: _t1340, lat: 34, lng: 74, utcOffset: _ist),
          throwsFormatException);
      expect(() => _metAt(_t1340, body: _met(points: [])), throwsFormatException);
      expect(
          () => _metAt(_t1340,
              body: '{"properties":{"timeseries":[{"time":"2026-11-02T08:00:00Z","data":{}}]}}'),
          throwsFormatException);
    });

    test('goes to JSON and back', () {
      final until = DateTime.utc(2026, 11, 2, 8, 40, 32);
      final w = _metAt(_t1340, freshUntil: until);
      final back = WeatherNow.fromJson(jsonDecode(jsonEncode(w.toJson())) as Map<String, dynamic>);
      expect(back.tempC, w.tempC);
      expect(back.feelsLikeC, isNull);
      expect(back.humidity, w.humidity);
      expect(back.windKmh, w.windKmh);
      expect(back.kind, w.kind);
      expect(back.isNight, w.isNight);
      expect(back.cloudPercent, 25.0);
      expect(back.precipitationMm, 0.0);
      expect(back.sunriseMin, w.sunriseMin);
      expect(back.sunsetMin, w.sunsetMin);
      expect(back.fetchedAt.isAtSameMomentAs(w.fetchedAt), isTrue);
      expect(back.freshUntil!.isAtSameMomentAs(until), isTrue);
      final cold = _one('cloudy', temp: 2, rh: 60, wind: 6);
      expect(WeatherNow.fromJson(cold.toJson()).feelsLikeC, cold.feelsLikeC);
    });
  });

  group('WeatherService', () {
    late List<Uri> calls;
    late DateTime clock;

    /// Answers like MET Norway, with [headers], or fails.
    void serve({Map<String, String> headers = const {}, int status = 200, String? body, bool fail = false}) {
      calls = [];
      WeatherService.get = (u) async {
        calls.add(u);
        if (fail) throw const SocketException('no internet');
        return http.Response(body ?? _met(), status, headers: headers);
      };
    }

    setUp(() {
      clock = _t1340;
      WeatherService.now = () => clock;
    });

    void at(Duration later) => clock = _t1340.add(later);

    test('asks MET Norway, names the app, keeps coordinates to four decimals, needs no key', () async {
      serve(headers: {'expires': 'Mon, 02 Nov 2026 08:40:32 GMT'});
      final w = await WeatherService.fetch(34.05751, 74.82361);
      expect(calls, hasLength(1));
      final u = calls.single;
      expect(u.scheme, 'https');
      expect(u.host, 'api.met.no');
      expect(u.path, '/weatherapi/locationforecast/2.0/compact');
      expect(u.queryParameters, {'lat': '34.0575', 'lon': '74.8236'}, reason: 'the place, nothing else');
      expect(w!.tempC, 18.0);

      expect(WeatherService.headersFor(u), {'User-Agent': WeatherService.userAgent});
      expect(WeatherService.userAgent, contains('KonnectKashmir'));
      expect(WeatherService.userAgent, contains('https://'));
      expect(WeatherService.userAgent, isNot(contains('@')), reason: 'no personal e-mail address');
    });

    test('the place comes from the caller (the phone\'s position), not from the service', () async {
      serve();
      await WeatherService.fetch(34.3000, 75.2900); // Sonamarg
      await WeatherService.fetch(33.7311, 75.1487); // Anantnag
      expect(calls[0].queryParameters, {'lat': '34.3000', 'lon': '75.2900'});
      expect(calls[1].queryParameters, {'lat': '33.7311', 'lon': '75.1487'});
    });

    test('keeps the reading on the phone', () async {
      serve(headers: {'expires': 'Mon, 02 Nov 2026 08:40:32 GMT'});
      await WeatherService.fetch(_lat, _lng);
      final saved = await WeatherService.cached(_lat, _lng);
      expect(saved!.tempC, 18.0);
      expect(saved.validUntil.isAtSameMomentAs(DateTime.utc(2026, 11, 2, 8, 40, 32)), isTrue);
    });

    test('does not ask again before MET Norway\'s own cache time (Expires)', () async {
      serve(headers: {'expires': 'Mon, 02 Nov 2026 08:40:32 GMT'});
      await WeatherService.fetch(_lat, _lng);
      expect(calls, hasLength(1));

      clock = DateTime.utc(2026, 11, 2, 8, 35);
      await WeatherService.fetch(_lat, _lng);
      expect(calls, hasLength(1), reason: 'not before Expires');

      clock = DateTime.utc(2026, 11, 2, 8, 41);
      await WeatherService.fetch(_lat, _lng);
      expect(calls, hasLength(2), reason: 'after Expires');
    });

    test('with no Expires: half an hour', () async {
      serve();
      await WeatherService.fetch(_lat, _lng);
      at(const Duration(minutes: 29));
      await WeatherService.fetch(_lat, _lng);
      expect(calls, hasLength(1));
      at(const Duration(minutes: 31));
      await WeatherService.fetch(_lat, _lng);
      expect(calls, hasLength(2));
    });

    test('an Expires that has already passed still means five minutes', () async {
      serve(headers: {'expires': 'Mon, 02 Nov 2026 08:00:00 GMT'});
      await WeatherService.fetch(_lat, _lng);
      at(const Duration(minutes: 4));
      await WeatherService.fetch(_lat, _lng);
      expect(calls, hasLength(1));
      at(const Duration(minutes: 6));
      await WeatherService.fetch(_lat, _lng);
      expect(calls, hasLength(2));
    });

    test('an Expires far ahead is held to under an hour, so an old reading is never shown as live', () async {
      serve(headers: {'expires': 'Mon, 02 Nov 2026 14:00:00 GMT'});
      await WeatherService.fetch(_lat, _lng);
      at(const Duration(minutes: 54));
      await WeatherService.fetch(_lat, _lng);
      expect(calls, hasLength(1));
      at(const Duration(minutes: 56));
      await WeatherService.fetch(_lat, _lng);
      expect(calls, hasLength(2));
    });

    test('a damaged Expires is the half hour', () async {
      serve(headers: {'expires': 'soon'});
      await WeatherService.fetch(_lat, _lng);
      at(const Duration(minutes: 29));
      await WeatherService.fetch(_lat, _lng);
      expect(calls, hasLength(1));
    });

    test('a nearby place shares the reading, a far one does not', () async {
      serve();
      await WeatherService.fetch(34.0837, 74.7973);
      await WeatherService.fetch(34.0901, 74.8010);
      expect(calls, hasLength(1));
      await WeatherService.fetch(34.0160, 75.3150); // Pahalgam
      expect(calls, hasLength(2));
    });

    test('two askers at once share one request', () async {
      calls = [];
      WeatherService.get = (u) async {
        calls.add(u);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return http.Response(_met(), 200);
      };
      final both = await Future.wait([
        WeatherService.fetch(_lat, _lng),
        WeatherService.fetch(_lat, _lng),
      ]);
      expect(calls, hasLength(1));
      expect(both.every((w) => w != null), isTrue);
    });

    test('offline, an error, a refusal or rubbish: nothing to show, quietly', () async {
      for (final run in <void Function()>[
        () => serve(fail: true),
        () => serve(status: 403, body: '{"error":"no"}'),
        () => serve(status: 429, body: ''),
        () => serve(status: 503, body: ''),
        () => serve(body: 'not json'),
        () => serve(body: '{"cod":200}'),
        () => serve(body: '{"properties":{"timeseries":[]}}'),
        () => serve(body: _met(points: [['2026-11-02T03:00:00Z', 18.0, 38.0, 3.0, 'fair_day']])), // 5 hours old
      ]) {
        WeatherService.reset();
        WeatherService.now = () => clock;
        SharedPreferences.setMockInitialValues({});
        run();
        expect(await WeatherService.fetch(_lat, _lng), isNull);
      }
    });

    test('when a request fails, the saved reading stays for an hour, and no longer', () async {
      for (final (minutes, shown) in [(40, true), (59, true), (61, false)]) {
        WeatherService.reset();
        WeatherService.now = () => clock;
        final reading = _metAt(_t1340.subtract(Duration(minutes: minutes)),
            freshUntil: _t1340.subtract(const Duration(minutes: 1)));
        SharedPreferences.setMockInitialValues(_saved(reading));
        serve(fail: true);
        final w = await WeatherService.fetch(_lat, _lng);
        expect(w != null, shown, reason: '$minutes minutes old');
        if (shown) expect(w!.tempC, 18.0);
      }
    });

    test('after a failure it waits five minutes before asking again, and a success clears that', () async {
      serve(fail: true);
      await WeatherService.fetch(_lat, _lng);
      expect(calls, hasLength(1));

      at(const Duration(minutes: 3));
      await WeatherService.fetch(_lat, _lng);
      await WeatherService.fetch(_lat, _lng);
      expect(calls, hasLength(1), reason: 'not hammering a service that just failed');

      at(const Duration(minutes: 6));
      serve(); // it is back
      final w = await WeatherService.fetch(_lat, _lng);
      expect(calls, hasLength(1));
      expect(w, isNotNull);

      // ...and a later failure waits again, from then.
      at(const Duration(minutes: 50));
      serve(fail: true);
      await WeatherService.fetch(_lat, _lng);
      expect(calls, hasLength(1));
      at(const Duration(minutes: 52));
      await WeatherService.fetch(_lat, _lng);
      expect(calls, hasLength(1));
      at(const Duration(minutes: 56));
      await WeatherService.fetch(_lat, _lng);
      expect(calls, hasLength(2));
    });

    test('a reading older than its cache time is replaced as soon as MET Norway answers', () async {
      final old = _metAt(_t1340.subtract(const Duration(minutes: 40)),
          freshUntil: _t1340.subtract(const Duration(minutes: 10)));
      SharedPreferences.setMockInitialValues(_saved(old));
      serve();
      final w = await WeatherService.fetch(_lat, _lng);
      expect(calls, hasLength(1));
      expect(w!.fetchedAt, _t1340);
    });

    test('a damaged saved reading is ignored', () async {
      SharedPreferences.setMockInitialValues({'weather_met_${WeatherService.cell(_lat, _lng)}': '{oops'});
      expect(await WeatherService.cached(_lat, _lng), isNull);
    });

    test('a reading saved by the old (OpenWeather) version is never shown', () async {
      SharedPreferences.setMockInitialValues({
        'weather_${WeatherService.cell(_lat, _lng)}': jsonEncode({
          'temp': 22.3, 'feels': 21.4, 'humidity': 30, 'wind': 4.1, 'id': 800, 'night': false,
          'sunrise': 410, 'sunset': 1057, 'at': _t1340.millisecondsSinceEpoch, 'src': 'owm',
        }),
      });
      expect(await WeatherService.cached(_lat, _lng), isNull);
    });
  });

  group('the weather card on the Deen screen', () {
    /// The Deen tab with a saved reading for its place (34.1, 74.8).
    Future<void> open(WidgetTester tester, WeatherNow? reading,
        {ThemeData? theme, double scale = 1.0, Locale? locale, double width = 360}) async {
      _phone(tester, w: width);
      SharedPreferences.setMockInitialValues({
        ..._deenSaved(),
        if (reading != null)
          'weather_met_${WeatherService.cell(34.1, 74.8)}': jsonEncode(reading.toJson()),
      });
      WeatherService.get = (u) async => throw Exception('offline');
      await tester.pumpWidget(_app(const DeenTab(), theme: theme ?? AppTheme.light, textScale: scale, locale: locale));
      await _settle(tester);
    }

    testWidgets('shows the reading, below the prayer times, with no data-source line', (tester) async {
      await open(tester, _metAt(_t1340));
      expect(find.text('Weather'), findsOneWidget);
      expect(find.text('18°C'), findsOneWidget);
      expect(find.text('Partly cloudy'), findsOneWidget);
      expect(find.text('Humidity'), findsOneWidget);
      expect(find.text('38%'), findsOneWidget);
      expect(find.text('Wind'), findsOneWidget);
      expect(find.text('12 km/h'), findsOneWidget);
      expect(find.text('Sunrise'), findsOneWidget);
      expect(find.text('6:51 AM'), findsOneWidget);
      expect(find.text('Sunset'), findsOneWidget);
      expect(find.text('5:37 PM'), findsOneWidget);
      expect(find.byIcon(Icons.wb_cloudy_rounded), findsOneWidget);
      expect(find.textContaining('MET Norway'), findsNothing);
      expect(find.textContaining('OpenWeather'), findsNothing);

      // The prayer times are still there, and the card sits below them.
      expect(find.text('5:15 AM'), findsOneWidget);
      final prayerBottom = tester.getBottomLeft(find.text('Isha').last).dy;
      final weatherTop = tester.getTopLeft(find.text('Weather')).dy;
      expect(weatherTop, greaterThan(prayerBottom));
      expect(tester.takeException(), isNull);
    });

    testWidgets('mild air has no "Feels like" line; a cold windy day has one', (tester) async {
      await open(tester, _metAt(_t1340));
      expect(find.textContaining('Feels like'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await open(tester, _one('cloudy', temp: 2, rh: 60, wind: 6));
      expect(find.textContaining('Feels like'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a night sky has the night icon', (tester) async {
      await open(tester, _one('clearsky_night', temp: 6));
      expect(find.text('Clear sky'), findsOneWidget);
      expect(find.byIcon(Icons.nightlight_round), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('with no reading and no network the card stays away, quietly', (tester) async {
      await open(tester, null);
      expect(find.text('Weather'), findsNothing);
      expect(find.text('5:15 AM'), findsOneWidget);
      expect(find.text('Continue Reading'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a reading from the internet appears, asked for at the saved place', (tester) async {
      _phone(tester);
      Uri? asked;
      SharedPreferences.setMockInitialValues(_deenSaved());
      WeatherService.get = (u) async {
        asked = u;
        return http.Response(_met(), 200);
      };
      await tester.pumpWidget(_app(const DeenTab(), theme: AppTheme.light));
      await _settle(tester);
      expect(find.text('18°C'), findsOneWidget);
      expect(find.textContaining('MET Norway'), findsNothing);
      expect(asked?.host, 'api.met.no');
      expect(asked?.queryParameters, {'lat': '34.1000', 'lon': '74.8000'});
      expect(await WeatherService.cached(34.1, 74.8), isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a place with no sun times shows no sunrise and sunset', (tester) async {
      final base = _metAt(_t1340);
      final noSun = WeatherNow(
        tempC: base.tempC,
        humidity: base.humidity,
        windKmh: base.windKmh,
        kind: base.kind,
        isNight: false,
        fetchedAt: _t1340,
      );
      await open(tester, noSun);
      expect(find.text('Weather'), findsOneWidget);
      expect(find.text('Sunrise'), findsNothing);
      expect(find.text('Sunset'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    for (final (lang, title, kind, wind) in [
      ('hi', 'मौसम', 'आंशिक बादल', '12 किमी/घंटा'),
      ('ur', 'موسم', 'جزوی ابر آلود', '12 کلومیٹر/گھنٹہ'),
    ]) {
      testWidgets('is in the app language ($lang)', (tester) async {
        await open(tester, _metAt(_t1340), locale: Locale(lang));
        expect(find.text(title), findsOneWidget);
        expect(find.text(kind), findsOneWidget);
        expect(find.text(wind), findsOneWidget);
        expect(find.text('18°C'), findsOneWidget);
        expect(find.textContaining('MET Norway'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    for (final (name, w, scale, dark) in [
      ('dark theme', 360.0, 1.0, true),
      ('a small phone with large text', 320.0, 1.6, false),
      ('large text in the dark', 360.0, 2.0, true),
    ]) {
      testWidgets('fits: $name', (tester) async {
        await open(tester, _one('cloudy', temp: 2, rh: 60, wind: 6),
            theme: dark ? AppTheme.dark : AppTheme.light, scale: scale, width: w);
        // With large text the card is further down the list: scroll to it.
        await tester.scrollUntilVisible(find.text('Weather'), 300,
            scrollable: find.byType(Scrollable).first);
        await _settle(tester);
        expect(find.text('Weather'), findsOneWidget);
        expect(find.text('2°C'), findsOneWidget);
        expect(find.textContaining('Feels like'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'no overflow');
      });
    }
  });

  group('WeatherCardBody', () {
    test('writes the clock the way the prayer times are written', () {
      expect(WeatherCardBody.clock(0), '12:00 AM');
      expect(WeatherCardBody.clock(5 * 60 + 5), '5:05 AM');
      expect(WeatherCardBody.clock(12 * 60), '12:00 PM');
      expect(WeatherCardBody.clock(17 * 60 + 32), '5:32 PM');
      expect(WeatherCardBody.clock(23 * 60 + 59), '11:59 PM');
    });

    test('every kind has an icon and a colour, day and night', () {
      for (final k in WeatherKind.values) {
        for (final night in [false, true]) {
          expect(weatherIcon(k, night: night), isA<IconData>(), reason: '$k');
          expect(weatherColor(k, night: night), isA<Color>(), reason: '$k');
        }
      }
    });
  });
}
