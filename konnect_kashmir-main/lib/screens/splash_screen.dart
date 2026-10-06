import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'main_shell.dart';

/// First screen. Shows the logo briefly, then opens the Dashboard (if a saved
/// session exists) or the Login screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1800), _next);
  }

  void _next() {
    if (!mounted) return;
    final loggedIn = context.read<AuthProvider>().isAuthenticated;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) => loggedIn
            ? const MainShell()
            : const LoginScreen(),
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

    return Scaffold(
      body: Stack(children: [
        Positioned(
          top: -40,
          right: -60,
          child: Opacity(
            opacity: isDark ? 0.10 : 0.08,
            child: Image.asset('assets/images/chinar.png', width: 300),
          ),
        ),
        Center(
          child: FadeTransition(
            opacity: CurvedAnimation(parent: _c, curve: Curves.easeOut),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1).animate(
                  CurvedAnimation(parent: _c, curve: Curves.easeOutCubic)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                logo,
                const SizedBox(height: 12),
                Text('Local services, Kashmir-wide',
                    style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.55))),
              ]),
            ),
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 48,
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2.4, color: AppColors.primary),
            ),
          ),
        ),
      ]),
    );
  }
}
