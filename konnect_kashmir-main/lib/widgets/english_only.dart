import 'package:flutter/widgets.dart';

/// Shows [child] (and everything below it) in English, left-to-right, whatever
/// language the rest of the app is using. The sign-in and OTP screens use this:
/// they must always be English, even right after a logout from Hindi or Urdu.
class EnglishOnly extends StatelessWidget {
  final Widget child;
  const EnglishOnly({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Localizations.override(
        context: context,
        locale: const Locale('en'),
        child: child,
      );
}
