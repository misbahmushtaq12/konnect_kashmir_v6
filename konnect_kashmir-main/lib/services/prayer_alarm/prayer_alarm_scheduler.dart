import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  /// The app may show notifications (and play their sound).
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
    Future<void> go(AndroidScheduleMode mode) => _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      payload: payload,
      scheduledDate: when,
      notificationDetails: _details,
      androidScheduleMode: mode,
    );

    // Exact alarms only when the phone allows them; otherwise the system may
    // deliver a few minutes late, which is better than not at all.
    final exact = await _canScheduleExact();
    try {
      await go(
        exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } on PlatformException catch (e) {
      if (e.code != 'exact_alarms_not_permitted') rethrow;
      await go(AndroidScheduleMode.inexactAllowWhileIdle);
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
      return AlarmPermissions(
        notifications: (await android.areNotificationsEnabled()) ?? true,
        exactAlarms: await _canScheduleExact(),
      );
    }
    final ios = _ios;
    if (ios != null) {
      final o = await ios.checkPermissions();
      return AlarmPermissions(
        notifications: o?.isEnabled ?? false,
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
