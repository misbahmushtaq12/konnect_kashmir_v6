import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The customer's own current position, used to show them the providers of the
/// district they are in. It never invents a position: when the permission is
/// refused or location is off, [current] is null and the Home screen behaves as
/// it always did (all providers).
///
/// A fix is kept for [_fresh], so opening Home, switching tabs and pulling to
/// refresh do not each switch the GPS on.
class CustomerLocation {
  static const Duration _fresh = Duration(minutes: 10);
  static const Duration _usable = Duration(hours: 6);

  static Position? _pos;
  static DateTime? _at;
  static Future<Position?>? _inflight;
  static bool _refused = false; // the user said no in this session: don't nag

  /// The last position, if it is recent. Instant (no GPS, no dialog).
  static Future<({double lat, double lng})?> lastKnown() async {
    final p = _pos;
    if (p != null && _at != null && DateTime.now().difference(_at!) < _usable) {
      return (lat: p.latitude, lng: p.longitude);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble('cust_lat');
      final lng = prefs.getDouble('cust_lng');
      final ms = prefs.getInt('cust_loc_at');
      if (lat == null || lng == null || ms == null) return null;
      final age = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(ms));
      return age < _usable ? (lat: lat, lng: lng) : null;
    } catch (_) {
      return null;
    }
  }

  /// The customer's current position (asks for the permission when needed).
  static Future<Position?> current() {
    final p = _pos;
    if (p != null && _at != null && DateTime.now().difference(_at!) < _fresh) {
      return Future.value(p);
    }
    return _inflight ??= _locate().whenComplete(() => _inflight = null);
  }

  static Future<Position?> _locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied && !_refused) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _refused = true;
        return null;
      }
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 10)),
        );
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }
      if (pos == null) return null;
      _pos = pos;
      _at = DateTime.now();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('cust_lat', pos.latitude);
        await prefs.setDouble('cust_lng', pos.longitude);
        await prefs.setInt('cust_loc_at', _at!.millisecondsSinceEpoch);
      } catch (_) {}
      return pos;
    } catch (e) {
      debugPrint('[CustomerLocation] $e');
      return null;
    }
  }

  /// Place names for a position, most specific first (district, town, area).
  static Future<List<String>> areaNames(double lat, double lng) async {
    try {
      final p = (await Geocoding().placemarkFromCoordinates(lat, lng)).firstOrNull;
      if (p == null) return [];
      return [
        p.subAdministrativeArea,
        p.locality,
        p.subLocality,
      ].whereType<String>().where((s) => s.trim().isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll('district', '')
      .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
      .trim();

  /// The district (from the app's own districts list) that the place names
  /// point to, or null when the customer is outside all of them.
  static Map<String, dynamic>? matchDistrict(
      List<String> names, List<Map<String, dynamic>> districts) {
    for (final raw in names) {
      final n = _norm(raw);
      if (n.isEmpty) continue;
      for (final d in districts) {
        final dn = _norm(d['name']?.toString() ?? '');
        if (dn.isNotEmpty && (dn == n || n.contains(dn) || dn.contains(n))) {
          return d;
        }
      }
    }
    return null;
  }
}
