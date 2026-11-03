import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/business_share.dart';

/// A small, quiet share icon for a business. It opens the phone's share sheet
/// with the business's own details and its link (see business_share.dart).
///
/// It uses the platform's own share symbol (the box with an arrow on iPhone,
/// the three linked dots on Android) so people recognise it at a glance.
class ShareBusinessButton extends StatelessWidget {
  final BusinessShareData data;
  final double size;

  /// Drawn over a photo: a white icon on a dark disc, so it shows on any picture.
  final bool overImage;
  const ShareBusinessButton({
    super.key,
    required this.data,
    this.size = 20,
    this.overImage = false,
  });

  static bool get _apple =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: () => shareBusiness(context, data),
      tooltip: context.l10n.shareBusiness,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      style: overImage
          ? IconButton.styleFrom(
              backgroundColor: Colors.black.withValues(alpha: 0.45),
            )
          : null,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      icon: Icon(
        _apple ? Icons.ios_share_rounded : Icons.share_rounded,
        size: size,
        color: overImage ? Colors.white : cs.onSurface.withValues(alpha: 0.62),
      ),
    );
  }
}
