import 'package:flutter/material.dart';
import 'package:konnect_kashmir/static/terms_screen.dart';
import 'package:konnect_kashmir/static/privacy_screen.dart';
import '../services/auth_service.dart';
import 'otp_ver.dart';

class LoginScreen extends StatefulWidget {
  final String? redirectMessage;

  const LoginScreen({Key? key, this.redirectMessage}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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
    if (cleaned.startsWith('+91')) cleaned = cleaned.substring(3);
    else if (cleaned.startsWith('91') && cleaned.length == 12) cleaned = cleaned.substring(2);
    else if (cleaned.startsWith('0')) cleaned = cleaned.substring(1);
    return cleaned;
  }

  void _sendOTP() async {
    final rawPhone = _phoneController.text.trim();

    if (rawPhone.isEmpty) {
      setState(() => _error = 'Please enter a phone number');
      return;
    }

    final cleanedPhone = _cleanPhone(rawPhone);

    if (cleanedPhone.length != 10 || !RegExp(r'^\d{10}$').hasMatch(cleanedPhone)) {
      setState(() => _error = 'Enter a valid 10-digit Indian mobile number');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await AuthService.sendOTP(cleanedPhone);

      if (result['success'] == true) {
        if (result['autoVerified'] == true) {
          final authResult = await AuthService.authenticateWithBackend(
              result['accessToken'] as String);
          if (mounted) {
            if (authResult['success'] == true) {
              Navigator.pushNamedAndRemoveUntil(
                  context, '/home', (route) => false);
            } else {
              setState(() => _error = authResult['error'] ?? 'Auth failed');
            }
          }
          return;
        }

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
        setState(() => _error = result['error'] ?? 'Failed to send OTP');
      }
    } catch (e) {
      setState(() => _error = 'Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size   = MediaQuery.of(context).size;
    final theme  = Theme.of(context);
    final cs     = theme.colorScheme;

    // ── Responsive breakpoints ─────────────────────────────────────────────
    final double screenWidth  = size.width;
    final double screenHeight = size.height;

    final bool isSmall  = screenWidth < 360;
    final bool isMedium = screenWidth >= 360 && screenWidth < 480;

    final double horizontalPadding = isSmall ? 16.0 : (isMedium ? 24.0 : 32.0);
    final double topSpacing        = screenHeight < 700 ? 32.0 : 60.0;
    final double logoIconSize      = isSmall ? 20.0 : 24.0;
    final double logoIconPad       = isSmall ? 8.0  : 10.0;
    final double logoFontSize      = isSmall ? 20.0 : (isMedium ? 23.0 : 26.0);
    final double subtitleFontSize  = isSmall ? 13.0 : 15.0;
    final double sectionSpacing    = screenHeight < 700 ? 28.0 : 48.0;
    final double labelFontSize     = isSmall ? 13.0 : 15.0;
    final double inputFontSize     = isSmall ? 14.0 : 16.0;
    final double prefixPadH        = isSmall ? 12.0 : 16.0;
    final double prefixPadV        = isSmall ? 15.0 : 18.0;
    final double buttonVertPad     = isSmall ? 13.0 : 16.0;
    final double buttonFontSize    = isSmall ? 14.0 : 16.0;
    final double hintFontSize      = isSmall ? 11.0 : 13.0;
    final double termsFontSize     = isSmall ? 11.0 : 13.0;
    final double bannerFontSize    = isSmall ? 12.0 : 13.0;
    final double bannerIconSize    = isSmall ? 16.0 : 18.0;
    final double bannerPad         = isSmall ? 10.0 : 14.0;
    final double bottomSpacing     = screenHeight < 700 ? 16.0 : 32.0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // ── Background fill ──────────────────────────────────────────────
          Positioned.fill(
            child: Container(color: theme.scaffoldBackgroundColor),
          ),

          // ── Watermark chinar ─────────────────────────────────────────────
          Positioned.fill(
            child: Center(
              child: Opacity(
                opacity: 0.18,
                child: Image.asset(
                  'assets/images/chinar.png',
                  width: screenWidth,
                  height: screenHeight,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: topSpacing),

                  // ── Logo ─────────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(logoIconPad),
                        decoration: BoxDecoration(
                          color: cs.primary.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: cs.primary.withOpacity(0.5),
                          ),
                        ),
                        child: Icon(
                          Icons.location_on,
                          color: cs.primary,
                          size: logoIconSize,
                        ),
                      ),
                      SizedBox(width: isSmall ? 8.0 : 12.0),
                      Flexible(
                        child: Text(
                          'KonnectKashmir',
                          style: TextStyle(
                            fontSize: logoFontSize,
                            fontWeight: FontWeight.bold,
                            color: cs.primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: isSmall ? 10.0 : 16.0),

                  Text(
                    'Enter your phone number to continue',
                    style: TextStyle(
                      fontSize: subtitleFontSize,
                      color: cs.onSurface.withOpacity(0.55),
                    ),
                    textAlign: TextAlign.center,
                  ),

                  // ── Redirect message banner ──────────────────────────────
                  if (widget.redirectMessage != null &&
                      widget.redirectMessage!.trim().isNotEmpty) ...[
                    SizedBox(height: isSmall ? 12.0 : 16.0),
                    Container(
                      padding: EdgeInsets.all(bannerPad),
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: cs.primary.withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: cs.primary, size: bannerIconSize),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.redirectMessage!,
                              style: TextStyle(
                                color: cs.primary,
                                fontSize: bannerFontSize,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  SizedBox(height: sectionSpacing),

                  // ── Phone label ──────────────────────────────────────────
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Phone Number',
                      style: TextStyle(
                        fontSize: labelFontSize,
                        color: cs.onSurface.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  SizedBox(height: isSmall ? 8.0 : 10.0),

                  // ── Phone input row ──────────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // +91 prefix box
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: prefixPadH,
                          vertical: prefixPadV,
                        ),
                        decoration: BoxDecoration(
                          color: cs.onSurface.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: cs.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          '+91',
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: inputFontSize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(width: isSmall ? 8.0 : 12.0),
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: inputFontSize,
                          ),
                          decoration: InputDecoration(
                            hintText: '9876543210',
                            hintStyle: TextStyle(
                              color: cs.onSurface.withOpacity(0.35),
                              fontSize: inputFontSize,
                            ),
                            filled: true,
                            fillColor: cs.onSurface.withOpacity(0.07),
                            counterText: '',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: isSmall ? 12.0 : 16.0,
                              vertical: isSmall ? 13.0 : 16.0,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: cs.primary.withOpacity(0.3),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: cs.primary.withOpacity(0.3),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: cs.primary,
                                width: 2,
                              ),
                            ),
                            errorText: _error,
                            errorStyle: TextStyle(
                              color: const Color(0xFFFF6B6B),
                              fontSize: isSmall ? 11.0 : 12.0,
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFFF6B6B),
                                width: 1.5,
                              ),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFFF6B6B),
                                width: 2,
                              ),
                            ),
                          ),
                          enabled: !_isLoading,
                          onChanged: (_) {
                            if (_error != null) {
                              setState(() => _error = null);
                            }
                          },
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: isSmall ? 20.0 : 28.0),

                  // ── Send OTP button ──────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _sendOTP,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        padding: EdgeInsets.symmetric(vertical: buttonVertPad),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                        disabledBackgroundColor: cs.primary.withOpacity(0.35),
                      ),
                      child: _isLoading
                          ? SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            cs.onPrimary,
                          ),
                        ),
                      )
                          : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Send OTP',
                            style: TextStyle(
                              fontSize: buttonFontSize,
                              fontWeight: FontWeight.w700,
                              color: cs.onPrimary,
                            ),
                          ),
                          SizedBox(width: isSmall ? 6.0 : 8.0),
                          Icon(Icons.arrow_forward,
                              color: cs.onPrimary,
                              size: isSmall ? 16.0 : 18.0),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: isSmall ? 14.0 : 20.0),

                  Text(
                    'We will send a 6-digit code to verify your number',
                    style: TextStyle(
                      fontSize: hintFontSize,
                      color: cs.onSurface.withOpacity(0.45),
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: isSmall ? 24.0 : 36.0),

                  _buildTermsText(context, cs, termsFontSize),

                  SizedBox(height: bottomSpacing),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsText(BuildContext context, ColorScheme cs, double fontSize) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          color: cs.onSurface.withOpacity(0.45),
        ),
        children: [
          const TextSpan(text: 'By continuing, you agree to our '),
          WidgetSpan(
            child: GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const TermsScreen())),
              child: Text(
                'Terms of Service',
                style: TextStyle(
                  color: cs.primary,
                  decoration: TextDecoration.underline,
                  fontSize: fontSize,
                ),
              ),
            ),
          ),
          const TextSpan(text: ' and '),
          WidgetSpan(
            child: GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PrivacyScreen())),
              child: Text(
                'Privacy Policy',
                style: TextStyle(
                  color: cs.primary,
                  decoration: TextDecoration.underline,
                  fontSize: fontSize,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}