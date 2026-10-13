import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'legal_chrome.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ── Theme helpers ────────────────────────────────────────────────────
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final strongText = cs.onSurface;
    final subtleText = cs.onSurface.withOpacity(0.55);
    final teal = cs.primary;
    final cardBorder = cs.onSurface.withOpacity(0.1);

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                const LegalAppBar(),

                Expanded(
                  child: SingleChildScrollView(
                    padding: kLegalPagePadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LegalHeader(
                          title: context.l10n.contactUs,
                          subtitle: 'We\'re here to help. Reach out to us anytime!',
                        ),

                        _buildContactCard(
                          icon: Icons.location_on,
                          title: context.l10n.ourOffice,
                          content:
                          '101, Iram Tower, Opp Police HQS,\nKaran Nagar, Srinagar 190010',
                          teal: teal,
                          strongText: strongText,
                          cardBorder: cardBorder,
                          surface: cs.surface,
                          onTap: () => _openMap(),
                        ),
                        const SizedBox(height: 16),
                        _buildContactCard(
                          icon: Icons.email_outlined,
                          title: context.l10n.email,
                          content: 'info@konnectkashmir.com',
                          teal: teal,
                          strongText: strongText,
                          cardBorder: cardBorder,
                          surface: cs.surface,
                          onTap: () =>
                              _sendEmail('info@konnectkashmir.com'),
                        ),
                        const SizedBox(height: 16),
                        _buildContactCard(
                          icon: Icons.phone_outlined,
                          title: context.l10n.callUs,
                          content: '+91 9055566624',
                          teal: teal,
                          strongText: strongText,
                          cardBorder: cardBorder,
                          surface: cs.surface,
                          onTap: () => _makeCall('+919055566624'),
                        ),
                        const SizedBox(height: 16),
                        _buildContactCard(
                          icon: Icons.chat_bubble_outline,
                          title: context.l10n.whatsapp,
                          content: context.l10n.chatWithUsWhatsapp,
                          teal: teal,
                          strongText: strongText,
                          cardBorder: cardBorder,
                          surface: cs.surface,
                          onTap: () => _openWhatsApp('+919055566624'),
                        ),
                        const SizedBox(height: 16),
                        _buildBusinessHoursCard(
                          context,
                          strongText: strongText,
                          subtleText: subtleText,
                          cardBorder: cardBorder,
                          rowBg: cs.onSurface.withOpacity(isDark ? 0.08 : 0.04),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String content,
    required VoidCallback onTap,
    required Color teal,
    required Color strongText,
    required Color cardBorder,
    required Color surface,
  }) {
    final radius = BorderRadius.circular(AppRadius.lg);
    return Material(
      color: surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: cardBorder, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, color: teal, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: AppText.heading,
                        fontWeight: FontWeight.bold,
                        color: strongText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      content,
                      style: TextStyle(
                          fontSize: AppText.body, color: teal, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: strongText.withValues(alpha: 0.35)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBusinessHoursCard(
    BuildContext context, {
    required Color strongText,
    required Color subtleText,
    required Color cardBorder,
    required Color rowBg,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(Icons.schedule_rounded,
                    color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  context.l10n.businessHours,
                  style: TextStyle(
                    fontSize: AppText.heading,
                    fontWeight: FontWeight.bold,
                    color: strongText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.mondaySaturday,
                        style: TextStyle(
                            fontSize: AppText.body,
                            color: subtleText,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 12),
                    Text(context.l10n.sunday,
                        style: TextStyle(
                            fontSize: AppText.body,
                            color: subtleText,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('9:00 AM - 6:00 PM',
                        style: TextStyle(
                            fontSize: AppText.caption,
                            color: subtleText,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Text(context.l10n.closed,
                        style: TextStyle(
                            fontSize: AppText.body,
                            color: subtleText,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openMap() async {
    final Uri url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=101+Iram+Tower+Karan+Nagar+Srinagar',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _sendEmail(String email) async {
    final Uri emailUri = Uri(
        scheme: 'mailto',
        path: email,
        query: 'subject=Inquiry from KonnectKashmir');
    if (await canLaunchUrl(emailUri)) await launchUrl(emailUri);
  }

  Future<void> _makeCall(String phoneNumber) async {
    final Uri telUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(telUri)) await launchUrl(telUri);
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    final Uri whatsappUri = Uri.parse(
        'https://wa.me/$phoneNumber?text=Hi KonnectKashmir');
    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    }
  }
}