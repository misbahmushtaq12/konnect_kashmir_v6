import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/l10n/l10n.dart';
import 'package:konnect_kashmir/screens/deen/audio_controller.dart';
import 'package:konnect_kashmir/screens/deen/audio_screen.dart';
import 'package:konnect_kashmir/screens/deen/deen_data.dart';
import 'package:konnect_kashmir/screens/deen/now_playing_screen.dart';
import 'package:konnect_kashmir/screens/deen/quran_screens.dart';
import 'package:konnect_kashmir/screens/deen/quran_service.dart';
import 'package:konnect_kashmir/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_audio_backend.dart';

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

const _surahs = [
  Surah(1, 'سُورَةُ ٱلْفَاتِحَةِ', 'Al-Faatiha', 'The Opening', 7),
  Surah(2, 'سُورَةُ البَقَرَةِ', 'Al-Baqara', 'The Cow', 286),
  Surah(3, 'سُورَةُ آلِ عِمْرَانَ', 'Aal-i-Imraan', 'The Family of Imraan', 200),
];

Widget _app(Widget home, {ThemeData? theme, double textScale = 1.0}) => MaterialApp(
      theme: theme ?? AppTheme.dark,
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
      home: home,
    );

QuranAudioController _controller(FakeBackend b) {
  final c = QuranAudioController(b);
  c.surahs = _surahs;
  c.loading = false;
  return c;
}

void _phone(WidgetTester tester, {double w = 360, double h = 800}) {
  tester.view.physicalSize = Size(w * 2, h * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

/// Opens the player the way the audio list does: on top of another page.
Future<void> _openPlayer(WidgetTester tester, QuranAudioController c,
    {ThemeData? theme, double textScale = 1.0}) async {
  await tester.pumpWidget(_app(
    Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) => NowPlayingScreen(controller: c)),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
    theme: theme,
    textScale: textScale,
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(_loadRoboto);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late FakeBackend backend;
  late QuranAudioController c;
  setUp(() => backend = FakeBackend());
  // The controller is made inside each test: its listeners must live in the
  // test's own zone, or the fake clock would not deliver their events.
  tearDown(() => c.dispose());

  group('the full-screen player', () {
    testWidgets('shows the surah, the reciter and the controls', (tester) async {
      _phone(tester);
      c = _controller(backend);
      await c.play(2);
      await _openPlayer(tester, c);

      expect(find.text('Al-Baqara'), findsOneWidget); // the title
      expect(find.text('سُورَةُ البَقَرَةِ'), findsOneWidget); // on the picture
      expect(find.text('The Cow'), findsOneWidget);
      expect(find.text(kReciters[0].name), findsWidgets);
      expect(find.text('Now playing'), findsOneWidget);
      expect(find.text('Read'), findsOneWidget);
      expect(find.text('286 verses'), findsOneWidget);
      expect(find.text('Queue'), findsOneWidget);

      for (final icon in [
        Icons.shuffle_rounded,
        Icons.skip_previous_rounded,
        Icons.pause_rounded, // playing now, so the big button shows "pause"
        Icons.skip_next_rounded,
        Icons.repeat_rounded,
        Icons.keyboard_arrow_down_rounded,
      ]) {
        expect(find.byIcon(icon), findsOneWidget, reason: '$icon');
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('the time and the seek bar follow the recitation', (tester) async {
      _phone(tester);
      c = _controller(backend);
      await c.play(1);
      await _openPlayer(tester, c);

      backend.position(const Duration(minutes: 1, seconds: 5));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('01:05'), findsOneWidget);
      expect(find.text('05:00'), findsOneWidget);

      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, 65000);
      expect(slider.max, 300000);
    });

    testWidgets('play / pause, next, previous, shuffle and repeat work',
        (tester) async {
      _phone(tester);
      c = _controller(backend);
      await c.play(2);
      await _openPlayer(tester, c);

      // Pause, then play again.
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();
      expect(c.playing, isFalse);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      expect(c.playing, isTrue);

      // Next, then back.
      await tester.tap(find.byIcon(Icons.skip_next_rounded));
      await tester.pumpAndSettle();
      expect(c.current, 3);
      expect(find.text('Aal-i-Imraan'), findsOneWidget);
      // On the last surah "next" is switched off.
      final next = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.skip_next_rounded));
      expect(next.onPressed, isNull);

      await tester.tap(find.byIcon(Icons.skip_previous_rounded));
      await tester.pumpAndSettle();
      expect(c.current, 2);

      // Repeat and shuffle switch on and show it.
      await tester.tap(find.byIcon(Icons.repeat_rounded));
      await tester.pump();
      expect(c.repeat, isTrue);
      expect(find.byIcon(Icons.repeat_one_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.shuffle_rounded));
      await tester.pump();
      expect(c.shuffle, isTrue);
    });

    testWidgets('the queue lists the surahs and a tap plays one', (tester) async {
      _phone(tester);
      c = _controller(backend);
      await c.play(1);
      await _openPlayer(tester, c);

      await tester.tap(find.text('Queue'));
      await tester.pumpAndSettle();
      expect(find.text('Al-Baqara'), findsOneWidget);
      expect(find.text('Aal-i-Imraan'), findsOneWidget);
      expect(find.byIcon(Icons.equalizer_rounded), findsOneWidget); // the playing one

      await tester.tap(find.text('Aal-i-Imraan'));
      await tester.pumpAndSettle();
      expect(c.current, 3);
      expect(backend.urls.last, kReciters[0].surahUrl(3));
      expect(find.text('Al-Baqara'), findsNothing, reason: 'the sheet closed');
    });

    testWidgets('the reciter menu changes the voice', (tester) async {
      _phone(tester);
      c = _controller(backend);
      await c.play(1);
      await _openPlayer(tester, c);

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text(kReciters[2].name));
      await tester.pumpAndSettle();
      expect(c.reciter, 2);
      expect(backend.urls.last, kReciters[2].surahUrl(1));
    });

    testWidgets('Read opens the Quran at this surah', (tester) async {
      _phone(tester);
      c = _controller(backend);
      await c.play(3);
      await _openPlayer(tester, c);
      await tester.tap(find.text('Read'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SurahReaderScreen), findsOneWidget);
      expect(tester.widget<SurahReaderScreen>(find.byType(SurahReaderScreen)).surah.number, 3);
      tester.takeException(); // the reader's own network call is not under test
    });

    testWidgets('the arrow at the top closes it', (tester) async {
      _phone(tester);
      c = _controller(backend);
      await c.play(1);
      await _openPlayer(tester, c);
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(NowPlayingScreen), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('it closes by itself when the last surah ends', (tester) async {
      _phone(tester);
      c = _controller(backend);
      await c.play(3);
      await _openPlayer(tester, c);
      backend.finish();
      // Let the end of the recording reach the controller, then settle.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(find.byType(NowPlayingScreen), findsNothing);
    });

    testWidgets('light theme, a small screen and large text, without overflow',
        (tester) async {
      _phone(tester, w: 320, h: 640);
      c = _controller(backend);
      await c.play(2);
      await _openPlayer(tester, c, theme: AppTheme.light, textScale: 1.5);
      expect(find.text('Al-Baqara'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('the audio list', () {
    final saved = jsonEncode([for (final s in _surahs) s.toJson()]);

    Future<QuranAudioController> pumpList(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({'quran_surahs': saved});
      final list = QuranAudioController(backend);
      await tester.pumpWidget(_app(AudioScreen(title: 'Audio', controller: list)));
      await tester.pumpAndSettle();
      return list;
    }

    testWidgets('tapping a surah plays it and opens the player', (tester) async {
      _phone(tester);
      c = _controller(backend);
      final list = await pumpList(tester);
      expect(find.text('2. Al-Baqara'), findsOneWidget);

      await tester.tap(find.text('2. Al-Baqara'));
      await tester.pumpAndSettle();

      expect(list.current, 2);
      expect(backend.urls, [kReciters[0].surahUrl(2)]);
      expect(find.byType(NowPlayingScreen), findsOneWidget);
      expect(find.text('Now playing'), findsOneWidget);
      list.dispose();
    });

    testWidgets('closing the player leaves a small player; its title reopens it',
        (tester) async {
      _phone(tester);
      c = _controller(backend);
      final list = await pumpList(tester);
      await tester.tap(find.text('1. Al-Faatiha'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(NowPlayingScreen), findsNothing);
      // The small player at the bottom: tap its title to open the big one.
      await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(NowPlayingScreen), findsOneWidget);
      list.dispose();
    });

    testWidgets('tapping the surah that is already playing does not restart it',
        (tester) async {
      _phone(tester);
      c = _controller(backend);
      final list = await pumpList(tester);
      await tester.tap(find.text('3. Aal-i-Imraan'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('3. Aal-i-Imraan'));
      await tester.pumpAndSettle();
      expect(backend.urls.length, 1, reason: 'the same recording keeps playing');
      expect(find.byType(NowPlayingScreen), findsOneWidget);
      list.dispose();
    });
  });
}
