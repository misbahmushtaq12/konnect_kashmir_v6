import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/services/api_service.dart';

/// What a shared business link finds when the app asks the backend for it:
/// the business, "no such business" (a deleted one, or an id that is not even a
/// UUID), or "could not ask" (no internet, server trouble: the screen offers a
/// retry). The bodies are the real answers of the backend.
void main() {
  const id = 'a38a59e1-23a6-4a2f-9394-ce77d50c8e3c';

  group('the answer to the business lookup', () {
    test('a business: its record', () {
      final body = jsonEncode([
        {'id': id, 'business_name': 'Sarwar Hussain', 'is_approved': true}
      ]);
      final v = ApiService.vendorDetailsFromResponse(200, body);
      expect(v, isNotNull);
      expect(v!['id'], id);
      expect(v['business_name'], 'Sarwar Hussain');
    });

    test('a deleted, hidden or unknown business (an empty list): none', () {
      expect(ApiService.vendorDetailsFromResponse(200, '[]'), isNull);
    });

    test('an id that is not a UUID (the database refuses it, 22P02): none, not an error',
        () {
      const body =
          '{"code":"22P02","details":null,"hint":null,"message":"invalid input syntax for type uuid: \\"42\\""}';
      expect(ApiService.vendorDetailsFromResponse(400, body), isNull);
    });

    test('anything else that went wrong is "could not ask", so a retry is offered', () {
      for (final status in [400, 401, 403, 404, 429, 500, 502, 503]) {
        expect(
          () => ApiService.vendorDetailsFromResponse(status, '{"message":"x"}'),
          throwsException,
          reason: 'HTTP $status',
        );
      }
      // An answer that is not what the backend sends is not "no business" either.
      expect(() => ApiService.vendorDetailsFromResponse(200, '<html>'),
          throwsA(anything));
    });
  });
}
