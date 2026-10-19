import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_overlays.dart';
import '../../widgets/app_snack.dart';
import 'audio_controller.dart';
import 'deen_data.dart';
import 'quran_screens.dart';
import 'quran_service.dart';

/// The reciter list. Returns the index picked, or null.
Future<int?> showReciterSheet(BuildContext context, int selected) {
  return showAppSheet<int>(
    context: context,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(ctx.l10n.deenReciter,
                style: const TextStyle(
                    fontSize: AppText.title, fontWeight: FontWeight.w800)),
          ),
        ),
        for (var i = 0; i < kReciters.length; i++)
          ListTile(
            leading: Icon(
                i == selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: AppColors.primary),
            title: Text(kReciters[i].name),
            onTap: () => Navigator.pop(ctx, i),
          ),
      ]),
    ),
  );
}

String _fmt(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
}

/// The full-screen player for a recitation: the surah as a picture, its name and
/// reciter, a seek bar, and shuffle / previous / play / next / repeat. The queue
/// (the surah list) opens from the bottom.
class NowPlayingScreen extends StatefulWidget {
  final QuranAudioController controller;
  const NowPlayingScreen({super.key, required this.controller});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  StreamSubscription<void>? _errSub;
  bool _closing = false;

  QuranAudioController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _errSub = _c.errors.listen((_) {
      if (mounted) {
        showAppSnack(context, context.l10n.deenAudioError, type: SnackType.error);
      }
    });
  }

  @override
  void dispose() {
    _errSub?.cancel();
    super.dispose();
  }

  Future<void> _pickReciter() async {
    final picked = await showReciterSheet(context, _c.reciter);
    if (picked != null && mounted) _c.setReciter(picked);
  }

  void _openQueue() {
    showAppSheet<void>(
      context: context,
      builder: (ctx) => _QueueSheet(
        controller: _c,
        onPick: (n) {
          Navigator.pop(ctx);
          _c.play(n);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final s = _c.currentSurah;
        if (s == null) {
          // Nothing is playing any more (the last surah ended, or it failed).
          if (!_closing) {
            _closing = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.of(context).maybePop();
            });
          }
          return const Scaffold(body: SizedBox.expand());
        }
        return _page(s);
      },
    );
  }

  Widget _page(Surah s) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final muted = cs.onSurface.withValues(alpha: 0.62);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(builder: (context, box) {
          final side = math.max(
              180.0, math.min(box.maxWidth - 40, box.maxHeight * 0.40));
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Top bar: close, "now playing", reciter menu.
                  Row(children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
                    ),
                    Expanded(
                      child: Text(l.audioNowPlaying,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: AppText.secondary,
                              fontWeight: FontWeight.w600,
                              color: muted)),
                    ),
                    IconButton(
                      onPressed: _pickReciter,
                      tooltip: l.deenReciter,
                      icon: const Icon(Icons.more_vert_rounded),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Center(
                    child: SurahArt(
                        surah: s, reciterName: _c.currentReciter.name, side: side),
                  ),
                  const SizedBox(height: 22),
                  Text(s.english,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          color: cs.onSurface)),
                  const SizedBox(height: 4),
                  Text(_c.currentReciter.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: AppText.heading, color: muted)),
                  const SizedBox(height: 14),
                  // Chips: read along, reciter, size of the surah.
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _PillButton(
                      icon: Icons.menu_book_rounded,
                      label: l.audioRead,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => SurahReaderScreen(surah: s)),
                      ),
                    ),
                    _PillButton(
                      icon: Icons.record_voice_over_rounded,
                      label: l.deenReciter,
                      onTap: _pickReciter,
                    ),
                    _PillButton(
                      icon: Icons.format_list_numbered_rounded,
                      label: l.deenVerses(s.ayahs.toString()),
                    ),
                  ]),
                  const SizedBox(height: 18),
                  _progress(muted),
                  const SizedBox(height: 6),
                  _controls(cs),
                  const SizedBox(height: 14),
                  // The queue handle, opened by a tap or an upward drag.
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _openQueue,
                    onVerticalDragEnd: (d) {
                      if ((d.primaryVelocity ?? 0) < 0) _openQueue();
                    },
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(children: [
                        Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: cs.onSurface.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(l.audioQueue,
                            style: TextStyle(
                                fontSize: AppText.body,
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface)),
                        const SizedBox(height: 6),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _progress(Color muted) {
    return StreamBuilder<Duration>(
      stream: _c.positionStream,
      builder: (_, snap) {
        final pos = snap.data ?? Duration.zero;
        final dur = _c.duration;
        final max = dur.inMilliseconds.toDouble();
        return Column(children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: max <= 0
                  ? 0
                  : pos.inMilliseconds.clamp(0, dur.inMilliseconds).toDouble(),
              max: max <= 0 ? 1 : max,
              onChanged: max <= 0
                  ? null
                  : (v) => _c.seek(Duration(milliseconds: v.toInt())),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(_fmt(pos),
                  textDirection: TextDirection.ltr,
                  style: TextStyle(fontSize: AppText.secondary, color: muted)),
              Text(_fmt(dur),
                  textDirection: TextDirection.ltr,
                  style: TextStyle(fontSize: AppText.secondary, color: muted)),
            ]),
          ),
        ]);
      },
    );
  }

  Widget _controls(ColorScheme cs) {
    final l = context.l10n;
    final muted = cs.onSurface.withValues(alpha: 0.6);
    final playing = _c.playing;

    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      IconButton(
        onPressed: _c.toggleShuffle,
        tooltip: l.audioShuffle,
        isSelected: _c.shuffle,
        icon: Icon(Icons.shuffle_rounded,
            color: _c.shuffle ? AppColors.primary : muted),
      ),
      IconButton(
        onPressed: _c.previous,
        tooltip: l.audioPrevious,
        iconSize: 40,
        icon: Icon(Icons.skip_previous_rounded, color: cs.onSurface),
      ),
      // The big play / pause button.
      Semantics(
        button: true,
        label: playing ? l.audioPause : l.audioPlay,
        child: GestureDetector(
          onTap: _c.togglePlayPause,
          child: Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
                color: AppColors.primary, shape: BoxShape.circle),
            child: _c.buffering
                ? const Padding(
                    padding: EdgeInsets.all(22),
                    child: CircularProgressIndicator(
                        strokeWidth: 3, color: Colors.white),
                  )
                : Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 42, color: Colors.white),
          ),
        ),
      ),
      IconButton(
        onPressed: _c.canNext ? _c.next : null,
        tooltip: l.audioNext,
        iconSize: 40,
        icon: Icon(Icons.skip_next_rounded,
            color: _c.canNext ? cs.onSurface : cs.onSurface.withValues(alpha: 0.3)),
      ),
      IconButton(
        onPressed: _c.toggleRepeat,
        tooltip: l.audioRepeat,
        isSelected: _c.repeat,
        icon: Icon(_c.repeat ? Icons.repeat_one_rounded : Icons.repeat_rounded,
            color: _c.repeat ? AppColors.primary : muted),
      ),
    ]);
  }
}

class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _PillButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.onSurface.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: cs.onSurface),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: AppText.secondary,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface)),
          ]),
        ),
      ),
    );
  }
}

/// The surah list as a queue: the one playing is marked, a tap plays another.
class _QueueSheet extends StatelessWidget {
  final QuranAudioController controller;
  final ValueChanged<int> onPick;
  const _QueueSheet({required this.controller, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final surahs = controller.surahs;
    final height = MediaQuery.of(context).size.height * 0.7;
    return SizedBox(
      height: height,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text(context.l10n.audioQueue,
              style: const TextStyle(
                  fontSize: AppText.title, fontWeight: FontWeight.w800)),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
            itemCount: surahs.length,
            itemBuilder: (_, i) {
              final s = surahs[i];
              final active = controller.current == s.number;
              return ListTile(
                onTap: () => onPick(s.number),
                leading: SizedBox(
                  width: 28,
                  child: active
                      ? const Icon(Icons.equalizer_rounded, color: AppColors.primary)
                      : Center(
                          child: Text('${s.number}',
                              style: TextStyle(
                                  color: cs.onSurface.withValues(alpha: 0.6)))),
                ),
                title: Text(s.english,
                    style: TextStyle(
                        fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                        color: active ? AppColors.primary : null)),
                trailing: Text(s.arabic,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(fontSize: AppText.heading)),
              );
            },
          ),
        ),
      ]),
    );
  }
}

/// A picture for a surah, drawn in code: its name in Arabic over a green
/// Islamic pattern, with its number and the reciter. (Recitations have no cover
/// art of their own.)
class SurahArt extends StatelessWidget {
  final Surah surah;
  final String reciterName;
  final double side;
  const SurahArt({
    super.key,
    required this.surah,
    required this.reciterName,
    required this.side,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: side,
      height: side,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(fit: StackFit.expand, children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F5A4C), Color(0xFF1F7A68), Color(0xFF123F3A)],
              ),
            ),
          ),
          CustomPaint(painter: _StarPatternPainter()),
          // Number badge, top left.
          Positioned(
            top: 14,
            left: 14,
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
                color: Colors.white.withValues(alpha: 0.12),
              ),
              child: Text('${surah.number}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: AppText.body)),
            ),
          ),
          // The name in Arabic, big, in the middle.
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(surah.arabic,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 44, height: 1.5)),
              ),
            ),
          ),
          // What the name means, and who reads.
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(surah.translation,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: AppText.secondary)),
              const SizedBox(height: 2),
              Text(reciterName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: AppText.body,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// A faint lattice of eight-pointed stars.
class _StarPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.09);
    const cell = 54.0;
    const r = cell * 0.42;
    for (var y = 0.0; y < size.height + cell; y += cell) {
      for (var x = 0.0; x < size.width + cell; x += cell) {
        canvas.save();
        canvas.translate(x, y);
        for (var k = 0; k < 2; k++) {
          canvas.save();
          canvas.rotate(k * math.pi / 4);
          canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: r * 1.6, height: r * 1.6), p);
          canvas.restore();
        }
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_StarPatternPainter old) => false;
}
