import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:konnect_kashmir/screens/profile_screen.dart';
import 'package:provider/provider.dart';
import 'package:konnect_kashmir/providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'main_shell.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String phoneNumber;

  const OTPVerificationScreen({super.key, required this.phoneNumber});

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen>
    with SingleTickerProviderStateMixin {
  // Single controller — OS autofills this reliably
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isLoading = false;
  String? _error;
  int _resendTimer = 60;
  bool _canResend = false;
  Timer? _timer;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _otpController.addListener(_onOtpChanged);

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

  void _onOtpChanged() {
    final val = _otpController.text;
    if (val.length == 6 && !_isLoading) {
      Future.delayed(const Duration(milliseconds: 120), _verifyOTP);
    }
    setState(() {});
  }

  void _startTimer() {
    setState(() {
      _resendTimer = 60;
      _canResend = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_resendTimer == 0) {
        setState(() => _canResend = true);
        t.cancel();
      } else {
        setState(() => _resendTimer--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    _otpController.removeListener(_onOtpChanged);
    _otpController.dispose();
    _focusNode.dispose();
    AuthService.clearSession();
    super.dispose();
  }

  // ── OTP verify ─────────────────────────────────────────────────────────────
  Future<void> _verifyOTP() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _error = 'Please enter the complete 6-digit OTP');
      return;
    }
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final sdkResult = await AuthService.verifyOTP(otp);
      if (sdkResult['success'] != true) {
        setState(() {
          _isLoading = false;
          _error = sdkResult['error'] ?? 'Invalid OTP';
        });
        return;
      }

      final authProvider = context.read<AuthProvider>();
      final result = await authProvider.verifyOTPFromSDK(
        sdkResult['accessToken'] as String,
        widget.phoneNumber,
      );

      setState(() => _isLoading = false);
      if (!mounted) return;

      if (result['success'] == true) {
        final String role = result['role'] ?? 'customer';
        final String name = result['name'] ?? '';
        final String userId = result['userId'] ?? '';
        final bool isNewUser = result['isNewUser'] == true;

        if (isNewUser || name.trim().isEmpty) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => CompleteProfileScreen(
                role: role,
                phone: widget.phoneNumber,
                userId: userId,
              ),
            ),
            (route) => false,
          );
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const MainShell()),
            (route) => false,
          );
        }
      } else {
        setState(() => _error = result['error'] ?? 'Authentication failed');
      }
    } catch (e) {
      setState(() => _error = 'Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOTP() async {
    if (!_canResend || _isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result =
        await context.read<AuthProvider>().sendOTP(widget.phoneNumber);
    setState(() => _isLoading = false);
    if (!mounted) return;

    if (result['success'] == true) {
      _otpController.clear();
      _focusNode.requestFocus();
      _startTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline_rounded,
                  color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                'OTP resent successfully!',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } else {
      setState(() => _error = result['error'] ?? 'Failed to resend OTP');
    }
  }

  // ── Custom 6-box display ─────────────────────────────────────────────────
  Widget _buildOtpBoxes(
    double fontSize,
    bool isDark,
    ColorScheme cs,
  ) {
    final String current = _otpController.text;
    final bool isFocused = _focusNode.hasFocus;

    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: List.generate(11, (i) {
          if (i.isOdd) {
            return const SizedBox(width: 6);
          }
          final int index = i ~/ 2;
          final bool hasDigit = index < current.length;
          final bool isActive = isFocused &&
              (index == current.length ||
                  (index == 5 && current.length == 6));

          final Color boxBg = isDark
              ? (isActive
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : const Color(0xFF0A1816).withValues(alpha: 0.65))
              : (isActive
                  ? AppColors.primary.withValues(alpha: 0.08)
                  : const Color(0xFFF0F6F5));

          final Color borderColor = _error != null
              ? const Color(0xFFFF5252)
              : (isActive
                  ? AppColors.primary
                  : (hasDigit
                      ? AppColors.primary.withValues(alpha: 0.6)
                      : cs.onSurface.withValues(alpha: isDark ? 0.12 : 0.16)));

          return Expanded(
            child: AspectRatio(
              aspectRatio: 0.86,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: boxBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: borderColor,
                    width: isActive || _error != null ? 2.0 : 1.2,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: hasDigit
                    ? Text(
                        current[index],
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: fontSize,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : (isActive ? _buildCursor() : null),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCursor() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 550),
      builder: (_, v, __) => Opacity(
        opacity: v < 0.5 ? v * 2 : (1 - v) * 2,
        child: Container(
          width: 2.2,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
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

    final double maxCardWidth = 440.0;
    final double otpFontSize = isSmall ? 18.0 : 22.0;

    // Standalone app logo
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

          // ── 2. Decorative Chinar Watermark ───────────────────────────────
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
                      // Top Bar with Back Button
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.10)
                                    : Colors.black.withValues(alpha: 0.08),
                              ),
                            ),
                            child: IconButton(
                              onPressed: () {
                                AuthService.clearSession();
                                Navigator.pop(context);
                              },
                              icon: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: cs.onSurface,
                                size: 18,
                              ),
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(),
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // App Logo
                      logoWidget,
                      const SizedBox(height: 6),

                      Text(
                        'Kashmir\'s Local Services & Business Directory',
                        style: TextStyle(
                          fontSize: isSmall ? 12.0 : 13.5,
                          color: cs.onSurface.withValues(alpha: 0.65),
                          letterSpacing: 0.2,
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 20),

                      // ── Main Glassmorphic Card ───────────────────────────
                      Container(
                        width: double.infinity,
                        constraints: BoxConstraints(maxWidth: maxCardWidth),
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
                                    Icons.mark_email_read_rounded,
                                    color: AppColors.primaryLight,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Verify OTP Code',
                                  style: TextStyle(
                                    fontSize: isSmall ? 16.5 : 18.5,
                                    fontWeight: FontWeight.w700,
                                    color: cs.onSurface,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Phone detail pill
                            Text(
                              'Enter the 6-digit code sent to your number',
                              style: TextStyle(
                                fontSize: isSmall ? 12 : 13,
                                color: cs.onSurface.withValues(alpha: 0.55),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Phone Badge with edit action
                            InkWell(
                              onTap: () {
                                AuthService.clearSession();
                                Navigator.pop(context);
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.20),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('🇮🇳',
                                        style: TextStyle(fontSize: 14)),
                                    const SizedBox(width: 6),
                                    Text(
                                      '+91 ${widget.phoneNumber}',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: cs.onSurface,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.edit_rounded,
                                      size: 14,
                                      color: AppColors.primaryLight,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 22),

                            // ── Visual 6 boxes + hidden real input ────────
                            Stack(
                              children: [
                                _buildOtpBoxes(
                                  otpFontSize,
                                  isDark,
                                  cs,
                                ),
                                Positioned.fill(
                                  child: Opacity(
                                    opacity: 0,
                                    child: AutofillGroup(
                                      child: TextField(
                                        controller: _otpController,
                                        focusNode: _focusNode,
                                        keyboardType: TextInputType.number,
                                        maxLength: 6,
                                        autofillHints: const [
                                          AutofillHints.oneTimeCode
                                        ],
                                        enableSuggestions: true,
                                        autocorrect: false,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                          LengthLimitingTextInputFormatter(6),
                                        ],
                                        decoration: const InputDecoration(
                                          counterText: '',
                                          border: InputBorder.none,
                                        ),
                                        style: const TextStyle(
                                            color: Colors.transparent),
                                        cursorColor: Colors.transparent,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Error Message
                            if (_error != null) ...[
                              const SizedBox(height: 12),
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

                            // ── Verify & Continue Button ──────────────────
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
                                  onTap: _isLoading ? null : _verifyOTP,
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
                                                'Verify & Continue',
                                                style: TextStyle(
                                                  fontSize: 15.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              Icon(
                                                Icons
                                                    .check_circle_outline_rounded,
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

                      const SizedBox(height: 22),

                      // ── Resend Code Section ──────────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : AppColors.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : AppColors.primary.withValues(alpha: 0.12),
                          ),
                        ),
                        child: _canResend
                            ? InkWell(
                                onTap: _isLoading ? null : _resendOTP,
                                borderRadius: BorderRadius.circular(12),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.refresh_rounded,
                                      size: 16,
                                      color: AppColors.primaryLight,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Resend OTP Code',
                                      style: TextStyle(
                                        color: AppColors.primaryLight,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.timer_outlined,
                                    size: 15,
                                    color:
                                        cs.onSurface.withValues(alpha: 0.45),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Resend code in ',
                                    style: TextStyle(
                                      color:
                                          cs.onSurface.withValues(alpha: 0.55),
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '${_resendTimer}s',
                                    style: const TextStyle(
                                      color: AppColors.primaryLight,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                      ),

                      const SizedBox(height: 16),
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
}