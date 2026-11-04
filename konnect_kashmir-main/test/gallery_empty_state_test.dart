import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/l10n/l10n.dart';
import 'package:konnect_kashmir/screens/business_details/business_photo_gallery.dart';
import 'package:konnect_kashmir/screens/business_details/gallery_empty_state.dart';
import 'package:konnect_kashmir/theme/app_theme.dart';

Future<GlobalKey> _show(
  WidgetTester tester, {
  ThemeData? theme,
  Locale locale = const Locale('en'),
  Size size = const Size(390, 844),
  double textScale = 1,
  double overlayTop = 80,
  bool loading = false,
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: MaterialApp(
        theme: theme ?? AppTheme.dark,
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
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              BusinessPhotoGallery(
                photos: const [],
                loading: loading,
                tint: const Color(0xFF339985),
                height: 360,
                overlayTop: overlayTop,
              ),
              const SizedBox(height: 600),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return key;
}

/// How much the pixels in [rect] differ from each other (0 for a flat colour).
Future<double> _variation(WidgetTester tester, GlobalKey key, Rect rect) async {
  final object =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return (await tester.runAsync(() async {
    final image = await object.toImage(pixelRatio: 1);
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final bytes = data.buffer.asUint8List();
    var lo = 255, hi = 0;
    for (var y = rect.top.toInt(); y < rect.bottom.toInt(); y += 2) {
      for (var x = rect.left.toInt(); x < rect.right.toInt(); x += 2) {
        final g = bytes[(y * image.width + x) * 4 + 1];
        if (g < lo) lo = g;
        if (g > hi) hi = g;
      }
    }
    image.dispose();
    return (hi - lo).toDouble();
  }))!;
}

void main() {
  group('a business with no photos', () {
    testWidgets('says so, in a short line and a supporting line', (
      tester,
    ) async {
      await _show(tester);
      expect(find.byType(GalleryEmptyState), findsOneWidget);
      expect(find.text('No photos available'), findsOneWidget);
      expect(find.text('Business photos will appear here'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final (code, title, subtitle) in [
      ('hi', 'कोई फ़ोटो उपलब्ध नहीं', 'व्यवसाय की फ़ोटो यहाँ दिखाई देंगी'),
      ('ur', 'کوئی تصویر دستیاب نہیں', 'کاروبار کی تصاویر یہاں دکھائی دیں گی'),
    ]) {
      testWidgets('$code: the same two lines in the language', (tester) async {
        await _show(tester, locale: Locale(code));
        expect(find.text(title), findsOneWidget);
        expect(find.text(subtitle), findsOneWidget);
        expect(find.text('No photos available'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('is only a picture: nothing to tap, no upload', (tester) async {
      await _show(tester);
      final inside = find.descendant(
        of: find.byType(GalleryEmptyState),
        matching: find.byWidgetPredicate(
          (w) =>
              w is ButtonStyleButton ||
              w is IconButton ||
              w is InkWell ||
              w is GestureDetector ||
              w is TextField,
        ),
      );
      expect(inside, findsNothing);
      for (final word in ['upload', 'Upload', 'Add photo', 'add photo']) {
        expect(find.textContaining(word), findsNothing, reason: word);
      }
    });

    testWidgets('keeps the size of the photo area', (tester) async {
      await _show(tester);
      expect(
        tester.getSize(find.byType(BusinessPhotoGallery)),
        const Size(390, 360),
      );
      expect(
        tester.getSize(find.byType(GalleryEmptyState)),
        const Size(390, 360),
      );
    });

    testWidgets(
      'is centred in the part of the area that the bars do not cover',
      (tester) async {
        await _show(tester, overlayTop: 80);
        final area = tester.getRect(find.byType(GalleryEmptyState));
        final title = tester.getRect(find.text('No photos available'));
        final subtitle = tester.getRect(
          find.text('Business photos will appear here'),
        );
        expect(title.center.dx, closeTo(area.center.dx, 1));
        expect(subtitle.center.dx, closeTo(area.center.dx, 1));
        // The picture starts below the status bar and the app bar.
        final pictures = find.descendant(
          of: find.byType(GalleryEmptyState),
          matching: find.byType(CustomPaint),
        );
        expect(
          tester.getTopLeft(pictures.first).dy,
          greaterThanOrEqualTo(area.top + 80 - 1),
        );
        // And the whole of it stays inside the area.
        expect(subtitle.bottom, lessThanOrEqualTo(area.bottom));
        // Roughly in the middle of what is left.
        final middle = (area.top + 80 + area.bottom) / 2;
        final content =
            (tester.getTopLeft(pictures.first).dy + subtitle.bottom) / 2;
        expect(content, closeTo(middle, 24));
      },
    );

    for (final (name, theme) in [
      ('dark', AppTheme.dark),
      ('light', AppTheme.light),
    ]) {
      testWidgets('$name theme: a storefront is drawn, not a flat colour', (
        tester,
      ) async {
        final key = await _show(tester, theme: theme);
        final area = tester.getRect(find.byType(GalleryEmptyState));
        // Where the shop is (above the text, below the app bar).
        final shop = Rect.fromLTWH(
          area.center.dx - 70,
          area.top + 110,
          140,
          70,
        );
        expect(await _variation(tester, key, shop), greaterThan(40));
        // A strip of backdrop at the far left is smooth.
        final plain = Rect.fromLTWH(0, area.top + 120, 24, 60);
        expect(await _variation(tester, key, plain), lessThan(25));
        expect(tester.takeException(), isNull);
      });
    }

    for (final (name, w, h, scale) in [
      ('a small phone', 320.0, 568.0, 1.0),
      ('large text', 360.0, 800.0, 2.0),
      ('a tablet', 820.0, 1180.0, 1.0),
    ]) {
      for (final code in ['en', 'hi', 'ur']) {
        testWidgets('$name, $code: nothing overflows', (tester) async {
          await _show(
            tester,
            size: Size(w, h),
            textScale: scale,
            locale: Locale(code),
            theme: code == 'ur' ? AppTheme.light : AppTheme.dark,
          );
          expect(find.byType(GalleryEmptyState), findsOneWidget);
          expect(tester.takeException(), isNull);
          final area = tester.getRect(find.byType(GalleryEmptyState));
          for (final t in tester.widgetList<Text>(
            find.descendant(
              of: find.byType(GalleryEmptyState),
              matching: find.byType(Text),
            ),
          )) {
            final r = tester.getRect(find.byWidget(t));
            expect(r.left, greaterThanOrEqualTo(area.left));
            expect(r.right, lessThanOrEqualTo(area.right));
            expect(r.bottom, lessThanOrEqualTo(area.bottom));
          }
        });
      }
    }

    testWidgets('is read out as one message', (tester) async {
      final handle = tester.ensureSemantics();
      await _show(tester);
      expect(
        find.bySemanticsLabel(
          'No photos available. Business photos will appear here',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('while the photos are still coming: the same backdrop with a '
        'spinner, and the message only once we know there are none', (
      tester,
    ) async {
      await _show(tester, loading: true);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('No photos available'), findsNothing);
      expect(
        find.byType(CustomPaint),
        findsWidgets,
      ); // the backdrop is already there
    });
  });
}
