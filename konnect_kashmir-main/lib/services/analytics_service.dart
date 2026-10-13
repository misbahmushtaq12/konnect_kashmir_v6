import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'backend_config.dart';
import 'shared_http.dart';

/// Search analytics: sends the same `track_search` event to the backend that the
/// website sends, so searches made in the app and on the site end up in the same
/// analytics tables (`source` tells them apart).
///
/// It is fire-and-forget: it never delays the screen, never throws and never
/// shows an error. A search that cannot be recorded is simply not recorded.
class AnalyticsService {
  AnalyticsService._();

  /// One id per app launch, so the backend can group the searches of one visit.
  static final String sessionId = _uuid4();

  static String? _version;

  /// Records one search. [query] is what the customer typed; [resultsCount] is
  /// the real number of providers found (counted by the database).
  static void trackSearch({
    required String? token,
    required String query,
    required int resultsCount,
    String? category,
    String? district,
    String? location,
    Map<String, dynamic> filters = const {},
  }) {
    _send(
      token: token,
      query: query,
      resultsCount: resultsCount,
      category: category,
      district: district,
      location: location,
      filters: filters,
    );
  }

  static Future<String> _appVersion() async {
    final cached = _version;
    if (cached != null) return cached;
    try {
      final v = (await PackageInfo.fromPlatform()).version;
      return _version = v.isEmpty ? 'unknown' : v;
    } catch (_) {
      return 'unknown';
    }
  }

  /// The exact set of fields `track_search` accepts (a field the function does
  /// not know would make the whole call fail, so nothing extra is ever added).
  @visibleForTesting
  static Map<String, dynamic> buildBody({
    required String query,
    required int resultsCount,
    required String appVersion,
    String? category,
    String? district,
    String? location,
    Map<String, dynamic> filters = const {},
  }) {
    final q = query.trim();
    return {
      'search_query': q.length > 200 ? q.substring(0, 200) : q,
      'results_count': resultsCount,
      'category': _clean(category),
      // Lower-case, like the website's `district: 'srinagar'`.
      'district': _clean(district)?.toLowerCase(),
      'location': _clean(location),
      'filters_applied': filters,
      'device_type':
          defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      'source': 'app',
      'app_version': appVersion,
      'session_id': sessionId,
    };
  }

  static String? _clean(String? s) {
    final t = s?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  static Future<void> _send({
    required String? token,
    required String query,
    required int resultsCount,
    String? category,
    String? district,
    String? location,
    Map<String, dynamic> filters = const {},
  }) async {
    try {
      final body = jsonEncode(buildBody(
        query: query,
        resultsCount: resultsCount,
        appVersion: await _appVersion(),
        category: category,
        district: district,
        location: location,
        filters: filters,
      ));

      Future<int> post(String bearer) async => (await sharedHttp
              .post(
                Uri.parse('$kSupabaseUrl/rest/v1/rpc/track_search'),
                headers: {
                  'Content-Type': 'application/json',
                  'apikey': kSupabaseAnonKey,
                  'Authorization': 'Bearer $bearer',
                },
                body: body,
              )
              .timeout(const Duration(seconds: 10)))
          .statusCode;

      var status = await post(token ?? kSupabaseAnonKey);
      // A signed-in customer whose session has just expired is still counted.
      if (token != null && (status == 401 || status == 403)) {
        status = await post(kSupabaseAnonKey);
      }
      // Debug builds only, and only the status (never the search text).
      if (kDebugMode) debugPrint('[Analytics] track_search -> HTTP $status');
    } catch (_) {
      // Analytics must never affect the app.
    }
  }

  static String _uuid4() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40; // version 4
    b[8] = (b[8] & 0x3f) | 0x80; // RFC 4122 variant
    String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
    return '${h(0)}${h(1)}${h(2)}${h(3)}-${h(4)}${h(5)}-${h(6)}${h(7)}-'
        '${h(8)}${h(9)}-${h(10)}${h(11)}${h(12)}${h(13)}${h(14)}${h(15)}';
  }
}
