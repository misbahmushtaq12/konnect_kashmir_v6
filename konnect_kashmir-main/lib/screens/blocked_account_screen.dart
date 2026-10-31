import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

/// Shows [BlockedAccountScreen] instead of the whole app while an admin has
/// blocked the signed-in account (see AuthProvider.isBlocked), like the website's
/// "Account Blocked" page. Signing out (the only way on) returns to the normal app.
class BlockedGate extends StatelessWidget {
  final Widget child;
  const BlockedGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final blocked = context.select<AuthProvider, bool>((a) => a.isBlocked);
    if (!blocked) return child;
    final reason = context.select<AuthProvider, String?>((a) => a.blockedReason);
    return BlockedAccountScreen(
      reason: reason,
      onSignOut: () => context.read<AuthProvider>().logout(),
    );
  }
}

/// "Your account has been blocked", the admin's reason if there is one, how to
/// reach support, and Sign out.
class BlockedAccountScreen extends StatelessWidget {
  final String? reason;
  final VoidCallback onSignOut;

  /// Opens the mail app to the support address (replaced in tests).
  final Future<void> Function()? onContact;
  const BlockedAccountScreen({
    super.key,
    required this.reason,
    required this.onSignOut,
    this.onContact,
  });

  static const supportEmail = 'info@konnectkashmir.com';

  Future<void> _contact() async {
    try {
      await launchUrl(Uri(scheme: 'mailto', path: supportEmail));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final why = reason?.trim() ?? '';
    return Scaffold(
      backgroundColor: AppColors.baseBg(Theme.of(context)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.block_rounded,
                        size: 36, color: AppColors.danger),
                  ),
                  const SizedBox(height: 20),
                  Text(l.blockedTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: AppText.title,
                          fontWeight: FontWeight.w800,
                          color: AppColors.danger)),
                  const SizedBox(height: 14),
                  Text(l.blockedBody,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: AppText.body,
                          height: 1.45,
                          color: cs.onSurface)),
                  if (why.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.25)),
                      ),
                      child: Text(l.blockedReason(why),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: AppText.body,
                              height: 1.4,
                              color: cs.onSurface.withValues(alpha: 0.85))),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text(l.blockedContactHelp,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: AppText.secondary,
                          height: 1.4,
                          color: cs.onSurface.withValues(alpha: 0.65))),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: AppButtons.primary,
                      onPressed: onContact ?? _contact,
                      icon: const Icon(Icons.mail_outline_rounded, size: 20),
                      label: Text(l.blockedContactButton),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(onPressed: onSignOut, child: Text(l.signOut)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
