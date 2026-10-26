import 'dart:convert';

import 'package:konnect_kashmir/services/prayer_alarm/prayer_alarm_scheduler.dart';

/// A stand-in for the phone's notification system.
///
/// Like the real one, scheduling an id that is already pending replaces it. With
/// a [limit] it behaves like iOS: only the last [limit] notifications set are
/// kept, and [dropped] counts the ones that were lost that way.
class FakeAlarmScheduler implements AlarmScheduler {
  FakeAlarmScheduler({this.limit});
  final int? limit;

  final Map<int, PendingAlarm> pendingById = {};
  final List<int> order = [];
  final List<int> scheduleCalls = [];
  final List<int> cancelCalls = [];
  int dropped = 0;
  int ensureReadyCalls = 0;
  int permissionRequests = 0;
  int exactRequests = 0; // asks that opened the exact-alarm screen

  /// What the user does on the phone's settings page for this app, run when it is
  /// opened. Null: they come back without changing anything.
  Future<void> Function()? onSettingsScreen;

  /// What the user does on Android's exact-alarm screen, run when it is opened.
  /// Null: they come back without giving the permission.
  Future<void> Function()? onExactScreen;
  int settingsOpened = 0;

  AlarmPermissions perms = const AlarmPermissions(
    notifications: true,
    exactAlarms: true,
  );
  Set<int> failIds = {};
  bool failPending = false;

  @override
  int? get pendingLimit => limit;

  @override
  Future<void> ensureReady() async => ensureReadyCalls++;

  @override
  Future<List<PendingAlarm>> pending() async {
    if (failPending) throw Exception('the system is not reachable');
    return pendingById.values.toList();
  }

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String payload,
  }) async {
    if (failIds.contains(id)) throw Exception('refused $id');
    scheduleCalls.add(id);
    pendingById[id] = PendingAlarm(id, title, body, payload);
    order.remove(id);
    order.add(id);
    final l = limit;
    while (l != null && order.length > l) {
      pendingById.remove(order.removeAt(0));
      dropped++;
    }
  }

  @override
  Future<void> cancel(int id) async {
    cancelCalls.add(id);
    pendingById.remove(id);
    order.remove(id);
  }

  @override
  Future<AlarmPermissions> permissions() async => perms;

  @override
  Future<AlarmPermissions> requestPermissions({
    bool exactAlarms = false,
  }) async {
    permissionRequests++;
    if (exactAlarms) {
      exactRequests++;
      await onExactScreen?.call();
    }
    return perms;
  }

  @override
  Future<void> openSettings() async {
    settingsOpened++;
    await onSettingsScreen?.call();
  }

  // ── Helpers for the tests ─────────────────────────────────────────────────

  /// Another feature's notification (not a prayer alarm).
  void addForeign(int id) {
    pendingById[id] = PendingAlarm(id, 'other', 'other', null);
    order.add(id);
  }

  /// The prayer alarms that are waiting, soonest first.
  List<PendingAlarm> get alarms {
    final list = pendingById.values.where((p) => p.payload != null).toList();
    list.sort((a, b) => atOf(a).compareTo(atOf(b)));
    return list;
  }

  List<int> get foreignIds => pendingById.values
      .where((p) => p.payload == null)
      .map((p) => p.id)
      .toList();

  static DateTime atOf(PendingAlarm p) => DateTime.fromMillisecondsSinceEpoch(
    (jsonDecode(p.payload!) as Map)['at'] as int,
    isUtc: true,
  );

  static String prayerOf(PendingAlarm p) =>
      (jsonDecode(p.payload!) as Map)['prayer'] as String;

  /// The system shows (and so removes) every alarm whose time has come.
  void fireDue(DateTime now) {
    for (final p in alarms.where((p) => !atOf(p).isAfter(now)).toList()) {
      pendingById.remove(p.id);
      order.remove(p.id);
    }
  }

  void resetCalls() {
    scheduleCalls.clear();
    cancelCalls.clear();
  }
}
