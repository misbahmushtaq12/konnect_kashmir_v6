import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:konnect_kashmir/services/business_photos/business_photo_service.dart';
import 'package:konnect_kashmir/services/business_photos/photo_processor.dart';
import 'package:konnect_kashmir/services/business_photos/photo_rules.dart';
import 'package:konnect_kashmir/services/business_photos/supabase_photo_backend.dart';

import 'support/fake_photo_backend.dart';

const _vendor = 'v1';

void main() {
  late FakePhotoBackend backend;
  late BusinessPhotoService service;
  var ids = 0;

  setUp(() {
    BusinessPhotoService.clearCache();
    backend = FakePhotoBackend();
    ids = 0;
    service = BusinessPhotoService(backend: backend, newId: () => 'id${++ids}');
  });

  group('adding a photo', () {
    test(
      'the compressed copy goes to original/, the watermarked one to public/, '
      'and the row points at the public one',
      () async {
        final out = await service.addPhotos(_vendor, [fakeProcessed('a.jpg')]);

        expect(out.single.ok, isTrue);
        expect(backend.files.keys, {
          'v1/original/id1.webp',
          'v1/public/id1.webp',
        });
        expect(backend.files['v1/original/id1.webp'], [1, 1, 1]);
        expect(backend.files['v1/public/id1.webp'], [2, 2, 2]);
        expect(backend.fileTypes['v1/public/id1.webp'], 'image/webp');
        final row = backend.table.values.single;
        expect(row.vendorId, _vendor);
        expect(row.storagePath, 'v1/public/id1.webp');
        expect(row.sortOrder, 0);
        // The order of the steps: original first, then public, then the row.
        expect(backend.calls.where((c) => !c.startsWith('rows')), [
          'upload v1/original/id1.webp',
          'upload v1/public/id1.webp',
          'insert v1/public/id1.webp 0',
        ]);
      },
    );

    test('a JPEG fallback keeps its extension and type', () async {
      final jpeg = ProcessedPhotoFor.jpeg('a.png');
      await service.addPhotos(_vendor, [jpeg]);
      expect(backend.files.keys, {'v1/original/id1.jpg', 'v1/public/id1.jpg'});
      expect(backend.fileTypes['v1/public/id1.jpg'], 'image/jpeg');
    });

    test(
      'the row is the last one + 1 (after the website\'s photos 0 to 3: 4)',
      () async {
        for (var i = 0; i < 4; i++) {
          backend.seed(_vendor, sortOrder: i);
        }
        await service.addPhotos(_vendor, [
          fakeProcessed('a'),
          fakeProcessed('b'),
        ]);
        final orders = backend.rowsOf(_vendor).map((p) => p.sortOrder);
        expect(orders, [0, 1, 2, 3, 4, 5]);
      },
    );

    test('the last one + 1 also when there are gaps', () async {
      backend.seed(_vendor, sortOrder: 0);
      backend.seed(_vendor, sortOrder: 7);
      await service.addPhotos(_vendor, [fakeProcessed('a')]);
      expect(backend.rowsOf(_vendor).last.sortOrder, 8);
    });

    test(
      'nothing in the file name, the owner or the place goes into the path',
      () async {
        await service.addPhotos(_vendor, [
          fakeProcessed('Home Srinagar 34.08N 74.79E.jpg'),
        ]);
        for (final path in backend.files.keys) {
          expect(path, matches(RegExp(r'^v1/(public|original)/id\d+\.webp$')));
        }
      },
    );

    test('each outcome is told as soon as it is known', () async {
      final heard = <String>[];
      await service.addPhotos(_vendor, [
        fakeProcessed('a'),
        fakeProcessed('b'),
      ], onEach: (o) => heard.add(o.photo.fileName));
      expect(heard, ['a', 'b']);
    });
  });

  group('the limit of 20 photos', () {
    test('1 photo is fine', () async {
      final out = await service.addPhotos(_vendor, [fakeProcessed('a')]);
      expect(out.single.ok, isTrue);
      expect(backend.rowsOf(_vendor), hasLength(1));
    });

    test('the 20th photo is accepted', () async {
      for (var i = 0; i < 19; i++) {
        backend.seed(_vendor);
      }
      final out = await service.addPhotos(_vendor, [
        fakeProcessed('twentieth'),
      ]);
      expect(out.single.ok, isTrue);
      expect(backend.rowsOf(_vendor), hasLength(20));
    });

    test('the 21st is refused, and nothing is uploaded for it', () async {
      for (var i = 0; i < 20; i++) {
        backend.seed(_vendor);
      }
      final filesBefore = backend.files.length;
      final out = await service.addPhotos(_vendor, [fakeProcessed('21st')]);

      expect(out.single.ok, isFalse);
      expect(out.single.error, isA<PhotoLimitReached>());
      expect(backend.rowsOf(_vendor), hasLength(20));
      expect(backend.files, hasLength(filesBefore));
      expect(backend.calls.where((c) => c.startsWith('upload')), isEmpty);
    });

    test(
      'a batch that goes over: the places that are left are filled, the rest refused',
      () async {
        for (var i = 0; i < 18; i++) {
          backend.seed(_vendor);
        }
        final out = await service.addPhotos(_vendor, [
          for (var i = 0; i < 5; i++) fakeProcessed('p$i'),
        ]);
        expect(out.where((o) => o.ok), hasLength(2));
        expect(
          out.where((o) => !o.ok).map((o) => o.error),
          everyElement(isA<PhotoLimitReached>()),
        );
        expect(backend.rowsOf(_vendor), hasLength(20));
      },
    );

    test('the database may say "full" when another phone filled the business: '
        'the same answer, and the files are removed again', () async {
      backend.triggerAlwaysFull = true;
      final out = await service.addPhotos(_vendor, [
        fakeProcessed('a'),
        fakeProcessed('b'),
      ]);
      expect(out.map((o) => o.error), everyElement(isA<PhotoLimitReached>()));
      expect(backend.files, isEmpty);
      expect(backend.table, isEmpty);
      // After "full" no further photo is tried.
      expect(backend.calls.where((c) => c.startsWith('insert')), hasLength(1));
    });
  });

  group('when a step fails, what was uploaded is deleted again', () {
    test('the row cannot be saved: both files go', () async {
      backend.failInsert = true;
      final out = await service.addPhotos(_vendor, [fakeProcessed('a')]);

      expect(out.single.ok, isFalse);
      expect(out.single.error, isA<PhotoBackendException>());
      expect(backend.table, isEmpty);
      expect(backend.files, isEmpty, reason: 'both copies were deleted');
      expect(
        backend.calls.last,
        'removeFiles v1/original/id1.webp,v1/public/id1.webp',
      );
    });

    test(
      'the public copy cannot be uploaded: the compressed copy goes',
      () async {
        backend.failUploadOf = '/public/';
        final out = await service.addPhotos(_vendor, [fakeProcessed('a')]);
        expect(out.single.ok, isFalse);
        expect(backend.files, isEmpty);
        expect(backend.table, isEmpty);
        expect(backend.calls.last, 'removeFiles v1/original/id1.webp');
      },
    );

    test('the first upload fails: nothing to delete, nothing left', () async {
      backend.failUploadOf = '/original/';
      final out = await service.addPhotos(_vendor, [fakeProcessed('a')]);
      expect(out.single.ok, isFalse);
      expect(backend.files, isEmpty);
      expect(backend.calls.where((c) => c.startsWith('removeFiles')), isEmpty);
    });

    test('a failed clean-up does not hide the real error', () async {
      backend
        ..failInsert = true
        ..failRemoveFiles = true;
      final out = await service.addPhotos(_vendor, [fakeProcessed('a')]);
      expect(out.single.error, isA<PhotoBackendException>());
      expect(
        (out.single.error as PhotoBackendException).message,
        'insert failed',
      );
    });

    test('one photo failing does not stop the next', () async {
      backend.failUploadOf = 'id1.';
      final out = await service.addPhotos(_vendor, [
        fakeProcessed('a'),
        fakeProcessed('b'),
      ]);
      expect(out.map((o) => o.ok), [false, true]);
      expect(backend.rowsOf(_vendor), hasLength(1));
      expect(backend.files.keys, {
        'v1/original/id2.webp',
        'v1/public/id2.webp',
      });
    });

    test('if the list cannot be read at all, nothing is uploaded', () async {
      backend.failRows = true;
      final out = await service.addPhotos(_vendor, [fakeProcessed('a')]);
      expect(out.single.ok, isFalse);
      expect(backend.calls.where((c) => c.startsWith('upload')), isEmpty);
    });
  });

  group('the list', () {
    test('in order of sort_order, then of when each was added', () async {
      final t = DateTime.utc(2026, 11, 3, 9);
      backend.seed(_vendor, sortOrder: 2, file: 'c.webp', createdAt: t);
      backend.seed(
        _vendor,
        sortOrder: 0,
        file: 'b.webp',
        createdAt: t.add(const Duration(minutes: 5)),
      );
      backend.seed(_vendor, sortOrder: 0, file: 'a.webp', createdAt: t);
      final list = await service.photos(_vendor);
      expect(list.map((p) => p.storagePath.split('/').last), [
        'a.webp',
        'b.webp',
        'c.webp',
      ]);
    });

    test(
      'each photo has a signed link; only public copies are ever signed',
      () async {
        backend.seed(_vendor, file: 'a.webp');
        // A row that points at a private copy must never be signed or shown.
        backend.seed(_vendor, file: 'secret.webp', folder: 'original');
        final list = await service.photos(_vendor);

        expect(list, hasLength(1));
        expect(
          list.single.url,
          startsWith('https://signed.example/v1/public/a.webp'),
        );
        expect(backend.signRequests.single, ['v1/public/a.webp']);
        for (final request in backend.signRequests) {
          expect(request.where((p) => p.contains('original')), isEmpty);
        }
      },
    );

    test('a business without photos asks for no links at all', () async {
      expect(await service.photos(_vendor), isEmpty);
      expect(backend.signRequests, isEmpty);
    });

    test('the list is not asked for again within a few minutes, until it '
        'changes or is refreshed', () async {
      backend.seed(_vendor);
      await service.photos(_vendor);
      await service.photos(_vendor);
      expect(backend.calls.where((c) => c.startsWith('rows')), hasLength(1));

      await service.photos(_vendor, refresh: true);
      expect(backend.calls.where((c) => c.startsWith('rows')), hasLength(2));

      // The owner's list was asked for too; it must not be served from before.
      await service.photos(_vendor, ownerView: true);
      await service.addPhotos(_vendor, [fakeProcessed('a')]);
      final after = await service.photos(_vendor, ownerView: true);
      expect(after, hasLength(2), reason: 'the new photo shows at once');
    });

    test('a list is used again only while it is fresh', () async {
      var now = DateTime.utc(2026, 11, 3, 9);
      final s = BusinessPhotoService(backend: backend, now: () => now);
      backend.seed(_vendor);
      await s.photos(_vendor);
      now = now.add(const Duration(minutes: 9));
      await s.photos(_vendor);
      expect(backend.calls.where((c) => c.startsWith('rows')), hasLength(1));
      now = now.add(const Duration(minutes: 2));
      await s.photos(_vendor);
      expect(backend.calls.where((c) => c.startsWith('rows')), hasLength(2));
    });

    test(
      'a photo whose link could not be made is kept, without a link',
      () async {
        backend.seed(_vendor, file: 'a.webp');
        backend.files.remove('v1/public/a.webp'); // the file is gone
        final list = await service.photos(_vendor);
        expect(list.single.url, isNull);
      },
    );

    test('network trouble is an error, not an empty list', () async {
      backend.failRows = true;
      await expectLater(
        service.photos(_vendor),
        throwsA(isA<PhotoBackendException>()),
      );
      backend.failRows = false;
      backend.seed(_vendor);
      backend.failSigning = true;
      await expectLater(
        service.photos(_vendor, refresh: true),
        throwsA(isA<PhotoBackendException>()),
      );
    });
  });

  group('deleting', () {
    test('the row is deleted first, then both files', () async {
      final p = backend.seed(_vendor, file: 'a.webp');
      await service.deletePhoto(p);

      expect(backend.table, isEmpty);
      expect(backend.files, isEmpty);
      final calls = backend.calls;
      expect(calls.first, 'deleteRow ${p.id}');
      expect(calls.last, 'removeFiles v1/public/a.webp,v1/original/a.webp');
    });

    test('if the row cannot be deleted, no file is touched', () async {
      final p = backend.seed(_vendor, file: 'a.webp');
      backend.failDeleteRow = true;
      await expectLater(
        service.deletePhoto(p),
        throwsA(isA<PhotoBackendException>()),
      );
      expect(backend.table, hasLength(1));
      expect(backend.files, hasLength(2));
      expect(backend.calls.where((c) => c.startsWith('removeFiles')), isEmpty);
    });

    test('if the files cannot be deleted, the photo is still gone', () async {
      final p = backend.seed(_vendor, file: 'a.webp');
      backend.failRemoveFiles = true;
      await service.deletePhoto(p);
      expect(backend.table, isEmpty);
    });

    test('a path of another business is never deleted', () async {
      const foreign = BusinessPhoto(
        id: 'x',
        vendorId: _vendor,
        storagePath: 'v2/public/a.webp',
        sortOrder: 0,
      );
      await service.deletePhoto(foreign);
      expect(backend.calls.where((c) => c.startsWith('removeFiles')), isEmpty);
    });

    test(
      'after a delete the list is asked for again, and a place is free',
      () async {
        for (var i = 0; i < 20; i++) {
          backend.seed(_vendor);
        }
        final full = await service.photos(_vendor);
        expect(full, hasLength(20));
        await service.deletePhoto(full.first);
        expect(await service.photos(_vendor), hasLength(19));
        final out = await service.addPhotos(_vendor, [fakeProcessed('new')]);
        expect(out.single.ok, isTrue);
      },
    );
  });

  group('the order', () {
    List<BusinessPhoto> four() => [
      for (var i = 0; i < 4; i++)
        backend.seed(_vendor, sortOrder: i, file: 'p$i.webp'),
    ];

    test('moved(): one place earlier, one later, and at the ends nothing', () {
      expect(moved([0, 1, 2, 3], 2, 1), [0, 2, 1, 3]);
      expect(moved([0, 1, 2, 3], 1, 2), [0, 2, 1, 3]);
      expect(moved([0, 1, 2, 3], 0, -1), [0, 1, 2, 3]);
      expect(moved([0, 1, 2, 3], 3, 4), [0, 1, 2, 3]);
      expect(moved([0, 1, 2, 3], 9, 0), [0, 1, 2, 3]);
    });

    test(
      'the new order is saved, only for the photos that changed place',
      () async {
        final photos = four();
        final done = await service.saveOrder(moved(photos, 2, 1));

        expect(done.map((p) => p.storagePath.split('/').last), [
          'p0.webp',
          'p2.webp',
          'p1.webp',
          'p3.webp',
        ]);
        expect(done.map((p) => p.sortOrder), [0, 1, 2, 3]);
        expect(backend.calls.where((c) => c.startsWith('sort')), hasLength(2));
        final stored = await service.photos(_vendor, refresh: true);
        expect(stored.map((p) => p.storagePath.split('/').last), [
          'p0.webp',
          'p2.webp',
          'p1.webp',
          'p3.webp',
        ]);
      },
    );

    test(
      'moving the last to the front gives every photo a new order',
      () async {
        final photos = four();
        final done = await service.saveOrder(moved(photos, 3, 0));
        expect(backend.calls.where((c) => c.startsWith('sort')), hasLength(4));
        expect(done.map((p) => p.sortOrder), [0, 1, 2, 3]);
        expect(
          (await service.photos(_vendor, refresh: true)).first.storagePath,
          'v1/public/p3.webp',
        );
      },
    );

    test('gaps in the old orders are closed up', () async {
      final a = backend.seed(_vendor, sortOrder: 3);
      final b = backend.seed(_vendor, sortOrder: 9);
      final done = await service.saveOrder([b, a]);
      expect(done.map((p) => p.sortOrder), [0, 1]);
    });

    test('a failed save is an error (the screen then asks again)', () async {
      final photos = four();
      backend.failSortUpdate = true;
      await expectLater(
        service.saveOrder(moved(photos, 1, 0)),
        throwsA(isA<PhotoBackendException>()),
      );
    });
  });

  group('admin approval', () {
    test(
      'a photo status is read from the server, an unknown one as waiting',
      () {
        expect(PhotoStatus.parse('approved'), PhotoStatus.approved);
        expect(PhotoStatus.parse('APPROVED '), PhotoStatus.approved);
        expect(PhotoStatus.parse('pending'), PhotoStatus.pending);
        expect(PhotoStatus.parse('rejected'), PhotoStatus.rejected);
        // An older row without the column, or a blank one, is an approved photo.
        expect(PhotoStatus.parse(null), PhotoStatus.approved);
        expect(PhotoStatus.parse(''), PhotoStatus.approved);
        // Never show what we cannot read.
        expect(PhotoStatus.parse('on_hold'), PhotoStatus.pending);
      },
    );

    test('a row carries its status and the reason it was not approved', () {
      final p = BusinessPhoto.fromRow({
        'id': 'r1',
        'vendor_id': 'v1',
        'storage_path': 'v1/public/a.webp',
        'sort_order': 0,
        'status': 'rejected',
        'rejection_reason': '  Not a photo of this business ',
      });
      expect(p.status, PhotoStatus.rejected);
      expect(p.rejectionReason, 'Not a photo of this business');
      final blank = BusinessPhoto.fromRow({
        'id': 'r2',
        'vendor_id': 'v1',
        'storage_path': 'v1/public/b.webp',
        'sort_order': 1,
        'status': 'approved',
        'rejection_reason': '   ',
      });
      expect(blank.rejectionReason, isNull);
      // copies keep both
      final c = p.copyWith(url: 'https://x');
      expect(c.status, PhotoStatus.rejected);
      expect(c.rejectionReason, 'Not a photo of this business');
    });

    void seedThree() {
      backend.seed(_vendor, sortOrder: 0, file: 'live.webp');
      backend.seed(
        _vendor,
        sortOrder: 1,
        file: 'wait.webp',
        status: PhotoStatus.pending,
      );
      backend.seed(
        _vendor,
        sortOrder: 2,
        file: 'no.webp',
        status: PhotoStatus.rejected,
        rejectionReason: 'Photo contains content that is not allowed.',
      );
    }

    test('the public sees approved photos only', () async {
      seedThree();
      final list = await service.photos(_vendor);
      expect(list.map((p) => p.storagePath.split('/').last), ['live.webp']);
      expect(list.single.status, PhotoStatus.approved);
      // The server is asked for approved photos only, and only those are signed.
      expect(backend.calls, contains('rows v1 approved'));
      expect(backend.signRequests.single, ['v1/public/live.webp']);
    });

    test('even a server that answered with more would not get a waiting or '
        'rejected photo shown', () async {
      seedThree();
      final careless = _IgnoresApprovedOnly(backend);
      final list = await BusinessPhotoService(
        backend: careless,
      ).photos(_vendor);
      expect(list.map((p) => p.storagePath.split('/').last), ['live.webp']);
      expect(backend.signRequests.single, ['v1/public/live.webp']);
    });

    test('the owner sees every photo with its status and reason', () async {
      seedThree();
      final list = await service.photos(_vendor, ownerView: true);
      expect(list.map((p) => p.status), [
        PhotoStatus.approved,
        PhotoStatus.pending,
        PhotoStatus.rejected,
      ]);
      expect(
        list.last.rejectionReason,
        'Photo contains content that is not allowed.',
      );
      expect(backend.calls, contains('rows v1'));
      expect(backend.calls, isNot(contains('rows v1 approved')));
      expect(
        list.every((p) => p.url != null),
        isTrue,
        reason: 'all can be shown to the owner',
      );
    });

    test('the two lists are kept apart, and a change drops both', () async {
      seedThree();
      expect(await service.photos(_vendor), hasLength(1));
      expect(await service.photos(_vendor, ownerView: true), hasLength(3));
      // Both come from the cache now.
      final before = backend.calls.where((c) => c.startsWith('rows')).length;
      await service.photos(_vendor);
      await service.photos(_vendor, ownerView: true);
      expect(backend.calls.where((c) => c.startsWith('rows')).length, before);

      await service.addPhotos(_vendor, [fakeProcessed('new')]);
      expect(
        await service.photos(_vendor),
        hasLength(1),
        reason: 'the new one waits',
      );
      expect(await service.photos(_vendor, ownerView: true), hasLength(4));
    });

    test(
      'a new photo waits for an admin: the owner sees it, the public does not',
      () async {
        await service.addPhotos(_vendor, [fakeProcessed('a')]);
        final mine = await service.photos(_vendor, ownerView: true);
        expect(mine.single.status, PhotoStatus.pending);
        expect(await service.photos(_vendor), isEmpty);
      },
    );

    test(
      'the limit of 20 counts waiting and approved photos together',
      () async {
        for (var i = 0; i < 12; i++) {
          backend.seed(_vendor, status: PhotoStatus.pending);
        }
        for (var i = 0; i < 8; i++) {
          backend.seed(_vendor);
        }
        final out = await service.addPhotos(_vendor, [fakeProcessed('21st')]);
        expect(out.single.error, isA<PhotoLimitReached>());
        expect(backend.calls.where((c) => c.startsWith('upload')), isEmpty);
      },
    );

    test('a rejected photo does not use up a place', () async {
      for (var i = 0; i < 18; i++) {
        backend.seed(_vendor);
      }
      for (var i = 0; i < 5; i++) {
        backend.seed(
          _vendor,
          status: PhotoStatus.rejected,
          rejectionReason: 'Inappropriate content',
        );
      }
      // 23 rows, but only 18 count: two more fit.
      final out = await service.addPhotos(_vendor, [
        fakeProcessed('a'),
        fakeProcessed('b'),
        fakeProcessed('c'),
      ]);
      expect(out.map((o) => o.ok), [true, true, false]);
      expect(out.last.error, isA<PhotoLimitReached>());
    });

    test(
      'the new photo goes after every photo, rejected ones included',
      () async {
        backend.seed(_vendor, sortOrder: 0);
        backend.seed(_vendor, sortOrder: 5, status: PhotoStatus.rejected);
        await service.addPhotos(_vendor, [fakeProcessed('a')]);
        expect(backend.rowsOf(_vendor).last.sortOrder, 6);
      },
    );

    test(
      'the owner can delete a waiting or a rejected photo, row and files',
      () async {
        final waiting = backend.seed(
          _vendor,
          file: 'w.webp',
          status: PhotoStatus.pending,
        );
        final rejected = backend.seed(
          _vendor,
          file: 'r.webp',
          status: PhotoStatus.rejected,
          rejectionReason: 'x',
        );
        await service.deletePhoto(waiting);
        await service.deletePhoto(rejected);
        expect(backend.table, isEmpty);
        expect(backend.files, isEmpty);
      },
    );

    test('moving photos keeps their status', () async {
      final a = backend.seed(_vendor, sortOrder: 0, file: 'a.webp');
      final b = backend.seed(
        _vendor,
        sortOrder: 1,
        file: 'b.webp',
        status: PhotoStatus.pending,
      );
      final done = await service.saveOrder([b, a]);
      expect(done.map((p) => p.status), [
        PhotoStatus.pending,
        PhotoStatus.approved,
      ]);
      expect(backend.rowsOf(_vendor).map((p) => p.status), [
        PhotoStatus.pending,
        PhotoStatus.approved,
      ]);
    });
  });

  group('the real backend, with its requests checked', () {
    late List<http.Request> sent;
    late SupabasePhotoBackend api;
    late String Function(http.Request) answer;
    var status = 200;

    setUp(() {
      sent = [];
      status = 200;
      answer = (_) => '[]';
      api = SupabasePhotoBackend(
        token: () => 'user-token',
        client: MockClient((req) async {
          sent.add(req);
          return http.Response(
            answer(req),
            status,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
    });

    test(
      'rows: this business only, in order, with the user\'s token',
      () async {
        answer = (_) => jsonEncode([
          {
            'id': 'r1',
            'vendor_id': 'v1',
            'storage_path': 'v1/public/a.webp',
            'sort_order': 1,
            'created_at': '2026-11-03T09:30:11.408225+00:00',
          },
        ]);
        final rows = await api.rows('v1');

        expect(rows.single.storagePath, 'v1/public/a.webp');
        expect(rows.single.sortOrder, 1);
        final r = sent.single;
        expect(r.method, 'GET');
        expect(r.url.path, '/rest/v1/business_photos');
        expect(r.url.queryParameters['vendor_id'], 'eq.v1');
        expect(r.url.queryParameters['order'], 'sort_order.asc,created_at.asc');
        expect(r.headers['Authorization'], 'Bearer user-token');
        expect(r.headers['apikey'], isNotEmpty);
      },
    );

    test(
      'rows: the public list asks for approved photos only; the owner list '
      'does not filter, and both ask for the status and the reason',
      () async {
        answer = (_) => jsonEncode([
          {
            'id': 'r1',
            'vendor_id': 'v1',
            'storage_path': 'v1/public/a.webp',
            'sort_order': 0,
            'status': 'rejected',
            'rejection_reason': 'Inappropriate content',
          },
        ]);
        final mine = await api.rows('v1');
        expect(mine.single.status, PhotoStatus.rejected);
        expect(mine.single.rejectionReason, 'Inappropriate content');
        expect(sent.last.url.queryParameters.containsKey('status'), isFalse);
        expect(sent.last.url.queryParameters['select'], contains('status'));
        expect(
          sent.last.url.queryParameters['select'],
          contains('rejection_reason'),
        );

        await api.rows('v1', approvedOnly: true);
        expect(sent.last.url.queryParameters['status'], 'eq.approved');
        expect(sent.last.url.queryParameters['vendor_id'], 'eq.v1');
      },
    );

    test('without a user token the public key is used', () async {
      final anon = SupabasePhotoBackend(
        client: MockClient((req) async {
          sent.add(req);
          return http.Response('[]', 200);
        }),
      );
      await anon.rows('v1');
      expect(
        sent.single.headers['Authorization'],
        'Bearer ${sent.single.headers['apikey']}',
      );
    });

    test('signing: only public paths, 6 hours, links made absolute', () async {
      answer = (_) => jsonEncode([
        {
          'path': 'v1/public/a.webp',
          'signedURL': '/object/sign/business-photos/v1/public/a.webp?token=T',
          'error': null,
        },
        {
          'path': 'v1/public/b.webp',
          'signedURL': null,
          'error': 'Object not found',
        },
      ]);
      final urls = await api.signedUrls([
        'v1/public/a.webp',
        'v1/public/b.webp',
        'v1/original/secret.webp',
      ]);

      final r = sent.single;
      expect(r.method, 'POST');
      expect(r.url.path, '/storage/v1/object/sign/business-photos');
      final body = jsonDecode(r.body) as Map;
      expect(body['expiresIn'], 21600);
      expect(body['paths'], ['v1/public/a.webp', 'v1/public/b.webp']);
      expect(urls.keys, ['v1/public/a.webp']);
      expect(
        urls['v1/public/a.webp'],
        endsWith(
          '/storage/v1/object/sign/business-photos/v1/public/a.webp?token=T',
        ),
      );
      expect(urls['v1/public/a.webp'], startsWith('https://'));
    });

    test('nothing public to sign: no request', () async {
      expect(await api.signedUrls(['v1/original/x.webp']), isEmpty);
      expect(sent, isEmpty);
    });

    test('upload: to the bucket, with the type, never overwriting', () async {
      status = 200;
      await api.upload(
        'v1/public/a.webp',
        Uint8List.fromList([9, 8, 7]),
        'image/webp',
      );
      final r = sent.single;
      expect(r.method, 'POST');
      expect(r.url.path, '/storage/v1/object/business-photos/v1/public/a.webp');
      expect(r.headers['Content-Type'], 'image/webp');
      expect(r.headers['x-upsert'], 'false');
      expect(r.bodyBytes, [9, 8, 7]);
    });

    test('a refused upload is an error with the server\'s words', () async {
      status = 403;
      answer = (_) =>
          jsonEncode({'message': 'new row violates row-level security policy'});
      await expectLater(
        api.upload('v1/public/a.webp', Uint8List(1), 'image/webp'),
        throwsA(
          isA<PhotoBackendException>().having(
            (e) => e.message,
            'message',
            contains('row-level security'),
          ),
        ),
      );
    });

    test('delete files: one request with every path', () async {
      await api.removeFiles(['v1/public/a.webp', 'v1/original/a.webp']);
      final r = sent.single;
      expect(r.method, 'DELETE');
      expect(r.url.path, '/storage/v1/object/business-photos');
      expect(jsonDecode(r.body), {
        'prefixes': ['v1/public/a.webp', 'v1/original/a.webp'],
      });
    });

    test(
      'insert: the row, and the limit message of the trigger is passed on',
      () async {
        status = 201;
        answer = (_) => jsonEncode([
          {
            'id': 'r9',
            'vendor_id': 'v1',
            'storage_path': 'v1/public/a.webp',
            'sort_order': 4,
          },
        ]);
        final row = await api.insertRow(
          vendorId: 'v1',
          storagePath: 'v1/public/a.webp',
          sortOrder: 4,
        );
        expect(row.id, 'r9');
        expect(jsonDecode(sent.single.body), {
          'vendor_id': 'v1',
          'storage_path': 'v1/public/a.webp',
          'sort_order': 4,
        });

        status = 400;
        answer = (_) => jsonEncode({
          'code': 'P0001',
          'message': 'A business can have at most 20 photos',
        });
        await expectLater(
          api.insertRow(
            vendorId: 'v1',
            storagePath: 'v1/public/b.webp',
            sortOrder: 5,
          ),
          throwsA(
            isA<PhotoBackendException>().having(
              (e) => e.message,
              'message',
              'A business can have at most 20 photos',
            ),
          ),
        );
      },
    );

    test(
      'the limit message turns into "limit reached" through the service',
      () async {
        final limited = SupabasePhotoBackend(
          token: () => 't',
          client: MockClient((req) async {
            if (req.method == 'GET') return http.Response('[]', 200);
            if (req.url.path.contains('/storage/')) {
              return http.Response('{}', 200);
            }
            return http.Response(
              jsonEncode({'message': 'A business can have at most 20 photos'}),
              400,
            );
          }),
        );
        final out = await BusinessPhotoService(
          backend: limited,
          newId: () => 'z',
        ).addPhotos('v1', [fakeProcessed('a')]);
        expect(out.single.error, isA<PhotoLimitReached>());
      },
    );

    test(
      'a delete or a move that a policy silently ignores is an error',
      () async {
        status = 200;
        answer = (_) =>
            '[]'; // return=representation with nothing: no row was touched
        await expectLater(
          api.deleteRow('r1'),
          throwsA(isA<PhotoBackendException>()),
        );
        await expectLater(
          api.updateSortOrder('r1', 2),
          throwsA(isA<PhotoBackendException>()),
        );

        answer = (_) => jsonEncode([
          {'id': 'r1'},
        ]);
        await api.deleteRow('r1');
        await api.updateSortOrder('r1', 2);
        final patch = sent.last;
        expect(patch.method, 'PATCH');
        expect(patch.url.queryParameters['id'], 'eq.r1');
        expect(jsonDecode(patch.body), {'sort_order': 2});
      },
    );
  });
}

/// A photo written as JPEG (the fallback when WEBP is not available).
class ProcessedPhotoFor {
  static ProcessedPhoto jpeg(String name) => ProcessedPhoto(
    fileName: name,
    original: Uint8List.fromList([1]),
    watermarked: Uint8List.fromList([2]),
    format: PhotoFormat.jpeg,
    inputBytes: 10,
  );
}

/// A backend that ignores [approvedOnly] and answers with every row (as if the
/// filter were lost on the way), to check the app does not show them anyway.
class _IgnoresApprovedOnly implements BusinessPhotoBackend {
  final FakePhotoBackend inner;
  _IgnoresApprovedOnly(this.inner);

  @override
  Future<List<BusinessPhoto>> rows(
    String vendorId, {
    bool approvedOnly = false,
  }) => inner.rows(vendorId);
  @override
  Future<Map<String, String>> signedUrls(List<String> publicPaths) =>
      inner.signedUrls(publicPaths);
  @override
  Future<void> upload(String path, Uint8List bytes, String contentType) =>
      inner.upload(path, bytes, contentType);
  @override
  Future<void> removeFiles(List<String> paths) => inner.removeFiles(paths);
  @override
  Future<BusinessPhoto> insertRow({
    required String vendorId,
    required String storagePath,
    required int sortOrder,
  }) => inner.insertRow(
    vendorId: vendorId,
    storagePath: storagePath,
    sortOrder: sortOrder,
  );
  @override
  Future<void> deleteRow(String id) => inner.deleteRow(id);
  @override
  Future<void> updateSortOrder(String id, int sortOrder) =>
      inner.updateSortOrder(id, sortOrder);
}
