import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Surah {
  final int number;
  final String arabic;
  final String english;
  final String translation;
  final int ayahs;
  const Surah(this.number, this.arabic, this.english, this.translation, this.ayahs);

  factory Surah.fromJson(Map<String, dynamic> j) => Surah(
        j['number'] as int,
        j['name'] as String,
        j['englishName'] as String,
        j['englishNameTranslation'] as String,
        j['numberOfAyahs'] as int,
      );

  Map<String, dynamic> toJson() => {
        'number': number,
        'name': arabic,
        'englishName': english,
        'englishNameTranslation': translation,
        'numberOfAyahs': ayahs,
      };
}

class Ayah {
  final int number; // number within the surah
  final String arabic;
  final String english;
  const Ayah(this.number, this.arabic, this.english);
}

/// Quran text from the public alquran.cloud API (Uthmani Arabic + Sahih
/// International English). The surah list never changes, so it is kept on the
/// phone after the first load.
class QuranService {
  static const _base = 'https://api.alquran.cloud/v1';
  static List<Surah>? _surahs;
  static final Map<int, List<Ayah>> _ayahs = {};

  static Future<List<Surah>> surahs() async {
    if (_surahs != null) return _surahs!;
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('quran_surahs');
    if (cached != null) {
      try {
        return _surahs = (jsonDecode(cached) as List)
            .map((e) => Surah.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (_) {}
    }
    final res = await http
        .get(Uri.parse('$_base/surah'))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) throw Exception('Quran unavailable (${res.statusCode})');
    final data = (jsonDecode(res.body)['data'] as List)
        .map((e) => Surah.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    await prefs.setString(
        'quran_surahs', jsonEncode(data.map((s) => s.toJson()).toList()));
    return _surahs = data;
  }

  static Future<List<Ayah>> ayahs(int surah) async {
    final hit = _ayahs[surah];
    if (hit != null) return hit;
    final res = await http
        .get(Uri.parse('$_base/surah/$surah/editions/quran-uthmani,en.sahih'))
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) throw Exception('Quran unavailable (${res.statusCode})');
    final editions = jsonDecode(res.body)['data'] as List;
    final ar = editions[0]['ayahs'] as List;
    final en = editions[1]['ayahs'] as List;
    final list = <Ayah>[
      for (var i = 0; i < ar.length; i++)
        Ayah(ar[i]['numberInSurah'] as int, ar[i]['text'] as String,
            en[i]['text'] as String),
    ];
    return _ayahs[surah] = list;
  }

  // ── Where the user stopped reading ─────────────────────────────────────────

  static Future<({int surah, int ayah})?> lastRead() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getInt('quran_last_surah');
    final a = prefs.getInt('quran_last_ayah');
    if (s == null || a == null) return null;
    return (surah: s, ayah: a);
  }

  static Future<void> saveLastRead(int surah, int ayah) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('quran_last_surah', surah);
    await prefs.setInt('quran_last_ayah', ayah);
  }
}
