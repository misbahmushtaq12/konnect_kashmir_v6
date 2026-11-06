import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'local_notifications.dart';
import 'shared_http.dart';

import '../providers/auth_provider.dart';
import '../screens/main_shell.dart';
import 'backend_config.dart';

/// Opens screens from a tapped notification.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> _showLocal(RemoteMessage m) async {
  final title = m.notification?.title ?? m.data['title']?.toString();
  final body = m.notification?.body ?? m.data['body']?.toString();
  if (title == null && body == null) return;
  await ensureLocalNotifications();
  await localNotifications.show(
    id: m.hashCode,
    title: title,
    body: body,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        kAlertsChannel.id,
        kAlertsChannel.name,
        channelDescription: kAlertsChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@drawable/ic_notification',
        color: const Color(0xFF339985),
        // The full-colour app icon beside the text (the small icon must be one colour).
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      ),
    ),
    payload: jsonEncode(m.data),
  );
}

/// Starts Firebase. Android reads android/app/google-services.json by itself.
/// iOS gets the same project's public client settings here (taken from
/// GoogleService-Info.plist), so it does not depend on the Xcode project
/// bundling that file.
Future<void> _initFirebase() async {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyCMD4hAmdJyOkAbV6bCCcVEkwxjpbprz_g',
        appId: '1:305067967310:ios:5f9924194ae416eeb4d41f',
        messagingSenderId: '305067967310',
        projectId: 'konnect-kashmir1',
        storageBucket: 'konnect-kashmir1.firebasestorage.app',
        iosBundleId: 'com.mediamosiac.konnectkashmirapp',
      ),
    );
  } else {
    await Firebase.initializeApp();
  }
}

Future<void>? _firebaseStart;

/// Starts Firebase once, however many parts of the app ask (push messages and
/// analytics both need it). A failed start is tried again on the next ask.
Future<void> ensureFirebaseStarted() =>
    _firebaseStart ??= _initFirebase().catchError((Object e) {
      _firebaseStart = null;
      throw e;
    });

/// Runs when a push arrives while the app is in the background or closed.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage m) async {
  try {
    await _initFirebase();
  } catch (_) {
    return;
  }
  // A message with a "notification" part is already shown by the system; only
  // data-only messages need to be shown here.
  if (m.notification != null) return;
  await _showLocal(m);
}

/// Real push notifications (Firebase Cloud Messaging) for lead and account
/// events sent by the backend. This asks for the notification permission after
/// sign-in, registers this device in `user_device_tokens`, shows pushes that
/// arrive while the app is open, and opens the right screen when one is tapped.
///
/// It needs the Firebase config files of the project (android/app/google-services.json,
/// ios/Runner/GoogleService-Info.plist). Without them it quietly does nothing.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  /// Counts the push messages that arrive while the app is open, so the bell can
  /// ask for its number again.
  final ValueNotifier<int> pushArrived = ValueNotifier<int>(0);

  AuthProvider? _auth;
  bool _started = false;
  bool _available = false;
  String? _token;
  String? _registeredFor;

  Future<void> start(AuthProvider auth) async {
    if (_started) return;
    _started = true;
    _auth = auth;
    try {
      await ensureFirebaseStarted();
      _available = true;
    } catch (e) {
      debugPrint('[Push] Firebase is not configured, push disabled: $e');
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
    localNotificationTapHandler = (payload) {
      Map<String, dynamic> data = {};
      try {
        final d = jsonDecode(payload ?? '{}');
        if (d is Map<String, dynamic>) data = d;
      } catch (_) {}
      _open(data);
    };
    await ensureLocalNotifications();

    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true, badge: true, sound: true);
    FirebaseMessaging.onMessage.listen((m) {
      pushArrived.value++;
      // iOS already shows a foreground message that has a notification part (see
      // the presentation options above); a local copy would show it twice.
      // Android does not show it, so there the local copy is needed.
      if (defaultTargetPlatform == TargetPlatform.iOS && m.notification != null) {
        return;
      }
      _showLocal(m);
    });
    FirebaseMessaging.onMessageOpenedApp.listen((m) => _open(m.data));
    FirebaseMessaging.instance.onTokenRefresh.listen((t) {
      _token = t;
      _registeredFor = null;
      _register();
    });

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _open(initial.data));
    }

    auth.onBeforeLogout = _unregister;
    auth.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  void _onAuthChanged() {
    final uid = _auth?.userId;
    if (uid == null) {
      _registeredFor = null;
      return;
    }
    if (_registeredFor != uid) _register();
  }

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        'apikey': kSupabaseAnonKey,
        'Authorization': 'Bearer ${_auth?.accessToken ?? kSupabaseAnonKey}',
      };

  Future<void> _register() async {
    final auth = _auth;
    if (!_available || auth == null || auth.userId == null) return;
    final uid = auth.userId!;
    _registeredFor = uid; // set early so a burst of auth changes registers once
    try {
      // Native permission prompt (Android 13+ / iOS). Ignored if already decided.
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      // On iPhone the FCM token only exists after Apple has given the phone its
      // APNs token (which needs the Push capability, a real device and the APNs
      // key uploaded to Firebase). Asking for the FCM token earlier throws, so
      // wait a few seconds for it. If it never comes, give up quietly: the
      // token-refresh listener registers the device as soon as it does arrive.
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        String? apns = await FirebaseMessaging.instance.getAPNSToken();
        for (var i = 0; apns == null && i < 10; i++) {
          await Future<void>.delayed(const Duration(seconds: 1));
          apns = await FirebaseMessaging.instance.getAPNSToken();
        }
        if (apns == null) {
          debugPrint('[Push] no APNs token yet (simulator, Push capability or '
              'provisioning profile missing?)');
          _registeredFor = null;
          return;
        }
      }

      _token ??= await FirebaseMessaging.instance.getToken();
      final token = _token;
      if (token == null) {
        _registeredFor = null;
        return;
      }

      final platform = defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
      // Debug builds only (never in TestFlight, App Store or Play builds): lets a
      // developer copy this phone's token into Firebase "Send test message".
      if (kDebugMode) debugPrint('[Push] FCM token ($platform): $token');
      final row = {
        'user_id': uid,
        'fcm_token': token,
        'platform': platform,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      // Same device, new account: move the token to this user; otherwise add it.
      final patch = await sharedHttp
          .patch(
            Uri.parse('$kSupabaseUrl/rest/v1/user_device_tokens')
                .replace(queryParameters: {'fcm_token': 'eq.$token'}),
            headers: {..._headers(), 'Prefer': 'return=representation'},
            body: jsonEncode(row),
          )
          .timeout(const Duration(seconds: 15));
      final updated = patch.statusCode == 200 &&
          patch.body.isNotEmpty &&
          (jsonDecode(patch.body) as List).isNotEmpty;
      if (!updated) {
        final ins = await sharedHttp
            .post(
              Uri.parse('$kSupabaseUrl/rest/v1/user_device_tokens'),
              headers: {..._headers(), 'Prefer': 'return=minimal'},
              body: jsonEncode(row),
            )
            .timeout(const Duration(seconds: 15));
        if (ins.statusCode >= 400 && ins.statusCode != 409) {
          debugPrint('[Push] token not saved (${ins.statusCode}): ${ins.body}');
          _registeredFor = null;
          return;
        }
      }
      if (kDebugMode) debugPrint('[Push] token saved to the backend ($platform)');
    } catch (e) {
      debugPrint('[Push] register failed: $e');
      _registeredFor = null;
    }
  }

  /// Called just before sign-out so this phone stops getting that user's pushes.
  Future<void> _unregister() async {
    final token = _token;
    if (!_available || token == null) return;
    try {
      await sharedHttp
          .delete(
            Uri.parse('$kSupabaseUrl/rest/v1/user_device_tokens')
                .replace(queryParameters: {'fcm_token': 'eq.$token'}),
            headers: _headers(),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
    _registeredFor = null;
  }

  /// Opens the screen the notification is about.
  void _open(Map<String, dynamic> data) {
    final auth = _auth;
    if (auth == null || !auth.isAuthenticated) return;
    final kind = (data['type'] ?? data['screen'] ?? data['event'] ?? '')
        .toString()
        .toLowerCase();
    int? tab;
    if (kind.contains('lead') ||
        kind.contains('call') ||
        kind.contains('whatsapp') ||
        kind.contains('approv') ||
        kind.contains('reject') ||
        kind.contains('listing') ||
        // photo_pending / photo_approved / photo_rejected
        kind.contains('photo') ||
        kind.contains('business') ||
        kind.contains('vendor')) {
      tab = MainShell.tabMyBusiness;
    } else if (kind.contains('credit') || kind.contains('transaction')) {
      tab = MainShell.tabProfile;
    } else if (kind.contains('prayer')) {
      // A prayer-time alarm that was tapped: show the prayer times.
      tab = MainShell.tabDeen;
    }
    if (tab != null) MainShell.tabRequest.value = tab;
    if (!MainShell.isShowing) {
      appNavigatorKey.currentState
          ?.pushNamedAndRemoveUntil('/home', (route) => false);
    }
  }
}
