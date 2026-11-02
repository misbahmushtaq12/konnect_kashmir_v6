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
import 'package:konnect_kashmir/services/weather_config.dart';
import 'package:konnect_kashmir/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _lat = 34.0837, _lng = 74.7973; // Srinagar

/// OpenWeather's `/data/2.5/weather` answer (the parts the app reads).
String _answer({
  int id = 802,
  String icon = '03d',
  double temp = 12.4,
  double feels = 10.3,
  int humidity = 63,
  double wind = 2.5,
  int tz = 19800,
  bool sun = true,
}) {
  // 06:45 and 17:32 on the clock of a place 5h30 ahead of UTC.
  final rise = DateTime.utc(2026, 10, 31, 1, 15).millisecondsSinceEpoch ~/ 1000;
  final set = DateTime.utc(2026, 10, 31, 12, 2).millisecondsSinceEpoch ~/ 1000;
  return jsonEncode({
    'coord': {'lon': _lng, 'lat': _lat},
    'weather': [
      {'id': id, 'main': 'Clouds', 'description': 'scattered clouds', 'icon': icon}
    ],
    'main': {
      'temp': temp,
      'feels_like': feels,
      'pressure': 1018,
      'humidity': humidity,
    },
    'wind': {'speed': wind, 'deg': 270},
    'sys': {if (sun) 'sunrise': rise, if (sun) 'sunset': set},
    'timezone': tz,
    'name': 'Srinagar',
    'cod': 200,
  });
}

WeatherNow _reading({DateTime? at, int id = 802, bool night = false}) => WeatherNow.fromApi(
      jsonDecode(_answer(id: id, icon: night ? '03n' : '03d')) as Map<String, dynamic>,
      fetchedAt: at ?? DateTime.now(),
    );

/// A saved reading for the area of [_lat], [_lng].
Map<String, Object> _savedReading(WeatherNow w) =>
    {'weather_${WeatherService.cell(_lat, _lng)}': jsonEncode(w.toJson())};

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
    WeatherService.apiKey = 'test-key';
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(WeatherService.reset);

  group('the OpenWeather key', () {
    test('is set', () {
      expect(kOpenWeatherKey, matches(RegExp(r'^[0-9a-f]{32}$')));
    });
  });

  group('weatherKindOf', () {
    test('groups the OpenWeather condition codes', () {
      const expected = {
        200: WeatherKind.thunderstorm,
        232: WeatherKind.thunderstorm,
        300: WeatherKind.drizzle,
        321: WeatherKind.drizzle,
        500: WeatherKind.rain,
        531: WeatherKind.rain,
        600: WeatherKind.snow,
        622: WeatherKind.snow,
        701: WeatherKind.fog,
        741: WeatherKind.fog,
        711: WeatherKind.haze,
        721: WeatherKind.haze,
        731: WeatherKind.dust,
        751: WeatherKind.dust,
        761: WeatherKind.dust,
        762: WeatherKind.dust,
        771: WeatherKind.storm,
        781: WeatherKind.storm,
        800: WeatherKind.clear,
        801: WeatherKind.partlyCloudy,
        802: WeatherKind.partlyCloudy,
        803: WeatherKind.cloudy,
        804: WeatherKind.cloudy,
        999: WeatherKind.cloudy,
      };
      expected.forEach((id, kind) => expect(weatherKindOf(id), kind, reason: '$id'));
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

  group('WeatherNow.fromApi', () {
    test('reads the answer', () {
      final w = WeatherNow.fromApi(jsonDecode(_answer()) as Map<String, dynamic>,
          fetchedAt: DateTime(2026, 10, 31, 12));
      expect(w.tempC, 12.4);
      expect(w.feelsLikeC, 10.3);
      expect(w.humidity, 63);
      expect(w.windKmh, closeTo(9.0, 0.001), reason: '2.5 m/s');
      expect(w.conditionId, 802);
      expect(w.kind, WeatherKind.partlyCloudy);
      expect(w.isNight, isFalse);
      expect(w.sunriseMin, 6 * 60 + 45, reason: 'on the clock of the place');
      expect(w.sunsetMin, 17 * 60 + 32);
      expect(w.fetchedAt, DateTime(2026, 10, 31, 12));
    });

    test('reads a real OpenWeather answer (Srinagar, 31 Oct 2026, evening)', () {
      const real = '{"coord":{"lon":74.7973,"lat":34.0837},"weather":[{"id":800,"main":"Clear",'
          '"description":"clear sky","icon":"01n"}],"base":"stations","main":{"temp":9.57,'
          '"feels_like":9.57,"temp_min":9.57,"temp_max":9.57,"pressure":1023,"humidity":57,'
          '"sea_level":1023,"grnd_level":838},"visibility":10000,"wind":{"speed":1.11,"deg":9,'
          '"gust":1.51},"clouds":{"all":8},"dt":1793468690,"sys":{"country":"IN",'
          '"sunrise":1793409543,"sunset":1793448580},"timezone":19800,"id":1255634,'
          '"name":"Srinagar","cod":200}';
      final w = WeatherNow.fromApi(jsonDecode(real) as Map<String, dynamic>,
          fetchedAt: DateTime.now());
      expect(w.tempC, 9.57);
      expect(w.humidity, 57);
      expect(w.windKmh, closeTo(3.996, 0.001));
      expect(w.kind, WeatherKind.clear);
      expect(w.isNight, isTrue);
      expect(WeatherCardBody.clock(w.sunriseMin!), '6:49 AM');
      expect(WeatherCardBody.clock(w.sunsetMin!), '5:39 PM');
    });

    test('night comes from the icon', () {
      final w = WeatherNow.fromApi(
          jsonDecode(_answer(icon: '01n', id: 800)) as Map<String, dynamic>,
          fetchedAt: DateTime.now());
      expect(w.isNight, isTrue);
      expect(w.kind, WeatherKind.clear);
    });

    test('the place\'s own time zone moves the sun times', () {
      final w = WeatherNow.fromApi(jsonDecode(_answer(tz: 0)) as Map<String, dynamic>,
          fetchedAt: DateTime.now());
      expect(w.sunriseMin, 1 * 60 + 15);
      expect(w.sunsetMin, 12 * 60 + 2);
    });

    test('a place where the sun does not rise has no sun times', () {
      final w = WeatherNow.fromApi(jsonDecode(_answer(sun: false)) as Map<String, dynamic>,
          fetchedAt: DateTime.now());
      expect(w.sunriseMin, isNull);
      expect(w.sunsetMin, isNull);
    });

    test('whole numbers are fine too', () {
      final j = jsonDecode(_answer()) as Map<String, dynamic>;
      j['main'] = {'temp': 9, 'feels_like': 7, 'humidity': 80};
      j['wind'] = {'speed': 0};
      final w = WeatherNow.fromApi(j, fetchedAt: DateTime.now());
      expect(w.tempC, 9.0);
      expect(w.windKmh, 0.0);
    });

    test('an answer without the weather is an error', () {
      expect(() => WeatherNow.fromApi({'cod': 200}, fetchedAt: DateTime.now()),
          throwsFormatException);
      final j = jsonDecode(_answer()) as Map<String, dynamic>..['weather'] = [];
      expect(() => WeatherNow.fromApi(j, fetchedAt: DateTime.now()), throwsFormatException);
    });

    test('goes to JSON and back', () {
      final w = _reading(at: DateTime.fromMillisecondsSinceEpoch(1761900000000), night: true);
      final back = WeatherNow.fromJson(jsonDecode(jsonEncode(w.toJson())) as Map<String, dynamic>);
      expect(back.tempC, w.tempC);
      expect(back.feelsLikeC, w.feelsLikeC);
      expect(back.humidity, w.humidity);
      expect(back.windKmh, w.windKmh);
      expect(back.conditionId, w.conditionId);
      expect(back.isNight, isTrue);
      expect(back.sunriseMin, w.sunriseMin);
      expect(back.sunsetMin, w.sunsetMin);
      expect(back.fetchedAt, w.fetchedAt);
    });
  });

  group('WeatherService', () {
    test('asks OpenWeather for metric weather at the place with the key', () {
      final u = WeatherService.uriFor(_lat, _lng);
      expect(u.scheme, 'https');
      expect(u.host, 'api.openweathermap.org');
      expect(u.path, '/data/2.5/weather');
      expect(u.queryParameters, {
        'lat': '34.0837',
        'lon': '74.7973',
        'units': 'metric',
        'appid': 'test-key',
      });
    });

    test('fetches, shows it and saves it on the phone', () async {
      final calls = <Uri>[];
      WeatherService.get = (u) async {
        calls.add(u);
        return http.Response(_answer(), 200);
      };
      final w = await WeatherService.fetch(_lat, _lng);
      expect(w, isNotNull);
      expect(w!.tempC, 12.4);
      expect(calls, hasLength(1));
      final saved = await WeatherService.cached(_lat, _lng);
      expect(saved?.tempC, 12.4);
    });

    test('no new request while the reading is fresh; one when it is not, or when forced', () async {
      var calls = 0;
      var clock = DateTime(2026, 10, 31, 12);
      WeatherService.now = () => clock;
      WeatherService.get = (u) async {
        calls++;
        return http.Response(_answer(temp: 10.0 + calls), 200);
      };

      await WeatherService.fetch(_lat, _lng);
      expect(calls, 1);

      clock = clock.add(const Duration(minutes: 19));
      final again = await WeatherService.fetch(_lat, _lng);
      expect(calls, 1, reason: 'still fresh');
      expect(again!.tempC, 11.0);

      clock = clock.add(const Duration(minutes: 2)); // 21 minutes
      final later = await WeatherService.fetch(_lat, _lng);
      expect(calls, 2);
      expect(later!.tempC, 12.0);

      final forced = await WeatherService.fetch(_lat, _lng, force: true);
      expect(calls, 3);
      expect(forced!.tempC, 13.0);
    });

    test('a nearby place (same area) shares the reading, a far one does not', () async {
      var calls = 0;
      WeatherService.get = (u) async {
        calls++;
        return http.Response(_answer(), 200);
      };
      await WeatherService.fetch(34.0837, 74.7973);
      await WeatherService.fetch(34.0901, 74.8010);
      expect(calls, 1);
      await WeatherService.fetch(28.6139, 77.2090); // Delhi
      expect(calls, 2);
    });

    test('two askers at once share one request', () async {
      var calls = 0;
      WeatherService.get = (u) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return http.Response(_answer(), 200);
      };
      final both = await Future.wait([
        WeatherService.fetch(_lat, _lng),
        WeatherService.fetch(_lat, _lng),
      ]);
      expect(calls, 1);
      expect(both.every((w) => w != null), isTrue);
    });

    test('a key that is not active yet (401) gives nothing, quietly', () async {
      WeatherService.get = (u) async => http.Response(
          '{"cod":401, "message": "Invalid API key."}', 401);
      expect(await WeatherService.fetch(_lat, _lng), isNull);
      expect(await WeatherService.cached(_lat, _lng), isNull);
    });

    test('no network, a bad answer, or a rate limit give nothing, quietly', () async {
      WeatherService.get = (u) async => throw const SocketException('no internet');
      expect(await WeatherService.fetch(_lat, _lng), isNull);

      WeatherService.get = (u) async => http.Response('not json', 200);
      expect(await WeatherService.fetch(_lat, _lng), isNull);

      WeatherService.get = (u) async => http.Response('{"cod":200}', 200);
      expect(await WeatherService.fetch(_lat, _lng), isNull);

      WeatherService.get = (u) async => http.Response('{"cod":429}', 429);
      expect(await WeatherService.fetch(_lat, _lng), isNull);
    });

    test('when a request fails, the saved reading is kept', () async {
      final clock = DateTime(2026, 10, 31, 12);
      WeatherService.now = () => clock;
      SharedPreferences.setMockInitialValues(
          _savedReading(_reading(at: clock.subtract(const Duration(minutes: 40)))));
      WeatherService.get = (u) async => throw const SocketException('no internet');
      final w = await WeatherService.fetch(_lat, _lng);
      expect(w?.tempC, 12.4);
    });

    test('a saved reading older than three hours is not shown', () async {
      final clock = DateTime(2026, 10, 31, 12);
      WeatherService.now = () => clock;
      SharedPreferences.setMockInitialValues(
          _savedReading(_reading(at: clock.subtract(const Duration(hours: 2, minutes: 59)))));
      expect(await WeatherService.cached(_lat, _lng), isNotNull);
      SharedPreferences.setMockInitialValues(
          _savedReading(_reading(at: clock.subtract(const Duration(hours: 3, minutes: 1)))));
      expect(await WeatherService.cached(_lat, _lng), isNull);
    });

    test('a damaged saved reading is ignored', () async {
      SharedPreferences.setMockInitialValues(
          {'weather_${WeatherService.cell(_lat, _lng)}': '{oops'});
      expect(await WeatherService.cached(_lat, _lng), isNull);
    });
  });

  group('the weather card on the Deen screen', () {
    testWidgets('shows the saved reading with all its details', (tester) async {
      _phone(tester);
      var calls = 0;
      WeatherService.get = (u) async {
        calls++;
        return http.Response(_answer(), 200);
      };
      SharedPreferences.setMockInitialValues({
        ..._deenSaved(),
        'weather_${WeatherService.cell(34.1, 74.8)}': jsonEncode(_reading().toJson()),
      });
      await tester.pumpWidget(_app(const DeenTab(), theme: AppTheme.light));
      await _settle(tester);

      expect(find.text('Weather'), findsOneWidget);
      expect(find.text('12°C'), findsOneWidget);
      expect(find.text('Partly cloudy'), findsOneWidget);
      expect(find.text('Feels like 10°'), findsOneWidget);
      expect(find.text('Humidity'), findsOneWidget);
      expect(find.text('63%'), findsOneWidget);
      expect(find.text('Wind'), findsOneWidget);
      expect(find.text('9 km/h'), findsOneWidget);
      expect(find.text('Sunrise'), findsOneWidget);
      expect(find.text('6:45 AM'), findsOneWidget);
      expect(find.text('Sunset'), findsOneWidget);
      expect(find.text('5:32 PM'), findsOneWidget);
      expect(find.byIcon(Icons.wb_cloudy_rounded), findsOneWidget);
      expect(calls, 0, reason: 'the saved reading is fresh: no request');

      // The prayer times are still there, and the card sits below them.
      expect(find.text('5:15 AM'), findsOneWidget);
      final prayerBottom = tester.getBottomLeft(find.text('Isha').last).dy;
      final weatherTop = tester.getTopLeft(find.text('Weather')).dy;
      expect(weatherTop, greaterThan(prayerBottom));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a night sky has the night icon', (tester) async {
      _phone(tester);
      SharedPreferences.setMockInitialValues({
        ..._deenSaved(),
        'weather_${WeatherService.cell(34.1, 74.8)}':
            jsonEncode(_reading(id: 800, night: true).toJson()),
      });
      WeatherService.get = (u) async => throw Exception('offline');
      await tester.pumpWidget(_app(const DeenTab(), theme: AppTheme.light));
      await _settle(tester);
      expect(find.text('Clear sky'), findsOneWidget);
      expect(find.byIcon(Icons.nightlight_round), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('with no reading and no network the card stays away, quietly', (tester) async {
      _phone(tester);
      SharedPreferences.setMockInitialValues(_deenSaved());
      WeatherService.get = (u) async => throw Exception('offline');
      await tester.pumpWidget(_app(const DeenTab(), theme: AppTheme.light));
      await _settle(tester);
      expect(find.text('Weather'), findsNothing);
      expect(find.text('5:15 AM'), findsOneWidget);
      expect(find.text('Continue Reading'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a key that is not active yet (401) leaves the card away', (tester) async {
      _phone(tester);
      SharedPreferences.setMockInitialValues(_deenSaved());
      WeatherService.get = (u) async => http.Response('{"cod":401}', 401);
      await tester.pumpWidget(_app(const DeenTab(), theme: AppTheme.light));
      await _settle(tester);
      expect(find.text('Weather'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a reading that arrives from the internet appears', (tester) async {
      _phone(tester);
      Uri? asked;
      SharedPreferences.setMockInitialValues(_deenSaved());
      WeatherService.get = (u) async {
        asked = u;
        return http.Response(_answer(id: 500, icon: '10d', temp: 4.6, feels: 1.2), 200);
      };
      await tester.pumpWidget(_app(const DeenTab(), theme: AppTheme.light));
      await _settle(tester);

      expect(find.text('5°C'), findsOneWidget, reason: '4.6 rounds to 5');
      expect(find.text('Rain'), findsOneWidget);
      expect(find.text('Feels like 1°'), findsOneWidget);
      expect(find.byIcon(Icons.water_drop_rounded), findsOneWidget);
      // It asked for the saved place.
      expect(asked?.queryParameters['lat'], '34.1000');
      expect(asked?.queryParameters['lon'], '74.8000');
      expect(asked?.queryParameters['units'], 'metric');
      // ...and kept the reading for next time.
      expect(await WeatherService.cached(34.1, 74.8), isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a place with no sun times shows no sunrise and sunset', (tester) async {
      _phone(tester);
      SharedPreferences.setMockInitialValues(_deenSaved());
      WeatherService.get = (u) async => http.Response(_answer(sun: false), 200);
      await tester.pumpWidget(_app(const DeenTab(), theme: AppTheme.light));
      await _settle(tester);
      expect(find.text('Weather'), findsOneWidget);
      expect(find.text('Sunrise'), findsNothing);
      expect(find.text('Sunset'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    for (final (lang, title, kind, wind) in [
      ('hi', 'मौसम', 'आंशिक बादल', '9 किमी/घंटा'),
      ('ur', 'موسم', 'جزوی ابر آلود', '9 کلومیٹر/گھنٹہ'),
    ]) {
      testWidgets('is in the app language ($lang)', (tester) async {
        _phone(tester);
        SharedPreferences.setMockInitialValues({
          ..._deenSaved(),
          'weather_${WeatherService.cell(34.1, 74.8)}': jsonEncode(_reading().toJson()),
        });
        WeatherService.get = (u) async => throw Exception('offline');
        await tester.pumpWidget(_app(const DeenTab(), locale: Locale(lang), theme: AppTheme.light));
        await _settle(tester);
        expect(find.text(title), findsOneWidget);
        expect(find.text(kind), findsOneWidget);
        expect(find.text(wind), findsOneWidget);
        expect(find.text('12°C'), findsOneWidget);
        // The number and its degree sign stay together, also right to left.
        expect(find.textContaining('10°'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    for (final (name, w, scale, dark) in [
      ('dark theme', 360.0, 1.0, true),
      ('a small phone with large text', 320.0, 1.6, false),
      ('large text in the dark', 360.0, 2.0, true),
    ]) {
      testWidgets('fits: $name', (tester) async {
        _phone(tester, w: w);
        SharedPreferences.setMockInitialValues({
          ..._deenSaved(),
          'weather_${WeatherService.cell(34.1, 74.8)}': jsonEncode(_reading().toJson()),
        });
        WeatherService.get = (u) async => throw Exception('offline');
        await tester.pumpWidget(_app(const DeenTab(),
            theme: dark ? AppTheme.dark : AppTheme.light, textScale: scale));
        await _settle(tester);
        // With large text the card is further down the list: scroll to it.
        await tester.scrollUntilVisible(find.text('Weather'), 300,
            scrollable: find.byType(Scrollable).first);
        await _settle(tester);
        expect(find.text('Weather'), findsOneWidget);
        expect(find.text('12°C'), findsOneWidget);
        expect(find.text('6:45 AM'), findsOneWidget);
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
  });
}
