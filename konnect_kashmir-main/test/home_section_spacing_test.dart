import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/l10n/category_names.dart';
import 'package:konnect_kashmir/l10n/l10n.dart';
import 'package:konnect_kashmir/providers/auth_provider.dart';
import 'package:konnect_kashmir/providers/locale_provider.dart';
import 'package:konnect_kashmir/providers/theme_provider.dart';
import 'package:konnect_kashmir/screens/customer_screen.dart';
import 'package:konnect_kashmir/screens/main_shell.dart';
import 'package:konnect_kashmir/services/category_groups.dart';
import 'package:konnect_kashmir/services/live_sync.dart';
import 'package:konnect_kashmir/theme/app_theme.dart';
import 'package:konnect_kashmir/widgets/app_widgets.dart';
import 'package:konnect_kashmir/widgets/floating_nav_bar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Home screen's service sections: every section takes the height of its own
/// tiles and sits the same distance under the one before it, however many rows
/// each one has, and whether or not the floating bottom bar is on the screen.

const _groups = <(String key, CategoryGroup group)>[
  ('home_repair', CategoryGroup.homeRepair),
  ('health_education', CategoryGroup.healthEducation),
  ('food_grocery', CategoryGroup.foodGrocery),
  ('fashion_shopping', CategoryGroup.fashionShopping),
  ('business_professional', CategoryGroup.businessProfessional),
  ('events_travel', CategoryGroup.eventsTravel),
];

/// Categories as the server sends them: [tiles] services per group (so a different
/// number of rows in each), plus one pinned one for Featured.
List<Map<String, dynamic>> _rows(List<int> tiles) => [
  {
    'slug': 'pinned_shop',
    'name': 'Pinned Shop',
    'is_active': true,
    'is_pinned': true,
    'display_order': 0,
    'group_key': null,
  },
  for (var g = 0; g < tiles.length; g++)
    for (var i = 0; i < tiles[g]; i++)
      {
        'slug': 'svc_${g}_$i',
        'name': 'S$g-$i',
        'is_active': true,
        'is_pinned': false,
        'display_order': g * 100 + i,
        'group_key': _groups[g].$1,
      },
];

class _Section {
  _Section(this.title, this.heading, this.tiles);
  final String title;
  final Rect heading;
  final List<Rect> tiles;
  double get top => tiles.map((r) => r.top).reduce((a, b) => a < b ? a : b);
  double get bottom =>
      tiles.map((r) => r.bottom).reduce((a, b) => a > b ? a : b);
  int get rowCount => tiles.map((r) => r.top.round()).toSet().length;
}

void main() {
  const cardHeight = 88.0; // the tile
  const rowGap = 8.0;

  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Opens Home (inside the shell, with its floating bar, unless [shell] is
  /// false) with the given categories saved from "the last visit".
  Future<void> home(
    WidgetTester tester,
    List<Map<String, dynamic>> categories, {
    bool shell = true,
    Size size = const Size(390, 9000),
    double bottomInset = 0,
    ThemeData? theme,
    Locale locale = const Locale('en'),
    double textScale = 1,
  }) async {
    SharedPreferences.setMockInitialValues({
      'service_categories_cache': jsonEncode(categories),
    });
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    tester.view.padding = FakeViewPadding(bottom: bottomInset * 2);
    tester.view.viewPadding = FakeViewPadding(bottom: bottomInset * 2);
    addTearDown(tester.view.reset);
    final auth = AuthProvider();
    final lang = await tester.runAsync(LocaleProvider.load);
    final themes = await tester.runAsync(ThemeProvider.load);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<LocaleProvider>.value(value: lang!),
          ChangeNotifierProvider<ThemeProvider>.value(value: themes!),
          ChangeNotifierProvider<LiveSync>.value(value: LiveSync(auth)),
        ],
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
          home: shell ? const MainShell() : const CustomerScreen(),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    // "Show all", in whatever language the page is in.
    await tester.tap(
      find.descendant(
        of: find.byType(SectionHeader),
        matching: find.byType(TextButton),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  /// The sections as laid out: each group's heading and its tiles.
  List<_Section> sections(WidgetTester tester, List<int> tiles) {
    final out = <_Section>[];
    final context = tester.element(find.byType(CustomerScreen));
    // (The pinned shop has no group of its own, so it is in Featured and in
    // Other, the last section.)
    final groups = <(String, List<String>, int)>[
      (categoryGroupName(context, CategoryGroup.featured), ['Pinned Shop'], 0),
      for (var g = 0; g < tiles.length; g++)
        if (tiles[g] > 0)
          (categoryGroupName(context, _groups[g].$2), [
            for (var i = 0; i < tiles[g]; i++) 'S$g-$i',
          ], 0),
      (categoryGroupName(context, CategoryGroup.other), ['Pinned Shop'], 1),
    ];
    for (final (title, names, which) in groups) {
      final heading = tester.getRect(find.text(title).at(0));
      final rects = <Rect>[];
      for (final n in names) {
        // the tile itself: the Material around the label
        final label = find.text(n);
        final tile = find
            .ancestor(
              of: which == 0 ? label.first : label.last,
              matching: find.byType(InkWell),
            )
            .first;
        rects.add(tester.getRect(tile));
      }
      out.add(_Section(title, heading, rects));
    }
    return out;
  }

  void expectCompact(WidgetTester tester, List<int> tiles, {String? why}) {
    final s = sections(tester, tiles);
    expect(s.length, greaterThan(2));
    for (var i = 0; i < s.length; i++) {
      final sec = s[i];
      // Its grid is as tall as its rows need, no more.
      final rows = (sec.tiles.length / 4).ceil();
      expect(sec.rowCount, rows, reason: '${sec.title}: rows');
      expect(
        sec.bottom - sec.top,
        closeTo(rows * cardHeight + (rows - 1) * rowGap, 0.6),
        reason: '${sec.title}: ${sec.tiles.length} tiles in $rows rows',
      );
      // Heading to its tiles: the same small step for every section.
      expect(
        sec.top - sec.heading.bottom,
        closeTo(8, 0.6),
        reason: '${sec.title}: heading to tiles $why',
      );
      // Section to section: 24-32 logical pixels, whatever the rows.
      if (i + 1 < s.length) {
        final gap = s[i + 1].heading.top - sec.bottom;
        expect(
          gap,
          inInclusiveRange(24, 32),
          reason: '${sec.title} -> ${s[i + 1].title}: blank space $why',
        );
      }
    }
  }

  // 1, 2, 3, 4 and 5 rows, and a group of one tile.
  const mixed = [4, 5, 9, 12, 13, 17];

  group('every section is as tall as its tiles and evenly spaced', () {
    testWidgets('Home with the floating bar: 1, 2, 3, 4 and 5 rows', (
      tester,
    ) async {
      await home(tester, _rows(mixed));
      expect(find.byType(FloatingNavBar), findsOneWidget);
      expectCompact(tester, mixed, why: '(with the bar)');
      expect(tester.takeException(), isNull);
    });

    testWidgets('Home on its own gives the same spacing', (tester) async {
      await home(tester, _rows(mixed), shell: false);
      expectCompact(tester, mixed, why: '(no bar)');
    });

    testWidgets('a single tile in a section is no different', (tester) async {
      const one = [1, 1, 1, 1, 1, 1];
      await home(tester, _rows(one));
      expectCompact(tester, one);
    });

    testWidgets('a full row (4) and one more (5)', (tester) async {
      const edge = [4, 5, 8, 9, 12, 13];
      await home(tester, _rows(edge));
      expectCompact(tester, edge);
    });

    testWidgets('a group with nothing in it leaves no gap', (tester) async {
      const gaps = [4, 0, 5, 0, 0, 3];
      await home(tester, _rows(gaps));
      expect(find.text('Health & Education'), findsNothing);
      final s = sections(tester, gaps);
      for (var i = 0; i + 1 < s.length; i++) {
        expect(
          s[i + 1].heading.top - s[i].bottom,
          inInclusiveRange(24, 32),
          reason: '${s[i].title} -> ${s[i + 1].title}',
        );
      }
    });

    testWidgets('the spacing is the same with a system navigation inset, in '
        'the light theme, in Hindi and Urdu, at large text', (tester) async {
      for (final (theme, locale, scale, inset) in [
        (AppTheme.light, const Locale('en'), 1.0, 34.0),
        (AppTheme.dark, const Locale('hi'), 1.3, 0.0),
        (AppTheme.dark, const Locale('ur'), 2.0, 24.0),
      ]) {
        await home(
          tester,
          _rows(mixed),
          theme: theme,
          locale: locale,
          textScale: scale,
          bottomInset: inset,
          size: const Size(360, 9000),
        );
        final s = sections(tester, mixed);
        // The tile rows do not depend on the language; the headings do, so
        // compare the tiles of each section with the first tile of the next.
        for (var i = 0; i + 1 < s.length; i++) {
          final next = s[i + 1];
          final gap = next.heading.top - s[i].bottom;
          expect(
            gap,
            inInclusiveRange(24, 32),
            reason: '${locale.languageCode} x$scale inset $inset: section $i',
          );
        }
      }
    });

    testWidgets('no blank band under the last section', (tester) async {
      await home(tester, _rows(mixed));
      final last = sections(tester, mixed).last;
      // The providers area starts right under the last section: what is left
      // is the small anchor and the filter chips' own spacing, not a bar-high
      // strip (that was 68px more).
      final next = find.textContaining(' providers');
      expect(next, findsOneWidget);
      final below = tester.getTopLeft(next).dy - last.bottom;
      expect(below, lessThan(40), reason: 'blank space under the last section');
    });
  });

  group('the last cards are not hidden behind the floating bar', () {
    testWidgets('scrolled to the end, the last item of Home ends above the '
        'capsule, with only a small gap', (tester) async {
      await home(tester, _rows(mixed), size: const Size(390, 844));
      final capsule = tester.getRect(find.byKey(FloatingNavBar.pillKey));
      final list = find
          .descendant(
            of: find.descendant(
              of: find.byType(CustomerScreen),
              matching: find.byType(RefreshIndicator),
            ),
            matching: find.byType(ListView),
          )
          .first;
      final scrollable = tester.state<ScrollableState>(
        find.descendant(of: list, matching: find.byType(Scrollable)).first,
      );
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pump();
      final last = tester
          .renderObject<RenderSliverList>(
            find.descendant(of: list, matching: find.byType(SliverList)).first,
          )
          .lastChild!;
      final bottom = last.localToGlobal(Offset(0, last.size.height)).dy;
      expect(bottom, lessThanOrEqualTo(capsule.top + 0.5));
      expect(capsule.top - bottom, lessThanOrEqualTo(16.5));
    });

    testWidgets('the service tiles of the last section can be scrolled clear '
        'of it when they are the end of the page', (tester) async {
      // Nothing follows the sections but the (empty) providers area, which has
      // no height here: the tiles themselves must still clear the capsule.
      await home(tester, _rows(mixed), size: const Size(390, 844));
      final capsule = tester.getRect(find.byKey(FloatingNavBar.pillKey));
      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(CustomerScreen),
          matching: find.byType(Scrollable),
        ).first,
      );
      // Scroll so that the last tile row of the page is at the very end of the
      // content: the gap between content end and capsule is the padding.
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pump();
      final visible = find.descendant(
        of: find.byType(CustomerScreen),
        matching: find.byType(InkWell),
      );
      for (final e in visible.evaluate()) {
        final r = tester.getRect(find.byWidget(e.widget));
        if (r.top < capsule.top && r.bottom > capsule.top) {
          // a tile (or anything tappable) cut by the capsule's top edge can
          // only be one that is simply scrolled behind it, never the last
          expect(r.height, isNot(88), reason: 'a tile is hidden by the bar');
        }
      }
    });
  });
}
