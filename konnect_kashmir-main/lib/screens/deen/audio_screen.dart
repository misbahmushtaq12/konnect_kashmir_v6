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
                      // The player is a bottom bar of its own, so the list ends above it.
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
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
      // The small player. Tap it (or drag it up) to open the full-screen one.
      bottomNavigationBar: current == null
          ? null
          : MiniPlayer(controller: _c, onOpen: _openPlayer),
    );
  }
}

/// The compact player at the bottom of the audio list: the surah and reciter, a
/// round play / pause button with previous and next either side, a thin seek bar
/// across the full width, and the time on both sides of it.
class MiniPlayer extends StatelessWidget {
  final QuranAudioController controller;
  final VoidCallback onOpen;
  const MiniPlayer({super.key, required this.controller, required this.onOpen});

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final c = controller;
    final isDark = cs.brightness == Brightness.dark;
    final bg = isDark
        ? Color.alphaBlend(AppColors.primary.withValues(alpha: 0.07), AppColors.darkSurface)
        : Colors.white;
    final muted = cs.onSurface.withValues(alpha: 0.62);
    final playing = c.playing;

    return SafeArea(
      top: false,
      child: GestureDetector(
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) < -200) onOpen();
        },
        child: Container(
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          padding: const EdgeInsets.fromLTRB(14, 8, 6, 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              // Surah and reciter; a tap anywhere here opens the full player.
              Expanded(
                child: InkWell(
                  onTap: onOpen,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.currentSurah?.english ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: AppText.body,
                                    fontWeight: FontWeight.w700,
                                    color: cs.onSurface)),
                            Text(c.currentReciter.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: AppText.caption, color: muted)),
                          ],
                        ),
                      ),
                      Icon(Icons.keyboard_arrow_up_rounded, size: 22, color: muted),
                    ]),
                  ),
                ),
              ),
              IconButton(
                onPressed: c.previous,
                tooltip: l.audioPrevious,
                visualDensity: VisualDensity.compact,
                iconSize: 26,
                icon: Icon(Icons.skip_previous_rounded, color: muted),
              ),
              Semantics(
                button: true,
                label: playing ? l.audioPause : l.audioPlay,
                child: Material(
                  color: AppColors.primary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: c.togglePlayPause,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: c.buffering
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.4, color: Colors.white),
                            )
                          : Icon(
                              playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 28,
                              color: Colors.white),
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: c.canNext ? c.next : null,
                tooltip: l.audioNext,
                visualDensity: VisualDensity.compact,
                iconSize: 26,
                icon: Icon(Icons.skip_next_rounded,
                    color: c.canNext ? muted : muted.withValues(alpha: 0.35)),
              ),
            ]),
            // The seek bar: thin, teal where played, a muted green for the rest.
            StreamBuilder<Duration>(
              stream: c.positionStream,
              builder: (_, snap) {
                final pos = snap.data ?? Duration.zero;
                final dur = c.duration;
                final max = dur.inMilliseconds.toDouble();
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(children: [
                    SizedBox(
                      height: 22,
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          padding: EdgeInsets.zero,
                          trackHeight: 3,
                          activeTrackColor: AppColors.primary,
                          inactiveTrackColor:
                              AppColors.primary.withValues(alpha: 0.25),
                          thumbColor: AppColors.primary,
                          disabledThumbColor: AppColors.primary.withValues(alpha: 0.4),
                          disabledActiveTrackColor:
                              AppColors.primary.withValues(alpha: 0.4),
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 5,
                              elevation: 0,
                              pressedElevation: 0),
                          overlayShape:
                              const RoundSliderOverlayShape(overlayRadius: 12),
                        ),
                        child: Slider(
                          value: max <= 0
                              ? 0
                              : pos.inMilliseconds
                                  .clamp(0, dur.inMilliseconds)
                                  .toDouble(),
                          max: max <= 0 ? 1 : max,
                          semanticFormatterCallback: (v) =>
                              _fmt(Duration(milliseconds: v.toInt())),
                          onChanged: max <= 0
                              ? null
                              : (v) =>
                                  c.seek(Duration(milliseconds: v.toInt())),
                        ),
                      ),
                    ),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(_fmt(pos),
                          textDirection: TextDirection.ltr,
                          style: TextStyle(fontSize: 11, color: muted)),
                      Text(_fmt(dur),
                          textDirection: TextDirection.ltr,
                          style: TextStyle(fontSize: 11, color: muted)),
                    ]),
                  ]),
                );
              },
            ),
          ]),
        ),
      ),
    );
  }
}
