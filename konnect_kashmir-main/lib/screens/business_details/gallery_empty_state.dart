import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_theme.dart';

/// What the photo area of a business shows when the business has no photos: a
/// quiet teal backdrop with a small storefront illustration and two lines of
/// text. It is only a picture for customers to look at; there is nothing to tap.
///
/// While the list of photos is still being asked for, [loading] shows the same
/// backdrop with a spinner, so nothing jumps when the answer arrives.
class GalleryEmptyState extends StatelessWidget {
  /// The height of the status bar and app bar that are drawn over the top of the
  /// photo area; the illustration is centred in what is left below them.
  final double topInset;
  final bool loading;

  const GalleryEmptyState({super.key, this.topInset = 0, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final p = _Palette(dark);
    final l = context.l10n;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Teal, fading into the page below it.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [p.skyTop, p.skyBottom, p.page],
              stops: const [0.0, 0.72, 1.0],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(top: topInset, bottom: 16),
          child: Center(
            child: loading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: p.accent,
                    ),
                  )
                : _content(l, p),
          ),
        ),
      ],
    );
  }

  Widget _content(AppLocalizations l, _Palette p) {
    return Semantics(
      container: true,
      label: '${l.noPhotosTitle}. ${l.noPhotosSubtitle}',
      child: ExcludeSemantics(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The glow and rings sit behind the illustration, a little larger.
                SizedBox(
                  width: 220,
                  height: 160,
                  child: CustomPaint(
                    painter: _BackdropPainter(p),
                    child: Center(
                      child: SizedBox(
                        width: _StorefrontPainter.size.width,
                        height: _StorefrontPainter.size.height,
                        child: CustomPaint(painter: _StorefrontPainter(p)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l.noPhotosTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: p.title,
                    fontSize: AppText.heading,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l.noPhotosSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: p.subtitle,
                    fontSize: AppText.secondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The colours of the empty state, for the dark and the light theme.
class _Palette {
  final bool dark;
  _Palette(this.dark);

  // Backdrop
  Color get skyTop => dark ? const Color(0xFF1D5254) : const Color(0xFFCDEAE4);
  Color get skyBottom =>
      dark ? const Color(0xFF15393A) : const Color(0xFFE6F4F1);
  Color get page => dark ? AppColors.darkBg : AppColors.lightBg;

  // Illustration
  Color get accent => dark ? AppColors.primaryLight : AppColors.primary;
  Color get stripeA => dark ? AppColors.primaryLight : AppColors.primary;
  Color get stripeB => dark ? const Color(0xFF1F6F61) : const Color(0xFFA9DDD1);
  Color get bodyTop => dark ? const Color(0xFF225454) : Colors.white;
  Color get bodyBottom =>
      dark ? const Color(0xFF173A3A) : const Color(0xFFDDF0EC);
  Color get line => accent.withValues(alpha: dark ? 0.6 : 0.65);
  Color get door => dark ? const Color(0xFF0F2C2D) : AppColors.primaryDark;
  Color get glass => accent.withValues(alpha: dark ? 0.16 : 0.14);

  // Text
  Color get title => dark ? const Color(0xFFEAF4F2) : AppColors.lightText;
  Color get subtitle => dark
      ? const Color(0xFFEAF4F2).withValues(alpha: 0.62)
      : AppColors.lightText.withValues(alpha: 0.62);
}

/// A soft glow with two faint rings around the illustration.
class _BackdropPainter extends CustomPainter {
  final _Palette p;
  const _BackdropPainter(this.p);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas.drawCircle(
      c,
      size.width * 0.5,
      Paint()
        ..shader = RadialGradient(
          colors: [
            p.accent.withValues(alpha: p.dark ? 0.22 : 0.20),
            p.accent.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: size.width * 0.5)),
    );
    final a = p.dark ? 0.12 : 0.16;
    Paint ring(double alpha) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = p.accent.withValues(alpha: alpha);
    canvas.drawCircle(c, size.height * 0.5, ring(a));
    canvas.drawCircle(c, size.height * 0.5 + 22, ring(a / 2));
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => old.p.dark != p.dark;
}

/// A small shop front: a striped awning with a scalloped edge, a sign, a window,
/// a door and a plant. Drawn at 168 x 136 and scaled with its box.
class _StorefrontPainter extends CustomPainter {
  static const Size size = Size(168, 136);
  final _Palette p;
  const _StorefrontPainter(this.p);

  @override
  void paint(Canvas canvas, Size boxSize) {
    canvas.scale(boxSize.width / size.width, boxSize.height / size.height);

    final fill = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = p.line;

    // Ground
    canvas.drawOval(
      const Rect.fromLTRB(20, 120, 148, 132),
      fill..color = p.accent.withValues(alpha: 0.12),
    );

    // Shop body
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTRB(28, 58, 140, 126),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      body,
      fill
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.bodyTop, p.bodyBottom],
        ).createShader(body.outerRect),
    );
    fill.shader = null;
    canvas.drawRRect(body, stroke);

    // Window with a glint
    final window = RRect.fromRectAndRadius(
      const Rect.fromLTRB(38, 82, 88, 114),
      const Radius.circular(5),
    );
    canvas.drawRRect(window, fill..color = p.glass);
    canvas.drawRRect(window, stroke);
    final thin = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..color = p.accent.withValues(alpha: 0.4);
    canvas.drawLine(const Offset(63, 82), const Offset(63, 114), thin);
    canvas.drawLine(const Offset(38, 98), const Offset(88, 98), thin);
    canvas.drawLine(
      const Offset(44, 108),
      const Offset(52, 90),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: p.dark ? 0.30 : 0.7),
    );

    // Door
    final door = Path()
      ..moveTo(98, 126)
      ..lineTo(98, 92)
      ..arcToPoint(const Offset(106, 84), radius: const Radius.circular(8))
      ..lineTo(122, 84)
      ..arcToPoint(const Offset(130, 92), radius: const Radius.circular(8))
      ..lineTo(130, 126)
      ..close();
    canvas.drawPath(door, fill..color = p.door);
    canvas.drawPath(door, stroke);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(104, 90, 124, 108),
        const Radius.circular(4),
      ),
      fill..color = p.glass,
    );
    canvas.drawCircle(const Offset(124, 112), 1.8, fill..color = p.accent);

    // Sign above the awning
    final sign = RRect.fromRectAndRadius(
      const Rect.fromLTRB(54, 14, 114, 32),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      sign,
      fill..color = p.dark ? const Color(0xFF0F2C2D) : AppColors.primaryDark,
    );
    canvas.drawRRect(sign, stroke);
    canvas.drawLine(
      const Offset(66, 23),
      const Offset(102, 23),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..color = p.accent.withValues(alpha: 0.85),
    );
    for (final x in [66.0, 102.0]) {
      canvas.drawLine(Offset(x, 32), Offset(x, 40), stroke);
    }

    // Awning: six stripes with a scalloped edge
    const left = 18.0, top = 40.0, stripe = 22.0, edge = 62.0;
    canvas.drawRect(
      const Rect.fromLTRB(28, 62, 140, 80),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: p.dark ? 0.28 : 0.10),
            Colors.black.withValues(alpha: 0),
          ],
        ).createShader(const Rect.fromLTRB(28, 62, 140, 80)),
    );
    for (var i = 0; i < 6; i++) {
      final x = left + i * stripe;
      final path = Path()
        ..moveTo(x, top)
        ..lineTo(x + stripe, top)
        ..lineTo(x + stripe, edge)
        ..arcToPoint(
          Offset(x, edge),
          radius: const Radius.circular(stripe / 2),
          clockwise: true,
        )
        ..close();
      canvas.drawPath(path, fill..color = i.isEven ? p.stripeA : p.stripeB);
    }
    // A highlight along the top of the awning and a fine outline on its edge.
    canvas.drawRect(
      const Rect.fromLTRB(left, top, left + 6 * stripe, top + 4),
      fill..color = Colors.white.withValues(alpha: 0.18),
    );
    final edgeLine = Path()..moveTo(left, edge);
    for (var i = 0; i < 6; i++) {
      edgeLine.arcToPoint(
        Offset(left + (i + 1) * stripe, edge),
        radius: const Radius.circular(stripe / 2),
        clockwise: false,
      );
    }
    canvas.drawPath(
      edgeLine,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black.withValues(alpha: p.dark ? 0.25 : 0.10),
    );

    // Plant in a pot, on the left
    final pot = Path()
      ..moveTo(6, 112)
      ..lineTo(24, 112)
      ..lineTo(22, 126)
      ..lineTo(8, 126)
      ..close();
    canvas.drawPath(pot, fill..color = p.door);
    canvas.drawPath(pot, stroke);
    final leaf = fill..color = p.accent.withValues(alpha: 0.8);
    for (final (tipX, tipY, ctrl) in [
      (4.0, 92.0, -6.0),
      (26.0, 90.0, 6.0),
      (15.0, 82.0, 0.0),
    ]) {
      final path = Path()
        ..moveTo(15, 112)
        ..quadraticBezierTo(15 + ctrl - 8, (112 + tipY) / 2, tipX, tipY)
        ..quadraticBezierTo(15 + ctrl + 8, (112 + tipY) / 2 + 2, 15, 112);
      canvas.drawPath(path, leaf);
    }

    // Sparkles
    for (final (cx, cy, r) in [
      (150.0, 30.0, 5.0),
      (140.0, 12.0, 3.0),
      (20.0, 36.0, 3.5),
    ]) {
      _sparkle(
        canvas,
        Offset(cx, cy),
        r,
        fill..color = p.accent.withValues(alpha: 0.65),
      );
    }
  }

  void _sparkle(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2;
      final tip = c + Offset(math.cos(a), math.sin(a)) * r;
      final next =
          c + Offset(math.cos(a + math.pi / 2), math.sin(a + math.pi / 2)) * r;
      if (i == 0) path.moveTo(tip.dx, tip.dy);
      path.quadraticBezierTo(c.dx, c.dy, next.dx, next.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_StorefrontPainter old) => old.p.dark != p.dark;
}
