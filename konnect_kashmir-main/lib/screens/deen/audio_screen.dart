import 'dart:async';
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_snack.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/error_retry.dart';
import 'audio_controller.dart';
import 'deen_data.dart';
import 'now_playing_screen.dart';

/// Quran recitation, streamed surah by surah. Tapping a surah starts it and opens
/// the full-screen player. "Islamic Audio" opens the same screen with the reciter
/// list up front.
class AudioScreen extends StatefulWidget {
  final bool chooseReciterFirst;
  final String title;

  /// Only for tests: a controller to use instead of the real player.
  final QuranAudioController? controller;
  const AudioScreen({
    super.key,
    required this.title,
    this.chooseReciterFirst = false,
    this.controller,
  });

  @override
  State<AudioScreen> createState() => _AudioScreenState();
}

class _AudioScreenState extends State<AudioScreen> {
  late final QuranAudioController _c =
      widget.controller ?? QuranAudioController(JustAudioBackend());
  StreamSubscription<void>? _errSub;

  @override
  void initState() {
    super.initState();
    _c.addListener(_changed);
    _errSub = _c.errors.listen((_) {
      if (mounted) {
        showAppSnack(context, context.l10n.deenAudioError, type: SnackType.error);
      }
    });
    _c.load();
    if (widget.chooseReciterFirst) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pickReciter();
      });
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _c.removeListener(_changed);
    _errSub?.cancel();
    if (widget.controller == null) _c.dispose();
    super.dispose();
  }

  Future<void> _pickReciter() async {
    final picked = await showReciterSheet(context, _c.reciter);
    if (picked != null && mounted) _c.setReciter(picked);
  }

  Future<void> _openPlayer() => Navigator.push(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => NowPlayingScreen(controller: _c),
        ),
      );

  /// A surah was tapped: play it (unless it is already playing) and show the player.
  void _tapSurah(int number) {
    if (_c.current != number) _c.play(number);
    _openPlayer();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final current = _c.current;
    final surahs = _c.surahs;

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
                      Text(kReciters[_c.reciter].name,
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
          child: _c.loading
              ? ListView(padding: const EdgeInsets.all(20), children: [
                  for (var i = 0; i < 7; i++) ...[
                    const Skeleton(height: 60, radius: AppRadius.md),
                    const SizedBox(height: 10),
                  ]
                ])
              : _c.loadError != null
                  ? ErrorRetry.fromError(_c.loadError, onRetry: _c.load)
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                          20, 4, 20, current != null ? 96 : 24),
                      itemCount: surahs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final s = surahs[i];
                        final active = current == s.number;
                        return AppCard(
                          onTap: () => _tapSurah(s.number),
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
                              child: active && _c.buffering
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : Icon(
                                      active && _c.playing
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
      // The small player: tap the title to open the full-screen one.
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
                  stream: _c.positionStream,
                  builder: (_, snap) {
                    final pos = snap.data ?? Duration.zero;
                    final dur = _c.duration;
                    final max = dur.inMilliseconds.toDouble();
                    return Row(children: [
                      Expanded(
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                onTap: _openPlayer,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(children: [
                                    Flexible(
                                      child: Text(_c.currentSurah?.english ?? '',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700)),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.keyboard_arrow_up_rounded,
                                        size: 20,
                                        color: cs.onSurface.withValues(alpha: 0.6)),
                                  ]),
                                ),
                              ),
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
                                      : (v) => _c.seek(
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
                        onPressed: _c.togglePlayPause,
                        icon: Icon(_c.playing
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
