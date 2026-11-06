import 'package:flutter/foundation.dart';

/// Web links that open the app instead of the website.
///
/// The new-lead SMS carries https://konnectkashmir.com/go?utm_campaign=new_lead.
/// The website's /go page sends a phone to the App Store or Google Play (and
/// counts the click). Once the website proves the app belongs to it (see
/// docs/app-links-website-setup.md), a phone that already has the app opens the
/// app on My Business instead, with no change to the SMS.
///
/// A shared business (the website's `/business/<id>` page) opens the app on that
/// business.
class AppLinks {
  AppLinks._();

  /// The website's "get the app" page. Any link to it opens the app.
  static const String goPath = '/go';

  /// The older dashboard link. Opens the app on My Business as well.
  static const String leadsPath = '/vendor/dashboard';

  /// A shared business: `/business/<id>`.
  static const String businessPath = '/business';

  /// The business a link asked for, waiting for the Home screen to show it. It
  /// is set by a link (while the app starts or runs) and cleared by whoever shows
  /// the business, so it also survives a sign-in in between.
  static final ValueNotifier<String?> businessRequest = ValueNotifier<String?>(null);

  /// `utm_campaign` of the new-lead SMS: a /go link with it lands on My Business.
  static const String leadsCampaign = 'new_lead';

  static Uri? _parse(String? route) =>
      (route == null || route.isEmpty) ? null : Uri.tryParse(route);

  static String _path(Uri u) => u.path.replaceAll(RegExp(r'/+$'), '');

  static bool _isLeadsPath(String path) =>
      path == leadsPath || path.startsWith('$leadsPath/');

  /// Whether [route] (a path such as "/go?utm_campaign=new_lead", or a full
  /// address) is a link the app should take over.
  ///
  /// Every `/business/...` address counts, even one with an id the app refuses
  /// (see [businessId]): the phone hands the app everything under `/business/`
  /// (that is what the app declares), so the app has to take it in and just open
  /// as usual. Leaving it out would be an unknown route, an error, instead.
  static bool isAppLink(String? route) {
    final u = _parse(route);
    if (u == null) return false;
    final path = _path(u);
    return path == goPath || _isLeadsPath(path) || isBusinessLink(route);
  }

  /// Whether [route] is under `/business/` at all, whatever follows (an id the
  /// app accepts, see [businessId], or not).
  static bool isBusinessLink(String? route) {
    final u = _parse(route);
    if (u == null) return false;
    final parts = u.pathSegments.where((s) => s.isNotEmpty).toList();
    return parts.length >= 2 && '/${parts.first}' == businessPath;
  }

  /// The id in a `/business/<id>` link, or null. Only plain ids (letters, digits,
  /// dashes) are accepted: the id is put into a database filter, so anything else
  /// is not a business link.
  static String? businessId(String? route) {
    final u = _parse(route);
    if (u == null) return null;
    final parts = u.pathSegments.where((s) => s.isNotEmpty).toList();
    if (parts.length != 2 || '/${parts.first}' != businessPath) return null;
    final id = parts[1];
    return RegExp(r'^[A-Za-z0-9-]{1,64}$').hasMatch(id) ? id : null;
  }

  /// Whether [route] should land on My Business (where the leads are).
  static bool isLeadsLink(String? route) {
    final u = _parse(route);
    if (u == null) return false;
    final path = _path(u);
    if (_isLeadsPath(path)) return true;
    return path == goPath && u.queryParameters['utm_campaign'] == leadsCampaign;
  }
}
