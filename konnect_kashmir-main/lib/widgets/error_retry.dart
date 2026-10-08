import 'package:flutter/material.dart';
import '../l10n/l10n.dart';

import '../theme/app_theme.dart';

/// Full-area error state with a Retry button, used instead of a snackbar that
/// disappears after a few seconds. Tells "no internet" apart from other errors.
class ErrorRetry extends StatelessWidget {
  final bool offline;
  final VoidCallback onRetry;
  final String? title;

  const ErrorRetry({
    super.key,
    required this.offline,
    required this.onRetry,
    this.title,
  });

  /// Builds the state from a raw error/exception text.
  factory ErrorRetry.fromError(
    String? raw, {
    Key? key,
    required VoidCallback onRetry,
    String? title,
  }) =>
      ErrorRetry(
        key: key,
        offline: isOfflineError(raw),
        onRetry: onRetry,
        title: title,
      );

  static bool isOfflineError(String? raw) {
    final t = (raw ?? '').toLowerCase();
    return t.contains('socketexception') ||
        t.contains('failed host lookup') ||
        t.contains('network is unreachable') ||
        t.contains('connection refused') ||
        t.contains('connection closed') ||
        t.contains('clientexception') ||
        t.contains('timeoutexception') ||
        t.contains('timed out');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title ??
                (offline ? context.l10n.noInternet : context.l10n.somethingWrong),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: AppText.heading, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            offline
                ? context.l10n.checkConnection
                : context.l10n.tryAgainMoment,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.7),
                fontSize: AppText.body,
                height: 1.4),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: Text(context.l10n.retry),
            style: AppButtons.primary,
          ),
        ]),
      ),
    );
  }
}
