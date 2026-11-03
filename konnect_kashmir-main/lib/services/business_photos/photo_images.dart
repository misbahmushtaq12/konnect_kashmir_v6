import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';

import 'business_photo_service.dart';

/// A picture to show: where to get it, and the name it keeps in the image cache.
class GalleryPhoto {
  final String cacheKey;
  final String url;
  const GalleryPhoto({required this.cacheKey, required this.url});

  @override
  bool operator ==(Object other) =>
      other is GalleryPhoto && other.cacheKey == cacheKey && other.url == url;

  @override
  int get hashCode => Object.hash(cacheKey, url);
}

extension BusinessPhotoToGallery on BusinessPhoto {
  /// The photo for display, or null when it has no signed link.
  GalleryPhoto? get forGallery =>
      url == null ? null : GalleryPhoto(cacheKey: cacheKey, url: url!);
}

typedef PhotoImageFactory = ImageProvider Function(GalleryPhoto photo);

/// How photos are fetched for display. The app keeps them on disk and in memory
/// under a name that does not change when the signed link is renewed, so a photo
/// is downloaded once and not again each time a new link is made. The tests
/// replace [factory] so no network is used.
class BusinessPhotoImages {
  BusinessPhotoImages._();

  static PhotoImageFactory factory = (photo) =>
      CachedNetworkImageProvider(photo.url, cacheKey: photo.cacheKey);

  static ImageProvider provider(GalleryPhoto photo) => factory(photo);
}
