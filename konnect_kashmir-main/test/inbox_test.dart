import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:konnect_kashmir/l10n/app_localizations_en.dart';
import 'package:konnect_kashmir/services/notifications/inbox_service.dart';

import 'support/fake_inbox_backend.dart';

void main() {
  late FakeInboxBackend backend;
  late InboxController inbox;
  late DateTime now;
  late ValueNotifier<int> push;

  setUp(() {
    backend = FakeInboxBackend();
    now = DateTime.utc(2026, 11, 6, 12);
    push = ValueNotifier<int>(0);
    inbox = InboxController(backend: backend, pushSignal: push, now: () => now);
  });

  tearDown(() => inbox.dispose());

  /// Lets the controller's own async work finish.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('a notification', () {
    test('is read from a row, and its type says what it is about', () {
      final n = AppNotification.fromRow({
        'id': 'n1',
        'user_id': 'u1',
        'vendor_id': 'v1',
        'type': 'photo_rejected',
        'title': ' Photo not approved ',
        'body':
            'Your photo for Orchid Cab Services was not approved: Inappropriate content.',
        'is_read': false,
        'created_at': '2026-11-06T09:00:00+00:00',
      });
      expect(n.kind, InboxKind.photoRejected);
      expect(n.title, 'Photo not approved');
      expect(n.vendorId, 'v1');
      expect(n.isRead, isFalse);
      expect(n.createdAt, DateTime.utc(2026, 11, 6, 9));
      expect(n.asRead().isRead, isTrue);
      expect(n.asRead().body, n.body);
    });

    test('types: the three photo ones, and anything else', () {
      expect(InboxKind.parse('photo_pending'), InboxKind.photoPending);
      expect(InboxKind.parse('photo_approved'), InboxKind.photoApproved);
      expect(InboxKind.parse('PHOTO_REJECTED'), InboxKind.photoRejected);
      expect(InboxKind.parse('something_new'), InboxKind.other);
      expect(InboxKind.parse(null), InboxKind.other);
      expect(InboxKind.photoPending.isPhoto, isTrue);
      expect(InboxKind.other.isPhoto, isFalse);
    });

    test('a row with missing parts still reads', () {
      final n = AppNotification.fromRow({'id': 7, 'is_read': null});
      expect(n.id, '7');
      expect(n.title, '');
      expect(n.vendorId, isNull);
      expect(n.createdAt, isNull);
      expect(n.isRead, isFalse);
    });
  });

  group('the bell', () {
    test('is not shown to a signed-out user', () async {
      backend.rows.add(note('a'));
      await inbox.refreshUnread(force: true);
      expect(inbox.visible, isFalse);
      expect(backend.calls, isEmpty);
    });

    test(
      'is shown once the server has answered, with the unread count',
      () async {
        backend.rows.addAll([note('a'), note('b'), note('c', read: true)]);
        inbox.setUser('u1');
        await settle();
        expect(inbox.visible, isTrue);
        expect(inbox.unread, 2);
      },
    );

    test('is not shown when the server has no notifications', () async {
      backend.unavailable = true;
      inbox.setUser('u1');
      await settle();
      expect(inbox.visible, isFalse);
      expect(inbox.unread, 0);
    });

    test('a failed count changes nothing, and is asked again soon', () async {
      backend.rows.add(note('a'));
      inbox.setUser('u1');
      await settle();
      expect(inbox.unread, 1);

      backend.failCount = true;
      await inbox.refreshUnread(force: true);
      expect(inbox.unread, 1, reason: 'what was shown stays');
      expect(inbox.visible, isTrue);

      backend.failCount = false;
      backend.rows.add(note('b'));
      await inbox.refreshUnread(); // no need to wait 20 seconds after a failure
      expect(inbox.unread, 2);
    });

    test('is asked for at most every 20 seconds, unless forced', () async {
      inbox.setUser('u1');
      await settle();
      int asked() => backend.calls.where((c) => c.startsWith('count')).length;
      expect(asked(), 1);

      await inbox.refreshUnread();
      expect(asked(), 1);
      now = now.add(const Duration(seconds: 19));
      await inbox.refreshUnread();
      expect(asked(), 1);
      now = now.add(const Duration(seconds: 2));
      await inbox.refreshUnread();
      expect(asked(), 2);
      await inbox.refreshUnread(force: true);
      expect(asked(), 3);
    });

    test('a push message that arrives makes it ask again at once', () async {
      inbox.setUser('u1');
      await settle();
      backend.rows.add(note('new', type: 'photo_approved'));
      push.value++;
      await settle();
      expect(inbox.unread, 1);
    });

    test('signing out hides it; another user starts from nothing', () async {
      backend.rows.add(note('a'));
      inbox.setUser('u1');
      await settle();
      expect(inbox.visible, isTrue);

      inbox.setUser(null);
      expect(inbox.visible, isFalse);
      expect(inbox.unread, 0);
      expect(inbox.items, isEmpty);

      inbox.setUser('u2');
      await settle();
      expect(backend.calls.last, 'count u2');
    });

    test('an answer that comes after the user changed is dropped', () async {
      backend.rows.addAll([note('a'), note('b'), note('c')]);
      backend.gate = Completer<void>();
      inbox.setUser('u1'); // its answer is held back
      await settle();
      inbox.setUser(null);
      backend.gate!.complete();
      await settle();
      expect(inbox.visible, isFalse);
      expect(inbox.unread, 0, reason: 'the old answer was not used');
    });
  });

  group('the list', () {
    test('has the newest first, and counts what is unread', () async {
      backend.rows.addAll([
        note('old', at: DateTime.utc(2026, 11, 1), read: true),
        note('mid', at: DateTime.utc(2026, 11, 3)),
        note('new', at: DateTime.utc(2026, 11, 5)),
      ]);
      inbox.setUser('u1');
      await inbox.load();
      expect(inbox.items.map((n) => n.id), ['new', 'mid', 'old']);
      expect(inbox.unread, 2);
      expect(inbox.loading, isFalse);
      expect(inbox.loadFailed, isFalse);
    });

    test('a failed load is told, not shown as empty', () async {
      inbox.setUser('u1');
      backend.failList = true;
      await inbox.load();
      expect(inbox.loadFailed, isTrue);
      expect(inbox.items, isEmpty);
      backend.failList = false;
      backend.rows.add(note('a'));
      await inbox.load();
      expect(inbox.loadFailed, isFalse);
      expect(inbox.items, hasLength(1));
    });

    test('marking one read changes it at once and tells the server', () async {
      backend.rows.addAll([
        note('a', at: DateTime.utc(2026, 11, 2)),
        note('b'),
      ]);
      inbox.setUser('u1');
      await inbox.load();
      expect(inbox.unread, 2);

      final first = inbox.items.first;
      final future = inbox.markRead(first);
      expect(
        inbox.items.first.isRead,
        isTrue,
        reason: 'at once, before the answer',
      );
      expect(inbox.unread, 1);
      await future;
      expect(backend.calls, contains('read ${first.id}'));
      expect(backend.rows.where((n) => n.isRead), hasLength(1));
    });

    test('marking one that is already read asks nothing', () async {
      backend.rows.add(note('a', read: true));
      inbox.setUser('u1');
      await inbox.load();
      backend.calls.clear();
      await inbox.markRead(inbox.items.single);
      expect(backend.calls, isEmpty);
    });

    test('if the server refuses, it is unread again', () async {
      backend.rows.addAll([note('a'), note('b')]);
      inbox.setUser('u1');
      await inbox.load();
      backend.failMark = true;
      await inbox.markRead(inbox.items.first);
      expect(inbox.unread, 2);
      expect(inbox.items.every((n) => !n.isRead), isTrue);
    });

    test('mark all read clears the count', () async {
      backend.rows.addAll([note('a'), note('b'), note('c')]);
      inbox.setUser('u1');
      await inbox.load();
      await inbox.markAllRead();
      expect(inbox.unread, 0);
      expect(inbox.items.every((n) => n.isRead), isTrue);
      expect(backend.calls, contains('readAll u1'));
    });

    test('mark all read, refused: back as it was', () async {
      backend.rows.addAll([note('a'), note('b')]);
      inbox.setUser('u1');
      await inbox.load();
      backend.failMark = true;
      await inbox.markAllRead();
      expect(inbox.unread, 2);
    });

    test('mark all read with nothing unread asks nothing', () async {
      backend.rows.add(note('a', read: true));
      inbox.setUser('u1');
      await inbox.load();
      backend.calls.clear();
      await inbox.markAllRead();
      expect(backend.calls, isEmpty);
    });
  });

  group('how long ago', () {
    final l = AppLocalizationsEn();
    final at = DateTime.utc(2026, 11, 6, 12);
    String ago(Duration d) => timeAgo(l, at.subtract(d), now: at);

    test('just now, minutes, hours, days', () {
      expect(ago(const Duration(seconds: 20)), 'Just now');
      expect(ago(const Duration(minutes: 5)), '5 min ago');
      expect(ago(const Duration(hours: 1)), '1 hour ago');
      expect(ago(const Duration(hours: 3)), '3 hours ago');
      expect(ago(const Duration(days: 1)), '1 day ago');
      expect(ago(const Duration(days: 4)), '4 days ago');
    });

    test('older than a week: the date; nothing known: nothing', () {
      expect(ago(const Duration(days: 20)), '17/10/2026');
      expect(timeAgo(l, null), '');
    });
  });

  group('the real backend, with its requests checked', () {
    late List<http.Request> sent;
    late SupabaseInboxBackend api;
    var status = 200;
    var headers = <String, String>{};
    var answer = '[]';

    setUp(() {
      sent = [];
      status = 200;
      headers = {};
      answer = '[]';
      api = SupabaseInboxBackend(
        token: () => 'user-token',
        client: MockClient((req) async {
          sent.add(req);
          return http.Response(answer, status, headers: headers);
        }),
      );
    });

    test('list: this user, newest first, with the user\'s token', () async {
      answer = jsonEncode([
        {
          'id': 'n1',
          'type': 'photo_approved',
          'title': 'Photo approved',
          'body': 'Your photo for X is now live.',
          'is_read': false,
          'created_at': '2026-11-06T09:00:00+00:00',
        },
      ]);
      final list = await api.list('u1');
      expect(list.single.title, 'Photo approved');
      final r = sent.single;
      expect(r.method, 'GET');
      expect(r.url.path, '/rest/v1/notifications');
      expect(r.url.queryParameters['user_id'], 'eq.u1');
      expect(r.url.queryParameters['order'], 'created_at.desc');
      expect(r.url.queryParameters['limit'], '50');
      expect(r.url.queryParameters['select'], contains('is_read'));
      expect(r.headers['Authorization'], 'Bearer user-token');
    });

    test('unread count: from the total the server reports', () async {
      headers = {'content-range': '0-0/12'};
      status = 206;
      expect(await api.unreadCount('u1'), 12);
      final r = sent.single;
      expect(r.url.queryParameters['is_read'], 'eq.false');
      expect(r.url.queryParameters['user_id'], 'eq.u1');
      expect(r.headers['Prefer'], 'count=exact');

      headers = {'content-range': '*/0'};
      status = 200;
      expect(await api.unreadCount('u1'), 0);
    });

    test(
      'no table, or no right to read it, is "unavailable", not an error',
      () async {
        status = 404;
        await expectLater(
          api.unreadCount('u1'),
          throwsA(isA<InboxUnavailable>()),
        );
        await expectLater(api.list('u1'), throwsA(isA<InboxUnavailable>()));
        status = 401;
        await expectLater(
          api.unreadCount('u1'),
          throwsA(isA<InboxUnavailable>()),
        );
        status = 500;
        await expectLater(
          api.unreadCount('u1'),
          throwsA(isNot(isA<InboxUnavailable>())),
        );
      },
    );

    test('mark read: only these messages, only is_read', () async {
      status = 204;
      await api.markRead(['a', 'b']);
      final r = sent.single;
      expect(r.method, 'PATCH');
      expect(r.url.queryParameters['id'], 'in.(a,b)');
      expect(jsonDecode(r.body), {'is_read': true});
      sent.clear();
      await api.markRead(const []);
      expect(sent, isEmpty);
    });

    test('mark all read: this user\'s unread ones', () async {
      status = 204;
      await api.markAllRead('u1');
      final r = sent.single;
      expect(r.method, 'PATCH');
      expect(r.url.queryParameters['user_id'], 'eq.u1');
      expect(r.url.queryParameters['is_read'], 'eq.false');
      expect(jsonDecode(r.body), {'is_read': true});
    });
  });
}
