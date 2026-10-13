import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/services/analytics_service.dart';

/// The backend function `track_search` takes exactly these ten named fields; a
/// field it does not know makes the whole call fail, so the list must not drift.
const _fields = {
  'search_query',
  'results_count',
  'category',
  'district',
  'location',
  'filters_applied',
  'device_type',
  'source',
  'app_version',
  'session_id',
};

void main() {
  group('track_search payload', () {
    test('has exactly the fields the backend expects', () {
      final b = AnalyticsService.buildBody(
        query: 'plumber',
        resultsCount: 24,
        appVersion: '1.0.4',
      );
      expect(b.keys.toSet(), _fields);
    });

    test('matches the website example (source, device, lower-case district)', () {
      final b = AnalyticsService.buildBody(
        query: 'vendors in srinagar',
        resultsCount: 24,
        category: 'vendors',
        district: 'Srinagar',
        location: 'Lal Chowk',
        filters: {'verifiedOnly': true},
        appVersion: '1.2.3',
      );
      expect(b['search_query'], 'vendors in srinagar');
      expect(b['results_count'], 24);
      expect(b['category'], 'vendors');
      expect(b['district'], 'srinagar');
      expect(b['location'], 'Lal Chowk');
      expect(b['filters_applied'], {'verifiedOnly': true});
      expect(b['source'], 'app');
      expect(b['app_version'], '1.2.3');
      // Tests run as Android; iOS reports 'ios'.
      expect(b['device_type'], anyOf('android', 'ios'));
    });

    test('unset or blank area fields are sent as null, not empty text', () {
      final b = AnalyticsService.buildBody(
        query: 'electrician',
        resultsCount: 0,
        category: '  ',
        district: null,
        location: '',
        appVersion: '1.0.4',
      );
      expect(b['category'], isNull);
      expect(b['district'], isNull);
      expect(b['location'], isNull);
      expect(b['filters_applied'], isEmpty);
    });

    test('the typed text is trimmed and very long text is cut', () {
      expect(
        AnalyticsService.buildBody(
                query: '  plumber  ', resultsCount: 1, appVersion: 'x')['search_query'],
        'plumber',
      );
      final long = 'a' * 500;
      expect(
        (AnalyticsService.buildBody(
                query: long, resultsCount: 1, appVersion: 'x')['search_query'] as String)
            .length,
        200,
      );
    });

    test('the session id is a version-4 UUID and stays the same all session', () {
      final uuid = RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
      expect(AnalyticsService.sessionId, matches(uuid));
      final a = AnalyticsService.buildBody(
          query: 'a1', resultsCount: 1, appVersion: 'x')['session_id'];
      final b = AnalyticsService.buildBody(
          query: 'b2', resultsCount: 2, appVersion: 'x')['session_id'];
      expect(a, b);
      expect(a, AnalyticsService.sessionId);
    });
  });
}
