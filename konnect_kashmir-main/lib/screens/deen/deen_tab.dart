import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../l10n/l10n.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_chip.dart';
import '../../widgets/app_overlays.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/error_retry.dart';
import 'audio_screen.dart';
import 'duas_screen.dart';
import 'prayer_service.dart';
import 'quran_screens.dart';
import 'quran_service.dart';

/// Deen: prayer times, Qibla, Quran, audio and duas.
class DeenTab extends StatefulWidget {
  /// False while another bottom-nav tab is showing (the compass is switched off
  /// then to save battery).
  final bool isActive;
  const DeenTab({super.key, this.isActive = true});

  @override
  State<DeenTab> createState() => _DeenTabState();
}

class _DeenTabState extends State<DeenTab> {
  Position? _pos;
  String? _place;
  PrayerDay? _day;
  PrayerSettings _settings = const PrayerSettings();
  int _timesReq = 0; // ignores answers to older settings
  double? _qibla;
  LocationProblem? _problem;
  String? _error;
  bool _loading = true;

  StreamSubscription<CompassEvent>? _compassSub;
  // Updated many times a second; only the compass listens, not the whole page.
  final ValueNotifier<double?> _heading = ValueNotifier<double?>(null);
  bool _compassMissing = false;

  Timer? _clock;
  DateTime _now = DateTime.now();

  ({int surah, int ayah})? _last;
  Surah? _lastSurah;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && widget.isActive) setState(() => _now = DateTime.now());
    });
    _loadLastRead();
    _bootstrap();
    if (widget.isActive) _startCompass();
  }

  @override
  void didUpdateWidget(DeenTab old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      _now = DateTime.now();
      _startCompass();
      _loadLastRead();
    } else if (!widget.isActive && old.isActive) {
      _stopCompass();
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    _stopCompass();
    _heading.dispose();
    super.dispose();
  }

  // ── Location, prayer times, Qibla ──────────────────────────────────────────

  Future<void> _bootstrap({bool ask = true}) async {
    setState(() {
      _loading = _day == null;
      _problem = null;
      _error = null;
    });
    try {
      _settings = await PrayerSettings.load();
      final pos = await PrayerService.position(ask: ask);
      if (!mounted) return;
      setState(() {
        _pos = pos;
        _qibla = qiblaBearing(pos.latitude, pos.longitude);
      });

      // Place name never holds up the prayer times.
      PrayerService.placeName(pos.latitude, pos.longitude).then((n) {
        if (mounted && n != null) setState(() => _place = n);
      });

      // Today's saved times first, so the screen is useful immediately.
      final cached = await PrayerService.cached(pos.latitude, pos.longitude, _settings);
      if (cached != null && mounted) {
        setState(() {
          _day = cached;
          _loading = false;
        });
      }
      final fresh = await PrayerService.fetch(pos.latitude, pos.longitude, _settings);
      if (!mounted) return;
      setState(() {
        _day = fresh;
        _loading = false;
      });
    } on LocationException catch (e) {
      if (!mounted) return;
      setState(() {
        _problem = e.problem;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // If we already show saved times, keep them and stay quiet.
        if (_day == null) _error = e.toString();
        _loading = false;
      });
    }
  }

  // ── Compass ────────────────────────────────────────────────────────────────

  void _startCompass() {
    if (_compassSub != null) return;
    final stream = FlutterCompass.events;
    if (stream == null) {
      setState(() => _compassMissing = true);
      return;
    }
    _compassSub = stream.listen((e) {
      final h = e.heading;
      if (h == null || !mounted) return;
      final heading = (h + 360) % 360;
      final prev = _heading.value;
      if (prev == null) {
        _heading.value = heading;
      } else {
        // Smooth out sensor jitter (turn the short way round the circle).
        var d = heading - prev;
        if (d > 180) d -= 360;
        if (d < -180) d += 360;
        _heading.value = (prev + d * 0.3 + 360) % 360;
      }
    }, onError: (_) {
      if (mounted) setState(() => _compassMissing = true);
    });
  }

  void _stopCompass() {
    _compassSub?.cancel();
    _compassSub = null;
  }

  // ── Continue reading ───────────────────────────────────────────────────────

  Future<void> _loadLastRead() async {
    final last = await QuranService.lastRead();
    Surah? surah;
    if (last != null) {
      try {
        final all = await QuranService.surahs();
        surah = all.firstWhere((s) => s.number == last.surah);
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _last = last;
      _lastSurah = surah;
    });
  }

  Future<void> _push(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) _loadLastRead();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  DateTime _at(String hm, {int addDays = 0}) {
    final p = hm.split(':');
    final n = _now;
    return DateTime(n.year, n.month, n.day + addDays, int.tryParse(p[0]) ?? 0,
        int.tryParse(p[1]) ?? 0);
  }

  String _12h(String hm) {
    final t = _at(hm);
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  /// Index (0..4) of the next prayer and when it starts.
  ({int index, DateTime at}) _next(PrayerDay d) {
    final times = d.times;
    for (var i = 0; i < times.length; i++) {
      final t = _at(times[i]);
      if (t.isAfter(_now)) return (index: i, at: t);
    }
    return (index: 0, at: _at(times[0], addDays: 1)); // tomorrow's Fajr
  }

  String _until(DateTime at) {
    final m = at.difference(_now).inMinutes;
    final h = m ~/ 60;
    final mm = m % 60;
    return h > 0 ? '${h}h ${mm}m' : '${mm}m';
  }

  // -- UI ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final hPad = size.width > 600 ? size.width * 0.10 : 20.0;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => _bootstrap(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics()),
              padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 28),
              children: [
                _header(),
                const SizedBox(height: 16),
                // Side by side on wide screens, stacked on phones.
                LayoutBuilder(builder: (context, box) {
                  final prayer = _prayerCard();
                  final qibla = _qiblaCard();
                  if (box.maxWidth >= 640 && _qibla != null) {
                    return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: prayer),
                          const SizedBox(width: 14),
                          Expanded(flex: 4, child: qibla),
                        ]);
                  }
                  return Column(children: [
                    prayer,
                    if (_qibla != null) ...[const SizedBox(height: 14), qibla],
                  ]);
                }),
                const SizedBox(height: 14),
                _tiles(),
                const SizedBox(height: 14),
                _continueCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// "DEEN" + a greeting, over a very faint mosque silhouette.
  Widget _header() {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    return Stack(children: [
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            painter: _MosqueArtPainter(AppColors.primary.withValues(alpha: 0.08)),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.navDeen.toUpperCase(),
              style: const TextStyle(
                  fontSize: AppText.titleLg,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6)),
          const SizedBox(height: 4),
          Text(l.deenGreeting,
              style: TextStyle(
                  fontSize: AppText.body,
                  color: cs.onSurface.withValues(alpha: 0.65))),
        ]),
      ),
    ]);
  }

  // ââ Prayer settings ââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

  /// Saves the new choice and recalculates the times on screen right away.
  Future<void> _applySettings(PrayerSettings next) async {
    setState(() => _settings = next);
    next.save();
    final pos = _pos;
    if (pos == null) return;
    final req = ++_timesReq;
    final cached = await PrayerService.cached(pos.latitude, pos.longitude, next);
    if (cached != null && mounted && req == _timesReq) {
      setState(() => _day = cached);
    }
    try {
      final fresh = await PrayerService.fetch(pos.latitude, pos.longitude, next);
      if (mounted && req == _timesReq) setState(() => _day = fresh);
    } catch (_) {
      // Keep showing the previous times if this request fails.
    }
  }

  void _openPrayerSettings() {
    showAppSheet<void>(
      context: context,
      builder: (ctx) => _PrayerSettingsSheet(
        initial: _settings,
        onChanged: _applySettings,
      ),
    );
  }

  static const List<IconData> _prayerIcons = [
    Icons.wb_twilight_rounded, // Fajr
    Icons.wb_sunny_rounded, // Dhuhr
    Icons.brightness_medium_rounded, // Asr
    Icons.nights_stay_rounded, // Maghrib
    Icons.dark_mode_rounded, // Isha
  ];

  Widget _prayerCard() {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toString();

    if (_loading) {
      return AppCard(
        padding: const EdgeInsets.all(18),
        child: Column(children: [
          const Skeleton(height: 18, radius: 6),
          const SizedBox(height: 10),
          const Skeleton(height: 14, width: 160, radius: 6),
          const SizedBox(height: 16),
          const Skeleton(height: 64, radius: AppRadius.md),
          const SizedBox(height: 10),
          for (var i = 0; i < 5; i++) ...[
            const Skeleton(height: 38, radius: AppRadius.sm),
            const SizedBox(height: 8),
          ],
        ]),
      );
    }

    if (_problem != null) return _locationProblemCard();
    if (_error != null && _day == null) {
      return ErrorRetry.fromError(_error, onRetry: _bootstrap);
    }
    final day = _day;
    if (day == null) return const SizedBox.shrink();

    final next = _next(day);
    final names = [
      l.prayerFajr,
      l.prayerDhuhr,
      l.prayerAsr,
      l.prayerMaghrib,
      l.prayerIsha
    ];
    final date = DateFormat.yMMMMEEEEd(locale).format(_now);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        color: cs.surface,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.13),
            AppColors.primary.withValues(alpha: 0.03),
          ],
        ),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(l.deenPrayerTimes,
                style: const TextStyle(
                    fontSize: AppText.heading, fontWeight: FontWeight.w800)),
          ),
          InkWell(
            onTap: _openPrayerSettings,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.tune_rounded,
                  size: 20, color: cs.onSurface.withValues(alpha: 0.6)),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.location_on_outlined,
              size: 18, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _place ??
                  (_pos == null
                      ? l.deenLocating
                      : '${_pos!.latitude.toStringAsFixed(2)}, ${_pos!.longitude.toStringAsFixed(2)}'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ]),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 24),
          child: Text(
            day.hijri.isEmpty ? date : '$date  ·  ${day.hijri}',
            style: TextStyle(
                fontSize: AppText.secondary,
                color: cs.onSurface.withValues(alpha: 0.7)),
          ),
        ),
        const SizedBox(height: 14),
        // The next prayer, front and centre.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(children: [
            Icon(_prayerIcons[next.index], color: AppColors.primary, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Text(l.deenNextPrayer(names[next.index], _until(next.at)),
                  style: const TextStyle(
                      fontSize: AppText.body, fontWeight: FontWeight.w700)),
            ),
            Text(_12h(day.times[next.index]),
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                    fontSize: AppText.heading,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary)),
          ]),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < 5; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: i == next.index
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : cs.onSurface.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(children: [
              Icon(_prayerIcons[i],
                  size: 20,
                  color: i == next.index
                      ? AppColors.primary
                      : cs.onSurface.withValues(alpha: 0.55)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(names[i],
                    style: TextStyle(
                        fontSize: AppText.body,
                        fontWeight:
                            i == next.index ? FontWeight.w800 : FontWeight.w600)),
              ),
              Text(_12h(day.times[i]),
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                      fontSize: AppText.body,
                      fontWeight: FontWeight.w700,
                      color: i == next.index ? AppColors.primary : null)),
            ]),
          ),
      ]),
    );
  }

  Widget _locationProblemCard() {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final (msg, label, action) = switch (_problem!) {
      LocationProblem.servicesOff => (
          l.deenLocationOff,
          l.deenOpenSettings,
          () => Geolocator.openLocationSettings()
        ),
      LocationProblem.denied => (
          l.deenLocationDenied,
          l.deenAllowLocation,
          () => _bootstrap()
        ),
      LocationProblem.deniedForever => (
          l.deenLocationBlocked,
          l.deenOpenSettings,
          () => Geolocator.openAppSettings()
        ),
    };
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        Icon(Icons.location_off_outlined,
            size: 40, color: cs.onSurface.withValues(alpha: 0.45)),
        const SizedBox(height: 12),
        Text(msg, textAlign: TextAlign.center),
        const SizedBox(height: 14),
        ElevatedButton(
          onPressed: action,
          style: AppButtons.compact(AppButtons.primary),
          child: Text(label),
        ),
      ]),
    );
  }

  Widget _qiblaCard() {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final qibla = _qibla;
    if (qibla == null) return const SizedBox.shrink();

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(l.deenQibla,
              style: const TextStyle(
                  fontSize: AppText.heading, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(l.deenQiblaAngle(qibla.toStringAsFixed(1)),
              style: TextStyle(
                  fontSize: AppText.secondary,
                  color: cs.onSurface.withValues(alpha: 0.7))),
        ),
        const SizedBox(height: 14),
        // Only this part rebuilds as the compass turns.
        ValueListenableBuilder<double?>(
          valueListenable: _heading,
          builder: (context, heading, _) {
            final turn = heading == null ? 0.0 : qiblaTurn(qibla, heading);
            final aligned = heading != null && turn.abs() < 5;
            return Column(children: [
              SizedBox(
                width: 210,
                height: 210,
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _CompassPainter(
                      heading: heading ?? 0,
                      qibla: qibla,
                      aligned: aligned,
                      ink: cs.onSurface,
                      accent: AppColors.primary,
                      good: AppColors.success,
                      north: AppColors.danger,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_compassMissing)
                Text(l.deenCompassMissing,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: AppText.secondary,
                        color: cs.onSurface.withValues(alpha: 0.65)))
              else ...[
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: aligned
                      ? AppChip(l.deenQiblaAligned,
                          key: const ValueKey('ok'),
                          icon: Icons.check_circle_rounded,
                          tone: ChipTone.success)
                      : AppChip(l.deenQiblaTurnTo,
                          key: const ValueKey('turn'),
                          icon: Icons.explore_outlined,
                          tone: ChipTone.primary),
                ),
                const SizedBox(height: 8),
                Text(l.deenQiblaHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: AppText.caption,
                        color: cs.onSurface.withValues(alpha: 0.6))),
              ],
            ]);
          },
        ),
      ]),
    );
  }

  Widget _tiles() {
    final l = context.l10n;
    Widget tile(IconData icon, String label, VoidCallback onTap) => Expanded(
          child: _PressCard(
            onTap: onTap,
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: AppText.body)),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.35)),
            ]),
          ),
        );

    return Column(children: [
      Row(children: [
        tile(Icons.menu_book_rounded, l.deenQuran,
            () => _push(const SurahListScreen())),
        const SizedBox(width: 12),
        tile(Icons.headphones_rounded, l.deenAudio,
            () => _push(AudioScreen(title: l.deenAudio))),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        tile(Icons.volunteer_activism_rounded, l.deenDuas,
            () => _push(const DuasScreen())),
        const SizedBox(width: 12),
        tile(
            Icons.library_music_rounded,
            l.deenIslamicAudio,
            () => _push(AudioScreen(
                title: l.deenIslamicAudio, chooseReciterFirst: true))),
      ]),
    ]);
  }

  Widget _continueCard() {
    final l = context.l10n;
    final last = _last;
    final surah = _lastSurah;
    final resume = last != null && surah != null;

    final VoidCallback open = resume
        ? () => _push(SurahReaderScreen(surah: surah, startAyah: last.ayah))
        : () => _push(const SurahListScreen());

    return _PressCard(
      onTap: open,
      padding: EdgeInsets.zero,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.primary, AppColors.primaryDark],
      ),
      child: Stack(children: [
        // A faint book, drawn with an icon (no image to load).
        Positioned(
          right: -6,
          bottom: -18,
          child: Icon(Icons.menu_book_rounded,
              size: 120, color: Colors.white.withValues(alpha: 0.10)),
        ),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.deenContinueReading,
                        style: TextStyle(
                            fontSize: AppText.secondary,
                            color: Colors.white.withValues(alpha: 0.85))),
                    const SizedBox(height: 4),
                    Text(resume ? surah.english : l.deenStartReading,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                    if (resume) ...[
                      const SizedBox(height: 2),
                      Text(l.deenVerseN(last.ayah.toString()),
                          style: TextStyle(
                              fontSize: AppText.secondary,
                              color: Colors.white.withValues(alpha: 0.85))),
                    ],
                  ]),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(l.deenContinue,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_rounded,
                    size: 16, color: Colors.white),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// A card that gives a small press animation when tapped.
class _PressCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  const _PressCard({
    required this.child,
    required this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.gradient,
  });

  @override
  State<_PressCard> createState() => _PressCardState();
}

class _PressCardState extends State<_PressCard> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppRadius.lg);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: Container(
          padding: widget.padding,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: radius,
            color: widget.gradient == null ? cs.surface : null,
            gradient: widget.gradient,
            border: widget.gradient == null
                ? Border.all(color: cs.onSurface.withValues(alpha: 0.08))
                : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// A very faint mosque skyline for the header, drawn in code.
class _MosqueArtPainter extends CustomPainter {
  final Color color;
  _MosqueArtPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    final w = size.width;
    final h = size.height;
    final base = h + 4;

    // Main dome and hall.
    final cx = w - 62;
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, base - 16), radius: 24),
        math.pi, math.pi, true, p);
    canvas.drawRect(Rect.fromLTRB(cx - 34, base - 16, cx + 34, base), p);
    // Minarets with pointed tops.
    for (final x in [cx - 52, cx + 52]) {
      canvas.drawRect(Rect.fromLTRB(x - 4, base - 46, x + 4, base), p);
      final tip = Path()
        ..moveTo(x - 5, base - 46)
        ..lineTo(x, base - 58)
        ..lineTo(x + 5, base - 46)
        ..close();
      canvas.drawPath(tip, p);
    }
    // Finial on the dome.
    canvas.drawRect(Rect.fromLTRB(cx - 1, base - 46, cx + 1, base - 38), p);
  }

  @override
  bool shouldRepaint(_MosqueArtPainter old) => old.color != color;
}

/// The Qibla compass: the dial (N/E/S/W) turns with the phone's heading, and
/// the Qibla marker and needle sit at (qibla - heading) from the top.
class _CompassPainter extends CustomPainter {
  final double heading;
  final double qibla;
  final bool aligned;
  final Color ink;
  final Color accent;
  final Color good;
  final Color north;

  _CompassPainter({
    required this.heading,
    required this.qibla,
    required this.aligned,
    required this.ink,
    required this.accent,
    required this.good,
    required this.north,
  });

  static double _rad(double deg) => deg * math.pi / 180;

  void _label(Canvas c, String text, Offset at, Color color) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              color: color, fontSize: 14, fontWeight: FontWeight.w800)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2 - 3;
    final arrowColor = aligned ? good : accent;

    // Face and ring.
    canvas.drawCircle(center, r, Paint()..color = ink.withValues(alpha: 0.04));
    canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = aligned ? 3 : 2
          ..color = aligned ? good : ink.withValues(alpha: 0.2));

    canvas.save();
    canvas.translate(center.dx, center.dy);

    // Dial: ticks and cardinal letters turn against the heading, so N points
    // to the real north.
    canvas.save();
    canvas.rotate(-_rad(heading));
    final tick = Paint()
      ..strokeWidth = 1.4
      ..color = ink.withValues(alpha: 0.3);
    for (var i = 0; i < 72; i++) {
      final long = i % 6 == 0;
      canvas.save();
      canvas.rotate(_rad(i * 5.0));
      canvas.drawLine(
          Offset(0, -r + 4), Offset(0, -r + (long ? 14 : 8)), tick);
      canvas.restore();
    }
    const cardinals = ['N', 'E', 'S', 'W'];
    for (var i = 0; i < 4; i++) {
      final a = _rad(i * 90.0);
      canvas.save();
      canvas.rotate(a);
      canvas.translate(0, -(r - 30));
      canvas.rotate(-a + _rad(heading)); // keep the letter upright
      _label(canvas, cardinals[i], Offset.zero, i == 0 ? north : ink.withValues(alpha: 0.75));
      canvas.restore();
    }
    canvas.restore();

    // Qibla: marker on the rim and the needle pointing to it.
    canvas.save();
    canvas.rotate(_rad(qibla - heading));

    final needle = Path()
      ..moveTo(0, -(r - 50))
      ..lineTo(9, 0)
      ..lineTo(0, 10)
      ..lineTo(-9, 0)
      ..close();
    canvas.drawPath(needle, Paint()..color = arrowColor);

    // Kaaba marker.
    canvas.translate(0, -(r - 17));
    final box = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-9, -9, 18, 18), const Radius.circular(3));
    canvas.drawRRect(box, Paint()..color = const Color(0xFF1B1B1B));
    canvas.drawRect(const Rect.fromLTWH(-9, -4, 18, 3),
        Paint()..color = const Color(0xFFC9A227));
    canvas.restore();

    // Hub.
    canvas.drawCircle(Offset.zero, 5, Paint()..color = ink.withValues(alpha: 0.8));
    canvas.drawCircle(Offset.zero, 2.5, Paint()..color = arrowColor);
    canvas.restore();

    // Fixed mark at the top: where the phone is pointing.
    final mark = Path()
      ..moveTo(center.dx - 7, 0)
      ..lineTo(center.dx + 7, 0)
      ..lineTo(center.dx, 10)
      ..close();
    canvas.drawPath(mark, Paint()..color = ink.withValues(alpha: 0.6));
  }

  @override
  bool shouldRepaint(_CompassPainter old) =>
      old.heading != heading ||
      old.qibla != qibla ||
      old.aligned != aligned ||
      old.ink != ink;
}
/// applied at once, behind the sheet.
class _PrayerSettingsSheet extends StatefulWidget {
  final PrayerSettings initial;
  final ValueChanged<PrayerSettings> onChanged;
  const _PrayerSettingsSheet({required this.initial, required this.onChanged});

  @override
  State<_PrayerSettingsSheet> createState() => _PrayerSettingsSheetState();
}

class _PrayerSettingsSheetState extends State<_PrayerSettingsSheet> {
  late PrayerSettings _s = widget.initial;

  void _set(PrayerSettings next) {
    setState(() => _s = next);
    widget.onChanged(next);
  }

  String _madhhabName(Madhhab m) {
    final l = context.l10n;
    return switch (m) {
      Madhhab.hanafi => l.madhhabHanafi,
      Madhhab.shafi => l.madhhabShafi,
      Madhhab.maliki => l.madhhabMaliki,
      Madhhab.hanbali => l.madhhabHanbali,
      Madhhab.jafari => l.madhhabJafari,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final jafari = _s.madhhab == Madhhab.jafari;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 0, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.prayerSettings,
              style: const TextStyle(
                  fontSize: AppText.title, fontWeight: FontWeight.w800)),
          const SizedBox(height: 18),
          Text(l.madhhabAsr,
              style: const TextStyle(
                  fontSize: AppText.body, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final m in Madhhab.values)
              InkWell(
                onTap: () => _set(_s.copyWith(madhhab: m)),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: m == _s.madhhab
                        ? AppColors.primary.withValues(alpha: 0.16)
                        : cs.onSurface.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: m == _s.madhhab
                            ? AppColors.primary
                            : Colors.transparent),
                  ),
                  child: Text(_madhhabName(m),
                      style: TextStyle(
                          fontSize: AppText.secondary,
                          fontWeight: FontWeight.w600,
                          color: m == _s.madhhab ? AppColors.primary : null)),
                ),
              ),
          ]),
          const SizedBox(height: 20),
          Text(l.calcMethod,
              style: const TextStyle(
                  fontSize: AppText.body, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            key: ValueKey(_s.effectiveMethod),
            initialValue: _s.effectiveMethod,
            isExpanded: true,
            items: [
              for (final e in kPrayerMethods)
                DropdownMenuItem(
                    value: e.$1,
                    child: Text(e.$2, overflow: TextOverflow.ellipsis)),
            ],
            // Ja'fari times always use the Jafari method.
            onChanged: jafari
                ? null
                : (v) {
                    if (v != null) _set(_s.copyWith(method: v));
                  },
          ),
          const SizedBox(height: 12),
          Text(jafari ? l.prayerSettingsJafariNote : l.prayerSettingsInfo,
              style: TextStyle(
                  fontSize: AppText.caption,
                  color: cs.onSurface.withValues(alpha: 0.6))),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.doneLabel),
            ),
          ),
        ],
      ),
    );
  }
}
