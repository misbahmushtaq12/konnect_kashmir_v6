import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

// App accent (same teal as the rest of the UI).
const Color _kAccent = AppColors.primary;

/// "Contact Details" sheet shown after a lead's phone number is revealed.
/// Uses the app theme (solid bottom-sheet surface), so it matches Light/Dark.
Future<void> showLeadContactSheet(
    BuildContext context, String name, String phone) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
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
                      Text('Contact Details',
                          style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      Text('Contact information for $name',
                          style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.6),
                              fontSize: 13)),
                    ]),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Icon(Icons.close,
                    color: cs.onSurface.withValues(alpha: 0.5)),
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
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            phone.isNotEmpty
                ? Text('+91  $phone',
                    style: const TextStyle(
                        color: AppColors.primaryLight,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5))
                : Text('Phone not available',
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.5),
                        fontSize: 16)),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.phone_in_talk, size: 22),
                  label: const Text('Call Now',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ),
              ),
          ]),
        ),
      );
    },
  );
}
