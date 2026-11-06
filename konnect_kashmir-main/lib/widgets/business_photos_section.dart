import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/business_photos/business_photo_service.dart'
    show PhotoStatus;
import '../services/business_photos/business_photos_controller.dart';
import '../services/business_photos/photo_images.dart';
import '../services/business_photos/photo_rules.dart';
import '../theme/app_theme.dart';
import 'app_snack.dart';

/// The "Business Photos" part of the listing form: the photos so far, a dashed
/// "Add photos" tile, and for each photo buttons to move it earlier or later and
/// to delete it. Used for a new listing and for editing one.
class BusinessPhotosSection extends StatelessWidget {
  final BusinessPhotosController controller;
  const BusinessPhotosSection({super.key, required this.controller});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => _content(context),
  );

  Widget _content(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.55);
    final items = controller.items;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.photo_camera_outlined,
              color: AppColors.primaryLight,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                l.businessPhotos,
                style: const TextStyle(
                  fontSize: AppText.heading,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _Tag(l.optionalTag),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          l.photosSubtitle(kMaxBusinessPhotos),
          style: TextStyle(color: muted, fontSize: AppText.secondary),
        ),
        const SizedBox(height: 10),
        Text(
          l.photosCount(controller.count, kMaxBusinessPhotos),
          style: const TextStyle(
            fontSize: AppText.secondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, c) {
            const gap = 8.0;
            final cols = c.maxWidth >= 480 ? 4 : 3;
            final size = (c.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                _AddTile(
                  size: size,
                  enabled: !controller.busy && !controller.atLimit,
                  working: controller.busy && !controller.loading,
                  label: l.addPhotos,
                  onTap: () => _add(context),
                ),
                for (var i = 0; i < items.length; i++)
                  _photoTile(context, i, size),
                // Two empty frames show where photos will go.
                if (items.isEmpty)
                  for (var i = 0; i < 2; i++)
                    _EmptyTile(size: size, loading: controller.loading),
              ],
            );
          },
        ),
        if (controller.atLimit) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: AppColors.warning,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l.photosLimitReached(kMaxBusinessPhotos),
                  style: TextStyle(color: muted, fontSize: AppText.caption),
                ),
              ),
            ],
          ),
        ],
        if (controller.loadFailed) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  l.photosLoadFailed,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: AppText.caption,
                  ),
                ),
              ),
              if (controller.editing)
                TextButton(
                  onPressed: controller.busy ? null : controller.load,
                  child: Text(l.retry),
                ),
            ],
          ),
        ],
        if (!controller.editing && controller.hasPending) ...[
          const SizedBox(height: 8),
          Text(
            l.photosUploadedOnSubmit,
            style: TextStyle(color: muted, fontSize: AppText.caption),
          ),
        ],
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.verified_user_outlined, size: 14, color: muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l.photosShownAfterReview,
                style: TextStyle(color: muted, fontSize: AppText.caption),
              ),
            ),
          ],
        ),
        if (controller.notes.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final n in controller.notes.take(_shownNotes))
            Text(
              l.photoCompressed(n.name, n.beforeKb, n.afterKb),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: muted, fontSize: AppText.caption),
            ),
          if (controller.notes.length > _shownNotes)
            Text(
              l.photoCompressedMore(controller.notes.length - _shownNotes),
              style: TextStyle(color: muted, fontSize: AppText.caption),
            ),
        ],
      ],
    );
  }

  static const int _shownNotes = 5;

  Widget _photoTile(BuildContext context, int i, double size) {
    final l = context.l10n;
    final item = controller.items[i];
    final status = item.saved?.status;
    final waiting = status == PhotoStatus.pending;
    final rejected = status == PhotoStatus.rejected;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final idle = !controller.busy;
    final last = i == controller.items.length - 1;
    // Every button has a 44 px touch area (its look is smaller); two of them
    // fit side by side even on the narrowest tile.
    final hit = math.min(44.0, (size - 2) / 2);

    final frame = rejected
        ? AppColors.danger
        : waiting
        ? AppColors.warning
        : null;

    final thumb = SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // A photo that was not approved is dimmed.
            Opacity(
              opacity: rejected ? 0.55 : 1,
              child: _Thumb(item: item),
            ),
            if (frame != null)
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: frame, width: 2),
                  ),
                ),
              ),
            if (item.uploading)
              const ColoredBox(
                color: Color(0x80000000),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  ),
                ),
              )
            else ...[
              PositionedDirectional(
                top: 4,
                start: 4,
                child: _Badge('${i + 1}'),
              ),
              PositionedDirectional(
                top: 0,
                end: 0,
                child: _TileButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: l.deletePhoto,
                  hit: hit,
                  onTap: idle ? () => _delete(context, i) : null,
                ),
              ),
              PositionedDirectional(
                bottom: 0,
                start: 0,
                child: _TileButton(
                  icon: rtl ? Icons.chevron_right : Icons.chevron_left,
                  tooltip: l.movePhotoEarlier,
                  hit: hit,
                  onTap: idle && i > 0 ? () => _move(context, i, -1) : null,
                ),
              ),
              PositionedDirectional(
                bottom: 0,
                end: 0,
                child: _TileButton(
                  icon: rtl ? Icons.chevron_left : Icons.chevron_right,
                  tooltip: l.movePhotoLater,
                  hit: hit,
                  onTap: idle && !last ? () => _move(context, i, 1) : null,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (status == null || status == PhotoStatus.approved) return thumb;
    return SizedBox(
      width: size,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          thumb,
          _StatusNote(
            key: ValueKey<String>('status-$i'),
            status: status,
            reason: item.saved?.rejectionReason,
          ),
        ],
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _add(BuildContext context) async {
    final result = await controller.add();
    if (!context.mounted) return;
    final lines = problemMessages(context, result);
    if (lines.isEmpty) return;
    showAppSnack(
      context,
      lines.join('\n'),
      type: result.failed.isNotEmpty ? SnackType.error : SnackType.warning,
      duration: const Duration(seconds: 5),
    );
  }

  Future<void> _move(BuildContext context, int i, int delta) async {
    final l = context.l10n;
    final ok = await controller.move(i, delta);
    if (!context.mounted || ok) return;
    showAppSnack(context, l.photoMoveFailed, type: SnackType.error);
  }

  Future<void> _delete(BuildContext context, int i) async {
    final l = context.l10n;
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.deletePhotoTitle),
        content: Text(ctx.l10n.deletePhotoBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              ctx.l10n.deletePhoto,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (sure != true || !context.mounted) return;
    final ok = await controller.remove(i);
    if (!context.mounted || ok) return;
    showAppSnack(context, l.photoDeleteFailed, type: SnackType.error);
  }
}

/// What to tell the owner after photos were added: the limit, files that were
/// skipped, uploads that failed. Empty when all went well.
List<String> problemMessages(BuildContext context, PhotoAddResult r) {
  final l = context.l10n;
  final out = <String>[];
  if (r.skippedForLimit > 0) {
    out.add(l.photosNotAddedLimit(r.skippedForLimit, kMaxBusinessPhotos));
  } else if (r.limitHit) {
    out.add(l.photosLimitReached(kMaxBusinessPhotos));
  }
  const mb = kMaxPhotoFileBytes ~/ (1024 * 1024);
  if (r.rejected.length == 1) {
    final f = r.rejected.first;
    out.add(switch (f.problem) {
      PhotoProblem.tooLarge => l.photoTooLarge(f.name, mb),
      PhotoProblem.unsupportedType => l.photoUnsupported(f.name),
      _ => l.photoUnreadable(f.name),
    });
  } else if (r.rejected.length > 1) {
    out.add(l.photosSkipped(r.rejected.length, mb));
  }
  if (r.failed.isNotEmpty && !r.limitHit) {
    out.add(l.photosUploadFailed(r.failed.length));
  }
  return out;
}

// ── Pieces ───────────────────────────────────────────────────────────────────

class _Thumb extends StatelessWidget {
  final PhotoItem item;
  const _Thumb({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget broken() => ColoredBox(
      color: cs.onSurface.withValues(alpha: 0.08),
      child: Icon(
        Icons.broken_image_outlined,
        color: cs.onSurface.withValues(alpha: 0.4),
      ),
    );

    final pending = item.pending;
    if (pending != null) {
      return Image.memory(
        pending.watermarked,
        fit: BoxFit.cover,
        cacheWidth: 360,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => broken(),
      );
    }
    final g = item.saved?.forGallery;
    if (g == null) return broken();
    return Image(
      image: ResizeImage.resizeIfNeeded(
        360,
        null,
        BusinessPhotoImages.provider(g),
      ),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      frameBuilder: (_, child, frame, sync) => frame == null && !sync
          ? ColoredBox(color: cs.onSurface.withValues(alpha: 0.06))
          : child,
      errorBuilder: (_, __, ___) => broken(),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag(this.text);

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: AppColors.primary.withValues(alpha: 0.45)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.primaryLight,
          fontSize: AppText.caption,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge(this.text);

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: AppText.caption,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _TileButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  /// The size of the touch area (the round button drawn in it is smaller).
  final double hit;
  const _TileButton({
    required this.icon,
    required this.tooltip,
    required this.hit,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onTap == null ? 0.35 : 1,
    child: Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: hit / 2,
        child: SizedBox(
          width: hit,
          height: hit,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: SizedBox(
                width: 30,
                height: 30,
                child: Icon(icon, size: 18, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// What an admin decided about a photo, under its tile: "Under review", or "Not
/// approved" with the reason (tap to read all of it).
class _StatusNote extends StatelessWidget {
  final PhotoStatus status;
  final String? reason;
  const _StatusNote({super.key, required this.status, this.reason});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final rejected = status == PhotoStatus.rejected;
    final color = rejected ? AppColors.danger : AppColors.warning;
    final text = !rejected
        ? l.photoUnderReview
        : (reason == null
              ? l.photoNotApproved
              : l.photoNotApprovedReason(reason!));
    final note = Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            rejected
                ? Icons.error_outline_rounded
                : Icons.hourglass_top_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: AppText.caption,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      container: true,
      label: text,
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: rejected && reason != null
              ? InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(ctx.l10n.photoReasonTitle),
                      content: Text(reason!),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(ctx.l10n.ok),
                        ),
                      ],
                    ),
                  ),
                  child: note,
                )
              : note,
        ),
      ),
    );
  }
}

class _EmptyTile extends StatelessWidget {
  final double size;
  final bool loading;
  const _EmptyTile({required this.size, required this.loading});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              )
            : Icon(
                Icons.image_outlined,
                size: 34,
                color: cs.onSurface.withValues(alpha: 0.22),
              ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  final double size;
  final bool enabled;
  final bool working;
  final String label;
  final VoidCallback onTap;
  const _AddTile({
    required this.size,
    required this.enabled,
    required this.working,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.primaryLight.withValues(alpha: enabled ? 1 : 0.4);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: enabled ? onTap : null,
        child: CustomPaint(
          painter: _DashedBorder(color: color, radius: AppRadius.sm),
          child: SizedBox(
            width: size,
            height: size,
            child: Padding(
              padding: const EdgeInsets.all(4),
              // Large text or a narrow phone: the content shrinks to fit the tile.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    working
                        ? SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: color,
                            ),
                          )
                        : Icon(
                            Icons.photo_camera_outlined,
                            size: 30,
                            color: color,
                          ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface
                              .withValues(alpha: enabled ? 1 : 0.45),
                          fontSize: AppText.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  final Color color;
  final double radius;
  const _DashedBorder({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.7),
          Radius.circular(radius),
        ),
      );
    const dash = 6.0, space = 4.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + dash, metric.length)),
          paint,
        );
        d += dash + space;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) =>
      old.color != color || old.radius != radius;
}
