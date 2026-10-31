import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/screens/deen/audio_controller.dart';
import 'package:konnect_kashmir/screens/deen/deen_data.dart';
import 'package:konnect_kashmir/screens/deen/quran_service.dart';
import 'package:konnect_kashmir/screens/deen/reciters_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_audio_backend.dart';

const _base = 'https://download.quranicaudio.com/quran';

List<Map<String, Object?>> _rows() => [
  {'id': 'id-1', 'name': 'Mishary Rashid Alafasy', 'source_base_url': '$_base/mishaari_raashid_al_3afaasee'},
  {'id': 'id-2', 'name': 'Abdurrahmaan As-Sudais', 'source_base_url': '$_base/abdurrahmaan_as-sudays'},
  {'id': 'id-3', 'name': 'Maher Al-Muaiqly', 'source_base_url': '$_base/maher_almu3aiqly/year1440'},
];

class _FakeSource implements RecitersSource {
  _FakeSource({this.saved, this.fresh, this.fails = false});
  final List<Reciter>? saved;
  final List<Reciter>? fresh;
  final bool fails;
  int fetches = 0;
  @override
  Future<List<Reciter>?> cached() async => saved;
  @override
  Future<List<Reciter>?> fetch() async {
    fetches++;
    if (fails) throw Exception('offline');
    return fresh;
  }
}

Reciter _r(String id, String name, String base) =>
    Reciter.fromCatalog(id: id, name: name, baseUrl: base);

QuranAudioController _make(FakeBackend b, RecitersSource? src) {
  final c = QuranAudioController(b, recitersSource: src);
  c.surahs = const [Surah(1, 'a', 'Al-Faatiha', 'The Opening', 7)];
  c.loading = false;
  return c;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the built-in list', () {
    test('is what the website was filled with: six, in order, same files', () {
      expect(kReciters.map((r) => r.name), [
        'Mishary Rashid Alafasy',
        'Abdurrahmaan As-Sudais',
        'Maher Al-Muaiqly',
        'Mahmoud Khalil Al-Husary',
        'Muhammad Siddiq Al-Minshawi',
        'Abdullah Awad Al-Juhany',
      ]);
      expect(kReciters[0].surahUrl(1), '$_base/mishaari_raashid_al_3afaasee/001.mp3');
      expect(kReciters[2].surahUrl(114), '$_base/maher_almu3aiqly/year1440/114.mp3');
    });

    test('a database reciter builds the same address as the website', () {
      // The website: `<base without a trailing slash>/<NNN>.mp3`.
      expect(
        _r('x', 'A', '$_base/maher_almu3aiqly/year1440/').surahUrl(7),
        '$_base/maher_almu3aiqly/year1440/007.mp3',
      );
      expect(_r('x', 'A', '$_base/slug').surahUrl(36), '$_base/slug/036.mp3');
    });
  });

  group('reading the database rows', () {
    test('good rows become reciters, in the order given', () {
      final list = SupabaseRecitersSource.parse(_rows());
      expect(list.map((r) => r.name), [
        'Mishary Rashid Alafasy',
        'Abdurrahmaan As-Sudais',
        'Maher Al-Muaiqly',
      ]);
      expect(list.map((r) => r.id), ['id-1', 'id-2', 'id-3']);
      expect(list[2].surahUrl(1), '$_base/maher_almu3aiqly/year1440/001.mp3');
    });

    test('a row that cannot be trusted is skipped', () {
      final list = SupabaseRecitersSource.parse([
        ..._rows().take(1),
        {'id': 'bad-1', 'name': 'Plain http', 'source_base_url': 'http://example.com/x'},
        {'id': 'bad-2', 'name': 'Script', 'source_base_url': 'javascript:alert(1)'},
        {'id': 'bad-3', 'name': '', 'source_base_url': 'https://example.com/x'},
        {'id': '', 'name': 'No id', 'source_base_url': 'https://example.com/x'},
        {'id': 'bad-4', 'name': 'No address'},
        'not a row',
        {'id': 'ok-2', 'name': '  Spaced  ', 'source_base_url': ' https://example.com/x '},
      ]);
      expect(list.map((r) => r.name), ['Mishary Rashid Alafasy', 'Spaced']);
      expect(list[1].baseUrl, 'https://example.com/x');
    });

    test('anything that is not a list gives nothing', () {
      expect(SupabaseRecitersSource.parse(null), isEmpty);
      expect(SupabaseRecitersSource.parse({'error': 'x'}), isEmpty);
    });

    test('the copy kept on the phone is read back', () async {
      SharedPreferences.setMockInitialValues({'deen_reciters_v1': jsonEncode(_rows())});
      final list = await SupabaseRecitersSource().cached();
      expect(list, hasLength(3));
      expect(list!.first.id, 'id-1');
    });

    test('no copy, or a damaged one, gives null', () async {
      expect(await SupabaseRecitersSource().cached(), isNull);
      SharedPreferences.setMockInitialValues({'deen_reciters_v1': '{not json'});
      expect(await SupabaseRecitersSource().cached(), isNull);
    });
  });

  group('the audio screen\'s list', () {
    test('starts with the built-in six and no source needed', () async {
      final c = _make(FakeBackend(), null);
      await c.load();
      expect(c.reciters, same(kReciters));
      c.dispose();
    });

    test('takes the saved list at once, then the server\'s', () async {
      final saved = [_r('a', 'Saved One', '$_base/s1')];
      final fresh = [_r('1', 'Mishary Rashid Alafasy', '$_base/m'), _r('2', 'Other', '$_base/o')];
      final c = _make(FakeBackend(), _FakeSource(saved: saved, fresh: fresh));
      await c.load();
      await pumpEventQueue();
      expect(c.reciters.map((r) => r.name), ['Mishary Rashid Alafasy', 'Other']);
      expect(c.currentReciter.id, '1');
      c.dispose();
    });

    test('keeps the built-in list when the server cannot be reached', () async {
      final c = _make(FakeBackend(), _FakeSource(fails: true));
      await c.load();
      await pumpEventQueue();
      expect(c.reciters, same(kReciters));
      c.dispose();
    });

    test('keeps the built-in list when the server sends nothing usable', () async {
      final c = _make(FakeBackend(), _FakeSource(fresh: null));
      await c.load();
      await pumpEventQueue();
      expect(c.reciters, same(kReciters));
      c.dispose();
    });

    test('plays the file the database row points to', () async {
      final backend = FakeBackend();
      final c = _make(backend, _FakeSource(fresh: SupabaseRecitersSource.parse(_rows())));
      await c.load();
      await pumpEventQueue();
      c.setReciter(2);
      await c.play(36);
      expect(backend.urls.last, '$_base/maher_almu3aiqly/year1440/036.mp3');
      c.dispose();
    });

    test('the reciter chosen stays chosen when the list changes underneath', () async {
      final backend = FakeBackend();
      final c = _make(backend, null);
      c.reciters = SupabaseRecitersSource.parse(_rows());
      c.reciter = 2; // Maher Al-Muaiqly
      // The same people again, with one new reciter put first.
      final list = [_r('new', 'New Reciter', '$_base/n'), ...SupabaseRecitersSource.parse(_rows())];
      final source = _FakeSource(fresh: list);
      final c2 = QuranAudioController(backend, recitersSource: source)
        ..surahs = const [Surah(1, 'a', 'Al-Faatiha', 'The Opening', 7)]
        ..loading = false
        ..reciters = SupabaseRecitersSource.parse(_rows())
        ..reciter = 2;
      await c2.load();
      await pumpEventQueue();
      expect(c2.currentReciter.name, 'Maher Al-Muaiqly');
      expect(c2.reciter, 3);
      c.dispose();
      c2.dispose();
    });
  });
}
