import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart' show ensureFirebaseStarted;

/// Where the events go. The real one is Firebase Analytics; the tests use a fake.
abstract class AnalyticsSink {
  Future<void> logEvent(String name, Map<String, Object> params);
  Future<void> logScreen(String name);
  Future<void> setUserId(String? id);
  Future<void> setUserProperty(String name, String? value);
}

/// Firebase Analytics. If Firebase is not set up (no config files, a test), every
/// call quietly does nothing.
class FirebaseAnalyticsSink implements AnalyticsSink {
  Future<FirebaseAnalytics?> _fa() async {
    try {
      await ensureFirebaseStarted();
      return FirebaseAnalytics.instance;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> logEvent(String name, Map<String, Object> params) async =>
      (await _fa())?.logEvent(name: name, parameters: params);

  @override
  Future<void> logScreen(String name) async => (await _fa())?.logScreenView(
    screenName: name,
    screenClass: 'Flutter',
  );

  @override
  Future<void> setUserId(String? id) async => (await _fa())?.setUserId(id: id);

  @override
  Future<void> setUserProperty(String name, String? value) async =>
      (await _fa())?.setUserProperty(name: name, value: value);
}

/// What people do in the app, sent to Firebase Analytics: screens (the user
/// journey), opens (every start, and one `daily_open` per day), who is signed in,
/// and a few key actions.
///
/// It never gets in the way: nothing here throws, waits, or shows anything. Nothing
/// is sent before [start], so screens and tests that never start it send nothing.
///
/// Not to be confused with `AnalyticsService`, which records searches in the
/// backend's own tables.
///
/// What is never sent: names, phone numbers, e-mail addresses, what was typed in
/// search, or anything else a person wrote. Only ids, categories and counts.
class AppAnalytics {
  /// [started] is for tests: they send without the lifecycle hooks of [start].
  AppAnalytics({
    AnalyticsSink? sink,
    DateTime Function()? clock,
    bool started = false,
  }) : _sink = sink ?? FirebaseAnalyticsSink(),
       _clock = clock ?? DateTime.now,
       _started = started;

  static AppAnalytics instance = AppAnalytics();

  final AnalyticsSink _sink;
  final DateTime Function() _clock;
  bool _started;

  /// Coming back after at least this long counts as a new open.
  static const Duration sessionGap = Duration(minutes: 30);

  String? _lastScreen;
  DateTime? _lastOpenAt;
  String? _userId;
  String? _role;

  /// The bottom tab that is showing (the Home screen is not a route of its own).
  String currentTab = 'home';

  // ── Starting ──────────────────────────────────────────────────────────────

  /// Starts sending. Call once, right after the app is shown.
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(_Lifecycle(this));
    unawaited(_opened('launch'));
  }

  void _guard(Future<void> Function() work) {
    if (!_started) return;
    unawaited(
      Future<void>.sync(work).catchError((Object e) {
        if (kDebugMode) debugPrint('[AppAnalytics] $e');
      }),
    );
  }

  // ── Opens ─────────────────────────────────────────────────────────────────

  /// The app came back to the front.
  void resumed() {
    if (!_started) return;
    final last = _lastOpenAt;
    if (last != null && _clock().difference(last) < sessionGap) return;
    unawaited(_opened('resume'));
  }

  Future<void> _opened(String how) async {
    _lastOpenAt = _clock();
    _guard(() => _sink.logEvent('app_open', {'how': how}));
    await _dailyOpen();
  }

  static const _kFirst = 'analytics_first_open_day';
  static const _kLast = 'analytics_last_open_day';
  static const _kStreak = 'analytics_streak';

  static String _day(DateTime t) {
    final d = t.toLocal();
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  /// One `daily_open` per calendar day (the phone's day), however often the app is
  /// opened: count them per day for "who opened the app today". `streak` is the
  /// number of days in a row, `days_since_first` the age of the install.
  Future<void> _dailyOpen() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final now = _clock().toLocal();
      final today = _day(now);
      final last = sp.getString(_kLast);
      if (last == today) return;
      final first = sp.getString(_kFirst) ?? today;
      final yesterday = _day(DateTime(now.year, now.month, now.day - 1));
      final streak = last == yesterday ? (sp.getInt(_kStreak) ?? 1) + 1 : 1;
      final age = DateTime(
        now.year,
        now.month,
        now.day,
      ).difference(DateTime.parse(first)).inDays;
      await sp.setString(_kFirst, first);
      await sp.setString(_kLast, today);
      await sp.setInt(_kStreak, streak);
      _guard(
        () => _sink.logEvent('daily_open', {
          'streak': streak,
          'days_since_first': age < 0 ? 0 : age,
        }),
      );
    } catch (_) {}
  }

  // ── Screens: the user journey ─────────────────────────────────────────────

  /// A screen came into view. The same screen twice in a row is counted once.
  void screen(String name) {
    if (!_started || name.isEmpty || name == _lastScreen) return;
    _lastScreen = name;
    _guard(() => _sink.logScreen(name));
  }

  /// A bottom tab was chosen.
  void tab(String name) {
    currentTab = name;
    screen(name);
  }

  // ── Who ───────────────────────────────────────────────────────────────────

  /// Who is signed in, or null for nobody. Only the account's id and role are sent.
  void setUser(String? id, String? role) {
    if (!_started) return;
    final before = _userId;
    final roleBefore = _role;
    _userId = id;
    _role = id == null ? null : role;
    if (before != id) _guard(() => _sink.setUserId(id));
    if (roleBefore != _role) {
      final value = _role;
      _guard(() => _sink.setUserProperty('user_role', value));
    }
    if (before != null && id == null) event('logout');
  }

  void setLanguage(String code) =>
      _guard(() => _sink.setUserProperty('app_language', code));

  // ── Events ────────────────────────────────────────────────────────────────

  /// Any event. Empty values are left out and long text is cut to what Firebase
  /// accepts (100 characters).
  void event(String name, [Map<String, Object?> params = const {}]) {
    final clean = <String, Object>{};
    params.forEach((k, v) {
      if (v == null) return;
      if (v is String) {
        final t = v.trim();
        if (t.isEmpty) return;
        clean[k] = t.length > 100 ? t.substring(0, 100) : t;
      } else if (v is num) {
        clean[k] = v;
      } else if (v is bool) {
        clean[k] = v ? 1 : 0;
      }
    });
    _guard(() => _sink.logEvent(name, clean));
  }

  /// Someone signed in ([newUser] true when the account was just made).
  void signedIn({required bool newUser}) =>
      event(newUser ? 'sign_up' : 'login', {'method': 'phone_otp'});

  /// A business page was opened.
  void viewBusiness(Object? id, {String? category}) =>
      event('view_business', {
        'business_id': id?.toString(),
        'category': category,
      });

  /// Call or WhatsApp was tapped on a business.
  void contactBusiness(String method, Object? id) =>
      event('contact_business', {'method': method, 'business_id': id?.toString()});

  /// A business's contact was unlocked (paid for with credits).
  void unlockContact(Object? id) =>
      event('unlock_contact', {'business_id': id?.toString()});

  /// A business was shared.
  void shareBusiness(Object? id) => event('share', {
    'content_type': 'business',
    'item_id': id?.toString(),
    'method': 'share_sheet',
  });

  /// A search ran. The words typed are not sent, only whether there were any.
  void search({String? category, int? results, bool hasText = false}) =>
      event('search', {
        'category': category,
        'results_count': results,
        'has_text': hasText,
      });

  /// The prayer-time beep was switched on or off.
  void prayerAlarm({required bool enabled}) =>
      event('prayer_alarm_toggle', {'enabled': enabled});
}

class _Lifecycle with WidgetsBindingObserver {
  final AppAnalytics _a;
  _Lifecycle(this._a);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _a.resumed();
  }
}

/// Logs a screen every time one comes into view, with no change needed on the
/// screens themselves: add it to `MaterialApp.navigatorObservers`.
///
/// A screen's name is its route name (`/login` -> `login`) or, for the many routes
/// without one, the name of its widget (`BusinessDetailsScreen` ->
/// `business_details`). Only widgets whose names end in Screen, Tab or Page are
/// used, so a name that cannot be read (an obfuscated build) is skipped rather than
/// logged as rubbish. Pop-ups and bottom sheets are not screens.
class AppRouteObserver extends NavigatorObserver {
  AppRouteObserver({AppAnalytics Function()? analytics})
    : _analytics = analytics ?? (() => AppAnalytics.instance);

  final AppAnalytics Function() _analytics;
  final Map<Route<dynamic>, String> _names = {};
  static const _tab = '@tab';

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _arrived(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) _names.remove(oldRoute);
    if (newRoute != null) _arrived(newRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _names.remove(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _names.remove(route);
    // Back on the screen underneath.
    if (previousRoute != null) _log(_names[previousRoute]);
  }

  void _log(String? name) {
    if (name == null) return;
    _analytics().screen(name == _tab ? _analytics().currentTab : name);
  }

  void _arrived(Route<dynamic> route) {
    if (route is! PageRoute) return;
    final named = routeScreenName(route.settings.name);
    if (named != null) {
      _names[route] = named;
      _log(named);
      return;
    }
    // Unnamed: read the widget once the page has been built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final name = _fromWidget(route);
      if (name == null) return;
      _names[route] = name;
      // Only if it is still the screen in front (it may have been popped already).
      if (route.isCurrent) _log(name);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  String? _fromWidget(Route<dynamic> route) {
    final ctx = route is ModalRoute ? route.subtreeContext : null;
    if (ctx == null) return null;
    String? found;
    var budget = 400;
    void visit(Element e) {
      if (found != null || budget-- <= 0) return;
      found = screenNameFromType(e.widget.runtimeType.toString());
      if (found == null) e.visitChildren(visit);
    }

    (ctx as Element).visitChildren(visit);
    return found == 'main_shell' ? _tab : found;
  }

  /// `/login` -> `login`; the start route and the shell are special.
  @visibleForTesting
  static String? routeScreenName(String? route) {
    if (route == null || route.isEmpty) return null;
    if (route == '/') return 'splash';
    if (route == '/home') return _tab;
    final s = route.split('?').first.replaceAll(RegExp(r'^/+'), '');
    if (s.isEmpty) return null;
    return s.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_').toLowerCase();
  }

  /// `BusinessDetailsScreen` -> `business_details`; null for any other widget.
  @visibleForTesting
  static String? screenNameFromType(String type) {
    if (type == 'MainShell') return 'main_shell';
    final m = RegExp(r'^([A-Z][A-Za-z0-9]*?)(Screen|Tab|Page)$').firstMatch(type);
    if (m == null) return null;
    final base = m.group(1)!;
    final snake = base
        .replaceAllMapped(RegExp(r'(?<=[a-z0-9])[A-Z]'), (x) => '_${x[0]}')
        .toLowerCase();
    return snake;
  }
}
