import 'dart:math' as math;
import 'dart:typed_data';

/// The rules for business photos, in one place (and free of any plugin, so the
/// tests can run them as they are).

/// A business may have this many photos (the database trigger enforces it too).
const int kMaxBusinessPhotos = 20;

/// The biggest file we accept from the phone's gallery.
const int kMaxPhotoFileBytes = 15 * 1024 * 1024;

/// The longest side of a stored photo, in pixels. Smaller photos are never enlarged.
const int kPhotoMaxSide = 1600;

/// A stored photo should be no bigger than this.
const int kPhotoTargetBytes = 500 * 1024;

/// Encoder quality (percent): start here, go down a step while the photo is too
/// big, never below the floor.
const int kPhotoStartQuality = 80;
const int kPhotoQualityStep = 10;
const int kPhotoMinQuality = 45;

/// The text written on the public copy, 60% opaque.
const String kWatermarkText = 'Konnect Kashmir';
const double kWatermarkOpacity = 0.6;

const String kPhotoBucket = 'business-photos';

/// Signed links last this long. The list is asked for again well before that.
const Duration kSignedUrlLifetime = Duration(hours: 6);

/// The formats a photo may come in.
enum PhotoSourceType { jpeg, png, webp }

/// What we store: WEBP, or JPEG where WEBP cannot be written.
enum PhotoFormat {
  webp('webp', 'image/webp'),
  jpeg('jpg', 'image/jpeg');

  final String extension;
  final String contentType;
  const PhotoFormat(this.extension, this.contentType);
}

enum PhotoProblem { empty, tooLarge, unsupportedType, unreadable }

/// A photo that was not accepted, and why.
class PhotoRejected implements Exception {
  final PhotoProblem problem;
  const PhotoRejected(this.problem);

  @override
  String toString() => 'PhotoRejected($problem)';
}

/// The type of a photo from its first bytes (not from its name, which the phone's
/// picker may leave without an extension or with a wrong one).
PhotoSourceType? sniffPhotoType(Uint8List head) {
  bool starts(List<int> sig, {int at = 0}) {
    if (head.length < at + sig.length) return false;
    for (var i = 0; i < sig.length; i++) {
      if (head[at + i] != sig[i]) return false;
    }
    return true;
  }

  if (starts(const [0xFF, 0xD8, 0xFF])) return PhotoSourceType.jpeg;
  if (starts(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    return PhotoSourceType.png;
  }
  // RIFF....WEBP
  if (starts(const [0x52, 0x49, 0x46, 0x46]) &&
      starts(const [0x57, 0x45, 0x42, 0x50], at: 8)) {
    return PhotoSourceType.webp;
  }
  return null;
}

/// Why a file may not be used, or null when it may. [length] is its size in bytes,
/// [head] its first bytes (12 are enough).
PhotoProblem? checkPhotoFile({required int length, required Uint8List head}) {
  if (length <= 0) return PhotoProblem.empty;
  if (length > kMaxPhotoFileBytes) return PhotoProblem.tooLarge;
  if (sniffPhotoType(head) == null) return PhotoProblem.unsupportedType;
  return null;
}

/// [width] x [height] scaled down so the longer side is at most [maxSide]; the
/// shape is kept and a smaller photo is returned as it is (never enlarged).
({int width, int height}) fitWithin(
  int width,
  int height, {
  int maxSide = kPhotoMaxSide,
}) {
  final longest = math.max(width, height);
  if (longest <= maxSide || longest <= 0) return (width: width, height: height);
  final scale = maxSide / longest;
  return (
    width: math.max(1, (width * scale).round()),
    height: math.max(1, (height * scale).round()),
  );
}

/// The qualities tried, in order: 80, 70, 60, 50, 45.
List<int> photoQualityLadder() {
  final out = <int>[];
  var q = kPhotoStartQuality;
  while (true) {
    out.add(q);
    if (q <= kPhotoMinQuality) break;
    q = math.max(kPhotoMinQuality, q - kPhotoQualityStep);
  }
  return out;
}

/// The result of [encodeWithinBudget].
class EncodedWithin {
  final Uint8List bytes;
  final int quality;
  const EncodedWithin(this.bytes, this.quality);
}

/// Encodes at the first quality of the ladder; while the result is bigger than
/// [budget] bytes it tries the next lower one. Returns the last (smallest) result
/// when even the lowest quality is over the budget.
Future<EncodedWithin> encodeWithinBudget(
  Future<Uint8List> Function(int quality) encode, {
  int budget = kPhotoTargetBytes,
}) async {
  EncodedWithin? last;
  for (final q in photoQualityLadder()) {
    final bytes = await encode(q);
    last = EncodedWithin(bytes, q);
    if (bytes.length <= budget) break;
  }
  return last!;
}

/// The watermark's text size: 4.5% of the photo's width, at least 14 pixels.
double watermarkFontSize(int imageWidth) => math.max(14.0, imageWidth * 0.045);

/// Whole kilobytes for display (at least 1 for a file that has any bytes).
int kilobytes(int bytes) =>
    bytes <= 0 ? 0 : math.max(1, (bytes / 1024).round());

// ── Storage paths ───────────────────────────────────────────────────────────

/// `{vendor}/public/{file}`: the watermarked copy everybody sees.
String publicPhotoPath(String vendorId, String file) =>
    '$vendorId/public/$file';

/// `{vendor}/original/{file}`: the compressed copy that is never shown.
String originalPhotoPath(String vendorId, String file) =>
    '$vendorId/original/$file';

final RegExp _publicPath = RegExp(r'^[^/]+/public/[^/]+$');

/// Whether [path] is a public copy. Only these are ever signed or shown.
bool isPublicPhotoPath(String path) => _publicPath.hasMatch(path);

/// The compressed copy that goes with a public path, or null for any other path.
String? originalPathOf(String publicPath) {
  if (!isPublicPhotoPath(publicPath)) return null;
  final i = publicPath.indexOf('/public/');
  return '${publicPath.substring(0, i)}/original/'
      '${publicPath.substring(i + '/public/'.length)}';
}
