import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/services/deen_events.dart';

class _Sent {
  final String table;
  final Map<String, Object?> row;
  final String bearer;
  _Sent(this.table, this.row, this.bearer);
}

DeenEvents _make(
  List<_Sent> sent, {
  List<int> answers = const [201],
  String? token,
  String? userId,
  bool started = true,
}) {
  var i = 0;
  final e = DeenEvents(
    poster: (table, row, bearer) async {
      sent.add(_Sent(table, row, bearer));
      return answers[i < answers.length ? i++ : answers.length - 1];
    },
    sessionId: () => 'session-1',
    started: started,
  );
  if (started) e.start(token: () => token, userId: () => userId);
  return e;
}

void main() {
  group('what is written', () {
    test('an audio event has the website\'s columns and source app', () async {
      final sent = <_Sent>[];
      _make(sent).audio('play', reciterId: 'rec-1', surah: 36);
      await pumpEventQueue();
      expect(sent.single.table, 'audio_play_events');
      expect(sent.single.row, {
        'event_type': 'play',
        'track_id': null,
        'reciter_id': 'rec-1',
        'surah_number': 36,
        'listened_seconds': 0,
        'source': 'app',
        'session_id': 'session-1',
        'user_id': null,
      });
    });

    test('listened seconds are kept between 0 and a day', () async {
      final sent = <_Sent>[];
      final e = _make(sent);
      e.audio('pause', reciterId: 'r', surah: 1, seconds: 42);
      e.audio('stop', reciterId: 'r', surah: 1, seconds: -5);
      e.audio('complete', reciterId: 'r', surah: 1, seconds: 999999);
      await pumpEventQueue();
      expect(sent.map((s) => s.row['listened_seconds']), [42, 0, 86400]);
      expect(sent.map((s) => s.row['event_type']), ['pause', 'stop', 'complete']);
    });

    test('the built-in reciters have no id: the row says so', () async {
      final sent = <_Sent>[];
      _make(sent).audio('play', surah: 2);
      await pumpEventQueue();
      expect(sent.single.row['reciter_id'], isNull);
      expect(sent.single.row['surah_number'], 2);
    });

    test('a Deen event keeps only the fields the dashboard reads, cut to length', () async {
      final sent = <_Sent>[];
      final e = _make(sent);
      e.deen('page_view');
      e.deen('madhhab_change', {'madhhab': 'hanafi', 'secret': 'x', 'phone': '+91'});
      e.deen('method_change', {'method': 'm' * 200});
      await pumpEventQueue();
      expect(sent.every((s) => s.table == 'deen_events'), isTrue);
      expect(sent[0].row, {
        'event_type': 'page_view',
        'meta': <String, String>{},
        'session_id': 'session-1',
        'source': 'app',
        'user_id': null,
      });
      expect(sent[1].row['meta'], {'madhhab': 'hanafi'});
      expect((sent[2].row['meta'] as Map)['method'], hasLength(80));
    });

    test('an event name the database does not know is not sent', () async {
      final sent = <_Sent>[];
      final e = _make(sent);
      e.audio('rewind');
      e.deen('dua_view');
      await pumpEventQueue();
      expect(sent, isEmpty);
    });

    test('nothing is sent before start', () async {
      final sent = <_Sent>[];
      final e = _make(sent, started: false);
      e.audio('play', surah: 1);
      e.deen('page_view');
      await pumpEventQueue();
      expect(sent, isEmpty);
    });
  });

  group('who sends it', () {
    test('signed in: the person\'s own token and id', () async {
      final sent = <_Sent>[];
      _make(sent, token: 'user-token', userId: 'user-1').deen('page_view');
      await pumpEventQueue();
      expect(sent.single.bearer, 'user-token');
      expect(sent.single.row['user_id'], 'user-1');
    });

    test('signed out: the public key and no id', () async {
      final sent = <_Sent>[];
      _make(sent).deen('page_view');
      await pumpEventQueue();
      expect(sent.single.bearer, isNot('user-token'));
      expect(sent.single.row['user_id'], isNull);
    });

    test('a refused token (expired or by policy) is retried once, anonymously', () async {
      for (final refused in [401, 403]) {
        final sent = <_Sent>[];
        _make(
          sent,
          answers: [refused, 201],
          token: 'user-token',
          userId: 'user-1',
        ).audio('play', reciterId: 'r', surah: 3);
        await pumpEventQueue();
        expect(sent.length, 2, reason: '$refused');
        expect(sent[0].bearer, 'user-token');
        expect(sent[1].bearer, isNot('user-token'));
        expect(sent[1].row['user_id'], isNull);
        expect(sent[1].row['surah_number'], 3);
      }
    });

    test('other errors are not retried', () async {
      for (final code in [400, 404, 500]) {
        final sent = <_Sent>[];
        _make(sent, answers: [code], token: 't', userId: 'u')
            .deen('page_view');
        await pumpEventQueue();
        expect(sent.length, 1, reason: '$code');
      }
    });

    test('a failing network never throws into the app', () async {
      final e = DeenEvents(
        poster: (_, __, ___) async => throw Exception('offline'),
        sessionId: () => 's',
        started: true,
      );
      e.audio('play', surah: 1);
      e.deen('page_view');
      await pumpEventQueue();
      expect(true, isTrue); // reaching here is the test
    });
  });
}
