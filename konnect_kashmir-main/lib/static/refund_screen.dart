import 'package:flutter/material.dart';
import 'grevience_screen.dart';

class RefundPolicy extends StatelessWidget {
  const RefundPolicy({super.key});

  // ── Theme-adaptive logo ───────────────────────────────────────────────────
  // Asset is a BLACK logo on transparent background.
  // Light mode → show as-is (black logo on light bg) ✅
  // Dark mode  → invert to white (white logo on dark bg) ✅
  static Widget _adaptiveLogo(BuildContext context, {double height = 40}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          -1,  0,  0, 0, 255,
          0, -1,  0, 0, 255,
          0,  0, -1, 0, 255,
          0,  0,  0, 1,   0,
        ]),
        child: Image.asset('assets/images/konnectkashmir.png', height: height),
      );
    } else {
      return Image.asset('assets/images/konnectkashmir.png', height: height);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs    = theme.colorScheme;

    return Scaffold(
      // ── CHANGE: scaffold bg from theme
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // ── Chinar watermark
          Positioned.fill(
            child: Center(
              child: Opacity(
                opacity: 0.18,
                child: Image.asset(
                  'assets/images/chinar.png',
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          CustomScrollView(
            slivers: [
              SliverAppBar(
                // ── CHANGE: appbar uses scaffold bg
                backgroundColor: theme.scaffoldBackgroundColor,
                elevation: 0,
                pinned: true,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back, color: cs.onSurface),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Row(
                  children: [
                    _adaptiveLogo(context, height: 40),
                  ],
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(1),
                  child: Container(
                    height: 1,
                    color: cs.outline.withOpacity(0.2),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Title
                      Text(
                        'Refund & Cancellation\nPolicy',
                        style: TextStyle(
                          // ── CHANGE: title from onSurface
                          color: cs.onSurface,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Last updated
                      Text(
                        'Last updated: February 2026',
                        style: TextStyle(
                          // ── CHANGE: accent from primary
                          color: cs.primary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Important Notice box
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          // ── CHANGE: notice box bg from surface
                          color: cs.onSurface.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cs.outline.withOpacity(0.15)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: cs.onSurface.withOpacity(0.5), size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Important Notice',
                                    style: TextStyle(
                                      color: cs.onSurface,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'This policy is published in accordance with the Consumer Protection (E-Commerce) Rules, 2020 and Consumer Protection Act, 2019.',
                                    style: TextStyle(
                                      color: cs.onSurface.withOpacity(0.6),
                                      fontSize: 13,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      _buildSectionTitle('1. Credit System Overview', cs),
                      const SizedBox(height: 12),
                      _buildBody('KonnectKashmir, a product of ',
                          bold: 'Media Mosiac (OPC) Private Limited',
                          suffix: ', uses a credit-based system for accessing vendor contact information. Credits can be obtained through:',
                          cs: cs),
                      const SizedBox(height: 12),
                      _buildBullet('Welcome Bonus:', ' 5 free credits upon registration', cs),
                      _buildBullet('Advertisements:', ' Watching ads to earn credits', cs),
                      _buildBullet('Referrals:', ' Credits earned for successful referrals', cs),
                      _buildBullet('Purchase:', ' Buying credits (when payment gateway is enabled)', cs),
                      const SizedBox(height: 28),

                      _buildSectionTitle('2. General Refund Policy', cs),
                      const SizedBox(height: 16),

                      _buildSubSectionTitle('2.1 Free Credits (Non-Refundable)', cs),
                      const SizedBox(height: 10),
                      _buildPlainBody('Credits obtained for free through any means (welcome bonus, watching ads, referrals, promotional campaigns) are ',
                          bold: 'non-refundable',
                          suffix: ' and have no monetary value.',
                          cs: cs),
                      const SizedBox(height: 20),

                      _buildSubSectionTitle('2.2 Purchased Credits', cs),
                      const SizedBox(height: 10),
                      _buildSimpleBody('When credit purchases are enabled, the following refund conditions apply:', cs),
                      const SizedBox(height: 10),
                      _buildBulletPlain('Unused purchased credits are refundable within 7 days of purchase', cs),
                      _buildBulletPlain('Partially used credit packs: Only unused portion may be refunded', cs),
                      _buildBulletPlain('Refund processing time: 5-7 business days', cs),
                      _buildBulletPlain('Refunds will be credited to the original payment method', cs),
                      const SizedBox(height: 28),

                      _buildSectionTitle('3. Conditions for Refund', cs),
                      const SizedBox(height: 10),
                      _buildSimpleBody('Refund requests will be considered in the following situations:', cs),
                      const SizedBox(height: 16),

                      _buildSubSectionTitle('3.1 Eligible for Refund', cs),
                      const SizedBox(height: 10),
                      _buildBullet('Technical Error:', ' Credits deducted but contact not revealed due to platform error', cs),
                      _buildBullet('Duplicate Charge:', ' Same vendor contact charged multiple times', cs),
                      _buildBullet('Invalid Vendor:', ' Vendor profile is fake, fraudulent, or has incorrect contact information (verified by our team)', cs),
                      _buildBullet('Service Unavailable:', ' Platform downtime prevented access to unlocked contact', cs),
                      _buildBullet('Payment Error:', ' Double payment for credit purchase', cs),
                      const SizedBox(height: 16),

                      _buildSubSectionTitle('3.2 Not Eligible for Refund', cs),
                      const SizedBox(height: 10),
                      _buildBulletPlain('Change of mind after unlocking vendor contact', cs),
                      _buildBulletPlain('Vendor not responding to inquiries (vendor behavior is outside our control)', cs),
                      _buildBulletPlain('Unsatisfactory service from the vendor (disputes are between user and vendor)', cs),
                      _buildBulletPlain('Credits earned through ads, referrals, or promotions', cs),
                      _buildBulletPlain('Account suspension due to Terms of Service violations', cs),
                      _buildBulletPlain('Expired credits (unused for 12+ months)', cs),
                      const SizedBox(height: 28),

                      _buildSectionTitle('4. Cancellation Policy', cs),
                      const SizedBox(height: 16),

                      _buildSubSectionTitle('4.1 Credit Purchase Cancellation', cs),
                      const SizedBox(height: 10),
                      _buildSimpleBody('Once a credit purchase is completed, it cannot be cancelled. However, you may request a refund as per Section 3 above.', cs),
                      const SizedBox(height: 20),

                      _buildSubSectionTitle('4.2 Account Cancellation', cs),
                      const SizedBox(height: 10),
                      _buildBulletPlain('You may delete your account at any time from account settings', cs),
                      _buildBulletPlain('Unused free credits are forfeited upon account deletion', cs),
                      _buildBulletPlain('Unused purchased credits may be refunded if requested before deletion', cs),
                      _buildBulletPlain('Unlocked vendor contacts remain accessible until account deletion', cs),
                      const SizedBox(height: 20),

                      _buildSubSectionTitle('4.3 Vendor Registration Cancellation', cs),
                      const SizedBox(height: 10),
                      _buildBulletPlain('Vendors may deactivate their listing at any time', cs),
                      _buildBulletPlain('Vendor registration is free; no refund applicable', cs),
                      _buildBulletPlain('Deactivation does not affect users who have already unlocked contact', cs),
                      const SizedBox(height: 28),

                      _buildSectionTitle('5. How to Request a Refund', cs),
                      const SizedBox(height: 10),
                      _buildSimpleBody('To request a refund:', cs),
                      const SizedBox(height: 12),
                      _buildNumbered('1.', 'Email ', boldMid: 'refund@konnectkashmir.com', suffix: ' with subject line "Refund Request"', cs: cs),
                      _buildNumbered('2.', 'Include your registered phone number', cs: cs),
                      _buildNumbered('3.', 'Describe the issue and reason for refund', cs: cs),
                      _buildNumbered('4.', 'Attach screenshots if applicable', cs: cs),
                      _buildNumbered('5.', 'Provide transaction ID (for purchased credits)', cs: cs),
                      const SizedBox(height: 14),
                      RichText(
                        text: TextSpan(
                          style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 14, height: 1.5),
                          children: [
                            const TextSpan(text: 'Requests must be submitted within '),
                            TextSpan(
                                text: '7 days',
                                style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold)),
                            const TextSpan(text: ' of the transaction.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      _buildSectionTitle('6. Refund Processing', cs),
                      const SizedBox(height: 12),
                      _buildBullet('Review Time:', ' 2-3 business days for initial review', cs),
                      _buildBullet('Approval Notification:', ' Email confirmation upon approval/rejection', cs),
                      _buildBullet('Credit Restoration:', ' Instant (for credit-based refunds)', cs),
                      _buildBullet('Monetary Refund:', ' 5-7 business days to original payment method', cs),
                      _buildBullet('Partial Refunds:', ' May be offered for partially valid claims', cs),
                      const SizedBox(height: 28),

                      _buildSectionTitle('7. Credit Restoration (Alternative to Refund)', cs),
                      const SizedBox(height: 10),
                      _buildSimpleBody('In some cases, we may offer credit restoration instead of monetary refund:', cs),
                      const SizedBox(height: 10),
                      _buildBulletPlain('Credits restored to your account immediately', cs),
                      _buildBulletPlain('Additional bonus credits may be provided as goodwill gesture', cs),
                      _buildBulletPlain('You may request monetary refund if you prefer', cs),
                      const SizedBox(height: 28),

                      _buildSectionTitle('8. Disputes', cs),
                      const SizedBox(height: 10),
                      _buildSimpleBody('If your refund request is denied and you disagree with our decision:', cs),
                      const SizedBox(height: 12),
                      _buildNumberedWithLink(
                        context: context,
                        number: '1.',
                        prefix: 'File a grievance with our ',
                        linkText: 'Grievance Officer',
                        cs: cs,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const GrievanceScreen()),
                        ),
                      ),
                      _buildNumbered('2.', 'Escalate to senior management via email', cs: cs),
                      _buildNumbered('3.', 'Approach the appropriate Consumer Disputes Redressal Forum', cs: cs),
                      const SizedBox(height: 28),

                      _buildSectionTitle('9. Important Clarifications', cs),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          // ── CHANGE: info box from surface
                          color: cs.onSurface.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cs.outline.withOpacity(0.12)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Platform vs Vendor Services:',
                              style: TextStyle(
                                color: cs.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'KonnectKashmir is an intermediary platform. Refunds from us only apply to platform services (credits, contact access). For refunds related to vendor services (work quality, payments to vendors), please contact the vendor directly. As per the Consumer Protection Act, 2019, vendors are responsible for their own refund policies.',
                              style: TextStyle(
                                color: cs.onSurface.withOpacity(0.6),
                                fontSize: 13,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      _buildSectionTitle('10. Contact Us', cs),
                      const SizedBox(height: 10),
                      _buildSimpleBody('For refund-related queries:', cs),
                      const SizedBox(height: 12),
                      _buildContactBullet('Company:', ' Media Mosiac (OPC) Private Limited', cs),
                      _buildContactBullet('Email:', ' refund@konnectkashmir.com', cs),
                      _buildContactBullet('General Support:', ' info@konnectkashmir.com', cs),
                      _buildContactBullet('Phone:', ' +91 9055566624', cs),
                      _buildContactBullet('Address:', ' 101, Iram Tower, Opp Police HQS, Karan Nagar, Srinagar 190010', cs),
                      const SizedBox(height: 28),

                      Divider(color: cs.outline.withOpacity(0.15)),
                      const SizedBox(height: 20),

                      Text(
                        'Legal Compliance',
                        style: TextStyle(color: cs.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      _buildSimpleBody('This Refund Policy is published in compliance with:', cs),
                      const SizedBox(height: 10),
                      _buildBulletPlain('Consumer Protection Act, 2019', cs),
                      _buildBulletPlain('Consumer Protection (E-Commerce) Rules, 2020', cs),
                      _buildBulletPlain('Information Technology (Intermediary Guidelines) Rules, 2021', cs),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Helpers — all now accept ColorScheme cs ──────────────────────────────

  Widget _buildSectionTitle(String text, ColorScheme cs) => Text(
    text,
    style: TextStyle(
      // ── CHANGE: section titles use primary colour
      color: cs.primary,
      fontSize: 18,
      fontWeight: FontWeight.bold,
    ),
  );

  Widget _buildSubSectionTitle(String text, ColorScheme cs) => Text(
    text,
    style: TextStyle(
      // ── CHANGE: sub-section titles use onSurface
      color: cs.onSurface,
      fontSize: 16,
      fontWeight: FontWeight.bold,
    ),
  );

  Widget _buildBody(String prefix, {String bold = '', String suffix = '', required ColorScheme cs}) =>
      RichText(
        text: TextSpan(
          style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 14, height: 1.6),
          children: [
            TextSpan(text: prefix),
            TextSpan(text: bold, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold)),
            TextSpan(text: suffix),
          ],
        ),
      );

  Widget _buildPlainBody(String prefix, {String bold = '', String suffix = '', required ColorScheme cs}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: RichText(
          text: TextSpan(
            style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 14, height: 1.6),
            children: [
              TextSpan(text: prefix),
              TextSpan(text: bold, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold)),
              TextSpan(text: suffix),
            ],
          ),
        ),
      );

  Widget _buildSimpleBody(String text, ColorScheme cs) => Text(
    text,
    style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 14, height: 1.6),
  );

  Widget _buildBullet(String label, String value, ColorScheme cs) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── CHANGE: bullet dot uses primary
        Text('• ', style: TextStyle(color: cs.primary, fontSize: 16)),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 14, height: 1.5),
              children: [
                TextSpan(text: label, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold)),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildBulletPlain(String text, ColorScheme cs) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('• ', style: TextStyle(color: cs.onSurface.withOpacity(0.4), fontSize: 16)),
        Expanded(
          child: Text(text, style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 14, height: 1.5)),
        ),
      ],
    ),
  );

  Widget _buildContactBullet(String label, String value, ColorScheme cs) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('• ', style: TextStyle(color: cs.primary, fontSize: 16)),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 14, height: 1.5),
              children: [
                TextSpan(text: label, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold)),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildNumbered(String number, String text,
      {String boldMid = '', String suffix = '', required ColorScheme cs}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              child: Text(number, style: TextStyle(color: cs.onSurface.withOpacity(0.4), fontSize: 14)),
            ),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 14, height: 1.5),
                  children: [
                    TextSpan(text: text),
                    if (boldMid.isNotEmpty)
                      TextSpan(text: boldMid, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold)),
                    if (suffix.isNotEmpty) TextSpan(text: suffix),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildNumberedWithLink({
    required BuildContext context,
    required String number,
    required String prefix,
    required String linkText,
    required VoidCallback onTap,
    required ColorScheme cs,
    String suffix = '',
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              child: Text(number, style: TextStyle(color: cs.onSurface.withOpacity(0.4), fontSize: 14)),
            ),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 14, height: 1.5),
                  children: [
                    TextSpan(text: prefix),
                    WidgetSpan(
                      child: GestureDetector(
                        onTap: onTap,
                        child: Text(
                          linkText,
                          style: TextStyle(
                            // ── CHANGE: link uses primary colour
                            color: cs.primary,
                            fontSize: 14,
                            decoration: TextDecoration.underline,
                            decorationColor: cs.primary,
                          ),
                        ),
                      ),
                    ),
                    TextSpan(text: suffix),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}