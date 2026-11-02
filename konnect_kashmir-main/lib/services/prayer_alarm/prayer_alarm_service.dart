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

/// A permission the beep needs before it can be switched on.
enum PrayerAlarmPermission {
  /// Notifications (and their sound): the beep is a notification. Needed on
  /// iPhone and Android alike.
  notifications,

  /// Android 12+: exact alarms, so it rings at the exact minute.
  exactAlarms,
}

/// What the settings screen shows.
class PrayerAlarmStatus {
  final bool enabled;

  /// How many prayer alarms are waiting on the phone.
  final int scheduled;

  /// The moment of the last one (UTC), or null.
  final DateTime? through;
  final Set<PrayerAlarmIssue> issues;

  /// True for the one status that finishes turning the beep on: alarms were set
  /// and nothing is wrong. The screen shows its confirmation for it.
  final bool justEnabled;

  /// The beep is NOT on, because this permission is missing (the user is being
  /// asked for it, or was asked and did not give it). Null when nothing is.
  final PrayerAlarmPermission? missingPermission;
  const PrayerAlarmStatus({
    this.enabled = false,
    this.scheduled = 0,
    this.through,
    this.issues = const {},
    this.justEnabled = false,
    this.missingPermission,
  });

  /// A permission is what stops the beep (not the place, the prayer times or the
  /// room on the phone).
  bool get needsPermission =>
      issues.contains(PrayerAlarmIssue.exactAlarmsOff) ||
      issues.contains(PrayerAlarmIssue.notificationsBlocked);

  /// The beep is on but it will not (fully) ring: a permission is missing, the
  /// system refused some alarms, or there is nothing on the phone because the place
  /// or the prayer times are missing. The screens show a warning next to the bell
  /// and the switch. Not a warning: a note about a place or prayer times that could
  /// not be refreshed while good alarms are still waiting on the phone.
  bool get hasWarning =>
      enabled &&
      (needsPermission ||
          issues.contains(PrayerAlarmIssue.failed) ||
          (issues.isNotEmpty && scheduled == 0));

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

/// The title and text of a prayer alarm that also asks the user to open the app
/// (see [AlarmReminder]), in the app language [lang].
typedef AlarmReminderText =
    ({String title, String body}) Function(
      Prayer prayer,
      AlarmReminder reminder,
      String lang,
    );

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
/// The alarms of the last two planned days also ask the user to open the app (see
/// [planReminders]), so they are told before the alarms run out and not after.
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
    AlarmReminderText? reminderText,
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
       _text = text ?? _defaultText,
       _reminderText = reminderText ?? _defaultReminderText;

  static final PrayerAlarmService instance = PrayerAlarmService();

  final AlarmScheduler scheduler;
  final PrayerCalendarSource _calendar;
  final LocationLookup _location;
  final DateTime Function() _clock;
  final Future<String> Function() _language;
  final AlarmText _text;
  final AlarmReminderText _reminderText;

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

  /// What the phone allowed when the alarms were last planned: coming back to
  /// the app plans again at once when this has changed (a permission was given
  /// or taken back in the system settings).
  AlarmPermissions? _lastPerms;

  /// The next planning is the one that finishes turning the beep on.
  bool _confirmNext = false;

  /// The permission that stopped the beep from being turned on (not given yet).
  PrayerAlarmPermission? _blockedOn;

  /// While the user is in the phone's settings: completed when they come back.
  Completer<void>? _backFromSettings;
  bool _wentToBackground = false;

  static PrayerAlarmPermission? _missing(AlarmPermissions? p) {
    if (p == null) return null;
    if (!p.notifications) return PrayerAlarmPermission.notifications;
    if (!p.exactAlarms) return PrayerAlarmPermission.exactAlarms;
    return null;
  }

  static PrayerAlarmIssue _issueFor(PrayerAlarmPermission p) => switch (p) {
    PrayerAlarmPermission.notifications =>
      PrayerAlarmIssue.notificationsBlocked,
    PrayerAlarmPermission.exactAlarms => PrayerAlarmIssue.exactAlarmsOff,
  };

  // Remembered on the phone, so it survives the app being closed while the user
  // is in the system settings.
  static const _pendingKey = 'prayer_alarm_pending_exact';
  Future<bool> _isPending() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(_pendingKey) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _setPending(bool on) async {
    try {
      await (await SharedPreferences.getInstance()).setBool(_pendingKey, on);
    } catch (_) {}
  }

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

  /// The app went to the background (the observer tells us).
  void appPaused() => _wentToBackground = true;

  /// The app came back to the front. If the user was in the phone's settings, the
  /// waiting [openNotificationSettings] is released; then everything is looked at.
  Future<void> appResumed() {
    if (_wentToBackground) {
      _wentToBackground = false;
      final back = _backFromSettings;
      if (back != null && !back.isCompleted) back.complete();
    }
    return onResume();
  }

  /// The app came back to the front. The permissions are looked at every time
  /// (one may have been given or taken back in the system settings); planning
  /// again is skipped only when nothing changed and it was done a moment ago.
  Future<void> onResume() async {
    // Nothing is on and nothing is waiting for a permission: nothing to check.
    if (!(await PrayerAlarmPrefs.load()).enabled && !await _isPending()) return;
    AlarmPermissions? now;
    try {
      now = await scheduler.permissions();
    } catch (_) {}
    final before = _lastPerms;
    final changed =
        now == null ||
        before == null ||
        now.exactAlarms != before.exactAlarms ||
        now.notifications != before.notifications;
    final last = _lastRefresh;
    final recent = last != null && _clock().difference(last) < minResumeGap;
    if (recent && !_forceNextResume && !changed && !await _zoneChanged()) {
      return;
    }
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

  /// The switch (one for all five prayers).
  ///
  /// Turning it ON needs two permissions, and the beep is NOT switched on until
  /// it has both: notifications (iPhone and Android 13+; the alarm is a
  /// notification, with a sound) and, on Android 12+, exact alarms (so it rings
  /// at the exact minute). The one that is missing is in
  /// [PrayerAlarmStatus.missingPermission]; the screen explains it and sends the
  /// user to the right system screen ([openNotificationSettings],
  /// [openExactAlarmSettings]) or calls [cancelPendingEnable]. With both, the
  /// alarms are planned (asking once for the place).
  ///
  /// Turning it OFF cancels the alarms.
  Future<PrayerAlarmStatus> setEnabled(bool on) async {
    if (!on) {
      await _setPending(false);
      _blockedOn = null;
      _confirmNext = false;
      await (await PrayerAlarmPrefs.load()).copyWith(enabled: false).save();
      return refresh(reason: 'turned off');
    }
    AlarmPermissions? perms;
    try {
      await scheduler.ensureReady();
      // The system's own prompt for notifications, where there still is one.
      perms = await scheduler.requestPermissions();
    } catch (e) {
      debugPrint('[PrayerAlarm] permission request failed: $e');
      try {
        perms = await scheduler.permissions();
      } catch (_) {}
    }
    final missing = _missing(perms);
    if (missing != null) {
      // Not on. Remembered, so that if the user goes to the phone's settings and
      // comes back (even after the app was closed meanwhile) it is finished.
      await _setPending(true);
      _blockedOn = missing;
      final s = PrayerAlarmStatus(
        issues: {_issueFor(missing)},
        missingPermission: missing,
      );
      status.value = s;
      return s;
    }
    _blockedOn = null;
    await _setPending(false);
    await (await PrayerAlarmPrefs.load()).copyWith(enabled: true).save();
    _confirmNext = true;
    return refresh(reason: 'turned on', askLocation: true);
  }

  /// The user agreed to give the exact-alarm permission: opens Android's screen
  /// for it (the one for this app) and returns when they come back. If the beep
  /// was waiting for it, the alarms are planned now that it is allowed; if not
  /// allowed, the status says it is still missing. Nothing is set without it.
  Future<PrayerAlarmStatus> openExactAlarmSettings() async {
    if (!(await PrayerAlarmPrefs.load()).enabled) await _setPending(true);
    _forceNextResume = true;
    try {
      await scheduler.requestPermissions(exactAlarms: true);
    } catch (e) {
      debugPrint('[PrayerAlarm] permission request failed: $e');
    }
    return refresh(
      reason: 'back from the exact-alarm screen',
      askLocation: true,
    );
  }

  /// The user agreed to turn notifications on: opens this app's page in the
  /// phone's settings and returns when they come back. (A notification permission
  /// can be asked for only once or twice, and on iPhone only once, so the
  /// settings are the way that always works.) Like [openExactAlarmSettings], it
  /// finishes turning the beep on if everything is allowed now.
  Future<PrayerAlarmStatus> openNotificationSettings() async {
    if (!(await PrayerAlarmPrefs.load()).enabled) await _setPending(true);
    _forceNextResume = true;
    final back = _backFromSettings = Completer<void>();
    _wentToBackground = false;
    try {
      await scheduler.openSettings();
      // Until the user is back. If the app is closed meanwhile, the next time it
      // opens finishes the job (the waiting was saved above).
      await back.future.timeout(const Duration(minutes: 30), onTimeout: () {});
    } catch (e) {
      debugPrint('[PrayerAlarm] could not open the settings: $e');
    }
    _backFromSettings = null;
    return refresh(reason: 'back from the settings', askLocation: true);
  }

  /// The user chose not to give the permission now: the beep stays off.
  Future<void> cancelPendingEnable() async {
    await _setPending(false);
    _blockedOn = null;
    status.value = const PrayerAlarmStatus();
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

    // Turning the beep on was waiting for the exact-alarm permission. Whenever the
    // app looks again (it came back from the system settings, or was opened anew):
    // allowed now -> finish turning it on; still not allowed -> it stays off and
    // the screen says the permission is still needed.
    if (await _isPending()) {
      AlarmPermissions? p;
      try {
        p = await scheduler.permissions();
      } catch (_) {}
      if (p != null) {
        await _setPending(false);
        final missing = _missing(p);
        if (missing == null) {
          await (await PrayerAlarmPrefs.load()).copyWith(enabled: true).save();
          _blockedOn = null;
          _confirmNext = true;
        } else {
          _blockedOn = missing; // asked, and still not given
        }
      }
    }

    final prefs = await PrayerAlarmPrefs.load();
    final state = await PrayerAlarmState.load();
    final issues = <PrayerAlarmIssue>{};

    PrayerAlarmStatus publish(int scheduled, {DateTime? through}) {
      // The first planning after turning the beep on confirms it, and only when it
      // really set alarms and nothing is wrong.
      final confirm = _confirmNext && issues.isEmpty && scheduled > 0;
      _confirmNext = false;
      final s = PrayerAlarmStatus(
        enabled: prefs.enabled,
        scheduled: scheduled,
        through: through ?? state.scheduledThrough,
        issues: issues,
        justEnabled: confirm,
        missingPermission: prefs.enabled ? null : _blockedOn,
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
      final blocked = _blockedOn;
      if (blocked != null) issues.add(_issueFor(blocked));
      return publish(0);
    }
    await _syncMaintenance(true, foreground);

    // Without notification permission nothing can sound; what is already
    // planned is kept so it works again the moment the user allows it.
    final perms = await scheduler.permissions();
    _lastPerms = perms;
    if (!perms.exactAlarms) issues.add(PrayerAlarmIssue.exactAlarmsOff);
    if (!perms.notifications) {
      issues.add(PrayerAlarmIssue.notificationsBlocked);
      return publish(owned.length);
    }
    // The beep is meant to ring at the exact minute and never a few minutes late,
    // so without permission for exact alarms none is set (and any that is left
    // from before is taken down). The user is told and can allow it.
    if (!perms.exactAlarms) {
      for (final o in owned) {
        await _cancel(o.id);
      }
      debugPrint(
        '[PrayerAlarm] $reason: exact alarms are not allowed, none set',
      );
      return publish(0);
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
    // The last days' alarms also ask the user to open the app.
    final reminders = planReminders(plan);
    ({String title, String body}) textOf(PlannedAlarm a) {
      final r = reminders[a.id];
      return r == null ? texts[a.prayer]! : _reminderText(a.prayer, r, lang);
    }

    String payloadOf(PlannedAlarm a) => jsonEncode({
      'type': 'prayer_alarm',
      'prayer': a.prayer.name,
      'at': a.at.millisecondsSinceEpoch,
      'lang': lang,
      if (reminders[a.id] != null) 'reminder': reminders[a.id]!.name,
    });

    final byId = {for (final a in plan) a.id: a};
    final kept = <int>{};
    for (final o in owned) {
      final a = byId[o.id];
      final text = a == null ? null : textOf(a);
      final same =
          a != null &&
          o.payload == payloadOf(a) &&
          o.title == text!.title &&
          o.body == text.body;
      if (same) {
        kept.add(o.id);
      } else {
        await _cancel(
          o.id,
        ); // switched off, moved, past, in another language, or its reminder changed
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
          title: textOf(a).title,
          body: textOf(a).body,
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

  static String _prayerName(AppLocalizations l, Prayer prayer) =>
      switch (prayer) {
        Prayer.fajr => l.prayerFajr,
        Prayer.dhuhr => l.prayerDhuhr,
        Prayer.asr => l.prayerAsr,
        Prayer.maghrib => l.prayerMaghrib,
        Prayer.isha => l.prayerIsha,
      };

  static ({String title, String body}) _defaultText(
    Prayer prayer,
    String lang,
  ) => _defaultReminderText(prayer, AlarmReminder.none, lang);

  static ({String title, String body}) _defaultReminderText(
    Prayer prayer,
    AlarmReminder reminder,
    String lang,
  ) {
    final l = lookupAppLocalizations(Locale(lang));
    final name = _prayerName(l, prayer);
    return switch (reminder) {
      AlarmReminder.none => (
        title: l.prayerAlarmNotifTitle(name),
        body: l.prayerAlarmNotifBody(name),
      ),
      AlarmReminder.endsTomorrow => (
        title: l.prayerAlarmNotifTitle(name),
        body: l.prayerAlarmNotifEndsTomorrow(name),
      ),
      AlarmReminder.endsToday => (
        title: l.prayerAlarmNotifTitle(name),
        body: l.prayerAlarmNotifEndsToday(name),
      ),
      AlarmReminder.last => (
        title: l.prayerAlarmNotifLastTitle,
        body: l.prayerAlarmNotifLastBody(name),
      ),
    };
  }
}

class _ResumeObserver with WidgetsBindingObserver {
  final PrayerAlarmService _service;
  _ResumeObserver(this._service);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _service.appPaused();
    if (state == AppLifecycleState.resumed) unawaited(_service.appResumed());
  }
}
