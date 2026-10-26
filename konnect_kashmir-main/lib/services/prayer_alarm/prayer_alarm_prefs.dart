import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'prayer_alarm_planner.dart';

/// What the user chose: one switch for all five prayers together.
///
/// Nothing is switched on for anyone: the switch starts OFF. (Earlier versions
/// also saved one switch per prayer; those saved values are ignored.)
class PrayerAlarmPrefs {
  final bool enabled;
  const PrayerAlarmPrefs({this.enabled = false});

  static const _master = 'prayer_alarm_enabled';

  /// The prayers that will sound: all five, or none while the switch is off.
  Set<Prayer> get active => enabled ? {...Prayer.values} : const <Prayer>{};

  PrayerAlarmPrefs copyWith({bool? enabled}) =>
      PrayerAlarmPrefs(enabled: enabled ?? this.enabled);

  static Future<PrayerAlarmPrefs> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      return PrayerAlarmPrefs(enabled: sp.getBool(_master) ?? false);
    } catch (_) {
      return const PrayerAlarmPrefs();
    }
  }

  Future<void> save() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool(_master, enabled);
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
