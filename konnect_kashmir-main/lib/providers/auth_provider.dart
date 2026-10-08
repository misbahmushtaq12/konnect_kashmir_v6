import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/widgets.dart';
import '../services/auth_service.dart';
import '../services/backend_config.dart';

const String _baseUrl = kSupabaseUrl;
const String _anonKey = kSupabaseAnonKey;

class AuthUser {
  final String phoneNumber;
  final String name;
  final String serverRole;
  final String? token;
  final String? id;

  const AuthUser({
    required this.phoneNumber,
    required this.name,
    required this.serverRole,
    this.token,
    this.id,
  });

  AuthUser copyWith({
    String? name,
    String? serverRole,
    String? token,
    String? id,
  }) {
    return AuthUser(
      phoneNumber: phoneNumber,
      name: name ?? this.name,
      serverRole: serverRole ?? this.serverRole,
      token: token ?? this.token,
      id: id ?? this.id,
    );
  }
}

class AuthProvider extends ChangeNotifier with WidgetsBindingObserver {
  AuthProvider() {
    WidgetsBinding.instance.addObserver(this);
  }

  // ── Session upkeep ────────────────────────────────────────────────────────
  // Access tokens last ~1h. Refresh them BEFORE they expire (not only at app
  // start), and never run two refreshes at once: refresh tokens are single-use,
  // and a second concurrent use can get the whole session revoked.
  bool _sessionExpired = false;
  /// True when the server permanently rejected the stored session; the UI asks
  /// the user to sign in again (a fresh login is the only way to recover).
  bool get sessionExpired => _sessionExpired;

  Timer? _refreshTimer;
  Future<bool>? _refreshInFlight;

  int _expiresAtMs = 0;

  void _scheduleRefresh(int expiresAtMs) {
    _expiresAtMs = expiresAtMs;
    _refreshTimer?.cancel();
    final due = DateTime.fromMillisecondsSinceEpoch(expiresAtMs)
        .subtract(const Duration(minutes: 5));
    var delay = due.difference(DateTime.now());
    if (delay < const Duration(seconds: 5)) delay = const Duration(seconds: 5);
    _refreshTimer = Timer(delay, () {
      refreshToken();
    });
  }

  /// Clears the saved session but keeps device-level preferences: the user's
  /// Light/Dark choice, so a logout/login on this phone doesn't lose them.
  Future<void> _clearSession(SharedPreferences prefs) async {
    final theme = prefs.getString('theme_mode');
    final themeSys = prefs.getString('theme_mode_sys');
    final lang = prefs.getString('app_locale');
    final langChosen = prefs.getBool('app_locale_chosen');
    await prefs.clear();
    if (theme != null) await prefs.setString('theme_mode', theme);
    if (themeSys != null) await prefs.setString('theme_mode_sys', themeSys);
    if (lang != null) await prefs.setString('app_locale', lang);
    if (langChosen != null) await prefs.setBool('app_locale_chosen', langChosen);
  }

  /// Coming back to the app (after it sat in the background) refreshes a token
  /// that expired meanwhile, so the user is never asked to sign in again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _user == null) return;
    final due = DateTime.fromMillisecondsSinceEpoch(_expiresAtMs)
        .subtract(const Duration(minutes: 5));
    if (DateTime.now().isAfter(due)) refreshToken();
  }

  /// A refresh that failed only because the network was down is retried soon;
  /// the user stays signed in meanwhile.
  void _retryRefreshLater() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer(const Duration(seconds: 30), () {
      refreshToken();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  AuthUser? _user;
  bool _isLoading = false;
  String? _error;


  AuthUser? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get error => _error;
  String? get accessToken => _user?.token;
  String? get userId => _user?.id;

  bool get isAdmin => _user?.serverRole == 'admin' || _user?.serverRole == 'super_admin';
  bool get isSuperAdmin => _user?.serverRole == 'super_admin';
  bool get isModerator => _user?.serverRole == 'moderator';
  bool get isCustomer => _user?.serverRole == 'customer';
  String get serverRole => _user?.serverRole ?? 'customer';

  Map<String, String> get authHeaders => {
    'Content-Type': 'application/json',
    'apikey': _anonKey,
    if (_user?.token != null) 'Authorization': 'Bearer ${_user!.token}',
  };


  Future<Map<String, dynamic>> sendOTP(String phoneNumber) async {
    _setLoading(true);
    _error = null;

    debugPrint('[AuthProvider] STEP 1 — sendOTP: "$phoneNumber"');

    try {
      final result = await AuthService.sendOTP(phoneNumber);
      _setLoading(false);

      if (result['success'] == true) {
        debugPrint('[AuthProvider] sendOTP → success via MSG91 SDK');
        return result;
      }

      _error = result['error'] ?? 'Failed to send OTP';
      debugPrint('[AuthProvider] sendOTP → error: $_error');
      return {'success': false, 'error': _error};
    } catch (e) {
      _setLoading(false);
      _error = e.toString().replaceFirst('Exception: ', '');
      debugPrint('[AuthProvider] sendOTP exception: $_error');
      return {'success': false, 'error': _error};
    }
  }

  /// Verifies the 4-digit OTP with the existing `verify-otp` Edge Function and
  /// signs the user in with the session it returns.
  Future<Map<String, dynamic>> verifyOTP(
      String phoneNumber, String otp) async {
    _setLoading(true);
    _error = null;


    try {
      final verifyResponse = await http.post(
        Uri.parse('$_baseUrl/functions/v1/verify-otp'),
        headers: {
          'Content-Type': 'application/json',
          'apikey': _anonKey,
        },
        body: jsonEncode({'phone': phoneNumber, 'otp': otp, 'source': 'app'}),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Request timed out.'),
      );

      debugPrint('[AuthProvider] legacyVerifyOTP → ${verifyResponse.statusCode}: ${verifyResponse.body}');

      if (verifyResponse.body.isEmpty) {
        _setLoading(false);
        _error = 'Empty response from server.';
        return {'success': false, 'error': _error};
      }

      final verifyData = jsonDecode(verifyResponse.body);

      if (verifyResponse.statusCode != 200 || verifyData['success'] != true) {
        _setLoading(false);
        _error = verifyData['message'] ?? verifyData['error'] ?? 'Invalid OTP';
        return {'success': false, 'error': _error};
      }

      final email     = verifyData['email']    as String?;
      final password  = verifyData['password'] as String?;
      final userId    = verifyData['userId']   as String?;
      final isNewUser = verifyData['isNewUser'] ?? false;

      if (email == null || password == null) {
        _setLoading(false);
        _error = 'Server did not return credentials.';
        return {'success': false, 'error': _error};
      }

      final signInResponse = await http.post(
        Uri.parse('$_baseUrl/auth/v1/token?grant_type=password'),
        headers: {'Content-Type': 'application/json', 'apikey': _anonKey},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 15));

      if (signInResponse.statusCode != 200) {
        _setLoading(false);
        final signInData = jsonDecode(signInResponse.body);
        _error = signInData['error_description'] ?? 'Sign-in failed';
        return {'success': false, 'error': _error};
      }

      final signInData   = jsonDecode(signInResponse.body);
      final accessToken  = signInData['access_token']  as String?;
      final refreshToken = signInData['refresh_token'] as String?;
      final authUserId   = signInData['user']?['id']   as String? ?? userId;

      String role = 'customer';
      try {
        final rolesResponse = await http.get(
          Uri.parse('$_baseUrl/rest/v1/user_roles?user_id=eq.$authUserId&select=role'),
          headers: {
            'Content-Type': 'application/json',
            'apikey': _anonKey,
            'Authorization': 'Bearer $accessToken',
          },
        ).timeout(const Duration(seconds: 10));
        if (rolesResponse.statusCode == 200 && rolesResponse.body.isNotEmpty) {
          final rolesList = jsonDecode(rolesResponse.body) as List;
          if (rolesList.isNotEmpty) {
            final roles = rolesList.map((r) => r['role'] as String).toList();
            if (roles.contains('super_admin')) role = 'super_admin';
            else if (roles.contains('admin')) role = 'admin';
            else if (roles.contains('moderator')) role = 'moderator';
            else role = roles.first;
          }
        }
      } catch (_) {}

      String displayName = '';
      try {
        final profileResponse = await http.get(
          Uri.parse('$_baseUrl/rest/v1/profiles?id=eq.$authUserId&select=full_name,role'),
          headers: {
            'Content-Type': 'application/json',
            'apikey': _anonKey,
            'Authorization': 'Bearer $accessToken',
          },
        ).timeout(const Duration(seconds: 10));
        if (profileResponse.statusCode == 200 && profileResponse.body.isNotEmpty) {
          final list = jsonDecode(profileResponse.body) as List;
          if (list.isNotEmpty) {
            final profile = list.first as Map<String, dynamic>;
            displayName = profile['full_name'] as String? ?? '';
            final profileRole = profile['role'] as String?;
            if (role == 'customer' && profileRole == 'vendor') role = 'vendor';
          }
        }
      } catch (_) {}

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token',  accessToken  ?? '');
      await prefs.setString('refresh_token', refreshToken ?? '');
      await prefs.setString('user_id',       authUserId   ?? '');
      await prefs.setString('user_role',     role);
      await prefs.setString('user_phone',    phoneNumber);
      await prefs.setString('user_email',    email);
      await prefs.setString('user_name',     displayName);
      final expiresAtMs =
          DateTime.now().add(const Duration(seconds: 3600)).millisecondsSinceEpoch;
      await prefs.setInt('token_expires_at', expiresAtMs);
      _scheduleRefresh(expiresAtMs);

      _sessionExpired = false;
      _user = AuthUser(
        phoneNumber: phoneNumber,
        name: displayName,
        serverRole: role,
        token: accessToken,
        id: authUserId,
      );
      _setLoading(false);
      notifyListeners();

      return {'success': true, 'isNewUser': isNewUser, 'role': role,
        'userId': authUserId, 'name': displayName};
    } on Exception catch (e) {
      _setLoading(false);
      _error = e.toString().replaceFirst('Exception: ', '');
      return {'success': false, 'error': _error};
    }
  }


  Future<bool> refreshToken() => _refreshInFlight ??=
      _refreshTokenOnce().whenComplete(() => _refreshInFlight = null);

  Future<bool> _refreshTokenOnce() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedRefreshToken = prefs.getString('refresh_token');

      if (storedRefreshToken == null || storedRefreshToken.isEmpty) {
        debugPrint('[AuthProvider] refreshToken — no refresh token stored');
        return false;
      }

      debugPrint('[AuthProvider] refreshToken — attempting refresh');

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/v1/token?grant_type=refresh_token'),
        headers: {'Content-Type': 'application/json', 'apikey': _anonKey},
        body: jsonEncode({'refresh_token': storedRefreshToken}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        final newAccessToken  = data['access_token']  as String?;
        final newRefreshToken = data['refresh_token'] as String?;

        if (newAccessToken == null) {
          debugPrint('[AuthProvider] refreshToken — no access_token in response');
          return false;
        }

        await prefs.setString('access_token', newAccessToken);
        if (newRefreshToken != null) {
          await prefs.setString('refresh_token', newRefreshToken);
        }
        final expiresAt = DateTime.now()
            .add(const Duration(seconds: 3600))
            .millisecondsSinceEpoch;
        await prefs.setInt('token_expires_at', expiresAt);
        _scheduleRefresh(expiresAt);

        if (_user != null) {
          _user = _user!.copyWith(token: newAccessToken);
          notifyListeners();
        }

        debugPrint('[AuthProvider] refreshToken — success');
        return true;
      }

      debugPrint('[AuthProvider] refreshToken — failed: ${response.statusCode}');
      // 400/401 = the server rejected this session for good (not a network blip).
      if ((response.statusCode == 400 || response.statusCode == 401) &&
          _user != null) {
        _sessionExpired = true;
        notifyListeners();
      }
      if (!_sessionExpired) _retryRefreshLater();
      return false;
    } catch (e) {
      debugPrint('[AuthProvider] refreshToken exception: $e');
      if (_user != null) _retryRefreshLater();
      return false;
    }
  }

  /// Set by the push-notification service: runs before sign-out so this phone
  /// stops receiving the user's notifications.
  Future<void> Function()? onBeforeLogout;

  Future<void> logout() async {
    try {
      await onBeforeLogout?.call();
    } catch (_) {}
    try {
      if (_user?.token != null) {
        await http.post(
          Uri.parse('$_baseUrl/auth/v1/logout?scope=local'),
          headers: authHeaders,
        ).timeout(const Duration(seconds: 10));
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    _refreshTimer?.cancel();
    await _clearSession(prefs);

    _user = null;
    _sessionExpired = false;
    notifyListeners();
  }

  Future<void> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token     = prefs.getString('access_token');
      final role      = prefs.getString('user_role');
      final phone     = prefs.getString('user_phone');
      final userId    = prefs.getString('user_id');
      final name      = prefs.getString('user_name') ?? '';
      final expiresAt = prefs.getInt('token_expires_at') ?? 0;

      if (token == null  || token.isEmpty  ||
          phone  == null || phone.isEmpty  ||
          userId == null || userId.isEmpty) {
        debugPrint('[AuthProvider] restoreSession — no stored session');
        return;
      }

      final expiryTime   = DateTime.fromMillisecondsSinceEpoch(expiresAt);
      final bufferExpiry = expiryTime.subtract(const Duration(minutes: 5));
      final isExpiredOrSoon = DateTime.now().isAfter(bufferExpiry);

      if (isExpiredOrSoon) {
        debugPrint('[AuthProvider] restoreSession — token expired/near-expiry, refreshing');
        _sessionExpired = false;
        _user = AuthUser(
          phoneNumber: phone,
          name: name,
          serverRole: role ?? 'customer',
          token: token,
          id: userId,
        );

        // Wait briefly so the first requests use a fresh token, but never hold
        // up the app start when offline; the refresh carries on in the background.
        final refreshed = await refreshToken()
            .timeout(const Duration(seconds: 4), onTimeout: () => false);
        // Only the server rejecting the session ends the login. No internet
        // keeps the user signed in; the refresh is retried automatically.
        if (!refreshed && _sessionExpired) {
          debugPrint('[AuthProvider] restoreSession — session rejected, clearing session');
          await _clearSession(prefs);
          _user = null;
          _sessionExpired = false;
          notifyListeners();
          return;
        }
        notifyListeners();
        debugPrint('[AuthProvider] restoreSession — restored userId=$userId role=$role (refreshed=$refreshed)');
        return;
      }

      _sessionExpired = false;
      _user = AuthUser(
        phoneNumber: phone,
        name: name,
        serverRole: role ?? 'customer',
        token: token,
        id: userId,
      );
      notifyListeners();
      _scheduleRefresh(expiresAt);
      debugPrint('[AuthProvider] restoreSession — restored userId=$userId role=$role');
    } catch (e) {
      debugPrint('[AuthProvider] restoreSession error: $e');
    }
  }

  Future<void> setSession(
      String accessToken,
      String newUserId, {
        String phone = '',
        String role = 'admin',
        String name = '',
      }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken);
    await prefs.setString('user_id',      newUserId);
    await prefs.setString('user_role',    role);
    await prefs.setString('user_phone',   phone);
    await prefs.setString('user_name',    name);

    final expiresAt = DateTime.now()
        .add(const Duration(seconds: 3600))
        .millisecondsSinceEpoch;
    await prefs.setInt('token_expires_at', expiresAt);

    _sessionExpired = false;
    _user = AuthUser(
      phoneNumber: phone,
      name: name,
      serverRole: role,
      token: accessToken,
      id: newUserId,
    );
    notifyListeners();
    debugPrint('[AuthProvider] setSession — userId=$newUserId role=$role phone=$phone');
  }

  Future<void> refreshProfile() async {
    if (_user?.id == null || _user?.token == null) return;
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/rest/v1/profiles?id=eq.${_user!.id}&select=full_name,role'),
        headers: authHeaders,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final list = jsonDecode(response.body) as List;
        if (list.isNotEmpty) {
          final profile = list.first as Map<String, dynamic>;
          final newName = profile['full_name'] as String? ?? _user!.name;
          _user = _user!.copyWith(name: newName);

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_name', newName);

          notifyListeners();
          debugPrint('[AuthProvider] refreshProfile — updated name="$newName"');
        }
      }
    } catch (e) {
      debugPrint('[AuthProvider] refreshProfile error: $e');
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}