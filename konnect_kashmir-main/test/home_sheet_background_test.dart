import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/l10n/l10n.dart';
import 'package:konnect_kashmir/providers/auth_provider.dart';
import 'package:konnect_kashmir/screens/customer_screen.dart';
import 'package:konnect_kashmir/services/live_sync.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      'a sheet opened over Home (district / locality filter) keeps the Home '
      'layout behind it, not the "Find services" screen', (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final auth = AuthProvider();
    // .value: the provider must not dispose it (that needs a started Supabase).
    final live = LiveSync(auth);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<LiveSync>.value(value: live),
      ],
      child: MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const CustomerScreen(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    // This is the Home tab: its search box, not the pushed screen's.
    expect(find.text('Search vendors...'), findsWidgets);
    expect(find.text('Find services'), findsNothing);

    // Open a sheet over it, as the district and locality filters do, and let
    // the screen rebuild while the sheet is up.
    final context = tester.element(find.byType(CustomerScreen));
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => const SizedBox(height: 200, child: Text('the sheet')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // ignore: invalid_use_of_protected_member
    tester.state(find.byType(CustomerScreen)).setState(() {});
    await tester.pump();

    expect(find.text('the sheet'), findsOneWidget);
    expect(find.text('Find services'), findsNothing);
    expect(find.text('Search vendors...'), findsWidgets);
  });
}
