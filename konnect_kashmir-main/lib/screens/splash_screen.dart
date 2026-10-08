import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import 'login_screen.dart';
import 'main_shell.dart';

/// First screen. Plays a short intro animation (logo pop, light sweep, soft
/// ripples, tagline), then opens the Dashboard (if a saved session exists) or
/// the Login screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _total = Duration(milliseconds: 2200);

  late final AnimationController _c =
      AnimationController(vsync: this, duration: _total)..forward();

  Animation<double> _interval(double a, double b, Curve curve) =>
      CurvedAnimation(parent: _c, curve: Interval(a, b, curve: curve));

  late final Animation<double> _logoFade =
      _interval(0.00, 0.30, Curves.easeOut);
  late final Animation<double> _logoScale =
      _interval(0.00, 0.50, Curves.easeOutBack);
  late final Animation<double> _shimmer =
      _interval(0.45, 0.90, Curves.easeInOut);
  late final Animation<double> _tagFade =
      _interval(0.40, 0.75, Curves.easeOut);

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 2400), _next);
  }

  void _next() {
    if (!mounted) return;
    final loggedIn = context.read<AuthProvider>().isAuthenticated;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) => AppBackground(
          child: loggedIn ? const MainShell() : const LoginScreen(),
        ),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    Widget logo = Image.asset('assets/images/konnectkashmir.png', width: 220);
    if (isDark) {
      logo = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          -1, 0, 0, 0, 255,
          0, -1, 0, 0, 255,
          0, 0, -1, 0, 255,
          0, 0, 0, 1, 0,
        ]),
        child: logo,
      );
    }

    // A soft light band sweeps across the logo once it has landed.
    final shimmeringLogo = AnimatedBuilder(
      animation: _shimmer,
      child: logo,
      builder: (context, child) {
        final x = -0.4 + 1.8 * _shimmer.value; // band centre across the logo
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            colors: [
              Colors.transparent,
              AppColors.primaryLight.withValues(alpha: 0.85),
              Colors.transparent,
            ],
            stops: [
              (x - 0.18).clamp(0.0, 1.0),
              x.clamp(0.0, 1.0),
              (x + 0.18).clamp(0.0, 1.0),
            ],
          ).createShader(rect),
          child: child,
        );
      },
    );

    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 360,
          height: 360,
          child: Stack(alignment: Alignment.center, children: [
            // Ripple rings behind the logo.
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _RipplePainter(_c)),
              ),
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              FadeTransition(
                opacity: _logoFade,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.75, end: 1).animate(_logoScale),
                  child: shimmeringLogo,
                ),
              ),
              const SizedBox(height: 14),
              FadeTransition(
                opacity: _tagFade,
                child: SlideTransition(
                  position: Tween<Offset>(
                          begin: const Offset(0, 0.6), end: Offset.zero)
                      .animate(_tagFade),
                  child: Text('Local services, Kashmir-wide',
                      style: TextStyle(
                          fontSize: AppText.body,
                          letterSpacing: 0.3,
                          color: cs.onSurface.withValues(alpha: 0.65))),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Two expanding, fading rings that start just after the logo appears.
class _RipplePainter extends CustomPainter {
  final Animation<double> t;
  _RipplePainter(this.t) : super(repaint: t);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    for (var i = 0; i < 2; i++) {
      final phase = ((t.value - 0.15 - i * 0.18) / 0.7).clamp(0.0, 1.0);
      if (phase <= 0 || phase >= 1) continue;
      final eased = Curves.easeOutCubic.transform(phase);
      final radius = 70 + 110 * eased;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.primary.withValues(alpha: 0.22 * (1 - phase));
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) => false;
}
