import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/auth_provider.dart';
import 'api_service.dart';

/// One place that keeps the app in step with the backend, so a change shows up
/// on the screen the user is looking at without pulling to refresh.
///
/// * [credits] is the single balance for the signed-in phone number (it lives in
///   `profiles.credit_balance`, so Customer, Vendor, Profile and Add Credit all
///   show the same number).
/// * [transactionsTick] / [leadsTick] go up whenever the backend reports a
///   change, and the visible screens reload when they see that.
///
/// It listens to Supabase Realtime (profiles, credit_transactions, call_clicks)
/// using the user's own session, so row-level security still applies. The
/// backend stays the source of truth: if Realtime is off for a table the
/// screens still load fresh data when they open.
class LiveSync extends ChangeNotifier {
  LiveSync(this._auth) {
    _auth.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  final AuthProvider _auth;

  int? _credits;
  int _transactionsTick = 0;
  int _leadsTick = 0;
  int _unlockedTick = 0;
  final Set<String> _unlockedVendorIds = {};

  int? get credits => _credits;
  int get transactionsTick => _transactionsTick;
  int get leadsTick => _leadsTick;

  /// Goes up when the backend records that this account unlocked a vendor
  /// contact (on this phone or any other device).
  int get unlockedTick => _unlockedTick;

  /// Vendors the backend reported as unlocked since the app started.
  Set<String> get unlockedVendorIds => _unlockedVendorIds;

  String? _uid;
  String? _token;
  final List<RealtimeChannel> _channels = [];
  Timer? _leadsDebounce;

  // ── Credits ───────────────────────────────────────────────────────────────

  /// Use after a backend call reports the new balance (unlock, ad reward...), so
  /// every screen shows it immediately.
  void setCredits(int value) {
    if (_credits == value) return;
    _credits = value;
    notifyListeners();
  }

  /// Tells open screens that a credit transaction was just made.
  void transactionHappened() {
    _transactionsTick++;
    notifyListeners();
  }

  Future<int?>? _creditsInFlight;
  DateTime? _creditsFetchedAt;

  /// Loads the balance from the backend. Callers that ask at the same moment
  /// share one request, and a balance fetched in the last few seconds is reused
  /// (pass [force] to skip that).
  Future<int?> refreshCredits({bool force = false}) {
    if (_uid == null) return Future.value(null);
    final inflight = _creditsInFlight;
    if (inflight != null) return inflight;
    final at = _creditsFetchedAt;
    if (!force &&
        _credits != null &&
        at != null &&
        DateTime.now().difference(at) < const Duration(seconds: 15)) {
      return Future.value(_credits);
    }
    return _creditsInFlight = _fetchCredits().whenComplete(() {
      _creditsInFlight = null;
    });
  }

  Future<int?> _fetchCredits() async {
    final uid = _uid;
    try {
      final c = await ApiService(token: _auth.accessToken, userId: _auth.userId)
          .getUserCredits();
      if (c != null && uid == _uid) {
        _creditsFetchedAt = DateTime.now();
        setCredits(c);
      }
      return c;
    } catch (_) {
      return null;
    }
  }

  // ── Following the signed-in user ──────────────────────────────────────────

  void _onAuthChanged() {
    final uid = _auth.userId;
    final token = _auth.accessToken;

    if (uid != _uid) {
      _stop();
      _uid = uid;
      _token = token;
      _credits = null;
      _creditsFetchedAt = null;
      _unlockedVendorIds.clear();
      notifyListeners();
      if (uid != null && token != null) _start(uid, token);
      return;
    }
    if (token != _token) {
      _token = token;
      // The session token was refreshed; keep the realtime socket on it.
      if (token != null) _setRealtimeAuth(token);
    }
  }

  Future<void> _setRealtimeAuth(String token) async {
    try {
      await Supabase.instance.client.realtime.setAuth(token);
    } catch (e) {
      debugPrint('[LiveSync] setAuth: $e');
    }
  }

  Future<void> _start(String uid, String token) async {
    try {
      await _setRealtimeAuth(token);
      if (uid != _uid) return;
      final client = Supabase.instance.client;

      RealtimeChannel listen(
        String table,
        PostgresChangeFilter? filter,
        void Function(PostgresChangePayload p) onChange,
      ) {
        // One channel per table: if one is unavailable the others still work.
        final ch = client
            .channel('live-$table-$uid')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: table,
              filter: filter,
              callback: onChange,
            )
            .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.channelError) {
            debugPrint('[LiveSync] $table: $error');
          }
        });
        _channels.add(ch);
        return ch;
      }

      PostgresChangeFilter eq(String column) => PostgresChangeFilter(
          type: PostgresChangeFilterType.eq, column: column, value: uid);

      // Balance and profile details.
      listen('profiles', eq('id'), (p) {
        final rec = p.newRecord;
        final bal = rec['credit_balance'];
        if (bal is num) {
          _creditsFetchedAt = DateTime.now();
          setCredits(bal.toInt());
        }
        final name = rec['full_name'];
        if (name is String && name != _auth.user?.name) {
          _auth.refreshProfile();
        }
      });

      // New / changed credit transactions.
      listen('credit_transactions', eq('user_id'), (_) {
        _transactionsTick++;
        notifyListeners();
      });

      // A vendor contact unlocked by this account (also from another device).
      listen('unlocked_vendor_contacts', eq('user_id'), (p) {
        final id = p.newRecord['vendor_id'];
        if (p.eventType == PostgresChangeEvent.insert && id != null) {
          _unlockedVendorIds.add(id.toString());
          _unlockedTick++;
          notifyListeners();
        }
      });

      // New lead activity (a customer calling or messaging a business).
      listen('call_clicks', null, (_) {
        _leadsDebounce?.cancel();
        _leadsDebounce = Timer(const Duration(milliseconds: 600), () {
          _leadsTick++;
          notifyListeners();
        });
      });
    } catch (e) {
      debugPrint('[LiveSync] start: $e');
    }
  }

  void _stop() {
    _leadsDebounce?.cancel();
    final client = Supabase.instance.client;
    for (final ch in _channels) {
      client.removeChannel(ch);
    }
    _channels.clear();
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    _stop();
    super.dispose();
  }
}
