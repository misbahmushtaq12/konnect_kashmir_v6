import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Single source of truth for the app's Light/Dark mode.
///
/// - No saved choice  -> [ThemeMode.system] (follows the device, live).
/// - User flips the Profile toggle -> explicit light/dark, saved locally. The
///   choice is relative to the phone's theme at that moment: as soon as the
///   phone's own Light/Dark setting changes (while the app is open, or while it
///   was closed), the app goes back to following the phone, so the app and the
///   Profile toggle never disagree with the phone after it changes.
class ThemeProvider extends ChangeNotifier with WidgetsBindingObserver {
  static const _prefKey = 'theme_mode';
  static const _sysKey = 'theme_mode_sys'; // phone theme when the choice was made

  ThemeMode _mode;
  ThemeProvider._(this._mode) {
    WidgetsBinding.instance.addObserver(this);
  }

  ThemeMode get mode => _mode;

  static String get _systemNow =>
      ui.PlatformDispatcher.instance.platformBrightness.name;

  /// Reads the saved preference (called once, before runApp, so the very first
  /// frame already uses the right theme).
  static Future<ThemeProvider> load() async {
    ThemeMode mode = ThemeMode.system;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved == 'light') mode = ThemeMode.light;
      if (saved == 'dark') mode = ThemeMode.dark;
      // The phone's theme changed since the choice was made: follow the phone.
      if (mode != ThemeMode.system && prefs.getString(_sysKey) != _systemNow) {
        mode = ThemeMode.system;
        await prefs.remove(_prefKey);
        await prefs.remove(_sysKey);
      }
    } catch (_) {}
    return ThemeProvider._(mode);
  }

  /// The phone switched between Light and Dark while the app is running.
  @override
  void didChangePlatformBrightness() {
    if (_mode != ThemeMode.system) {
      _mode = ThemeMode.system;
      _forgetChoice();
    }
    // MaterialApp follows the phone in system mode; this also refreshes
    // everything that listens to the provider.
    notifyListeners();
  }

  Future<void> _forgetChoice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKey);
      await prefs.remove(_sysKey);
    } catch (_) {}
  }

  Future<void> setDark(bool dark) async {
    final next = dark ? ThemeMode.dark : ThemeMode.light;
    if (next == _mode) return;
    _mode = next;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, dark ? 'dark' : 'light');
      await prefs.setString(_sysKey, _systemNow);
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
