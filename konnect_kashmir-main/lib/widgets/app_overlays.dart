import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// One bottom sheet for the whole app. Background, rounded top, safe-area and
/// the drag handle all come from the theme, so every sheet looks the same and
/// never draws its own (second) handle. Don't pass colours or shapes here.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    showDragHandle: true,
    builder: builder,
  );
}

/// One dialog for the whole app. Shape, colour and text styles come from the
/// theme's dialogTheme. Give either a [message] or a custom [content].
Future<T?> showAppDialog<T>(
  BuildContext context, {
  required String title,
  String? message,
  Widget? content,
  required List<Widget> actions,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: content ?? (message != null ? Text(message) : null),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: actions,
    ),
  );
}

/// Standard confirm dialog: Cancel (secondary) + confirm (primary, or danger for
/// destructive actions). Returns true only when the user confirms.
Future<bool> showAppConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool danger = false,
}) async {
  final ok = await showAppDialog<bool>(
    context,
    title: title,
    message: message,
    actions: [
      Row(children: [
        Expanded(
          child: ElevatedButton(
            style: AppButtons.secondary,
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelLabel),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            style: danger ? AppButtons.danger : AppButtons.primary,
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ),
      ]),
    ],
  );
  return ok == true;
}
