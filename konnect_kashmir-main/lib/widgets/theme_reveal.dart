import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';

/// Circular "reveal" transition for Light/Dark switching.
///
/// Flow: snapshot the current UI -> switch the real theme underneath (instant,
/// MaterialApp has no theme lerp) -> paint the snapshot on top, clipped to
/// everything *outside* a circle that grows from the toggle. Each frame only
/// repaints one lightweight CustomPaint; the app itself is not rebuilt.
///
/// Place once above the Navigator (MaterialApp.builder). The theme logic and
/// persistence stay in [ThemeProvider]; this only wraps the call visually.
class ThemeReveal extends StatefulWidget {
  final Widget child;
  const ThemeReveal({super.key, required this.child});

  /// Switches theme with the reveal, originating at [trigger]'s center.
  /// Falls back to a plain switch if the host is missing or capture fails.
  static Future<void> setDark(BuildContext trigger, bool dark) async {
    final host = trigger.findAncestorStateOfType<_ThemeRevealState>();
    if (host == null) {
      await trigger.read<ThemeProvider>().setDark(dark);
      return;
    }
    await host._run(trigger, dark);
  }

  @override
  State<ThemeReveal> createState() => _ThemeRevealState();
}

class _ThemeRevealState extends State<ThemeReveal>
    with SingleTickerProviderStateMixin {
  final GlobalKey _boundaryKey = GlobalKey();

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _progress =
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

  ui.Image? _snapshot;
  Offset _origin = Offset.zero;
  double _maxRadius = 0;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    _snapshot?.dispose();
    super.dispose();
  }

  Future<void> _run(BuildContext trigger, bool dark) async {
    if (_busy) return; // ignore taps while a reveal is running
    _busy = true;
    final provider = context.read<ThemeProvider>();

    try {
      final hostBox = context.findRenderObject() as RenderBox?;
      final triggerBox = trigger.findRenderObject() as RenderBox?;
      final boundary = _boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (hostBox == null || triggerBox == null || boundary == null) {
        await provider.setDark(dark);
        return;
      }

      final size = hostBox.size;
      final center = triggerBox.localToGlobal(triggerBox.size.center(Offset.zero));
      final origin = hostBox.globalToLocal(center);
      final pixelRatio = MediaQuery.of(context).devicePixelRatio;

      final image = await boundary.toImage(pixelRatio: pixelRatio);
      if (!mounted) {
        image.dispose();
        return;
      }

      // Farthest screen corner from the origin, so every corner gets covered.
      final maxRadius = [
        origin.distance,
        (origin - Offset(size.width, 0)).distance,
        (origin - Offset(0, size.height)).distance,
        (origin - Offset(size.width, size.height)).distance,
      ].reduce(math.max);

      setState(() {
        _snapshot = image;
        _origin = origin;
        _maxRadius = maxRadius;
      });
      _controller.value = 0;
      await WidgetsBinding.instance.endOfFrame; // overlay is on screen

      await provider.setDark(dark); // real theme changes underneath
      await WidgetsBinding.instance.endOfFrame; // new theme has been painted

      if (mounted) await _controller.forward(from: 0);
    } catch (_) {
      await provider.setDark(dark);
    } finally {
      if (mounted) {
        final old = _snapshot;
        setState(() => _snapshot = null);
        old?.dispose();
      }
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(key: _boundaryKey, child: widget.child),
        if (snapshot != null)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _RevealPainter(
                  image: snapshot,
                  origin: _origin,
                  maxRadius: _maxRadius,
                  progress: _progress,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RevealPainter extends CustomPainter {
  final ui.Image image;
  final Offset origin;
  final double maxRadius;
  final Animation<double> progress;

  _RevealPainter({
    required this.image,
    required this.origin,
    required this.maxRadius,
    required this.progress,
  }) : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    final radius = maxRadius * progress.value;
    // Draw the OLD snapshot everywhere except inside the growing circle, so the
    // live (new-theme) UI shows through the circle.
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(Rect.fromCircle(center: origin, radius: radius));
    canvas.save();
    canvas.clipPath(path);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.low,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RevealPainter old) =>
      old.image != image || old.origin != origin || old.maxRadius != maxRadius;
}
