import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'prayer_alarm_planner.dart';

/// What the user chose: the master switch and one switch per prayer.
///
/// Nothing is switched on for anyone: the master switch starts OFF. The five
/// prayer switches start ON, so turning the master switch on gives all five
/// alarms and the user can then untick the ones they do not want.
class PrayerAlarmPrefs {
  final bool enabled;
  final Set<Prayer> prayers;
  const PrayerAlarmPrefs({
    this.enabled = false,
    this.prayers = const {...Prayer.values},
  });

  static const _master = 'prayer_alarm_enabled';
  static String _key(Prayer p) => 'prayer_alarm_${p.name}';

  /// The prayers that will actually sound: none while the master switch is off.
  Set<Prayer> get active => enabled ? prayers : const {};

  PrayerAlarmPrefs copyWith({bool? enabled, Set<Prayer>? prayers}) =>
      PrayerAlarmPrefs(
        enabled: enabled ?? this.enabled,
        prayers: prayers ?? this.prayers,
      );

  PrayerAlarmPrefs withPrayer(Prayer p, bool on) =>
      copyWith(prayers: on ? {...prayers, p} : ({...prayers}..remove(p)));

  static Future<PrayerAlarmPrefs> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      return PrayerAlarmPrefs(
        enabled: sp.getBool(_master) ?? false,
        prayers: {
          for (final p in Prayer.values)
            if (sp.getBool(_key(p)) ?? true) p,
        },
      );
    } catch (_) {
      return const PrayerAlarmPrefs();
    }
  }

  Future<void> save() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool(_master, enabled);
      for (final p in Prayer.values) {
        await sp.setBool(_key(p), prayers.contains(p));
      }
    } catch (_) {}
  }
}

/// What the alarm service remembers about its last successful planning, so the
/// next one can tell that the place, the zone or the language changed.
class PrayerAlarmState {
  final double? lat;
  final double? lng;

  /// The phone's offset from UTC in minutes when the alarms were last planned.
  final int? deviceOffsetMinutes;

  /// The language the notification texts were written in.
  final String? lang;

  /// The moment of the last alarm that is on the phone (UTC).
  final DateTime? scheduledThrough;
  final DateTime? lastRefresh;

  const PrayerAlarmState({
    this.lat,
    this.lng,
    this.deviceOffsetMinutes,
    this.lang,
    this.scheduledThrough,
    this.lastRefresh,
  });

  static const _key = 'prayer_alarm_state';

  PrayerAlarmState copyWith({
    double? lat,
    double? lng,
    int? deviceOffsetMinutes,
    String? lang,
    DateTime? scheduledThrough,
    DateTime? lastRefresh,
  }) => PrayerAlarmState(
    lat: lat ?? this.lat,
    lng: lng ?? this.lng,
    deviceOffsetMinutes: deviceOffsetMinutes ?? this.deviceOffsetMinutes,
    lang: lang ?? this.lang,
    scheduledThrough: scheduledThrough ?? this.scheduledThrough,
    lastRefresh: lastRefresh ?? this.lastRefresh,
  );

  Map<String, dynamic> toJson() => {
    'lat': lat,
    'lng': lng,
    'off': deviceOffsetMinutes,
    'lang': lang,
    'through': scheduledThrough?.millisecondsSinceEpoch,
    'at': lastRefresh?.millisecondsSinceEpoch,
  };

  static DateTime? _ms(Object? v) =>
      v is int ? DateTime.fromMillisecondsSinceEpoch(v, isUtc: true) : null;

  factory PrayerAlarmState.fromJson(Map<String, dynamic> j) => PrayerAlarmState(
    lat: (j['lat'] as num?)?.toDouble(),
    lng: (j['lng'] as num?)?.toDouble(),
    deviceOffsetMinutes: j['off'] as int?,
    lang: j['lang'] as String?,
    scheduledThrough: _ms(j['through']),
    lastRefresh: _ms(j['at']),
  );

  static Future<PrayerAlarmState> load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null) return const PrayerAlarmState();
      return PrayerAlarmState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const PrayerAlarmState();
    }
  }

  Future<void> save() async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        _key,
        jsonEncode(toJson()),
      );
    } catch (_) {}
  }
}
