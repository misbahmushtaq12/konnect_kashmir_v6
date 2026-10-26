import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import '../../l10n/app_localizations.dart';
import '../../providers/locale_provider.dart';
import '../../screens/deen/prayer_service.dart';
import '../customer_location.dart';
import 'prayer_alarm_planner.dart';
import 'prayer_alarm_prefs.dart';
import 'prayer_alarm_scheduler.dart';
import 'prayer_calendar.dart';
import 'prayer_zone.dart';

/// Why the alarms are not (fully) working. Several can apply at once.
enum PrayerAlarmIssue {
  /// Notifications are off for the app, so nothing can sound.
  notificationsBlocked,

  /// Android only: exact alarms are not allowed, so a beep may be a few minutes late.
  exactAlarmsOff,

  /// No place is known to work the prayer times out for.
  noLocation,

  /// Prayer times are not saved on the phone and could not be downloaded.
  noTimes,

  /// iOS: the phone's 64 pending notifications are used up by other features.
  noRoom,

  /// The system refused to take some alarms.
  failed,
}

/// What the settings screen shows.
class PrayerAlarmStatus {
  final bool enabled;

  /// How many prayer alarms are waiting on the phone.
  final int scheduled;

  /// The moment of the last one (UTC), or null.
  final DateTime? through;
  final Set<PrayerAlarmIssue> issues;
  const PrayerAlarmStatus({
    this.enabled = false,
    this.scheduled = 0,
    this.through,
    this.issues = const {},
  });

  static const PrayerAlarmStatus idle = PrayerAlarmStatus();
}

/// Looks for the place to plan the alarms for: [foreground] is false in the
/// background (no GPS then) and [ask] allows the permission dialog.
typedef LocationLookup =
    Future<({double lat, double lng})?> Function({
      required bool foreground,
      required bool ask,
    });

/// The title and text of a notification, in the app language [lang].
typedef AlarmText =
    ({String title, String body}) Function(Prayer prayer, String lang);

/// Keeps the alarms topped up while the app is closed, where the system allows it.
abstract class PrayerAlarmMaintenance {
  Future<void> sync({required bool enabled});
}

/// Prayer-time beeps, planned on the phone.
///
/// The five prayer times for the next [windowDays] days are put on the phone as
/// local notifications. The system keeps them and fires them with the app closed
/// and with no internet. Every time the app opens (and when the user changes a
/// setting) the window is moved forward: alarms that are already right are left
/// alone, wrong or out-of-date ones are cancelled, missing ones are added. Only
/// notifications in the prayer-alarm id block are ever touched.
///
/// The limit that cannot be removed: once the planned days run out, nothing on
/// the phone can add more until the app runs again (Android also tries once or
/// twice a day in the background; iOS does not).
class PrayerAlarmService {
  PrayerAlarmService({
    AlarmScheduler? scheduler,
    PrayerCalendarSource? calendar,
    LocationLookup? location,
    DateTime Function()? clock,
    Future<String> Function()? language,
    AlarmText? text,
    this.maintenance,
    this.windowDays = kDefaultWindowDays,
    this.iosReserve = 14,
    this.androidBudget = 100,
    this.minResumeGap = const Duration(minutes: 10),
  }) : scheduler = scheduler ?? LocalAlarmScheduler(),
       _calendar = calendar ?? PrayerCalendarSource(),
       _location = location ?? _defaultLocation,
       _clock = clock ?? DateTime.now,
       _language = language ?? _defaultLanguage,
       _text = text ?? _defaultText;

  static final PrayerAlarmService instance = PrayerAlarmService();

  final AlarmScheduler scheduler;
  final PrayerCalendarSource _calendar;
  final LocationLookup _location;
  final DateTime Function() _clock;
  final Future<String> Function() _language;
  final AlarmText _text;

  /// Set by the app to keep the alarms topped up in the background (Android).
  PrayerAlarmMaintenance? maintenance;

  /// How many days ahead are planned (today is the first).
  final int windowDays;

  /// iOS: notifications kept free for the app's other features, out of the 64.
  final int iosReserve;

  /// Android: the most prayer alarms planned at once. (The system allows far
  /// more; ten days of five prayers is 50.)
  final int androidBudget;

  /// Coming back to the app sooner than this after the last planning does not
  /// plan again (unless the time zone changed).
  final Duration minResumeGap;

  final ValueNotifier<PrayerAlarmStatus> status = ValueNotifier(
    PrayerAlarmStatus.idle,
  );

  bool _started = false;
  DateTime? _lastRefresh;
  bool _forceNextResume = false;
  String? _languageNow;
  Future<void> _queue = Future<void>.value();

  // ── Starting and lifecycle ────────────────────────────────────────────────

  /// Plans the alarms now and again whenever the app comes back to the front.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _ensureTimeZones();
    WidgetsBinding.instance.addObserver(_ResumeObserver(this));
    await refresh(reason: 'launch');
  }

  /// The app came back to the front. Plans again unless that was done a moment ago.
  Future<void> onResume() async {
    final last = _lastRefresh;
    final recent = last != null && _clock().difference(last) < minResumeGap;
    if (recent && !_forceNextResume && !await _zoneChanged()) return;
    _forceNextResume = false;
    await refresh(reason: 'resume');
  }

  /// The app language changed to [code]. (Passed in because the language is saved
  /// a moment after listeners hear about it, so reading it back could be too early.)
  Future<void> onLanguageChanged(String code) {
    _languageNow = code;
    return refresh(reason: 'language');
  }

  Future<void> onPrayerSettingsChanged() => refresh(reason: 'prayer settings');

  Future<bool> _zoneChanged() async {
    final before = (await PrayerAlarmState.load()).deviceOffsetMinutes;
    return before != null &&
        before != _clock().toLocal().timeZoneOffset.inMinutes;
  }

  // ── What the settings screen calls ────────────────────────────────────────

  Future<PrayerAlarmPrefs> prefs() => PrayerAlarmPrefs.load();

  /// The master switch. Turning it on asks for the notification permission and
  /// (once) the location, then plans the alarms; turning it off cancels them.
  Future<PrayerAlarmStatus> setEnabled(bool on) async {
    await (await PrayerAlarmPrefs.load()).copyWith(enabled: on).save();
    if (on) {
      try {
        await scheduler.ensureReady();
        await scheduler.requestPermissions();
      } catch (e) {
        debugPrint('[PrayerAlarm] permission request failed: $e');
      }
    }
    return refresh(reason: on ? 'turned on' : 'turned off', askLocation: on);
  }

  /// One prayer's switch.
  Future<PrayerAlarmStatus> setPrayer(Prayer prayer, bool on) async {
    await (await PrayerAlarmPrefs.load()).withPrayer(prayer, on).save();
    return refresh(reason: '${prayer.name} ${on ? 'on' : 'off'}');
  }

  /// Asks again for what is missing. With [exactAlarms] (Android 12+) this opens
  /// the system screen where the user allows exact alarms.
  Future<PrayerAlarmStatus> requestPermissions({
    bool exactAlarms = false,
  }) async {
    _forceNextResume = true; // the user comes back from a system screen
    try {
      await scheduler.requestPermissions(exactAlarms: exactAlarms);
    } catch (e) {
      debugPrint('[PrayerAlarm] permission request failed: $e');
    }
    return refresh(reason: 'permission', askLocation: true);
  }

  Future<void> openSystemSettings() {
    _forceNextResume = true;
    return scheduler.openSettings();
  }

  // ── Planning ──────────────────────────────────────────────────────────────

  /// Brings the alarms on the phone in line with the settings, the place and the
  /// language. Safe to call at any time and from several places: runs one after
  /// another, and planning twice never makes duplicates.
  Future<PrayerAlarmStatus> refresh({
    String reason = 'manual',
    bool foreground = true,
    bool askLocation = false,
  }) {
    final run = _queue.then((_) => _refresh(reason, foreground, askLocation));
    _queue = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  Future<PrayerAlarmStatus> _refresh(
    String reason,
    bool foreground,
    bool askLocation,
  ) async {
    _ensureTimeZones();
    final now = _clock();
    final prefs = await PrayerAlarmPrefs.load();
    final state = await PrayerAlarmState.load();
    final issues = <PrayerAlarmIssue>{};

    PrayerAlarmStatus publish(int scheduled, {DateTime? through}) {
      final s = PrayerAlarmStatus(
        enabled: prefs.enabled,
        scheduled: scheduled,
        through: through ?? state.scheduledThrough,
        issues: issues,
      );
      status.value = s;
      return s;
    }

    List<PendingAlarm> pending;
    try {
      await scheduler.ensureReady();
      pending = await scheduler.pending();
    } catch (e) {
      debugPrint('[PrayerAlarm] $reason: the system could not be reached: $e');
      issues.add(PrayerAlarmIssue.failed);
      return publish(0);
    }
    final owned = pending.where((p) => isPrayerAlarmId(p.id)).toList();

    // Nothing wanted: take down our alarms and only ours.
    if (prefs.active.isEmpty) {
      for (final o in owned) {
        await _cancel(o.id);
      }
      await _syncMaintenance(false, foreground);
      _lastRefresh = now;
      debugPrint(
        '[PrayerAlarm] $reason: off, ${owned.length} alarms cancelled',
      );
      return publish(0);
    }
    await _syncMaintenance(true, foreground);

    // Without notification permission nothing can sound; what is already
    // planned is kept so it works again the moment the user allows it.
    final perms = await scheduler.permissions();
    if (!perms.exactAlarms) issues.add(PrayerAlarmIssue.exactAlarmsOff);
    if (!perms.notifications) {
      issues.add(PrayerAlarmIssue.notificationsBlocked);
      return publish(owned.length);
    }

    var place = await _locate(foreground, askLocation);
    if (place == null && state.lat != null && state.lng != null) {
      place = (lat: state.lat!, lng: state.lng!); // the last place used
    }
    if (place == null) {
      issues.add(PrayerAlarmIssue.noLocation);
      return publish(owned.length);
    }
    final lat = _round2(place.lat);
    final lng = _round2(place.lng);

    final settings = await PrayerSettings.load();
    final local = now.toLocal();
    final nextMonth = DateTime(local.year, local.month + 1);
    final calendar = await _calendar.load(
      lat: lat,
      lng: lng,
      settings: settings,
      months: [
        (y: local.year, m: local.month),
        (y: nextMonth.year, m: nextMonth.month),
      ],
    );
    final zone = prayerZoneFor(calendar.timeZone, local.timeZoneOffset);

    // How many alarms the phone can take. iOS keeps only 64 notifications for
    // the whole app, so what other features have waiting is subtracted first.
    final limit = scheduler.pendingLimit;
    final others = pending.length - owned.length;
    var budget = limit == null ? androidBudget : limit - others - iosReserve;
    budget = math.min(budget, windowDays * prefs.active.length);
    if (budget <= 0) {
      issues.add(PrayerAlarmIssue.noRoom);
      return publish(owned.length);
    }

    final plan = planAlarms(
      now: now,
      calendar: calendar,
      zone: zone,
      enabled: prefs.active,
      maxAlarms: budget,
      windowDays: windowDays,
    );
    if (plan.isEmpty) {
      // No usable times (offline with nothing saved, say): do not throw away
      // alarms that are still good.
      issues.add(PrayerAlarmIssue.noTimes);
      return publish(owned.length);
    }

    final lang = _languageNow ?? await _language();
    final texts = {for (final p in Prayer.values) p: _text(p, lang)};
    String payloadOf(PlannedAlarm a) => jsonEncode({
      'type': 'prayer_alarm',
      'prayer': a.prayer.name,
      'at': a.at.millisecondsSinceEpoch,
      'lang': lang,
      // How it was set: if the user allows (or takes back) exact alarms later, the
      // payload no longer matches and every alarm is set again in the right mode.
      'exact': perms.exactAlarms,
    });

    final byId = {for (final a in plan) a.id: a};
    final kept = <int>{};
    for (final o in owned) {
      final a = byId[o.id];
      final same =
          a != null &&
          o.payload == payloadOf(a) &&
          o.title == texts[a.prayer]!.title &&
          o.body == texts[a.prayer]!.body;
      if (same) {
        kept.add(o.id);
      } else {
        await _cancel(
          o.id,
        ); // switched off, moved, past, or in another language
      }
    }

    var added = 0;
    var failed = 0;
    for (final a in plan) {
      if (kept.contains(a.id)) continue;
      try {
        await scheduler.schedule(
          id: a.id,
          at: a.at,
          title: texts[a.prayer]!.title,
          body: texts[a.prayer]!.body,
          payload: payloadOf(a),
        );
        added++;
      } catch (e) {
        failed++;
        debugPrint(
          '[PrayerAlarm] could not schedule ${a.prayer.name} ${a.at}: $e',
        );
      }
    }
    if (failed > 0) issues.add(PrayerAlarmIssue.failed);

    final through = plan.last.at;
    await PrayerAlarmState(
      lat: lat,
      lng: lng,
      deviceOffsetMinutes: local.timeZoneOffset.inMinutes,
      lang: lang,
      scheduledThrough: through,
      lastRefresh: now,
    ).save();
    _lastRefresh = now;
    debugPrint(
      '[PrayerAlarm] $reason: ${kept.length} kept, $added added, '
      '$failed failed, through $through, issues $issues',
    );
    return publish(kept.length + added, through: through);
  }

  Future<({double lat, double lng})?> _locate(bool foreground, bool ask) async {
    try {
      return await _location(
        foreground: foreground,
        ask: ask,
      ).timeout(const Duration(seconds: 20));
    } catch (e) {
      debugPrint('[PrayerAlarm] location: $e');
      return null;
    }
  }

  Future<void> _cancel(int id) async {
    try {
      await scheduler.cancel(id);
    } catch (e) {
      debugPrint('[PrayerAlarm] could not cancel $id: $e');
    }
  }

  Future<void> _syncMaintenance(bool enabled, bool foreground) async {
    final m = maintenance;
    // The background job must not re-register itself.
    if (m == null || !foreground) return;
    try {
      await m.sync(enabled: enabled);
    } catch (e) {
      debugPrint('[PrayerAlarm] background upkeep: $e');
    }
  }

  static double _round2(double v) => double.parse(v.toStringAsFixed(2));

  static bool _zonesReady = false;
  static void _ensureTimeZones() {
    if (_zonesReady) return;
    tzdata.initializeTimeZones();
    _zonesReady = true;
  }

  // ── Defaults used by the real app ─────────────────────────────────────────

  /// The place the app already knows (Home and the Deen screen remember it); the
  /// GPS only when it does not, and never in the background.
  static Future<({double lat, double lng})?> _defaultLocation({
    required bool foreground,
    required bool ask,
  }) async {
    final known = await CustomerLocation.lastKnown();
    if (known != null) return known;
    if (!foreground) return null;
    try {
      final p = await PrayerService.position(ask: ask);
      CustomerLocation.remember(p.latitude, p.longitude);
      return (lat: p.latitude, lng: p.longitude);
    } catch (_) {
      return null;
    }
  }

  static Future<String> _defaultLanguage() async {
    try {
      final code = (await SharedPreferences.getInstance()).getString(
        LocaleProvider.prefLocale,
      );
      if (code != null &&
          LocaleProvider.supported.any((l) => l.locale.languageCode == code)) {
        return code;
      }
    } catch (_) {}
    return 'en';
  }

  static ({String title, String body}) _defaultText(
    Prayer prayer,
    String lang,
  ) {
    final l = lookupAppLocalizations(Locale(lang));
    final name = switch (prayer) {
      Prayer.fajr => l.prayerFajr,
      Prayer.dhuhr => l.prayerDhuhr,
      Prayer.asr => l.prayerAsr,
      Prayer.maghrib => l.prayerMaghrib,
      Prayer.isha => l.prayerIsha,
    };
    return (
      title: l.prayerAlarmNotifTitle(name),
      body: l.prayerAlarmNotifBody(name),
    );
  }
}

class _ResumeObserver with WidgetsBindingObserver {
  final PrayerAlarmService _service;
  _ResumeObserver(this._service);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_service.onResume());
  }
}
