import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/services/business_photos/photo_rules.dart';

Uint8List _bytes(List<int> head) => Uint8List.fromList(head);

final _jpeg = _bytes([0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10, 0x4A, 0x46, 0x49, 0x46]);
final _png = _bytes([
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0,
  0,
  0,
  0,
]);
final _webp = _bytes([
  0x52,
  0x49,
  0x46,
  0x46,
  0x24,
  0,
  0,
  0,
  0x57,
  0x45,
  0x42,
  0x50,
  0x56,
  0x50,
]);
final _gif = _bytes([0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0, 0, 0, 0, 0, 0]);
// A HEIC file: "ftypheic" after the size.
final _heic = _bytes([
  0,
  0,
  0,
  0x18,
  0x66,
  0x74,
  0x79,
  0x70,
  0x68,
  0x65,
  0x69,
  0x63,
]);

void main() {
  group('which files are accepted', () {
    test('JPG, PNG and WEBP are, whatever the file is called', () {
      expect(sniffPhotoType(_jpeg), PhotoSourceType.jpeg);
      expect(sniffPhotoType(_png), PhotoSourceType.png);
      expect(sniffPhotoType(_webp), PhotoSourceType.webp);
      for (final head in [_jpeg, _png, _webp]) {
        expect(checkPhotoFile(length: 200 * 1024, head: head), isNull);
      }
    });

    test('anything else is not: GIF, HEIC, a PDF, text, nothing', () {
      for (final head in [
        _gif,
        _heic,
        _bytes([0x25, 0x50, 0x44, 0x46, 0x2D]), // %PDF-
        _bytes([0x68, 0x65, 0x6C, 0x6C, 0x6F]), // hello
        _bytes([0xFF, 0xD8]), // too short to be a JPEG
        _bytes([
          0x52,
          0x49,
          0x46,
          0x46,
          0,
          0,
          0,
          0,
          0x57,
          0x41,
          0x56,
          0x45,
        ]), // WAV
      ]) {
        expect(
          checkPhotoFile(length: 1000, head: head),
          PhotoProblem.unsupportedType,
        );
      }
    });

    test('15 MB is the most: exactly 15 MB passes, one byte more does not', () {
      expect(kMaxPhotoFileBytes, 15 * 1024 * 1024);
      expect(checkPhotoFile(length: kMaxPhotoFileBytes, head: _jpeg), isNull);
      expect(
        checkPhotoFile(length: kMaxPhotoFileBytes + 1, head: _jpeg),
        PhotoProblem.tooLarge,
      );
      expect(
        checkPhotoFile(length: 40 * 1024 * 1024, head: _png),
        PhotoProblem.tooLarge,
      );
    });

    test('an empty file is refused', () {
      expect(checkPhotoFile(length: 0, head: Uint8List(0)), PhotoProblem.empty);
    });

    test('a file that is too big is refused before its type is looked at', () {
      expect(
        checkPhotoFile(length: kMaxPhotoFileBytes + 1, head: _gif),
        PhotoProblem.tooLarge,
      );
    });
  });

  group('the size of a photo', () {
    test('the longest side comes down to 1600 px, the shape is kept', () {
      expect(fitWithin(4000, 3000), (width: 1600, height: 1200));
      expect(fitWithin(3000, 4000), (width: 1200, height: 1600));
      expect(fitWithin(1601, 1601), (width: 1600, height: 1600));
      expect(fitWithin(12000, 800), (width: 1600, height: 107));
    });

    test('a photo that is small enough is never enlarged', () {
      expect(fitWithin(1600, 1200), (width: 1600, height: 1200));
      expect(fitWithin(800, 600), (width: 800, height: 600));
      expect(fitWithin(1, 1), (width: 1, height: 1));
    });

    test('a very thin photo keeps at least one pixel', () {
      expect(fitWithin(100000, 10).height, greaterThanOrEqualTo(1));
    });
  });

  group('quality steps', () {
    test('start at 80, go down by 10, stop at 45', () {
      expect(photoQualityLadder(), [80, 70, 60, 50, 45]);
    });

    test(
      'the first result under 500 KB is kept, and no lower quality is tried',
      () async {
        final tried = <int>[];
        final done = await encodeWithinBudget((q) async {
          tried.add(q);
          // 100 KB per ten quality points: 80 -> 800 KB, 70 -> 700 KB, 60 -> 600 KB,
          // 50 -> 500 KB (this is the first one that fits)
          return Uint8List(q * 10 * 1024);
        });
        expect(tried, [80, 70, 60, 50]);
        expect(done.quality, 50);
        expect(done.bytes.length, lessThanOrEqualTo(kPhotoTargetBytes));
      },
    );

    test(
      'a photo that is small to begin with is written once, at 80',
      () async {
        final tried = <int>[];
        final done = await encodeWithinBudget((q) async {
          tried.add(q);
          return Uint8List(120 * 1024);
        });
        expect(tried, [80]);
        expect(done.quality, 80);
      },
    );

    test(
      'when even 45 is too big, the 45 result is returned (nothing worse)',
      () async {
        final tried = <int>[];
        final done = await encodeWithinBudget((q) async {
          tried.add(q);
          return Uint8List(900 * 1024);
        });
        expect(tried, [80, 70, 60, 50, 45]);
        expect(done.quality, 45);
      },
    );
  });

  group('the watermark', () {
    test('its text is "Konnect Kashmir", 60% opaque', () {
      expect(kWatermarkText, 'Konnect Kashmir');
      expect(kWatermarkOpacity, 0.6);
    });

    test('its size is 4.5% of the width, and never under 14 px', () {
      expect(watermarkFontSize(1600), closeTo(72, 1e-9));
      expect(watermarkFontSize(1000), closeTo(45, 1e-9));
      expect(watermarkFontSize(400), closeTo(18, 1e-9));
      expect(watermarkFontSize(311), 14); // 4.5% would be 13.995
      expect(watermarkFontSize(100), 14);
      expect(watermarkFontSize(0), 14);
    });
  });

  group('where the files go', () {
    test('the public copy and the private copy have the same name', () {
      expect(publicPhotoPath('v1', 'a.webp'), 'v1/public/a.webp');
      expect(originalPhotoPath('v1', 'a.webp'), 'v1/original/a.webp');
    });

    test('only a public path is a public path', () {
      expect(isPublicPhotoPath('v1/public/a.webp'), isTrue);
      expect(isPublicPhotoPath('v1/public/a.jpg'), isTrue);
      expect(isPublicPhotoPath('v1/original/a.webp'), isFalse);
      expect(isPublicPhotoPath('v1/public/sub/a.webp'), isFalse);
      expect(isPublicPhotoPath('public/a.webp'), isFalse);
      expect(isPublicPhotoPath('v1/publicity/a.webp'), isFalse);
      expect(isPublicPhotoPath('../v2/public/a.webp'), isFalse);
      expect(isPublicPhotoPath(''), isFalse);
    });

    test('the private copy that belongs to a public path', () {
      expect(originalPathOf('v1/public/a.webp'), 'v1/original/a.webp');
      expect(originalPathOf('v1/original/a.webp'), isNull);
      expect(originalPathOf('whatever'), isNull);
    });
  });

  test('sizes are shown in whole kilobytes', () {
    expect(kilobytes(0), 0);
    expect(kilobytes(1), 1);
    expect(kilobytes(1024), 1);
    expect(kilobytes(6 * 1024 * 1024), 6144);
    expect(kilobytes(312 * 1024 + 300), 312);
  });
}
