import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/services/search_gate.dart';

void main() {
  group('rules', () {
    test('a search needs 3 characters after trimming', () {
      expect(SearchGate.effective(''), '');
      expect(SearchGate.effective('a'), '');
      expect(SearchGate.effective('ap'), '');
      expect(SearchGate.effective('  ap  '), '');
      expect(SearchGate.effective('app'), 'app');
      expect(SearchGate.effective('  app  '), 'app');
      expect(SearchGate.effective('apple'), 'apple');
    });

    test('characters are counted, not bytes (Urdu, Hindi)', () {
      expect(SearchGate.effective('کا'), '');
      expect(SearchGate.effective('کاری'), 'کاری');
      expect(SearchGate.effective('दुकान'), 'दुकान');
    });

    test('the hint is for 1-2 characters only', () {
      expect(SearchGate.tooShort(''), isFalse);
      expect(SearchGate.tooShort('   '), isFalse);
      expect(SearchGate.tooShort('a'), isTrue);
      expect(SearchGate.tooShort(' ap '), isTrue);
      expect(SearchGate.tooShort('app'), isFalse);
    });

    test('letter case does not make a different search', () {
      expect(SearchGate.same('Apple', 'APPLE'), isTrue);
      expect(SearchGate.same('apple', 'aPpLe'), isTrue);
      expect(SearchGate.same('apple', 'apples'), isFalse);
    });

    test('% _ and \\ typed by the user are matched literally', () {
      expect(SearchGate.likeEscape('plumber'), 'plumber');
      expect(SearchGate.likeEscape('50%'), r'50\%');
      expect(SearchGate.likeEscape('a_b'), r'a\_b');
      expect(SearchGate.likeEscape(r'a\b'), r'a\\b');
    });
  });

  group('requests', () {
    const wait = Duration(milliseconds: 400);

    // Runs [steps] against a gate and returns the queries that were searched.
    Future<List<String>> run(
      WidgetTester tester,
      List<(String, Duration)> steps,
    ) async {
      final searched = <String>[];
      late final SearchGate gate;
      gate = SearchGate(onSearch: () => searched.add(gate.current));
      for (final (typed, pause) in steps) {
        gate.changed(typed);
        await tester.pump(pause);
      }
      await tester.pump(wait);
      gate.dispose();
      return searched;
    }

    testWidgets('the table from the brief: a, ap, app, appl, apple, APPLE, empty',
        (tester) async {
      final searched = await run(tester, [
        for (final t in ['a', 'ap', 'app', 'appl', 'apple', 'APPLE', ''])
          (t, wait),
      ]);
      // 1-2 characters: nothing. 3+: one request each. Case-only: nothing.
      // Emptied after a search: one request to reset the list.
      expect(searched, ['app', 'appl', 'apple', '']);
    });

    testWidgets('typing fast sends one request, for the final text',
        (tester) async {
      final searched = await run(tester, [
        for (final t in ['a', 'ap', 'app', 'appl', 'apple'])
          (t, const Duration(milliseconds: 100)),
      ]);
      expect(searched, ['apple']);
    });

    testWidgets('1 or 2 characters never search', (tester) async {
      expect(await run(tester, [('a', wait), ('ap', wait)]), isEmpty);
    });

    testWidgets('deleting below 3 drops the pending search', (tester) async {
      final searched = await run(tester, [
        ('apple', const Duration(milliseconds: 100)),
        ('ap', wait),
      ]);
      // "apple" never went out; only the reset to "no text search" did.
      expect(searched, ['']);
    });

    testWidgets('only the letter case changed: no new request, results kept',
        (tester) async {
      final searched = await run(tester, [('Apple', wait), ('APPLE', wait)]);
      expect(searched, ['Apple']);
    });

    testWidgets('a case-only change does not cancel the pending search',
        (tester) async {
      final searched = await run(tester, [
        ('Apple', const Duration(milliseconds: 100)),
        ('APPLE', wait),
      ]);
      expect(searched, ['Apple']);
    });

    testWidgets('surrounding spaces are ignored', (tester) async {
      final searched = await run(tester, [(' apple ', wait), ('apple', wait)]);
      expect(searched, ['apple']);
    });

    testWidgets('reset drops a pending search', (tester) async {
      final searched = <String>[];
      late final SearchGate gate;
      gate = SearchGate(onSearch: () => searched.add(gate.current));
      gate.changed('apple');
      gate.reset();
      await tester.pump(wait * 2);
      expect(searched, isEmpty);
      expect(gate.current, '');
      gate.dispose();
    });
  });
}
