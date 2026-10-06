import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

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
    // ── Theme helpers ────────────────────────────────────────────────────
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final size = MediaQuery.of(context).size;
    final strongText = cs.onSurface;
    final subtleText = cs.onSurface.withOpacity(0.55);
    final teal = cs.primary;
    final dividerColor = cs.onSurface.withOpacity(0.15);
    final cardBorder = cs.onSurface.withOpacity(0.1);
    final chinarOpacity = isDark ? 0.18 : 0.07;

    return Scaffold(
      body: Stack(
        children: [
          // ── Chinar watermark ─────────────────────────────────────────
          Positioned.fill(
            child: Center(
              child: Opacity(
                opacity: chinarOpacity,
                child: Image.asset(
                  'assets/images/chinar.png',
                  width: size.width,
                  height: size.height,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Logo bar ───────────────────────────────────────────
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

                // ── Back button ────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back, color: strongText, size: 24),
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
                          'Contact Us',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: strongText,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'We\'re here to help. Reach out to us anytime!',
                          style: TextStyle(fontSize: 16, color: subtleText),
                        ),
                        const SizedBox(height: 40),

                        _buildContactCard(
                          icon: Icons.location_on,
                          title: 'Our Office',
                          content:
                          '101, Iram Tower, Opp Police HQS,\nKaran Nagar, Srinagar 190010',
                          teal: teal,
                          strongText: strongText,
                          cardBorder: cardBorder,
                          onTap: () => _openMap(),
                        ),
                        const SizedBox(height: 16),
                        _buildContactCard(
                          icon: Icons.email_outlined,
                          title: 'Email',
                          content: 'info@konnectkashmir.com',
                          teal: teal,
                          strongText: strongText,
                          cardBorder: cardBorder,
                          onTap: () =>
                              _sendEmail('info@konnectkashmir.com'),
                        ),
                        const SizedBox(height: 16),
                        _buildContactCard(
                          icon: Icons.phone_outlined,
                          title: 'Call Us',
                          content: '+91 9055566624',
                          teal: teal,
                          strongText: strongText,
                          cardBorder: cardBorder,
                          onTap: () => _makeCall('+919055566624'),
                        ),
                        const SizedBox(height: 16),
                        _buildContactCard(
                          icon: Icons.chat_bubble_outline,
                          title: 'WhatsApp',
                          content: 'Chat with us on WhatsApp',
                          teal: teal,
                          strongText: strongText,
                          cardBorder: cardBorder,
                          onTap: () => _openWhatsApp('+919055566624'),
                        ),
                        const SizedBox(height: 16),
                        _buildBusinessHoursCard(
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
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: teal, size: 28),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: strongText,
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onTap,
                  child: Text(
                    content,
                    style: TextStyle(
                        fontSize: 15, color: teal, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessHoursCard({
    required Color strongText,
    required Color subtleText,
    required Color cardBorder,
    required Color rowBg,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Business Hours',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: strongText,
            ),
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
                    Text('Monday - Saturday',
                        style: TextStyle(
                            fontSize: 15,
                            color: subtleText,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 12),
                    Text('Sunday',
                        style: TextStyle(
                            fontSize: 15,
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
                            fontSize: 11,
                            color: subtleText,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Text('Closed',
                        style: TextStyle(
                            fontSize: 15,
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