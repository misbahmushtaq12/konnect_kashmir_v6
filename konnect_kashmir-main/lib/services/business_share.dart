import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../widgets/app_snack.dart';
import 'app_analytics.dart';

/// The website page of one business. It is a real page: the website's
/// `/business/:id` route loads the business whose `vendors_public.id` is in the
/// address (the same id the app holds), and the app opens it directly when it is
/// installed (see AppLinks).
String? businessUrl(Object? id) {
  final s = id?.toString().trim() ?? '';
  if (s.isEmpty || s == 'null') return null;
  return 'https://konnectkashmir.com/business/${Uri.encodeComponent(s)}';
}

/// What is known about a business at the moment it is shared. Every part except
/// the name may be empty; empty parts are simply left out.
///
/// [address] and [phone] are only filled in after the user has unlocked this
/// business's contact. Locked contacts cost credits, so sharing must not hand
/// them out for free: a locked business is shared with its area only.
class BusinessShareData {
  final Object? id;
  final String name;
  final String category;
  final String locality;
  final String address;
  final String phone;
  const BusinessShareData({
    required this.id,
    required this.name,
    this.category = '',
    this.locality = '',
    this.address = '',
    this.phone = '',
  });
}

/// The message that is shared: built only from [d], never from fixed details.
///
///     Check out Sajad Khatmband on Konnect Kashmir
///     Category: Carpenter
///     Address: Noorbagh, Srinagar
///     Phone: +91 9876543210
///
///     View details: https://konnectkashmir.com/business/<id>
///
/// Without an id there is no page to point to, so no link is invented: the
/// message is just the business information.
String businessShareText(AppLocalizations l, BusinessShareData d) {
  String t(String s) => s.trim();
  final name = t(d.name);
  final category = t(d.category);
  final locality = t(d.locality);
  final address = t(d.address);
  var phone = t(d.phone);
  if (phone.isNotEmpty && !phone.startsWith('+')) phone = '+91 $phone';

  final info = <String>[
    if (name.isNotEmpty) l.shareBusinessIntro(name),
    if (category.isNotEmpty) l.shareBusinessCategory(category),
    if (address.isNotEmpty)
      l.shareBusinessAddress(
        // The area is added only if the address does not already say it.
        locality.isNotEmpty &&
                !address.toLowerCase().contains(locality.toLowerCase())
            ? '$address, $locality'
            : address,
      )
    else if (locality.isNotEmpty)
      l.shareBusinessArea(locality),
    if (phone.isNotEmpty) l.shareBusinessPhone(phone),
  ];
  final url = businessUrl(d.id);
  return [
    info.join('\n'),
    if (url != null) l.shareBusinessLink(url),
  ].where((s) => s.isNotEmpty).join('\n\n');
}

typedef ShareSender = Future<ShareResult> Function(ShareParams params);

/// Opens the phone's own share sheet (WhatsApp, Messages, Instagram, ...).
/// Returns false, after telling the user, if it could not be opened.
Future<bool> shareBusiness(
  BuildContext context,
  BusinessShareData data, {
  ShareSender? sender,
}) async {
  final l = AppLocalizations.of(context);
  // On an iPad the share sheet is a popover and must know where to point.
  final box = context.findRenderObject();
  final origin = box is RenderBox && box.hasSize
      ? box.localToGlobal(Offset.zero) & box.size
      : null;
  try {
    await (sender ?? SharePlus.instance.share)(
      ShareParams(
        text: businessShareText(l, data),
        subject: data.name.trim().isEmpty ? null : data.name.trim(),
        sharePositionOrigin: origin,
      ),
    );
    AppAnalytics.instance.shareBusiness(data.id);
    return true;
  } catch (e) {
    debugPrint('[Share] could not open the share sheet: $e');
    if (context.mounted) {
      showAppSnack(context, l.shareBusinessFailed, type: SnackType.error);
    }
    return false;
  }
}
