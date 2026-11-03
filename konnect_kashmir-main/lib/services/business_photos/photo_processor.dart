import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'photo_rules.dart';

/// A photo ready to upload: the compressed copy that is kept private, and the
/// same photo with the watermark, which is the one people see.
class ProcessedPhoto {
  /// The name of the file the owner picked, for messages.
  final String fileName;
  final Uint8List original;
  final Uint8List watermarked;
  final PhotoFormat format;

  /// Size of the picked file, in bytes.
  final int inputBytes;

  const ProcessedPhoto({
    required this.fileName,
    required this.original,
    required this.watermarked,
    required this.format,
    required this.inputBytes,
  });

  /// Size of the compressed copy, in bytes.
  int get compressedBytes => original.length;
}

abstract class PhotoProcessor {
  /// Checks, shrinks, compresses and watermarks [bytes]. Throws [PhotoRejected]
  /// for a file that may not be used.
  Future<ProcessedPhoto> process({
    required String fileName,
    required Uint8List bytes,
  });
}

/// Writes a picture as WEBP or JPEG. The phone does this natively; the tests
/// give their own.
abstract class PhotoEncoder {
  /// Throws when [format] cannot be written on this device.
  Future<Uint8List> encode(
    Uint8List png, {
    required int width,
    required int height,
    required PhotoFormat format,
    required int quality,
  });
}

/// The phone's own encoder (libwebp / the platform JPEG writer). No metadata is
/// kept: the picture it is given is a fresh PNG with none, and it never copies
/// EXIF (which could hold the place the photo was taken).
class NativePhotoEncoder implements PhotoEncoder {
  const NativePhotoEncoder();

  @override
  Future<Uint8List> encode(
    Uint8List png, {
    required int width,
    required int height,
    required PhotoFormat format,
    required int quality,
  }) async {
    final out = await FlutterImageCompress.compressWithList(
      png,
      // The picture already has its final size; asking for its own size means
      // "do not scale".
      minWidth: width,
      minHeight: height,
      quality: quality,
      format: format == PhotoFormat.webp
          ? CompressFormat.webp
          : CompressFormat.jpeg,
      keepExif: false,
    );
    if (out.isEmpty) throw StateError('${format.name} encoder gave no data');
    return out;
  }
}

/// The real [PhotoProcessor]: decodes with the engine, shrinks to at most
/// [kPhotoMaxSide], draws the watermark on a second copy, and writes both with
/// the encoder (WEBP, or JPEG where WEBP is not available).
class UiPhotoProcessor implements PhotoProcessor {
  final PhotoEncoder encoder;
  const UiPhotoProcessor({this.encoder = const NativePhotoEncoder()});

  @override
  Future<ProcessedPhoto> process({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final head = bytes.length > 16
        ? Uint8List.sublistView(bytes, 0, 16)
        : bytes;
    final problem = checkPhotoFile(length: bytes.length, head: head);
    if (problem != null) throw PhotoRejected(problem);

    final ui.Image base;
    try {
      base = await _decodeFitted(bytes);
    } catch (_) {
      throw const PhotoRejected(PhotoProblem.unreadable);
    }
    try {
      final plainPng = await _toPng(await _flatten(base, watermark: false));
      final markedPng = await _toPng(await _flatten(base, watermark: true));
      final w = base.width, h = base.height;

      final original = await _compress(plainPng, w, h);
      // Both copies are written the same way, so they share one extension.
      final marked = await _compress(markedPng, w, h, only: original.format);
      return ProcessedPhoto(
        fileName: fileName,
        original: original.bytes,
        watermarked: marked.bytes,
        format: original.format,
        inputBytes: bytes.length,
      );
    } finally {
      base.dispose();
    }
  }

  /// Decoded straight to the final size, so a 12 MP photo is never held in
  /// memory at full size.
  Future<ui.Image> _decodeFitted(Uint8List bytes) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      try {
        final fit = fitWithin(descriptor.width, descriptor.height);
        final shrink =
            fit.width != descriptor.width || fit.height != descriptor.height;
        final codec = await descriptor.instantiateCodec(
          // One side only: the other keeps the photo's own shape.
          targetWidth: shrink && descriptor.width >= descriptor.height
              ? fit.width
              : null,
          targetHeight: shrink && descriptor.height > descriptor.width
              ? fit.height
              : null,
        );
        try {
          return (await codec.getNextFrame()).image;
        } finally {
          codec.dispose();
        }
      } finally {
        descriptor.dispose();
      }
    } finally {
      buffer.dispose();
    }
  }

  /// A new picture of [src] on white (so a transparent PNG does not turn black
  /// as a JPEG), with the watermark when asked.
  Future<ui.Image> _flatten(ui.Image src, {required bool watermark}) async {
    final w = src.width, h = src.height;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    canvas.drawImage(src, Offset.zero, Paint());
    if (watermark) paintWatermark(canvas, Size(w.toDouble(), h.toDouble()));
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(w, h);
    } finally {
      picture.dispose();
    }
  }

  Future<Uint8List> _toPng(ui.Image image) async {
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw const PhotoRejected(PhotoProblem.unreadable);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      image.dispose();
    }
  }

  /// WEBP at the ladder's qualities; JPEG when WEBP cannot be written (unless
  /// [only] says which one to use).
  Future<({Uint8List bytes, PhotoFormat format})> _compress(
    Uint8List png,
    int width,
    int height, {
    PhotoFormat? only,
  }) async {
    Object? lastError;
    for (final format
        in only != null ? [only] : const [PhotoFormat.webp, PhotoFormat.jpeg]) {
      try {
        final done = await encodeWithinBudget(
          (q) => encoder.encode(
            png,
            width: width,
            height: height,
            format: format,
            quality: q,
          ),
        );
        return (bytes: done.bytes, format: format);
      } catch (e) {
        lastError = e;
      }
    }
    throw StateError('The photo could not be compressed: $lastError');
  }
}

/// Draws "Konnect Kashmir" in the bottom-right corner of a picture of [size]:
/// white letters with a dark outline, at 60% opacity, as large as 4.5% of the
/// width (at least 14 pixels). (Public so it can be tested.)
void paintWatermark(Canvas canvas, Size size) {
  final fontSize = watermarkFontSize(size.width.round());
  final base = TextStyle(
    fontSize: fontSize,
    fontWeight: FontWeight.w700,
    letterSpacing: fontSize * 0.02,
  );
  TextPainter paint(TextStyle style) => TextPainter(
    text: TextSpan(text: kWatermarkText, style: style),
    textDirection: TextDirection.ltr,
  )..layout();

  final fill = paint(base.copyWith(color: const Color(0xFFFFFFFF)));
  final outline = paint(
    base.copyWith(
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (fontSize / 7).clamp(1.5, 8.0)
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF000000),
    ),
  );

  final margin = (size.width * 0.025).clamp(8.0, 64.0);
  final origin = Offset(
    size.width - fill.width - margin,
    size.height - fill.height - margin,
  );
  // Letters and outline are drawn into one layer, which is then made 60%
  // opaque, so where they overlap the outline does not show through the letters.
  canvas.saveLayer(
    (origin & fill.size).inflate(fontSize),
    Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: kWatermarkOpacity),
  );
  outline.paint(canvas, origin);
  fill.paint(canvas, origin);
  canvas.restore();
}
