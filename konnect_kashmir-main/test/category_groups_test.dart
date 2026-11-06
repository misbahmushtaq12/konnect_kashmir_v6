import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/l10n/category_names.dart';
import 'package:konnect_kashmir/l10n/l10n.dart';
import 'package:konnect_kashmir/providers/auth_provider.dart';
import 'package:konnect_kashmir/screens/customer_screen.dart';
import 'package:konnect_kashmir/services/category_groups.dart';
import 'package:konnect_kashmir/services/live_sync.dart';
import 'package:konnect_kashmir/widgets/app_widgets.dart' show Skeleton;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The real `service_categories` rows (read from the live database on 6 Nov
/// 2026): slug, name, is_active, is_pinned, display_order, group_key.
List<Map<String, dynamic>> _live() =>
    (jsonDecode(
              File(
                'test/fixtures/service_categories_live.json',
              ).readAsStringSync(),
            )
            as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

typedef _Cat = Map<String, dynamic>;

List<({CategoryGroup group, List<_Cat> items})> _group(
  Iterable<_Cat> rows, {
  int? limit,
}) => CategoryGroups.group<_Cat>(
  rows,
  groupKeyOf: (c) => c['group_key'] as String?,
  pinned: (c) => c['is_pinned'] == true,
  orderOf: (c) => (c['display_order'] as num?)?.toInt() ?? 0,
  nameOf: (c) => c['name'].toString(),
  limit: limit,
);

_Cat _c(
  String slug, {
  String? group,
  int order = 0,
  bool pinned = false,
  String? name,
}) => {
  'slug': slug,
  'name': name ?? slug,
  'group_key': group,
  'display_order': order,
  'is_pinned': pinned,
  'is_active': true,
};

List<String> _slugs(List<_Cat> l) => [for (final c in l) c['slug'] as String];

void main() {
  group('the nine groups', () {
    test('are in the fixed order, with the database\'s keys', () {
      expect(CategoryGroup.values.map((g) => g.label), [
        'Featured',
        'Home & Repair',
        'Health & Education',
        'Food & Grocery',
        'Fashion & Shopping',
        'Business & Professional',
        'Events & Travel',
        'More Services',
        'Other',
      ]);
      expect(CategoryGroup.values.map((g) => g.key), [
        null,
        'home_repair',
        'health_education',
        'food_grocery',
        'fashion_shopping',
        'business_professional',
        'events_travel',
        'more_services',
        'other',
      ]);
    });

    test('a key names its group; no key, or one we do not know, is Other', () {
      expect(CategoryGroup.fromKey('home_repair'), CategoryGroup.homeRepair);
      expect(
        CategoryGroup.fromKey('more_services'),
        CategoryGroup.moreServices,
      );
      expect(CategoryGroup.fromKey('other'), CategoryGroup.other);
      expect(CategoryGroup.fromKey(null), CategoryGroup.other);
      expect(CategoryGroup.fromKey(''), CategoryGroup.other);
      expect(CategoryGroup.fromKey('  '), CategoryGroup.other);
      expect(CategoryGroup.fromKey('brand_new_group'), CategoryGroup.other);
      // Featured is never named by a key: it is the pinned ones.
      expect(CategoryGroup.fromKey('featured'), CategoryGroup.other);
    });
  });

  group('grouping what the admin decided', () {
    test(
      'the groups come in the fixed order whatever order the data is in',
      () {
        final g = _group([
          _c('a', group: 'events_travel'),
          _c('b', group: 'home_repair'),
          _c('c', group: 'other'),
          _c('d', group: 'food_grocery'),
        ]);
        expect(g.map((e) => e.group), [
          CategoryGroup.homeRepair,
          CategoryGroup.foodGrocery,
          CategoryGroup.eventsTravel,
          CategoryGroup.other,
        ]);
      },
    );

    test(
      'a category with no group is under Other, with the ones placed there',
      () {
        final g = _group([
          _c('placed', group: 'other', order: 5),
          _c('unplaced', order: 1),
          _c('odd', group: 'something_else', order: 3),
        ]);
        expect(g.single.group, CategoryGroup.other);
        expect(_slugs(g.single.items), ['unplaced', 'odd', 'placed']);
      },
    );

    test('empty groups are not shown', () {
      final g = _group([_c('a', group: 'health_education')]);
      expect(g.map((e) => e.group), [CategoryGroup.healthEducation]);
      expect(_group(const []), isEmpty);
    });

    test('inside a group: by display order, then by name, then as given', () {
      final g = _group([
        _c('z', group: 'home_repair', order: 2, name: 'Zebra'),
        _c('b2', group: 'home_repair', order: 1, name: 'beta'),
        _c('a1', group: 'home_repair', order: 1, name: 'Alpha'),
        _c('first', group: 'home_repair', order: 0, name: 'Plumber'),
        _c('same1', group: 'home_repair', order: 3, name: 'Same'),
        _c('same2', group: 'home_repair', order: 3, name: 'same'),
      ]);
      expect(_slugs(g.single.items), [
        'first',
        'a1',
        'b2',
        'z',
        'same1',
        'same2',
      ]);
    });

    test('moving a category to another group needs no change in the app', () {
      final rows = [_c('brand_new_thing', group: 'home_repair')];
      expect(_group(rows).single.group, CategoryGroup.homeRepair);
      rows.single['group_key'] = 'food_grocery';
      expect(_group(rows).single.group, CategoryGroup.foodGrocery);
      rows.single['display_order'] =
          7; // reordering: only the order of its group
      expect(_group(rows).single.items.single['slug'], 'brand_new_thing');
    });
  });

  group('Featured', () {
    test('is the pinned categories, first, in display order', () {
      final g = _group([
        _c('plumber', group: 'home_repair', order: 3, pinned: true),
        _c('tailor', group: 'fashion_shopping', order: 1, pinned: true),
        _c('electrician', group: 'home_repair', order: 2),
      ]);
      expect(g.first.group, CategoryGroup.featured);
      expect(_slugs(g.first.items), ['tailor', 'plumber']);
    });

    test('is hidden when nothing is pinned', () {
      final g = _group([_c('a', group: 'home_repair')]);
      expect(g.map((e) => e.group), isNot(contains(CategoryGroup.featured)));
    });

    test('a pinned category is also in its own group', () {
      final g = _group([
        _c('plumber', group: 'home_repair', order: 3, pinned: true),
        _c('electrician', group: 'home_repair', order: 2),
      ]);
      expect(_slugs(g[0].items), ['plumber']);
      expect(g[1].group, CategoryGroup.homeRepair);
      expect(_slugs(g[1].items), ['electrician', 'plumber']);
    });

    test('unpinning takes it out of Featured and nothing else changes', () {
      final rows = [
        _c('plumber', group: 'home_repair', pinned: true),
        _c('electrician', group: 'home_repair', order: 1),
      ];
      expect(_group(rows).first.group, CategoryGroup.featured);
      rows.first['is_pinned'] = false;
      final g = _group(rows);
      expect(g.single.group, CategoryGroup.homeRepair);
      expect(_slugs(g.single.items), ['plumber', 'electrician']);
    });

    test('a pinned one with no group is in Featured and under Other', () {
      final g = _group([_c('instagram-shops', pinned: true)]);
      expect(g.map((e) => e.group), [
        CategoryGroup.featured,
        CategoryGroup.other,
      ]);
    });
  });

  group('the collapsed Home view (a limit)', () {
    final many = [
      for (var i = 0; i < 10; i++) _c('h$i', group: 'home_repair', order: i),
      for (var i = 0; i < 4; i++) _c('f$i', group: 'food_grocery', order: i),
    ];

    test('the first few, counting group by group', () {
      final g = _group(many, limit: 7);
      expect(g.single.group, CategoryGroup.homeRepair);
      expect(g.single.items.length, 7);
      final two = _group(many, limit: 12);
      expect(two.map((e) => e.items.length), [10, 2]);
      expect(two.last.group, CategoryGroup.foodGrocery);
      expect(_group(many, limit: 0), isEmpty);
    });

    test('Featured is never cut by it, and is not counted', () {
      final g = _group([
        _c('pin1', pinned: true),
        _c('pin2', pinned: true, order: 1),
        ...many,
      ], limit: 1);
      expect(g.map((e) => e.group), [
        CategoryGroup.featured,
        CategoryGroup.homeRepair,
      ]);
      expect(_slugs(g.first.items), ['pin1', 'pin2']);
      expect(g.last.items.length, 1);
    });
  });

  group('the live categories (a snapshot of the database)', () {
    test('every group has what the website has', () {
      final g = _group(_live());
      final sizes = {for (final e in g) e.group: e.items.length};
      expect(sizes, {
        CategoryGroup.featured: 1,
        CategoryGroup.homeRepair: 19,
        CategoryGroup.healthEducation: 10,
        CategoryGroup.foodGrocery: 5,
        CategoryGroup.fashionShopping: 7,
        CategoryGroup.businessProfessional: 10,
        CategoryGroup.eventsTravel: 7,
        // nothing is in More Services yet
        CategoryGroup.other: 21, // the 'other' one and 20 not yet placed
      });
      expect(
        g.map((e) => e.group),
        isNot(contains(CategoryGroup.moreServices)),
      );
    });

    test(
      'Featured is Instagram Shops; Plumber is in Home & Repair, in order',
      () {
        final g = _group(_live());
        expect(_slugs(g.first.items), ['instagram-shops']);
        final home = g.firstWhere((e) => e.group == CategoryGroup.homeRepair);
        expect(_slugs(home.items).take(8).toList(), [
          'home_services',
          'electrician',
          'plumber',
          'carpenter',
          'painter',
          'mason_dasil',
          'labour',
          'gardener',
        ]);
      },
    );

    test('what is not placed yet is under Other', () {
      final other = _group(_live()).last;
      expect(other.group, CategoryGroup.other);
      expect(
        _slugs(other.items),
        containsAll([
          'mechanic',
          'driver',
          'car_rental',
          'jobseekers',
          'instagram-shops',
        ]),
      );
    });

    test(
      'no category is lost: every one is in exactly one group (and Featured)',
      () {
        final rows = _live();
        final g = _group(rows);
        final seen = <String>[];
        for (final e in g.where((e) => e.group != CategoryGroup.featured)) {
          seen.addAll(_slugs(e.items));
        }
        expect(seen.length, rows.length);
        expect(seen.toSet(), rows.map((r) => r['slug']).toSet());
      },
    );
  });

  group('on the Home screen', () {
    Widget app(Locale locale, AuthProvider auth, LiveSync live) =>
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<LiveSync>.value(value: live),
          ],
          child: MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const CustomerScreen(),
          ),
        );

    /// The categories "from the last visit" (the server cannot be reached here).
    void saved(List<_Cat> rows) => SharedPreferences.setMockInitialValues({
      'service_categories_cache': jsonEncode(rows),
    });

    Future<void> home(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      tester.view.physicalSize = const Size(900, 8000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final auth = AuthProvider();
      await tester.pumpWidget(app(locale, auth, LiveSync(auth)));
      await tester.pump(const Duration(milliseconds: 300));
    }

    double y(WidgetTester tester, String t) =>
        tester.getTopLeft(find.text(t).first).dy;

    testWidgets(
      'the groups are on screen at once, from the last visit: Featured '
      'first, then Home & Repair, collapsed to the first seven',
      (tester) async {
        saved(_live());
        await home(tester);

        expect(find.text('Our services'), findsOneWidget);
        expect(find.text('Featured'), findsOneWidget);
        expect(find.text('Instagram Shops'), findsOneWidget);
        expect(find.text('Home & Repair'), findsOneWidget);
        expect(y(tester, 'Featured'), lessThan(y(tester, 'Home & Repair')));
        expect(
          y(tester, 'Instagram Shops'),
          lessThan(y(tester, 'Home & Repair')),
        );
        // the first seven of the group, in the admin's order
        for (final name in [
          'Home Services',
          'Electrician',
          'Plumber',
          'Carpenter',
          'Painter',
          'Mason (Dasil)',
          'Labour / Helper',
        ]) {
          expect(find.text(name), findsOneWidget, reason: name);
        }
        expect(
          find.text('Gardener'),
          findsNothing,
          reason: 'the eighth is behind Show all',
        );
        expect(find.text('Health & Education'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('"Show all" opens every group, in the fixed order; empty ones '
        'are not there', (tester) async {
      saved(_live());
      await home(tester);
      await tester.tap(find.text('Show all'));
      await tester.pumpAndSettle();

      final headings = [
        'Featured',
        'Home & Repair',
        'Health & Education',
        'Food & Grocery',
        'Fashion & Shopping',
        'Business & Professional',
        'Events & Travel',
      ];
      for (final h in headings) {
        expect(find.text(h), findsOneWidget, reason: h);
      }
      for (var i = 0; i < headings.length - 1; i++) {
        expect(
          y(tester, headings[i]),
          lessThan(y(tester, headings[i + 1])),
          reason: headings[i],
        );
      }
      expect(
        find.text('More Services'),
        findsNothing,
        reason: 'nothing is in it',
      );
      // "Other" is the last heading: the group (and the one category of that name).
      expect(find.text('Other'), findsNWidgets(2));
      expect(y(tester, 'Events & Travel'), lessThan(y(tester, 'Other')));
      // What is not placed yet is there, under Other.
      expect(y(tester, 'Mechanic'), greaterThan(y(tester, 'Events & Travel')));
      expect(find.text('Car Rental'), findsOneWidget);

      await tester.tap(find.text('Show less'));
      await tester.pumpAndSettle();
      expect(find.text('Health & Education'), findsNothing);
    });

    testWidgets('an admin change shows the next time it loads: Plumber moved to '
        'Featured, a new category in Food & Grocery', (tester) async {
      final rows = _live();
      rows.firstWhere((r) => r['slug'] == 'plumber')['is_pinned'] = true;
      rows.firstWhere((r) => r['slug'] == 'plumber')['display_order'] = -5;
      rows.add(
        _c(
          'brand_new',
          group: 'food_grocery',
          order: 99,
          name: 'Brand New Bakery',
        ),
      );
      saved(rows);
      await home(tester);
      await tester.tap(find.text('Show all'));
      await tester.pumpAndSettle();

      // Plumber is under Featured, before Instagram Shops (order -5 against 0), and
      // still in Home & Repair.
      expect(find.text('Plumber'), findsNWidgets(2));
      // (the same row of tiles: Plumber comes first)
      expect(
        tester.getTopLeft(find.text('Plumber').first).dx,
        lessThan(tester.getTopLeft(find.text('Instagram Shops').first).dx),
      );
      expect(find.text('Brand New Bakery'), findsOneWidget);
      expect(
        y(tester, 'Brand New Bakery'),
        greaterThan(y(tester, 'Food & Grocery')),
      );
      expect(
        y(tester, 'Brand New Bakery'),
        lessThan(y(tester, 'Fashion & Shopping')),
      );
    });

    testWidgets('unpinned: no Featured at all', (tester) async {
      final rows = _live();
      for (final r in rows) {
        r['is_pinned'] = false;
      }
      saved(rows);
      await home(tester);
      expect(find.text('Featured'), findsNothing);
      expect(find.text('Home & Repair'), findsOneWidget);
    });

    testWidgets('a category the admin has not placed shows under Other', (
      tester,
    ) async {
      saved([
        _c('plumber', group: 'home_repair', name: 'Plumber'),
        _c('mystery', name: 'Mystery Trade', order: 2),
      ]);
      await home(tester);
      expect(find.text('Home & Repair'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);
      expect(find.text('Mystery Trade'), findsOneWidget);
      expect(y(tester, 'Home & Repair'), lessThan(y(tester, 'Other')));
    });

    testWidgets('before anything is known: a placeholder, not the services in '
        'the wrong places', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(900, 8000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final auth = AuthProvider();
      await tester.pumpWidget(app(const Locale('en'), auth, LiveSync(auth)));
      // The very first frame.
      expect(find.byType(Skeleton), findsWidgets);
      expect(find.text('Electrician'), findsNothing);
      expect(find.text('Our services'), findsOneWidget);
    });

    testWidgets(
      'no internet and nothing saved: the built-in list, in one plain '
      'list with no group headings',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await home(tester);
        await tester.pump(const Duration(seconds: 7));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Electrician'), findsOneWidget);
        expect(find.text('Home & Repair'), findsNothing);
        expect(find.text('Featured'), findsNothing);
        expect(find.byType(Skeleton), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('choosing a service shows a chip that clears it, and so does '
        'tapping the service again', (tester) async {
      saved(_live());
      await home(tester);

      expect(find.byIcon(Icons.close), findsNothing);
      await tester.tap(find.text('Electrician'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Electrician'), findsNWidgets(2));
      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Electrician'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);

      await tester.tap(find.text('Electrician'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byIcon(Icons.close), findsOneWidget);
      await tester.tap(find.text('Electrician').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('Featured has a name in every language', (tester) async {
      for (final e in {
        'en': 'Featured',
        'hi': 'विशेष',
        'ur': 'نمایاں',
      }.entries) {
        late String name;
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(e.key),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Builder(
              builder: (context) {
                name = categoryGroupName(context, CategoryGroup.featured);
                return const SizedBox();
              },
            ),
          ),
        );
        expect(name, e.value, reason: e.key);
      }
    });

    testWidgets('the group names follow the app language', (tester) async {
      saved(_live());
      await home(tester, locale: const Locale('hi'));
      expect(find.text('घर और मरम्मत'), findsOneWidget);
      expect(find.text('विशेष'), findsOneWidget);
      expect(find.text('Home & Repair'), findsNothing);
    });
  });
}
