import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/l10n/l10n.dart';
import 'package:konnect_kashmir/screens/business_details/business_photo_gallery.dart';
import 'package:konnect_kashmir/screens/business_details/gallery_empty_state.dart';
import 'package:konnect_kashmir/services/business_photos/photo_images.dart';
import 'package:konnect_kashmir/theme/app_theme.dart';

import 'support/fake_photo_images.dart';

List<GalleryPhoto> _photos(int n) => [
  for (var i = 0; i < n; i++)
    GalleryPhoto(
      cacheKey: 'v1/public/p$i.webp',
      url: 'https://signed.example/v1/public/p$i.webp?token=t$i',
    ),
];

Future<void> _show(
  WidgetTester tester,
  List<GalleryPhoto> photos, {
  bool loading = false,
  Locale locale = const Locale('en'),
  Size size = const Size(390, 844),
  ThemeData? theme,
  GlobalKey? boundary,
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final app = MaterialApp(
    theme: theme ?? AppTheme.light,
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          BusinessPhotoGallery(
            photos: photos,
            loading: loading,
            tint: const Color(0xFF339985),
            height: 360,
          ),
          const SizedBox(height: 800),
        ],
      ),
    ),
  );
  await tester.pumpWidget(
    boundary == null ? app : RepaintBoundary(key: boundary, child: app),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Finder get _gallery => find.byType(BusinessPhotoGallery);
Finder get _dots =>
    find.descendant(of: _gallery, matching: find.byType(AnimatedContainer));
Finder _inViewer(Finder f) =>
    find.descendant(of: find.byType(BusinessPhotoViewer), matching: f);

/// The colour of one pixel of what is on screen (in logical pixels).
Future<ui.Color> _pixel(
  WidgetTester tester,
  GlobalKey boundary,
  double x,
  double y,
) async {
  final object =
      boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return (await tester.runAsync(() async {
    final image = await object.toImage(pixelRatio: 1);
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final i = (y.round() * image.width + x.round()) * 4;
    final color = ui.Color.fromARGB(
      255,
      data.getUint8(i),
      data.getUint8(i + 1),
      data.getUint8(i + 2),
    );
    image.dispose();
    return color;
  }))!;
}

int _red(ui.Color c) => (c.r * 255).round();
int _green(ui.Color c) => (c.g * 255).round();

/// How far the carousel is scrolled, in pixels.
double _scrolled(WidgetTester tester) =>
    tester.widget<PageView>(find.byType(PageView)).controller!.offset;

/// The scale of the zoomable photo that is shown in the viewer.
double _zoom(WidgetTester tester) {
  final viewer = tester.widget<InteractiveViewer>(
    find.byType(InteractiveViewer),
  );
  return viewer.transformationController!.value.getMaxScaleOnAxis();
}

void main() {
  group('many photos', () {
    testWidgets('edge to edge, with dots and a count; swiping changes both', (
      tester,
    ) async {
      await FakePhotoImages.install(tester);
      await _show(tester, _photos(5));

      expect(tester.getSize(_gallery).width, 390, reason: 'edge to edge');
      expect(find.text('1/5'), findsOneWidget);
      expect(_dots, findsNWidgets(5));
      // The first dot is the long one (18 px, and 3 px of space on each side).
      expect(tester.getSize(_dots.at(0)).width, 24);
      expect(tester.getSize(_dots.at(1)).width, 12);

      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.text('2/5'), findsOneWidget);
      expect(tester.getSize(_dots.at(0)).width, 12);
      expect(tester.getSize(_dots.at(1)).width, 24);

      // The count is in the bottom right corner, the dots in the middle.
      final box = tester.getRect(_gallery);
      final count = tester.getRect(find.text('2/5'));
      expect(count.right, greaterThan(box.right - 40));
      expect(count.bottom, greaterThan(box.bottom - 30));
      expect(
        (tester.getRect(_dots.first).left + tester.getRect(_dots.last).right) /
            2,
        closeTo(box.center.dx, 1),
        reason: 'the row of dots is in the middle',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('twenty photos fit: twenty dots, the count 20/20 at the end', (
      tester,
    ) async {
      await FakePhotoImages.install(tester);
      await _show(tester, _photos(20), size: const Size(320, 700));
      expect(_dots, findsNWidgets(20));
      expect(find.text('1/20'), findsOneWidget);
      for (var i = 0; i < 19; i++) {
        await tester.drag(find.byType(PageView), const Offset(-300, 0));
        await tester.pumpAndSettle();
      }
      expect(find.text('20/20'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('each photo is shown whole over a blurred copy of itself', (
      tester,
    ) async {
      await FakePhotoImages.install(tester);
      await _show(tester, _photos(3));
      final images = tester.widgetList<Image>(
        find.descendant(of: _gallery, matching: find.byType(Image)),
      );
      expect(
        images.map((i) => i.fit),
        containsAll([BoxFit.contain, BoxFit.cover]),
        reason:
            'the photo itself is contained (never cropped); the backdrop covers',
      );
      final blur = tester.widgetList<ImageFiltered>(find.byType(ImageFiltered));
      expect(blur, isNotEmpty);
    });

    testWidgets('only the photo on show and its neighbours are fetched', (
      tester,
    ) async {
      final fake = await FakePhotoImages.install(tester);
      await _show(tester, _photos(5));
      expect(fake.requested.toSet(), {
        'v1/public/p0.webp',
        'v1/public/p1.webp',
      });

      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(fake.requested.toSet(), {
        'v1/public/p0.webp',
        'v1/public/p1.webp',
        'v1/public/p2.webp',
      });
    });

    testWidgets('a photo that cannot load shows a quiet tile; the rest go on', (
      tester,
    ) async {
      await FakePhotoImages.install(tester, broken: {'v1/public/p1.webp'});
      await _show(tester, _photos(3));
      expect(find.byIcon(Icons.image_not_supported_outlined), findsNothing);

      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('2/3'), findsOneWidget);
      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);

      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.text('3/3'), findsOneWidget);
      expect(find.byIcon(Icons.image_not_supported_outlined), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('every photo broken: still no exception, still swipes', (
      tester,
    ) async {
      await FakePhotoImages.install(
        tester,
        broken: {for (final p in _photos(3)) p.cacheKey},
      );
      await _show(tester, _photos(3));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
      expect(find.byType(Image), findsWidgets);
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.text('2/3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('one photo', () {
    testWidgets('no dots and no count', (tester) async {
      await FakePhotoImages.install(tester);
      await _show(tester, _photos(1));
      expect(_dots, findsNothing);
      expect(find.text('1/1'), findsNothing);
      expect(find.byType(PageView), findsOneWidget);
      expect(find.byType(GalleryEmptyState), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('it can still be opened full screen', (tester) async {
      await FakePhotoImages.install(tester);
      await _show(tester, _photos(1));
      await tester.tap(find.byType(PageView));
      await tester.pumpAndSettle();
      expect(find.byType(BusinessPhotoViewer), findsOneWidget);
      expect(_inViewer(find.text('1/1')), findsOneWidget);
    });
  });

  group('no photo', () {
    testWidgets('a clean placeholder with an icon, nothing to break', (
      tester,
    ) async {
      final fake = await FakePhotoImages.install(tester);
      await _show(tester, const []);
      expect(find.byType(GalleryEmptyState), findsOneWidget);
      expect(find.byType(PageView), findsNothing);
      // (The faint leaf behind every screen is an Image too; look in the gallery.)
      expect(
        find.descendant(of: _gallery, matching: find.byType(Image)),
        findsNothing,
      );
      expect(_dots, findsNothing);
      expect(fake.requested, isEmpty);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'while the photos are still being asked for: a spinner, not the "no photos" message',
      (tester) async {
        await FakePhotoImages.install(tester);
        await _show(tester, const [], loading: true);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('No photos available'), findsNothing);
        expect(find.text('Business photos will appear here'), findsNothing);
      },
    );

    testWidgets('the placeholder works in the dark theme too', (tester) async {
      await _show(tester, const [], theme: AppTheme.dark);
      expect(find.byType(GalleryEmptyState), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('photos arriving later replace the placeholder', (
      tester,
    ) async {
      await FakePhotoImages.install(tester);
      await _show(tester, const [], loading: true);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: Scaffold(
            body: BusinessPhotoGallery(
              photos: _photos(2),
              tint: const Color(0xFF339985),
              height: 360,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('1/2'), findsOneWidget);
      expect(find.byType(GalleryEmptyState), findsNothing);
    });
  });

  group('a photo removed while it is on show', () {
    testWidgets('the gallery moves to a photo that still exists', (
      tester,
    ) async {
      await FakePhotoImages.install(tester);
      Widget app(List<GalleryPhoto> p) => MaterialApp(
        theme: AppTheme.light,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: Scaffold(
          body: BusinessPhotoGallery(
            photos: p,
            tint: const Color(0xFF339985),
            height: 360,
          ),
        ),
      );
      await tester.pumpWidget(app(_photos(3)));
      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('3/3'), findsOneWidget);

      await tester.pumpWidget(app(_photos(2)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('2/2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('full screen', () {
    Future<void> open(WidgetTester tester, {int n = 5}) async {
      await FakePhotoImages.install(tester);
      await _show(tester, _photos(n));
      await tester.tap(find.byType(PageView));
      await tester.pumpAndSettle();
    }

    testWidgets('a tap opens it, with the count; Close goes back', (
      tester,
    ) async {
      await open(tester);
      expect(find.byType(BusinessPhotoViewer), findsOneWidget);
      expect(_inViewer(find.text('1/5')), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(BusinessPhotoViewer), findsNothing);
    });

    testWidgets('the close button and the count are at the top of the screen', (
      tester,
    ) async {
      await open(tester);
      expect(
        tester.getTopLeft(find.byIcon(Icons.close_rounded)).dy,
        lessThan(80),
      );
      expect(tester.getTopLeft(_inViewer(find.text('1/5'))).dy, lessThan(80));
      expect(
        tester.getTopRight(_inViewer(find.text('1/5'))).dx,
        greaterThan(300),
        reason: 'the count is on the right',
      );
    });

    testWidgets('it opens on the photo that was tapped', (tester) async {
      await FakePhotoImages.install(tester);
      await _show(tester, _photos(5));
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PageView));
      await tester.pumpAndSettle();
      expect(_inViewer(find.text('2/5')), findsOneWidget);
    });

    testWidgets(
      'swiping moves between the photos, and the gallery behind follows',
      (tester) async {
        await open(tester);
        await tester.drag(
          find.byType(BusinessPhotoViewer),
          const Offset(-300, 0),
        );
        await tester.pumpAndSettle();
        await tester.drag(
          find.byType(BusinessPhotoViewer),
          const Offset(-300, 0),
        );
        await tester.pumpAndSettle();
        expect(_inViewer(find.text('3/5')), findsOneWidget);

        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();
        expect(
          find.text('3/5'),
          findsOneWidget,
          reason: 'the gallery is on photo 3',
        );
      },
    );

    testWidgets('double tap zooms in, double tap again zooms out', (
      tester,
    ) async {
      await open(tester);
      expect(_zoom(tester), 1);
      final at = tester.getCenter(find.byType(InteractiveViewer));

      await tester.tapAt(at);
      await tester.pump(kDoubleTapMinTime);
      await tester.tapAt(at);
      await tester.pumpAndSettle();
      expect(_zoom(tester), closeTo(2.5, 0.01));

      await tester.tapAt(at);
      await tester.pump(kDoubleTapMinTime);
      await tester.tapAt(at);
      await tester.pumpAndSettle();
      expect(_zoom(tester), closeTo(1, 0.01));
    });

    testWidgets('the spot that was tapped stays under the finger', (
      tester,
    ) async {
      await open(tester);
      final box = tester.getRect(find.byType(InteractiveViewer));
      final at = box.center + const Offset(80, 60);
      await tester.tapAt(at);
      await tester.pump(kDoubleTapMinTime);
      await tester.tapAt(at);
      await tester.pumpAndSettle();
      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      final local = at - box.topLeft;
      final shown = MatrixUtils.transformPoint(
        viewer.transformationController!.value,
        local,
      );
      expect(shown.dx, closeTo(local.dx, 0.5));
      expect(shown.dy, closeTo(local.dy, 0.5));
    });

    testWidgets('pinching zooms in', (tester) async {
      await open(tester);
      final c = tester.getCenter(find.byType(InteractiveViewer));
      final a = await tester.startGesture(c - const Offset(20, 0));
      final b = await tester.startGesture(c + const Offset(20, 0));
      await tester.pump();
      await a.moveTo(c - const Offset(90, 0));
      await b.moveTo(c + const Offset(90, 0));
      await tester.pump();
      await a.up();
      await b.up();
      await tester.pumpAndSettle();
      expect(_zoom(tester), greaterThan(1.5));
      expect(_zoom(tester), lessThanOrEqualTo(5));
    });

    testWidgets('it cannot be zoomed out past normal size, nor in past 5x', (
      tester,
    ) async {
      await open(tester);
      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      expect(viewer.minScale, 1);
      expect(viewer.maxScale, 5);
    });

    testWidgets('while zoomed the photo is moved, not swiped away', (
      tester,
    ) async {
      await open(tester);
      PageScrollPhysics? paging() {
        final p = tester.widget<PageView>(find.byType(PageView)).physics;
        return p is PageScrollPhysics ? p : null;
      }

      expect(
        paging(),
        isNotNull,
        reason: 'at normal size the page can be swiped',
      );
      final at = tester.getCenter(find.byType(InteractiveViewer));
      await tester.tapAt(at);
      await tester.pump(kDoubleTapMinTime);
      await tester.tapAt(at);
      await tester.pumpAndSettle();
      expect(
        tester.widget<PageView>(find.byType(PageView)).physics,
        isA<NeverScrollableScrollPhysics>(),
      );
      await tester.drag(
        find.byType(BusinessPhotoViewer),
        const Offset(-300, 0),
      );
      await tester.pumpAndSettle();
      expect(_inViewer(find.text('1/5')), findsOneWidget);

      // Back to normal size: swiping works again.
      await tester.tapAt(at);
      await tester.pump(kDoubleTapMinTime);
      await tester.tapAt(at);
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(BusinessPhotoViewer),
        const Offset(-300, 0),
      );
      await tester.pumpAndSettle();
      expect(_inViewer(find.text('2/5')), findsOneWidget);
    });

    testWidgets('a photo that cannot load shows an icon, not a broken image', (
      tester,
    ) async {
      await FakePhotoImages.install(tester, broken: {'v1/public/p0.webp'});
      await _show(tester, _photos(2));
      await tester.tap(find.byType(PageView));
      await tester.pumpAndSettle();
      expect(
        _inViewer(find.byIcon(Icons.image_not_supported_outlined)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('swiping between photos', () {
    const k0 = 'v1/public/p0.webp';
    const k1 = 'v1/public/p1.webp';
    const k2 = 'v1/public/p2.webp';

    testWidgets('the next photo is fetched while this one is on show, so it is '
        'ready when the finger gets there', (tester) async {
      final fake = await FakePhotoImages.install(tester, slow: {k1, k2});
      await _show(tester, _photos(3));
      expect(
        fake.requested,
        contains(k1),
        reason: 'asked for before any swipe',
      );
      expect(
        fake.requested,
        isNot(contains(k2)),
        reason: 'two ahead is too far',
      );

      fake.release(k1); // it arrives while the first photo is still on show
      await tester.pump(const Duration(milliseconds: 100));

      final g = await tester.startGesture(const Offset(300, 200));
      await g.moveBy(const Offset(-60, 0));
      await tester.pump();
      await g.moveBy(const Offset(-120, 0));
      await tester.pump();
      expect(_scrolled(tester), greaterThan(100));
      expect(
        find.descendant(
          of: _gallery,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
        reason: 'the incoming photo is drawn at once, not after a wait',
      );
      await g.up();
      await tester.pumpAndSettle();
    });

    testWidgets('the photo behind is ready too when going back', (
      tester,
    ) async {
      final fake = await FakePhotoImages.install(tester);
      await _show(tester, _photos(4));
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.text('3/4'), findsOneWidget);
      // On photo 3: photos 2 and 4 are loaded; photo 1 was loaded on the way.
      expect(fake.requested.toSet(), {
        'v1/public/p0.webp',
        'v1/public/p1.webp',
        'v1/public/p2.webp',
        'v1/public/p3.webp',
      });
    });

    testWidgets('the photo that leaves does not paint over the one that comes '
        '(swiping back)', (tester) async {
      final red = await solidImage(tester, const ui.Color(0xFFC81E1E));
      final green = await solidImage(tester, const ui.Color(0xFF1EAA3C));
      await FakePhotoImages.install(tester, pictures: {k0: red, k1: green});
      final boundary = GlobalKey();
      await _show(tester, _photos(3), boundary: boundary);
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.text('2/3'), findsOneWidget);

      // Half way back to the red photo.
      final g = await tester.startGesture(const Offset(100, 200));
      await g.moveBy(const Offset(40, 0));
      await tester.pump();
      await g.moveBy(const Offset(140, 0));
      await tester.pump();
      final seam = 390 - _scrolled(tester); // where the green page begins
      expect(seam, inInclusiveRange(100, 290));

      // Just on the red side of the seam it is red. The green page's blur used to
      // spread over this strip.
      for (final dx in [4.0, 12.0, 30.0, 60.0]) {
        final c = await _pixel(tester, boundary, seam - dx, 100);
        expect(
          _red(c),
          greaterThan(_green(c) + 40),
          reason: '${dx}px before the seam',
        );
      }
      // And on the green side it is green.
      final c = await _pixel(tester, boundary, seam + 12, 100);
      expect(_green(c), greaterThan(_red(c) + 40));
      await g.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a photo that has not arrived yet is an opaque page of its '
        'own: the photo that leaves does not show through', (tester) async {
      final red = await solidImage(tester, const ui.Color(0xFFC81E1E));
      await FakePhotoImages.install(tester, pictures: {k0: red}, slow: {k1});
      final boundary = GlobalKey();
      await _show(tester, _photos(3), boundary: boundary);

      final g = await tester.startGesture(const Offset(300, 200));
      await g.moveBy(const Offset(-40, 0));
      await tester.pump();
      await g.moveBy(const Offset(-140, 0));
      await tester.pump();
      final seam = 390 - _scrolled(tester); // where the waiting page begins
      expect(seam, inInclusiveRange(100, 290));

      for (final dx in [4.0, 12.0, 40.0]) {
        final c = await _pixel(tester, boundary, seam + dx, 100);
        expect(
          _green(c),
          greaterThan(_red(c)),
          reason:
              'the waiting page is its own light page, not the red photo ${dx}px in',
        );
      }
      await g.up();
      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets('pages are not rebuilt while they move (only the dots and the '
        'count change)', (tester) async {
      final fake = await FakePhotoImages.install(tester);
      await _show(tester, _photos(3));
      final g = await tester.startGesture(const Offset(300, 200));
      await g.moveBy(const Offset(-40, 0));
      await tester.pump();
      await g.moveBy(const Offset(-80, 0));
      await tester.pump();
      final before = fake.providersMade.where((k) => k == k1).length;
      expect(before, greaterThan(0), reason: 'the second page is on screen');

      await g.moveBy(const Offset(-150, 0)); // past half way: the count changes
      await tester.pump();
      expect(find.text('2/3'), findsOneWidget);
      await g.up();
      await tester.pumpAndSettle();
      expect(
        fake.providersMade.where((k) => k == k1).length,
        before,
        reason: 'the second page was built once',
      );
    });

    testWidgets('going back and forth does not fetch a photo again', (
      tester,
    ) async {
      final fake = await FakePhotoImages.install(tester);
      await _show(tester, _photos(3));
      for (final dx in [-300.0, -300.0, 300.0, 300.0, -300.0]) {
        await tester.drag(find.byType(PageView), Offset(dx, 0));
        await tester.pumpAndSettle();
      }
      for (final k in [k0, k1, k2]) {
        // Two pictures per photo at most: the full one and the small blurred one.
        expect(
          fake.requested.where((r) => r == k).length,
          lessThanOrEqualTo(2),
          reason: k,
        );
      }
    });

    testWidgets('full screen uses the picture the carousel already has', (
      tester,
    ) async {
      final fake = await FakePhotoImages.install(tester);
      await _show(tester, _photos(3));
      await tester.pumpAndSettle();
      final before = fake.requested.where((r) => r == k0).length;
      await tester.tap(find.byType(PageView));
      await tester.pumpAndSettle();
      expect(find.byType(BusinessPhotoViewer), findsOneWidget);
      expect(
        fake.requested.where((r) => r == k0).length,
        before,
        reason: 'photo 1 was not loaded a second time',
      );
    });

    testWidgets('full screen also gets the next photo ready', (tester) async {
      final fake = await FakePhotoImages.install(tester, slow: {k1});
      await _show(tester, _photos(3));
      await tester.tap(find.byType(PageView));
      await tester.pumpAndSettle();
      expect(fake.requested, contains(k1));
    });

    testWidgets('swiping fast through every photo on a slow connection: the '
        'swipe is never blocked, and everything arrives afterwards', (
      tester,
    ) async {
      final keys = [for (var i = 0; i < 5; i++) 'v1/public/p$i.webp'];
      final fake = await FakePhotoImages.install(tester, slow: keys.toSet());
      await _show(tester, _photos(5));
      // Flings one after the other, without waiting for the photos or for the
      // carousel to come to rest: it keeps moving every time.
      var flings = 0;
      while (find.text('5/5').evaluate().isEmpty && flings < 12) {
        await tester.fling(find.byType(PageView), const Offset(-300, 0), 2500);
        await tester.pump(const Duration(milliseconds: 100));
        flings++;
      }
      expect(flings, lessThan(12), reason: 'the end was reached');
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('5/5'), findsOneWidget);
      expect(tester.takeException(), isNull);

      fake.releaseAll();
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: _gallery,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );
      // Swiping back shows the photos that arrived in the meantime.
      await tester.fling(find.byType(PageView), const Offset(300, 0), 2500);
      await tester.pumpAndSettle();
      expect(find.text('4/5'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a photo that fails to load is skipped over without a hitch', (
      tester,
    ) async {
      final fake = await FakePhotoImages.install(tester, broken: {k1});
      await _show(tester, _photos(3));
      expect(fake.requested, contains(k1));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        tester.takeException(),
        isNull,
        reason: 'the failed preload is not an error',
      );
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.text('3/3'), findsOneWidget);
      expect(find.byIcon(Icons.image_not_supported_outlined), findsNothing);
    });

    testWidgets('the dots and the count follow the photo that is on show', (
      tester,
    ) async {
      await FakePhotoImages.install(tester);
      await _show(tester, _photos(4));
      Future<void> expectOn(int n) async {
        expect(find.text('$n/4'), findsOneWidget);
        for (var i = 0; i < 4; i++) {
          expect(tester.getSize(_dots.at(i)).width, i == n - 1 ? 24 : 12);
        }
      }

      await expectOn(1);
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      await expectOn(2);
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      await expectOn(3);
      await tester.drag(find.byType(PageView), const Offset(300, 0));
      await tester.pumpAndSettle();
      await expectOn(2);
    });
  });

  group('languages', () {
    for (final locale in ['hi', 'ur']) {
      testWidgets('$locale: opens and swipes without trouble', (tester) async {
        await FakePhotoImages.install(tester);
        await _show(tester, _photos(3), locale: Locale(locale));
        expect(find.text('1/3'), findsOneWidget);
        await tester.tap(find.byType(PageView));
        await tester.pumpAndSettle();
        expect(find.byType(BusinessPhotoViewer), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
