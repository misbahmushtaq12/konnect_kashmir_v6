import 'dart:async';

import 'package:konnect_kashmir/screens/deen/audio_controller.dart';

/// A stand-in for the phone's audio player.
class FakeBackend implements AudioBackend {
  final _state = StreamController<AudioPlayerState>.broadcast();
  final _pos = StreamController<Duration>.broadcast();
  final urls = <String>[];
  final seeks = <Duration>[];
  int stops = 0;
  bool _playing = false;
  bool failNext = false;
  Duration? length = const Duration(minutes: 5);

  void _emit({bool completed = false, bool buffering = false}) => _state.add(
      AudioPlayerState(playing: _playing, buffering: buffering, completed: completed));

  /// The recording reached its end.
  void finish() {
    _playing = false;
    _emit(completed: true);
  }

  void position(Duration d) => _pos.add(d);

  @override
  Stream<AudioPlayerState> get stateStream => _state.stream;
  @override
  Stream<Duration> get positionStream => _pos.stream;
  @override
  Duration? get duration => length;
  @override
  bool get playing => _playing;
  @override
  Future<void> setUrl(String url) async {
    if (failNext) {
      failNext = false;
      throw Exception('no network');
    }
    urls.add(url);
  }

  @override
  void play() {
    _playing = true;
    _emit();
  }

  @override
  void pause() {
    _playing = false;
    _emit();
  }

  @override
  Future<void> stop() async {
    _playing = false;
    stops++;
    _emit();
  }

  @override
  Future<void> seek(Duration position) async => seeks.add(position);
  @override
  Future<void> dispose() async {}
}
