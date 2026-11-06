import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/l10n/l10n.dart';
import 'package:konnect_kashmir/providers/auth_provider.dart';
import 'package:konnect_kashmir/providers/locale_provider.dart';
import 'package:konnect_kashmir/providers/theme_provider.dart';
import 'package:konnect_kashmir/screens/customer_screen.dart';
import 'package:konnect_kashmir/screens/deen/deen_tab.dart';
import 'package:konnect_kashmir/screens/deen/weather_service.dart';
import 'package:konnect_kashmir/screens/main_shell.dart';
import 'package:konnect_kashmir/screens/my_business_tab.dart';
import 'package:konnect_kashmir/screens/profile_tab.dart';
import 'package:konnect_kashmir/services/live_sync.dart';
import 'package:konnect_kashmir/theme/app_theme.dart';
import 'package:konnect_kashmir/widgets/floating_nav_bar.dart';
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
      loader.addFont(
        Future.value(ByteData.view(file.readAsBytesSync().buffer)),
      );
    }
  }
  await loader.load();
}

List<FloatingNavItem> _items(BuildContext c) => [
  FloatingNavItem(
    label: c.l10n.navHome,
    icon: const Icon(Icons.home_outlined),
    selectedIcon: const Icon(Icons.home_rounded),
  ),
  FloatingNavItem(
    label: c.l10n.navMyBusiness,
    icon: const Icon(Icons.storefront_outlined),
    selectedIcon: const Icon(Icons.storefront_rounded),
  ),
  FloatingNavItem(
    label: c.l10n.navDeen,
    icon: const Icon(Icons.mosque_outlined),
    selectedIcon: const Icon(Icons.mosque_rounded),
  ),
  FloatingNavItem(
    label: c.l10n.navProfile,
    icon: const Icon(Icons.person_outline_rounded),
    selectedIcon: const Icon(Icons.person_rounded),
  ),
];

/// The bar on its own, over a plain page.
Future<ValueNotifier<int>> _bar(
  WidgetTester tester, {
  ThemeData? theme,
  Locale locale = const Locale('en'),
  Size size = const Size(390, 844),
  double textScale = 1,
  double bottomInset = 0,
  double keyboard = 0,
  int selected = 0,
  Widget body = const SizedBox.expand(),
  void Function(int)? onTap,
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  tester.view.padding = FakeViewPadding(bottom: bottomInset * 2);
  tester.view.viewPadding = FakeViewPadding(bottom: bottomInset * 2);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard * 2);
  addTearDown(tester.view.reset);
  final index = ValueNotifier<int>(selected);
  await tester.pumpWidget(
    MaterialApp(
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
        // As in the app: the page runs behind the floating bar.
        extendBody: true,
        body: body,
        bottomNavigationBar: Builder(
          builder: (context) => ValueListenableBuilder<int>(
            valueListenable: index,
            builder: (_, i, __) => FloatingNavBar(
              items: _items(context),
              selectedIndex: i,
              onSelected: (n) {
                index.value = n;
                onTap?.call(n);
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
  return index;
}

Finder _slot(int i) => find.byKey(ValueKey<String>('nav-$i'));

/// The highlight behind an item (its animated box).
AnimatedContainer _highlight(WidgetTester tester, int i) =>
    tester.widget<AnimatedContainer>(
      find.descendant(of: _slot(i), matching: find.byType(AnimatedContainer)),
    );

/// The colour of the highlight right now (while it is changing, not its target).
Color _paintedColor(WidgetTester tester, int i) =>
    ((tester
                .widget<DecoratedBox>(
                  find.descendant(
                    of: find.descendant(
                      of: _slot(i),
                      matching: find.byType(AnimatedContainer),
                    ),
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .decoration)
            as BoxDecoration)
        .color!;

Color? _highlightColor(WidgetTester tester, int i) =>
    ((_highlight(tester, i).decoration as BoxDecoration).color);

void main() {
  setUpAll(_loadRoboto);

  group('the bar', () {
    testWidgets('has the four destinations, each named and with its icon', (
      tester,
    ) async {
      await _bar(tester);
      expect(find.byType(FloatingNavBar), findsOneWidget);
      for (final label in ['Home', 'My Business', 'Deen', 'Profile']) {
        expect(find.byTooltip(label), findsOneWidget, reason: label);
      }
      for (var i = 0; i < 4; i++) {
        expect(_slot(i), findsOneWidget);
      }
      // Home is selected: its icon is filled, the others are outlined.
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
      expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);
      expect(find.byIcon(Icons.mosque_outlined), findsOneWidget);
      expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('icons only: no text at all, whichever item is selected', (
      tester,
    ) async {
      for (final code in ['en', 'hi', 'ur']) {
        for (var i = 0; i < 4; i++) {
          await _bar(tester, selected: i, locale: Locale(code));
          expect(
            find.descendant(
              of: find.byType(FloatingNavBar),
              matching: find.byType(Text),
            ),
            findsNothing,
            reason: '$code, item $i selected',
          );
          // (An icon is drawn as a glyph, which is the only rich text there.)
          for (final w in tester.widgetList<RichText>(
            find.descendant(
              of: find.byType(FloatingNavBar),
              matching: find.byType(RichText),
            ),
          )) {
            expect(
              w.text.style?.fontFamily,
              'MaterialIcons',
              reason: '$code, item $i selected: only icon glyphs',
            );
          }
        }
      }
    });

    testWidgets('is a slim capsule, lower than the old 64px bar', (
      tester,
    ) async {
      await _bar(tester);
      final pill = tester.getRect(find.byKey(FloatingNavBar.pillKey));
      expect(pill.height, FloatingNavBar.barHeight);
      expect(pill.height, lessThanOrEqualTo(56));
      // The whole bar, air included, takes little height: the capsule and a
      // thin strip of air, no outer container.
      final bar = tester.getRect(find.byType(FloatingNavBar));
      expect(bar.height, lessThanOrEqualTo(56 + 4 + 8 + 0.5));
      expect(pill.top - bar.top, lessThanOrEqualTo(4.5));
      expect(bar.bottom - pill.bottom, lessThanOrEqualTo(8.5));
    });

    testWidgets('has no background of its own around the capsule', (
      tester,
    ) async {
      await _bar(tester);
      // Nothing is painted in the bar's space except the capsule: no outer
      // card, no fade strip. (Only the capsule's own boxes are decorated.)
      final boxes = find.descendant(
        of: find.byType(FloatingNavBar),
        matching: find.byType(DecoratedBox),
      );
      final capsule = tester.getRect(find.byKey(FloatingNavBar.pillKey));
      for (final box in boxes.evaluate()) {
        final r = tester.getRect(find.byWidget(box.widget));
        expect(
          capsule.inflate(0.5).contains(r.topLeft) &&
              capsule.inflate(0.5).contains(r.bottomRight),
          isTrue,
          reason: 'a box outside the capsule: $r',
        );
      }
      expect(
        find.descendant(
          of: find.byType(FloatingNavBar),
          matching: find.byType(IgnorePointer),
        ),
        findsNothing,
      );
    });

    testWidgets('the space beside and under the capsule is see-through to taps', (
      tester,
    ) async {
      var pageTaps = 0;
      final taps = <int>[];
      await _bar(
        tester,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => pageTaps++,
          child: const SizedBox.expand(),
        ),
        onTap: taps.add,
      );
      final capsule = tester.getRect(find.byKey(FloatingNavBar.pillKey));
      // Left of the capsule, level with it; and in the air under it.
      await tester.tapAt(Offset(4, capsule.center.dy));
      await tester.tapAt(Offset(capsule.center.dx, 844 - 2));
      expect(pageTaps, 2, reason: 'those taps belong to the page');
      expect(taps, isEmpty);
      // On the capsule, the bar takes it.
      await tester.tap(_slot(1));
      expect(taps, [1]);
      expect(pageTaps, 2);
    });

    testWidgets('steps aside while the keyboard is open', (tester) async {
      await _bar(tester, keyboard: 300);
      expect(find.byKey(FloatingNavBar.pillKey), findsNothing);
      expect(
        tester.getSize(find.byType(FloatingNavBar)).height,
        0,
        reason: 'and takes no room above the keyboard',
      );
      await _bar(tester);
      expect(find.byKey(FloatingNavBar.pillKey), findsOneWidget);
    });

    testWidgets('a page behind it is as tall as the screen and can scroll its '
        'last item clear of the capsule', (tester) async {
      await _bar(
        tester,
        bottomInset: 20,
        body: Builder(
          builder: (context) => ListView(
            key: const ValueKey('page'),
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              FloatingNavBar.bottomClearance(context),
            ),
            children: [
              for (var i = 0; i < 40; i++)
                SizedBox(
                  key: ValueKey('row$i'),
                  height: 90,
                  child: Text('row $i'),
                ),
            ],
          ),
        ),
      );
      final capsule = tester.getRect(find.byKey(FloatingNavBar.pillKey));
      // No blank strip is reserved: the list reaches the bottom of the screen.
      expect(
        tester.getRect(find.byKey(const ValueKey('page'))).bottom,
        844,
        reason: 'the list runs behind the bar',
      );

      // To the very end of the list (a plain jump: no overscroll stretch).
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      final last = tester.getRect(find.byKey(const ValueKey('row39')));
      expect(last.bottom, lessThanOrEqualTo(capsule.top), reason: 'not hidden');
      expect(
        capsule.top - last.bottom,
        lessThanOrEqualTo(4 + 12 + 0.5),
        reason: 'and only a small gap, no big reserved padding',
      );
    });

    testWidgets('bottomClearance is the bar height outside the shell too', (
      tester,
    ) async {
      late double inScaffold;
      await _bar(
        tester,
        bottomInset: 20,
        body: Builder(
          builder: (context) {
            inScaffold = FloatingNavBar.bottomClearance(context);
            return const SizedBox.expand();
          },
        ),
      );
      final bar = tester.getRect(find.byType(FloatingNavBar));
      expect(inScaffold, closeTo(bar.height + 12, 0.5));

      // On a plain page (no bar) it is only the system inset and the gap.
      late double plain;
      tester.view.padding = const FakeViewPadding(bottom: 40);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              plain = FloatingNavBar.bottomClearance(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(plain, 20 + 12);
    });

    testWidgets(
      'floats: a fine-outlined, shadowed capsule inset from the sides and '
      'above the bottom edge',
      (tester) async {
        await _bar(tester);
        final pill = tester.getRect(find.byKey(FloatingNavBar.pillKey));
        expect(pill.left, greaterThanOrEqualTo(16));
        expect(390 - pill.right, greaterThanOrEqualTo(16));
        expect(
          844 - pill.bottom,
          greaterThanOrEqualTo(8),
          reason: 'air below it',
        );
        expect(pill.center.dx, closeTo(195, 0.5), reason: 'centred');

        final shadow =
            tester
                    .widget<DecoratedBox>(find.byKey(FloatingNavBar.pillKey))
                    .decoration
                as BoxDecoration;
        expect(
          shadow.borderRadius,
          BorderRadius.circular(FloatingNavBar.barHeight / 2),
          reason: 'a full capsule',
        );
        expect(shadow.boxShadow, isNotEmpty, reason: 'it casts a soft shadow');

        // The outline is drawn over the glass.
        final outline = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byKey(FloatingNavBar.pillKey),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        expect(outline.position, DecorationPosition.foreground);
        expect((outline.decoration as BoxDecoration).border, isNotNull);
      },
    );

    testWidgets('is glass: blurred, and translucent in both themes', (
      tester,
    ) async {
      final fills = <Brightness, Color>{};
      for (final theme in [AppTheme.dark, AppTheme.light]) {
        await _bar(tester, theme: theme);
        expect(
          find.descendant(
            of: find.byKey(FloatingNavBar.pillKey),
            matching: find.byType(BackdropFilter),
          ),
          findsOneWidget,
        );
        final glass = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(BackdropFilter),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        final colors = ((glass.decoration as BoxDecoration).gradient!
                as LinearGradient)
            .colors;
        for (final c in colors) {
          expect(c.a, lessThan(1), reason: 'see-through');
          expect(c.a, greaterThan(0.5), reason: 'but still a solid backing');
        }
        fills[theme.brightness] = colors.last;
      }
      expect(
        fills[Brightness.dark]!.computeLuminance(),
        lessThan(fills[Brightness.light]!.computeLuminance()),
        reason: 'dark glass on the dark theme, light glass on the light one',
      );
    });

    testWidgets('stays above the system navigation area', (tester) async {
      await _bar(tester, bottomInset: 34);
      final pill = tester.getRect(find.byKey(FloatingNavBar.pillKey));
      expect(844 - pill.bottom, greaterThanOrEqualTo(34 + 8));
    });

    testWidgets('does not stretch across a tablet', (tester) async {
      await _bar(tester, size: const Size(820, 1180));
      final pill = tester.getRect(find.byKey(FloatingNavBar.pillKey));
      expect(pill.width, lessThanOrEqualTo(312));
      expect(pill.center.dx, closeTo(410, 1));
    });

    testWidgets('the selected one sits in a round highlight in the accent; '
        'the others are quiet outline icons', (tester) async {
      await _bar(tester, selected: 1);
      expect(_highlightColor(tester, 1), isNot(Colors.transparent));
      expect(_highlightColor(tester, 1)!.a, greaterThan(0.1));
      expect(
        ((_highlight(tester, 1).decoration as BoxDecoration).shape),
        BoxShape.circle,
      );
      for (final i in [0, 2, 3]) {
        expect(_highlightColor(tester, i)!.a, 0, reason: 'item $i: no highlight');
      }
      // The highlight is small and round, inside the capsule.
      final box = tester.getSize(
        find.descendant(
          of: _slot(1),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(box, const Size.square(FloatingNavBar.highlightSize));
      expect(box.height, lessThan(FloatingNavBar.barHeight));

      // Its icon is the filled one, in the mint accent; the others are outlined and muted.
      expect(
        find.descendant(
          of: _slot(1),
          matching: find.byIcon(Icons.storefront_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _slot(0),
          matching: find.byIcon(Icons.home_outlined),
        ),
        findsOneWidget,
      );
      Color iconColor(int i) => IconTheme.of(
        tester.element(
          find.descendant(of: _slot(i), matching: find.byType(Icon)),
        ),
      ).color!;
      expect(iconColor(1), const Color(0xFF6BC4B2));
      expect(iconColor(0).a, lessThan(0.7));
      expect(iconColor(0), isNot(iconColor(1)));
      // Same size for all icons.
      for (var i = 0; i < 4; i++) {
        expect(
          tester.getSize(
            find.descendant(of: _slot(i), matching: find.byType(Icon)),
          ),
          const Size(24, 24),
        );
      }
    });

    testWidgets('the items are spread evenly', (tester) async {
      await _bar(tester);
      final centres = [
        for (var i = 0; i < 4; i++) tester.getCenter(_slot(i)).dx,
      ];
      final gap = centres[1] - centres[0];
      for (var i = 1; i < 4; i++) {
        expect(centres[i] - centres[i - 1], closeTo(gap, 0.5));
      }
    });

    testWidgets('light theme: the accent is the deeper teal, the glass is light', (
      tester,
    ) async {
      await _bar(tester, theme: AppTheme.light, selected: 2);
      final c = IconTheme.of(
        tester.element(
          find.descendant(of: _slot(2), matching: find.byType(Icon)),
        ),
      ).color!;
      expect(c, AppColors.primaryDark);
      expect(_highlightColor(tester, 2)!.a, greaterThan(0.1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('dark theme: the accent is the lighter mint', (tester) async {
      await _bar(tester, theme: AppTheme.dark, selected: 3);
      final c = IconTheme.of(
        tester.element(
          find.descendant(of: _slot(3), matching: find.byType(Icon)),
        ),
      ).color!;
      expect(c, AppColors.primaryLight);
    });

    testWidgets('tapping each item switches to it', (tester) async {
      final taps = <int>[];
      final index = await _bar(tester, onTap: taps.add);
      for (final i in [1, 2, 3, 0, 3, 1]) {
        await tester.tap(_slot(i));
        await tester.pump(const Duration(milliseconds: 400));
        expect(index.value, i);
        // Only this one is highlighted now, and it shows the filled icon.
        for (var j = 0; j < 4; j++) {
          expect(
            _highlightColor(tester, j)!.a,
            j == i ? greaterThan(0.1) : 0,
            reason: 'tapped $i, item $j',
          );
        }
      }
      expect(taps, [1, 2, 3, 0, 3, 1]);
    });

    testWidgets('a tap on the icon itself switches too', (tester) async {
      final index = await _bar(tester);
      await tester.tap(find.byIcon(Icons.mosque_outlined));
      await tester.pump(const Duration(milliseconds: 400));
      expect(index.value, 2);
    });

    testWidgets('the highlight and the icon colour change smoothly', (
      tester,
    ) async {
      final index = await _bar(tester);
      Color iconColor(int i) => IconTheme.of(
        tester.element(
          find.descendant(of: _slot(i), matching: find.byType(Icon)),
        ),
      ).color!;
      final before = iconColor(2);

      await tester.tap(_slot(2));
      expect(index.value, 2);
      // Half way through the change the highlight is neither gone nor full.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      final mid = _paintedColor(tester, 2);
      final midIcon = iconColor(2);
      await tester.pump(const Duration(milliseconds: 400));
      final end = _paintedColor(tester, 2);
      final endIcon = iconColor(2);
      expect(mid.a, lessThan(end.a));
      expect(mid.a, greaterThan(0));
      expect(midIcon, isNot(before));
      expect(midIcon, isNot(endIcon));
      expect(endIcon, AppColors.primaryLight);
      // The one that was left lets go of its highlight.
      expect(_highlightColor(tester, 0)!.a, 0);
    });

    testWidgets('tapping the selected one again reports it (so a tab can '
        'scroll to its top)', (tester) async {
      final taps = <int>[];
      await _bar(tester, selected: 0, onTap: taps.add);
      await tester.tap(_slot(0));
      expect(taps, [0]);
    });

    testWidgets('every item is an easy target, even though the bar is slim', (
      tester,
    ) async {
      await _bar(tester);
      for (var i = 0; i < 4; i++) {
        final size = tester.getSize(
          find.descendant(of: _slot(i), matching: find.byType(InkWell)),
        );
        expect(size.width, greaterThanOrEqualTo(48), reason: 'item $i');
        expect(size.height, greaterThanOrEqualTo(48), reason: 'item $i');
      }
    });

    testWidgets('a screen reader hears each name and which one is selected', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _bar(tester, selected: 2);
      for (final label in ['Home', 'My Business', 'Deen', 'Profile']) {
        expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      }
      expect(
        tester.getSemantics(find.bySemanticsLabel('Deen')),
        matchesSemantics(
          label: 'Deen',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Home')),
        matchesSemantics(
          label: 'Home',
          isButton: true,
          isSelected: false,
          hasSelectedState: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('the names are also tooltips (long press)', (tester) async {
      await _bar(tester);
      await tester.longPress(_slot(1));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('My Business'), findsOneWidget);
    });

    for (final (name, w, h, scale) in [
      ('a very narrow phone', 280.0, 560.0, 1.0),
      ('a small phone', 320.0, 568.0, 1.0),
      ('large text', 360.0, 800.0, 2.0),
    ]) {
      for (final code in ['en', 'hi', 'ur']) {
        testWidgets('$name, $code: everything fits and stays tappable', (
          tester,
        ) async {
          final index = await _bar(
            tester,
            size: Size(w, h),
            textScale: scale,
            locale: Locale(code),
            bottomInset: 20,
          );
          final pill = tester.getRect(find.byKey(FloatingNavBar.pillKey));
          expect(pill.left, greaterThanOrEqualTo(0));
          expect(pill.right, lessThanOrEqualTo(w));
          expect(pill.height, FloatingNavBar.barHeight);
          for (var i = 0; i < 4; i++) {
            index.value = i;
            await tester.pump(const Duration(milliseconds: 400));
            expect(tester.takeException(), isNull, reason: 'tab $i');
            final slot = tester.getRect(_slot(i));
            expect(slot.width, greaterThanOrEqualTo(48), reason: 'tab $i');
            expect(slot.height, greaterThanOrEqualTo(48), reason: 'tab $i');
            expect(slot.left, greaterThanOrEqualTo(pill.left - 0.5));
            expect(slot.right, lessThanOrEqualTo(pill.right + 0.5));
            final icon = tester.getRect(
              find.descendant(of: _slot(i), matching: find.byType(Icon)),
            );
            expect(icon.left, greaterThanOrEqualTo(slot.left - 0.5));
            expect(icon.right, lessThanOrEqualTo(slot.right + 0.5));
          }
          // And a tap still lands on the right item.
          await tester.tap(_slot(3));
          expect(index.value, 3);
        });
      }
    }

    testWidgets('right to left (Urdu): Home is on the right', (tester) async {
      await _bar(tester, locale: const Locale('ur'));
      expect(
        tester.getCenter(_slot(0)).dx,
        greaterThan(tester.getCenter(_slot(3)).dx),
      );
    });
  });

  group('in the app', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      MainShell.tabRequest.value = null;
      WeatherService.reset();
      WeatherService.get = (_) async => throw Exception('offline');
    });
    tearDown(WeatherService.reset);

    Future<void> shell(WidgetTester tester, {ThemeData? theme}) async {
      tester.view.physicalSize = const Size(360, 800) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final auth = AuthProvider();
      final locale = await tester.runAsync(LocaleProvider.load);
      final themes = await tester.runAsync(ThemeProvider.load);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<LocaleProvider>.value(value: locale!),
            ChangeNotifierProvider<ThemeProvider>.value(value: themes!),
            ChangeNotifierProvider<LiveSync>.value(value: LiveSync(auth)),
          ],
          child: MaterialApp(
            theme: theme ?? AppTheme.dark,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const MainShell(),
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    int selected(WidgetTester tester) => tester
        .widget<FloatingNavBar>(find.byType(FloatingNavBar))
        .selectedIndex;

    Future<void> go(WidgetTester tester, String label) async {
      await tester.tap(
        find.descendant(
          of: find.byType(FloatingNavBar),
          matching: find.byTooltip(label),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    testWidgets('one bar, the four tabs, each opens its own screen', (
      tester,
    ) async {
      await shell(tester);
      expect(find.byType(FloatingNavBar), findsOneWidget);
      expect(selected(tester), MainShell.tabHome);
      expect(find.byType(CustomerScreen), findsOneWidget);

      await go(tester, 'My Business');
      expect(selected(tester), MainShell.tabMyBusiness);
      expect(find.byType(MyBusinessTab), findsOneWidget);
      expect(find.byType(FloatingNavBar), findsOneWidget);

      await go(tester, 'Deen');
      expect(selected(tester), MainShell.tabDeen);
      expect(find.byType(DeenTab), findsOneWidget);
      expect(find.byType(FloatingNavBar), findsOneWidget);

      await go(tester, 'Profile');
      expect(selected(tester), MainShell.tabProfile);
      expect(find.byType(ProfileTab), findsOneWidget);
      expect(find.byType(FloatingNavBar), findsOneWidget);

      await go(tester, 'Home');
      expect(selected(tester), MainShell.tabHome);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the tabs keep their state while you are on another one', (
      tester,
    ) async {
      await shell(tester);
      final home = tester.state(find.byType(CustomerScreen));
      await go(tester, 'Deen');
      await go(tester, 'Profile');
      await go(tester, 'Home');
      expect(tester.state(find.byType(CustomerScreen)), same(home));
      // The tabs that were opened are still there, only hidden.
      expect(find.byType(DeenTab, skipOffstage: false), findsOneWidget);
      expect(find.byType(ProfileTab, skipOffstage: false), findsOneWidget);
      // One that was never opened is not built (no needless work at start).
      expect(find.byType(MyBusinessTab, skipOffstage: false), findsNothing);
    });

    testWidgets('a tapped notification or a link can switch the tab', (
      tester,
    ) async {
      await shell(tester);
      MainShell.tabRequest.value = MainShell.tabMyBusiness;
      await tester.pump(const Duration(milliseconds: 300));
      expect(selected(tester), MainShell.tabMyBusiness);
      MainShell.tabRequest.value = MainShell.tabDeen;
      await tester.pump(const Duration(milliseconds: 300));
      expect(selected(tester), MainShell.tabDeen);
    });

    testWidgets("Android's back goes to Home from any other tab, then leaves", (
      tester,
    ) async {
      await shell(tester);
      await go(tester, 'My Business');
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 300));
      expect(selected(tester), MainShell.tabHome);
    });

    testWidgets('a page opened over a tab (a business, a photo viewer) has no '
        'bar of its own; coming back finds the same tab with its bar', (
      tester,
    ) async {
      await shell(tester);
      await go(tester, 'Deen');
      final nav = Navigator.of(tester.element(find.byType(MainShell)));

      nav.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('a business'))),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.text('a business'), findsOneWidget);
      expect(
        find.byType(FloatingNavBar),
        findsNothing,
        reason: 'not on a detail page',
      );

      nav.pop();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.byType(FloatingNavBar), findsOneWidget);
      expect(
        selected(tester),
        MainShell.tabDeen,
        reason: 'the same tab as before',
      );
      expect(find.byType(DeenTab), findsOneWidget);
    });

    // The tab's own main list (not a chip row inside it).
    Finder mainList(Type tab) => find
        .descendant(
          of: find.descendant(
            of: find.byType(tab),
            matching: find.byType(RefreshIndicator),
          ),
          matching: find.byType(ListView),
        )
        .first;

    /// The page runs behind the bar (no blank strip), and its list pads its end
    /// by just the bar's height so the last item scrolls clear of the capsule.
    Future<void> expectRunsBehindBar(WidgetTester tester, Type tab) async {
      final bar = tester.getRect(find.byType(FloatingNavBar));
      final capsule = tester.getRect(find.byKey(FloatingNavBar.pillKey));
      final list = mainList(tab);

      expect(
        tester.getRect(find.byType(tab)).bottom,
        closeTo(800, 0.5),
        reason: '$tab reaches the bottom of the screen',
      );
      expect(
        tester.getRect(list).bottom,
        closeTo(800, 0.5),
        reason: '$tab: no strip is held back for the bar',
      );
      expect(bar.height, lessThanOrEqualTo(56 + 4 + 8 + 0.5));

      final pad = tester
          .widget<ListView>(list)
          .padding!
          .resolve(TextDirection.ltr)
          .bottom;
      expect(pad, greaterThanOrEqualTo(bar.height), reason: '$tab: enough');
      expect(
        pad,
        lessThanOrEqualTo(bar.height + 16),
        reason: '$tab: and no more than the minimum',
      );

      final scrollable = tester.state<ScrollableState>(
        find.descendant(of: list, matching: find.byType(Scrollable)).first,
      );
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pump();
      final last = tester
          .renderObject<RenderSliverList>(
            find.descendant(of: list, matching: find.byType(SliverList)).first,
          )
          .lastChild!;
      final bottom = last.localToGlobal(Offset(0, last.size.height)).dy;
      expect(
        bottom,
        lessThanOrEqualTo(capsule.top + 0.5),
        reason: '$tab: the last item is not hidden behind the capsule',
      );
      if (scrollable.position.maxScrollExtent > 0) {
        expect(
          capsule.top - bottom,
          lessThanOrEqualTo(16.5),
          reason: '$tab: scrolled to the end it sits just above the capsule',
        );
      }
    }

    testWidgets(
      'every tab runs behind the bar: no blank strip, and its last item '
      'scrolls clear of the capsule',
      (tester) async {
        await shell(tester);
        await expectRunsBehindBar(tester, CustomerScreen);
        for (final (label, tab) in [
          ('My Business', MyBusinessTab),
          ('Deen', DeenTab),
          ('Profile', ProfileTab),
        ]) {
          await go(tester, label);
          await expectRunsBehindBar(tester, tab);
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('behind a system navigation area too', (tester) async {
      tester.view.padding = const FakeViewPadding(bottom: 48);
      tester.view.viewPadding = const FakeViewPadding(bottom: 48);
      await shell(tester);
      final capsule = tester.getRect(find.byKey(FloatingNavBar.pillKey));
      expect(800 - capsule.bottom, greaterThanOrEqualTo(24 + 8));
      for (final tab in [CustomerScreen]) {
        final pad = tester
            .widget<ListView>(mainList(tab))
            .padding!
            .resolve(TextDirection.ltr)
            .bottom;
        expect(
          pad,
          greaterThanOrEqualTo(800 - capsule.top),
          reason: 'clears the capsule, with the inset',
        );
      }
    });

    testWidgets('light theme too', (tester) async {
      await shell(tester, theme: AppTheme.light);
      await go(tester, 'Deen');
      expect(selected(tester), MainShell.tabDeen);
      expect(tester.takeException(), isNull);
    });
  });
}
