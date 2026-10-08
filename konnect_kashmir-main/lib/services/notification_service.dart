import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../providers/auth_provider.dart';
import '../screens/main_shell.dart';
import 'backend_config.dart';

/// Opens screens from a tapped notification.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  'konnect_alerts',
  'Alerts',
  description: 'Leads, credits and other account updates',
  importance: Importance.high,
);

final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
bool _localReady = false;

Future<void> _initLocal({void Function(String? payload)? onTap}) async {
  if (_localReady) return;
  await _local.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ),
    onDidReceiveNotificationResponse: (r) => onTap?.call(r.payload),
  );
  await _local
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_channel);
  _localReady = true;
}

Future<void> _showLocal(RemoteMessage m) async {
  final title = m.notification?.title ?? m.data['title']?.toString();
  final body = m.notification?.body ?? m.data['body']?.toString();
  if (title == null && body == null) return;
  await _initLocal();
  await _local.show(
    id: m.hashCode,
    title: title,
    body: body,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    ),
    payload: jsonEncode(m.data),
  );
}

/// Runs when a push arrives while the app is in the background or closed.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage m) async {
  try {
    await Firebase.initializeApp();
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
      await Firebase.initializeApp();
      _available = true;
    } catch (e) {
      debugPrint('[Push] Firebase is not configured, push disabled: $e');
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
    await _initLocal(onTap: (payload) {
      Map<String, dynamic> data = {};
      try {
        final d = jsonDecode(payload ?? '{}');
        if (d is Map<String, dynamic>) data = d;
      } catch (_) {}
      _open(data);
    });

    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true, badge: true, sound: true);
    FirebaseMessaging.onMessage.listen(_showLocal);
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

      _token ??= await FirebaseMessaging.instance.getToken();
      final token = _token;
      if (token == null) {
        _registeredFor = null;
        return;
      }

      final platform = defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
      final row = {
        'user_id': uid,
        'fcm_token': token,
        'platform': platform,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      // Same device, new account: move the token to this user; otherwise add it.
      final patch = await http
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
        final ins = await http
            .post(
              Uri.parse('$kSupabaseUrl/rest/v1/user_device_tokens'),
              headers: {..._headers(), 'Prefer': 'return=minimal'},
              body: jsonEncode(row),
            )
            .timeout(const Duration(seconds: 15));
        if (ins.statusCode >= 400 && ins.statusCode != 409) {
          debugPrint('[Push] token not saved (${ins.statusCode}): ${ins.body}');
          _registeredFor = null;
        }
      }
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
      await http
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
    if (kind.contains('lead') || kind.contains('call') || kind.contains('whatsapp')) {
      tab = MainShell.tabMyBusiness;
    } else if (kind.contains('credit') || kind.contains('transaction')) {
      tab = MainShell.tabProfile;
    }
    if (tab != null) MainShell.tabRequest.value = tab;
    if (!MainShell.isShowing) {
      appNavigatorKey.currentState
          ?.pushNamedAndRemoveUntil('/home', (route) => false);
    }
  }
}
