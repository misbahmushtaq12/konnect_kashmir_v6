import 'dart:async';

/// The rules of the provider search box (Home search and the pushed provider
/// list share them), so a search request is only sent when it is worth sending:
///
///  * the text is trimmed and needs at least [minChars] characters;
///  * the same search typed in another letter case ("Apple" -> "APPLE") is not
///    sent again;
///  * typing is debounced, and a newer query replaces a pending one.
///
/// The database side is unchanged: the search itself is a case-insensitive
/// `ilike` on the provider name (see `ApiService.getVendors`).
class SearchGate {
  SearchGate({
    required this.onSearch,
    this.debounce = const Duration(milliseconds: 400),
    String initial = '',
  }) : _current = initial.trim();

  /// A search is only sent from this many characters (after trimming).
  static const int minChars = 3;

  /// Runs once the user pauses, with the query in [current].
  final void Function() onSearch;
  final Duration debounce;

  Timer? _timer;
  String _current;

  /// The query the server should be asked for; '' means "no text search" (the
  /// box is empty or still shorter than [minChars]).
  String get current => _current;

  /// Call with the text of the box on every change. Returns true when the query
  /// to search for changed, in which case a search is scheduled (replacing any
  /// pending one). Returns false, and leaves a pending search untouched, when
  /// nothing new would be asked: still too short, or only the letter case
  /// changed.
  bool changed(String typed) {
    final next = effective(typed);
    if (same(next, _current)) return false;
    _current = next;
    _timer?.cancel();
    _timer = Timer(debounce, onSearch);
    return true;
  }

  /// Forget everything (box cleared, filters cleared...) and drop a pending
  /// search. The caller loads whatever it needs itself.
  void reset([String query = '']) {
    _timer?.cancel();
    _current = query.trim();
  }

  void dispose() => _timer?.cancel();

  /// What is sent to the server for [typed]: the trimmed text, or '' while it is
  /// shorter than [minChars] characters.
  static String effective(String typed) {
    final t = typed.trim();
    return t.runes.length >= minChars ? t : '';
  }

  /// Something is typed but is not enough to search yet.
  static bool tooShort(String typed) {
    final n = typed.trim().runes.length;
    return n > 0 && n < minChars;
  }

  /// The same search, ignoring letter case.
  static bool same(String a, String b) => a.toLowerCase() == b.toLowerCase();

  /// Makes [query] safe inside a LIKE/ILIKE pattern: `%` and `_` typed by the
  /// user match themselves instead of acting as wildcards.
  static String likeEscape(String query) =>
      query.replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}');
}
