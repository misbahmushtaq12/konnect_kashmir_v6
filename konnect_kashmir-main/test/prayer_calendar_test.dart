import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/screens/deen/prayer_service.dart';
import 'package:konnect_kashmir/services/prayer_alarm/prayer_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_aladhan.dart';

const _srinagar = (lat: 34.08, lng: 74.80);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('reading Aladhan\'s month', () {
    test('keeps the five times of each day without the zone suffix', () {
      final cal = PrayerCalendar.fromApi(
        jsonDecode(aladhanMonthJson(2026, 10)) as Map<String, dynamic>,
      );
      expect(cal.days.length, 31);
      expect(cal.days['2026-10-24'], [
        '05:10',
        '12:15',
        '15:30',
        '17:45',
        '19:05',
      ]);
      expect(cal.timeZone, 'Asia/Kolkata');
    });

    test('a day with a missing or odd time is left out, the rest stay', () {
      final body =
          jsonDecode(aladhanMonthJson(2026, 10)) as Map<String, dynamic>;
      (body['data'] as List)[3]['timings']['Asr'] = null;
      (body['data'] as List)[4]['timings']['Isha'] = 'soon';
      final cal = PrayerCalendar.fromApi(body);
      expect(cal.days.length, 29);
      expect(cal.days.containsKey('2026-10-04'), isFalse);
      expect(cal.days.containsKey('2026-10-05'), isFalse);
    });

    test('survives being saved and read back, and merges months', () {
      final a = PrayerCalendar.fromApi(
        jsonDecode(aladhanMonthJson(2026, 10)) as Map<String, dynamic>,
      );
      final b = PrayerCalendar.fromApi(
        jsonDecode(aladhanMonthJson(2026, 11)) as Map<String, dynamic>,
      );
      final back = PrayerCalendar.fromJson(
        jsonDecode(jsonEncode(a.merge(b).toJson())) as Map<String, dynamic>,
      );
      expect(back.days.length, 61);
      expect(back.timeZone, 'Asia/Kolkata');
    });
  });

  group('downloading and saving months', () {
    const settings = PrayerSettings();

    test('downloads a month once and then uses the saved one', () async {
      final api = FakeAladhan();
      final source = PrayerCalendarSource(fetch: api.fetch);
      final months = [(y: 2026, m: 10)];

      final first = await source.load(
        lat: _srinagar.lat,
        lng: _srinagar.lng,
        settings: settings,
        months: months,
      );
      expect(first.days.length, 31);
      expect(api.calls.length, 1);

      final again = await source.load(
        lat: _srinagar.lat,
        lng: _srinagar.lng,
        settings: settings,
        months: months,
      );
      expect(again.days.length, 31);
      expect(api.calls.length, 1, reason: 'the saved month is used');
    });

    test('asks for the right place, method and madhhab', () async {
      final api = FakeAladhan();
      final source = PrayerCalendarSource(fetch: api.fetch);
      await source.load(
        lat: 34.0837,
        lng: 74.7973,
        settings: const PrayerSettings(madhhab: Madhhab.shafi, method: 3),
        months: [(y: 2026, m: 10)],
      );
      final uri = api.calls.single;
      expect(uri.host, 'api.aladhan.com');
      expect(uri.path, '/v1/calendar/2026/10');
      expect(uri.queryParameters, {
        'latitude': '34.08',
        'longitude': '74.80',
        'method': '3',
        'school': '0',
      });
    });

    test('works offline from the saved months', () async {
      final api = FakeAladhan();
      final source = PrayerCalendarSource(fetch: api.fetch);
      final months = [(y: 2026, m: 10), (y: 2026, m: 11)];
      await source.load(
        lat: _srinagar.lat,
        lng: _srinagar.lng,
        settings: settings,
        months: months,
      );

      api.fail = true; // no internet from now on
      final offline = await source.load(
        lat: _srinagar.lat,
        lng: _srinagar.lng,
        settings: settings,
        months: months,
      );
      expect(offline.days.length, 61);
    });

    test(
      'a month that cannot be downloaded is missing, the others still come',
      () async {
        final api = FakeAladhan(
          respond: (uri, y, m) => m == 11
              ? throw Exception('server error')
              : aladhanMonthJson(y, m),
        );
        final cal = await PrayerCalendarSource(fetch: api.fetch).load(
          lat: _srinagar.lat,
          lng: _srinagar.lng,
          settings: settings,
          months: [(y: 2026, m: 10), (y: 2026, m: 11)],
        );
        expect(cal.days.length, 31);
        expect(cal.days.keys.every((k) => k.startsWith('2026-10')), isTrue);
      },
    );

    test(
      'nothing saved and no internet gives an empty calendar, not a crash',
      () async {
        final api = FakeAladhan()..fail = true;
        final cal = await PrayerCalendarSource(fetch: api.fetch).load(
          lat: _srinagar.lat,
          lng: _srinagar.lng,
          settings: settings,
          months: [(y: 2026, m: 10)],
        );
        expect(cal.isEmpty, isTrue);
      },
    );

    test('an empty or broken answer is not saved', () async {
      var body = '{"code":200,"data":[]}';
      final api = FakeAladhan(respond: (uri, y, m) => body);
      final source = PrayerCalendarSource(fetch: api.fetch);
      expect(
        (await source.load(
          lat: _srinagar.lat,
          lng: _srinagar.lng,
          settings: settings,
          months: [(y: 2026, m: 10)],
        )).isEmpty,
        isTrue,
      );
      body = aladhanMonthJson(2026, 10);
      expect(
        (await source.load(
          lat: _srinagar.lat,
          lng: _srinagar.lng,
          settings: settings,
          months: [(y: 2026, m: 10)],
        )).days.length,
        31,
        reason: 'asked again, since nothing was saved',
      );
    });

    test('another place, method or madhhab has its own saved months', () async {
      final api = FakeAladhan();
      final source = PrayerCalendarSource(fetch: api.fetch);
      final months = [(y: 2026, m: 10)];
      await source.load(
        lat: 34.08,
        lng: 74.80,
        settings: settings,
        months: months,
      );
      await source.load(
        lat: 28.61,
        lng: 77.21,
        settings: settings,
        months: months,
      );
      await source.load(
        lat: 34.08,
        lng: 74.80,
        settings: settings.copyWith(madhhab: Madhhab.shafi),
        months: months,
      );
      await source.load(
        lat: 34.08,
        lng: 74.80,
        settings: settings.copyWith(method: 3),
        months: months,
      );
      expect(api.calls.length, 4);
    });

    test(
      'old months are forgotten so the phone does not collect them',
      () async {
        final api = FakeAladhan();
        final source = PrayerCalendarSource(fetch: api.fetch);
        Future<void> get(int y, int m) => source.load(
          lat: _srinagar.lat,
          lng: _srinagar.lng,
          settings: settings,
          months: [(y: y, m: m)],
        );
        await get(2026, 6);
        await get(2026, 9);
        await get(
          2026,
          10,
        ); // the saving of October removes everything before September
        final sp = await SharedPreferences.getInstance();
        final keys = sp
            .getKeys()
            .where((k) => k.startsWith('prayer_cal_'))
            .toList();
        expect(keys.any((k) => k.contains('202606')), isFalse);
        expect(keys.any((k) => k.contains('202609')), isTrue);
        expect(keys.any((k) => k.contains('202610')), isTrue);
      },
    );
  });
}
