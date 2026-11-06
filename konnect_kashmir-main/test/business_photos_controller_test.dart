import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/services/business_photos/business_photo_service.dart';
import 'package:konnect_kashmir/services/business_photos/business_photos_controller.dart';
import 'package:konnect_kashmir/services/business_photos/photo_picker.dart';
import 'package:konnect_kashmir/services/business_photos/photo_rules.dart';

import 'support/fake_photo_backend.dart';

/// A picked file of [size] bytes (its bytes are only really that long when small).
PickedPhoto _pick(String name, {int size = 8}) => PickedPhoto(
  name: name,
  length: size,
  read: () async => Uint8List(size > 2 * 1024 * 1024 ? 8 : size),
);

List<PickedPhoto> _picks(int n, {String prefix = 'p'}) => [
  for (var i = 0; i < n; i++) _pick('$prefix$i.jpg'),
];

void main() {
  late FakePhotoBackend backend;
  late FakePhotoProcessor processor;
  late BusinessPhotoService service;
  late List<int> pickerLimits;
  late List<PickedPhoto> nextPick;
  var ids = 0;

  setUp(() {
    BusinessPhotoService.clearCache();
    backend = FakePhotoBackend();
    processor = FakePhotoProcessor();
    ids = 0;
    service = BusinessPhotoService(backend: backend, newId: () => 'id${++ids}');
    pickerLimits = [];
    nextPick = [];
  });

  BusinessPhotosController controller({String? vendorId}) =>
      BusinessPhotosController(
        vendorId: vendorId,
        service: service,
        processor: processor,
        picker: (limit) async {
          pickerLimits.add(limit);
          return nextPick;
        },
      );

  group('editing a business that has photos', () {
    test('loads what is there, in order, and counts', () async {
      backend.seed('v1', sortOrder: 1, file: 'b.webp');
      backend.seed('v1', sortOrder: 0, file: 'a.webp');
      final c = controller(vendorId: 'v1');
      await c.load();

      expect(c.items.map((i) => i.saved!.storagePath.split('/').last), [
        'a.webp',
        'b.webp',
      ]);
      expect(c.count, 2);
      expect(c.remaining, 18);
      expect(c.atLimit, isFalse);
      expect(c.loadFailed, isFalse);
    });

    test('a failed load is told, not shown as "no photos"', () async {
      backend.failRows = true;
      final c = controller(vendorId: 'v1');
      await c.load();
      expect(c.loadFailed, isTrue);
      expect(c.items, isEmpty);

      backend.failRows = false;
      await c.load();
      expect(c.loadFailed, isFalse);
    });

    test('adding uploads at once and shows the sizes: X KB -> Y KB', () async {
      final c = controller(vendorId: 'v1');
      await c.load();
      nextPick = [_pick('shop.jpg', size: 700 * 1024)];
      final r = await c.add();

      expect(pickerLimits, [
        20,
      ], reason: 'the picker is told how many places are left');
      expect(r.compressed.single.name, 'shop.jpg');
      expect(r.compressed.single.beforeKb, 700);
      expect(
        r.compressed.single.afterKb,
        70,
      ); // the fake makes it ten times smaller
      expect(r.failed, isEmpty);
      expect(c.notes.single.name, 'shop.jpg');
      expect(c.count, 1);
      expect(
        c.items.single.saved,
        isNotNull,
        reason: 'now a saved photo, not a waiting one',
      );
      expect(backend.rowsOf('v1'), hasLength(1));
      expect(c.busy, isFalse);
    });

    test('the 20-photo limit: 18 + 5 chosen = 2 added, 3 told about', () async {
      for (var i = 0; i < 18; i++) {
        backend.seed('v1');
      }
      final c = controller(vendorId: 'v1');
      await c.load();
      expect(c.remaining, 2);
      nextPick = _picks(5);
      final r = await c.add();

      expect(pickerLimits, [2]);
      expect(r.compressed, hasLength(2));
      expect(r.skippedForLimit, 3);
      expect(processor.processed, [
        'p0.jpg',
        'p1.jpg',
      ], reason: 'the extra files are not even read');
      expect(c.count, 20);
      expect(c.atLimit, isTrue);
      expect(backend.rowsOf('v1'), hasLength(20));
    });

    test('at 20 the picker is not even opened', () async {
      for (var i = 0; i < 20; i++) {
        backend.seed('v1');
      }
      final c = controller(vendorId: 'v1');
      await c.load();
      expect(c.atLimit, isTrue);
      nextPick = _picks(1);
      final r = await c.add();
      expect(pickerLimits, isEmpty);
      expect(r.nothingChosen, isTrue);
      expect(c.count, 20);
    });

    test('one place left: one photo', () async {
      for (var i = 0; i < 19; i++) {
        backend.seed('v1');
      }
      final c = controller(vendorId: 'v1');
      await c.load();
      nextPick = _picks(1);
      await c.add();
      expect(pickerLimits, [1]);
      expect(c.count, 20);
    });

    test('after a delete at 20, one more can be added', () async {
      for (var i = 0; i < 20; i++) {
        backend.seed('v1');
      }
      final c = controller(vendorId: 'v1');
      await c.load();
      expect(c.atLimit, isTrue);
      expect(await c.remove(5), isTrue);
      expect(c.count, 19);
      expect(c.atLimit, isFalse);
      nextPick = _picks(1);
      await c.add();
      expect(c.count, 20);
    });

    test(
      'files that may not be used are told about, the others go on',
      () async {
        final c = controller(vendorId: 'v1');
        await c.load();
        nextPick = [
          _pick('ok1.jpg'),
          _pick('big.jpg', size: kMaxPhotoFileBytes + 1),
          _pick('bad.gif'),
          _pick('gone.png'),
          _pick('empty.jpg', size: 0),
          _pick('ok2.jpg'),
        ];
        final r = await c.add();

        expect(r.compressed.map((n) => n.name), ['ok1.jpg', 'ok2.jpg']);
        expect(r.rejected.map((f) => (f.name, f.problem)), [
          ('big.jpg', PhotoProblem.tooLarge),
          ('bad.gif', PhotoProblem.unsupportedType),
          ('gone.png', PhotoProblem.unreadable),
          ('empty.jpg', PhotoProblem.empty),
        ]);
        expect(
          processor.processed,
          isNot(contains('big.jpg')),
          reason: 'too big: never read',
        );
        expect(c.count, 2);
      },
    );

    test(
      'a photo that cannot be uploaded is told about by name; the rest stay',
      () async {
        final c = controller(vendorId: 'v1');
        await c.load();
        backend.failUploadOf = 'id1.';
        nextPick = _picks(2);
        final r = await c.add();
        expect(r.failed, ['p0.jpg']);
        expect(r.compressed.map((n) => n.name), ['p1.jpg']);
        expect(c.count, 1);
        expect(backend.files.keys.where((k) => k.contains('id1.')), isEmpty);
      },
    );

    test('while something runs a second add is ignored', () async {
      final c = controller(vendorId: 'v1');
      await c.load();
      final first = c.addPicked(_picks(1));
      expect(c.busy, isTrue);
      final second = await c.addPicked(_picks(1, prefix: 'q'));
      expect(second.nothingChosen, isTrue);
      await first;
      expect(c.busy, isFalse);
      expect(c.count, 1);
    });
  });

  group('order', () {
    Future<BusinessPhotosController> three() async {
      for (var i = 0; i < 3; i++) {
        backend.seed('v1', sortOrder: i, file: 'p$i.webp');
      }
      final c = controller(vendorId: 'v1');
      await c.load();
      return c;
    }

    List<String> names(BusinessPhotosController c) => [
      for (final i in c.items) i.saved!.storagePath.split('/').last,
    ];

    test('move later and move earlier are saved', () async {
      final c = await three();
      expect(await c.move(0, 1), isTrue);
      expect(names(c), ['p1.webp', 'p0.webp', 'p2.webp']);
      expect(await c.move(2, -1), isTrue);
      expect(names(c), ['p1.webp', 'p2.webp', 'p0.webp']);
      expect(backend.rowsOf('v1').map((p) => p.storagePath.split('/').last), [
        'p1.webp',
        'p2.webp',
        'p0.webp',
      ]);
      expect(c.items.map((i) => i.saved!.sortOrder), [0, 1, 2]);
    });

    test('the first cannot go earlier, the last cannot go later', () async {
      final c = await three();
      backend.calls.clear();
      expect(await c.move(0, -1), isTrue);
      expect(await c.move(2, 1), isTrue);
      expect(names(c), ['p0.webp', 'p1.webp', 'p2.webp']);
      expect(backend.calls, isEmpty, reason: 'nothing was sent');
    });

    test(
      'if the new order cannot be saved: false, and the real order is shown',
      () async {
        final c = await three();
        backend.failSortUpdate = true;
        expect(await c.move(0, 1), isFalse);
        backend.failSortUpdate = false;
        expect(names(c), ['p0.webp', 'p1.webp', 'p2.webp']);
      },
    );
  });

  group('deleting', () {
    test('a saved photo: the row and both files go', () async {
      backend.seed('v1', file: 'a.webp');
      backend.seed('v1', file: 'b.webp');
      final c = controller(vendorId: 'v1');
      await c.load();
      expect(await c.remove(0), isTrue);
      expect(c.count, 1);
      expect(backend.table, hasLength(1));
      expect(backend.files.keys.where((k) => k.contains('a.webp')), isEmpty);
      expect(
        backend.files.keys.where((k) => k.contains('b.webp')),
        hasLength(2),
      );
    });

    test('if it cannot be deleted it stays, and it says so', () async {
      backend.seed('v1');
      final c = controller(vendorId: 'v1');
      await c.load();
      backend.failDeleteRow = true;
      expect(await c.remove(0), isFalse);
      expect(c.count, 1);
    });

    test('an index that is not there changes nothing', () async {
      backend.seed('v1');
      final c = controller(vendorId: 'v1');
      await c.load();
      expect(await c.remove(4), isTrue);
      expect(c.count, 1);
    });
  });

  group('photos waiting for an admin, or not approved', () {
    test('the count and the free places leave out rejected photos', () async {
      for (var i = 0; i < 17; i++) {
        backend.seed('v1');
      }
      backend.seed('v1', status: PhotoStatus.pending);
      backend.seed('v1', status: PhotoStatus.pending);
      for (var i = 0; i < 4; i++) {
        backend.seed('v1', status: PhotoStatus.rejected, rejectionReason: 'x');
      }
      final c = controller(vendorId: 'v1');
      await c.load();
      expect(c.items, hasLength(23));
      expect(c.count, 19);
      expect(c.remaining, 1);
      expect(c.atLimit, isFalse);
    });

    test(
      'the owners own list is loaded (all statuses), not the public one',
      () async {
        backend.seed('v1', status: PhotoStatus.pending);
        final c = controller(vendorId: 'v1');
        await c.load();
        expect(c.items.single.saved!.status, PhotoStatus.pending);
        expect(backend.calls, isNot(contains('rows v1 approved')));
      },
    );

    test(
      'a rejected photo at the end of the list can be deleted, and moved',
      () async {
        backend.seed('v1', sortOrder: 0, file: 'a.webp');
        backend.seed('v1', sortOrder: 1, file: 'b.webp');
        backend.seed(
          'v1',
          sortOrder: 2,
          file: 'c.webp',
          status: PhotoStatus.rejected,
          rejectionReason: 'x',
        );
        final c = controller(vendorId: 'v1');
        await c.load();
        expect(await c.move(2, -1), isTrue);
        expect(c.items.map((i) => i.saved!.storagePath.split('/').last), [
          'a.webp',
          'c.webp',
          'b.webp',
        ]);
        expect(await c.remove(1), isTrue);
        expect(c.items, hasLength(2));
        expect(backend.rowsOf('v1').map((p) => p.status), [
          PhotoStatus.approved,
          PhotoStatus.approved,
        ]);
      },
    );

    test(
      'a photo added to a business comes back waiting, and fills a place',
      () async {
        final c = controller(vendorId: 'v1');
        await c.load();
        nextPick = _picks(1);
        await c.add();
        expect(c.items.single.saved!.status, PhotoStatus.pending);
        expect(c.count, 1);
      },
    );
  });

  group('a new listing (no business yet)', () {
    test('photos are prepared and kept; nothing is uploaded', () async {
      final c = controller();
      nextPick = _picks(3);
      final r = await c.add();

      expect(r.compressed, hasLength(3));
      expect(c.count, 3);
      expect(c.hasPending, isTrue);
      expect(c.items.every((i) => i.pending != null && !i.uploading), isTrue);
      expect(backend.calls, isEmpty);
    });

    test('the limit counts the waiting photos too', () async {
      final c = controller();
      nextPick = _picks(20);
      await c.add();
      expect(c.atLimit, isTrue);
      nextPick = _picks(1, prefix: 'x');
      final r = await c.add();
      expect(r.nothingChosen, isTrue);
      expect(c.count, 20);

      final c2 = controller();
      nextPick = _picks(18);
      await c2.add();
      nextPick = _picks(3, prefix: 'more');
      final r2 = await c2.add();
      expect(r2.compressed, hasLength(2));
      expect(r2.skippedForLimit, 1);
    });

    test('they can be moved and removed before Submit', () async {
      final c = controller();
      nextPick = _picks(3);
      await c.add();
      expect(await c.move(2, -1), isTrue);
      expect(c.items.map((i) => i.pending!.fileName), [
        'p0.jpg',
        'p2.jpg',
        'p1.jpg',
      ]);
      expect(await c.remove(0), isTrue);
      expect(c.items.map((i) => i.pending!.fileName), ['p2.jpg', 'p1.jpg']);
      expect(backend.calls, isEmpty);
    });

    test(
      'once the business exists they are uploaded in the chosen order',
      () async {
        final c = controller();
        nextPick = _picks(3);
        await c.add();
        await c.move(2, -1);
        final failed = await c.uploadPending('new-vendor');

        expect(failed, isEmpty);
        final rows = backend.rowsOf('new-vendor');
        expect(rows.map((p) => p.sortOrder), [0, 1, 2]);
        expect(
          backend.files.keys.where((k) => k.startsWith('new-vendor/public/')),
          hasLength(3),
        );
        expect(
          backend.files.keys.where((k) => k.startsWith('new-vendor/original/')),
          hasLength(3),
        );
      },
    );

    test(
      'photos that could not be uploaded are named, the rest are saved',
      () async {
        final c = controller();
        nextPick = _picks(3);
        await c.add();
        backend.failUploadOf = 'id2.';
        final failed = await c.uploadPending('new-vendor');
        expect(failed, ['p1.jpg']);
        expect(backend.rowsOf('new-vendor'), hasLength(2));
      },
    );

    test('with no photo chosen nothing is asked of the server', () async {
      final c = controller();
      expect(await c.uploadPending('new-vendor'), isEmpty);
      expect(backend.calls, isEmpty);
    });
  });
}
