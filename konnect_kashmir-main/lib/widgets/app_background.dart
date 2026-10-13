import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// App-wide background: solid brand color + a static, subtle Chinar leaf.
///
/// Applied once to every page route through [AppTheme] (see
/// `_AppBackgroundTransitions`), so screens only need a transparent Scaffold.
/// The leaf lives outside any scroll view, ignores touches and takes no layout
/// space — it stays fixed while the content scrolls over it.
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ColoredBox(
      color: isDark ? AppColors.darkBg : AppColors.lightBg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: _ChinarLeaf()),
          child,
        ],
      ),
    );
  }
}

class _ChinarLeaf extends StatelessWidget {
  const _ChinarLeaf();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: IgnorePointer(
        child: Center(
          // The fade is applied by the image itself (no extra full-screen layer for
          // every page), and it is decoded at a size the screen can use.
          child: Image.asset(
            'assets/images/chinar.png',
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            cacheWidth: 900,
            opacity: AlwaysStoppedAnimation<double>(isDark ? 0.18 : 0.08),
          ),
        ),
      ),
    );
  }
}
