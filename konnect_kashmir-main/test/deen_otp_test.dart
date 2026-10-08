import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/l10n/app_localizations.dart';
import 'package:konnect_kashmir/screens/deen/deen_data.dart';
import 'package:konnect_kashmir/screens/deen/prayer_service.dart';
import 'package:konnect_kashmir/screens/otp_ver.dart';
import 'package:konnect_kashmir/services/auth_service.dart';

/// Standard great-circle initial bearing from (lat, lng) to the Kaaba, written
/// independently of the app's formula (it is the same bearing, scaled by cos φ2).
double _reference(double lat, double lng) {
  double r(double d) => d * math.pi / 180;
  final dl = r(39.8262 - lng);
  final y = math.sin(dl) * math.cos(r(21.4225));
  final x = math.cos(r(lat)) * math.sin(r(21.4225)) -
      math.sin(r(lat)) * math.cos(r(21.4225)) * math.cos(dl);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

void main() {
  audioUrlTests();
  group('Qibla', () {
    test('London is about 119 degrees from North', () {
      expect(qiblaBearing(51.5074, -0.1278), closeTo(118.99, 0.5));
    });

    test('matches the standard great-circle bearing in several places', () {
      for (final p in [
        (34.0837, 74.7973), // Srinagar
        (28.6139, 77.2090), // Delhi
        (40.7128, -74.0060), // New York
        (-33.8688, 151.2093), // Sydney
        (21.0, 39.0), // near Makkah
      ]) {
        expect(qiblaBearing(p.$1, p.$2), closeTo(_reference(p.$1, p.$2), 1e-6));
      }
    });

    test('indicator turns by qibla minus heading, the short way round', () {
      expect(qiblaTurn(100, 90), closeTo(10, 1e-9));
      expect(qiblaTurn(10, 350), closeTo(20, 1e-9));
      expect(qiblaTurn(350, 10), closeTo(-20, 1e-9));
      expect(qiblaTurn(90, 90), 0);
    });
  });

  group('Prayer times (Aladhan data.timings / data.date.hijri)', () {
    test('reads the five prayers and the Hijri date', () {
      final day = PrayerDay.fromApi({
        'timings': {
          'Fajr': '04:21 (IST)',
          'Sunrise': '05:52',
          'Dhuhr': '12:20',
          'Asr': '16:35',
          'Maghrib': '18:40',
          'Isha': '20:05',
        },
        'date': {
          'hijri': {
            'day': '17',
            'month': {'en': "Rabi' al-thani"},
            'year': '1448',
          },
        },
      });
      expect(day.times, ['04:21', '12:20', '16:35', '18:40', '20:05']);
      expect(day.hijri, "17 Rabi' al-thani 1448");
    });
  });

  group('OTP rules', () {
    test('4 digits, valid 5 minutes, resend after 30 seconds', () {
      expect(AuthService.otpLength, 4);
      expect(AuthService.otpValidity, const Duration(minutes: 5));
      expect(AuthService.resendWait, const Duration(seconds: 30));
    });

    testWidgets('the OTP field takes exactly 4 digits', (tester) async {
      await tester.pumpWidget(MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const OTPVerificationScreen(phoneNumber: '9876543210'),
      ));
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.maxLength, 4);
      expect(find.textContaining('4-digit'), findsOneWidget);
    });
  });
}

void audioUrlTests() {
  group('Quran audio URLs', () {
    test('surah numbers are padded to three digits', () {
      const r = Reciter('x', 'abc/def');
      expect(r.surahUrl(1), 'https://download.quranicaudio.com/quran/abc/def/001.mp3');
      expect(r.surahUrl(36), endsWith('/036.mp3'));
      expect(r.surahUrl(114), endsWith('/114.mp3'));
    });
  });
}
