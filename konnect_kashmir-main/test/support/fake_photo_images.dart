import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/services/business_photos/photo_images.dart';

/// A 1x1 PNG.
final Uint8List kTestPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

/// Stands in for the network image cache in widget tests: every photo shows a
/// 1x1 picture at once, except those whose cache key is in [broken], which fail
/// to load (as a bad or expired link does). [requested] lists the cache keys that
/// were asked for, so a test can see what would have been downloaded.
class FakePhotoImages {
  FakePhotoImages._(this._image, this.broken);

  final ui.Image _image;
  final Set<String> broken;
  final List<String> requested = [];

  /// Installs the fake for one test (call inside the test, so the image can be
  /// decoded outside the fake clock) and removes it when the test ends.
  static Future<FakePhotoImages> install(
    WidgetTester tester, {
    Set<String> broken = const {},
  }) async {
    // The global image cache is keyed by the provider, so a photo shown by an
    // earlier test would be served from it and never reach this fake.
    _forgetImages();
    addTearDown(_forgetImages);
    final image = await tester.runAsync(() => decodeImageFromList(kTestPng));
    final fake = FakePhotoImages._(image!, {...broken});
    final before = BusinessPhotoImages.factory;
    BusinessPhotoImages.factory = (photo) => _FakeProvider(fake, photo);
    addTearDown(() => BusinessPhotoImages.factory = before);
    return fake;
  }
}

void _forgetImages() {
  PaintingBinding.instance.imageCache
    ..clear()
    ..clearLiveImages();
}

class _FakeProvider extends ImageProvider<_FakeProvider> {
  final FakePhotoImages fake;
  final GalleryPhoto photo;
  const _FakeProvider(this.fake, this.photo);

  @override
  Future<_FakeProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_FakeProvider>(this);

  @override
  ImageStreamCompleter loadImage(
    _FakeProvider key,
    ImageDecoderCallback decode,
  ) {
    fake.requested.add(photo.cacheKey);
    if (fake.broken.contains(photo.cacheKey)) {
      return OneFrameImageStreamCompleter(
        Future<ImageInfo>.error(Exception('the link does not work')),
      );
    }
    return OneFrameImageStreamCompleter(
      SynchronousFuture<ImageInfo>(ImageInfo(image: fake._image.clone())),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is _FakeProvider && other.photo == photo;

  @override
  int get hashCode => photo.hashCode;
}
