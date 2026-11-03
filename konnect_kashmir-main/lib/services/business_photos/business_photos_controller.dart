import 'package:flutter/foundation.dart';

import 'business_photo_service.dart';
import 'photo_picker.dart';
import 'photo_processor.dart';
import 'photo_rules.dart';

/// One tile of the owner's photo list: a photo already saved, or one that is
/// prepared and waiting (it is uploaded at once for a business that exists, and
/// when the listing is submitted for a new one).
@immutable
class PhotoItem {
  final BusinessPhoto? saved;
  final ProcessedPhoto? pending;

  /// The photo is being uploaded.
  final bool uploading;

  const PhotoItem.saved(BusinessPhoto this.saved)
    : pending = null,
      uploading = false;
  const PhotoItem.pending(ProcessedPhoto this.pending, {this.uploading = false})
    : saved = null;
}

/// "Compressed: {name}: {before} KB -> {after} KB"
class CompressionNote {
  final String name;
  final int beforeKb;
  final int afterKb;
  const CompressionNote(this.name, this.beforeKb, this.afterKb);
}

class RejectedFile {
  final String name;
  final PhotoProblem problem;
  const RejectedFile(this.name, this.problem);
}

/// What came of adding photos.
class PhotoAddResult {
  /// Photos that were prepared (and, for an existing business, uploaded).
  final List<CompressionNote> compressed;

  /// Files that may not be used.
  final List<RejectedFile> rejected;

  /// Photos chosen beyond the free places; they were not added.
  final int skippedForLimit;

  /// Photos that were ready but could not be uploaded (by file name).
  final List<String> failed;

  /// The server said the business is full.
  final bool limitHit;

  const PhotoAddResult({
    this.compressed = const [],
    this.rejected = const [],
    this.skippedForLimit = 0,
    this.failed = const [],
    this.limitHit = false,
  });

  bool get nothingChosen =>
      compressed.isEmpty &&
      rejected.isEmpty &&
      skippedForLimit == 0 &&
      failed.isEmpty;
}

/// The state behind the "Business Photos" section of the listing form: the
/// photos shown, how many places are left, and adding, deleting and moving them.
///
/// With a [vendorId] (editing) every change goes to the server at once. Without
/// one (a new listing) the photos are prepared and kept in the list until
/// [uploadPending] is called with the new business's id.
class BusinessPhotosController extends ChangeNotifier {
  final String? vendorId;
  final BusinessPhotoService service;
  final PhotoProcessor processor;
  final PhotoPicker picker;

  BusinessPhotosController({
    this.vendorId,
    required this.service,
    this.processor = const UiPhotoProcessor(),
    this.picker = pickPhotosFromGallery,
  });

  List<PhotoItem> _items = const [];
  List<PhotoItem> get items => _items;

  bool _loading = false;
  bool get loading => _loading;

  bool _loadFailed = false;

  /// The saved photos could not be asked for.
  bool get loadFailed => _loadFailed;

  bool _busy = false;

  /// Something is being prepared, uploaded, deleted or saved.
  bool get busy => _busy;

  List<CompressionNote> _notes = const [];

  /// The sizes of the photos added last.
  List<CompressionNote> get notes => _notes;

  bool get editing => vendorId != null;
  int get count => _items.length;
  int get remaining =>
      (kMaxBusinessPhotos - count).clamp(0, kMaxBusinessPhotos);
  bool get atLimit => count >= kMaxBusinessPhotos;
  bool get hasPending => _items.any((i) => i.pending != null);

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _set(List<PhotoItem> items) {
    _items = items;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _setBusy(bool v) {
    _busy = v;
    _notify();
  }

  /// Asks the server for the saved photos (editing only).
  Future<void> load() async {
    final id = vendorId;
    if (id == null) return;
    _loading = true;
    _loadFailed = false;
    _notify();
    try {
      final list = await service.photos(id, refresh: true);
      _items = [for (final p in list) PhotoItem.saved(p)];
    } catch (_) {
      _loadFailed = true;
    }
    _loading = false;
    _notify();
  }

  /// Opens the gallery and adds what is chosen.
  Future<PhotoAddResult> add() async {
    if (_busy || atLimit) return const PhotoAddResult();
    final List<PickedPhoto> picked;
    try {
      picked = await picker(remaining);
    } catch (_) {
      return const PhotoAddResult();
    }
    return addPicked(picked);
  }

  /// Checks, compresses and watermarks [picked] (only as many as there are
  /// places left), and uploads them when the business exists.
  Future<PhotoAddResult> addPicked(List<PickedPhoto> picked) async {
    if (_busy || picked.isEmpty) return const PhotoAddResult();
    _setBusy(true);
    try {
      final take = picked.take(remaining).toList();
      final skipped = picked.length - take.length;
      final rejected = <RejectedFile>[];
      final ready = <ProcessedPhoto>[];

      for (final file in take) {
        try {
          final problem = file.length <= 0
              ? PhotoProblem.empty
              : file.length > kMaxPhotoFileBytes
              ? PhotoProblem.tooLarge
              : null;
          if (problem != null) throw PhotoRejected(problem);
          final done = await processor.process(
            fileName: file.name,
            bytes: await file.read(),
          );
          ready.add(done);
          _set([..._items, PhotoItem.pending(done, uploading: editing)]);
        } on PhotoRejected catch (e) {
          rejected.add(RejectedFile(file.name, e.problem));
        } catch (_) {
          rejected.add(RejectedFile(file.name, PhotoProblem.unreadable));
        }
      }

      var compressed = [for (final p in ready) _noteOf(p)];
      final failed = <String>[];
      var limitHit = false;

      final id = vendorId;
      if (id != null && ready.isNotEmpty) {
        final outcomes = await service.addPhotos(id, ready);
        for (final o in outcomes) {
          if (o.ok) continue;
          failed.add(o.photo.fileName);
          if (o.error is PhotoLimitReached) limitHit = true;
        }
        compressed = [
          for (final o in outcomes)
            if (o.ok) _noteOf(o.photo),
        ];
        // The server's list (with fresh links) replaces the waiting tiles.
        await _reloadAfterChange();
      }
      _notes = compressed;
      return PhotoAddResult(
        compressed: compressed,
        rejected: rejected,
        skippedForLimit: skipped,
        failed: failed,
        limitHit: limitHit,
      );
    } finally {
      _setBusy(false);
    }
  }

  CompressionNote _noteOf(ProcessedPhoto p) => CompressionNote(
    p.fileName,
    kilobytes(p.inputBytes),
    kilobytes(p.compressedBytes),
  );

  Future<void> _reloadAfterChange() async {
    final id = vendorId;
    if (id == null) return;
    try {
      final list = await service.photos(id, refresh: true);
      _items = [for (final p in list) PhotoItem.saved(p)];
      _loadFailed = false;
    } catch (_) {
      // Keep what is shown; the waiting tiles are replaced at the next load.
      _items = [
        for (final i in _items)
          if (i.saved != null) i,
      ];
      _loadFailed = true;
    }
    _notify();
  }

  /// Moves the photo at [index] one place earlier (delta -1) or later (+1).
  /// Returns false when it could not be saved.
  Future<bool> move(int index, int delta) async {
    final to = index + delta;
    if (_busy || index < 0 || index >= count || to < 0 || to >= count) {
      return true;
    }
    final before = _items;
    final after = moved(before, index, to);
    _set(after);
    if (!editing) return true;

    _setBusy(true);
    try {
      final saved = [for (final i in after) i.saved!];
      final done = await service.saveOrder(saved);
      _set([for (final p in done) PhotoItem.saved(p)]);
      return true;
    } catch (_) {
      await _reloadAfterChange();
      return false;
    } finally {
      _setBusy(false);
    }
  }

  /// Deletes the photo at [index]. Returns false when it could not be deleted.
  Future<bool> remove(int index) async {
    if (_busy || index < 0 || index >= count) return true;
    final item = _items[index];
    final saved = item.saved;
    if (saved == null) {
      _set([..._items]..removeAt(index));
      return true;
    }
    _setBusy(true);
    try {
      await service.deletePhoto(saved);
      _set([..._items]..removeAt(index));
      return true;
    } catch (_) {
      return false;
    } finally {
      _setBusy(false);
    }
  }

  /// Uploads the photos prepared for a new listing, as the photos of
  /// [newVendorId]. Returns the names of those that could not be uploaded.
  Future<List<String>> uploadPending(String newVendorId) async {
    final waiting = [
      for (final i in _items)
        if (i.pending != null) i.pending!,
    ];
    if (waiting.isEmpty) return const [];
    _setBusy(true);
    try {
      final outcomes = await service.addPhotos(newVendorId, waiting);
      return [
        for (final o in outcomes)
          if (!o.ok) o.photo.fileName,
      ];
    } finally {
      _setBusy(false);
    }
  }
}
