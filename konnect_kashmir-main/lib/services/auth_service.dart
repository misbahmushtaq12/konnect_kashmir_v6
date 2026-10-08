import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'backend_config.dart';

/// Phone OTP through the existing Supabase Edge Function `send-otp` (the
/// DLT-approved SMS template lives on the server). Verifying is done by
/// `AuthProvider.verifyOTP`, which calls the existing `verify-otp` function.
class AuthService {
  /// The OTP is always 4 digits and valid for 5 minutes (enforced by the server;
  /// the app also refuses to submit an OTP older than this).
  static const int otpLength = 4;
  static const Duration otpValidity = Duration(minutes: 5);

  /// A new OTP can be requested only after this long.
  static const Duration resendWait = Duration(seconds: 30);

  static Future<Map<String, dynamic>> sendOTP(String phone) async {
    try {
      final res = await http
          .post(
            Uri.parse('$kSupabaseUrl/functions/v1/send-otp'),
            headers: {
              'Content-Type': 'application/json',
              'apikey': kSupabaseAnonKey,
              'Authorization': 'Bearer $kSupabaseAnonKey',
            },
            body: jsonEncode({'phone': phone}),
          )
          .timeout(const Duration(seconds: 15));

      Map<String, dynamic> data = {};
      if (res.body.isNotEmpty) {
        try {
          final d = jsonDecode(res.body);
          if (d is Map<String, dynamic>) data = d;
        } catch (_) {}
      }

      if (res.statusCode == 200 && data['success'] != false) {
        return {'success': true};
      }
      return {
        'success': false,
        'error': (data['error'] ?? data['message'] ?? 'Failed to send OTP')
            .toString(),
      };
    } catch (e) {
      debugPrint('[AuthService] sendOTP exception: $e');
      return {
        'success': false,
        'error': 'Could not reach the server. Check your internet and try again.',
      };
    }
  }
}
