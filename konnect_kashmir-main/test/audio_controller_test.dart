import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/screens/deen/audio_controller.dart';
import 'package:konnect_kashmir/screens/deen/deen_data.dart';
import 'package:konnect_kashmir/screens/deen/quran_service.dart';

import 'support/fake_audio_backend.dart';

const _surahs = [
  Surah(1, 'الفاتحة', 'Al-Faatiha', 'The Opening', 7),
  Surah(2, 'البقرة', 'Al-Baqara', 'The Cow', 286),
  Surah(3, 'آل عمران', 'Aal-i-Imraan', 'The Family of Imraan', 200),
  Surah(4, 'النساء', 'An-Nisaa', 'The Women', 176),
];

String _url(int reciter, int surah) => kReciters[reciter].surahUrl(surah);

QuranAudioController _make(FakeBackend b, {int seed = 1}) {
  final c = QuranAudioController(b, random: math.Random(seed));
  c.surahs = _surahs;
  c.loading = false;
  return c;
}

void main() {
  late FakeBackend backend;
  late QuranAudioController c;
  setUp(() {
    backend = FakeBackend();
    c = _make(backend);
  });
  tearDown(() => c.dispose());

  group('playing', () {
    test('a surah is played from the chosen reciter', () async {
      await c.play(2);
      expect(c.current, 2);
      expect(c.currentSurah?.english, 'Al-Baqara');
      expect(backend.urls, [_url(0, 2)]);
      expect(c.playing, isTrue);
    });

    test('tapping the playing surah pauses and resumes it; another one switches',
        () async {
      await c.toggle(1);
      expect(c.playing, isTrue);
      await c.toggle(1);
      expect(c.playing, isFalse);
      await c.toggle(1);
      expect(c.playing, isTrue);
      expect(backend.urls.length, 1, reason: 'the same recording, not reloaded');

      await c.toggle(3);
      expect(c.current, 3);
      expect(backend.urls.last, _url(0, 3));
    });

    test('a failure clears the current surah and tells the screen', () async {
      var errors = 0;
      c.errors.listen((_) => errors++);
      backend.failNext = true;
      await c.play(1);
      await pumpEventQueue();
      expect(c.current, isNull);
      expect(c.buffering, isFalse);
      expect(errors, 1);
    });

    test('another reciter carries on with the same surah', () async {
      await c.play(2);
      c.setReciter(3);
      await pumpEventQueue();
      expect(c.current, 2);
      expect(backend.urls.last, _url(3, 2));
    });
  });

  group('when a surah ends', () {
    test('the next one plays', () async {
      await c.play(1);
      backend.finish();
      await pumpEventQueue();
      expect(c.current, 2);
      expect(backend.urls.last, _url(0, 2));
    });

    test('after the last surah it stops', () async {
      await c.play(4);
      backend.finish();
      await pumpEventQueue();
      expect(c.current, isNull);
      expect(backend.stops, 1);
    });

    test('with repeat, the same surah starts again', () async {
      await c.play(2);
      c.toggleRepeat();
      backend.finish();
      await pumpEventQueue();
      expect(c.current, 2);
      expect(backend.urls.length, 1, reason: 'not downloaded again');
      expect(backend.seeks, [Duration.zero]);
      expect(c.playing, isTrue);
    });

    test('with shuffle, another surah plays', () async {
      await c.play(2);
      c.toggleShuffle();
      backend.finish();
      await pumpEventQueue();
      expect(c.current, isNot(2));
      expect(c.current, inInclusiveRange(1, 4));
    });
  });

  group('next and previous', () {
    test('next goes to the following surah, and is off on the last', () async {
      await c.play(3);
      expect(c.canNext, isTrue);
      c.next();
      await pumpEventQueue();
      expect(c.current, 4);
      expect(c.canNext, isFalse);
      c.next();
      await pumpEventQueue();
      expect(c.current, 4, reason: 'nothing after the last one');
    });

    test('with shuffle, next is always possible and never the same surah', () async {
      await c.play(4);
      c.toggleShuffle();
      expect(c.canNext, isTrue);
      for (var i = 0; i < 10; i++) {
        final before = c.current;
        c.next();
        await pumpEventQueue();
        expect(c.current, isNot(before));
      }
    });

    test('previous restarts a surah that is a few seconds in', () async {
      await c.play(3);
      backend.position(const Duration(seconds: 20));
      await pumpEventQueue();
      c.previous();
      await pumpEventQueue();
      expect(c.current, 3);
      expect(backend.seeks, [Duration.zero]);
    });

    test('previous at the start goes to the surah before', () async {
      await c.play(3);
      backend.position(const Duration(seconds: 1));
      await pumpEventQueue();
      c.previous();
      await pumpEventQueue();
      expect(c.current, 2);
    });

    test('previous on the first surah just restarts it', () async {
      await c.play(1);
      c.previous();
      await pumpEventQueue();
      expect(c.current, 1);
      expect(backend.seeks, [Duration.zero]);
    });
  });

  test('with nothing playing the controls do nothing', () async {
    c.next();
    c.previous();
    c.togglePlayPause();
    await pumpEventQueue();
    expect(c.current, isNull);
    expect(backend.urls, isEmpty);
    expect(c.canNext, isFalse);
  });
}
