import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// The one local-notification plugin of the app, shared by the push messages and
/// the prayer alarms, so it is set up once and a tap is always handled in one place.

/// The channel for leads, credits and other account updates.
const AndroidNotificationChannel kAlertsChannel = AndroidNotificationChannel(
  'konnect_alerts',
  'Alerts',
  description: 'Leads, credits and other account updates',
  importance: Importance.high,
);

final FlutterLocalNotificationsPlugin localNotifications =
    FlutterLocalNotificationsPlugin();

/// Called with the payload of a notification the user tapped. Set by whoever
/// opens screens (see NotificationService); it may be set before or after
/// [ensureLocalNotifications].
void Function(String? payload)? localNotificationTapHandler;

Future<void>? _ready;

/// Safe to call any number of times and from several places at once.
Future<void> ensureLocalNotifications() =>
    _ready ??= _init().catchError((Object e) {
      _ready = null; // try again next time
      throw e;
    });

Future<void> _init() async {
  await localNotifications.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@drawable/ic_notification'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ),
    onDidReceiveNotificationResponse: (r) =>
        localNotificationTapHandler?.call(r.payload),
  );
  await localNotifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(kAlertsChannel);
}
