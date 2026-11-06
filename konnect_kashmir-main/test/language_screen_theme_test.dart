import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/l10n/l10n.dart';
import 'package:konnect_kashmir/providers/auth_provider.dart';
import 'package:konnect_kashmir/providers/locale_provider.dart';
import 'package:konnect_kashmir/screens/language_screen.dart';
import 'package:konnect_kashmir/screens/splash_screen.dart';
import 'package:konnect_kashmir/theme/app_theme.dart';
import 'package:konnect_kashmir/widgets/app_background.dart';
import 'package:konnect_kashmir/widgets/force_ltr.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Roboto from the Flutter SDK, so text is as wide as on a phone.
Future<void> _loadRoboto() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = Directory('$root/bin/cache/artifacts/material_fonts');
  if (!dir.existsSync()) return;
  final loader = FontLoader('Roboto');
  for (final name in ['Roboto-Regular', 'Roboto-Medium', 'Roboto-Bold']) {
    final file = File('${dir.path}/$name.ttf');
    if (file.existsSync()) {
      loader.addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer)));
    }
  }
  await loader.load();
}

const _delegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// The themes of the real app (light and dark), as `main.dart` sets them up.
Widget _themed(
  Brightness brightness,
  Widget Function(BuildContext) home, {
  Locale? locale,
  double textScale = 1,
  bool forceLtr = true,
}) =>
    MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: _delegates,
      builder: (context, child) {
        var w = child!;
        // The app never mirrors its layout (main.dart), even in Urdu.
        if (forceLtr) w = ForceLtr(child: w);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: w,
        );
      },
      home: Builder(builder: home),
    );

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

/// The picker on its own, inside the themed app, with a real [LocaleProvider].
Future<LocaleProvider> _picker(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  String language = 'en',
  bool settings = false,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool forceLtr = true,
  VoidCallback? onContinue,
}) async {
  SharedPreferences.setMockInitialValues({'app_locale': language});
  final locale = await LocaleProvider.load();
  _size(tester, size);
  await tester.pumpWidget(
    ChangeNotifierProvider<LocaleProvider>.value(
      value: locale,
      child: Consumer<LocaleProvider>(
        builder: (_, l, __) => _themed(
          brightness,
          (_) => LanguageScreen(isSettings: settings, onContinue: onContinue),
          locale: l.locale,
          textScale: textScale,
          forceLtr: forceLtr,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return locale;
}

// ── colour maths (WCAG 2.x) ────────────────────────────────────────────────
double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// The page colour with the Chinar leaf at its strongest on top of it (dark: the
/// leaf lightens the page by up to 18%, light: darkens it by up to 8%). Anything
/// that passes against this passes wherever the leaf is.
Color _worstPage(Brightness b) => b == Brightness.dark
    ? Color.alphaBlend(Colors.white.withValues(alpha: 0.18), AppColors.darkBg)
    : Color.alphaBlend(Colors.black.withValues(alpha: 0.08), AppColors.lightBg);

/// What a Text really paints with (theme + its own style), on top of [bg].
Color _textOn(WidgetTester tester, Finder text, Color bg) {
  final rich = tester.widget<RichText>(
      find.descendant(of: text, matching: find.byType(RichText)).first);
  return Color.alphaBlend(rich.text.style!.color!, bg);
}

// ── finders ───────────────────────────────────────────────────────────────
/// The three language cards, in order: English, Hindi, Urdu.
Finder get _tiles => find.byType(AnimatedContainer);

BoxDecoration _deco(WidgetTester tester, int i) =>
    tester.widget<AnimatedContainer>(_tiles.at(i)).decoration! as BoxDecoration;

Material _cardMaterial(WidgetTester tester, int i) => tester.widget<Material>(
    find.ancestor(of: _tiles.at(i), matching: find.byType(Material)).first);

Finder _tileTexts(int i) =>
    find.descendant(of: _tiles.at(i), matching: find.byType(Text));

Icon _icon(WidgetTester tester, int i) =>
    tester.widget<Icon>(find.descendant(of: _tiles.at(i), matching: find.byType(Icon)));

Finder get _continue => find.byType(ElevatedButton);

Finder _pageText(String s) => find.text(s);

/// The card as painted: its tint over the theme surface over the page. With
/// [leaf] the page is the worst case under the Chinar leaf, else the plain colour.
Color _tileBg(WidgetTester tester, int i, Brightness b, {bool leaf = true}) {
  final page = leaf
      ? _worstPage(b)
      : (b == Brightness.dark ? AppColors.darkBg : AppColors.lightBg);
  final base = Color.alphaBlend(_cardMaterial(tester, i).color!, page);
  final tint = _deco(tester, i).color;
  return tint == null ? base : Color.alphaBlend(tint, base);
}

void main() {
  setUpAll(_loadRoboto);

  // ── the first-run route: the bug was a black page ────────────────────────
  group('first-run route has the app background (not the bare black window)', () {
    for (final b in Brightness.values) {
      testWidgets('${b.name}: splash -> picker sits on AppBackground and paints the theme colour',
          (tester) async {
        SharedPreferences.setMockInitialValues({});
        final locale = await LocaleProvider.load();
        expect(locale.hasChosen, isFalse);
        _size(tester, const Size(360, 800));
        final shot = GlobalKey();
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: AuthProvider()),
            ChangeNotifierProvider<LocaleProvider>.value(value: locale),
          ],
          child: RepaintBoundary(
            key: shot,
            child: _themed(b, (_) => const SplashScreen()),
          ),
        ));
        await tester.pump(const Duration(milliseconds: 2500));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Choose your language'), findsOneWidget);
        final want = b == Brightness.dark ? AppColors.darkBg : AppColors.lightBg;

        // What is on screen: the corner is the theme colour, opaque (a transparent
        // corner is the bare black window the picker used to sit on).
        final c = (await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(shot));
          final image = await boundary.toImage();
          final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
          const x = 3, y = 3;
          final i = (y * image.width + x) * 4;
          return Color.fromARGB(data.getUint8(i + 3), data.getUint8(i),
              data.getUint8(i + 1), data.getUint8(i + 2));
        }))!;
        expect(c.a, 1.0, reason: 'a transparent corner is the black window');
        const tol = 14 / 255; // the faint leaf may sit under the corner
        expect((c.r - want.r).abs(), lessThan(tol), reason: '$c vs $want');
        expect((c.g - want.g).abs(), lessThan(tol), reason: '$c vs $want');
        expect((c.b - want.b).abs(), lessThan(tol), reason: '$c vs $want');

        // Why: the splash opens the picker with a plain fade route (the theme's
        // page transition, which adds AppBackground, is not used), so the picker
        // is wrapped in AppBackground by the splash.
        final bg = find.ancestor(
            of: find.byType(LanguageScreen), matching: find.byType(AppBackground));
        expect(bg, findsOneWidget);
        expect(
          tester
              .widget<ColoredBox>(
                  find.descendant(of: bg, matching: find.byType(ColoredBox)).first)
              .color,
          want,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('opened from Profile it is on the route background too', (tester) async {
      SharedPreferences.setMockInitialValues({'app_locale': 'en'});
      final locale = await LocaleProvider.load();
      _size(tester, const Size(390, 844));
      await tester.pumpWidget(ChangeNotifierProvider<LocaleProvider>.value(
        value: locale,
        child: _themed(
          Brightness.dark,
          (c) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                  c,
                  MaterialPageRoute<void>(
                      builder: (_) => const LanguageScreen(isSettings: true))),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(
          find.ancestor(
              of: find.byType(LanguageScreen), matching: find.byType(AppBackground)),
          findsWidgets);
      expect(find.text('Choose your language'), findsOneWidget);
    });
  });

  // ── it is drawn with the theme, in both modes ─────────────────────────────
  for (final b in Brightness.values) {
    group('theme look (${b.name})', () {
      testWidgets('transparent Scaffold, theme card, border, radius and selection',
          (tester) async {
        await _picker(tester, brightness: b);
        final cs = Theme.of(tester.element(find.byType(LanguageScreen))).colorScheme;

        expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, isNull,
            reason: 'the page colour comes from AppBackground, not from this screen');
        expect(_tiles, findsNWidgets(3));

        for (var i = 0; i < 3; i++) {
          final m = _cardMaterial(tester, i);
          expect(m.color, cs.surface, reason: 'card $i is the app card surface');
          expect(m.borderRadius, BorderRadius.circular(AppRadius.lg));
          final d = _deco(tester, i);
          expect(d.borderRadius, BorderRadius.circular(AppRadius.lg));
        }

        // English is chosen: primary border + tint; the others are quiet.
        final sel = _deco(tester, 0);
        expect((sel.border! as Border).top.color, AppColors.primary);
        expect((sel.border! as Border).top.width, 1.5);
        expect(sel.color, AppColors.primary.withValues(alpha: 0.10));
        for (final i in [1, 2]) {
          final d = _deco(tester, i);
          expect((d.border! as Border).top.color, cs.onSurface.withValues(alpha: 0.08));
          expect((d.border! as Border).top.width, 1);
          expect(d.color, isNull);
        }

        // The indicator: check in the brand colour vs an empty ring.
        expect(_icon(tester, 0).icon, Icons.check_circle_rounded);
        expect(_icon(tester, 0).color, AppColors.primary);
        for (final i in [1, 2]) {
          expect(_icon(tester, i).icon, Icons.radio_button_unchecked_rounded);
          expect(_icon(tester, i).color, cs.onSurface.withValues(alpha: 0.55));
        }
      });

      testWidgets('title and names come from the theme text styles', (tester) async {
        await _picker(tester, brightness: b);
        final cs = Theme.of(tester.element(find.byType(LanguageScreen))).colorScheme;
        TextStyle style(Finder f) => tester
            .widget<RichText>(find.descendant(of: f, matching: find.byType(RichText)).first)
            .text
            .style!;

        final title = style(_pageText('Choose your language'));
        expect(title.fontSize, AppText.title);
        expect(title.fontWeight, FontWeight.w800);
        expect(title.color, cs.onSurface);
        expect(style(_pageText('You can change this anytime from Profile.')).fontSize,
            AppText.body);
        expect(style(_tileTexts(1).first).fontSize, AppText.heading);
        expect(style(_tileTexts(1).last).fontSize, AppText.secondary);
      });

      testWidgets('Continue is the app Primary button, full width', (tester) async {
        await _picker(tester, brightness: b);
        final btn = tester.widget<ElevatedButton>(_continue);
        final mat = tester.widget<Material>(
            find.descendant(of: _continue, matching: find.byType(Material)).first);
        expect(mat.color, AppColors.primary);
        expect(_textOn(tester, find.text('Continue'), AppColors.primary), Colors.white);
        expect(btn.style!.minimumSize!.resolve({}), const Size(double.infinity, 48));
        expect(btn.style!.shape!.resolve({}),
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)));
        final screen = tester.getRect(find.byType(LanguageScreen));
        final rect = tester.getRect(_continue);
        expect(rect.left, 24);
        expect(rect.right, screen.right - 24);
      });

      testWidgets('the chosen card differs from the others', (tester) async {
        await _picker(tester, brightness: b);
        for (final i in [1, 2]) {
          expect(_deco(tester, i).border, isNot(_deco(tester, 0).border));
          expect(_deco(tester, i).color, isNot(_deco(tester, 0).color));
          expect(_icon(tester, i).icon, isNot(_icon(tester, 0).icon));
          expect(_tileBg(tester, i, b), isNot(_tileBg(tester, 0, b)));
        }
      });
    });
  }

  // ── readable (WCAG AA) on the real colours ────────────────────────────────
  for (final b in Brightness.values) {
    for (final lang in ['en', 'hi', 'ur']) {
      testWidgets('contrast: ${b.name}, app language $lang', (tester) async {
        // From Profile the whole picker follows the app language.
        await _picker(tester, brightness: b, language: lang, settings: true);
        final l10n = lookupAppLocalizations(Locale(lang));
        final page = _worstPage(b);
        void aa(String what, Color fg, Color bg, [double min = 4.5]) =>
            expect(_contrast(fg, bg), greaterThanOrEqualTo(min), reason: what);

        aa('title', _textOn(tester, _pageText(l10n.chooseLanguage), page), page);
        aa('subtitle', _textOn(tester, _pageText(l10n.chooseLanguageHint), page), page);

        for (var i = 0; i < 3; i++) {
          final bg = _tileBg(tester, i, b);
          aa('name $i', _textOn(tester, _tileTexts(i).first, bg), bg);
          aa('english name $i', _textOn(tester, _tileTexts(i).last, bg), bg);
          // The empty ring / the check: graphics need 3:1. The check is the brand
          // colour (as on the Home tiles), measured on the card itself; the leaf
          // is a faint decoration and would only be under part of it.
          final icon = _icon(tester, i).color!;
          final iconBg = i == (lang == 'en' ? 0 : lang == 'hi' ? 1 : 2)
              ? _tileBg(tester, i, b, leaf: false)
              : bg;
          aa('indicator $i', Color.alphaBlend(icon, iconBg), iconBg, 3.0);
        }

        // Continue: white on the brand colour, the same on every Primary button
        // in the app (the theme's, not ours to change here). It is bold UI text.
        aa('Continue', _textOn(tester, find.text(l10n.continueLabel), AppColors.primary),
            AppColors.primary, 3.0);
        expect(tester.takeException(), isNull);
      });
    }
  }

  // ── behaviour is unchanged ─────────────────────────────────────────────────
  group('behaviour', () {
    testWidgets('tapping a card selects it; Continue saves and moves on, once',
        (tester) async {
      var moved = 0;
      final locale = await _picker(tester, onContinue: () => moved++);

      await tester.tap(find.text('हिन्दी'));
      await tester.pumpAndSettle();
      expect(locale.locale.languageCode, 'hi');
      expect(_icon(tester, 1).icon, Icons.check_circle_rounded);
      expect(_icon(tester, 0).icon, Icons.radio_button_unchecked_rounded);
      expect((_deco(tester, 1).border! as Border).top.color, AppColors.primary);
      // The first-run picker stays English while the app switches.
      expect(find.text('Choose your language'), findsOneWidget);

      await tester.tap(find.text('اردو'));
      await tester.pumpAndSettle();
      expect(locale.locale.languageCode, 'ur');
      expect(_icon(tester, 2).icon, Icons.check_circle_rounded);
      expect(_icon(tester, 1).icon, Icons.radio_button_unchecked_rounded);
      expect(moved, 0);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(moved, 1);
      expect(locale.hasChosen, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(LocaleProvider.prefLocale), 'ur');
      expect(prefs.getBool(LocaleProvider.prefChosen), isTrue);
    });

    testWidgets('from Profile: Continue saves and goes back', (tester) async {
      SharedPreferences.setMockInitialValues({'app_locale': 'en'});
      final locale = await LocaleProvider.load();
      _size(tester, const Size(390, 844));
      await tester.pumpWidget(ChangeNotifierProvider<LocaleProvider>.value(
        value: locale,
        child: Consumer<LocaleProvider>(
          builder: (_, l, __) => _themed(
            Brightness.light,
            locale: l.locale,
            (c) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                    c,
                    MaterialPageRoute<void>(
                        builder: (_) => const LanguageScreen(isSettings: true))),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      // From Profile it follows the app language and can be backed out of.
      expect(find.text('Choose your language'), findsOneWidget);
      await tester.tap(find.text('हिन्दी'));
      await tester.pumpAndSettle();
      expect(find.text(lookupAppLocalizations(const Locale('hi')).chooseLanguage),
          findsOneWidget);
      await tester.tap(find.text(lookupAppLocalizations(const Locale('hi')).continueLabel));
      await tester.pumpAndSettle();
      expect(find.byType(LanguageScreen), findsNothing);
      expect(find.text('open'), findsOneWidget);
      expect((await SharedPreferences.getInstance()).getBool(LocaleProvider.prefChosen),
          isTrue);
      expect(locale.locale.languageCode, 'hi');
    });

    testWidgets('a screen reader hears each language and which one is chosen',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _picker(tester);
      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp('English'))),
        isSemantics(isButton: true, isSelected: true, hasSelectedState: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp('Hindi'))),
        isSemantics(isButton: true, isSelected: false, hasSelectedState: true),
      );
      expect(find.bySemanticsLabel(RegExp('Urdu')), findsOneWidget);
      handle.dispose();
    });
  });

  // ── fits every phone, big text, every language, RTL ───────────────────────
  const sizes = <String, Size>{
    '320x568': Size(320, 568),
    '360x800': Size(360, 800),
    '411x914': Size(411, 914),
    'tablet 800x1280': Size(800, 1280),
    'landscape 1024x768': Size(1024, 768),
  };

  for (final e in sizes.entries) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('fits ${e.key} at text x$scale (en/hi/ur, light/dark, RTL or not)',
          (tester) async {
        for (final b in Brightness.values) {
          for (final lang in ['en', 'hi', 'ur']) {
            for (final ltr in [true, false]) {
              for (final settings in [false, true]) {
                if (!ltr && lang != 'ur') continue; // only Urdu is RTL
                await _picker(tester,
                    brightness: b,
                    language: lang,
                    settings: settings,
                    size: e.value,
                    textScale: scale,
                    forceLtr: ltr);
                final reason = '${e.key} x$scale ${b.name} $lang ltr:$ltr settings:$settings';
                expect(tester.takeException(), isNull, reason: reason);

                final view = tester.getRect(find.byType(LanguageScreen));
                // Continue is always on screen, inside the margins.
                final btn = tester.getRect(_continue);
                expect(btn.bottom, lessThanOrEqualTo(view.bottom), reason: reason);
                expect(btn.left, greaterThanOrEqualTo(view.left), reason: reason);
                expect(btn.right, lessThanOrEqualTo(view.right), reason: reason);

                // Every card can be reached and is as wide as the button.
                for (var i = 0; i < 3; i++) {
                  await tester.ensureVisible(_tiles.at(i));
                  await tester.pump();
                  final r = tester.getRect(_tiles.at(i));
                  expect(r.width, closeTo(btn.width, 0.5), reason: '$reason tile $i');
                  expect(r.left, greaterThanOrEqualTo(view.left), reason: reason);
                  expect(r.right, lessThanOrEqualTo(view.right), reason: reason);
                  expect(r.bottom, lessThanOrEqualTo(btn.top + 0.5),
                      reason: '$reason tile $i is not hidden under Continue');
                }
                expect(tester.takeException(), isNull, reason: reason);
              }
            }
          }
        }
        // A tablet gets a phone-sized column in the middle, not a stretched one.
        if (e.value.width > 600) {
          final btn = tester.getRect(_continue);
          expect(btn.width, lessThanOrEqualTo(480));
          expect(btn.center.dx, closeTo(e.value.width / 2, 1));
        }
      });
    }
  }

  testWidgets('Urdu in a real right-to-left layout: back arrow at the start, no overflow',
      (tester) async {
    await _picker(tester,
        language: 'ur', settings: true, forceLtr: false, size: const Size(360, 800));
    final ctx = tester.element(find.byType(LanguageScreen));
    expect(Directionality.of(ctx), TextDirection.rtl);
    expect(tester.getTopRight(find.byType(IconButton)).dx, greaterThan(300));
    expect(tester.takeException(), isNull);
  });
}
