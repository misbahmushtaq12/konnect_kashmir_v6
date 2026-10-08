import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_overlays.dart';
import '../../widgets/app_snack.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/error_retry.dart';
import 'deen_data.dart';
import 'quran_service.dart';

/// Quran recitation, streamed surah by surah. "Islamic Audio" opens the same
/// screen with the reciter list up front.
class AudioScreen extends StatefulWidget {
  final bool chooseReciterFirst;
  final String title;
  const AudioScreen({super.key, required this.title, this.chooseReciterFirst = false});

  @override
  State<AudioScreen> createState() => _AudioScreenState();
}

class _AudioScreenState extends State<AudioScreen> {
  final AudioPlayer _player = AudioPlayer();
  List<Surah> _surahs = [];
  bool _loading = true;
  String? _error;
  int _reciter = 0;
  int? _current; // surah number being played
  bool _buffering = false;
  StreamSubscription<PlayerState>? _stateSub;

  @override
  void initState() {
    super.initState();
    _stateSub = _player.playerStateStream.listen((st) {
      if (!mounted) return;
      final buffering = st.processingState == ProcessingState.loading ||
          st.processingState == ProcessingState.buffering;
      if (st.processingState == ProcessingState.completed) {
        _player.stop();
        setState(() {
          _current = null;
          _buffering = false;
        });
      } else if (buffering != _buffering) {
        setState(() => _buffering = buffering);
      } else {
        setState(() {}); // play / pause icon
      }
    });
    _load();
    if (widget.chooseReciterFirst) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pickReciter();
      });
    }
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await QuranService.surahs();
      if (!mounted) return;
      setState(() {
        _surahs = s;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _play(int surah) async {
    setState(() {
      _current = surah;
      _buffering = true;
    });
    try {
      await _player
          .setUrl(kReciters[_reciter].surahUrl(surah))
          .timeout(const Duration(seconds: 25));
      if (!mounted || _current != surah) return; // the user picked another one
      _player.play();
    } catch (_) {
      if (!mounted || _current != surah) return;
      setState(() {
        _current = null;
        _buffering = false;
      });
      showAppSnack(context, context.l10n.deenAudioError, type: SnackType.error);
    }
  }

  Future<void> _toggle(int surah) async {
    if (_current == surah) {
      _player.playing ? _player.pause() : _player.play();
    } else {
      await _play(surah);
    }
  }

  Future<void> _pickReciter() async {
    final picked = await showAppSheet<int>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(context.l10n.deenReciter,
                  style: const TextStyle(
                      fontSize: AppText.title, fontWeight: FontWeight.w800)),
            ),
          ),
          for (var i = 0; i < kReciters.length; i++)
            ListTile(
              leading: Icon(
                  i == _reciter
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: AppColors.primary),
              title: Text(kReciters[i].name),
              onTap: () => Navigator.pop(ctx, i),
            ),
        ]),
      ),
    );
    if (picked == null || picked == _reciter || !mounted) return;
    setState(() => _reciter = picked);
    final playing = _current;
    if (playing != null) _play(playing);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final current = _current;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: AppCard(
            onTap: _pickReciter,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              const Icon(Icons.record_voice_over_rounded,
                  color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.l10n.deenReciter,
                          style: TextStyle(
                              fontSize: AppText.caption,
                              color: cs.onSurface.withValues(alpha: 0.6))),
                      Text(kReciters[_reciter].name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: AppText.body)),
                    ]),
              ),
              Icon(Icons.expand_more_rounded,
                  color: cs.onSurface.withValues(alpha: 0.5)),
            ]),
          ),
        ),
        Expanded(
          child: _loading
              ? ListView(padding: const EdgeInsets.all(20), children: [
                  for (var i = 0; i < 7; i++) ...[
                    const Skeleton(height: 60, radius: AppRadius.md),
                    const SizedBox(height: 10),
                  ]
                ])
              : _error != null
                  ? ErrorRetry.fromError(_error, onRetry: _load)
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                          20, 4, 20, current != null ? 96 : 24),
                      itemCount: _surahs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final s = _surahs[i];
                        final active = current == s.number;
                        return AppCard(
                          onTap: () => _toggle(s.number),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          child: Row(children: [
                            Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: active && _buffering
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : Icon(
                                      active && _player.playing
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      color: AppColors.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text('${s.number}. ${s.english}',
                                  style: TextStyle(
                                      fontWeight: active
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      fontSize: AppText.body)),
                            ),
                            Text(s.arabic,
                                textDirection: TextDirection.rtl,
                                style: const TextStyle(
                                    fontSize: AppText.heading,
                                    fontWeight: FontWeight.w600)),
                          ]),
                        );
                      },
                    ),
        ),
      ]),
      bottomNavigationBar: current == null
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
                decoration: BoxDecoration(
                  color: AppColors.solid(cs),
                  border: Border(
                      top: BorderSide(color: cs.onSurface.withValues(alpha: 0.1))),
                ),
                child: StreamBuilder<Duration>(
                  stream: _player.positionStream,
                  builder: (_, snap) {
                    final pos = snap.data ?? Duration.zero;
                    final dur = _player.duration ?? Duration.zero;
                    final max = dur.inMilliseconds.toDouble();
                    return Row(children: [
                      Expanded(
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  _surahs.isEmpty
                                      ? ''
                                      : _surahs[current - 1].english,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                    trackHeight: 3,
                                    thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 6)),
                                child: Slider(
                                  value: max <= 0
                                      ? 0
                                      : pos.inMilliseconds
                                          .clamp(0, dur.inMilliseconds)
                                          .toDouble(),
                                  max: max <= 0 ? 1 : max,
                                  onChanged: max <= 0
                                      ? null
                                      : (v) => _player.seek(
                                          Duration(milliseconds: v.toInt())),
                                ),
                              ),
                              Text('${_fmt(pos)} / ${_fmt(dur)}',
                                  style: TextStyle(
                                      fontSize: AppText.caption,
                                      color:
                                          cs.onSurface.withValues(alpha: 0.6))),
                            ]),
                      ),
                      IconButton(
                        iconSize: 34,
                        color: AppColors.primary,
                        onPressed: () => _toggle(current),
                        icon: Icon(_player.playing
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_fill_rounded),
                      ),
                    ]);
                  },
                ),
              ),
            ),
    );
  }
}
