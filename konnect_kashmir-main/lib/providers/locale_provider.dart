import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app language (English / Hindi / Urdu). Same idea as ThemeProvider: load
/// once before runApp so the very first frame is already in the right language.
class LocaleProvider extends ChangeNotifier {
  static const prefLocale = 'app_locale';
  static const prefChosen = 'app_locale_chosen';

  /// Languages the app offers, with their own (native) names.
  static const supported = <AppLanguage>[
    AppLanguage(Locale('en'), 'English'),
    AppLanguage(Locale('hi'), 'हिन्दी'),
    AppLanguage(Locale('ur'), 'اردو'),
  ];

  Locale _locale;
  bool _chosen;
  LocaleProvider._(this._locale, this._chosen);

  Locale get locale => _locale;

  /// False until the user has picked a language once (first login).
  bool get hasChosen => _chosen;

  String get nativeName => supported
      .firstWhere((l) => l.locale.languageCode == _locale.languageCode,
          orElse: () => supported.first)
      .nativeName;

  static Future<LocaleProvider> load() async {
    Locale locale = const Locale('en');
    bool chosen = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(prefLocale);
      if (code != null && supported.any((l) => l.locale.languageCode == code)) {
        locale = Locale(code);
      }
      chosen = prefs.getBool(prefChosen) ?? false;
    } catch (_) {}
    return LocaleProvider._(locale, chosen);
  }

  /// Switches the language immediately (screen updates at once).
  Future<void> setLocale(Locale locale) async {
    if (locale.languageCode == _locale.languageCode) return;
    _locale = locale;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefLocale, locale.languageCode);
    } catch (_) {}
  }

  /// Remembers that the user has made a choice, so the picker isn't shown again.
  Future<void> confirmChoice() async {
    _chosen = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefLocale, _locale.languageCode);
      await prefs.setBool(prefChosen, true);
    } catch (_) {}
  }
}

class AppLanguage {
  final Locale locale;
  final String nativeName;
  const AppLanguage(this.locale, this.nativeName);
}
