import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../l10n/l10n.dart';
import '../backend_config.dart';
import '../shared_http.dart';

/// What a notification is about. The server writes the `type`; one we do not know
/// is [other] and is shown like any other message.
enum InboxKind {
  photoPending,
  photoApproved,
  photoRejected,
  other;

  static InboxKind parse(Object? type) =>
      switch ('$type'.trim().toLowerCase()) {
        'photo_pending' => photoPending,
        'photo_approved' => photoApproved,
        'photo_rejected' => photoRejected,
        _ => other,
      };

  bool get isPhoto => this != other;
}

/// One row of `notifications`: a message for the signed-in user. The server makes
/// them (an upload, an approval, a rejection); the app only reads them and marks
/// them read.
@immutable
class AppNotification {
  final String id;
  final String? vendorId;
  final String type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    this.vendorId,
    required this.type,
    required this.title,
    required this.body,
    this.isRead = false,
    this.createdAt,
  });

  InboxKind get kind => InboxKind.parse(type);

  factory AppNotification.fromRow(Map<String, dynamic> row) => AppNotification(
    id: '${row['id']}',
    vendorId: row['vendor_id'] == null ? null : '${row['vendor_id']}',
    type: '${row['type'] ?? ''}',
    title: '${row['title'] ?? ''}'.trim(),
    body: '${row['body'] ?? ''}'.trim(),
    isRead: row['is_read'] == true,
    createdAt: DateTime.tryParse('${row['created_at'] ?? ''}'),
  );

  AppNotification asRead() => AppNotification(
    id: id,
    vendorId: vendorId,
    type: type,
    title: title,
    body: body,
    isRead: true,
    createdAt: createdAt,
  );
}

/// The server: the `notifications` table, read with the user's own token.
abstract class InboxBackend {
  /// The newest messages of [userId], newest first.
  Future<List<AppNotification>> list(String userId, {int limit = 50});

  /// How many of them are unread. Throws [InboxUnavailable] when the server has
  /// no such table (the feature is not there yet).
  Future<int> unreadCount(String userId);

  Future<void> markRead(List<String> ids);
  Future<void> markAllRead(String userId);
}

/// The notifications cannot be read on this server (no table, or no access).
class InboxUnavailable implements Exception {
  const InboxUnavailable();
}

class SupabaseInboxBackend implements InboxBackend {
  final String? Function() _token;
  final http.Client _client;

  SupabaseInboxBackend({String? Function()? token, http.Client? client})
    : _token = token ?? (() => null),
      _client = client ?? sharedHttp;

  static const Duration _timeout = Duration(seconds: 20);

  Map<String, String> _headers([Map<String, String>? more]) => {
    'apikey': kSupabaseAnonKey,
    'Authorization': 'Bearer ${_token() ?? kSupabaseAnonKey}',
    ...?more,
  };

  Uri _rest(Map<String, String> query) => Uri.parse(
    '$kSupabaseUrl/rest/v1/notifications',
  ).replace(queryParameters: query);

  Exception _failure(http.Response res) {
    // No table (PGRST205 / 404) or no right to read it: not an error to show.
    if (res.statusCode == 404 ||
        res.statusCode == 401 ||
        res.statusCode == 403) {
      return const InboxUnavailable();
    }
    return Exception('Notifications unavailable (${res.statusCode})');
  }

  @override
  Future<List<AppNotification>> list(String userId, {int limit = 50}) async {
    final res = await _client
        .get(
          _rest({
            'select': 'id,user_id,vendor_id,type,title,body,is_read,created_at',
            'user_id': 'eq.$userId',
            'order': 'created_at.desc',
            'limit': '$limit',
          }),
          headers: _headers(),
        )
        .timeout(_timeout);
    if (res.statusCode != 200) throw _failure(res);
    final rows = jsonDecode(res.body);
    if (rows is! List) throw Exception('Unexpected answer');
    return [
      for (final r in rows)
        if (r is Map) AppNotification.fromRow(Map<String, dynamic>.from(r)),
    ];
  }

  @override
  Future<int> unreadCount(String userId) async {
    final res = await _client
        .get(
          _rest({
            'select': 'id',
            'user_id': 'eq.$userId',
            'is_read': 'eq.false',
            'limit': '1',
          }),
          headers: _headers({'Prefer': 'count=exact'}),
        )
        .timeout(_timeout);
    if (res.statusCode != 200 && res.statusCode != 206) throw _failure(res);
    // "0-0/12" or "*/0": the number after the slash is the total.
    final range = res.headers['content-range'] ?? '';
    final total = int.tryParse(range.split('/').last);
    if (total != null) return total;
    final rows = jsonDecode(res.body);
    return rows is List ? rows.length : 0;
  }

  @override
  Future<void> markRead(List<String> ids) async {
    if (ids.isEmpty) return;
    final res = await _client
        .patch(
          _rest({'id': 'in.(${ids.join(',')})'}),
          headers: _headers({
            'Content-Type': 'application/json',
            'Prefer': 'return=minimal',
          }),
          body: jsonEncode({'is_read': true}),
        )
        .timeout(_timeout);
    if (res.statusCode != 204 && res.statusCode != 200) throw _failure(res);
  }

  @override
  Future<void> markAllRead(String userId) async {
    final res = await _client
        .patch(
          _rest({'user_id': 'eq.$userId', 'is_read': 'eq.false'}),
          headers: _headers({
            'Content-Type': 'application/json',
            'Prefer': 'return=minimal',
          }),
          body: jsonEncode({'is_read': true}),
        )
        .timeout(_timeout);
    if (res.statusCode != 204 && res.statusCode != 200) throw _failure(res);
  }
}

/// The signed-in user's notifications: how many are unread (for the bell) and the
/// list. Until the server has answered once, [visible] is false, so a server
/// without the table shows no bell at all.
class InboxController extends ChangeNotifier {
  final InboxBackend backend;
  final DateTime Function() _now;

  /// Something that fires when a push message arrives, so the count is current.
  final Listenable? pushSignal;

  InboxController({
    required this.backend,
    this.pushSignal,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    pushSignal?.addListener(_onPush);
  }

  String? _userId;
  bool _available = false;
  int _unread = 0;
  List<AppNotification> _items = const [];
  bool _loading = false;
  bool _loadFailed = false;
  DateTime? _lastCount;
  int _generation =
      0; // changes with the user: answers of an old user are dropped
  bool _disposed = false;

  String? get userId => _userId;

  /// Whether the bell is shown: a signed-in user, and a server that has the table.
  bool get visible => _userId != null && _available;
  int get unread => _unread;
  List<AppNotification> get items => _items;
  bool get loading => _loading;
  bool get loadFailed => _loadFailed;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// The signed-in user changed (sign in, sign out, another account).
  void setUser(String? userId) {
    if (userId == _userId) return;
    _generation++;
    _userId = userId;
    _available = false;
    _unread = 0;
    _items = const [];
    _loading = false;
    _loadFailed = false;
    _lastCount = null;
    _notify();
    if (userId != null) unawaited(refreshUnread(force: true));
  }

  void _onPush() => unawaited(refreshUnread(force: true));

  /// Asks for the number of unread messages. Not more than once in 20 seconds
  /// unless [force]d.
  Future<void> refreshUnread({bool force = false}) async {
    final id = _userId;
    if (id == null) return;
    final last = _lastCount;
    if (!force &&
        last != null &&
        _now().difference(last) < const Duration(seconds: 20)) {
      return;
    }
    _lastCount = _now();
    final gen = _generation;
    try {
      final n = await backend.unreadCount(id);
      if (gen != _generation) return;
      _available = true;
      _unread = n;
    } on InboxUnavailable {
      if (gen != _generation) return;
      _available = false;
    } catch (_) {
      // A failed count keeps what is shown; it is asked again later.
      _lastCount = null;
      return;
    }
    _notify();
  }

  /// Loads the list (newest first).
  Future<void> load() async {
    final id = _userId;
    if (id == null) return;
    final gen = _generation;
    _loading = true;
    _loadFailed = false;
    _notify();
    try {
      final list = await backend.list(id);
      if (gen != _generation) return;
      _items = list;
      _available = true;
      _unread = list.where((n) => !n.isRead).length;
      // The count may include messages older than the 50 shown.
      unawaited(refreshUnread(force: true));
    } on InboxUnavailable {
      if (gen != _generation) return;
      _available = false;
      _loadFailed = true;
    } catch (_) {
      if (gen != _generation) return;
      _loadFailed = true;
    }
    _loading = false;
    _notify();
  }

  /// Marks one message read (at once on screen; undone if the server refuses).
  Future<void> markRead(AppNotification n) async {
    if (n.isRead) return;
    final before = _items;
    final beforeUnread = _unread;
    _items = [for (final i in _items) i.id == n.id ? i.asRead() : i];
    _unread = _unread > 0 ? _unread - 1 : 0;
    _notify();
    try {
      await backend.markRead([n.id]);
    } catch (_) {
      _items = before;
      _unread = beforeUnread;
      _notify();
    }
  }

  /// Marks every message read.
  Future<void> markAllRead() async {
    final id = _userId;
    if (id == null || (_unread == 0 && _items.every((n) => n.isRead))) return;
    final before = _items;
    final beforeUnread = _unread;
    _items = [for (final i in _items) i.asRead()];
    _unread = 0;
    _notify();
    try {
      await backend.markAllRead(id);
    } catch (_) {
      _items = before;
      _unread = beforeUnread;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    pushSignal?.removeListener(_onPush);
    super.dispose();
  }
}

/// "Just now", "5 min ago", "2 hours ago", "3 days ago", and for older ones a date
/// that reads the same in any language.
String timeAgo(AppLocalizations l, DateTime? at, {DateTime? now}) {
  if (at == null) return '';
  final diff = (now ?? DateTime.now()).difference(at);
  if (diff.inSeconds < 60) return l.timeJustNow;
  if (diff.inMinutes < 60) return l.minutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l.hoursAgo(diff.inHours);
  if (diff.inDays < 7) return l.daysAgo(diff.inDays);
  final d = at.toLocal();
  return '${d.day}/${d.month}/${d.year}';
}
