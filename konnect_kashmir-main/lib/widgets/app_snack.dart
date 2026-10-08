import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum SnackType { success, error, warning, info }

/// One consistent snackbar for the whole app: same shape, text style and four
/// meaningful colours (success / error / warning / info) from [AppColors].
void showAppSnack(
  BuildContext context,
  String message, {
  SnackType type = SnackType.info,
  Duration? duration,
  SnackBarAction? action,
}) {
  final (Color bg, IconData icon) = switch (type) {
    SnackType.success => (AppColors.success, Icons.check_circle_outline_rounded),
    SnackType.error => (AppColors.danger, Icons.error_outline_rounded),
    SnackType.warning => (AppColors.warning, Icons.warning_amber_rounded),
    SnackType.info => (const Color(0xFF2B3A3A), Icons.info_outline_rounded),
  };
  // Warning is a light amber: dark text keeps it readable.
  final fg = type == SnackType.warning ? const Color(0xFF2A1D00) : Colors.white;

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      backgroundColor: bg,
      duration: duration ??
          Duration(seconds: type == SnackType.error ? 4 : 3),
      action: action,
      content: Row(children: [
        Icon(icon, color: fg, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: fg, fontSize: AppText.body, fontWeight: FontWeight.w600)),
        ),
      ]),
    ));
}
