import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../services/deen_events.dart';
import 'deen_data.dart';
import 'quran_service.dart';
import 'reciters_source.dart';

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

/// Reports what happens while a recitation plays: `play`, `pause`, `stop` or
/// `complete`, the reciter's database id (null for the built-in list), the surah,
/// and the seconds actually listened since the last report.
typedef AudioEventSink = void Function(
  String type, {
  String? reciterId,
  int? surah,
  int seconds,
});

void _recordAudioEvent(
  String type, {
  String? reciterId,
  int? surah,
  int seconds = 0,
}) =>
    DeenEvents.instance
        .audio(type, reciterId: reciterId, surah: surah, seconds: seconds);

/// Quran recitation playback shared by the audio list and the full-screen player:
/// the surah being played, the reciter, shuffle and repeat. When a surah ends the
/// next one plays (a random one with shuffle, the same one with repeat); after the
/// last surah playback stops.
///
/// The reciters come from the database ([recitersSource]; the same list as the
/// website) and are the built-in [kReciters] until that answers or when it cannot.
class QuranAudioController extends ChangeNotifier {
  QuranAudioController(
    this._backend, {
    math.Random? random,
    RecitersSource? recitersSource,
    AudioEventSink? onEvent,
  })  : _random = random ?? math.Random(),
        _recitersSource = recitersSource,
        _onEvent = onEvent ?? _recordAudioEvent {
    _stateSub = _backend.stateStream.listen(_onState);
    _positionSub = _backend.positionStream.listen(_positionTick);
  }

  final AudioBackend _backend;
  final RecitersSource? _recitersSource;
  final AudioEventSink _onEvent;
  final math.Random _random;
  StreamSubscription<AudioPlayerState>? _stateSub;
  StreamSubscription<Duration>? _positionSub;
  final StreamController<void> _errors = StreamController<void>.broadcast();
  Duration _position = Duration.zero;
  bool _disposed = false;

  List<Surah> surahs = const [];
  bool loading = true;
  String? loadError;

  /// The reciters to choose from, in order (the database list once it is known).
  List<Reciter> reciters = kReciters;

  /// Index into [reciters].
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

  Reciter get currentReciter => reciters[reciter];

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
    unawaited(_loadReciters());
  }

  /// The saved list first (so it is there at once), then the server's. Anything
  /// that goes wrong leaves the list as it is.
  Future<void> _loadReciters() async {
    final source = _recitersSource;
    if (source == null) return;
    try {
      final saved = await source.cached();
      if (saved != null) _useReciters(saved);
      final fresh = await source.fetch();
      if (fresh != null) _useReciters(fresh);
    } catch (_) {}
  }

  /// Switches to [list], keeping the chosen reciter (by name) when it is in it.
  void _useReciters(List<Reciter> list) {
    if (_disposed || list.isEmpty) return;
    final name = currentReciter.name;
    final same = list.length == reciters.length &&
        [for (var i = 0; i < list.length; i++)
          list[i].name == reciters[i].name &&
              list[i].id == reciters[i].id &&
              list[i].surahUrl(1) == reciters[i].surahUrl(1)].every((e) => e);
    if (same) return;
    reciters = list;
    final i = list.indexWhere((r) => r.name == name);
    reciter = i >= 0 ? i : 0;
    _notify();
  }

  // ── What is reported to the database ──────────────────────────────────────
  // One "stretch" of listening runs from a play (or resume) to the next pause,
  // stop or the end. Its seconds are only the time that really played: a jump
  // forward or back in the seek bar adds nothing.

  bool _listening = false;
  double _heard = 0;
  Duration _lastPosition = Duration.zero;
  String? _heardReciterId;
  int? _heardSurah;

  void _positionTick(Duration p) {
    if (_listening && _backend.playing) {
      final ms = (p - _lastPosition).inMilliseconds;
      if (ms > 0 && ms < 2000) _heard += ms / 1000;
    }
    _lastPosition = p;
    _position = p;
  }

  void _beginListening() {
    final surah = current;
    if (_listening || surah == null) return;
    _listening = true;
    _heard = 0;
    _lastPosition = _position;
    _heardReciterId = currentReciter.id;
    _heardSurah = surah;
    _onEvent('play', reciterId: _heardReciterId, surah: _heardSurah);
  }

  void _endListening(String type) {
    if (!_listening) return;
    _listening = false;
    final seconds = _heard.round().clamp(0, 86400);
    _heard = 0;
    _onEvent(type,
        reciterId: _heardReciterId, surah: _heardSurah, seconds: seconds);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _onState(AudioPlayerState st) {
    if (st.completed) {
      _onCompleted();
      return;
    }
    // Paused or resumed from outside the app (a call, headphones taken out).
    if (_listening && !st.playing) {
      _endListening('pause');
    } else if (!_listening && st.playing && !st.buffering && current != null) {
      _beginListening();
    }
    buffering = st.buffering;
    _notify(); // play / pause icon
  }

  Future<void> _onCompleted() async {
    final cur = current;
    if (cur == null) return;
    _endListening('complete');
    if (repeat) {
      await _backend.seek(Duration.zero);
      _backend.play();
      _beginListening();
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
    _endListening('stop'); // the one that was playing is left
    current = surah;
    buffering = true;
    _notify();
    try {
      await _backend
          .setUrl(currentReciter.surahUrl(surah))
          .timeout(const Duration(seconds: 25));
      if (_disposed || current != surah) return; // the user picked another one
      _backend.play();
      _beginListening();
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
    if (playing) {
      _backend.pause();
      _endListening('pause');
    } else {
      _backend.play();
      _beginListening();
    }
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
    _endListening('stop'); // the screen is left while it is playing
    _disposed = true;
    _stateSub?.cancel();
    _positionSub?.cancel();
    _errors.close();
    _backend.dispose();
    super.dispose();
  }
}
