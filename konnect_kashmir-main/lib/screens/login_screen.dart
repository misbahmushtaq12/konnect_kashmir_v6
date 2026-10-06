import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:konnect_kashmir/static/terms_screen.dart';
import 'package:konnect_kashmir/static/privacy_screen.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'otp_ver.dart';

class LoginScreen extends StatefulWidget {
  final String? redirectMessage;

  const LoginScreen({Key? key, this.redirectMessage}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = false;
  String? _error;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _phoneController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _cleanPhone(String raw) {
    String cleaned = raw.replaceAll(RegExp(r'[\s\-]'), '');
    if (cleaned.startsWith('+91')) {
      cleaned = cleaned.substring(3);
    } else if (cleaned.startsWith('91') && cleaned.length == 12) {
      cleaned = cleaned.substring(2);
    } else if (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }
    return cleaned;
  }

  void _sendOTP() async {
    final rawPhone = _phoneController.text.trim();

    if (rawPhone.isEmpty) {
      setState(() => _error = 'Please enter a phone number');
      return;
    }

    final cleanedPhone = _cleanPhone(rawPhone);

    if (cleanedPhone.length != 10 ||
        !RegExp(r'^\d{10}$').hasMatch(cleanedPhone)) {
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
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final double screenWidth = size.width;
    final bool isSmall = screenWidth < 360;

    // Palette tokens
    final Color bgColor =
        isDark ? const Color(0xFF0C1E1C) : const Color(0xFFF3FAF8);
    final Color cardBg = isDark
        ? const Color(0xFF142B28).withValues(alpha: 0.88)
        : Colors.white.withValues(alpha: 0.94);
    final Color cardBorder = isDark
        ? AppColors.primaryLight.withValues(alpha: 0.18)
        : AppColors.primary.withValues(alpha: 0.15);
    final Color inputBg = isDark
        ? const Color(0xFF0A1816).withValues(alpha: 0.65)
        : const Color(0xFFF0F6F5);

    // Standalone App Logo
    Widget logoWidget = Image.asset(
      'assets/images/konnectkashmir.png',
      width: isSmall ? 320 : 380,
      height: isSmall ? 130 : 165,
      fit: BoxFit.contain,
    );
    if (isDark) {
      logoWidget = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          -1, 0, 0, 0, 255,
          0, -1, 0, 0, 255,
          0, 0, -1, 0, 255,
          0, 0, 0, 1, 0,
        ]),
        child: logoWidget,
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // ── 1. Atmospheric Ambient Gradients ─────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [
                          const Color(0xFF091716),
                          const Color(0xFF102724),
                          const Color(0xFF0B1B19),
                        ]
                      : [
                          const Color(0xFFEBF7F4),
                          const Color(0xFFF5FCFA),
                          const Color(0xFFEDF8F5),
                        ],
                ),
              ),
            ),
          ),

          // ── Ambient Light Orb (Top-Right) ────────────────────────────────
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Ambient Light Orb (Bottom-Left) ──────────────────────────────
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: isDark ? 0.12 : 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── 2. Decorative Chinar Watermarks ──────────────────────────────
          Positioned(
            top: 20,
            right: -30,
            child: Transform.rotate(
              angle: 0.25,
              child: Opacity(
                opacity: isDark ? 0.09 : 0.06,
                child: Image.asset(
                  'assets/images/chinar.png',
                  width: 240,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: -40,
            child: Transform.rotate(
              angle: -0.3,
              child: Opacity(
                opacity: isDark ? 0.07 : 0.05,
                child: Image.asset(
                  'assets/images/chinar.png',
                  width: 220,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          // ── 3. Main Interactive Content ──────────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: isSmall ? 18.0 : 24.0,
                vertical: 10.0,
              ),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: isSmall ? 6.0 : 12.0),

                      // ── Top Brand App Logo ─────────────────────────────
                      logoWidget,
                      const SizedBox(height: 6),

                      // Subtitle
                      Text(
                        'Kashmir\'s Local Services & Business Directory',
                        style: TextStyle(
                          fontSize: isSmall ? 12.5 : 14.0,
                          color: cs.onSurface.withValues(alpha: 0.70),
                          letterSpacing: 0.2,
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 20),

                      // ── Optional Redirect Notification Banner ──────────
                      if (widget.redirectMessage != null &&
                          widget.redirectMessage!.trim().isNotEmpty) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                color: AppColors.accent,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  widget.redirectMessage!,
                                  style: const TextStyle(
                                    color: AppColors.accent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // ── Main Glassmorphic Form Card ───────────────────
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxWidth: 440),
                        padding: EdgeInsets.all(isSmall ? 20.0 : 26.0),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: cardBorder,
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                              blurRadius: 28,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Card Header
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.lock_person_rounded,
                                    color: AppColors.primaryLight,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Sign In / Register',
                                  style: TextStyle(
                                    fontSize: isSmall ? 16.5 : 18.5,
                                    fontWeight: FontWeight.w700,
                                    color: cs.onSurface,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Enter your mobile number to get started',
                              style: TextStyle(
                                fontSize: isSmall ? 12 : 13,
                                color: cs.onSurface.withValues(alpha: 0.55),
                              ),
                            ),

                            const SizedBox(height: 22),

                            // Phone Number Label
                            Text(
                              'Mobile Number',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface.withValues(alpha: 0.85),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Input Box with +91 Country Indicator
                            Container(
                              decoration: BoxDecoration(
                                color: inputBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _error != null
                                      ? const Color(0xFFFF5252)
                                      : (_focusNode.hasFocus
                                          ? AppColors.primary
                                          : cs.onSurface.withValues(
                                              alpha: isDark ? 0.12 : 0.15)),
                                  width: _focusNode.hasFocus || _error != null
                                      ? 1.8
                                      : 1.2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Flag & Prefix Container
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        right: BorderSide(
                                          color: cs.onSurface.withValues(
                                              alpha: isDark ? 0.10 : 0.12),
                                          width: 1.2,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          '🇮🇳',
                                          style: TextStyle(fontSize: 16),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '+91',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: cs.onSurface,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Text Field
                                  Expanded(
                                    child: TextField(
                                      controller: _phoneController,
                                      focusNode: _focusNode,
                                      keyboardType: TextInputType.phone,
                                      maxLength: 10,
                                      autofillHints: const [
                                        AutofillHints.telephoneNumberNational
                                      ],
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(10),
                                      ],
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: cs.onSurface,
                                        letterSpacing: 1.2,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: '98765 43210',
                                        hintStyle: TextStyle(
                                          fontSize: 15,
                                          letterSpacing: 0.5,
                                          color: cs.onSurface
                                              .withValues(alpha: 0.32),
                                          fontWeight: FontWeight.normal,
                                        ),
                                        counterText: '',
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 14,
                                        ),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                      ),
                                      enabled: !_isLoading,
                                      onChanged: (_) {
                                        if (_error != null) {
                                          setState(() => _error = null);
                                        }
                                      },
                                      onSubmitted: (_) => _sendOTP(),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Error text
                            if (_error != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    color: Color(0xFFFF5252),
                                    size: 15,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: const TextStyle(
                                        color: Color(0xFFFF5252),
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            const SizedBox(height: 22),

                            // ── Send Verification OTP Button ─────────────
                            Container(
                              width: double.infinity,
                              height: 52,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(
                                  colors: _isLoading
                                      ? [
                                          AppColors.primary
                                              .withValues(alpha: 0.6),
                                          AppColors.primaryDark
                                              .withValues(alpha: 0.6),
                                        ]
                                      : [
                                          const Color(0xFF38B29B),
                                          const Color(0xFF227B6C),
                                        ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: _isLoading
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.38),
                                          blurRadius: 18,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _isLoading ? null : _sendOTP,
                                  borderRadius: BorderRadius.circular(16),
                                  splashColor:
                                      Colors.white.withValues(alpha: 0.2),
                                  highlightColor:
                                      Colors.white.withValues(alpha: 0.1),
                                  child: Center(
                                    child: _isLoading
                                        ? const SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.4,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                            ),
                                          )
                                        : const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                'Send Verification OTP',
                                                style: TextStyle(
                                                  fontSize: 15.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              Icon(
                                                Icons.arrow_forward_rounded,
                                                color: Colors.white,
                                                size: 19,
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 14),

                            // Security Caption
                            Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.lock_outline_rounded,
                                    size: 13,
                                    color: cs.onSurface.withValues(alpha: 0.40),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Safe & secure',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      color:
                                          cs.onSurface.withValues(alpha: 0.45),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Terms & Privacy Footer ─────────────────────────
                      _buildTermsText(context, cs, isSmall ? 11.5 : 12.5),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsText(BuildContext context, ColorScheme cs, double fontSize) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: TextStyle(
            fontSize: fontSize,
            color: cs.onSurface.withValues(alpha: 0.50),
            height: 1.4,
          ),
          children: [
            const TextSpan(text: 'By continuing, you agree to KonnectKashmir\'s\n'),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TermsScreen()),
                ),
                child: const Text(
                  'Terms of Service',
                  style: TextStyle(
                    color: AppColors.primaryLight,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
            const TextSpan(text: ' and '),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                ),
                child: const Text(
                  'Privacy Policy',
                  style: TextStyle(
                    color: AppColors.primaryLight,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}