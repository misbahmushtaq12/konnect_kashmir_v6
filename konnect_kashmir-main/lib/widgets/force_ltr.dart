import 'package:flutter/widgets.dart';

/// Keeps a screen left-to-right even when the app language is Urdu (RTL).
/// Used for screens whose text is English only (e.g. the legal documents), so
/// English never appears mirrored.
class ForceLtr extends StatelessWidget {
  final Widget child;
  const ForceLtr({super.key, required this.child});

  @override
  Widget build(BuildContext context) =>
      Directionality(textDirection: TextDirection.ltr, child: child);
}
