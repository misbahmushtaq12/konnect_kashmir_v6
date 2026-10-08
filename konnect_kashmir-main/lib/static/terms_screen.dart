import 'package:flutter/material.dart';
import 'legal_accordion.dart';
import '../theme/app_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:konnect_kashmir/static/privacy_screen.dart';
import 'package:konnect_kashmir/static/refund_screen.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});


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
          SafeArea(
            child: Column(
              children: [
                // ── App Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      _adaptiveLogo(context, height: 40),
                    ],
                  ),
                ),

                // ── CHANGE: divider colour from outline
                Container(
                  height: 1,
                  color: cs.outline.withOpacity(0.2),
                ),

                const SizedBox(height: 24),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back, color: cs.onSurface, size: 24),
                          const SizedBox(width: 16),
                          Text(
                            'Back to Home',
                            style: TextStyle(
                              // ── CHANGE: back button text from onSurface
                              color: cs.onSurface,
                              fontSize: AppText.heading,
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
                    child: LegalBody(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),

                        // ── Page title
                        Text(
                          'Terms of Service',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            // ── CHANGE: title from onSurface
                            color: cs.onSurface,
                          ),
                        ),

                        const SizedBox(height: 16),

                        Text(
                          'Last updated: February 2026',
                          style: TextStyle(
                            fontSize: AppText.body,
                            // ── CHANGE: date text from onSurface with opacity
                            color: cs.onSurface.withOpacity(0.5),
                          ),
                        ),

                        const SizedBox(height: 32),

                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'These Terms of Service are published in accordance with the Information Technology Act, 2000, Information Technology (Intermediary Guidelines and Digital Media Ethics Code) Rules, 2021, and Consumer Protection (E-Commerce) Rules, 2020.',
                              style: TextStyle(
                                fontSize: AppText.caption,
                                // ── CHANGE: note text from onSurface
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        _buildSectionTitle('1. Introduction and Acceptance', cs),
                        const SizedBox(height: 16),
                        _buildRichTextParagraph(
                          context,
                          'Welcome to KonnectKashmir ("Platform", "we", "us", or "our"). By accessing or using our Platform, you ("User", "you", or "your") agree to be bound by these Terms of Service, our ',
                          [
                            _LinkSpan('Privacy Policy', () {
                              Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => const PrivacyScreen()));
                            }),
                            _LinkSpan(', and ', null),
                            _LinkSpan('Refund Policy', () {
                              Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => const RefundPolicy()));
                            }),
                            _LinkSpan('.', null),
                          ],
                          cs,
                        ),
                        const SizedBox(height: 16),
                        _buildParagraph(
                          'KonnectKashmir is an intermediary platform as defined under Section 2(1)(w) of the Information Technology Act, 2000, that connects service seekers with local service providers in Kashmir.',
                          cs,
                        ),

                        const SizedBox(height: 32),
                        _buildSectionTitle('2. Eligibility', cs),
                        const SizedBox(height: 16),
                        _buildParagraph('By using the Platform, you represent and warrant that:', cs),
                        const SizedBox(height: 12),
                        _buildBulletPoint('You are at least 18 years of age', cs),
                        _buildBulletPoint('You have the legal capacity to enter into binding contracts', cs),
                        _buildBulletPoint('You are not prohibited from using the Platform under any applicable law', cs),
                        _buildBulletPoint('You will provide accurate and complete information during registration', cs),

                        const SizedBox(height: 32),
                        _buildSectionTitle('3. Nature of Platform - Intermediary Status', cs),
                        const SizedBox(height: 16),
                        _buildParagraph('Important: KonnectKashmir operates as an information intermediary under Section 2(1)(w) of the IT Act, 2000. We:', cs),
                        const SizedBox(height: 12),
                        _buildBulletPoint('Provide a platform for service seekers and service providers to connect', cs),
                        _buildBulletPoint('Do NOT employ, endorse, or guarantee any vendor listed on the Platform', cs),
                        _buildBulletPoint('Do NOT participate in or control transactions between users and vendors', cs),
                        _buildBulletPoint('Do NOT guarantee the quality, timeliness, or legality of services offered', cs),
                        _buildBulletPoint('Do NOT verify the accuracy of all information posted by users or vendors', cs),
                        const SizedBox(height: 16),
                        _buildParagraph('As per Section 79 of the IT Act and Rule 3 of IT(Intermediary Guidelines) Rules, 2021,we are not liable for third-party content or transactions on the Platform.', cs),

                        const SizedBox(height: 32),
                        _buildSectionTitle('4. User Accounts and Registration', cs),
                        const SizedBox(height: 16),
                        _buildParagraph('4.1 Account Creation:', cs),
                        const SizedBox(height: 16),
                        _buildBulletPoint('Registration requires a valid Indian mobile phone number', cs),
                        _buildBulletPoint('Account access is via OTP (One-Time Password) authentication', cs),
                        _buildBulletPoint('You are responsible for maintaining the confidentiality of your account', cs),
                        _buildBulletPoint('You must notify us immediately of any unauthorized access', cs),
                        const SizedBox(height: 16),
                        _buildParagraph('4.2 Account Termination', cs),
                        const SizedBox(height: 16),
                        _buildParagraph('We reserve the right to suspend or terminate accounts for violation of these Terms, fraudulent activity, or as required by law. You may delete your account at any time through the Platform settings.', cs),
                        const SizedBox(height: 16),

                        _buildSectionTitle('5. Credits System', cs),
                        const SizedBox(height: 16),
                        _buildParagraph('5.1 Credit Usage', cs),
                        const SizedBox(height: 16),
                        _buildBulletPoint('Credits are required to unlock vendor contact information', cs),
                        _buildBulletPoint('New Users receive 5 free credits upon registration', cs),
                        _buildBulletPoint('Additional credits can be earned by watching advertisements or referrals', cs),
                        _buildBulletPoint('Credits may be purchased (when payment gateway is enabled)', cs),
                        const SizedBox(height: 16),
                        _buildParagraph('5.2 Credit Terms', cs),
                        const SizedBox(height: 16),
                        _buildBulletPoint('Credits are non-transferable between accounts', cs),
                        _buildBulletPoint('Credits have no cash value and cannot be redeemed for money', cs),
                        _buildBulletPoint('Unused credits expire after 12 months of account inactivity', cs),
                        _buildRichTextParagraph(context, 'Refund credits is subject to our ',
                          [
                            _LinkSpan('Refund Policy', () {
                              Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => const RefundPolicy()));
                            }),
                          ],
                          cs,
                        ),

                        const SizedBox(height: 16),
                        _buildSectionTitle('6. Vendor Obligations', cs),
                        const SizedBox(height: 16),
                        _buildParagraph('Vendors registered on the Platform agree to:', cs),
                        const SizedBox(height: 16),
                        _buildBulletPoint('Provide accurate and truthful business information', cs),
                        _buildBulletPoint('Maintain valid licenses/permits as required by law for their services', cs),
                        _buildBulletPoint('Comply with all applicable laws including Consumer Protection Act, 2019', cs),
                        _buildBulletPoint('Respond professionally to customer inquiries', cs),
                        _buildBulletPoint('Not engage in misleading advertising or fraudulent practices', cs),
                        _buildBulletPoint('Keep pricing and service information up to date', cs),
                        _buildBulletPoint('Complete Aadhaar verification for "Verified" badge (optional but recommended)', cs),

                        const SizedBox(height: 32),
                        _buildSectionTitle('7. Customer Obligations', cs),
                        const SizedBox(height: 16),
                        _buildParagraph('Customers using the Platform agree to:', cs),
                        const SizedBox(height: 16),
                        _buildBulletPoint('Use vendor contact information solely for service inquiries', cs),
                        _buildBulletPoint('Not harass, spam, or misuse vendor contact details', cs),
                        _buildBulletPoint('Verify vendor credentials independently before engaging services', cs),
                        _buildBulletPoint('Not share unlocked contact information publicly', cs),
                        _buildBulletPoint('Provide honest and fair reviews based on actual experience', cs),
                        _buildBulletPoint('Report any suspicious or fraudulent vendor activity', cs),
                        const SizedBox(height: 16),

                        _buildSectionTitle('8. Prohibited Activities', cs),
                        const SizedBox(height: 16),
                        _buildParagraph('Users are prohibited from:', cs),
                        const SizedBox(height: 16),
                        _buildBulletPoint('Creating fake accounts or misrepresenting identity', cs),
                        _buildBulletPoint('Posting false, misleading, or defamatory content', cs),
                        _buildBulletPoint('Scraping, data mining, or automated collection of data', cs),
                        _buildBulletPoint('Interfering with Platform security or infrastructure', cs),
                        _buildBulletPoint('Uploading malware, viruses, or harmful code', cs),
                        _buildBulletPoint('Circumventing the credit system through any means', cs),
                        _buildBulletPoint('Using the Platform for any illegal purpose', cs),
                        _buildBulletPoint('Posting content that violates any Indian law', cs),
                        _buildBulletPoint('Harassing other users or vendors', cs),
                        const SizedBox(height: 16),

                        _buildSectionTitle('9. Reviews and Ratings', cs),
                        const SizedBox(height: 16),
                        _buildBulletPoint('Only users who have unlocked a vendor\'s contact can submit reviews', cs),
                        _buildBulletPoint('Reviews must be honest, relevant, and based on actual experience', cs),
                        _buildBulletPoint('Reviews are subject to moderation and approval', cs),
                        _buildBulletPoint('We reserve the right to remove reviews that violate guidelines', cs),
                        _buildBulletPoint('Fake or incentivized reviews are prohibited', cs),
                        const SizedBox(height: 16),

                        _buildSectionTitle('10. Intellectual Property', cs),
                        const SizedBox(height: 16),
                        _buildParagraph('All content, features, and functionality of the Platform (including but not limited to text, graphics, logos, icons, images, and software) are owned by KonnectKashmir or its licensors and are protected by Indian and international copyright, trademark, and other intellectual property laws.', cs),
                        const SizedBox(height: 16),
                        _buildParagraph('Users retain ownership of content they upload but grant us a non-exclusive, royalty-free license to use, display, and distribute such content on the Platform.', cs),
                        const SizedBox(height: 16),

                        _buildSectionTitle('11. Disclaimer of Warranties', cs),
                        const SizedBox(height: 16),
                        _buildParagraph('THE PLATFORM IS PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTIES OF ANY KIND. TO THE FULLEST EXTENT PERMITTED BY LAW:', cs),
                        const SizedBox(height: 16),
                        _buildBulletPoint('We do not warrant the accuracy, completeness, or reliability of any vendor information', cs),
                        _buildBulletPoint('We do not guarantee uninterrupted or error-free access to the Platform', cs),
                        _buildBulletPoint('We are not responsible for the quality of services provided by vendors', cs),
                        _buildBulletPoint('We are not liable for any transactions between users and vendors', cs),
                        const SizedBox(height: 16),

                        _buildSectionTitle('12. Limitation of Liability', cs),
                        const SizedBox(height: 16),
                        _buildParagraph('To the maximum extent permitted by applicable law, KonnectKashmir shall not be liable for:', cs),
                        const SizedBox(height: 16),
                        _buildBulletPoint('Any indirect, incidental, special, consequential, or punitive damages', cs),
                        _buildBulletPoint('Loss of profits, data, or business opportunities', cs),
                        _buildBulletPoint('Damages arising from vendor services or products', cs),
                        _buildBulletPoint('Unauthorized access to or alteration of your data', cs),
                        _buildBulletPoint('Any conduct of third parties on the Platform', cs),
                        const SizedBox(height: 16),
                        _buildParagraph('Our total liability shall not exceed the amount paid by you (if any) in the 12 months preceding the claim.', cs),
                        const SizedBox(height: 16),

                        _buildSectionTitle('13. Indemnification', cs),
                        const SizedBox(height: 16),
                        _buildParagraph('You agree to indemnify, defend, and hold harmless KonnectKashmir, its officers, directors, employees, and agents from any claims, damages, losses, liabilities, costs, and expenses arising from:', cs),
                        const SizedBox(height: 16),
                        _buildBulletPoint('Your violation of these Terms', cs),
                        _buildBulletPoint('Your violation of any law or rights of a third party', cs),
                        _buildBulletPoint('Any content you submit to the Platform', cs),
                        _buildBulletPoint('Your use or misuse of the Platform', cs),
                        const SizedBox(height: 16),

                        _buildSectionTitle('14. Consumer Protection', cs),
                        const SizedBox(height: 16),
                        _buildParagraph('In accordance with the Consumer Protection Act, 2019 and Consumer Protection (E-Commerce) Rules, 2020:', cs),
                        const SizedBox(height: 16),
                        _buildBulletPoint('Users have the right to seek redress for deficient services from vendors', cs),
                        _buildBulletPoint('Complaints can be filed with the appropriate Consumer Disputes Redressal Forum', cs),
                        _buildBulletPoint('We display vendor information clearly without misleading representations', cs),
                        _buildBulletPoint('Our grievance mechanism is accessible via the Grievance Portal', cs),
                        const SizedBox(height: 16),

                        _buildSectionTitle('15. Dispute Resolution', cs),
                        const SizedBox(height: 16),
                        _buildParagraph('15.1 Between Users and Vendors', cs),
                        const SizedBox(height: 16),
                        _buildParagraph('Disputes arising from services are between the user and vendor. We may assist in mediation but are not obligated to resolve such disputes.', cs),
                        const SizedBox(height: 16),
                        _buildParagraph('15.2 Between Users and Platform', cs),
                        const SizedBox(height: 16),
                        _buildParagraph('Any disputes shall first be attempted to be resolved through our Grievance Officer. If unresolved within 30 days, disputes shall be subject to:', cs),
                        const SizedBox(height: 12),
                        _buildBulletPoint('Arbitration: Under the Arbitration and Conciliation Act, 1996', cs),
                        _buildBulletPoint('Jurisdiction: Courts in Srinagar, Jammu & Kashmir', cs),
                        _buildBulletPoint('Governing Law: Laws of India', cs),
                        const SizedBox(height: 16),

                        _buildSectionTitle('16. Modification of Terms', cs),
                        const SizedBox(height: 16),
                        _buildParagraph('We reserve the right to modify these Terms at any time. Changes will be effective upon posting on the Platform. Significant changes will be notified via the Platform or SMS. Your continued use constitutes acceptance of modified Terms.', cs),
                        const SizedBox(height: 16),

                        _buildSectionTitle('17. Grievance Redressal', cs),
                        const SizedBox(height: 16),
                        _buildParagraph('In accordance with IT (Intermediary Guidelines) Rules, 2021, we have appointed a Grievance Officer:', cs),
                        const SizedBox(height: 16),
                        _buildBulletPoint('Email: grievance@konnectkashmir.com', cs),
                        _buildBulletPoint('Response Time: Acknowledgment within 24 hours', cs),
                        _buildBulletPoint('Resolution Time: Within 15 days (or 72 hours for content-related complaints)', cs),
                        _buildBulletPoint('Portal: Submit Grievance', cs),
                        const SizedBox(height: 16),

                        _buildSectionTitle('18. Severability', cs),
                        const SizedBox(height: 16),
                        _buildParagraph('If any provision of these Terms is found to be invalid or unenforceable, the remaining provisions shall continue in full force and effect.', cs),
                        const SizedBox(height: 16),

                        _buildSectionTitle('19. Contact Information', cs),
                        const SizedBox(height: 16),
                        _buildParagraph('For questions about these Terms of Service:', cs),
                        const SizedBox(height: 16),
                        _buildBulletPoint('Company: Media Mosiac (OPC) Private Limited', cs),
                        _buildBulletPoint('Email: info@konnectkashmir.com', cs),
                        _buildBulletPoint('Phone: +91 9055566624', cs),
                        _buildBulletPoint('Address: 101, Iram Tower, Opp Police HQS, Karan Nagar, Srinagar 190010', cs),
                        const SizedBox(height: 16),

                        _buildSectionTitle('Applicable Laws', cs),
                        const SizedBox(height: 16),
                        _buildParagraph('These Terms are governed by:', cs),
                        const SizedBox(height: 16),
                        _buildBulletPoint('Information Technology Act, 2000', cs),
                        _buildBulletPoint('IT (Intermediary Guidelines and Digital Media Ethics Code) Rules, 2021', cs),
                        _buildBulletPoint('Consumer Protection Act, 2019', cs),
                        _buildBulletPoint('Consumer Protection (E-Commerce) Rules, 2020', cs),
                        _buildBulletPoint('Indian Contract Act, 1872', cs),
                        _buildBulletPoint('Arbitration and Conciliation Act, 1996', cs),

                        const SizedBox(height: 40),
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

  // ── Helpers — all now accept ColorScheme cs ──────────────────────────────

  Widget _buildSectionTitle(String title, ColorScheme cs) =>
      LegalSectionTitle(title);

  Widget _buildParagraph(String text, ColorScheme cs) => Text(
    text,
    style: TextStyle(
      fontSize: AppText.body,
      // ── CHANGE: paragraph text from onSurface
      color: cs.onSurface,
      height: 1.6,
    ),
  );

  Widget _buildRichTextParagraph(
      BuildContext context,
      String normalText,
      List<_LinkSpan> spans,
      ColorScheme cs,
      ) {
    final List<TextSpan> textSpans = [
      TextSpan(
        text: normalText,
        style: TextStyle(fontSize: AppText.body, color: cs.onSurface, height: 1.6),
      ),
    ];

    for (final span in spans) {
      textSpans.add(
        TextSpan(
          text: span.text,
          style: TextStyle(
            fontSize: AppText.body,
            // ── CHANGE: links use primary, plain text uses onSurface
            color: span.onTap != null ? cs.primary : cs.onSurface,
            height: 1.6,
            decoration: span.onTap != null ? TextDecoration.underline : null,
            decorationColor: span.onTap != null ? cs.primary : null,
          ),
          recognizer: span.onTap != null
              ? (TapGestureRecognizer()..onTap = span.onTap)
              : null,
        ),
      );
    }

    return RichText(text: TextSpan(children: textSpans));
  }

  Widget _buildBulletPoint(String text, ColorScheme cs) => Padding(
    padding: const EdgeInsets.only(left: 16, bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 8),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            // ── CHANGE: bullet dot uses primary colour
            color: cs.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: AppText.body, color: cs.onSurface, height: 1.6),
          ),
        ),
      ],
    ),
  );
}

class _LinkSpan {
  final String text;
  final VoidCallback? onTap;
  _LinkSpan(this.text, this.onTap);
}