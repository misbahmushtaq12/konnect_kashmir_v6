import 'dart:async';

import 'package:konnect_kashmir/services/notifications/inbox_service.dart';

AppNotification note(
  String id, {
  String type = 'photo_approved',
  String? title,
  String? body,
  bool read = false,
  DateTime? at,
  String? vendorId = 'v1',
}) => AppNotification(
  id: id,
  vendorId: vendorId,
  type: type,
  title: title ?? 'Photo approved',
  body: body ?? 'Your photo for Orchid Cab Services is now live.',
  isRead: read,
  createdAt: at ?? DateTime.utc(2026, 11, 6, 9),
);

/// The `notifications` table of one user, in memory.
class FakeInboxBackend implements InboxBackend {
  final List<AppNotification> rows = [];
  final List<String> calls = [];

  bool unavailable = false;
  bool failCount = false;
  bool failList = false;
  bool failMark = false;

  /// While set, answers wait for it (to test slow answers and a user switch).
  Completer<void>? gate;

  @override
  Future<List<AppNotification>> list(String userId, {int limit = 50}) async {
    calls.add('list $userId');
    await gate?.future;
    if (unavailable) throw const InboxUnavailable();
    if (failList) throw Exception('offline');
    return [...rows]..sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
  }

  @override
  Future<int> unreadCount(String userId) async {
    calls.add('count $userId');
    await gate?.future;
    if (unavailable) throw const InboxUnavailable();
    if (failCount) throw Exception('offline');
    return rows.where((n) => !n.isRead).length;
  }

  @override
  Future<void> markRead(List<String> ids) async {
    calls.add('read ${ids.join(',')}');
    if (failMark) throw Exception('offline');
    for (var i = 0; i < rows.length; i++) {
      if (ids.contains(rows[i].id)) rows[i] = rows[i].asRead();
    }
  }

  @override
  Future<void> markAllRead(String userId) async {
    calls.add('readAll $userId');
    if (failMark) throw Exception('offline');
    for (var i = 0; i < rows.length; i++) {
      rows[i] = rows[i].asRead();
    }
  }
}
