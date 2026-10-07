import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Single source of truth for the app's Light/Dark mode.
///
/// - No saved choice  -> [ThemeMode.system] (follows the device, live).
/// - User flips the Profile toggle -> explicit light/dark, saved locally and
///   never overridden by later device theme changes.
class ThemeProvider extends ChangeNotifier {
  static const _prefKey = 'theme_mode';

  ThemeMode _mode;
  ThemeProvider._(this._mode);

  ThemeMode get mode => _mode;

  /// Reads the saved preference (called once, before runApp, so the very first
  /// frame already uses the right theme).
  static Future<ThemeProvider> load() async {
    ThemeMode mode = ThemeMode.system;
    try {
      final saved = (await SharedPreferences.getInstance()).getString(_prefKey);
      if (saved == 'light') mode = ThemeMode.light;
      if (saved == 'dark') mode = ThemeMode.dark;
    } catch (_) {}
    return ThemeProvider._(mode);
  }

  Future<void> setDark(bool dark) async {
    final next = dark ? ThemeMode.dark : ThemeMode.light;
    if (next == _mode) return;
    _mode = next;
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance())
          .setString(_prefKey, dark ? 'dark' : 'light');
    } catch (_) {}
  }
}
