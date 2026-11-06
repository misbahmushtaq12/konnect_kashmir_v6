import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/l10n/category_names.dart';
import 'package:konnect_kashmir/l10n/l10n.dart';

/// The real `service_categories` rows (live database, 6 Nov 2026).
List<Map<String, dynamic>> _live() =>
    (jsonDecode(File('test/fixtures/service_categories_live.json').readAsStringSync())
            as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

/// `categoryName` for every category, in one language.
Future<Map<String, String>> _names(WidgetTester tester, String code) async {
  final out = <String, String>{};
  await tester.pumpWidget(MaterialApp(
    locale: Locale(code),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Builder(builder: (context) {
      for (final c in _live()) {
        out[c['slug'] as String] =
            categoryName(context, c['slug'] as String, c['name'] as String);
      }
      return const SizedBox();
    }),
  ));
  return out;
}

final _devanagari = RegExp(r'[ऀ-ॿ]');
final _arabicScript = RegExp(r'[؀-ۿ]');

void main() {
  testWidgets('Instagram Shops has a Hindi and an Urdu name', (tester) async {
    expect((await _names(tester, 'en'))['instagram-shops'], 'Instagram Shops');
    expect((await _names(tester, 'hi'))['instagram-shops'], 'इंस्टाग्राम शॉप्स');
    expect((await _names(tester, 'ur'))['instagram-shops'], 'انسٹاگرام شاپس');
  });

  testWidgets('every live category is named in Hindi and in Urdu (none falls back to English)',
      (tester) async {
    final rows = _live();
    expect(rows.length, greaterThan(70)); // the fixture is the full list
    final en = await _names(tester, 'en');
    final hi = await _names(tester, 'hi');
    final ur = await _names(tester, 'ur');
    for (final c in rows) {
      final slug = c['slug'] as String;
      expect(en[slug], c['name'], reason: 'English is the data\'s own name: $slug');
      expect(hi[slug], matches(_devanagari), reason: 'Hindi name of $slug: ${hi[slug]}');
      expect(ur[slug], matches(_arabicScript), reason: 'Urdu name of $slug: ${ur[slug]}');
    }
  });

  testWidgets('a category the app has never heard of still shows its English name',
      (tester) async {
    late String name;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ur'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(builder: (context) {
        name = categoryName(context, 'brand-new-slug', 'Brand New');
        return const SizedBox();
      }),
    ));
    expect(name, 'Brand New');
  });
}
