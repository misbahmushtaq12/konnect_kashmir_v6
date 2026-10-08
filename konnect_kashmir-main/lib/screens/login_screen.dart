import 'package:flutter/material.dart';
import '../widgets/english_only.dart';
import '../l10n/l10n.dart';
import 'package:konnect_kashmir/static/privacy_screen.dart';
import 'package:konnect_kashmir/static/terms_screen.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'otp_ver.dart';

/// Sign-in is always English (and left-to-right), whatever the app language is.
class LoginScreen extends StatelessWidget {
  final String? redirectMessage;

  const LoginScreen({Key? key, this.redirectMessage}) : super(key: key);

  @override
  Widget build(BuildContext context) =>
      EnglishOnly(child: _LoginBody(redirectMessage: redirectMessage));
}

class _LoginBody extends StatefulWidget {
  final String? redirectMessage;

  const _LoginBody({this.redirectMessage});

  @override
  State<_LoginBody> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<_LoginBody> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String _cleanPhone(String raw) {
    String cleaned = raw.replaceAll(RegExp(r'[\s\-]'), '');
    if (cleaned.startsWith('+91'))
      cleaned = cleaned.substring(3);
    else if (cleaned.startsWith('91') && cleaned.length == 12)
      cleaned = cleaned.substring(2);
    else if (cleaned.startsWith('0'))
      cleaned = cleaned.substring(1);
    return cleaned;
  }

  void _sendOTP() async {
    final rawPhone = _phoneController.text.trim();

    if (rawPhone.isEmpty) {
      setState(() => _error = context.l10n.errPhoneRequired);
      return;
    }

    final cleanedPhone = _cleanPhone(rawPhone);

    if (cleanedPhone.length != 10 ||
        !RegExp(r'^\d{10}$').hasMatch(cleanedPhone)) {
      setState(() => _error = context.l10n.errPhoneInvalid);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await AuthService.sendOTP(cleanedPhone);

      if (result['success'] == true) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  OTPVerificationScreen(phoneNumber: cleanedPhone),
            ),
          );
        }
      } else {
        setState(() => _error = result['error'] ?? context.l10n.errSendOtp);
      }
    } catch (e) {
      setState(() => _error = 'Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _adaptiveLogo({double height = 80}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Widget logo = Image.asset(
      'assets/images/konnectkashmir.png',
      height: height,
    );
    if (isDark) {
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          -1,
          0,
          0,
          0,
          255,
          0,
          -1,
          0,
          0,
          255,
          0,
          0,
          -1,
          0,
          255,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: logo,
      );
    }
    return logo;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Palette tailored precisely to reference design
    const Color bgDark = Color(0xFF0C1916);
    const Color cardBgDark = Color(0xFF132521);
    const Color cardBorderDark = Color(0xFF244F45);
    const Color inputBgDark = Color(0xFF10211E);
    const Color inputBorderDark = Color(0xFF2D8272);
    const Color inputDividerDark = Color(0xFF254B42);
    // Text follows the mode: white in dark mode, black in light mode.
    final Color textMuted = isDark ? Colors.white : Colors.black;
    final Color textFooterMuted = isDark ? Colors.white : Colors.black;
    const Color tealBrand = Color(0xFF339985);
    const Color iconBadgeBg = Color(0xFF1B3B34);
   // const Color bgwhite = Color(fffff);

    return Scaffold(
      backgroundColor: isDark ? bgDark : theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background fill
          Positioned.fill(
            child: Container(
              color: isDark ? bgDark : theme.scaffoldBackgroundColor,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, viewport) => SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: viewport.maxHeight,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(height: 44),
                                // 1. Top Logo - Large, prominent, centered
                                _adaptiveLogo(height: 80),
                                const SizedBox(height: 32),
                                // 3. Tagline
                                Text(
                                  context.l10n.loginTagline,
                                  style: TextStyle(
                                    fontSize: AppText.body,
                                    color: textMuted,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: 0.2,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 32),

                                // Redirect message banner if present
                                if (widget.redirectMessage != null &&
                                    widget.redirectMessage!
                                        .trim()
                                        .isNotEmpty) ...[
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 20),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: tealBrand.withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.sm,
                                      ),
                                      border: Border.all(
                                        color: tealBrand.withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.info_outline,
                                          color: tealBrand,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            widget.redirectMessage!,
                                            style: const TextStyle(
                                              color: tealBrand,
                                              fontSize: AppText.secondary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                // 4. Main Card
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 22,
                                    vertical: 26,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? cardBgDark
                                        : theme.colorScheme.surface,
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.xl,
                                    ),
                                    border: Border.all(
                                      color: isDark
                                          ? cardBorderDark
                                          : theme.colorScheme.onSurface
                                                .withValues(alpha: 0.08),
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.22,
                                        ),
                                        blurRadius: 24,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // 5. Header inside card
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? iconBadgeBg
                                                  : tealBrand.withValues(
                                                      alpha: 0.15,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppRadius.sm,
                                                  ),
                                            ),
                                            child: const Icon(
                                              Icons.lock_person_rounded,
                                              color: tealBrand,
                                              size: 22,
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Text(
                                            context.l10n.signInRegister,
                                            style: TextStyle(
                                              fontSize: AppText.heading,
                                              fontWeight: FontWeight.bold,
                                              color:isDark ? Colors.white: Colors.black,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        context.l10n.enterMobileToStart,
                                        style: TextStyle(
                                          fontSize: AppText.secondary,
                                          color: textMuted,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      Text(
                                        context.l10n.mobileNumber,
                                        style: TextStyle(
                                          fontSize: AppText.body,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 10),

                                      // 6. Mobile number field - Rectangular with moderately rounded corners
                                      Container(
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? inputBgDark
                                              : theme.colorScheme.onSurface
                                                    .withValues(alpha: 0.05),
                                          borderRadius: BorderRadius.circular(
                                            AppRadius.sm,
                                          ),
                                          border: Border.all(
                                            color: inputBorderDark,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            // Left section: Flag + Country Code
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                  ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Text(
                                                    '🇮🇳',
                                                    style: TextStyle(
                                                      fontSize: AppText.heading,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '+91',
                                                    style: TextStyle(
                                                      fontSize: AppText.body,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: isDark ? Colors.white: Colors.black,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Vertical divider
                                            Container(
                                              height: 28,
                                              width: 1.2,
                                              color: inputDividerDark,
                                            ),
                                            // Right section: Phone input
                                            Expanded(
                                              child: TextField(
                                                controller: _phoneController,
                                                keyboardType:
                                                    TextInputType.phone,
                                                style: TextStyle(
                                                  fontSize: AppText.body,
                                                  letterSpacing: 1.2,
                                                  fontWeight: FontWeight.w500,
                                                  color:  isDark ? Colors.white: Colors.black, 
                                                ),
                                                decoration:
                                                    const InputDecoration(
                                                      hintText: '98765 43210',
                                                      hintStyle: TextStyle(
                                                        color: Color(
                                                          0xFF557069,
                                                        ),
                                                        letterSpacing: 1.2,
                                                        fontSize: AppText.body,
                                                      ),
                                                      border: InputBorder.none,
                                                      enabledBorder:
                                                          InputBorder.none,
                                                      focusedBorder:
                                                          InputBorder.none,
                                                      contentPadding:
                                                          EdgeInsets.symmetric(
                                                            horizontal: 14,
                                                            vertical: 14,
                                                          ),
                                                    ),
                                                onChanged: (_) {
                                                  if (_error != null) {
                                                    setState(
                                                      () => _error = null,
                                                    );
                                                  } else
                                                    setState(() {});
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (_error != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 8,
                                          ),
                                          child: Text(
                                            _error!,
                                            style: const TextStyle(
                                              color: Color(0xFFFF6B6B),
                                              fontSize: AppText.caption,
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 24),

                                      // 7. OTP button
                                      Container(
                                        width: double.infinity,
                                        height: 54,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            AppRadius.md,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: tealBrand.withValues(
                                                alpha: 0.35,
                                              ),
                                              blurRadius: 18,
                                              offset: const Offset(0, 6),
                                            ),
                                          ],
                                        ),
                                        child: ElevatedButton(
                                          onPressed: _isLoading
                                              ? null
                                              : _sendOTP,
                                          style: AppButtons.primary,
                                          child: _isLoading
                                              ? const SizedBox(
                                                  height: 24,
                                                  width: 24,
                                                  child:
                                                      CircularProgressIndicator(
                                                        color: Colors.white,
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      context.l10n.sendVerificationOtp,
                                                      style: TextStyle(
                                                        fontSize: AppText.body,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        letterSpacing: 0.2,
                                                      ),
                                                    ),
                                                    SizedBox(width: 8),
                                                    Icon(
                                                      Icons
                                                          .arrow_forward_rounded,
                                                      size: 20,
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      ),
                                      const SizedBox(height: 18),

                                      // 8. Security text
                                      Center(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.lock_outline_rounded,
                                              size: 14,
                                              color: textFooterMuted,
                                            ),
                                            SizedBox(width: 6),
                                            Text(
                                              context.l10n.safeSecure,
                                              style: TextStyle(
                                                fontSize: AppText.caption,
                                                color: textFooterMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 32),
                              ],
                            ),
                            // 9. Terms section: part of the scroll content, so it stays at
                            // the bottom when there is room but never rides up with the keyboard.
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 8,
                                bottom: 24,
                              ),
                              child: _buildTermsText(
                                context,
                                tealBrand,
                                textFooterMuted,
                                12.0,
                              ),
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildTermsText(
    BuildContext context,
    Color tealColor,
    Color mutedColor,
    double fontSize,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.l10n.byContinuing,
          style: TextStyle(fontSize: fontSize, color: mutedColor),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TermsScreen()),
              ),
              child: Text(
                context.l10n.termsOfService,
                style: TextStyle(
                  color: tealColor,
                  decoration: TextDecoration.underline,
                  decorationColor: tealColor,
                  fontWeight: FontWeight.w600,
                  fontSize: fontSize,
                ),
              ),
            ),
            Text(
              ' ${context.l10n.andWord} ',
              style: TextStyle(color: mutedColor, fontSize: fontSize),
            ),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyScreen()),
              ),
              child: Text(
                context.l10n.privacyPolicy,
                style: TextStyle(
                  color: tealColor,
                  decoration: TextDecoration.underline,
                  decorationColor: tealColor,
                  fontWeight: FontWeight.w600,
                  fontSize: fontSize,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
