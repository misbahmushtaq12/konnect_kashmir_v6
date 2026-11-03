import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/l10n/l10n.dart';
import 'package:konnect_kashmir/screens/business_details/business_photo_gallery.dart';
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
}) async {
  tester.view.physicalSize = size * 2;
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
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Finder get _gallery => find.byType(BusinessPhotoGallery);
Finder get _dots =>
    find.descendant(of: _gallery, matching: find.byType(AnimatedContainer));
Finder _inViewer(Finder f) =>
    find.descendant(of: find.byType(BusinessPhotoViewer), matching: f);

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

    testWidgets('only the photo on show is fetched', (tester) async {
      final fake = await FakePhotoImages.install(tester);
      await _show(tester, _photos(5));
      expect(fake.requested.toSet(), {'v1/public/p0.webp'});
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
      expect(find.byIcon(Icons.storefront_rounded), findsNothing);
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
      expect(find.byIcon(Icons.storefront_rounded), findsOneWidget);
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
      'while the photos are still being asked for: a spinner, not the placeholder',
      (tester) async {
        await FakePhotoImages.install(tester);
        await _show(tester, const [], loading: true);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byIcon(Icons.storefront_rounded), findsNothing);
      },
    );

    testWidgets('the placeholder works in the dark theme too', (tester) async {
      await _show(tester, const [], theme: AppTheme.dark);
      expect(find.byIcon(Icons.storefront_rounded), findsOneWidget);
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
      expect(find.byIcon(Icons.storefront_rounded), findsNothing);
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
