import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/screens/deen/weather_math.dart';

const _ist = Duration(hours: 5, minutes: 30);

void main() {
  group('sunTimes', () {
    // Real answers of OpenWeather for the same day and place (its times are cut to the
    // minute): Srinagar on 2 November 2026 rose at 06:50:53 and set at 17:37:46.
    test('Srinagar, 2 Nov 2026, agrees with OpenWeather to within two minutes', () {
      final s = sunTimes(34.0837, 74.7973, 2026, 11, 2, _ist)!;
      expect(s.rise, closeTo(6 * 60 + 51, 2));
      expect(s.set, closeTo(17 * 60 + 38, 2));
    });

    test('Dharwad, 1 Nov 2026, agrees with what the card showed there (6:26 and 6:00)', () {
      final s = sunTimes(15.45, 74.99, 2026, 11, 1, _ist)!;
      expect(s.rise, closeTo(6 * 60 + 27, 2.5));
      expect(s.set, closeTo(18 * 60 + 1, 2.5));
    });

    test('the southern hemisphere: Sydney, 21 Dec', () {
      final s = sunTimes(-33.87, 151.21, 2026, 12, 21, const Duration(hours: 11))!;
      expect(s.rise, closeTo(5 * 60 + 41, 4));
      expect(s.set, closeTo(20 * 60 + 5, 4));
    });

    test('summer days are longer than winter days in Srinagar', () {
      final summer = sunTimes(34.0837, 74.7973, 2026, 6, 21, _ist)!;
      final winter = sunTimes(34.0837, 74.7973, 2026, 12, 21, _ist)!;
      expect(summer.set - summer.rise, greaterThan(winter.set - winter.rise + 180));
    });

    test('on the equator at the equinox the day is about twelve hours', () {
      final s = sunTimes(0, 0, 2026, 3, 20, Duration.zero)!;
      expect(s.set - s.rise, inInclusiveRange(722, 732));
    });

    test('the clock only shifts the times', () {
      final a = sunTimes(34.0837, 74.7973, 2026, 11, 2, Duration.zero)!;
      final b = sunTimes(34.0837, 74.7973, 2026, 11, 2, _ist)!;
      expect(b.rise - a.rise, 330);
      expect(b.set - a.set, 330);
    });

    test('the midnight sun and the polar night have no sunrise and sunset', () {
      expect(sunTimes(69.65, 18.96, 2026, 6, 21, const Duration(hours: 2)), isNull);
      expect(sunTimes(69.65, 18.96, 2026, 12, 21, const Duration(hours: 1)), isNull);
    });

    test('it works at the turn of the month and the year', () {
      for (final (y, m, d) in [(2026, 12, 31), (2027, 1, 1), (2026, 2, 28), (2028, 2, 29), (2026, 3, 1)]) {
        final s = sunTimes(34.0837, 74.7973, y, m, d, _ist)!;
        expect(s.rise, inInclusiveRange(5 * 60, 8 * 60), reason: '$y-$m-$d');
        expect(s.set, inInclusiveRange(16 * 60 + 30, 20 * 60), reason: '$y-$m-$d');
      }
    });
  });

  group('feelsLikeC (only where an official index is defined)', () {
    test('mild air: no index applies, so there is no value (nothing is made up)', () {
      expect(feelsLikeC(18, 38, 11.5), isNull);
      expect(feelsLikeC(22, 60, 20), isNull);
      expect(feelsLikeC(10.5, 50, 30), isNull);
      expect(feelsLikeC(26.9, 80, 10), isNull);
    });

    test('cold with wind: the wind chill', () {
      expect(feelsLikeC(0, 50, 20), closeTo(-5.2, 0.1));
      expect(feelsLikeC(5, 50, 15), closeTo(1.75, 0.1));
      expect(feelsLikeC(10, 50, 10), lessThan(10));
    });

    test('cold without wind: none (the wind chill needs over 4.8 km/h)', () {
      expect(feelsLikeC(0, 50, 4), isNull);
      expect(feelsLikeC(-3, 50, 0), isNull);
    });

    test('hot and humid: the heat index', () {
      expect(feelsLikeC(35, 60, 5), closeTo(45, 1.5));
      expect(feelsLikeC(32, 70, 5), greaterThan(38));
    });

    test('hot and dry: none (the heat index needs 40 % humidity)', () {
      expect(feelsLikeC(35, 20, 5), isNull);
      expect(feelsLikeC(30, 39, 5), isNull);
    });
  });
}
