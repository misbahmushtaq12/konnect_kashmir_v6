import 'dart:typed_data';

import 'package:konnect_kashmir/services/business_photos/business_photo_service.dart';
import 'package:konnect_kashmir/services/business_photos/photo_processor.dart';
import 'package:konnect_kashmir/services/business_photos/photo_rules.dart';

/// The `business_photos` table and the `business-photos` bucket, in memory, with
/// the database's 20-photo trigger and switches to make single steps fail.
class FakePhotoBackend implements BusinessPhotoBackend {
  /// Rows by id, and files by path.
  final Map<String, BusinessPhoto> table = {};
  final Map<String, Uint8List> files = {};
  final Map<String, String> fileTypes = {};

  /// Every call, in order ("upload x", "insert x", "removeFiles a,b" ...).
  final List<String> calls = [];
  final List<List<String>> signRequests = [];

  bool failRows = false;
  bool failSigning = false;
  bool failInsert = false;
  bool failDeleteRow = false;
  bool failRemoveFiles = false;
  bool failSortUpdate = false;

  /// Fail the upload of a path that contains this text.
  String? failUploadOf;

  /// Say "limit reached" on the next insert, whatever the count (a second phone
  /// filled the business in the meantime).
  bool triggerAlwaysFull = false;

  int _nextId = 1;
  int _clock = 0;

  /// Puts a photo straight into the table and the bucket, as the website would.
  BusinessPhoto seed(
    String vendorId, {
    int? sortOrder,
    String? file,
    DateTime? createdAt,
    String folder = 'public',
    PhotoStatus status = PhotoStatus.approved,
    String? rejectionReason,
  }) {
    final name = file ?? 'seed$_nextId.webp';
    final path = '$vendorId/$folder/$name';
    files[path] = Uint8List.fromList([1, 2, 3]);
    if (folder == 'public') {
      files[originalPhotoPath(vendorId, name)] = Uint8List.fromList([4, 5, 6]);
    }
    final photo = BusinessPhoto(
      id: 'row${_nextId++}',
      vendorId: vendorId,
      storagePath: path,
      sortOrder:
          sortOrder ?? table.values.where((p) => p.vendorId == vendorId).length,
      createdAt: createdAt ?? DateTime.utc(2026, 11, 3, 9, 0, _clock++),
      status: status,
      rejectionReason: rejectionReason,
    );
    table[photo.id] = photo;
    return photo;
  }

  List<BusinessPhoto> rowsOf(String vendorId) =>
      table.values.where((p) => p.vendorId == vendorId).toList()
        ..sort(comparePhotos);

  @override
  Future<List<BusinessPhoto>> rows(
    String vendorId, {
    bool approvedOnly = false,
  }) async {
    calls.add(approvedOnly ? 'rows $vendorId approved' : 'rows $vendorId');
    if (failRows) throw const PhotoBackendException('offline');
    return [
      for (final p in rowsOf(vendorId))
        if (!approvedOnly || p.status == PhotoStatus.approved) p,
    ];
  }

  @override
  Future<Map<String, String>> signedUrls(List<String> publicPaths) async {
    calls.add('sign ${publicPaths.length}');
    signRequests.add(List.of(publicPaths));
    if (failSigning) throw const PhotoBackendException('offline');
    return {
      for (final p in publicPaths)
        if (files.containsKey(p)) p: 'https://signed.example/$p?token=t',
    };
  }

  @override
  Future<void> upload(String path, Uint8List bytes, String contentType) async {
    calls.add('upload $path');
    if (failUploadOf != null && path.contains(failUploadOf!)) {
      throw const PhotoBackendException('upload failed', statusCode: 500);
    }
    files[path] = bytes;
    fileTypes[path] = contentType;
  }

  @override
  Future<void> removeFiles(List<String> paths) async {
    calls.add('removeFiles ${paths.join(',')}');
    if (failRemoveFiles) throw const PhotoBackendException('offline');
    for (final p in paths) {
      files.remove(p);
    }
  }

  @override
  Future<BusinessPhoto> insertRow({
    required String vendorId,
    required String storagePath,
    required int sortOrder,
  }) async {
    calls.add('insert $storagePath $sortOrder');
    if (failInsert) {
      throw const PhotoBackendException('insert failed', statusCode: 500);
    }
    // The trigger.
    final counted = rowsOf(
      vendorId,
    ).where((p) => p.status != PhotoStatus.rejected);
    if (triggerAlwaysFull || counted.length >= kMaxBusinessPhotos) {
      throw const PhotoBackendException(
        'A business can have at most 20 photos',
        statusCode: 400,
      );
    }
    final photo = BusinessPhoto(
      id: 'row${_nextId++}',
      vendorId: vendorId,
      storagePath: storagePath,
      sortOrder: sortOrder,
      createdAt: DateTime.utc(2026, 11, 3, 10, 0, _clock++),
      // The server makes every new photo wait for an admin.
      status: PhotoStatus.pending,
    );
    table[photo.id] = photo;
    return photo;
  }

  @override
  Future<void> deleteRow(String id) async {
    calls.add('deleteRow $id');
    if (failDeleteRow) throw const PhotoBackendException('offline');
    table.remove(id);
  }

  @override
  Future<void> updateSortOrder(String id, int sortOrder) async {
    calls.add('sort $id $sortOrder');
    if (failSortUpdate) throw const PhotoBackendException('offline');
    final p = table[id]!;
    table[id] = BusinessPhoto(
      id: p.id,
      vendorId: p.vendorId,
      storagePath: p.storagePath,
      sortOrder: sortOrder,
      createdAt: p.createdAt,
      status: p.status,
      rejectionReason: p.rejectionReason,
    );
  }
}

/// A [PhotoProcessor] that does no image work: the "photo" is its own bytes. A
/// file whose name starts with `bad` is refused as unsupported, `gone` as
/// unreadable.
class FakePhotoProcessor implements PhotoProcessor {
  final List<String> processed = [];

  @override
  Future<ProcessedPhoto> process({
    required String fileName,
    required Uint8List bytes,
  }) async {
    processed.add(fileName);
    if (fileName.startsWith('bad')) {
      throw const PhotoRejected(PhotoProblem.unsupportedType);
    }
    if (fileName.startsWith('gone')) {
      throw const PhotoRejected(PhotoProblem.unreadable);
    }
    // "Compressing" makes it ten times smaller.
    final small = bytes.length ~/ 10 < 1 ? 1 : bytes.length ~/ 10;
    return ProcessedPhoto(
      fileName: fileName,
      original: Uint8List(small),
      watermarked: Uint8List(small + 1),
      format: PhotoFormat.webp,
      inputBytes: bytes.length,
    );
  }
}

ProcessedPhoto fakeProcessed(String name, {int inputBytes = 6 * 1024 * 1024}) =>
    ProcessedPhoto(
      fileName: name,
      original: Uint8List.fromList([1, 1, 1]),
      watermarked: Uint8List.fromList([2, 2, 2]),
      format: PhotoFormat.webp,
      inputBytes: inputBytes,
    );
