import 'dart:convert';

/// Aladhan's `/calendar/{year}/{month}` answer for a whole month.
///
/// Every day has the same times unless [times] changes them (it is given the
/// request address, so a test can make the times depend on the place or the
/// madhhab). The zone name is [zone].
String aladhanMonthJson(
  int year,
  int month, {
  String zone = 'Asia/Kolkata',
  List<String> times = const ['05:10', '12:15', '15:30', '17:45', '19:05'],
  bool zoneSuffix = true,
}) {
  String t(int i) => zoneSuffix ? '${times[i]} (IST)' : times[i];
  final days = DateTime.utc(year, month + 1, 0).day;
  String two(int n) => n.toString().padLeft(2, '0');
  return jsonEncode({
    'code': 200,
    'status': 'OK',
    'data': [
      for (var d = 1; d <= days; d++)
        {
          'timings': {
            'Fajr': t(0),
            'Sunrise': '06:30 (IST)',
            'Dhuhr': t(1),
            'Asr': t(2),
            'Sunset': '17:45 (IST)',
            'Maghrib': t(3),
            'Isha': t(4),
          },
          'date': {
            'readable': '$d',
            'gregorian': {'date': '${two(d)}-${two(month)}-$year'},
            'hijri': {'day': '1'},
          },
          'meta': {'timezone': zone},
        },
    ],
  });
}

/// A fake Aladhan: remembers every request and can be made to fail.
class FakeAladhan {
  FakeAladhan({this.respond});

  /// Builds the body for a request, or null for the default month.
  final String Function(Uri uri, int year, int month)? respond;

  final List<Uri> calls = [];
  bool fail = false;

  Future<String> fetch(Uri uri) async {
    calls.add(uri);
    if (fail) throw Exception('no internet');
    // /v1/calendar/{year}/{month}
    final seg = uri.pathSegments;
    final y = int.parse(seg[seg.length - 2]);
    final m = int.parse(seg.last);
    return respond?.call(uri, y, m) ?? aladhanMonthJson(y, m);
  }
}
