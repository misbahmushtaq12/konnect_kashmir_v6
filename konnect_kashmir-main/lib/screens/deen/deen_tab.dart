import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../l10n/l10n.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_chip.dart';
import '../../widgets/app_header.dart';
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
  double? _qibla;
  LocationProblem? _problem;
  String? _error;
  bool _loading = true;

  StreamSubscription<CompassEvent>? _compassSub;
  double? _heading;
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
      final cached = await PrayerService.cached(pos.latitude, pos.longitude);
      if (cached != null && mounted) {
        setState(() {
          _day = cached;
          _loading = false;
        });
      }
      final fresh = await PrayerService.fetch(pos.latitude, pos.longitude);
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
      setState(() {
        final prev = _heading;
        if (prev == null) {
          _heading = heading;
        } else {
          // Smooth out sensor jitter (turn the short way round the circle).
          var d = heading - prev;
          if (d > 180) d -= 360;
          if (d < -180) d += 360;
          _heading = (prev + d * 0.3 + 360) % 360;
        }
      });
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

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final hPad = size.width > 600 ? size.width * 0.12 : 20.0;

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
              padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 24),
              children: [
                AppHeader(title: context.l10n.navDeen),
                const SizedBox(height: 16),
                _prayerCard(),
                const SizedBox(height: 14),
                _qiblaCard(),
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

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.deenPrayerTimes,
            style: const TextStyle(
                fontSize: AppText.heading, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
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
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ]),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 24),
          child: Text(l.deenCurrentLocation,
              style: TextStyle(
                  fontSize: AppText.caption,
                  color: cs.onSurface.withValues(alpha: 0.55))),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Icon(Icons.calendar_today_outlined,
              size: 16, color: cs.onSurface.withValues(alpha: 0.6)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              day.hijri.isEmpty ? date : '$date  ·  ${day.hijri}',
              style: TextStyle(
                  fontSize: AppText.secondary,
                  color: cs.onSurface.withValues(alpha: 0.75)),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        AppChip(l.deenNextPrayer(names[next.index], _until(next.at)),
            icon: Icons.schedule_rounded, tone: ChipTone.primary),
        const SizedBox(height: 12),
        for (var i = 0; i < 5; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: i == next.index
                  ? AppColors.primary.withValues(alpha: 0.14)
                  : cs.onSurface.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(children: [
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

    final heading = _heading;
    final turn = heading == null ? 0.0 : qiblaTurn(qibla, heading);
    final aligned = heading != null && turn.abs() < 5;
    final arrow = aligned ? AppColors.success : AppColors.primary;

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
        const SizedBox(height: 16),
        SizedBox(
          width: 190,
          height: 190,
          child: Stack(alignment: Alignment.center, children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: aligned
                        ? AppColors.success
                        : cs.onSurface.withValues(alpha: 0.18),
                    width: aligned ? 3 : 2),
              ),
            ),
            // Fixed mark: the top of the phone.
            Positioned(
              top: 0,
              child: Icon(Icons.arrow_drop_down_rounded,
                  size: 30, color: cs.onSurface.withValues(alpha: 0.5)),
            ),
            // The indicator: turned by (qibla − device heading).
            Transform.rotate(
              angle: turn * math.pi / 180,
              child: Icon(Icons.navigation_rounded, size: 110, color: arrow),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Text(
          _compassMissing
              ? l.deenCompassMissing
              : aligned
                  ? l.deenQiblaAligned
                  : l.deenQiblaHint,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: AppText.secondary,
              fontWeight: aligned ? FontWeight.w700 : FontWeight.w400,
              color: aligned
                  ? AppColors.success
                  : cs.onSurface.withValues(alpha: 0.65)),
        ),
      ]),
    );
  }

  Widget _tiles() {
    final l = context.l10n;
    Widget tile(IconData icon, String label, VoidCallback onTap) => Expanded(
          child: AppCard(
            onTap: onTap,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
            child: Column(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(height: 10),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: AppText.secondary)),
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
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final last = _last;
    final surah = _lastSurah;

    final VoidCallback open = (last != null && surah != null)
        ? () => _push(SurahReaderScreen(surah: surah, startAyah: last.ayah))
        : () => _push(const SurahListScreen());

    return AppCard(
      onTap: open,
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.auto_stories_rounded, color: AppColors.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.deenContinueReading,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: AppText.body)),
            const SizedBox(height: 2),
            Text(
              (last != null && surah != null)
                  ? l.deenLastRead(surah.english, last.ayah.toString())
                  : l.deenStartReading,
              style: TextStyle(
                  fontSize: AppText.secondary,
                  color: cs.onSurface.withValues(alpha: 0.65)),
            ),
          ]),
        ),
        Icon(Icons.chevron_right_rounded,
            color: cs.onSurface.withValues(alpha: 0.4)),
      ]),
    );
  }
}
