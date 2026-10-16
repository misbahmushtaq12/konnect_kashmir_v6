import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/services/youtube_link.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

void main() {
  group('the three ads that are live', () {
    test('the second ad (Cilwana): v is not the first parameter', () {
      const url =
          'https://youtube.com/watch?si=-MBdUcf6jByJEwXS&v=TZ6I6E8cFew&feature=youtu.be';
      expect(YoutubeLink.videoId(url), 'TZ6I6E8cFew');
      // This is the bug: the player package alone finds nothing in this link.
      expect(YoutubePlayer.convertUrlToId(url), isNull);
    });

    test('the other two ads (youtu.be links)', () {
      expect(YoutubeLink.videoId('https://youtu.be/JGI42037uwQ?si=yNIwqOi5KXdWSkgB'),
          'JGI42037uwQ');
      expect(YoutubeLink.videoId('https://youtu.be/XFjYIXqWX-4?si=Cx2uAQnI2FBRrkU4'),
          'XFjYIXqWX-4');
    });
  });

  group('other ways a link can be copied', () {
    test('every form gives the same id', () {
      for (final url in [
        'https://www.youtube.com/watch?v=TZ6I6E8cFew',
        'https://youtube.com/watch?v=TZ6I6E8cFew&t=5s',
        'https://m.youtube.com/watch?feature=share&v=TZ6I6E8cFew',
        'https://music.youtube.com/watch?v=TZ6I6E8cFew',
        'https://youtu.be/TZ6I6E8cFew',
        'https://youtu.be/TZ6I6E8cFew/',
        'https://www.youtube.com/shorts/TZ6I6E8cFew',
        'https://www.youtube.com/embed/TZ6I6E8cFew?rel=0',
        'https://www.youtube-nocookie.com/embed/TZ6I6E8cFew',
        'https://www.youtube.com/live/TZ6I6E8cFew?si=abc',
        '  https://youtu.be/TZ6I6E8cFew  ',
        'TZ6I6E8cFew',
      ]) {
        expect(YoutubeLink.videoId(url), 'TZ6I6E8cFew', reason: url);
      }
    });

    test('a video id with - and _ is kept whole', () {
      expect(YoutubeLink.videoId('https://youtu.be/XFjYIXqWX-4'), 'XFjYIXqWX-4');
      expect(YoutubeLink.videoId('https://youtu.be/a_b-c_d-e_f'), 'a_b-c_d-e_f');
    });
  });

  group('not a video link', () {
    test('gives null instead of a wrong id', () {
      for (final bad in [
        '',
        '   ',
        'not a link',
        'https://example.com/watch?v=TZ6I6E8cFew',
        'https://youtube.com.evil.com/watch?v=TZ6I6E8cFew',
        'https://www.youtube.com/watch',
        'https://www.youtube.com/watch?v=short',
        'https://www.youtube.com/playlist?list=PLabcdefghijk',
        'https://www.youtube.com/@somechannel',
        'https://youtu.be/',
        'ftp://youtu.be/TZ6I6E8cFew',
        'TZ6I6E8cFe', // 10 characters
      ]) {
        expect(YoutubeLink.videoId(bad), isNull, reason: bad);
      }
    });
  });
}
