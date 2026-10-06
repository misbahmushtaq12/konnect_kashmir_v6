
import 'package:flutter/foundation.dart';
import 'package:sendotp_flutter_sdk/sendotp_flutter_sdk.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static const String _widgetId  = '366377675443333634343630';
  static const String _tokenAuth = '493826TbjIWgsm569c0f014P1';

  static bool    _initialized  = false;
  static String? _reqId;
  static String? _lastToken; // stores last successful accessToken

  static void initialize() {
    if (!_initialized) {
      OTPWidget.initializeWidget(_widgetId, _tokenAuth);
      _initialized = true;
      debugPrint('[AuthService] MSG91 OTPWidget initialized');
    }
  }


  static Future<Map<String, dynamic>> sendOTP(String phone) async {
    try {
      if (!_initialized) initialize();

      debugPrint('[AuthService] sendOTP → 91$phone');

      final response = await OTPWidget.sendOTP({
        'identifier': '91$phone',
      });

      debugPrint('[AuthService] sendOTP FULL response: $response');

      if (response == null) {
        return {'success': false, 'error': 'No response from MSG91'};
      }

      if (response['type'] == 'success') {
        // Invisible SIM verification — already verified, skip OTP screen
        if (response.containsKey('access-token')) {
          debugPrint('[AuthService] sendOTP → auto-verified via SIM');
          return {
            'success':      true,
            'autoVerified': true,
            'accessToken':  response['access-token'],
          };
        }


        _reqId = response['reqId'] ??
            response['req_id'] ??
            response['message'] ??
            response['data'];

        debugPrint('[AuthService] sendOTP → OTP sent, reqId=$_reqId');
        return {
          'success':      true,
          'autoVerified': false,
          'reqId':        _reqId,
        };
      }

      return {
        'success': false,
        'error': response['message'] ?? 'Failed to send OTP',
      };
    } catch (e) {
      debugPrint('[AuthService] sendOTP exception: $e');
      return {'success': false, 'error': e.toString()};
    }
  }


  static Future<Map<String, dynamic>> verifyOTP(String otp) async {
    try {
      if (_reqId == null) {
        return {'success': false, 'error': 'No active OTP session. Please resend OTP.'};
      }

      debugPrint('[AuthService] verifyOTP → otp=$otp reqId=$_reqId');

      final response = await OTPWidget.verifyOTP({
        'reqId': _reqId!,
        'otp':   otp,
      });

      debugPrint('[AuthService] verifyOTP FULL response: $response');

      if (response == null) {
        return {'success': false, 'error': 'No response from MSG91'};
      }


      if (response['type'] == 'success') {
        final accessToken =
            response['access-token'] ??
                response['accessToken']  ??
                response['token']        ??
                response['message']      ?? '';

        _lastToken = accessToken;
        debugPrint('[AuthService] verifyOTP → success, accessToken=$accessToken');
        return {'success': true, 'accessToken': accessToken};
      }


      final msg = (response['message'] ?? '').toString().toLowerCase();
      if (msg.contains('already verified') || msg.contains('already verifed')) {
        final accessToken =
            response['access-token'] ??
                response['accessToken']  ??
                response['token']        ??
                _lastToken               ??
                _reqId                   ?? '';

        debugPrint('[AuthService] verifyOTP → already verified, reusing token=$accessToken');
        return {'success': true, 'accessToken': accessToken};
      }

      // ── FAILURE ───────────────────────────────────────────────────────────
      return {
        'success': false,
        'error': response['message'] ?? 'Invalid OTP',
      };
    } catch (e) {
      debugPrint('[AuthService] verifyOTP exception: $e');
      return {'success': false, 'error': e.toString()};
    }
  }


  static Future<Map<String, dynamic>> authenticateWithBackend(
      String accessToken) async {
    try {
      debugPrint('[AuthService] authenticateWithBackend → calling verify-otp edge function');

      final supabase = Supabase.instance.client;

      final response = await supabase.functions.invoke(
        'verify-otp',
        body: {
          'widgetToken': accessToken,
          'source':      'app',
        },
      );

      debugPrint('[AuthService] authenticateWithBackend response: ${response.data}');

      if (response.data == null) {
        return {'success': false, 'error': 'Empty response from server'};
      }

      if (response.data['success'] != true) {
        return {
          'success': false,
          'error': response.data['error'] ??
              response.data['message'] ??
              'Backend auth failed',
        };
      }

      final email    = response.data['email']    as String?;
      final password = response.data['password'] as String?;

      if (email == null || password == null) {
        return {'success': false, 'error': 'Server did not return credentials'};
      }


      final authResponse = await supabase.auth.signInWithPassword(
        email:    email,
        password: password,
      );

      if (authResponse.session == null) {
        return {'success': false, 'error': 'Supabase sign-in failed'};
      }

      debugPrint('[AuthService] authenticateWithBackend → Supabase session created');

      return {
        'success':   true,
        'isNewUser': response.data['isNewUser'] ?? false,
        'session':   authResponse.session,
        'userId':    authResponse.user?.id,
      };
    } catch (e) {
      debugPrint('[AuthService] authenticateWithBackend exception: $e');
      return {'success': false, 'error': e.toString()};
    }
  }


  static Future<void> retryOTP({int channel = 11}) async {
    try {
      if (_reqId == null) {
        debugPrint('[AuthService] retryOTP — no active session');
        return;
      }
      debugPrint('[AuthService] retryOTP → channel=$channel reqId=$_reqId');
      await OTPWidget.retryOTP({
        'reqId':        _reqId!,
        'retryChannel': channel,
      });
    } catch (e) {
      debugPrint('[AuthService] retryOTP exception: $e');
    }
  }

  static void clearSession() {
    _reqId     = null;
    _lastToken = null;
    debugPrint('[AuthService] session cleared');
  }
}