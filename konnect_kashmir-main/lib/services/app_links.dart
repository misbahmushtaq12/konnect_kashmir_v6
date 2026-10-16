/// Web links that open the app instead of the website.
///
/// The new-lead SMS carries https://konnectkashmir.com/go?utm_campaign=new_lead.
/// The website's /go page sends a phone to the App Store or Google Play (and
/// counts the click). Once the website proves the app belongs to it (see
/// docs/app-links-website-setup.md), a phone that already has the app opens the
/// app on My Business instead, with no change to the SMS.
class AppLinks {
  AppLinks._();

  /// The website's "get the app" page. Any link to it opens the app.
  static const String goPath = '/go';

  /// The older dashboard link. Opens the app on My Business as well.
  static const String leadsPath = '/vendor/dashboard';

  /// `utm_campaign` of the new-lead SMS: a /go link with it lands on My Business.
  static const String leadsCampaign = 'new_lead';

  static Uri? _parse(String? route) =>
      (route == null || route.isEmpty) ? null : Uri.tryParse(route);

  static String _path(Uri u) => u.path.replaceAll(RegExp(r'/+$'), '');

  static bool _isLeadsPath(String path) =>
      path == leadsPath || path.startsWith('$leadsPath/');

  /// Whether [route] (a path such as "/go?utm_campaign=new_lead", or a full
  /// address) is a link the app should take over.
  static bool isAppLink(String? route) {
    final u = _parse(route);
    if (u == null) return false;
    final path = _path(u);
    return path == goPath || _isLeadsPath(path);
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
