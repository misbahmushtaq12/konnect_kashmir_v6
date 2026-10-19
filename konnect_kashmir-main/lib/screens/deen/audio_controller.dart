import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'deen_data.dart';
import 'quran_service.dart';

/// What the screens need to know about the audio player.
class AudioPlayerState {
  final bool playing;
  final bool buffering;
  final bool completed;
  const AudioPlayerState({
    required this.playing,
    required this.buffering,
    required this.completed,
  });
}

/// The audio player behind [QuranAudioController]. A small interface, so the
/// controller can be tested without a phone's audio system.
abstract class AudioBackend {
  Stream<AudioPlayerState> get stateStream;
  Stream<Duration> get positionStream;
  Duration? get duration;
  bool get playing;
  Future<void> setUrl(String url);
  void play();
  void pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> dispose();
}

/// The real player (just_audio).
class JustAudioBackend implements AudioBackend {
  final AudioPlayer _p = AudioPlayer();

  @override
  Stream<AudioPlayerState> get stateStream => _p.playerStateStream.map((st) =>
      AudioPlayerState(
        playing: st.playing,
        buffering: st.processingState == ProcessingState.loading ||
            st.processingState == ProcessingState.buffering,
        completed: st.processingState == ProcessingState.completed,
      ));

  @override
  Stream<Duration> get positionStream => _p.positionStream;

  @override
  Duration? get duration => _p.duration;

  @override
  bool get playing => _p.playing;

  @override
  Future<void> setUrl(String url) async {
    await _p.setUrl(url);
  }

  // just_audio's play() only finishes when playback stops, so it is not awaited.
  @override
  void play() => unawaited(_p.play());

  @override
  void pause() => unawaited(_p.pause());

  @override
  Future<void> stop() => _p.stop();

  @override
  Future<void> seek(Duration position) => _p.seek(position);

  @override
  Future<void> dispose() => _p.dispose();
}

/// Quran recitation playback shared by the audio list and the full-screen player:
/// the surah being played, the reciter, shuffle and repeat. When a surah ends the
/// next one plays (a random one with shuffle, the same one with repeat); after the
/// last surah playback stops.
class QuranAudioController extends ChangeNotifier {
  QuranAudioController(this._backend, {math.Random? random})
      : _random = random ?? math.Random() {
    _stateSub = _backend.stateStream.listen(_onState);
    _positionSub = _backend.positionStream.listen((p) => _position = p);
  }

  final AudioBackend _backend;
  final math.Random _random;
  StreamSubscription<AudioPlayerState>? _stateSub;
  StreamSubscription<Duration>? _positionSub;
  final StreamController<void> _errors = StreamController<void>.broadcast();
  Duration _position = Duration.zero;
  bool _disposed = false;

  List<Surah> surahs = const [];
  bool loading = true;
  String? loadError;

  /// Index into [kReciters].
  int reciter = 0;

  /// The surah number being played, or null when nothing is.
  int? current;
  bool buffering = false;
  bool shuffle = false;
  bool repeat = false;

  /// Fires when a recording could not be played.
  Stream<void> get errors => _errors.stream;
  Stream<Duration> get positionStream => _backend.positionStream;
  Duration get duration => _backend.duration ?? Duration.zero;
  bool get playing => _backend.playing;

  Reciter get currentReciter => kReciters[reciter];

  Surah? get currentSurah {
    final n = current;
    if (n == null) return null;
    for (final s in surahs) {
      if (s.number == n) return s;
    }
    return null;
  }

  bool get canNext {
    final n = current;
    if (n == null || surahs.isEmpty) return false;
    return shuffle ? surahs.length > 1 : n < surahs.length;
  }

  Future<void> load() async {
    loading = true;
    loadError = null;
    _notify();
    try {
      surahs = await QuranService.surahs();
      loading = false;
    } catch (e) {
      loadError = e.toString();
      loading = false;
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _onState(AudioPlayerState st) {
    if (st.completed) {
      _onCompleted();
      return;
    }
    buffering = st.buffering;
    _notify(); // play / pause icon
  }

  Future<void> _onCompleted() async {
    final cur = current;
    if (cur == null) return;
    if (repeat) {
      await _backend.seek(Duration.zero);
      _backend.play();
      return;
    }
    final next = _nextSurah(cur);
    if (next != null) {
      await play(next);
    } else {
      await _backend.stop();
      current = null;
      buffering = false;
      _notify();
    }
  }

  int? _nextSurah(int cur) {
    if (surahs.isEmpty) return null;
    if (shuffle) {
      if (surahs.length < 2) return null;
      final others = [
        for (final s in surahs)
          if (s.number != cur) s.number
      ];
      return others[_random.nextInt(others.length)];
    }
    return cur < surahs.length ? cur + 1 : null;
  }

  Future<void> play(int surah) async {
    current = surah;
    buffering = true;
    _notify();
    try {
      await _backend
          .setUrl(kReciters[reciter].surahUrl(surah))
          .timeout(const Duration(seconds: 25));
      if (_disposed || current != surah) return; // the user picked another one
      _backend.play();
    } catch (_) {
      if (_disposed || current != surah) return;
      current = null;
      buffering = false;
      _notify();
      _errors.add(null);
    }
  }

  /// Play [surah], or pause / resume it if it is the one playing.
  Future<void> toggle(int surah) async {
    if (current == surah) {
      togglePlayPause();
    } else {
      await play(surah);
    }
  }

  void togglePlayPause() {
    if (current == null) return;
    playing ? _backend.pause() : _backend.play();
  }

  void next() {
    final cur = current;
    if (cur == null) return;
    final n = _nextSurah(cur);
    if (n != null) play(n);
  }

  /// Like most players: a few seconds in, "previous" goes back to the start of
  /// this surah; at the start it goes to the surah before.
  void previous() {
    final cur = current;
    if (cur == null) return;
    if (_position > const Duration(seconds: 3) || cur <= 1) {
      _backend.seek(Duration.zero);
    } else {
      play(cur - 1);
    }
  }

  Future<void> seek(Duration position) => _backend.seek(position);

  void toggleShuffle() {
    shuffle = !shuffle;
    _notify();
  }

  void toggleRepeat() {
    repeat = !repeat;
    _notify();
  }

  /// Another reciter: the surah being played carries on with the new voice.
  void setReciter(int index) {
    if (index == reciter) return;
    reciter = index;
    _notify();
    final cur = current;
    if (cur != null) play(cur);
  }

  @override
  void dispose() {
    _disposed = true;
    _stateSub?.cancel();
    _positionSub?.cancel();
    _errors.close();
    _backend.dispose();
    super.dispose();
  }
}
