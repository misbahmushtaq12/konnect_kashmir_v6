import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_theme.dart';
import 'weather_service.dart';

/// The name of a kind of weather in the app's language.
String weatherKindName(AppLocalizations l, WeatherKind k) => switch (k) {
      WeatherKind.clear => l.weatherClear,
      WeatherKind.partlyCloudy => l.weatherPartlyCloudy,
      WeatherKind.cloudy => l.weatherCloudy,
      WeatherKind.drizzle => l.weatherDrizzle,
      WeatherKind.rain => l.weatherRain,
      WeatherKind.thunderstorm => l.weatherThunderstorm,
      WeatherKind.snow => l.weatherSnow,
      WeatherKind.fog => l.weatherFog,
      WeatherKind.haze => l.weatherHaze,
      WeatherKind.dust => l.weatherDust,
      WeatherKind.storm => l.weatherStorm,
    };

IconData weatherIcon(WeatherKind k, {bool night = false}) => switch (k) {
      WeatherKind.clear => night ? Icons.nightlight_round : Icons.wb_sunny_rounded,
      WeatherKind.partlyCloudy =>
        night ? Icons.nights_stay_rounded : Icons.wb_cloudy_rounded,
      WeatherKind.cloudy => Icons.cloud_rounded,
      WeatherKind.drizzle => Icons.grain_rounded,
      WeatherKind.rain => Icons.water_drop_rounded,
      WeatherKind.thunderstorm => Icons.thunderstorm_rounded,
      WeatherKind.snow => Icons.ac_unit_rounded,
      WeatherKind.fog => Icons.foggy,
      WeatherKind.haze => Icons.blur_on_rounded,
      WeatherKind.dust => Icons.air_rounded,
      WeatherKind.storm => Icons.tornado_rounded,
    };

Color weatherColor(WeatherKind k, {bool night = false}) => switch (k) {
      WeatherKind.clear => night ? const Color(0xFF6C63D9) : const Color(0xFFF2B01E),
      WeatherKind.partlyCloudy =>
        night ? const Color(0xFF6C63D9) : const Color(0xFFF08A3C),
      WeatherKind.drizzle ||
      WeatherKind.rain ||
      WeatherKind.thunderstorm =>
        const Color(0xFF29A3E0),
      WeatherKind.snow => const Color(0xFF1BB5C9),
      _ => const Color(0xFF5F7D95),
    };

/// What the Deen weather card shows inside its frame: the temperature and the
/// sky, how it feels, the humidity and wind, and the sun's rise and set (useful
/// beside Fajr and Maghrib).
class WeatherCardBody extends StatelessWidget {
  final WeatherNow weather;
  const WeatherCardBody({super.key, required this.weather});

  /// 6:12 AM from minutes after midnight, the way the prayer times are written.
  static String clock(int minutes) {
    final h24 = (minutes ~/ 60) % 24;
    final h = h24 % 12 == 0 ? 12 : h24 % 12;
    return '$h:${(minutes % 60).toString().padLeft(2, '0')} ${h24 < 12 ? 'AM' : 'PM'}';
  }

  static String _deg(double t) => t.round().toString();

  /// "10°" for the middle of a sentence. In a right-to-left language the number and
  /// its degree sign are kept together, left to right, or the sign jumps to the
  /// wrong side of the number.
  static String _withDegree(BuildContext context, double t) {
    final s = '${_deg(t)}°';
    return Directionality.of(context) == TextDirection.rtl ? '\u2066$s\u2069' : s;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final w = weather;
    final tint = weatherColor(w.kind, night: w.isNight);
    final muted = cs.onSurface.withValues(alpha: 0.65);

    Widget stat(IconData icon, String label, String value) => Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label,
                    style: TextStyle(fontSize: AppText.caption, color: muted)),
                Text(value,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                        fontSize: AppText.body,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface)),
              ]),
            ),
          ]),
        );

    final hasSun = w.sunriseMin != null && w.sunsetMin != null;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l.deenWeather,
          style: TextStyle(
              fontSize: AppText.heading,
              fontWeight: FontWeight.w800,
              color: cs.onSurface)),
      const SizedBox(height: 10),
      Row(children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tint.withValues(alpha: 0.14),
          ),
          child: Icon(weatherIcon(w.kind, night: w.isNight), size: 30, color: tint),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${_deg(w.tempC)}°C',
                textDirection: TextDirection.ltr,
                style: TextStyle(
                    fontSize: AppText.titleLg,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    color: cs.onSurface)),
            const SizedBox(height: 2),
            Text(weatherKindName(l, w.kind),
                style: TextStyle(
                    fontSize: AppText.body,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
            if (w.feelsLikeC != null)
              Text(l.weatherFeelsLike(_withDegree(context, w.feelsLikeC!)),
                  style: TextStyle(fontSize: AppText.caption, color: muted)),
          ]),
        ),
      ]),
      const SizedBox(height: 14),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        stat(Icons.water_drop_outlined, l.weatherHumidity, '${w.humidity}%'),
        const SizedBox(width: 12),
        stat(Icons.air_rounded, l.weatherWind,
            l.weatherWindValue(w.windKmh.round().toString())),
      ]),
      if (hasSun) ...[
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          stat(Icons.wb_twilight_rounded, l.weatherSunrise, clock(w.sunriseMin!)),
          const SizedBox(width: 12),
          stat(Icons.nights_stay_rounded, l.weatherSunset, clock(w.sunsetMin!)),
        ]),
      ],
    ]);
  }
}
