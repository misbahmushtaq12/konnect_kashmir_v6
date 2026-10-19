import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../l10n/l10n.dart';
import '../../services/customer_location.dart';
import '../../theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/live_sync.dart';
import '../../widgets/app_chip.dart';
import '../../widgets/app_header.dart';
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

  /// Back to Home. The bottom bar is hidden on this tab, so the header has a
  /// back arrow that calls this.
  final VoidCallback? onBack;
  const DeenTab({super.key, this.isActive = true, this.onBack});

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
    context.read<LiveSync>().refreshCredits();
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

      // Start from the last known place: today's saved times appear at once, and
      // the fresh location below only replaces them if it is a different place.
      PrayerDay? shown;
      final known = await CustomerLocation.lastKnown();
      if (known != null && mounted) {
        final p = Position(
          latitude: known.lat,
          longitude: known.lng,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
        shown = await PrayerService.cached(known.lat, known.lng, _settings);
        if (!mounted) return;
        setState(() {
          _pos = p;
          _qibla = qiblaBearing(known.lat, known.lng);
          if (shown != null) {
            _day = shown;
            _loading = false;
          }
        });
        PrayerService.placeName(known.lat, known.lng).then((n) {
          if (mounted && n != null) setState(() => _place = n);
        });
      }

      final pos = await PrayerService.position(ask: ask);
      if (!mounted) return;
      CustomerLocation.remember(pos.latitude, pos.longitude);
      setState(() {
        _pos = pos;
        _qibla = qiblaBearing(pos.latitude, pos.longitude);
      });

      // Place name never holds up the prayer times.
      PrayerService.placeName(pos.latitude, pos.longitude).then((n) {
        if (mounted && n != null) setState(() => _place = n);
      });

      // Today's saved times for this place: nothing more to fetch.
      final cached = shown ??
          await PrayerService.cached(pos.latitude, pos.longitude, _settings);
      if (cached != null && mounted) {
        setState(() {
          _day = cached;
          _loading = false;
        });
        return;
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
    final hPad = size.width > 600 ? size.width * 0.10 : 16.0;

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
              padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 24),
              children: [
                _header(),
                const SizedBox(height: 14),
                if (_qibla != null) ...[
                  _qiblaBanner(),
                  const SizedBox(height: 14),
                ],
                _prayerCard(),
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

  /// The Konnect Kashmir logo (light on the dark theme).
  Widget _logo() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logo = Image.asset('assets/images/konnectkashmir.png',
        cacheHeight: 192, height: 44);
    if (!isDark) return logo;
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        -1, 0, 0, 0, 255,
        0, -1, 0, 0, 255,
        0, 0, -1, 0, 255,
        0, 0, 0, 1, 0,
      ]),
      child: logo,
    );
  }

  /// A compact top line (back arrow, logo, place, credits), then the title and
  /// the greeting. The bottom bar is hidden on this tab, so the arrow is the way
  /// back to Home.
  Widget _header() {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final credits = context.watch<LiveSync>().credits;
    final first =
        (context.watch<AuthProvider>().user?.name ?? '').trim().split(' ').first;
    final place = _place != null
        ? _place!.split(',').first.trim()
        : (_pos == null
            ? l.deenLocating
            : '${_pos!.latitude.toStringAsFixed(2)}, ${_pos!.longitude.toStringAsFixed(2)}');

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        if (widget.onBack != null)
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: widget.onBack,
            tooltip: l.navHome,
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                size: 20, color: cs.onSurface),
          ),
        _logo(),
        const SizedBox(width: 8),
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.location_on_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 2),
              Flexible(
                child: Text(place,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: AppText.secondary,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface)),
              ),
            ]),
          ),
        ),
        if (credits != null) ...[
          const SizedBox(width: 8),
          CreditChip(credits),
        ],
      ]),
      const SizedBox(height: 14),
      Text(l.navDeen,
          style: TextStyle(
              fontSize: AppText.titleLg,
              fontWeight: FontWeight.w800,
              color: cs.onSurface)),
      const SizedBox(height: 2),
      Text(first.isEmpty ? l.deenGreeting : '${l.deenGreeting}, $first',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: AppText.body,
              color: cs.onSurface.withValues(alpha: 0.65))),
    ]);
  }

  // -- Prayer settings --------------------------------------------------------

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
    final highlight = AppColors.primary.withValues(
        alpha: Theme.of(context).brightness == Brightness.dark ? 0.20 : 0.12);

    return _DeenCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(l.deenPrayerTimes,
                style: TextStyle(
                    fontSize: AppText.heading,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface)),
          ),
          // The prayer settings (madhhab and calculation method).
          InkWell(
            onTap: _openPrayerSettings,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.tune_rounded,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(l.filterLabel,
                    style: const TextStyle(
                        fontSize: AppText.secondary,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
              ]),
            ),
          ),
        ]),
        // The date, with the Hijri date, on its own line.
        Text(day.hijri.isEmpty ? date : '$date  ·  ${day.hijri}',
            style: TextStyle(
                fontSize: AppText.caption,
                color: cs.onSurface.withValues(alpha: 0.65))),
        const SizedBox(height: 8),
        // The countdown to the next prayer.
        Row(children: [
          Icon(_prayerIcons[next.index], size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(l.deenNextPrayer(names[next.index], _until(next.at)),
                style: const TextStyle(
                    fontSize: AppText.secondary,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
          ),
        ]),
        const SizedBox(height: 10),
        for (var i = 0; i < 5; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: i == next.index ? highlight : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(children: [
              Icon(_prayerIcons[i], size: 20, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(names[i],
                    style: TextStyle(
                        fontSize: AppText.body,
                        color: cs.onSurface,
                        fontWeight:
                            i == next.index ? FontWeight.w800 : FontWeight.w600)),
              ),
              Text(_12h(day.times[i]),
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                      fontSize: AppText.body,
                      fontWeight: FontWeight.w700,
                      color: i == next.index ? AppColors.primary : cs.onSurface)),
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

  /// A wide scenic banner: a small live compass and the Qibla angle. Tapping it
  /// opens the full compass in a sheet.
  Widget _qiblaBanner() {
    final l = context.l10n;
    final qibla = _qibla;
    if (qibla == null) return const SizedBox.shrink();
    final angleText = l.deenQiblaFromNorth(qibla.toStringAsFixed(1));

    return Semantics(
      button: true,
      label: angleText,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _openCompass,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: _deenShadow(context),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            // At least 150 high; it grows with large text instead of overflowing.
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 150),
              child: Stack(alignment: Alignment.center, children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _KashmirScenePainter(
                        dark: Theme.of(context).brightness == Brightness.dark),
                  ),
                ),
                // Keeps the white text readable on top of the picture.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          AppColors.primaryDark.withValues(alpha: 0.30),
                          AppColors.primaryDark.withValues(alpha: 0.82),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  // Only this part rebuilds as the compass turns.
                  child: ValueListenableBuilder<double?>(
                    valueListenable: _heading,
                    builder: (context, heading, _) {
                      final aligned =
                          heading != null && qiblaTurn(qibla, heading).abs() < 5;
                      final status = _compassMissing
                          ? l.deenQibla
                          : (aligned ? l.deenQiblaAligned : l.deenQiblaTurnTo);
                      return Row(children: [
                        SizedBox(
                          width: 104,
                          height: 104,
                          child: RepaintBoundary(
                            child: CustomPaint(
                              painter: _MiniCompassPainter(
                                angle: qibla - (heading ?? 0),
                                aligned: aligned,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(angleText,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: AppText.heading,
                                      fontWeight: FontWeight.w800,
                                      height: 1.2)),
                              const SizedBox(height: 8),
                              Row(children: [
                                Icon(
                                    aligned
                                        ? Icons.check_circle_rounded
                                        : Icons.explore_outlined,
                                    size: 16,
                                    color: aligned
                                        ? const Color(0xFF8CF2C0)
                                        : Colors.white.withValues(alpha: 0.9)),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(status,
                                      style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.92),
                                          fontSize: AppText.secondary,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ]),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: Colors.white.withValues(alpha: 0.85)),
                      ]);
                    },
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  /// The full compass: the big dial with the "aligned" mark and the hint.
  void _openCompass() {
    showAppSheet<void>(
      context: context,
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: _qiblaDetail(),
      ),
    );
  }

  Widget _qiblaDetail() {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final qibla = _qibla;
    if (qibla == null) return const SizedBox.shrink();

    return Column(children: [
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
    ]);
  }

  /// Quran, Audio and Duas in one row.
  Widget _tiles() {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    Widget tile(IconData icon, String label, VoidCallback onTap) => Expanded(
          child: _PressCard(
            onTap: onTap,
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
            child: Column(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(height: 8),
              Text(label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: AppText.caption,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                      color: cs.onSurface)),
            ]),
          ),
        );

    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        tile(Icons.menu_book_rounded, l.deenQuran,
            () => _push(const SurahListScreen())),
        const SizedBox(width: 8),
        tile(Icons.headphones_rounded, l.deenAudio,
            () => _push(AudioScreen(title: l.deenAudio))),
        const SizedBox(width: 8),
        tile(Icons.volunteer_activism_rounded, l.deenDuas,
            () => _push(const DuasScreen())),
      ]),
    );
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
          padding: const EdgeInsets.all(16),
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

/// The card colour of the Deen screen: white in the light theme, a slightly
/// lighter teal than the page in the dark one.
Color _deenCardColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? Color.alphaBlend(
            AppColors.primary.withValues(alpha: 0.07), AppColors.darkSurface)
        : Colors.white;

/// A very soft shadow in the light theme (none in the dark one).
List<BoxShadow> _deenShadow(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const []
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ];

/// A plain card for the Deen screen.
class _DeenCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _DeenCard({required this.child, this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _deenCardColor(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.06)),
        boxShadow: _deenShadow(context),
      ),
      child: child,
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
            color: widget.gradient == null ? _deenCardColor(context) : null,
            gradient: widget.gradient,
            border: widget.gradient == null
                ? Border.all(color: cs.onSurface.withValues(alpha: 0.06))
                : null,
            boxShadow: _deenShadow(context),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// A Kashmir scene for the Qibla banner, drawn in code: snow-capped mountains, a
/// lake, pines and a minaret. Colours follow the light or dark theme.
class _KashmirScenePainter extends CustomPainter {
  final bool dark;
  _KashmirScenePainter({required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    // Sky.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const [Color(0xFF0E2B2C), Color(0xFF214E4B)]
              : const [Color(0xFF7CC3D8), Color(0xFFD6EEEE)],
        ).createShader(rect),
    );

    // Far mountains with snow on the peaks.
    final far = Path()
      ..moveTo(0, h * 0.64)
      ..lineTo(w * 0.16, h * 0.30)
      ..lineTo(w * 0.31, h * 0.56)
      ..lineTo(w * 0.50, h * 0.16)
      ..lineTo(w * 0.70, h * 0.54)
      ..lineTo(w * 0.86, h * 0.28)
      ..lineTo(w, h * 0.60)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
        far, Paint()..color = dark ? const Color(0xFF2F5E66) : const Color(0xFF5F93A6));
    final snow = Paint()..color = Colors.white.withValues(alpha: dark ? 0.55 : 0.9);
    for (final p in [
      [0.16, 0.30, 0.04],
      [0.50, 0.16, 0.06],
      [0.86, 0.28, 0.045],
    ]) {
      final cx = w * p[0];
      final top = h * p[1];
      final dx = w * p[2];
      canvas.drawPath(
        Path()
          ..moveTo(cx, top)
          ..lineTo(cx - dx, top + h * 0.13)
          ..lineTo(cx - dx * 0.35, top + h * 0.10)
          ..lineTo(cx, top + h * 0.15)
          ..lineTo(cx + dx * 0.35, top + h * 0.10)
          ..lineTo(cx + dx, top + h * 0.13)
          ..close(),
        snow,
      );
    }

    // Green hills.
    final hills = Path()
      ..moveTo(0, h * 0.74)
      ..quadraticBezierTo(w * 0.22, h * 0.56, w * 0.45, h * 0.72)
      ..quadraticBezierTo(w * 0.68, h * 0.60, w, h * 0.72)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
        hills, Paint()..color = dark ? const Color(0xFF1D4A3D) : const Color(0xFF3E8F63));

    // The lake, with a few light ripples.
    final lakeTop = h * 0.76;
    final lakeRect = Rect.fromLTRB(0, lakeTop, w, h);
    canvas.drawRect(
      lakeRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const [Color(0xFF1B5A5C), Color(0xFF0F3B3D)]
              : const [Color(0xFF4DB3B5), Color(0xFF2A8C92)],
        ).createShader(lakeRect),
    );
    final ripple = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 5; i++) {
      final y = lakeTop + (h - lakeTop) * (0.2 + i * 0.17);
      final x = w * (0.12 + ((i * 37) % 70) / 100);
      canvas.drawLine(Offset(x, y), Offset(x + w * 0.10, y), ripple);
    }

    // Pines on the left shore.
    final pine = Paint()..color = dark ? const Color(0xFF123B2D) : const Color(0xFF1E5B3E);
    for (final p in [
      [0.04, 0.50, 0.09],
      [0.10, 0.44, 0.10],
      [0.17, 0.52, 0.08],
    ]) {
      final cx = w * p[0];
      final top = h * p[1];
      final base = h * 0.80;
      final half = w * p[2] / 2;
      for (var t = 0; t < 3; t++) {
        final y0 = top + (base - top) * t / 3;
        final y1 = top + (base - top) * (t + 1.4) / 3;
        canvas.drawPath(
          Path()
            ..moveTo(cx, y0)
            ..lineTo(cx - half * (0.55 + t * 0.2), y1)
            ..lineTo(cx + half * (0.55 + t * 0.2), y1)
            ..close(),
          pine,
        );
      }
    }

    // A minaret with a green dome on the right.
    final mx = w * 0.88;
    final tower = Paint()..color = dark ? const Color(0xFF9C8F78) : const Color(0xFFD8C8A8);
    canvas.drawRect(Rect.fromLTRB(mx - w * 0.011, h * 0.34, mx + w * 0.011, h * 0.80), tower);
    canvas.drawRect(Rect.fromLTRB(mx - w * 0.016, h * 0.46, mx + w * 0.016, h * 0.485), tower);
    canvas.drawArc(
      Rect.fromCenter(center: Offset(mx, h * 0.34), width: w * 0.05, height: h * 0.20),
      math.pi,
      math.pi,
      true,
      Paint()..color = dark ? const Color(0xFF1F6E55) : const Color(0xFF2F9A74),
    );
    canvas.drawRect(Rect.fromLTRB(mx - 1, h * 0.20, mx + 1, h * 0.27), tower);
  }

  @override
  bool shouldRepaint(_KashmirScenePainter old) => old.dark != dark;
}

/// The small compass of the banner: a ring and an arrow that points to the Qibla
/// ([angle] is the Qibla direction in degrees, clockwise from the top of the
/// phone). The arrow turns light green when you face it.
class _MiniCompassPainter extends CustomPainter {
  final double angle;
  final bool aligned;
  _MiniCompassPainter({required this.angle, required this.aligned});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2 - 3;
    final accent = aligned ? const Color(0xFF8CF2C0) : Colors.white;

    canvas.drawCircle(c, r, Paint()..color = Colors.black.withValues(alpha: 0.30));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = aligned ? 4 : 3
        ..color = accent.withValues(alpha: aligned ? 1 : 0.9),
    );

    final tick = Paint()
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.55);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    for (var i = 0; i < 12; i++) {
      canvas.save();
      canvas.rotate(i * math.pi / 6);
      canvas.drawLine(Offset(0, -r + 5), Offset(0, -r + (i % 3 == 0 ? 13 : 9)), tick);
      canvas.restore();
    }

    // The arrow.
    canvas.rotate(angle * math.pi / 180);
    final arrow = Path()
      ..moveTo(0, -r * 0.62)
      ..lineTo(r * 0.30, r * 0.36)
      ..lineTo(0, r * 0.18)
      ..lineTo(-r * 0.30, r * 0.36)
      ..close();
    canvas.drawPath(arrow, Paint()..color = accent);
    canvas.restore();

    // Where the phone points (the top).
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - 6, 1)
        ..lineTo(c.dx + 6, 1)
        ..lineTo(c.dx, 10)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(_MiniCompassPainter old) =>
      old.angle != angle || old.aligned != aligned;
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
