import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/painting.dart' show decodeImageFromList;
import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/services/business_photos/photo_processor.dart';
import 'package:konnect_kashmir/services/business_photos/photo_rules.dart';

/// A stand-in for the phone's WEBP/JPEG writer. It writes no real image: the
/// size it gives back is the number of pixels times the quality / 200, which is
/// roughly how a photo behaves (more quality, more bytes), so the size rules can
/// be tested. It records every picture it was asked to write.
class _ModelEncoder implements PhotoEncoder {
  final List<
    ({int width, int height, PhotoFormat format, int quality, Uint8List png})
  >
  calls = [];
  bool webpWorks = true;

  @override
  Future<Uint8List> encode(
    Uint8List png, {
    required int width,
    required int height,
    required PhotoFormat format,
    required int quality,
  }) async {
    calls.add((
      width: width,
      height: height,
      format: format,
      quality: quality,
      png: png,
    ));
    if (format == PhotoFormat.webp && !webpWorks) {
      throw UnsupportedError('no WEBP here');
    }
    return Uint8List((width * height * quality / 200).round());
  }
}

/// A PNG of [w] x [h]: a gentle gradient, or random noise (which a PNG cannot
/// squeeze, so the file is big).
Future<Uint8List> _png(
  WidgetTester t,
  int w,
  int h, {
  bool noise = false,
}) async {
  return (await t.runAsync(() async {
    final px = Uint8List(w * h * 4);
    final rnd = math.Random(7);
    for (var i = 0; i < w * h; i++) {
      final x = i % w, y = i ~/ w;
      // The red channel is flat, so the watermark's brightness can be measured.
      px[i * 4] = noise ? rnd.nextInt(256) : 100;
      px[i * 4 + 1] = noise ? rnd.nextInt(256) : (100 + (x * 40 ~/ w));
      px[i * 4 + 2] = noise ? rnd.nextInt(256) : (100 + (y * 40 ~/ h));
      px[i * 4 + 3] = 255;
    }
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(px, w, h, ui.PixelFormat.rgba8888, done.complete);
    final image = await done.future;
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }))!;
}

/// The pixels (RGBA) and size of a PNG.
Future<({Uint8List rgba, int width, int height})> _pixels(
  WidgetTester t,
  Uint8List png,
) async {
  return (await t.runAsync(() async {
    final image = await decodeImageFromList(png);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final out = (
      rgba: data!.buffer.asUint8List(),
      width: image.width,
      height: image.height,
    );
    image.dispose();
    return out;
  }))!;
}

/// The chunk names of a PNG file, in order.
List<String> _chunks(Uint8List png) {
  final out = <String>[];
  var i = 8;
  final view = ByteData.sublistView(png);
  while (i + 8 <= png.length) {
    final len = view.getUint32(i);
    out.add(String.fromCharCodes(png.sublist(i + 4, i + 8)));
    i += 12 + len;
  }
  return out;
}

void main() {
  late _ModelEncoder encoder;
  late UiPhotoProcessor processor;

  setUp(() {
    encoder = _ModelEncoder();
    processor = UiPhotoProcessor(encoder: encoder);
  });

  Future<ProcessedPhoto> run(WidgetTester t, Uint8List png) async => (await t
      .runAsync(() => processor.process(fileName: 'shop.png', bytes: png)))!;

  group('compression', () {
    testWidgets(
      'a photo of more than 5 MB ends up under 500 KB, 1600 px at most',
      (tester) async {
        final big = await _png(tester, 1800, 1400, noise: true);
        expect(big.length, greaterThan(5 * 1024 * 1024));
        expect(big.length, lessThan(kMaxPhotoFileBytes));

        final done = await run(tester, big);

        expect(done.inputBytes, big.length);
        expect(done.compressedBytes, lessThan(kPhotoTargetBytes));
        expect(done.watermarked.length, lessThan(kPhotoTargetBytes));
        // 1800 x 1400 became 1600 x 1244: the shape is the same.
        final first = encoder.calls.first;
        expect(first.width, 1600);
        expect(first.height, inInclusiveRange(1243, 1245));
        expect(
          encoder.calls.map((c) => c.quality).toSet().difference({
            80,
            70,
            60,
            50,
            45,
          }),
          isEmpty,
        );
        expect(done.format, PhotoFormat.webp);
        expect(done.format.extension, 'webp');
      },
    );

    testWidgets(
      'quality goes 80, 70, 60, 50 until the photo fits, for each copy',
      (tester) async {
        final done = await run(tester, await _png(tester, 1800, 1400));
        expect(done.compressedBytes, lessThanOrEqualTo(kPhotoTargetBytes));
        // 1600 x 1244 at the model's sizes: 80, 70 and 60 are too big, 50 fits.
        expect(encoder.calls.map((c) => c.quality), [
          80,
          70,
          60,
          50,
          80,
          70,
          60,
          50,
        ]);
      },
    );

    testWidgets('a photo is never enlarged', (tester) async {
      await run(tester, await _png(tester, 400, 300));
      expect(encoder.calls.first.width, 400);
      expect(encoder.calls.first.height, 300);
      // 400 x 300 at 80 is 48 KB: the first try fits.
      expect(encoder.calls.map((c) => c.quality), [80, 80]);
    });

    testWidgets('a tall photo keeps its shape', (tester) async {
      await run(tester, await _png(tester, 1000, 3200));
      expect(encoder.calls.first.width, 500);
      expect(encoder.calls.first.height, 1600);
    });

    testWidgets('exactly 1600 px is left alone', (tester) async {
      await run(tester, await _png(tester, 1600, 900));
      expect(encoder.calls.first.width, 1600);
      expect(encoder.calls.first.height, 900);
    });

    testWidgets('without WEBP on the device both copies are JPEG', (
      tester,
    ) async {
      encoder.webpWorks = false;
      final done = await run(tester, await _png(tester, 800, 600));
      expect(done.format, PhotoFormat.jpeg);
      expect(done.format.extension, 'jpg');
      expect(done.format.contentType, 'image/jpeg');
      // Tried WEBP once, then wrote the original copy as JPEG, and the
      // watermarked copy straight as JPEG as well (it did not try WEBP again).
      expect(encoder.calls.map((c) => c.format), [
        PhotoFormat.webp,
        PhotoFormat.jpeg,
        PhotoFormat.jpeg,
      ]);
      expect(done.original, isNotEmpty);
      expect(done.watermarked, isNotEmpty);
    });
  });

  /// Why [bytes] is refused, or null when it is accepted. (An error thrown
  /// inside runAsync would be lost, so it is caught inside.)
  Future<Object?> refusal(WidgetTester t, Uint8List bytes) =>
      t.runAsync<Object?>(() async {
        try {
          await processor.process(fileName: 'x', bytes: bytes);
          return null;
        } on PhotoRejected catch (e) {
          return e.problem;
        }
      });

  group('the files that are refused', () {
    testWidgets('over 15 MB, without even decoding it', (tester) async {
      final png = await _png(tester, 40, 40);
      final huge = Uint8List(kMaxPhotoFileBytes + 1)
        ..setRange(0, png.length, png);
      expect(await refusal(tester, huge), PhotoProblem.tooLarge);
      expect(encoder.calls, isEmpty);
    });

    testWidgets('a GIF, a PDF, text', (tester) async {
      for (final bytes in [
        Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 1, 0, 1, 0]),
        Uint8List.fromList('%PDF-1.4 hello'.codeUnits),
        Uint8List.fromList('not a photo at all'.codeUnits),
      ]) {
        expect(await refusal(tester, bytes), PhotoProblem.unsupportedType);
      }
      expect(encoder.calls, isEmpty);
    });

    testWidgets('a PNG that is damaged', (tester) async {
      final png = await _png(tester, 64, 64);
      expect(
        await refusal(tester, Uint8List.fromList(png.sublist(0, 40))),
        PhotoProblem.unreadable,
      );
      expect(encoder.calls, isEmpty);
    });

    testWidgets('an empty file', (tester) async {
      expect(await refusal(tester, Uint8List(0)), PhotoProblem.empty);
    });

    testWidgets('a good photo is not refused', (tester) async {
      expect(await refusal(tester, await _png(tester, 64, 64)), isNull);
    });
  });

  group('the watermark', () {
    testWidgets(
      'the compressed copy has none; the public copy has it in the bottom right, white at 60% with a dark outline',
      (tester) async {
        await run(tester, await _png(tester, 1000, 800));
        // The first picture written is the compressed copy, the first one after the
        // ladder of that copy is the watermarked one.
        final plain = encoder.calls.first.png;
        final marked = encoder.calls
            .firstWhere((c) => !listEquals(c.png, plain))
            .png;

        final a = await _pixels(tester, plain);
        final b = await _pixels(tester, marked);
        expect((a.width, a.height), (b.width, b.height));
        final w = a.width, h = a.height;

        var minX = w, minY = h, maxX = -1, maxY = -1;
        var brightest = 0, darkest = 255;
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            final i = (y * w + x) * 4;
            final same =
                a.rgba[i] == b.rgba[i] &&
                a.rgba[i + 1] == b.rgba[i + 1] &&
                a.rgba[i + 2] == b.rgba[i + 2];
            if (same) continue;
            minX = math.min(minX, x);
            minY = math.min(minY, y);
            maxX = math.max(maxX, x);
            maxY = math.max(maxY, y);
            brightest = math.max(brightest, b.rgba[i]);
            darkest = math.min(darkest, b.rgba[i]);
          }
        }
        expect(maxX, greaterThanOrEqualTo(0), reason: 'the watermark is drawn');
        // Only the bottom-right corner changed: nothing in the top part, nothing on
        // the left fifth, and not on the very edge.
        expect(minY, greaterThan(h * 0.8));
        expect(minX, greaterThan(w * 0.2));
        expect(maxX, lessThan(w - 1));
        expect(maxY, lessThan(h - 1));
        // It sits in the corner: the right end is near the right edge.
        expect(maxX, greaterThan(w * 0.9));
        expect(maxY, greaterThan(h * 0.9));
        // White at 60% over a background of about 100 is about 193; the outline is
        // dark. Never pure white.
        expect(brightest, inInclusiveRange(185, 200));
        expect(darkest, lessThan(70));
      },
    );

    testWidgets(
      'the same picture, copied, is the same picture: no watermark on the compressed copy',
      (tester) async {
        final src = await _png(tester, 600, 400);
        await run(tester, src);
        final plain = await _pixels(tester, encoder.calls.first.png);
        final original = await _pixels(tester, src);
        expect(plain.width, original.width);
        // Compare a corner sample: the bottom right of the compressed copy is
        // exactly the source picture there.
        final i = ((plain.height - 10) * plain.width + (plain.width - 10)) * 4;
        expect(plain.rgba.sublist(i, i + 3), original.rgba.sublist(i, i + 3));
      },
    );
  });

  group('a photo straight from a phone camera', () {
    // 200 x 100 as stored, with the EXIF flag "turn 90 degrees clockwise" and
    // GPS tags (a latitude). The left half is red, the right half blue.
    final fixture = File('test/fixtures/exif_rotated_with_gps.jpg');

    testWidgets('is turned upright, and what is written has no location in it', (
      tester,
    ) async {
      final bytes = fixture.readAsBytesSync();
      expect(
        String.fromCharCodes(bytes.take(200)),
        contains('Exif'),
        reason: 'the fixture really carries EXIF',
      );

      final done = (await tester.runAsync(
        () => processor.process(fileName: 'IMG_0001.jpg', bytes: bytes),
      ))!;

      // Upright: 100 wide, 200 tall (the stored 200 x 100 turned a quarter), the
      // red half now on top.
      final first = encoder.calls.first;
      expect((first.width, first.height), (100, 200));
      final p = await _pixels(tester, first.png);
      int red(int x, int y) => p.rgba[(y * p.width + x) * 4];
      int blue(int x, int y) => p.rgba[(y * p.width + x) * 4 + 2];
      expect(red(50, 10), greaterThan(200));
      expect(blue(50, 10), lessThan(60));
      expect(blue(50, 190), greaterThan(200));

      // Nothing of the camera's metadata is in either copy's source picture.
      for (final c in encoder.calls) {
        final text = String.fromCharCodes(c.png);
        expect(text, isNot(contains('Exif')));
        expect(text, isNot(contains('GPS')));
        expect(_chunks(c.png), isNot(contains('eXIf')));
      }
      expect(done.original, isNotEmpty);
    });
  });

  group('metadata', () {
    testWidgets('what is written carries no EXIF, text or location chunks', (
      tester,
    ) async {
      await run(tester, await _png(tester, 300, 200));
      expect(encoder.calls, isNotEmpty);
      for (final c in encoder.calls) {
        final chunks = _chunks(c.png);
        expect(chunks.first, 'IHDR');
        expect(chunks.last, 'IEND');
        for (final banned in ['eXIf', 'tEXt', 'zTXt', 'iTXt']) {
          expect(chunks, isNot(contains(banned)));
        }
      }
    });
  });
}
