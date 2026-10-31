import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/l10n/category_names.dart';
import 'package:konnect_kashmir/l10n/l10n.dart';
import 'package:konnect_kashmir/providers/auth_provider.dart';
import 'package:konnect_kashmir/screens/customer_screen.dart';
import 'package:konnect_kashmir/services/category_groups.dart';
import 'package:konnect_kashmir/services/live_sync.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The real category slugs in the database, in display order (read 19 Oct 2026).
const _dbSlugs = [
  'home_services', 'electrician', 'plumber', 'carpenter', 'painter',
  'mason_dasil', 'labour', 'gardener', 'tailor', 'cleaner', 'home_tutor',
  'professional_instructor', 'education_consultant', 'pharmacy',
  'psychiatrist_therapist', 'physiotherapist', 'laptop_mobile_repair',
  'appliance_repair', 'laundry', 'mechanic', 'driver', 'car_rental',
  'car_detailing', 'Furniture & Fixture', 'architect', 'lawyer',
  'chartered_accountant', 'property_dealer', 'buliders_developers',
  'insurance_agent', 'designer', 'web_mobile', 'kashmiri_art_artisans',
  'copperware', 'steel_iron_works', 'Transport_cargo',
  'courier_cargo_services', 'wedding', 'middleman_manzimyor', 'photography',
  'tent', 'catering', 'bakery', 'mehndi_artist', 'makeup_artist',
  'custom_gifting', 'tour_travels', 'flooring_and_furnishing', 'hijama',
  'advertisement_hoardings', 'hajj_umrah', 'cctv_security', 'pet_care',
  'scrap_dealer', 'solar_installer', 'sales_marketing', 'musician',
  'training_fitness', 'agriculture_farming', 'labs_diagnostics',
  'building_material', 'car_bike', 'mens-clothing', 'womens-clothing',
  'shoes', 'kidswear', 'jobseekers', 'clinics', 'heating-hamams',
  'interior-designers', 'food-items', 'beverages', 'grocery', 'other',
];

void main() {
  group('the groups, as on the website', () {
    test('the same sizes as the website\'s Browse page', () {
      final g = CategoryGroups.group<String>(_dbSlugs, (s) => s);
      final sizes = {for (final e in g) e.group: e.items.length};
      expect(sizes, {
        CategoryGroup.homeRepair: 19,
        CategoryGroup.healthEducation: 10,
        CategoryGroup.foodGrocery: 5,
        CategoryGroup.fashionShopping: 7,
        CategoryGroup.businessProfessional: 10,
        CategoryGroup.eventsTravel: 7,
        CategoryGroup.moreServices: 15,
        CategoryGroup.other: 1,
      });
      // Nothing is pinned here, so there is no Featured group.
      expect(g.map((e) => e.group).toList(),
          CategoryGroup.values.where((x) => x != CategoryGroup.featured).toList());
    });

    test('a pinned category (Instagram Shops) is shown first, under Featured, and not again in its group', () {
      // As in the live database: Instagram Shops is first and is the only pinned one.
      final cats = ['instagram-shops', ..._dbSlugs];
      final g = CategoryGroups.group<String>(
        cats,
        (s) => s,
        pinned: (s) => s == 'instagram-shops',
      );
      expect(g.first.group, CategoryGroup.featured);
      expect(g.first.items, ['instagram-shops']);
      expect(g.length, 9, reason: 'Featured and the eight usual groups');
      // It is not in More Services any more, which keeps its other fifteen.
      final more = g.firstWhere((e) => e.group == CategoryGroup.moreServices);
      expect(more.items, isNot(contains('instagram-shops')));
      expect(more.items.length, 15);
      // Every other group is as before.
      expect(g.skip(1).map((e) => e.items.length).toList(), [19, 10, 5, 7, 10, 7, 15, 1]);
    });

    test('Featured keeps the order given, and is never cut by the collapsed limit', () {
      final g = CategoryGroups.group<String>(
        ['instagram-shops', 'painter', 'plumber', 'tailor', 'electrician'],
        (s) => s,
        pinned: (s) => s == 'instagram-shops' || s == 'tailor',
        limit: 1,
      );
      expect(g.map((e) => e.group).toList(), [CategoryGroup.featured, CategoryGroup.homeRepair]);
      expect(g.first.items, ['instagram-shops', 'tailor']);
      expect(g.last.items, ['painter'], reason: 'the limit counts the usual groups only');
    });

    test('without the pinned flag (the offline fallback) Instagram Shops is in More Services, as before', () {
      expect(CategoryGroups.of('instagram-shops'), CategoryGroup.moreServices);
      final g = CategoryGroups.group<String>(['plumber', 'instagram-shops'], (s) => s);
      expect(g.map((e) => e.group).toList(), [CategoryGroup.homeRepair, CategoryGroup.moreServices]);
    });

    test('a group with only pinned items and nothing else still shows Featured', () {
      final g = CategoryGroups.group<String>(['instagram-shops'], (s) => s, pinned: (_) => true);
      expect(g.single.group, CategoryGroup.featured);
    });

    test('a group keeps the database order, like the website', () {
      final g = CategoryGroups.group<String>(_dbSlugs, (s) => s);
      expect(g.first.items.take(8).toList(), [
        'home_services', 'electrician', 'plumber', 'carpenter', 'painter',
        'mason_dasil', 'labour', 'gardener',
      ]);
      expect(g.first.items.last, 'interior-designers');
      // "More Services" collects what no group claims.
      final more = g.firstWhere((e) => e.group == CategoryGroup.moreServices);
      expect(more.items, containsAll(
          ['mechanic', 'driver', 'Furniture & Fixture', 'Transport_cargo', 'jobseekers']));
    });

    test('a slug nobody knows goes to More Services; empty groups are left out', () {
      expect(CategoryGroups.of('something_new'), CategoryGroup.moreServices);
      final g = CategoryGroups.group<String>(['plumber', 'something_new'], (s) => s);
      expect(g.map((e) => e.group).toList(),
          [CategoryGroup.homeRepair, CategoryGroup.moreServices]);
    });

    test('collapsed: the first few, counting group by group', () {
      final g = CategoryGroups.group<String>(_dbSlugs, (s) => s, limit: 7);
      expect(g.length, 1);
      expect(g.single.group, CategoryGroup.homeRepair);
      expect(g.single.items.length, 7);

      // A limit bigger than the first group carries on into the next.
      final two = CategoryGroups.group<String>(_dbSlugs, (s) => s, limit: 21);
      expect(two.map((e) => e.items.length).toList(), [19, 2]);
      expect(two.last.group, CategoryGroup.healthEducation);

      expect(CategoryGroups.group<String>(_dbSlugs, (s) => s, limit: 0), isEmpty);
    });
  });

  group('on the Home screen', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Widget app(Locale locale, AuthProvider auth, LiveSync live) => MultiProvider(
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

    testWidgets('collapsed it shows the first group; "Show all" opens every group',
        (tester) async {
      tester.view.physicalSize = const Size(900, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final auth = AuthProvider();
      await tester.pumpWidget(app(const Locale('en'), auth, LiveSync(auth)));
      await tester.pump(const Duration(milliseconds: 300));

      // Collapsed: one heading and the first seven services. No "All" tile.
      expect(find.text('Our services'), findsOneWidget);
      expect(find.text('All'), findsNothing);
      expect(find.text('Home & Repair'), findsOneWidget);
      expect(find.text('Health & Education'), findsNothing);
      expect(find.text('Electrician'), findsOneWidget);

      await tester.tap(find.text('Show all'));
      await tester.pumpAndSettle();

      for (final heading in [
        'Home & Repair', 'Health & Education', 'Food & Grocery',
        'Fashion & Shopping', 'Business & Professional', 'Events & Travel',
        'More Services', 'Other',
      ]) {
        // 'Other' is also the name of one service tile, so it appears twice.
        expect(find.text(heading),
            heading == 'Other' ? findsNWidgets(2) : findsOneWidget,
            reason: heading);
      }
      // Headings appear in the website's order, top to bottom.
      double y(String t) => tester.getTopLeft(find.text(t).first).dy;
      expect(y('Home & Repair') < y('Health & Education'), isTrue);
      expect(y('Health & Education') < y('Food & Grocery'), isTrue);
      expect(y('Business & Professional') < y('Events & Travel'), isTrue);
      expect(y('More Services') < y('Other'), isTrue);

      await tester.tap(find.text('Show less'));
      await tester.pumpAndSettle();
      expect(find.text('Health & Education'), findsNothing);
    });

    testWidgets('choosing a service shows a chip that clears it, and so does '
        'tapping the service again', (tester) async {
      tester.view.physicalSize = const Size(900, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final auth = AuthProvider();
      await tester.pumpWidget(app(const Locale('en'), auth, LiveSync(auth)));
      await tester.pump(const Duration(milliseconds: 300));

      // The chip row (the active filters) is not there before a choice.
      expect(find.byIcon(Icons.close), findsNothing);

      await tester.tap(find.text('Electrician'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      // The tile and the chip both say Electrician.
      expect(find.text('Electrician'), findsNWidgets(2));
      expect(find.byIcon(Icons.close), findsOneWidget);

      // The cross clears the choice.
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Electrician'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);

      // Tapping the same service twice also clears it.
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
      for (final e in {'en': 'Featured', 'hi': 'विशेष', 'ur': 'نمایاں'}.entries) {
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
            home: Builder(builder: (context) {
              name = categoryGroupName(context, CategoryGroup.featured);
              return const SizedBox();
            }),
          ),
        );
        expect(name, e.value, reason: e.key);
      }
    });

    testWidgets('the group names follow the app language', (tester) async {
      tester.view.physicalSize = const Size(900, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final auth = AuthProvider();
      await tester.pumpWidget(app(const Locale('hi'), auth, LiveSync(auth)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('घर और मरम्मत'), findsOneWidget);
      expect(find.text('Home & Repair'), findsNothing);
    });
  });

}
