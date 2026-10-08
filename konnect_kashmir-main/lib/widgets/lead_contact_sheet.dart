import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import 'app_overlays.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

// App accent (same teal as the rest of the UI).
const Color _kAccent = AppColors.primary;

/// context.l10n.contactDetails sheet shown after a lead's phone number is revealed.
/// Uses the app theme (solid bottom-sheet surface), so it matches Light/Dark.
Future<void> showLeadContactSheet(
    BuildContext context, String name, String phone) {
  return showAppSheet<void>(
    context: context,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              const Icon(Icons.phone_outlined, color: _kAccent, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.l10n.contactDetails,
                          style: TextStyle(
                              color: cs.onSurface,
                              fontSize: AppText.title,
                              fontWeight: FontWeight.bold)),
                      Text('Contact information for $name',
                          style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.7),
                              fontSize: AppText.secondary)),
                    ]),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Icon(Icons.close,
                    color: cs.onSurface.withValues(alpha: 0.66)),
              ),
            ]),
            const SizedBox(height: 28),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                  color: _kAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle),
              child:
                  const Icon(Icons.person_outline, color: _kAccent, size: 40),
            ),
            const SizedBox(height: 14),
            Text(name,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: cs.onSurface,
                    fontSize: AppText.heading,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            phone.isNotEmpty
                ? Text('+91  $phone',
                    style: const TextStyle(
                        color: AppColors.primaryLight,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5))
                : Text(context.l10n.phoneNotAvailable,
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.66),
                        fontSize: AppText.body)),
            const SizedBox(height: 26),
            if (phone.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final uri = Uri(scheme: 'tel', path: phone);
                    if (await canLaunchUrl(uri)) await launchUrl(uri);
                  },
                  style: AppButtons.primary,
                  icon: const Icon(Icons.phone_in_talk, size: 22),
                  label: Text(context.l10n.callNow,
                      style:
                          TextStyle(fontSize: AppText.heading, fontWeight: FontWeight.bold)),
                ),
              ),
          ]),
        ),
      );
    });
}
