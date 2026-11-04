import 'dart:io';

import 'package:flutter/material.dart';
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
    icon: const Icon(Icons.person_outline),
    selectedIcon: const Icon(Icons.person),
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
  int selected = 0,
  void Function(int)? onTap,
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  tester.view.padding = FakeViewPadding(bottom: bottomInset * 2);
  tester.view.viewPadding = FakeViewPadding(bottom: bottomInset * 2);
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
        body: const SizedBox.expand(),
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
    testWidgets('has the four destinations, each named', (tester) async {
      await _bar(tester);
      expect(find.byType(FloatingNavBar), findsOneWidget);
      for (final label in ['Home', 'My Business', 'Deen', 'Profile']) {
        expect(find.byTooltip(label), findsOneWidget, reason: label);
      }
      for (var i = 0; i < 4; i++) {
        expect(_slot(i), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'floats: rounded, inset from the sides, above the bottom edge',
      (tester) async {
        await _bar(tester);
        final pill = tester.getRect(find.byKey(FloatingNavBar.pillKey));
        expect(pill.left, greaterThanOrEqualTo(20));
        expect(390 - pill.right, greaterThanOrEqualTo(20));
        expect(
          844 - pill.bottom,
          greaterThanOrEqualTo(12),
          reason: 'air below it',
        );
        expect(pill.height, FloatingNavBar.barHeight);

        final box =
            tester
                    .widget<DecoratedBox>(find.byKey(FloatingNavBar.pillKey))
                    .decoration
                as BoxDecoration;
        expect(
          box.borderRadius,
          BorderRadius.circular(FloatingNavBar.barHeight / 2),
        );
        expect(box.boxShadow, isNotEmpty, reason: 'it casts a soft shadow');
        expect(box.border, isNotNull, reason: 'with a fine outline');
      },
    );

    testWidgets('the page above it fades out, without catching any touch', (
      tester,
    ) async {
      await _bar(tester);
      final bar = tester.getRect(find.byType(FloatingNavBar));
      final fade = find.descendant(
        of: find.byType(FloatingNavBar),
        matching: find.byType(IgnorePointer),
      );
      expect(fade, findsWidgets);
      final strip = tester.getRect(fade.first);
      expect(strip.bottom, closeTo(bar.top, 0.5));
      expect(strip.height, FloatingNavBar.fadeHeight);
      expect(strip.width, 390);
    });

    testWidgets('stays above the system navigation area', (tester) async {
      await _bar(tester, bottomInset: 34);
      final pill = tester.getRect(find.byKey(FloatingNavBar.pillKey));
      expect(844 - pill.bottom, greaterThanOrEqualTo(34 + 12));
    });

    testWidgets('does not stretch across a tablet', (tester) async {
      await _bar(tester, size: const Size(820, 1180));
      final pill = tester.getRect(find.byKey(FloatingNavBar.pillKey));
      expect(pill.width, lessThanOrEqualTo(440));
      expect(pill.center.dx, closeTo(410, 1));
    });

    testWidgets('the selected one is highlighted and named; the others are '
        'quiet icons', (tester) async {
      await _bar(tester, selected: 1);
      expect(_highlightColor(tester, 1), isNot(Colors.transparent));
      expect(_highlightColor(tester, 1)!.a, greaterThan(0.1));
      for (final i in [0, 2, 3]) {
        expect(_highlightColor(tester, i), Colors.transparent);
      }
      // Its name is written under it; the others have no text.
      expect(
        find.descendant(of: _slot(1), matching: find.text('My Business')),
        findsOneWidget,
      );
      for (final i in [0, 2, 3]) {
        expect(
          find.descendant(of: _slot(i), matching: find.byType(Text)),
          findsNothing,
        );
      }
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

    testWidgets('light theme: the accent is the deeper teal', (tester) async {
      await _bar(tester, theme: AppTheme.light, selected: 2);
      final c = IconTheme.of(
        tester.element(
          find.descendant(of: _slot(2), matching: find.byType(Icon)),
        ),
      ).color!;
      expect(c, AppColors.primaryDark);
    });

    testWidgets('a tap selects, and the highlight moves with a smooth change', (
      tester,
    ) async {
      final taps = <int>[];
      final index = await _bar(tester, onTap: taps.add);
      await tester.tap(_slot(2));
      expect(taps, [2]);
      expect(index.value, 2);

      // Half way through the change the highlight is neither gone nor full.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      final mid = _paintedColor(tester, 2);
      await tester.pump(const Duration(milliseconds: 400));
      final end = _paintedColor(tester, 2);
      expect(mid.a, lessThan(end.a));
      expect(mid.a, greaterThan(0));
      expect(_highlightColor(tester, 0), Colors.transparent);
      expect(
        find.descendant(of: _slot(2), matching: find.text('Deen')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _slot(0), matching: find.text('Home')),
        findsNothing,
      );
    });

    testWidgets('tapping the selected one again reports it (so a tab can '
        'scroll to its top)', (tester) async {
      final taps = <int>[];
      await _bar(tester, selected: 0, onTap: taps.add);
      await tester.tap(_slot(0));
      expect(taps, [0]);
    });

    testWidgets('every item is an easy target', (tester) async {
      await _bar(tester);
      for (var i = 0; i < 4; i++) {
        final size = tester.getSize(
          find.descendant(of: _slot(i), matching: find.byType(InkWell)),
        );
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
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
      handle.dispose();
    });

    for (final (name, w, h, scale) in [
      ('a small phone', 320.0, 568.0, 1.0),
      ('large text', 360.0, 800.0, 2.0),
    ]) {
      for (final code in ['en', 'hi', 'ur']) {
        testWidgets('$name, $code: every tab fits', (tester) async {
          final index = await _bar(
            tester,
            size: Size(w, h),
            textScale: scale,
            locale: Locale(code),
            bottomInset: 20,
          );
          for (var i = 0; i < 4; i++) {
            index.value = i;
            await tester.pump(const Duration(milliseconds: 400));
            expect(tester.takeException(), isNull, reason: 'tab $i');
            final label = tester.widget<Text>(
              find.descendant(of: _slot(i), matching: find.byType(Text)),
            );
            final r = tester.getRect(find.byWidget(label));
            final slot = tester.getRect(_slot(i));
            expect(r.left, greaterThanOrEqualTo(slot.left - 0.5));
            expect(r.right, lessThanOrEqualTo(slot.right + 0.5));
          }
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

    testWidgets(
      'the bar leaves the page above it alone: nothing hidden behind it',
      (tester) async {
        await shell(tester);
        final bar = tester.getRect(find.byType(FloatingNavBar));
        final page = tester.getRect(find.byType(CustomerScreen));
        expect(page.bottom, lessThanOrEqualTo(bar.top + 0.5));
        expect(bar.bottom, closeTo(800, 0.5));
      },
    );

    testWidgets('light theme too', (tester) async {
      await shell(tester, theme: AppTheme.light);
      await go(tester, 'Deen');
      expect(selected(tester), MainShell.tabDeen);
      expect(tester.takeException(), isNull);
    });
  });
}
