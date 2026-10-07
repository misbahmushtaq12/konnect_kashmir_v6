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
  Color get _inputFill =>
      _isDark ? Colors.black.withValues(alpha: 0.30) : _cs.surfaceContainerHighest;

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

  Widget _adaptiveLogo({double height = 75}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Widget logo = Image.asset('assets/images/konnectkashmir.png', height: height);
    if (isDark) {
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          -1, 0, 0, 0, 255,
          0, -1, 0, 0, 255,
          0, 0, -1, 0, 255,
          0, 0, 0, 1, 0,
        ]),
        child: logo,
      );
    }
    return logo;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final otpBoxSize = size.width < 360 ? 40.0 : 46.0;
    final otpFontSize = size.width < 360 ? 18.0 : 22.0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background fill
          Positioned.fill(
            child: Container(color: theme.scaffoldBackgroundColor),
          ),
          // Top right Chinar watermark
          Positioned(
            top: -30,
            right: -50,
            child: Opacity(
              opacity: isDark ? 0.12 : 0.08,
              child: Image.asset('assets/images/chinar.png', width: 280),
            ),
          ),
          // Bottom left Chinar watermark
          Positioned(
            bottom: -40,
            left: -50,
            child: Opacity(
              opacity: isDark ? 0.10 : 0.06,
              child: Image.asset('assets/images/chinar.png', width: 260),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 10),
                        // Back Button
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: () {
                              AuthService.clearSession();
                              Navigator.pop(context);
                            },
                            icon: Icon(Icons.arrow_back, color: cs.onSurface),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Adaptive Logo
                        _adaptiveLogo(height: 75),
                        const SizedBox(height: 24),
                        Text(
                          "Verify your phone number",
                          style: TextStyle(
                            fontSize: 14,
                            color: cs.onSurface.withValues(alpha: 0.60),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),

                        // Main Card
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF162521) : cs.surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: cs.onSurface.withValues(alpha: 0.08),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              )
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: cs.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(Icons.verified_user_rounded, color: cs.primary, size: 20),
                                  ),
                                  const SizedBox(width: 14),
                                  const Text(
                                    'OTP Verification',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Enter the 6-digit code sent to\n+91 ${widget.phoneNumber}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: cs.onSurface.withValues(alpha: 0.55),
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 28),
                              
                              // Visual 6 boxes + hidden real input
                              Stack(
                                children: [
                                  _buildOtpBoxes(otpBoxSize, otpFontSize),
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

                              if (_error != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: Center(
                                    child: Text(_error!, style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 13)),
                                  ),
                                ),

                              const SizedBox(height: 32),
                              // Verify Button
                              Container(
                                width: double.infinity,
                                height: 56,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: cs.primary.withValues(alpha: 0.3),
                                      blurRadius: 16,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _verifyOTP,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: cs.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    padding: EdgeInsets.zero,
                                    elevation: 0,
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                        )
                                      : const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Verify & Proceed',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Icon(Icons.arrow_forward_rounded, size: 20),
                                          ],
                                        ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Center(
                                child: _canResend
                                    ? TextButton(
                                        onPressed: _resendOTP,
                                        child: Text(
                                          'Resend OTP',
                                          style: TextStyle(
                                            color: cs.primary,
                                            fontSize: 14.0,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                    : Text(
                                        'Resend OTP in ${_resendTimer}s',
                                        style: TextStyle(
                                            color: cs.onSurface.withValues(alpha: 0.4),
                                            fontSize: 14.0),
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
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