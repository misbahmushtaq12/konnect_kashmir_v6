import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

/// `context.l10n.navHome` — the current language's text, resolved at compile
/// time by gen-l10n (no files are parsed while the app runs).
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
