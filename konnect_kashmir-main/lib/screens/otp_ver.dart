import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:konnect_kashmir/screens/profile_screen.dart';
import 'package:provider/provider.dart';
import 'package:konnect_kashmir/providers/auth_provider.dart';
import '../services/auth_service.dart';
import 'main_shell.dart';

const Color _kTeal = Color(0xFF6BC4B2);

class OTPVerificationScreen extends StatefulWidget {
  final String phoneNumber;

  const OTPVerificationScreen({super.key, required this.phoneNumber});

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  // Single controller — the OS autofills this reliably
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isLoading = false;
  String? _error;
  int _resendTimer = 60;
  bool _canResend = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _otpController.addListener(_onOtpChanged);
  }

  void _onOtpChanged() {
    final val = _otpController.text;
    if (val.length == 6 && !_isLoading) {
      // Small delay so the UI renders the filled boxes before verifying
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
      if (!mounted) { t.cancel(); return; }
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
    _otpController.removeListener(_onOtpChanged);
    _otpController.dispose();
    _focusNode.dispose();
    AuthService.clearSession();
    super.dispose();
  }

  // ── Theme helpers ──────────────────────────────────────────────────────────
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  ColorScheme get _cs => Theme.of(context).colorScheme;
  Color get _onSurface => _cs.onSurface;
  Color get _onMuted => _cs.onSurface.withOpacity(0.55);
  Color get _inputFill =>
      _isDark ? Colors.black.withOpacity(0.30) : _cs.surfaceContainerHighest;

  // ── OTP verify ─────────────────────────────────────────────────────────────
  Future<void> _verifyOTP() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _error = 'Please enter the complete 6-digit OTP');
      return;
    }
    if (_isLoading) return;

    setState(() { _isLoading = true; _error = null; });

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
              role: role, phone: widget.phoneNumber, userId: userId,
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
  }

  Future<void> _resendOTP() async {
    if (!_canResend) return;
    setState(() { _isLoading = true; _error = null; });

    final result = await context.read<AuthProvider>().sendOTP(widget.phoneNumber);
    setState(() => _isLoading = false);
    if (!mounted) return;

    if (result['success'] == true) {
      _otpController.clear();
      _focusNode.requestFocus();
      _startTimer();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('OTP resent successfully'),
        backgroundColor: _kTeal,
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      setState(() => _error = result['error'] ?? 'Failed to resend OTP');
    }
  }

  // ── Custom 6-box display (purely visual, tapping opens the hidden field) ──
  Widget _buildOtpBoxes(double boxSize, double fontSize) {
    final String current = _otpController.text;
    final bool isFocused = _focusNode.hasFocus;

    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(6, (index) {
          final bool hasDigit = index < current.length;
          final bool isActive = isFocused &&
              (index == current.length || (index == 5 && current.length == 6));

          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: boxSize,
            height: boxSize + 4,
            decoration: BoxDecoration(
              color: _inputFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive
                    ? _kTeal
                    : hasDigit
                    ? _kTeal.withOpacity(0.5)
                    : _cs.outline.withOpacity(_isDark ? 0.25 : 0.40),
                width: isActive ? 2 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: hasDigit
                ? Text(
              current[index],
              style: TextStyle(
                color: _onSurface,
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
              ),
            )
                : isActive
                ? _buildCursor()
                : null,
          );
        }),
      ),
    );
  }

  Widget _buildCursor() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      builder: (_, v, __) => Opacity(
        opacity: v < 0.5 ? v * 2 : (1 - v) * 2,
        child: Container(
          width: 2,
          height: 24,
          color: _kTeal,
        ),
      ),
      onEnd: () => setState(() {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double screenWidth = size.width;
    final double screenHeight = size.height;

    // ── Responsive breakpoints ─────────────────────────────────────────────
    final bool isSmall = screenWidth < 360;
    final bool isMedium = screenWidth >= 360 && screenWidth < 480;

    final double horizontalPadding = isSmall ? 16.0 : (isMedium ? 24.0 : 32.0);
    final double titleFontSize = isSmall ? 26.0 : (isMedium ? 30.0 : 32.0);
    final double subtitleFontSize = isSmall ? 14.0 : 16.0;
    final double phoneFontSize = isSmall ? 15.0 : (isMedium ? 17.0 : 18.0);
    final double otpBoxSize = isSmall ? 40.0 : (isMedium ? 46.0 : 52.0);
    final double otpFontSize = isSmall ? 18.0 : (isMedium ? 22.0 : 24.0);
    final double topSpacing = screenHeight < 700 ? 12.0 : 20.0;
    final double otpTopSpacing = screenHeight < 700 ? 28.0 : 52.0;
    final double buttonSpacing = screenHeight < 700 ? 24.0 : 40.0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // ── Chinar watermark ───────────────────────────────────────────────
          Positioned.fill(
            child: Center(
              child: Opacity(
                opacity: _isDark ? 0.18 : 0.07,
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
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: topSpacing),

                  // ── Back ────────────────────────────────────────────────────
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () {
                        AuthService.clearSession();
                        Navigator.pop(context);
                      },
                      icon: Icon(Icons.arrow_back, color: _onSurface),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Title ───────────────────────────────────────────────────
                  Text(
                    'Verify OTP',
                    style: TextStyle(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.bold,
                      color: _kTeal,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Enter the 6-digit code sent to',
                    style: TextStyle(fontSize: subtitleFontSize, color: _onMuted),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '+91 ${widget.phoneNumber}',
                    style: TextStyle(
                      fontSize: phoneFontSize,
                      fontWeight: FontWeight.bold,
                      color: _onSurface,
                    ),
                  ),
                  SizedBox(height: otpTopSpacing),

                  // ── Visual 6 boxes + hidden real input ──────────────────────
                  Stack(
                    children: [
                      // Visual boxes (what user sees)
                      _buildOtpBoxes(otpBoxSize, otpFontSize),

                      // Hidden TextField (what OS autofills into)
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0,
                          child: AutofillGroup(
                            child: TextField(
                              controller: _otpController,
                              focusNode: _focusNode,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              autofillHints: const [AutofillHints.oneTimeCode],
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
                              style: const TextStyle(color: Colors.transparent),
                              cursorColor: Colors.transparent,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Error ───────────────────────────────────────────────────
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        border: Border.all(color: Colors.red.withOpacity(0.35)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(
                            color: Colors.red[400],
                            fontSize: isSmall ? 12.0 : 14.0),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  SizedBox(height: buttonSpacing),

                  // ── Verify button ───────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _verifyOTP,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kTeal,
                        foregroundColor: const Color(0xFF0D1F17),
                        padding: EdgeInsets.symmetric(
                            vertical: isSmall ? 13.0 : 16.0),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        disabledBackgroundColor: _kTeal.withOpacity(0.35),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF0D1F17)),
                        ),
                      )
                          : Text(
                        'Verify OTP',
                        style: TextStyle(
                          fontSize: isSmall ? 14.0 : 16.0,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0D1F17),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Resend ──────────────────────────────────────────────────
                  _canResend
                      ? TextButton(
                    onPressed: _resendOTP,
                    child: Text(
                      'Resend OTP',
                      style: TextStyle(
                        color: _kTeal,
                        fontSize: isSmall ? 14.0 : 16.0,
                        decoration: TextDecoration.underline,
                        decorationColor: _kTeal,
                      ),
                    ),
                  )
                      : Text(
                    'Resend OTP in ${_resendTimer}s',
                    style: TextStyle(
                        color: _onMuted,
                        fontSize: isSmall ? 13.0 : 15.0),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}