import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'privacy_screen.dart';
import 'terms_screen.dart';

class GrievanceScreen extends StatelessWidget {
  const GrievanceScreen({super.key});

  // ── Theme-adaptive logo ───────────────────────────────────────────────────
  // Asset is a BLACK logo on transparent background.
  // Light mode → show as-is (black logo on light bg) ✅
  // Dark mode  → invert to white (white logo on dark bg) ✅
  static Widget _adaptiveLogo(BuildContext context, {double height = 60}) {
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

  Future<void> _launchEmail(String email) async {
    final Uri uri = Uri(scheme: 'mailto', path: email);
    await launchUrl(uri);
  }

  Future<void> _launchPhone(String phone) async {
    final Uri uri = Uri(scheme: 'tel', path: phone);
    await launchUrl(uri);
  }

  Future<void> _launchWebsite(String url) async {
    final Uri uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // ── Themed helper widgets ────────────────────────────────────────────────

  Widget _card({required Widget child, required Color borderColor}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }

  Widget _bullet(String text, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("• ", style: TextStyle(color: textColor, fontSize: 15)),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: textColor, fontSize: 15, height: 1.6)),
          ),
        ],
      ),
    );
  }

  Widget _timelineRow(
      String left, String right, Color textColor, Color valueColor,
      Color rowBg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
              child: Text(left,
                  style: TextStyle(color: textColor, fontSize: 15))),
          Text(right,
              style: TextStyle(
                  color: valueColor, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _numbered(String text, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 28, bottom: 10),
      child: Text(text,
          style:
          TextStyle(color: textColor, fontSize: 15, height: 1.6)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ── Theme helpers ──────────────────────────────────────────────────
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final strongText = cs.onSurface;
    final subtleText = cs.onSurface.withOpacity(0.6);
    final faintText = cs.onSurface.withOpacity(0.4);
    final teal = cs.primary;
    final borderColor = cs.onSurface.withOpacity(0.15);
    final dividerColor = cs.onSurface.withOpacity(0.15);
    final rowBg = cs.onSurface.withOpacity(isDark ? 0.08 : 0.04);

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // ── Logo bar ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      _adaptiveLogo(context, height: 60),
                    ],
                  ),
                ),

                Divider(color: dividerColor, height: 1, thickness: 1),
                const SizedBox(height: 24),

                // ── Back button ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Row(
                      children: [
                        Icon(Icons.arrow_back,
                            color: strongText),
                        const SizedBox(width: 12),
                        Text(
                          "Back to Home",
                          style: TextStyle(
                              color: strongText,
                              fontSize: 18,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
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
                          "Grievance Redressal",
                          style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: strongText),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "As per the Information Technology (Intermediary Guidelines and Digital Media Ethics Code) Rules, 2021, we have established a grievance redressal mechanism for users.",
                          style: TextStyle(color: subtleText, height: 1.6),
                        ),
                        const SizedBox(height: 24),

                        // Pre-read note
                        _card(
                          borderColor: borderColor,
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                  color: subtleText,
                                  fontSize: 15,
                                  height: 1.6),
                              children: [
                                const TextSpan(
                                    text:
                                    "Before filing a grievance, please review our "),
                                TextSpan(
                                    text: "Terms of Service",
                                    style: TextStyle(
                                        color: teal,
                                        decoration:
                                        TextDecoration.underline,
                                        decorationColor: teal),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                const TermsScreen()));
                                      }),
                                const TextSpan(text: " and "),
                                TextSpan(
                                    text: "Privacy Policy",
                                    style: TextStyle(
                                        color: teal,
                                        decoration:
                                        TextDecoration.underline,
                                        decorationColor: teal),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                const PrivacyScreen()));
                                      }),
                                const TextSpan(text: "."),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Grievance Officer
                        _card(
                          borderColor: borderColor,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Grievance Officer",
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: strongText)),
                              const SizedBox(height: 16),
                              Text(
                                "In accordance with Rule 3(2) of the IT (Intermediary Guidelines) Rules, 2021, we have appointed the following Grievance Officer:",
                                style: TextStyle(
                                    color: subtleText, height: 1.6),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Icon(Icons.email, color: teal),
                                  const SizedBox(width: 12),
                                  GestureDetector(
                                    onTap: () => _launchEmail(
                                        "grievance@konnectkashmir.com"),
                                    child: Text(
                                      "grievance@konnectkashmir.com",
                                      style: TextStyle(
                                          color: teal,
                                          decoration:
                                          TextDecoration.underline,
                                          decorationColor: teal),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Icon(Icons.phone, color: teal),
                                  const SizedBox(width: 12),
                                  GestureDetector(
                                    onTap: () =>
                                        _launchPhone("+919055566624"),
                                    child: Text(
                                      "+91 9055566624",
                                      style: TextStyle(
                                          color: teal,
                                          decoration:
                                          TextDecoration.underline,
                                          decorationColor: teal),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Response Timeline
                        _card(
                          borderColor: borderColor,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Response Timeline",
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: strongText)),
                              const SizedBox(height: 20),
                              _timelineRow("Acknowledgment",
                                  "Within 24 hours", subtleText, teal, rowBg),
                              _timelineRow(
                                  "Content-related complaints",
                                  "Within 72 hours",
                                  subtleText,
                                  teal,
                                  rowBg),
                              _timelineRow(
                                  "General grievances resolution",
                                  "Within 15 days",
                                  subtleText,
                                  teal,
                                  rowBg),
                              _timelineRow("Appeal (if unsatisfied)",
                                  "Within 30 days", subtleText, teal, rowBg),
                            ],
                          ),
                        ),

                        const SizedBox(height: 40),

                        Text("Types of Grievances We Handle",
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: strongText)),
                        const SizedBox(height: 20),

                        _card(
                          borderColor: borderColor,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Platform-Related Issues",
                                  style: TextStyle(
                                      color: strongText,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              _bullet("Account access problems", subtleText),
                              _bullet("Credit disputes", subtleText),
                              _bullet("Technical issues", subtleText),
                              _bullet("Feature requests", subtleText),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _card(
                          borderColor: borderColor,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Content-Related Issues",
                                  style: TextStyle(
                                      color: strongText,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              _bullet("Fake/misleading vendor profiles",
                                  subtleText),
                              _bullet("Defamatory reviews", subtleText),
                              _bullet("Copyright infringement", subtleText),
                              _bullet("Inappropriate content", subtleText),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _card(
                          borderColor: borderColor,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Privacy Concerns",
                                  style: TextStyle(
                                      color: strongText,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              _bullet("Data access requests", subtleText),
                              _bullet("Data correction requests", subtleText),
                              _bullet("Data deletion requests", subtleText),
                              _bullet("Consent withdrawal", subtleText),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _card(
                          borderColor: borderColor,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Vendor/User Complaints",
                                  style: TextStyle(
                                      color: strongText,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              _bullet("Fraudulent vendors", subtleText),
                              _bullet("Harassment by users", subtleText),
                              _bullet(
                                  "Misuse of contact information", subtleText),
                              _bullet("Fake reviews", subtleText),
                            ],
                          ),
                        ),

                        const SizedBox(height: 40),

                        Text("How to File a Grievance",
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: strongText)),
                        const SizedBox(height: 16),

                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                                color: subtleText,
                                fontSize: 15,
                                height: 1.6),
                            children: [
                              const TextSpan(
                                  text:
                                  "To file a grievance, please email us at "),
                              TextSpan(
                                text: "grievance@konnectkashmir.com",
                                style: TextStyle(
                                    color: teal,
                                    decoration: TextDecoration.underline,
                                    decorationColor: teal),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => _launchEmail(
                                      "grievance@konnectkashmir.com"),
                              ),
                              const TextSpan(
                                  text: " with the following details:"),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        _numbered("1. Your registered phone number", subtleText),
                        _numbered(
                            "2. Detailed description of the grievance",
                            subtleText),
                        _numbered(
                            "3. Date and time of the incident", subtleText),
                        _numbered(
                            "4. Screenshots or supporting documents",
                            subtleText),
                        _numbered(
                            "5. Vendor ID or profile link", subtleText),
                        _numbered(
                            "6. Your preferred resolution", subtleText),

                        const SizedBox(height: 32),

                        Text("Escalation Process",
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: strongText)),
                        const SizedBox(height: 12),
                        Text(
                          "If you are not satisfied with our response, you may:",
                          style:
                          TextStyle(color: subtleText, height: 1.6),
                        ),
                        const SizedBox(height: 16),

                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                                color: subtleText,
                                fontSize: 15,
                                height: 1.6),
                            children: [
                              const TextSpan(
                                  text:
                                  "1. Appeal to Senior Management: Email "),
                              TextSpan(
                                text: "info@konnectkashmir.com",
                                style: TextStyle(
                                    color: teal,
                                    decoration: TextDecoration.underline,
                                    decorationColor: teal),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => _launchEmail(
                                      "info@konnectkashmir.com"),
                              ),
                              const TextSpan(
                                  text:
                                  " within 30 days of resolution."),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "2. Consumer Forum: File a complaint under the Consumer Protection Act, 2019.",
                          style:
                          TextStyle(color: subtleText, height: 1.6),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "3. Data Protection Board: For privacy related grievances under DPDP Act, 2023, you may approach the Data Protection Board of India.",
                          style:
                          TextStyle(color: subtleText, height: 1.6),
                        ),
                        const SizedBox(height: 12),

                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                                color: subtleText,
                                fontSize: 15,
                                height: 1.6),
                            children: [
                              const TextSpan(
                                  text: "4. Cyber Crime Portal: Report at "),
                              TextSpan(
                                text: "cybercrime.gov.in",
                                style: TextStyle(
                                    color: teal,
                                    decoration: TextDecoration.underline,
                                    decorationColor: teal),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => _launchWebsite(
                                      "https://cybercrime.gov.in"),
                              ),
                              const TextSpan(text: "."),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        _card(
                          borderColor: borderColor,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Office Address",
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: strongText)),
                              const SizedBox(height: 16),
                              Text(
                                "Media Mosiac (OPC) Private Limited\nOperating as KonnectKashmir\n\n101, Iram Tower, Opp Police HQS\nKaran Nagar, Srinagar\nJammu & Kashmir - 190010\nIndia",
                                style: TextStyle(
                                    color: subtleText, height: 1.6),
                              ),
                              const SizedBox(height: 16),
                              Divider(color: dividerColor),
                              const SizedBox(height: 12),
                              Text(
                                "Business Hours: Monday - Saturday, 9:00 AM - 6:00 PM IST",
                                style: TextStyle(
                                    color: subtleText, height: 1.6),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        Text(
                          "This grievance mechanism is established in compliance with Rule 3(2) of the Information Technology (Intermediary Guidelines and Digital Media Ethics Code) Rules, 2021.",
                          style:
                          TextStyle(color: faintText, height: 1.6),
                        ),

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
}