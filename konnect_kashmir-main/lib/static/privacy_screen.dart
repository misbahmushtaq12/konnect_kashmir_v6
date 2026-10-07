import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:konnect_kashmir/static/privacy_screen.dart';
import 'package:konnect_kashmir/static/refund_screen.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

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
    final cs = theme.colorScheme;

    final strongText = cs.onSurface;
    final subtleText = cs.onSurface.withOpacity(0.7);
    final teal = cs.primary;
    final dividerColor = cs.onSurface.withOpacity(0.15);
    final bulletColor = teal;

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // ── Logo bar ──────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      _adaptiveLogo(context, height: 40),
                    ],
                  ),
                ),

                Divider(color: dividerColor, height: 1, thickness: 1),
                const SizedBox(height: 24),

                // ── Back button ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back,
                              color: strongText, size: 24),
                          const SizedBox(width: 16),
                          Text(
                            'Back to Home',
                            style: TextStyle(
                              color: strongText,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),

                        Text(
                          'Privacy Policy',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: strongText,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Last updated: February 2026',
                          style: TextStyle(
                              fontSize: 14,
                              color: cs.onSurface.withOpacity(0.45)),
                        ),
                        const SizedBox(height: 32),

                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'This Privacy Policy is published in accordance with the Digital Personal Data Protection Act, 2023 (DPDP Act), Information Technology Act, 2000, and Information Technology (Reasonable Security Practices and Procedures and Sensitive Personal Data or Information) Rules, 2011.',
                              style: TextStyle(
                                  fontSize: 12, color: subtleText),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        _sectionTitle('1. Data Fiduciary Information', strongText),
                        const SizedBox(height: 16),
                        _paragraph(
                          'Media Mosiac (OPC) Private Limited, operating the platform "KonnectKashmir" (hereinafter referred to as "we", "us", "our", or "Platform"), acts as a Data Fiduciary under the DPDP Act, 2023. Our contact details are:',
                          subtleText,
                        ),
                        const SizedBox(height: 16),
                        _bullet('Legal Entity: Media Mosiac (OPC) Private Limited', subtleText, bulletColor),
                        _bullet('Platform Name: KonnectKashmir', subtleText, bulletColor),
                        _bullet('Registered Address: 101, Iram Tower, Opp Police HQS, Karan Nagar, Srinagar, J&K 190010', subtleText, bulletColor),
                        _bullet('Email: info@konnectkashmir.com', subtleText, bulletColor),
                        _bullet('Phone: +91 9055566624', subtleText, bulletColor),

                        const SizedBox(height: 16),
                        _sectionTitle('2. Personal Data We Collect', strongText),
                        const SizedBox(height: 16),
                        _paragraph('We collect and process the following categories of personal data:', subtleText),
                        const SizedBox(height: 16),
                        _paragraph('2.1 Data Provided by You:', subtleText),
                        const SizedBox(height: 12),
                        _bullet('Mobile phone number (for OTP-based authentication)', subtleText, bulletColor),
                        _bullet('Full name (optional, for profile)', subtleText, bulletColor),
                        _bullet('Aadhaar last 4 digits (for vendor verification only, with consent)', subtleText, bulletColor),
                        _bullet('Business information (for vendors: business name, address, services, working hours)', subtleText, bulletColor),
                        _bullet('Profile photo (optional)', subtleText, bulletColor),

                        const SizedBox(height: 24),
                        _paragraph('2.2 Data Collected Automatically:', subtleText),
                        const SizedBox(height: 12),
                        _bullet('Device information (browser type, operating system)', subtleText, bulletColor),
                        _bullet('IP address and approximate location', subtleText, bulletColor),
                        _bullet('Usage data (pages visited, features used, time spent)', subtleText, bulletColor),
                        _bullet('Cookies and similar tracking technologies', subtleText, bulletColor),

                        const SizedBox(height: 16),
                        _sectionTitle('3. Purpose of Data Processing', strongText),
                        const SizedBox(height: 16),
                        _paragraph('Under Section 4 of the DPDP Act, we process your data for the following lawful purposes:', subtleText),
                        const SizedBox(height: 16),
                        _bullet('Account Creation: To register and authenticate your account', subtleText, bulletColor),
                        _bullet('Service Delivery: To connect customers with service providers', subtleText, bulletColor),
                        _bullet('Credit System: To manage credits for unlocking vendor contacts', subtleText, bulletColor),
                        _bullet('Communication: To send OTPs, notifications, and service updates', subtleText, bulletColor),
                        _bullet('Vendor Verification: To verify vendor identity (with explicit consent)', subtleText, bulletColor),
                        _bullet('Platform Improvement: To analyze usage and improve our services', subtleText, bulletColor),
                        _bullet('Legal Compliance: To comply with applicable laws and regulations', subtleText, bulletColor),
                        _bullet('Dispute Resolution: To address complaints and resolve disputes', subtleText, bulletColor),

                        const SizedBox(height: 16),
                        _sectionTitle('4. Consent and Legal Basis', strongText),
                        const SizedBox(height: 16),
                        _paragraph('In accordance with Section 6 of the DPDP Act, we obtain your consent before processing personal data. You provide consent by:', subtleText),
                        const SizedBox(height: 16),
                        _bullet('Registering on the Platform (implied consent for core services)', subtleText, bulletColor),
                        _bullet('Opting in for Aadhaar verification (explicit consent)', subtleText, bulletColor),
                        _bullet('Accepting Terms of Service and this Privacy Policy', subtleText, bulletColor),
                        const SizedBox(height: 16),
                        _paragraph('You may withdraw consent at any time by contacting us. However, withdrawal may limit your ability to use certain features of the Platform.', subtleText),

                        const SizedBox(height: 16),
                        _sectionTitle('5. Data Retention', strongText),
                        const SizedBox(height: 16),
                        _paragraph('We retain your personal data as follows:', subtleText),
                        const SizedBox(height: 16),
                        _bullet('Account Data: Until you delete your account or 3 years of inactivity', subtleText, bulletColor),
                        _bullet('Transaction Records: 8 years (as per Income Tax Act requirements)', subtleText, bulletColor),
                        _bullet('OTP Data: Automatically deleted within 10 minutes of generation', subtleText, bulletColor),
                        _bullet('Vendor Data: Until vendor requests deletion or 3 years after deactivation', subtleText, bulletColor),
                        _bullet('Analytics Data: Anonymized after 12 months', subtleText, bulletColor),

                        const SizedBox(height: 16),
                        _sectionTitle('6. Your Rights Under DPDP Act', strongText),
                        const SizedBox(height: 16),
                        _paragraph('As a Data Principal under the DPDP Act, 2023, you have the following rights:', subtleText),
                        const SizedBox(height: 16),
                        _bullet('Right to Access: Request a summary of your personal data and processing activities', subtleText, bulletColor),
                        _bullet('Right to Correction: Request correction of inaccurate or incomplete data', subtleText, bulletColor),
                        _bullet('Right to Erasure: Request deletion of your personal data (subject to legal requirements)', subtleText, bulletColor),
                        _bullet('Right to Grievance Redressal: File complaints with our Grievance Officer', subtleText, bulletColor),
                        _bullet('Right to Nominate: Nominate another person to exercise your rights', subtleText, bulletColor),
                        const SizedBox(height: 16),
                        _paragraph('To exercise these rights, contact our Data Protection Officer at dpo@konnectkashmir.com or visit our Grievance Redressal page.', subtleText),

                        const SizedBox(height: 16),
                        _sectionTitle('7. Vendor Contact Information Protection', strongText),
                        const SizedBox(height: 16),
                        _paragraph('Vendor contact details (phone numbers, email, WhatsApp) are classified as sensitive business information and are protected through:', subtleText),
                        const SizedBox(height: 16),
                        _bullet('Credit-based access system (users must spend credits to reveal contacts)', subtleText, bulletColor),
                        _bullet('Row-level security at the database level', subtleText, bulletColor),
                        _bullet('Masking in public views until explicitly unlocked', subtleText, bulletColor),
                        _bullet('Audit trail of all contact unlock events', subtleText, bulletColor),

                        const SizedBox(height: 16),
                        _sectionTitle('8. Data Sharing and Disclosure', strongText),
                        const SizedBox(height: 16),
                        _paragraph('We do not sell or rent your personal data. We may share data only:', subtleText),
                        const SizedBox(height: 16),
                        _bullet('With Your Consent: When you explicitly authorize sharing', subtleText, bulletColor),
                        _bullet('Service Providers: With vendors who assist in platform operations (under confidentiality agreements)', subtleText, bulletColor),
                        _bullet('Legal Requirements: When required by law, court order, or government authority', subtleText, bulletColor),
                        _bullet('Safety: To protect rights, property, or safety of users or the public', subtleText, bulletColor),
                        const SizedBox(height: 16),
                        _paragraph('We do not transfer personal data outside India except where permitted under the DPDP Act and approved by the Central Government.', subtleText),

                        const SizedBox(height: 16),
                        _sectionTitle('9. Data Security Measures', strongText),
                        const SizedBox(height: 16),
                        _paragraph('As per Section 8 of the DPDP Act and IT (Reasonable Security Practices) Rules, 2011, we implement the following security measures:', subtleText),
                        const SizedBox(height: 16),
                        _bullet('SSL/TLS encryption for all data transmissions', subtleText, bulletColor),
                        _bullet('Encrypted storage of sensitive data', subtleText, bulletColor),
                        _bullet('Row-level security policies in our database', subtleText, bulletColor),
                        _bullet('Regular security audits and vulnerability assessments', subtleText, bulletColor),
                        _bullet('Access controls and authentication mechanisms', subtleText, bulletColor),
                        _bullet('Secure OTP-based authentication (no password storage)', subtleText, bulletColor),

                        const SizedBox(height: 16),
                        _sectionTitle('10. Cookies Policy', strongText),
                        const SizedBox(height: 16),
                        _paragraph('We use cookies and similar technologies to:', subtleText),
                        const SizedBox(height: 16),
                        _bullet('Essential Cookies: Required for authentication and security', subtleText, bulletColor),
                        _bullet('Functional Cookies: Remember your preferences and language settings', subtleText, bulletColor),
                        _bullet('Analytics Cookies: Understand usage patterns and improve services', subtleText, bulletColor),
                        const SizedBox(height: 16),
                        _paragraph('You can control cookies through your browser settings. Disabling essential cookies may affect platform functionality.', subtleText),

                        const SizedBox(height: 16),
                        _sectionTitle('11. Children\'s Privacy', strongText),
                        const SizedBox(height: 16),
                        _paragraph('Our Platform is not intended for users under 18 years of age. We do not knowingly collect personal data from children. If we become aware of such collection, we will delete the data immediately. Parents or guardians who believe their child has provided data should contact us.', subtleText),

                        const SizedBox(height: 16),
                        _sectionTitle('12. Changes to Privacy Policy', strongText),
                        const SizedBox(height: 16),
                        _paragraph('We may update this Privacy Policy periodically. Significant changes will be notified through the Platform or via SMS. Continued use after changes constitutes acceptance of the updated policy.', subtleText),

                        const SizedBox(height: 16),
                        _sectionTitle('13. Grievance Redressal', strongText),
                        const SizedBox(height: 16),
                        _paragraph('In compliance with the IT (Intermediary Guidelines) Rules, 2021, we have appointed a Grievance Officer. For any privacy-related concerns:', subtleText),
                        const SizedBox(height: 16),
                        _bullet('Grievance Officer: Mr. [To be appointed]', subtleText, bulletColor),
                        _bullet('Email: grievance@konnectkashmir.com', subtleText, bulletColor),
                        _bullet('Response Time: Within 24 hours acknowledgment, 15 days resolution', subtleText, bulletColor),
                        const SizedBox(height: 16),
                        _paragraph('If unsatisfied with our response, you may file a complaint with the Data Protection Board of India under Section 28 of the DPDP Act, 2023.', subtleText),

                        const SizedBox(height: 16),
                        _sectionTitle('14. Contact Us', strongText),
                        const SizedBox(height: 16),
                        _paragraph('For any privacy-related questions or to exercise your rights:', subtleText),
                        const SizedBox(height: 16),
                        _bullet('Company: Media Mosiac (OPC) Private Limited', subtleText, bulletColor),
                        _bullet('Email: info@konnectkashmir.com', subtleText, bulletColor),
                        _bullet('Phone: +91 9055566624', subtleText, bulletColor),
                        _bullet('Address: 101, Iram Tower, Opp Police HQS, Karan Nagar, Srinagar 190010', subtleText, bulletColor),
                        _bullet('Grievance Portal: Submit Grievance', subtleText, bulletColor),

                        const SizedBox(height: 16),
                        _sectionTitle('Applicable Laws', strongText),
                        const SizedBox(height: 16),
                        _paragraph('This Privacy Policy is governed by and shall be construed in accordance with the laws of India, including but not limited to:', subtleText),
                        const SizedBox(height: 16),
                        _bullet('Digital Personal Data Protection Act, 2023', subtleText, bulletColor),
                        _bullet('Information Technology Act, 2000', subtleText, bulletColor),
                        _bullet('IT (Reasonable Security Practices and Procedures and Sensitive Personal Data or Information) Rules, 2011', subtleText, bulletColor),
                        _bullet('IT (Intermediary Guidelines and Digital Media Ethics Code) Rules, 2021', subtleText, bulletColor),

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

  static Widget _sectionTitle(String title, Color color) {
    return Text(
      title,
      style: TextStyle(
          fontSize: 22, fontWeight: FontWeight.bold, color: color),
    );
  }

  static Widget _paragraph(String text, Color color) {
    return Text(
      text,
      style: TextStyle(fontSize: 15, color: color, height: 1.6),
    );
  }

  static Widget _bullet(String text, Color textColor, Color dotColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
                color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style:
              TextStyle(fontSize: 15, color: textColor, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}