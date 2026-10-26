import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:timezone/timezone.dart' as tz;

import '../local_notifications.dart';

/// The Android channel the prayer beep plays on. A channel's sound cannot be
/// changed once the channel exists, so changing the beep (or its importance)
/// means a NEW id: raise the version (`konnect_prayer_v2`), put the old id in
/// [kLegacyPrayerChannelIds] and the next launch deletes it. People who switched
/// off this channel in the system settings will then have to switch it on again.
const String kPrayerChannelId = 'konnect_prayer_v1';
const List<String> kLegacyPrayerChannelIds = [];

/// The beep file: `android/app/src/main/res/raw/prayer_beep.wav` (Android) and
/// `ios/Runner/prayer_beep.wav` (iOS, which needs the extension).
const String kPrayerSoundAndroid = 'prayer_beep';
const String kPrayerSoundIos = 'prayer_beep.wav';

const AndroidNotificationChannel kPrayerChannel = AndroidNotificationChannel(
  kPrayerChannelId,
  'Prayer alarms',
  description: 'A short beep at each prayer time',
  importance: Importance.high,
  playSound: true,
  sound: RawResourceAndroidNotificationSound(kPrayerSoundAndroid),
);

/// Whether the user's own settings for the Prayer alarms category still let it
/// beep. Android lets people switch a category off, make it silent (low
/// importance) or take its sound away, all without touching the app-wide
/// "notifications" switch. A category that does not exist yet (null) is fine: it
/// is created with the right settings.
bool prayerChannelCanSound(AndroidNotificationChannel? channel) =>
    channel == null ||
    channel.importance == Importance.unspecified ||
    (channel.importance.value >= Importance.defaultImportance.value &&
        channel.playSound);

/// A notification that is waiting on the phone.
class PendingAlarm {
  final int id;
  final String? title;
  final String? body;
  final String? payload;
  const PendingAlarm(this.id, this.title, this.body, this.payload);
}

/// What the phone lets the app do.
class AlarmPermissions {
  /// The app may show notifications and play their sound. On iPhone that is
  /// notifications AND Sounds switched on in its settings; on Android it is
  /// notifications on AND the Prayer alarms category neither off nor silent.
  final bool notifications;

  /// The app may fire at the exact minute. Always true where that is not a
  /// separate permission (iOS, Android 11 and older).
  final bool exactAlarms;
  const AlarmPermissions({
    required this.notifications,
    required this.exactAlarms,
  });
}

/// The part of the phone the alarm service talks to. The real one uses local
/// notifications; the tests use a fake.
abstract class AlarmScheduler {
  /// The most notifications the system keeps waiting for this app at once, or
  /// null when there is no small limit (Android). On iOS it is 64, and that
  /// count is shared with every other local notification of the app.
  int? get pendingLimit;

  Future<void> ensureReady();
  Future<List<PendingAlarm>> pending();
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String payload,
  });
  Future<void> cancel(int id);

  Future<AlarmPermissions> permissions();

  /// Shows the system permission dialog for notifications; with [exactAlarms]
  /// it also opens the system screen where exact alarms are allowed (Android 12+).
  Future<AlarmPermissions> requestPermissions({bool exactAlarms = false});

  /// Opens this app's page in the system settings.
  Future<void> openSettings();
}

/// Local notifications on the phone: they are kept by the operating system and
/// fire without the app running and without the internet.
class LocalAlarmScheduler implements AlarmScheduler {
  FlutterLocalNotificationsPlugin get _plugin => localNotifications;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  bool get _isIos => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  int? get pendingLimit => _isIos ? 64 : null;

  @override
  Future<void> ensureReady() async {
    await ensureLocalNotifications();
    final android = _android;
    if (android == null) return;
    await android.createNotificationChannel(kPrayerChannel);
    for (final old in kLegacyPrayerChannelIds) {
      await android.deleteNotificationChannel(channelId: old);
    }
  }

  @override
  Future<List<PendingAlarm>> pending() async => [
    for (final r in await _plugin.pendingNotificationRequests())
      PendingAlarm(r.id, r.title, r.body, r.payload),
  ];

  NotificationDetails get _details => const NotificationDetails(
    android: AndroidNotificationDetails(
      kPrayerChannelId,
      'Prayer alarms',
      channelDescription: 'A short beep at each prayer time',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(kPrayerSoundAndroid),
      category: AndroidNotificationCategory.reminder,
      icon: '@drawable/ic_notification',
      color: Color(0xFF339985),
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: false,
      sound: kPrayerSoundIos,
    ),
  );

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String payload,
  }) async {
    // One moment in time; the zone only labels it.
    final when = tz.TZDateTime.from(at, tz.UTC);
    // Always exact: the beep rings at the exact minute. (The service only sets
    // alarms once the phone allows exact alarms.)
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      payload: payload,
      scheduledDate: when,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<bool> _channelCanSound(AndroidFlutterLocalNotificationsPlugin a) async {
    try {
      final channels = await a.getNotificationChannels();
      final mine = channels?.where((c) => c.id == kPrayerChannelId);
      return prayerChannelCanSound(
        mine == null || mine.isEmpty ? null : mine.first,
      );
    } catch (_) {
      return true; // cannot tell: do not warn about something unknown
    }
  }

  Future<bool> _canScheduleExact() async {
    final android = _android;
    if (android == null) return true;
    return (await android.canScheduleExactNotifications()) ?? true;
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<AlarmPermissions> permissions() async {
    final android = _android;
    if (android != null) {
      final appOn = (await android.areNotificationsEnabled()) ?? true;
      return AlarmPermissions(
        notifications: appOn && await _channelCanSound(android),
        exactAlarms: await _canScheduleExact(),
      );
    }
    final ios = _ios;
    if (ios != null) {
      final o = await ios.checkPermissions();
      // The alarm is a beep: notifications that are allowed but have their Sounds
      // switched off in the iPhone's settings cannot ring, so they do not count.
      return AlarmPermissions(
        notifications: (o?.isEnabled ?? false) && (o?.isSoundEnabled ?? false),
        exactAlarms: true,
      );
    }
    return const AlarmPermissions(notifications: false, exactAlarms: true);
  }

  @override
  Future<AlarmPermissions> requestPermissions({
    bool exactAlarms = false,
  }) async {
    await ensureLocalNotifications();
    final android = _android;
    if (android != null) {
      await android.requestNotificationsPermission();
      if (exactAlarms) await android.requestExactAlarmsPermission();
    } else {
      await _ios?.requestPermissions(alert: true, sound: true);
    }
    return permissions();
  }

  @override
  Future<void> openSettings() => Geolocator.openAppSettings();
}
