import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/business_photos/photo_images.dart';
import '../../theme/app_theme.dart';

/// The big photo carousel at the top of a business's page: edge to edge, swiped
/// sideways, with dots and a count at the bottom. A photo is shown whole (never
/// cropped), over a blurred copy of itself that fills the empty space. Tapping
/// opens [BusinessPhotoViewer].
///
/// With no photo it shows a clean placeholder, and while the photos are still
/// being asked for a quiet loading state, so nothing flashes or breaks.
class BusinessPhotoGallery extends StatefulWidget {
  final List<GalleryPhoto> photos;

  /// The list of photos has not arrived yet.
  final bool loading;

  /// The colour of the business's category; tints the placeholder.
  final Color tint;
  final double height;

  const BusinessPhotoGallery({
    super.key,
    required this.photos,
    required this.tint,
    required this.height,
    this.loading = false,
  });

  @override
  State<BusinessPhotoGallery> createState() => _BusinessPhotoGalleryState();
}

class _BusinessPhotoGalleryState extends State<BusinessPhotoGallery> {
  final PageController _page = PageController();
  int _index = 0;

  @override
  void didUpdateWidget(BusinessPhotoGallery old) {
    super.didUpdateWidget(old);
    // The list changed (a photo was deleted or moved): stay on a photo that exists.
    if (_index >= widget.photos.length && widget.photos.isNotEmpty) {
      _index = widget.photos.length - 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _page.hasClients) _page.jumpToPage(_index);
      });
    }
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _open(int i) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => BusinessPhotoViewer(
        photos: widget.photos,
        start: i,
        onPage: (p) {
          if (_page.hasClients) _page.jumpToPage(p);
        },
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    final many = photos.length > 1;
    final index = photos.isEmpty ? 0 : _index.clamp(0, photos.length - 1);

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (photos.isEmpty)
            GalleryPlaceholder(tint: widget.tint, loading: widget.loading)
          else
            PageView.builder(
              controller: _page,
              itemCount: photos.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => Semantics(
                image: true,
                button: true,
                label: context.l10n.detailsPhotoLabel(i + 1, photos.length),
                child: GestureDetector(
                  onTap: () => _open(i),
                  child: _GalleryPage(photo: photos[i], tint: widget.tint),
                ),
              ),
            ),
          // Keeps the white buttons at the top readable over any photo.
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 110,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x73000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),
          ),
          if (many) ...[
            PositionedDirectional(
              bottom: 14,
              start: 0,
              end: 0,
              child: IgnorePointer(
                child: _Dots(count: photos.length, index: index),
              ),
            ),
            PositionedDirectional(
              bottom: 10,
              end: 12,
              child: IgnorePointer(
                child: _Counter('${index + 1}/${photos.length}'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One photo: whole, centred, over a blurred copy of itself.
class _GalleryPage extends StatelessWidget {
  final GalleryPhoto photo;
  final Color tint;
  const _GalleryPage({required this.photo, required this.tint});

  @override
  Widget build(BuildContext context) {
    final provider = BusinessPhotoImages.provider(photo);
    return Stack(
      fit: StackFit.expand,
      children: [
        _Backdrop(tint: tint),
        // The blurred copy only needs a small picture.
        ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: 26,
            sigmaY: 26,
            tileMode: TileMode.clamp,
          ),
          child: Image(
            image: ResizeImage.resizeIfNeeded(160, null, provider),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
        const ColoredBox(color: Color(0x2E000000)),
        Image(
          image: ResizeImage.resizeIfNeeded(1280, null, provider),
          fit: BoxFit.contain,
          // A spinner until the photo arrives (and no animation once it has),
          // then the photo fades in.
          frameBuilder: (_, child, frame, sync) => sync
              ? child
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    if (frame == null)
                      const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        ),
                      ),
                    AnimatedOpacity(
                      opacity: frame == null ? 0 : 1,
                      duration: const Duration(milliseconds: 220),
                      child: child,
                    ),
                  ],
                ),
          errorBuilder: (_, __, ___) =>
              _Backdrop(tint: tint, icon: Icons.image_not_supported_outlined),
        ),
      ],
    );
  }
}

class _Backdrop extends StatelessWidget {
  final Color tint;
  final IconData? icon;
  final bool spinner;
  const _Backdrop({required this.tint, this.icon, this.spinner = false});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [tint.withValues(alpha: 0.30), tint.withValues(alpha: 0.10)],
      ),
    ),
    child: Center(
      child: icon != null
          ? Icon(icon, size: 44, color: tint.withValues(alpha: 0.7))
          : spinner
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
          : null,
    ),
  );
}

/// What a business with no photo shows: its category's colour and a shop icon.
class GalleryPlaceholder extends StatelessWidget {
  final Color tint;
  final bool loading;
  const GalleryPlaceholder({
    super.key,
    required this.tint,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return _Backdrop(tint: tint, spinner: true);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tint.withValues(alpha: 0.30), tint.withValues(alpha: 0.08)],
        ),
      ),
      child: Center(
        child: Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tint.withValues(alpha: 0.16),
          ),
          child: Icon(Icons.storefront_rounded, size: 46, color: tint),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int index;
  const _Dots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < count; i++)
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: i == index ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: i == index
                ? Colors.white
                : Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
    ],
  );
}

class _Counter extends StatelessWidget {
  final String text;
  const _Counter(this.text);

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: AppText.caption,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

/// The photos full screen: swipe between them, pinch or double-tap to zoom.
class BusinessPhotoViewer extends StatefulWidget {
  final List<GalleryPhoto> photos;
  final int start;

  /// Told when another photo is shown, so the carousel behind can follow.
  final ValueChanged<int>? onPage;

  const BusinessPhotoViewer({
    super.key,
    required this.photos,
    this.start = 0,
    this.onPage,
  });

  @override
  State<BusinessPhotoViewer> createState() => _BusinessPhotoViewerState();
}

class _BusinessPhotoViewerState extends State<BusinessPhotoViewer> {
  late final PageController _page = PageController(initialPage: widget.start);
  late int _index = widget.start;

  /// A zoomed photo is moved with the finger, so swiping to the next one is
  /// switched off until it is back to normal size.
  bool _zoomed = false;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.photos.length;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _page,
            physics: _zoomed
                ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(),
            itemCount: n,
            onPageChanged: (i) {
              setState(() => _index = i);
              widget.onPage?.call(i);
            },
            itemBuilder: (_, i) => Semantics(
              image: true,
              label: context.l10n.detailsPhotoLabel(i + 1, n),
              child: _ZoomablePhoto(
                // A new page starts at normal size.
                key: ValueKey(widget.photos[i]),
                photo: widget.photos[i],
                onZoomed: (z) {
                  if (z != _zoomed && i == _index) setState(() => _zoomed = z);
                },
              ),
            ),
          ),
          // At the very top (a plain child of the stack would fill it and be centred).
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close_rounded),
                      color: Colors.white,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.45),
                      ),
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                    ),
                    const Spacer(),
                    _Counter('${_index + 1}/$n'),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomablePhoto extends StatefulWidget {
  final GalleryPhoto photo;
  final ValueChanged<bool> onZoomed;
  const _ZoomablePhoto({
    super.key,
    required this.photo,
    required this.onZoomed,
  });

  @override
  State<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<_ZoomablePhoto>
    with SingleTickerProviderStateMixin {
  static const double _doubleTapScale = 2.5;

  final TransformationController _transform = TransformationController();
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _anim,
    curve: Curves.easeOut,
  );
  Matrix4Tween? _tween;
  Offset _tapAt = Offset.zero;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _transform.addListener(() {
      final z = _transform.value.getMaxScaleOnAxis() > 1.02;
      if (z != _zoomed) {
        _zoomed = z;
        widget.onZoomed(z);
      }
    });
    _anim.addListener(() {
      final tween = _tween;
      if (tween != null) _transform.value = tween.evaluate(_curve);
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    _transform.dispose();
    super.dispose();
  }

  /// Double tap: zoom in on the spot that was tapped, or back out.
  void _toggleZoom() {
    final from = _transform.value;
    final Matrix4 to;
    if (from.getMaxScaleOnAxis() > 1.02) {
      to = Matrix4.identity();
    } else {
      const s = _doubleTapScale;
      // Scales around the tapped point: that point stays where it is.
      to = Matrix4(
        s,
        0,
        0,
        0, //
        0,
        s,
        0,
        0, //
        0,
        0,
        1,
        0, //
        -_tapAt.dx * (s - 1),
        -_tapAt.dy * (s - 1),
        0,
        1,
      );
    }
    _tween = Matrix4Tween(begin: from, end: to);
    _anim.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (d) => _tapAt = d.localPosition,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _transform,
        minScale: 1,
        maxScale: 5,
        child: SizedBox.expand(
          child: Image(
            image: ResizeImage.resizeIfNeeded(
              2048,
              null,
              BusinessPhotoImages.provider(widget.photo),
            ),
            fit: BoxFit.contain,
            frameBuilder: (_, child, frame, sync) => sync || frame != null
                ? child
                : const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        color: Colors.white70,
                      ),
                    ),
                  ),
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(
                Icons.image_not_supported_outlined,
                color: Colors.white54,
                size: 56,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
