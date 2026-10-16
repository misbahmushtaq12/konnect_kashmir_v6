/// Finds the video id inside a YouTube link, for the ads people watch for credits.
///
/// The player package only understands `youtube.com/watch?v=ID` with `v` as the
/// FIRST parameter. YouTube's own "Copy link" on a phone can give
/// `youtube.com/watch?si=XXXX&v=ID&feature=youtu.be` (v is not first), which the
/// package turns into "no video" and the player then shows "The request contains
/// an invalid parameter value" (error 2). This reads the link properly instead.
class YoutubeLink {
  YoutubeLink._();

  static final RegExp _id = RegExp(r'^[A-Za-z0-9_-]{11}$');

  /// The 11-character video id in [input] (a link, or the id itself), or null if
  /// it is not a link to a YouTube video.
  static String? videoId(String input) {
    final s = input.trim();
    if (_id.hasMatch(s)) return s;

    final u = Uri.tryParse(s);
    if (u == null || (u.scheme != 'https' && u.scheme != 'http')) return null;

    final host = u.host.toLowerCase();
    final seg = u.pathSegments.where((p) => p.isNotEmpty).toList();
    String? candidate;

    if (host == 'youtu.be') {
      // youtu.be/ID?si=...
      candidate = seg.isNotEmpty ? seg.first : null;
    } else if (_isYoutubeHost(host)) {
      if (seg.isNotEmpty && seg.first == 'watch') {
        // youtube.com/watch?v=ID, with v anywhere in the query
        candidate = u.queryParameters['v'];
      } else if (seg.length >= 2 &&
          const {'shorts', 'embed', 'live', 'v'}.contains(seg.first)) {
        // youtube.com/shorts/ID, /embed/ID, /live/ID
        candidate = seg[1];
      }
    }
    return (candidate != null && _id.hasMatch(candidate)) ? candidate : null;
  }

  static bool _isYoutubeHost(String host) =>
      host == 'youtube.com' ||
      host.endsWith('.youtube.com') ||
      host == 'youtube-nocookie.com' ||
      host.endsWith('.youtube-nocookie.com');
}
