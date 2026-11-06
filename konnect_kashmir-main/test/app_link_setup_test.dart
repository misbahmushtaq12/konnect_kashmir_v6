import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/services/app_links.dart';
import 'package:konnect_kashmir/services/business_share.dart';

/// The shared business link only opens the app when four things agree: the
/// address the app shares, the Android manifest, the iPhone entitlements and the
/// two proof files the website serves (docs/well-known). Nothing here can run a
/// phone, but it stops any one of them drifting away from the others unnoticed.
void main() {
  String read(String path) => File(path).readAsStringSync();

  final manifest = read('android/app/src/main/AndroidManifest.xml');
  final gradle = read('android/app/build.gradle.kts');
  final assetLinks =
      jsonDecode(read('docs/well-known/assetlinks.json')) as List<dynamic>;
  final aasa = jsonDecode(read('docs/well-known/apple-app-site-association'))
      as Map<String, dynamic>;

  group('the address the app shares', () {
    test('is https://konnectkashmir.com/business/<id>, and the app reads it back', () {
      for (final id in [
        'a38a59e1-23a6-4a2f-9394-ce77d50c8e3c',
        '3f2a9c1e-7b64-4d0a-9e55-1c2d3e4f5a6b',
        '42',
        'abc-DEF-9',
      ]) {
        final url = businessUrl(id)!;
        expect(url, 'https://konnectkashmir.com/business/$id');
        expect(AppLinks.businessId(url), id, reason: url);
        expect(AppLinks.isAppLink(url), isTrue, reason: url);
      }
    });

    test('is the host and path the app declares to Android', () {
      final u = Uri.parse(businessUrl('x')!);
      expect(u.scheme, 'https');
      expect(manifest, contains('android:host="${u.host}"'));
      expect(manifest, contains('android:pathPrefix="/business/"'));
      expect(u.path, startsWith('/business/'));
    });
  });

  group('Android', () {
    test('the filter is a verified https link filter on konnectkashmir.com', () {
      expect(manifest, contains('android:autoVerify="true"'));
      expect(manifest, contains('android.intent.action.VIEW'));
      expect(manifest, contains('android.intent.category.BROWSABLE'));
      expect(manifest, contains('android:scheme="https"'));
      expect(manifest, contains('android:host="konnectkashmir.com"'));
      // www redirects, so it can never be verified (and one host that fails
      // verification breaks the whole filter on Android 11 and older).
      expect(manifest, isNot(contains('android:host="www.konnectkashmir.com"')));
      // The links are handed to the app's own routes.
      expect(manifest, contains('android:name="flutter_deeplinking_enabled"'));
    });

    test('the proof file names the app id the app is built with', () {
      final applicationId =
          RegExp(r'applicationId\s*=\s*"([^"]+)"').firstMatch(gradle)!.group(1);
      expect(applicationId, 'com.mediamosiac.konnect_kashmir');

      expect(assetLinks, hasLength(1));
      final statement = assetLinks.single as Map<String, dynamic>;
      expect(statement['relation'],
          ['delegate_permission/common.handle_all_urls']);
      final target = statement['target'] as Map<String, dynamic>;
      expect(target['namespace'], 'android_app');
      expect(target['package_name'], applicationId);
    });

    test('and lists both signing certificates (Play app signing and upload)', () {
      final fingerprints = (((assetLinks.single as Map)['target']
              as Map)['sha256_cert_fingerprints'] as List)
          .cast<String>();
      final shape = RegExp(r'^([0-9A-F]{2}:){31}[0-9A-F]{2}$');
      for (final f in fingerprints) {
        expect(shape.hasMatch(f), isTrue, reason: 'not a SHA-256 fingerprint: $f');
      }
      expect(fingerprints.toSet(), hasLength(fingerprints.length));
      // Play app signing key (signs what Google Play delivers) and the upload
      // key (android/key.properties; signs builds installed straight from a file).
      expect(fingerprints, hasLength(2));
      expect(fingerprints.any((f) => f.startsWith('21:FA:63:64')), isTrue);
      expect(fingerprints.any((f) => f.startsWith('F3:FA:B6:77')), isTrue);
    });
  });

  group('iPhone', () {
    test('the app declares the domain', () {
      expect(read('ios/Runner/Runner.entitlements'),
          contains('<string>applinks:konnectkashmir.com</string>'));
      expect(read('ios/Runner/Info.plist'),
          matches(RegExp(r'<key>FlutterDeepLinkingEnabled</key>\s*<true/>')));
      // The entitlements file is the one the Runner target signs with.
      expect(read('ios/Runner.xcodeproj/project.pbxproj'),
          contains('CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'));
    });

    test('the proof file names the bundle id and sends /business/* to the app', () {
      final bundleId = RegExp(
              r'PRODUCT_BUNDLE_IDENTIFIER = ([A-Za-z0-9.]+);',
              multiLine: true)
          .allMatches(read('ios/Runner.xcodeproj/project.pbxproj'))
          .map((m) => m.group(1)!)
          .where((id) => !id.endsWith('.RunnerTests'))
          .toSet();
      expect(bundleId, {'com.mediamosiac.konnectkashmirapp'});

      final details = ((aasa['applinks'] as Map)['details'] as List).cast<Map>();
      expect(details, hasLength(1));
      final appIds = (details.single['appIDs'] as List).cast<String>();
      expect(appIds, hasLength(1));
      // <Apple Team ID>.<bundle id>
      expect(appIds.single, matches(RegExp(r'^[A-Z0-9]{10}\.')));
      expect(appIds.single.substring(11), bundleId.single);

      final paths =
          (details.single['components'] as List).map((c) => (c as Map)['/']);
      expect(paths, containsAll(['/go', '/business/*']));
    });
  });
}
