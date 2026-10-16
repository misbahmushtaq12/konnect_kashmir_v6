import 'package:url_launcher/url_launcher.dart';

/// Google Maps links for a provider's address, with no backend change.
///
/// The address is still one text in `vendors.address`. A pin, when the provider
/// has one, is a Google Maps link written after the address text:
///
///     Lal Chowk, Srinagar https://maps.app.goo.gl/AbCdEf
///
/// [split] and [join] move between that text and its two parts, so the form can
/// show an address box and a link box, and the listing can show the address
/// without the link. Old addresses (no link) are untouched.
class MapLink {
  MapLink._();

  /// Added to a text search so it does not land in another state.
  static const String region = 'Jammu and Kashmir';

  static final RegExp _url = RegExp(r'https?://\S+', caseSensitive: false);
  static final RegExp _plusCode = RegExp(r'^[0-9A-Z]{4,8}\+[0-9A-Z]{2,}');
  static final RegExp _googleHost = RegExp(r'^(www\.)?google\.(com|co\.in)$');
  static final RegExp _mapsGoogleHost = RegExp(r'^maps\.google\.(com|co\.in)$');

  /// Only links that really go to Google Maps are accepted (the app opens them).
  static bool isGoogleMapsLink(String link) {
    final u = Uri.tryParse(link.trim());
    if (u == null || (u.scheme != 'https' && u.scheme != 'http')) return false;
    final host = u.host.toLowerCase();
    if (host == 'maps.app.goo.gl') return u.path.length > 1;
    if (host == 'goo.gl') return u.path.startsWith('/maps');
    if (_mapsGoogleHost.hasMatch(host)) return true;
    return _googleHost.hasMatch(host) && u.path.startsWith('/maps');
  }

  /// The first Google Maps link inside [text], or null.
  static String? extractLink(String text) {
    for (final m in _url.allMatches(text)) {
      final raw = m.group(0)!.replaceFirst(RegExp(r'[).,;!?]+$'), '');
      if (isGoogleMapsLink(raw)) return raw;
    }
    return null;
  }

  /// A stored address as its text and its Google Maps link (null if none).
  static ({String text, String? link}) split(String address) {
    final link = extractLink(address);
    if (link == null) return (text: address.trim(), link: null);
    final text = address
        .replaceFirst(link, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[\s|,;:\-–]+|[\s|,;:\-–]+$'), '');
    return (text: text, link: link);
  }

  /// The text to store. [link] replaces any link already in [text]; with no
  /// [link], a link typed inside [text] is kept.
  static String join(String text, [String? link]) {
    final s = split(text);
    final given = (link ?? '').trim().isEmpty ? null : extractLink(link!);
    final l = given ?? (link == null || link.trim().isEmpty ? s.link : null);
    return [s.text, if (l != null) l].where((p) => p.isNotEmpty).join(' ');
  }

  /// An exact pin at a GPS position.
  static String pinFromCoordinates(double lat, double lng) =>
      'https://www.google.com/maps/search/?api=1'
      '&query=${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';

  static Uri searchUrl(String query) => Uri.https(
      'www.google.com', '/maps/search/', {'api': '1', 'query': query});

  /// Where "Show in map" goes: the provider's pin if it has one, else a search
  /// for its address (with the locality), else for its name in the locality.
  /// Null when there is nothing to look for.
  static Uri? target({
    required String address,
    String locality = '',
    String businessName = '',
  }) {
    final s = split(address);
    if (s.link != null) return Uri.parse(s.link!);
    final loc = locality.trim();
    String? query;
    if (s.text.isNotEmpty) {
      final lower = s.text.toLowerCase();
      query = [
        s.text,
        if (loc.isNotEmpty && !lower.contains(loc.toLowerCase())) loc,
        if (!lower.contains('kashmir')) region,
      ].join(', ');
    } else if (loc.isNotEmpty && businessName.trim().isNotEmpty) {
      query = '${businessName.trim()}, $loc, $region';
    }
    return query == null ? null : searchUrl(query);
  }

  /// One address line from the parts a place lookup returns, most specific
  /// first. Empty parts, repeats and Plus Codes ("WJ5P+XX") are left out.
  static String composeAddress(Iterable<String?> parts) {
    final seen = <String>{};
    final out = <String>[];
    for (final p in parts) {
      final t = (p ?? '').trim();
      if (t.isEmpty || _plusCode.hasMatch(t)) continue;
      if (seen.add(t.toLowerCase())) out.add(t);
    }
    return out.join(', ');
  }

  /// Opens Google Maps (the app, or the browser). False if nothing could open it.
  static Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
