import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'photo_processor.dart';
import 'photo_rules.dart';

/// Where a photo stands with the admins. Nothing is shown to the public until it
/// is [approved]; the owner sees all three.
enum PhotoStatus {
  pending,
  approved,
  rejected;

  /// A missing value is an older photo (approved); a value we do not know is
  /// treated as waiting, so it is never shown by mistake.
  static PhotoStatus parse(Object? value) {
    if (value == null) return approved;
    return switch ('$value'.trim().toLowerCase()) {
      '' || 'approved' => approved,
      'rejected' => rejected,
      _ => pending,
    };
  }
}

/// One photo of a business, as stored: a row of `business_photos` that points at
/// the watermarked copy in the `business-photos` bucket.
@immutable
class BusinessPhoto {
  final String id;
  final String vendorId;

  /// `{vendor}/public/{file}`: the only copy the app ever reads or shows.
  final String storagePath;
  final int sortOrder;
  final DateTime? createdAt;

  /// Pending until an admin approves it (see [PhotoStatus]).
  final PhotoStatus status;

  /// Why an admin (or the automatic check) did not approve it; null otherwise.
  final String? rejectionReason;

  /// A signed link to the public copy (valid for [kSignedUrlLifetime]); null when
  /// one could not be made.
  final String? url;

  const BusinessPhoto({
    required this.id,
    required this.vendorId,
    required this.storagePath,
    required this.sortOrder,
    this.createdAt,
    this.status = PhotoStatus.approved,
    this.rejectionReason,
    this.url,
  });

  factory BusinessPhoto.fromRow(Map<String, dynamic> row) => BusinessPhoto(
    id: '${row['id']}',
    vendorId: '${row['vendor_id']}',
    storagePath: '${row['storage_path']}',
    sortOrder: row['sort_order'] is num
        ? (row['sort_order'] as num).toInt()
        : int.tryParse('${row['sort_order']}') ?? 0,
    createdAt: DateTime.tryParse('${row['created_at'] ?? ''}'),
    status: PhotoStatus.parse(row['status']),
    rejectionReason: _reason(row['rejection_reason']),
  );

  static String? _reason(Object? v) {
    final s = v?.toString().trim() ?? '';
    return s.isEmpty ? null : s;
  }

  /// Names the picture in the image cache. It stays the same when the signed link
  /// is renewed, so a photo already on the phone is not downloaded again.
  String get cacheKey => storagePath;

  BusinessPhoto copyWith({int? sortOrder, String? url}) => BusinessPhoto(
    id: id,
    vendorId: vendorId,
    storagePath: storagePath,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt,
    status: status,
    rejectionReason: rejectionReason,
    url: url ?? this.url,
  );
}

/// By `sort_order`, then by when it was added.
int comparePhotos(BusinessPhoto a, BusinessPhoto b) {
  final c = a.sortOrder.compareTo(b.sortOrder);
  if (c != 0) return c;
  final x = a.createdAt, y = b.createdAt;
  if (x != null && y != null) return x.compareTo(y);
  return 0;
}

/// The server said no (or could not be reached).
class PhotoBackendException implements Exception {
  final String message;
  final int? statusCode;
  const PhotoBackendException(this.message, {this.statusCode});

  @override
  String toString() => 'PhotoBackendException($statusCode): $message';
}

/// The business already has [kMaxBusinessPhotos] photos.
class PhotoLimitReached implements Exception {
  const PhotoLimitReached();

  @override
  String toString() => 'A business can have at most $kMaxBusinessPhotos photos';
}

/// What the service needs from the server: the `business_photos` table and the
/// `business-photos` bucket. [SupabasePhotoBackend] is the real one.
abstract class BusinessPhotoBackend {
  /// The rows of one business (any order). With [approvedOnly] only the photos
  /// an admin has approved: what everybody else sees. Without it, the server
  /// answers with all the signed-in user may see (an owner: every status).
  Future<List<BusinessPhoto>> rows(
    String vendorId, {
    bool approvedOnly = false,
  });

  /// A signed link for each of [publicPaths] (a path that could not be signed is
  /// missing from the answer).
  Future<Map<String, String>> signedUrls(List<String> publicPaths);

  Future<void> upload(String path, Uint8List bytes, String contentType);
  Future<void> removeFiles(List<String> paths);

  Future<BusinessPhoto> insertRow({
    required String vendorId,
    required String storagePath,
    required int sortOrder,
  });
  Future<void> deleteRow(String id);
  Future<void> updateSortOrder(String id, int sortOrder);
}

/// How one photo of a batch went.
class PhotoUploadOutcome {
  final ProcessedPhoto photo;
  final BusinessPhoto? saved;
  final Object? error;
  const PhotoUploadOutcome(this.photo, {this.saved, this.error});

  bool get ok => saved != null;
}

class _Cached {
  final List<BusinessPhoto> photos;
  final DateTime at;
  const _Cached(this.photos, this.at);
}

/// Listing, adding, deleting and ordering the photos of a business.
class BusinessPhotoService {
  final BusinessPhotoBackend backend;
  final String Function() _newId;
  final DateTime Function() _now;

  BusinessPhotoService({
    required this.backend,
    String Function()? newId,
    DateTime Function()? now,
  }) : _newId = newId ?? randomPhotoId,
       _now = now ?? DateTime.now;

  /// The lists already asked for. A list is used again for a few minutes (the
  /// signed links in it last hours), and is dropped whenever a photo is added,
  /// deleted or moved, so the next look shows the change.
  static final Map<String, _Cached> _cache = {};
  static String _key(String vendorId, bool owner) =>
      '$vendorId#${owner ? 'owner' : 'public'}';
  static const Duration _listFresh = Duration(minutes: 10);

  static void clearCache() => _cache.clear();

  /// The photos of a business, in order, with a signed link for each. Only public
  /// copies are listed; a path that is not one is ignored. Throws when the server
  /// could not be asked.
  Future<List<BusinessPhoto>> photos(
    String vendorId, {
    bool refresh = false,
    bool ownerView = false,
  }) async {
    final key = _key(vendorId, ownerView);
    final hit = _cache[key];
    if (!refresh && hit != null && _now().difference(hit.at) < _listFresh) {
      return hit.photos;
    }
    final rows = [
      for (final r in await backend.rows(vendorId, approvedOnly: !ownerView))
        // (Checked again here: the public never gets a photo that is not approved.)
        if (isPublicPhotoPath(r.storagePath) &&
            (ownerView || r.status == PhotoStatus.approved))
          r,
    ]..sort(comparePhotos);
    final urls = rows.isEmpty
        ? const <String, String>{}
        : await backend.signedUrls([for (final r in rows) r.storagePath]);
    final out = [for (final r in rows) r.copyWith(url: urls[r.storagePath])];
    _cache[key] = _Cached(out, _now());
    return out;
  }

  void _changed(String vendorId) {
    _cache.remove(_key(vendorId, true));
    _cache.remove(_key(vendorId, false));
  }

  /// Uploads [photos] one after the other, as the next photos of [vendorId].
  /// A photo that cannot be added is reported in its outcome; the rest go on
  /// (except after the limit, which ends the batch). [onEach] hears each outcome
  /// as soon as it is known.
  Future<List<PhotoUploadOutcome>> addPhotos(
    String vendorId,
    List<ProcessedPhoto> photos, {
    void Function(PhotoUploadOutcome outcome)? onEach,
  }) async {
    final outcomes = <PhotoUploadOutcome>[];
    void note(PhotoUploadOutcome o) {
      outcomes.add(o);
      onEach?.call(o);
    }

    var count = 0;
    var last = -1;
    try {
      final current = await backend.rows(vendorId);
      // The limit counts waiting and approved photos; a rejected one does not.
      count = current.where((p) => p.status != PhotoStatus.rejected).length;
      last = current.fold<int>(-1, (m, p) => math.max(m, p.sortOrder));
    } catch (e) {
      for (final p in photos) {
        note(PhotoUploadOutcome(p, error: e));
      }
      return outcomes;
    }

    try {
      for (final p in photos) {
        if (count >= kMaxBusinessPhotos) {
          note(PhotoUploadOutcome(p, error: const PhotoLimitReached()));
          continue;
        }
        try {
          final saved = await _uploadOne(vendorId, p, last + 1);
          count++;
          last = saved.sortOrder;
          note(PhotoUploadOutcome(p, saved: saved));
        } on PhotoLimitReached catch (e) {
          count = kMaxBusinessPhotos;
          note(PhotoUploadOutcome(p, error: e));
        } catch (e) {
          note(PhotoUploadOutcome(p, error: e));
        }
      }
    } finally {
      _changed(vendorId);
    }
    return outcomes;
  }

  /// Steps 5 to 8 for one photo: the compressed copy goes to `original/`, the
  /// watermarked copy to `public/`, then the row is added. When any step fails,
  /// whatever was already uploaded is deleted again.
  Future<BusinessPhoto> _uploadOne(
    String vendorId,
    ProcessedPhoto p,
    int sortOrder,
  ) async {
    final file = '${_newId()}.${p.format.extension}';
    final originalPath = originalPhotoPath(vendorId, file);
    final publicPath = publicPhotoPath(vendorId, file);
    final uploaded = <String>[];
    try {
      await backend.upload(originalPath, p.original, p.format.contentType);
      uploaded.add(originalPath);
      await backend.upload(publicPath, p.watermarked, p.format.contentType);
      uploaded.add(publicPath);
      return await backend.insertRow(
        vendorId: vendorId,
        storagePath: publicPath,
        sortOrder: sortOrder,
      );
    } catch (e) {
      if (uploaded.isNotEmpty) {
        try {
          await backend.removeFiles(uploaded);
        } catch (_) {
          // Nothing more can be done; the files are private and unreferenced.
        }
      }
      if (e is PhotoBackendException &&
          e.message.toLowerCase().contains('at most $kMaxBusinessPhotos')) {
        throw const PhotoLimitReached();
      }
      rethrow;
    }
  }

  /// Removes the row first, then both files. Throws when the row could not be
  /// removed (nothing else is touched). A file that could not be removed is left
  /// behind: the photo is gone for everybody either way.
  Future<void> deletePhoto(BusinessPhoto photo) async {
    await backend.deleteRow(photo.id);
    _changed(photo.vendorId);
    final files = <String>[
      for (final path in [photo.storagePath, originalPathOf(photo.storagePath)])
        if (path != null && path.startsWith('${photo.vendorId}/')) path,
    ];
    if (files.isEmpty) return;
    try {
      await backend.removeFiles(files);
    } catch (e) {
      debugPrint('[Photos] files of ${photo.id} were left behind: $e');
    }
  }

  /// Gives the photos of [ordered] the sort orders 0, 1, 2... in that order and
  /// saves the ones that changed. Returns the list with the new orders. Throws
  /// when a save fails; the caller should then ask the server again.
  Future<List<BusinessPhoto>> saveOrder(List<BusinessPhoto> ordered) async {
    final out = <BusinessPhoto>[];
    try {
      for (var i = 0; i < ordered.length; i++) {
        final p = ordered[i];
        if (p.sortOrder != i) await backend.updateSortOrder(p.id, i);
        out.add(p.copyWith(sortOrder: i));
      }
    } finally {
      if (ordered.isNotEmpty) _changed(ordered.first.vendorId);
    }
    return out;
  }
}

/// [list] with the photo at [from] moved to [to] (both clamped into the list).
List<T> moved<T>(List<T> list, int from, int to) {
  if (from < 0 || from >= list.length) return List<T>.of(list);
  final target = to.clamp(0, list.length - 1);
  final out = List<T>.of(list);
  out.insert(target, out.removeAt(from));
  return out;
}

/// A random version-4 UUID for a file name (nothing about the photo, its owner
/// or its place is in a name).
String randomPhotoId() {
  final r = math.Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0F) | 0x40;
  b[8] = (b[8] & 0x3F) | 0x80;
  String h(int from, int to) => [
    for (var i = from; i < to; i++) b[i].toRadixString(16).padLeft(2, '0'),
  ].join();
  return '${h(0, 4)}-${h(4, 6)}-${h(6, 8)}-${h(8, 10)}-${h(10, 16)}';
}
