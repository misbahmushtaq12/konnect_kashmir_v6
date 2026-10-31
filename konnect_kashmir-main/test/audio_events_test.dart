import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/screens/deen/audio_controller.dart';
import 'package:konnect_kashmir/screens/deen/deen_data.dart';
import 'package:konnect_kashmir/screens/deen/quran_service.dart';

import 'support/fake_audio_backend.dart';

typedef _Ev = ({String type, String? reciterId, int? surah, int seconds});

const _surahs = [
  Surah(1, 'a', 'Al-Faatiha', 'The Opening', 7),
  Surah(2, 'b', 'Al-Baqara', 'The Cow', 286),
  Surah(3, 'c', 'Aal-i-Imraan', 'The Family of Imraan', 200),
];

const _base = 'https://download.quranicaudio.com/quran';
final _reciters = [
  Reciter.fromCatalog(id: 'rec-A', name: 'A', baseUrl: '$_base/a'),
  Reciter.fromCatalog(id: 'rec-B', name: 'B', baseUrl: '$_base/b'),
];

void main() {
  late FakeBackend backend;
  late List<_Ev> events;
  late QuranAudioController c;

  setUp(() {
    backend = FakeBackend();
    events = [];
    c = QuranAudioController(
      backend,
      onEvent: (type, {reciterId, surah, seconds = 0}) => events.add(
        (type: type, reciterId: reciterId, surah: surah, seconds: seconds),
      ),
    )
      ..surahs = _surahs
      ..loading = false
      ..reciters = _reciters;
  });
  tearDown(() => c.dispose());

  /// The player moves through [seconds] of the recording, half a second at a time.
  Future<void> listen(int seconds, {int from = 0}) async {
    for (var ms = from * 1000 + 500; ms <= (from + seconds) * 1000; ms += 500) {
      backend.position(Duration(milliseconds: ms));
      await pumpEventQueue();
    }
  }

  List<String> types() => [for (final e in events) e.type];

  test('starting a recitation reports play with the reciter and the surah', () async {
    await c.play(2);
    await pumpEventQueue();
    expect(events, [
      (type: 'play', reciterId: 'rec-A', surah: 2, seconds: 0),
    ]);
  });

  test('pausing reports the seconds that really played; resuming reports play again', () async {
    await c.play(1);
    await listen(7);
    c.togglePlayPause(); // pause
    await pumpEventQueue();
    expect(types(), ['play', 'pause']);
    expect(events.last.seconds, 7);
    expect(events.last.surah, 1);

    c.togglePlayPause(); // resume
    await pumpEventQueue();
    await listen(3, from: 7);
    c.togglePlayPause();
    await pumpEventQueue();
    expect(types(), ['play', 'pause', 'play', 'pause']);
    expect(events.last.seconds, 3, reason: 'only this stretch, not the total');
  });

  test('a jump in the seek bar adds no listening time', () async {
    await c.play(1);
    await listen(2);
    backend.position(const Duration(minutes: 3)); // dragged far forward
    await pumpEventQueue();
    backend.position(const Duration(minutes: 3, milliseconds: 500));
    await pumpEventQueue();
    c.togglePlayPause();
    await pumpEventQueue();
    // 2 s of playing + 0.5 s after the jump; the 3 minutes skipped do not count.
    expect(events.last.type, 'pause');
    expect(events.last.seconds, inInclusiveRange(2, 3));
  });

  test('a recitation that ends reports complete, then the next one starts', () async {
    await c.play(1);
    await listen(5);
    backend.finish();
    await pumpEventQueue();
    expect(types(), ['play', 'complete', 'play']);
    expect(events[1].surah, 1);
    expect(events[1].seconds, 5);
    expect(events[2].surah, 2);
  });

  test('repeat reports complete and a new play for the same surah', () async {
    c.toggleRepeat();
    await c.play(2);
    await listen(4);
    backend.finish();
    await pumpEventQueue();
    expect(types(), ['play', 'complete', 'play']);
    expect(events.map((e) => e.surah), [2, 2, 2]);
  });

  test('after the last surah there is a complete and then nothing', () async {
    await c.play(3);
    await listen(2);
    backend.finish();
    await pumpEventQueue();
    expect(types(), ['play', 'complete']);
  });

  test('choosing another surah while one plays reports stop for the first', () async {
    await c.play(1);
    await listen(6);
    await c.play(3);
    await pumpEventQueue();
    expect(types(), ['play', 'stop', 'play']);
    expect(events[1].surah, 1);
    expect(events[1].seconds, 6);
    expect(events[2].surah, 3);
  });

  test('another reciter: stop for the old voice, play for the new one', () async {
    await c.play(2);
    await listen(3);
    c.setReciter(1);
    await pumpEventQueue();
    expect(types(), ['play', 'stop', 'play']);
    expect(events[1].reciterId, 'rec-A');
    expect(events[2].reciterId, 'rec-B');
    expect(events[2].surah, 2);
  });

  test('leaving the screen while it plays reports stop; after a pause it does not', () async {
    // A player of its own (the shared one is disposed by the test's tear-down).
    final events1 = <_Ev>[];
    final b1 = FakeBackend();
    final c1 = QuranAudioController(
      b1,
      onEvent: (type, {reciterId, surah, seconds = 0}) => events1.add(
        (type: type, reciterId: reciterId, surah: surah, seconds: seconds),
      ),
    )
      ..surahs = _surahs
      ..loading = false;
    await c1.play(1);
    for (var ms = 500; ms <= 4000; ms += 500) {
      b1.position(Duration(milliseconds: ms));
      await pumpEventQueue();
    }
    c1.dispose();
    expect([for (final e in events1) e.type], ['play', 'stop']);
    expect(events1.last.seconds, 4);

    // A second player, paused before the screen is left.
    final events2 = <String>[];
    final b2 = FakeBackend();
    final c2 = QuranAudioController(
      b2,
      onEvent: (type, {reciterId, surah, seconds = 0}) => events2.add(type),
    )
      ..surahs = _surahs
      ..loading = false;
    await c2.play(1);
    c2.togglePlayPause();
    c2.dispose();
    expect(events2, ['play', 'pause']);
  });

  test('paused or resumed from outside (a call, headphones) is reported too', () async {
    await c.play(1);
    await listen(2);
    backend.pause(); // the system paused it
    await pumpEventQueue();
    expect(types(), ['play', 'pause']);

    backend.play(); // and something resumed it
    await pumpEventQueue();
    expect(types(), ['play', 'pause', 'play']);
  });

  test('buffering is not a play, and a failed load reports nothing', () async {
    backend.failNext = true;
    await c.play(1);
    await pumpEventQueue();
    expect(events, isEmpty);

    await c.play(1);
    backend.buffer();
    await pumpEventQueue();
    expect(types(), ['play']);
  });

  test('the built-in list reports no reciter id', () async {
    final events2 = <_Ev>[];
    final c2 = QuranAudioController(
      FakeBackend(),
      onEvent: (type, {reciterId, surah, seconds = 0}) => events2.add(
        (type: type, reciterId: reciterId, surah: surah, seconds: seconds),
      ),
    )
      ..surahs = _surahs
      ..loading = false;
    await c2.play(1);
    expect(events2.single.reciterId, isNull);
    c2.dispose();
  });
}
