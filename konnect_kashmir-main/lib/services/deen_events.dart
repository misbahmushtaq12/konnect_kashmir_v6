import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'analytics_service.dart';
import 'backend_config.dart';
import 'shared_http.dart';

/// Sends one row to a table and returns the HTTP status. [bearer] is the key or
/// token to send in the Authorization header.
typedef EventPoster =
    Future<int> Function(String table, Map<String, Object?> row, String bearer);

/// What people do in Deen, recorded in the same two tables the website writes to
/// (so the admin's Deen Analytics shows the app next to the website):
///
/// * `audio_play_events` - `play`, `pause`, `stop`, `complete` of a recitation, with
///   the reciter, the surah and the seconds actually listened.
/// * `deen_events` - `page_view`, `compass_started`, `madhhab_change`,
///   `method_change`, with a small `meta`.
///
/// Every row carries `source = 'app'` (the website writes `'website'`). Rows are
/// sent with the app's public key, or the signed-in user's own token, and the
/// database's row-level-security policies decide what is accepted: nothing here
/// uses a secret. If the signed-in token is refused (expired, or a policy says no),
/// the row is sent once more as an anonymous one.
///
/// Like the other analytics it never throws, never waits and never shows anything,
/// and it sends nothing before [start].
class DeenEvents {
  DeenEvents({
    EventPoster? poster,
    String Function()? sessionId,
    bool started = false,
  }) : _poster = poster ?? _httpPost,
       _sessionId = sessionId ?? (() => AnalyticsService.sessionId),
       _started = started;

  static DeenEvents instance = DeenEvents();

  final EventPoster _poster;
  final String Function() _sessionId;
  bool _started;
  String? Function() _token = () => null;
  String? Function() _userId = () => null;

  /// The audio event names the database and the dashboard know (the website uses
  /// the same ones).
  static const audioTypes = {'play', 'pause', 'stop', 'complete'};

  /// The Deen event names the dashboard knows.
  static const deenTypes = {
    'page_view',
    'compass_started',
    'madhhab_change',
    'method_change',
  };

  /// Starts sending. [token] and [userId] say who is signed in (null: nobody).
  void start({String? Function()? token, String? Function()? userId}) {
    if (token != null) _token = token;
    if (userId != null) _userId = userId;
    _started = true;
  }

  // ── What is recorded ──────────────────────────────────────────────────────

  /// A recitation event. [reciterId] is the `audio_reciters.id` (null for the
  /// built-in fallback list); [seconds] is the time actually listened.
  void audio(
    String type, {
    String? reciterId,
    int? surah,
    String? trackId,
    int seconds = 0,
  }) {
    if (!audioTypes.contains(type)) return;
    _send('audio_play_events', audioRow(type, reciterId, surah, trackId, seconds));
  }

  /// A Deen screen event, with the few fields the dashboard understands in [meta].
  void deen(String type, [Map<String, String> meta = const {}]) {
    if (!deenTypes.contains(type)) return;
    _send('deen_events', deenRow(type, meta));
  }

  // ── Rows ──────────────────────────────────────────────────────────────────

  @visibleForTesting
  Map<String, Object?> audioRow(
    String type,
    String? reciterId,
    int? surah,
    String? trackId,
    int seconds,
  ) => {
    'event_type': type,
    'track_id': trackId,
    'reciter_id': reciterId,
    'surah_number': surah,
    'listened_seconds': seconds.clamp(0, 86400),
    'source': 'app',
    'session_id': _sessionId(),
  };

  @visibleForTesting
  Map<String, Object?> deenRow(String type, Map<String, String> meta) {
    // Only what the dashboard reads, cut to the same lengths as the website.
    final m = <String, String>{};
    String cut(String s, int n) => s.length > n ? s.substring(0, n) : s;
    if (meta['madhhab'] != null) m['madhhab'] = cut(meta['madhhab']!, 40);
    if (meta['method'] != null) m['method'] = cut(meta['method']!, 80);
    if (meta['city'] != null) m['city'] = cut(meta['city']!, 80);
    return {
      'event_type': type,
      'meta': m,
      'session_id': _sessionId(),
      'source': 'app',
    };
  }

  // ── Sending ───────────────────────────────────────────────────────────────

  void _send(String table, Map<String, Object?> row) {
    if (!_started) return;
    unawaited(_deliver(table, row));
  }

  Future<void> _deliver(String table, Map<String, Object?> row) async {
    try {
      final token = _token();
      final uid = _userId();
      final signedIn = token != null && token.isNotEmpty && uid != null;
      var status = await _poster(table, {
        ...row,
        'user_id': signedIn ? uid : null,
      }, signedIn ? token : kSupabaseAnonKey);
      // The signed-in token was refused (expired, or the policy says no): the
      // event still counts, as an anonymous one.
      if (signedIn && (status == 401 || status == 403)) {
        status = await _poster(table, {
          ...row,
          'user_id': null,
        }, kSupabaseAnonKey);
      }
      // Debug builds only, and only the status.
      if (kDebugMode) {
        debugPrint('[DeenEvents] $table ${row['event_type']} -> HTTP $status');
      }
    } catch (_) {
      // Analytics must never affect the app.
    }
  }

  static Future<int> _httpPost(
    String table,
    Map<String, Object?> row,
    String bearer,
  ) async => (await sharedHttp
          .post(
            Uri.parse('$kSupabaseUrl/rest/v1/$table'),
            headers: {
              'Content-Type': 'application/json',
              'apikey': kSupabaseAnonKey,
              'Authorization': 'Bearer $bearer',
              'Prefer': 'return=minimal',
            },
            body: jsonEncode(row),
          )
          .timeout(const Duration(seconds: 10)))
      .statusCode;
}
