import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/backend_config.dart';
import '../../services/shared_http.dart';
import 'deen_data.dart';

/// Where the list of reciters comes from. The real one is the `audio_reciters`
/// table, which the website uses too; the tests use a fake.
abstract class RecitersSource {
  /// The copy saved on the phone the last time, or null.
  Future<List<Reciter>?> cached();

  /// The list from the server, or null when it cannot be had (offline, an error,
  /// nothing usable in the answer).
  Future<List<Reciter>?> fetch();
}

/// Reads `audio_reciters` (the same table as the website) with the app's public
/// key: only active rows, in the table's order. Nothing here needs, or could use,
/// a secret: what the public key may read is decided by the table's own
/// row-level-security policy.
class SupabaseRecitersSource implements RecitersSource {
  static const _cacheKey = 'deen_reciters_v1';

  @override
  Future<List<Reciter>?> cached() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_cacheKey);
      if (raw == null) return null;
      final list = parse(jsonDecode(raw));
      return list.isEmpty ? null : list;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Reciter>?> fetch() async {
    try {
      final res = await sharedHttp
          .get(
            Uri.parse(
              '$kSupabaseUrl/rest/v1/audio_reciters'
              '?select=id,name,source_base_url&is_active=eq.true'
              '&order=sort_order.asc,name.asc',
            ),
            headers: {
              'apikey': kSupabaseAnonKey,
              'Authorization': 'Bearer $kSupabaseAnonKey',
            },
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final list = parse(jsonDecode(res.body));
      if (list.isEmpty) return null;
      try {
        await (await SharedPreferences.getInstance()).setString(
          _cacheKey,
          jsonEncode([
            for (final r in list)
              {'id': r.id, 'name': r.name, 'source_base_url': r.baseUrl},
          ]),
        );
      } catch (_) {}
      if (kDebugMode) {
        debugPrint('[Deen] ${list.length} reciters loaded from the database');
      }
      return list;
    } catch (_) {
      return null;
    }
  }

  /// The rows as reciters. A row that cannot be used is skipped: no id, no name,
  /// or an address that is not https (the list is data from a database, so it is
  /// checked before it is trusted to play anything).
  @visibleForTesting
  static List<Reciter> parse(Object? json) {
    if (json is! List) return const [];
    final out = <Reciter>[];
    for (final row in json) {
      if (row is! Map) continue;
      final id = row['id'];
      final name = row['name'];
      final base = row['source_base_url'];
      if (id is! String || id.trim().isEmpty) continue;
      if (name is! String || name.trim().isEmpty) continue;
      if (base is! String) continue;
      final uri = Uri.tryParse(base.trim());
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) continue;
      out.add(
        Reciter.fromCatalog(
          id: id.trim(),
          name: name.trim(),
          baseUrl: base.trim(),
        ),
      );
    }
    return out;
  }
}
