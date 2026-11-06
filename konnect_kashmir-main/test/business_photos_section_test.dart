import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/l10n/l10n.dart';
import 'package:konnect_kashmir/services/business_photos/business_photo_service.dart';
import 'package:konnect_kashmir/services/business_photos/business_photos_controller.dart';
import 'package:konnect_kashmir/services/business_photos/photo_picker.dart';
import 'package:konnect_kashmir/services/business_photos/photo_rules.dart';
import 'package:konnect_kashmir/theme/app_theme.dart';
import 'package:konnect_kashmir/widgets/business_photos_section.dart';

import 'support/fake_photo_backend.dart';
import 'support/fake_photo_images.dart';

PickedPhoto _pick(String name, {int size = 700 * 1024}) => PickedPhoto(
  name: name,
  length: size,
  read: () async => Uint8List(size > 2 * 1024 * 1024 ? 8 : size),
);

void main() {
  late FakePhotoBackend backend;
  late BusinessPhotoService service;
  late List<PickedPhoto> nextPick;
  late List<int> pickerLimits;
  var ids = 0;

  setUp(() {
    BusinessPhotoService.clearCache();
    backend = FakePhotoBackend();
    ids = 0;
    service = BusinessPhotoService(backend: backend, newId: () => 'id${++ids}');
    nextPick = [];
    pickerLimits = [];
  });

  BusinessPhotosController controller({String? vendorId}) =>
      BusinessPhotosController(
        vendorId: vendorId,
        service: service,
        processor: FakePhotoProcessor(),
        picker: (limit) async {
          pickerLimits.add(limit);
          return nextPick;
        },
      );

  Future<void> show(
    WidgetTester tester,
    BusinessPhotosController c, {
    Locale locale = const Locale('en'),
    double textScale = 1,
    double width = 390,
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = Size(width, 1400) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.light,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: BusinessPhotosSection(controller: c),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Lets the controller's work (all in memory here) finish.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  group('a new listing', () {
    testWidgets(
      'shows the heading, the count, the Add tile and two empty frames',
      (tester) async {
        await FakePhotoImages.install(tester);
        await show(tester, controller());

        expect(find.text('Business Photos'), findsOneWidget);
        expect(find.text('Optional'), findsOneWidget);
        expect(
          find.text('Add up to 20 photos to showcase your business'),
          findsOneWidget,
        );
        expect(find.text('Photos (0/20)'), findsOneWidget);
        expect(find.text('Add photos'), findsOneWidget);
        expect(find.byIcon(Icons.image_outlined), findsNWidgets(2));
        expect(find.byTooltip('Delete photo'), findsNothing);
        expect(
          find.text(
            'You have reached the limit of 20 photos. Delete one to add another.',
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('adding shows "Compressed: name: X KB -> Y KB" and the count', (
      tester,
    ) async {
      await FakePhotoImages.install(tester);
      final c = controller();
      await show(tester, c);
      nextPick = [_pick('shop.jpg')];
      await tester.tap(find.text('Add photos'));
      await settle(tester);

      expect(pickerLimits, [20]);
      expect(
        find.text('Compressed: shop.jpg: 700 KB -> 70 KB'),
        findsOneWidget,
      );
      expect(find.text('Photos (1/20)'), findsOneWidget);
      expect(
        find.text('Your photos are uploaded when you submit.'),
        findsOneWidget,
        reason: 'a new listing has no business to upload to yet',
      );
      expect(find.byTooltip('Delete photo'), findsOneWidget);
      expect(backend.calls, isEmpty, reason: 'nothing uploaded yet');
    });

    testWidgets('a long list of sizes is cut short', (tester) async {
      await FakePhotoImages.install(tester);
      final c = controller();
      await show(tester, c);
      nextPick = [for (var i = 0; i < 8; i++) _pick('p$i.jpg')];
      await tester.tap(find.text('Add photos'));
      await settle(tester);
      expect(find.textContaining('Compressed: p'), findsNWidgets(5));
      expect(find.text('+3 more'), findsOneWidget);
    });
  });

  group('editing', () {
    Future<BusinessPhotosController> withPhotos(
      WidgetTester tester,
      int n, {
      double width = 390,
      Locale locale = const Locale('en'),
    }) async {
      await FakePhotoImages.install(tester);
      for (var i = 0; i < n; i++) {
        backend.seed('v1', sortOrder: i, file: 'p$i.webp');
      }
      final c = controller(vendorId: 'v1');
      await c.load();
      await show(tester, c, width: width, locale: locale);
      return c;
    }

    testWidgets('shows the saved photos with their buttons', (tester) async {
      await withPhotos(tester, 3);
      expect(find.text('Photos (3/20)'), findsOneWidget);
      expect(find.byTooltip('Delete photo'), findsNWidgets(3));
      expect(find.byTooltip('Move earlier'), findsNWidgets(3));
      expect(find.byTooltip('Move later'), findsNWidgets(3));
      for (final n in ['1', '2', '3']) {
        expect(find.text(n), findsOneWidget);
      }
      expect(find.byIcon(Icons.image_outlined), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('at 20 photos: the count, the message, and Add does nothing', (
      tester,
    ) async {
      await withPhotos(tester, 20);
      expect(find.text('Photos (20/20)'), findsOneWidget);
      expect(
        find.text(
          'You have reached the limit of 20 photos. Delete one to add another.',
        ),
        findsOneWidget,
      );
      nextPick = [_pick('21st.jpg')];
      await tester.tap(find.text('Add photos'));
      await settle(tester);
      expect(pickerLimits, isEmpty, reason: 'the gallery is not even opened');
      expect(backend.rowsOf('v1'), hasLength(20));
    });

    testWidgets(
      'one more than there is room for: the extra ones are told about',
      (tester) async {
        await withPhotos(tester, 18);
        nextPick = [for (var i = 0; i < 5; i++) _pick('n$i.jpg')];
        await tester.tap(find.text('Add photos'));
        await settle(tester);

        expect(pickerLimits, [2]);
        expect(find.text('Photos (20/20)'), findsOneWidget);
        expect(
          find.text(
            '3 photos were not added. A business can have up to 20 photos.',
          ),
          findsOneWidget,
        );
        expect(backend.rowsOf('v1'), hasLength(20));
      },
    );

    testWidgets('a file that is too big, and one that is not a photo', (
      tester,
    ) async {
      await withPhotos(tester, 1);
      nextPick = [_pick('big.jpg', size: kMaxPhotoFileBytes + 1)];
      await tester.tap(find.text('Add photos'));
      await settle(tester);
      expect(
        find.text('big.jpg is larger than 15 MB, so it was not added.'),
        findsOneWidget,
      );

      nextPick = [_pick('bad.gif')];
      await tester.tap(find.text('Add photos'));
      await settle(tester);
      expect(
        find.text(
          'bad.gif is not a JPG, PNG or WEBP photo, so it was not added.',
        ),
        findsOneWidget,
      );

      nextPick = [_pick('bad1.gif'), _pick('bad2.gif')];
      await tester.tap(find.text('Add photos'));
      await settle(tester);
      expect(
        find.text(
          '2 photos were not added. Only JPG, PNG or WEBP files up to 15 MB can be used.',
        ),
        findsOneWidget,
      );
      expect(find.text('Photos (1/20)'), findsOneWidget);
    });

    testWidgets('an upload that fails is told, and nothing is left behind', (
      tester,
    ) async {
      await withPhotos(tester, 1);
      backend.failInsert = true;
      nextPick = [_pick('a.jpg')];
      await tester.tap(find.text('Add photos'));
      await settle(tester);
      expect(
        find.text(
          '1 photos could not be uploaded. Check your connection and try again.',
        ),
        findsOneWidget,
      );
      expect(find.text('Photos (1/20)'), findsOneWidget);
      expect(backend.files.keys.where((k) => k.contains('id1')), isEmpty);
    });

    testWidgets('move later changes the order, and it is saved', (
      tester,
    ) async {
      await withPhotos(tester, 3);
      await tester.tap(find.byTooltip('Move later').first);
      await settle(tester);
      expect(backend.rowsOf('v1').map((p) => p.storagePath.split('/').last), [
        'p1.webp',
        'p0.webp',
        'p2.webp',
      ]);
      await tester.tap(find.byTooltip('Move earlier').last);
      await settle(tester);
      expect(backend.rowsOf('v1').map((p) => p.storagePath.split('/').last), [
        'p1.webp',
        'p2.webp',
        'p0.webp',
      ]);
    });

    testWidgets('the first photo cannot move earlier, the last not later', (
      tester,
    ) async {
      await withPhotos(tester, 3);
      backend.calls.clear();
      await tester.tap(find.byTooltip('Move earlier').first);
      await tester.tap(find.byTooltip('Move later').last);
      await settle(tester);
      expect(backend.calls, isEmpty);
    });

    testWidgets('a save that fails says so', (tester) async {
      await withPhotos(tester, 3);
      backend.failSortUpdate = true;
      await tester.tap(find.byTooltip('Move later').first);
      await settle(tester);
      expect(
        find.text(
          'The new order could not be saved. Check your connection and try again.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('delete asks first; Cancel keeps the photo', (tester) async {
      await withPhotos(tester, 2);
      await tester.tap(find.byTooltip('Delete photo').first);
      await tester.pump();
      expect(find.text('Delete this photo?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(find.text('Photos (2/20)'), findsOneWidget);
      expect(backend.rowsOf('v1'), hasLength(2));
    });

    testWidgets('delete removes the row and both files', (tester) async {
      await withPhotos(tester, 2);
      await tester.tap(find.byTooltip('Delete photo').first);
      await tester.pump();
      await tester.tap(find.text('Delete photo'));
      await settle(tester);

      expect(find.text('Photos (1/20)'), findsOneWidget);
      expect(backend.rowsOf('v1'), hasLength(1));
      expect(backend.files.keys.where((k) => k.contains('p0.webp')), isEmpty);
      expect(
        backend.files.keys.where((k) => k.contains('p1.webp')),
        hasLength(2),
      );
    });

    testWidgets('a delete that fails says so and keeps the photo', (
      tester,
    ) async {
      await withPhotos(tester, 2);
      backend.failDeleteRow = true;
      await tester.tap(find.byTooltip('Delete photo').first);
      await tester.pump();
      await tester.tap(find.text('Delete photo'));
      await settle(tester);
      expect(
        find.text(
          'The photo could not be deleted. Check your connection and try again.',
        ),
        findsOneWidget,
      );
      expect(find.text('Photos (2/20)'), findsOneWidget);
    });

    testWidgets('a photo whose link is bad shows a tile, not an exception', (
      tester,
    ) async {
      await FakePhotoImages.install(tester, broken: {'v1/public/p0.webp'});
      backend.seed('v1', sortOrder: 0, file: 'p0.webp');
      final c = controller(vendorId: 'v1');
      await c.load();
      await show(tester, c);
      await settle(tester);
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('photos that cannot be loaded: told, with Retry', (
      tester,
    ) async {
      await FakePhotoImages.install(tester);
      backend.failRows = true;
      final c = controller(vendorId: 'v1');
      await c.load();
      await show(tester, c);
      expect(
        find.text('Your photos could not be loaded. Check your connection.'),
        findsOneWidget,
      );
      backend.failRows = false;
      backend.seed('v1', file: 'p0.webp');
      await tester.tap(find.text('Retry'));
      await settle(tester);
      expect(find.text('Photos (1/20)'), findsOneWidget);
      expect(
        find.text('Your photos could not be loaded. Check your connection.'),
        findsNothing,
      );
    });
  });

  group('admin approval, as the owner sees it', () {
    const longReason =
        'Not a photo of this business. Please upload a clear picture of your shop front or of your work, without any text or logo on it.';

    Future<BusinessPhotosController> mixed(
      WidgetTester tester, {
      double width = 390,
      ThemeData? theme,
      Locale locale = const Locale('en'),
      double textScale = 1,
      String reason = 'Not a photo of this business',
    }) async {
      await FakePhotoImages.install(tester);
      backend.seed('v1', sortOrder: 0, file: 'a.webp');
      backend.seed(
        'v1',
        sortOrder: 1,
        file: 'b.webp',
        status: PhotoStatus.pending,
      );
      backend.seed(
        'v1',
        sortOrder: 2,
        file: 'c.webp',
        status: PhotoStatus.rejected,
        rejectionReason: reason,
      );
      final c = controller(vendorId: 'v1');
      await c.load();
      await show(
        tester,
        c,
        width: width,
        theme: theme,
        locale: locale,
        textScale: textScale,
      );
      return c;
    }

    testWidgets(
      'each photo shows where it stands: live, under review, or not approved with the reason',
      (tester) async {
        await mixed(tester);
        expect(find.text('Under review'), findsOneWidget);
        expect(
          find.text('Not approved: Not a photo of this business'),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('status-0')),
          findsNothing,
          reason: 'an approved photo has no note',
        );
        expect(find.byKey(const ValueKey('status-1')), findsOneWidget);
        expect(find.byKey(const ValueKey('status-2')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'a rejected photo without a reason still says it was not approved',
      (tester) async {
        await FakePhotoImages.install(tester);
        backend.seed('v1', file: 'x.webp', status: PhotoStatus.rejected);
        final c = controller(vendorId: 'v1');
        await c.load();
        await show(tester, c);
        expect(find.text('Not approved'), findsOneWidget);
      },
    );

    testWidgets('tapping the note reads the whole reason', (tester) async {
      await mixed(tester, reason: longReason);
      await tester.tap(find.byKey(const ValueKey('status-2')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Why this photo was not approved'), findsOneWidget);
      expect(find.text(longReason), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Why this photo was not approved'), findsNothing);
    });

    testWidgets('the line under the block says photos are shown after review', (
      tester,
    ) async {
      await mixed(tester);
      expect(find.text('Photos are shown after admin review.'), findsOneWidget);
    });

    testWidgets('the same line on a new listing', (tester) async {
      await FakePhotoImages.install(tester);
      await show(tester, controller());
      expect(find.text('Photos are shown after admin review.'), findsOneWidget);
    });

    testWidgets(
      'the count is waiting and approved photos; a rejected one is not in it',
      (tester) async {
        final c = await mixed(tester);
        expect(find.text('Photos (2/20)'), findsOneWidget);
        expect(
          c.items,
          hasLength(3),
          reason: 'the rejected photo is still listed',
        );
      },
    );

    testWidgets(
      'twenty waiting and approved photos fill it, whatever is rejected',
      (tester) async {
        await FakePhotoImages.install(tester);
        for (var i = 0; i < 12; i++) {
          backend.seed('v1', sortOrder: i, status: PhotoStatus.pending);
        }
        for (var i = 12; i < 20; i++) {
          backend.seed('v1', sortOrder: i);
        }
        for (var i = 20; i < 23; i++) {
          backend.seed(
            'v1',
            sortOrder: i,
            status: PhotoStatus.rejected,
            rejectionReason: 'x',
          );
        }
        final c = controller(vendorId: 'v1');
        await c.load();
        await show(tester, c);
        expect(find.text('Photos (20/20)'), findsOneWidget);
        expect(
          find.text(
            'You have reached the limit of 20 photos. Delete one to add another.',
          ),
          findsOneWidget,
        );
        nextPick = [_pick('21st.jpg')];
        await tester.tap(find.text('Add photos'));
        await settle(tester);
        expect(pickerLimits, isEmpty);
      },
    );

    testWidgets(
      'a rejected photo leaves a place free: Add still works at 19 + 1 rejected',
      (tester) async {
        await FakePhotoImages.install(tester);
        for (var i = 0; i < 19; i++) {
          backend.seed('v1', sortOrder: i);
        }
        backend.seed(
          'v1',
          sortOrder: 19,
          status: PhotoStatus.rejected,
          rejectionReason: 'x',
        );
        final c = controller(vendorId: 'v1');
        await c.load();
        await show(tester, c);
        expect(find.text('Photos (19/20)'), findsOneWidget);
        nextPick = [_pick('new.jpg')];
        await tester.tap(find.text('Add photos'));
        await settle(tester);
        expect(pickerLimits, [1]);
        // The new photo waits for an admin, and shows so.
        expect(find.text('Photos (20/20)'), findsOneWidget);
        expect(find.text('Under review'), findsOneWidget);
      },
    );

    testWidgets('the owner can delete a waiting or a rejected photo', (
      tester,
    ) async {
      await mixed(tester);
      // delete the rejected one (the third tile), then the waiting one
      await tester.tap(find.byTooltip('Delete photo').at(2));
      await tester.pump();
      await tester.tap(find.text('Delete photo'));
      await settle(tester);
      expect(
        find.text('Not approved: Not a photo of this business'),
        findsNothing,
      );
      expect(backend.rowsOf('v1').map((p) => p.status), [
        PhotoStatus.approved,
        PhotoStatus.pending,
      ]);

      await tester.tap(find.byTooltip('Delete photo').at(1));
      await tester.pump();
      await tester.tap(find.text('Delete photo'));
      await settle(tester);
      expect(find.text('Under review'), findsNothing);
      expect(backend.rowsOf('v1').map((p) => p.status), [PhotoStatus.approved]);
      expect(find.text('Photos (1/20)'), findsOneWidget);
    });

    testWidgets('moving a photo keeps its status', (tester) async {
      await mixed(tester);
      await tester.tap(find.byTooltip('Move earlier').at(1));
      await settle(tester);
      expect(backend.rowsOf('v1').map((p) => p.status), [
        PhotoStatus.pending,
        PhotoStatus.approved,
        PhotoStatus.rejected,
      ]);
      expect(find.text('Under review'), findsOneWidget);
    });

    for (final width in [320.0, 375.0, 390.0, 768.0, 1024.0, 1440.0]) {
      for (final dark in [false, true]) {
        testWidgets(
          '${width.toInt()}px, ${dark ? 'dark' : 'light'}: every button has a 44 px touch area, '
          'nothing overlaps or overflows',
          (tester) async {
            await mixed(
              tester,
              width: width,
              theme: dark ? AppTheme.dark : AppTheme.light,
              reason: longReason,
            );
            expect(tester.takeException(), isNull);

            final tiles = tester.getRect(find.byType(BusinessPhotosSection));
            for (var i = 0; i < 3; i++) {
              final rects = [
                tester.getRect(find.byTooltip('Delete photo').at(i)),
                tester.getRect(find.byTooltip('Move earlier').at(i)),
                tester.getRect(find.byTooltip('Move later').at(i)),
              ];
              for (final r in rects) {
                expect(
                  r.width,
                  greaterThanOrEqualTo(44),
                  reason: 'tile $i width',
                );
                expect(
                  r.height,
                  greaterThanOrEqualTo(44),
                  reason: 'tile $i height',
                );
                expect(r.right, lessThanOrEqualTo(tiles.right + 0.5));
                expect(r.left, greaterThanOrEqualTo(tiles.left - 0.5));
              }
              for (var a = 0; a < 3; a++) {
                for (var b = a + 1; b < 3; b++) {
                  expect(
                    rects[a].overlaps(rects[b]),
                    isFalse,
                    reason: 'buttons $a and $b of tile $i overlap',
                  );
                }
              }
            }
            // The Add tile and the status notes are easy targets too, and stay in their tile.
            expect(
              tester.getSize(find.text('Add photos')).width,
              greaterThan(0),
            );
            final note = tester.getRect(find.byKey(const ValueKey('status-2')));
            expect(note.height, greaterThanOrEqualTo(44));
            expect(note.right, lessThanOrEqualTo(tiles.right + 0.5));
            final photo = tester.getRect(find.byTooltip('Delete photo').at(2));
            expect(
              note.top,
              greaterThanOrEqualTo(photo.bottom - 1),
              reason: 'the note is under its photo',
            );
          },
        );
      }
    }

    for (final code in ['hi', 'ur']) {
      testWidgets('$code, a small phone with large text: fits', (tester) async {
        await mixed(
          tester,
          width: 320,
          locale: Locale(code),
          textScale: 1.6,
          reason: longReason,
        );
        expect(tester.takeException(), isNull);
        final l = AppLocalizations.of(
          tester.element(find.byType(BusinessPhotosSection)),
        );
        expect(find.text(l.photoUnderReview), findsOneWidget);
        expect(find.text(l.photosShownAfterReview), findsOneWidget);
        expect(find.text(l.photoNotApprovedReason(longReason)), findsOneWidget);
      });
    }
  });

  group('languages and sizes', () {
    for (final locale in ['en', 'hi', 'ur']) {
      for (final width in [320.0, 600.0]) {
        testWidgets(
          '$locale at $width px wide, big text, 20 photos: no overflow',
          (tester) async {
            await FakePhotoImages.install(tester);
            for (var i = 0; i < 20; i++) {
              backend.seed('v1', sortOrder: i, file: 'p$i.webp');
            }
            final c = controller(vendorId: 'v1');
            await c.load();
            await show(
              tester,
              c,
              locale: Locale(locale),
              width: width,
              textScale: 1.6,
            );
            expect(tester.takeException(), isNull);
            // Tooltips are in the app language too.
            expect(
              find.byTooltip('Delete photo'),
              locale == 'en' ? findsNWidgets(20) : findsNothing,
            );
            // The strings really are translated.
            final l = AppLocalizations.of(
              tester.element(find.byType(BusinessPhotosSection)),
            );
            expect(l.photosCount(20, 20), isNotEmpty);
            expect(find.text(l.photosCount(20, 20)), findsOneWidget);
            expect(find.text(l.photosLimitReached(20)), findsOneWidget);
          },
        );
      }
    }
  });
}
