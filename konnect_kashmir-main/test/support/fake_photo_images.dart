import 'dart:async';
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

/// A 1x1 picture of one colour (to tell photos apart by their pixels).
Future<ui.Image> solidImage(WidgetTester tester, ui.Color color) async {
  return (await tester.runAsync(() async {
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      Uint8List.fromList([
        (color.r * 255).round(),
        (color.g * 255).round(),
        (color.b * 255).round(),
        255,
      ]),
      1,
      1,
      ui.PixelFormat.rgba8888,
      done.complete,
    );
    return done.future;
  }))!;
}

/// Stands in for the network image cache in widget tests: every photo shows a
/// 1x1 picture at once, except
///  * those whose cache key is in [broken], which fail to load (as a bad or
///    expired link does), and
///  * those in [slow], which arrive only when [release] is called (a slow
///    network).
/// [requested] lists the cache keys that were asked for (once per image the
/// cache had to load), so a test can see what would have been downloaded;
/// [providersMade] lists every time a widget asked for a provider, which shows
/// when photos were rebuilt.
class FakePhotoImages {
  FakePhotoImages._(this._image, this.broken, this.slow, this.pictures);

  final ui.Image _image;
  final Set<String> broken;
  final Set<String> slow;

  /// Pictures to show instead of the default one, by cache key.
  final Map<String, ui.Image> pictures;
  final List<String> requested = [];
  final List<String> providersMade = [];
  final Map<String, Completer<void>> _gates = {};

  Completer<void> _gate(String key) =>
      _gates.putIfAbsent(key, () => Completer<void>());

  /// The photo with this cache key arrives.
  void release(String key) {
    if (!_gate(key).isCompleted) _gate(key).complete();
  }

  /// Every held-back photo arrives.
  void releaseAll() => slow.forEach(release);

  /// Installs the fake for one test (call inside the test, so the image can be
  /// decoded outside the fake clock) and removes it when the test ends.
  static Future<FakePhotoImages> install(
    WidgetTester tester, {
    Set<String> broken = const {},
    Set<String> slow = const {},
    Map<String, ui.Image> pictures = const {},
  }) async {
    // The global image cache is keyed by the provider, so a photo shown by an
    // earlier test would be served from it and never reach this fake.
    _forgetImages();
    addTearDown(_forgetImages);
    final image = await tester.runAsync(() => decodeImageFromList(kTestPng));
    final fake = FakePhotoImages._(image!, {...broken}, {...slow}, {
      ...pictures,
    });
    final before = BusinessPhotoImages.factory;
    BusinessPhotoImages.factory = (photo) {
      fake.providersMade.add(photo.cacheKey);
      return _FakeProvider(fake, photo);
    };
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
    final k = photo.cacheKey;
    fake.requested.add(k);
    if (fake.broken.contains(k)) {
      return OneFrameImageStreamCompleter(
        Future<ImageInfo>.error(Exception('the link does not work')),
      );
    }
    ImageInfo info() =>
        ImageInfo(image: (fake.pictures[k] ?? fake._image).clone());
    final gate = fake.slow.contains(k) ? fake._gate(k) : null;
    if (gate == null || gate.isCompleted) {
      return OneFrameImageStreamCompleter(SynchronousFuture<ImageInfo>(info()));
    }
    return OneFrameImageStreamCompleter(gate.future.then((_) => info()));
  }

  @override
  bool operator ==(Object other) =>
      other is _FakeProvider && other.photo == photo;

  @override
  int get hashCode => photo.hashCode;
}
