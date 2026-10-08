import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseUrl = 'https://fmmpsqnpezjofsluirrv.supabase.co';
  static const String _anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZtbXBzcW5wZXpqb2ZzbHVpcnJ2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk2MzIyNTgsImV4cCI6MjA4NTIwODI1OH0.6FCU_FLaHsKsE7G50A7-_zYf46GZiKpecg4l_de3tn4';

  final String? token;
  final String? userId;

  ApiService({this.token, this.userId});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'apikey': _anonKey,
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Map<String, String> get _headersWithPreference => {
    ..._headers,
    'Prefer': 'return=representation',
  };


  Map<String, String> get _headersMinimalReturn => {
    ..._headers,
    'Prefer': 'return=minimal',
  };

  Map<String, dynamic> _err(String msg) => {'success': false, 'error': msg};
  Map<String, dynamic> _ok([Map<String, dynamic>? data]) =>
      {'success': true, ...?data};


  Future<Map<String, dynamic>> verifyOTPWithWidget(String widgetToken) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/functions/v1/verify-otp'),
        headers: _headers,
        body: jsonEncode({
          'widgetToken': widgetToken,
          'source': 'app',
        }),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) return _ok(data);
        return _err(data['error'] ?? 'Widget verification failed');
      }
      return _err('Widget verification failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> getOTPWidgetConfig() async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/functions/v1/get-otp-widget-config'),
        headers: _headers,
        body: '{}',
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) return _ok(data);
        return _err('Failed to load widget config');
      }
      return _err('Failed to load widget (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> phoneAuthFix(String phone, String otp) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/functions/v1/phone-auth-fix'),
        headers: _headers,
        body: jsonEncode({'phone': phone, 'otp': otp}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['found'] == true && data['fixed'] == true) return _ok(data);
        return _err('User not found or fix failed');
      }
      return _err('Auth fix failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> adminPinAuth({
    required String action,
    String? phone,
    String? pin,
    String? newPin,
    String? widgetToken,
  }) async {
    try {
      final body = {
        'action': action,
        if (phone != null) 'phone': phone,
        if (pin != null) 'pin': pin,
        if (newPin != null) 'newPin': newPin,
        if (widgetToken != null) 'widgetToken': widgetToken,
      };
      final res = await http.post(
        Uri.parse('$_baseUrl/functions/v1/admin-pin-auth'),
        headers: _headers,
        body: jsonEncode(body),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) return _ok(data);
        return _err(data['message'] ?? 'Admin auth failed');
      }
      return _err('Admin auth failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  /// Records that the signed-in user tapped a vendor's Call or WhatsApp button
  /// (a row in `call_clicks`, which is what becomes a lead for that vendor).
  /// Fire-and-forget: it never delays the call or the chat from opening and it
  /// never throws. Nothing is recorded for a signed-out user.
  void trackCallClick(String vendorId, String action) {
    final uid = userId;
    if (uid == null || token == null || vendorId.isEmpty) return;
    http
        .post(
          Uri.parse('$_baseUrl/rest/v1/call_clicks'),
          headers: _headersMinimalReturn,
          body: jsonEncode({
            'user_id': uid,
            'vendor_id': vendorId,
            'action': action,
            'source': 'app',
          }),
        )
        .timeout(const Duration(seconds: 15))
        .then<void>((_) {}, onError: (_) {});
  }

  Future<Map<String, dynamic>> unlockVendorContact(String vendorId) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/functions/v1/unlock-vendor-contact'),
        headers: _headers,
        body: jsonEncode({'vendorId': vendorId, 'source': 'app'}),
      );
      if (res.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(res.body));
      }
      return _err('Contact unlock failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> claimAdCredits(String adId) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/functions/v1/claim-ad-credits'),
        headers: _headers,
        body: jsonEncode({'adId': adId}),
      );
      if (res.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(res.body));
      }
      return _err('Claim failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> processReferral({
    required String action,
    String? referralCode,
    String? userRole,
  }) async {
    try {
      final body = {
        'action': action,
        if (referralCode != null) 'referralCode': referralCode,
        if (userRole != null) 'userRole': userRole,
      };
      final res = await http.post(
        Uri.parse('$_baseUrl/functions/v1/process-referral'),
        headers: _headers,
        body: jsonEncode(body),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) return _ok(data);
        return _err(data['message'] ?? 'Referral processing failed');
      }
      return _err('Referral failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> sendLeadSMS(
      String vendorId, String vendorPhone, String vendorName) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/functions/v1/send-lead-sms'),
        headers: _headers,
        body: jsonEncode({
          'vendorId': vendorId,
          'vendorPhone': vendorPhone,
          'vendorName': vendorName,
        }),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) return _ok(data);
        return _err(data['message'] ?? 'SMS send failed');
      }
      return _err('SMS failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> sendApprovalSMS(String vendorId) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/functions/v1/send-approval-sms'),
        headers: _headers,
        body: jsonEncode({'vendorId': vendorId}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) return _ok(data);
        return _err(data['message'] ?? 'SMS send failed');
      }
      return _err('SMS failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> sendWhatsAppMsg(String phoneNumber,
      {required String message, String? url}) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/functions/v1/send-whatsapp-msg91'),
        headers: _headers,
        body: jsonEncode({
          'phone_number': phoneNumber,
          'value1': message,
          if (url != null) 'url': url,
        }),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) return _ok(data);
        return _err(data['message'] ?? 'WhatsApp send failed');
      }
      return _err('WhatsApp failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> syncToSheets() async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/functions/v1/sync-to-sheets'),
        headers: _headers,
        body: '{}',
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) return _ok(data);
        return _err(data['message'] ?? 'Sync failed');
      }
      return _err('Sync failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> deleteUser(String userId) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/functions/v1/delete-user'),
        headers: _headers,
        body: jsonEncode({'userId': userId}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) return _ok(data);
        return _err(data['message'] ?? 'Delete failed');
      }
      return _err('Delete failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> syncPendingAdmins() async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/functions/v1/sync-pending-admins'),
        headers: _headers,
        body: '{}',
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true || data['synced'] != null) return _ok(data);
        return _err(data['message'] ?? 'Sync failed');
      }
      return _err('Sync failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> getLeadNames(List<String> vendorIds) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/functions/v1/get-lead-names'),
        headers: _headers,
        body: jsonEncode({'vendorIds': vendorIds}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['leads'] != null) return _ok(data);
        return _err('Failed to load leads');
      }
      return _err('Lead fetch failed (${res.statusCode}): ${res.body}');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> revealLeadPhone(
      String leadUserId, String vendorId) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/functions/v1/reveal-lead-phone'),
        headers: _headers,
        body: jsonEncode({'leadUserId': leadUserId, 'vendorId': vendorId}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['phone'] != null) return _ok(data);
        return _err('Failed to reveal phone');
      }
      return _err('Phone reveal failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> getUserPhones(List<String> userIds) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/functions/v1/get-user-phones'),
        headers: _headers,
        body: jsonEncode({'userIds': userIds}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['phones'] != null) return _ok(data);
        return _err('Failed to load phones');
      }
      return _err('Phone fetch failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> findUserByPhone(String phone) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/functions/v1/find-user-by-phone'),
        headers: _headers,
        body: jsonEncode({'phone': phone}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['userId'] != null) return _ok(data);
        return _err('User not found');
      }
      return _err('User search failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getVendors({
    String search = '',
    String? district,
    String? locality,
    String? service,
    String? browseCategory,
    String? districtId,
    String? localityId,
    String? serviceSlug,
    bool verifiedOnly = false,
    int limit = 100,
    int offset = 0,
    // When true, network/server failures throw instead of returning an empty
    // list, so the UI can show "No internet / Retry" rather than "No providers".
    bool throwOnError = false,
    // Sort order (PostgREST syntax); newest first by default.
    String order = 'created_at.desc',
    // Only these vendors (e.g. the saved ones).
    List<String>? ids,
    // Receives the real number of vendors matching the filters (not just this
    // page), counted by the database.
    void Function(int total)? onTotal,
  }) async {
    try {
      if (ids != null && ids.isEmpty) {
        onTotal?.call(0);
        return [];
      }
      final String? effectiveService = serviceSlug ?? browseCategory ?? service;
      List<String>? districtLocalityIds;
      if (localityId == null && districtId != null) {
        districtLocalityIds = await _getLocalityIdsByDistrict(districtId,
            throwOnError: throwOnError);
        if (districtLocalityIds.isEmpty) {
          onTotal?.call(0);
          return [];
        }
      }
      final params = <String, String>{
        'select': 'id,business_name,service_type,locality_id,'
            'localities(name),'
            'description,is_verified,logo_url,created_at,'
            'min_price,max_price,experience_years,'
            'provides_home_service,accepts_online_payment,'
            'phone',
        'is_approved': 'eq.true',
        'limit': '$limit',
        'offset': '$offset',
        'order': order,
        if (ids != null) 'id': 'in.(${ids.join(',')})',
        if (search.isNotEmpty) 'business_name': 'ilike.%$search%',
        if (effectiveService != null) 'service_type': 'eq.$effectiveService',
        if (verifiedOnly) 'is_verified': 'eq.true',
        if (localityId != null) 'locality_id': 'eq.$localityId',
        if (districtLocalityIds != null && districtLocalityIds.isNotEmpty)
          'locality_id': 'in.(${districtLocalityIds.join(',')})',
      };
      final uri = Uri.parse('$_baseUrl/rest/v1/vendors_public')
          .replace(queryParameters: params);
      final res = await http.get(uri,
          headers: onTotal == null
              ? _headers
              : {..._headers, 'Prefer': 'count=exact'});
      if (res.statusCode == 200 || res.statusCode == 206) {
        if (onTotal != null) {
          // "Content-Range: 0-19/1440" -> 1440
          final total = int.tryParse(
              (res.headers['content-range'] ?? '').split('/').last);
          if (total != null) onTotal(total);
        }
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      }
      if (throwOnError) {
        throw Exception('Server error (${res.statusCode})');
      }
      return [];
    } catch (e) {
      if (throwOnError) rethrow;
      return [];
    }
  }

  // Locality ids rarely change; cache per district so repeat filters skip a request.
  static final Map<String, List<String>> _districtLocalityIds = {};

  Future<List<String>> _getLocalityIdsByDistrict(String districtId,
      {bool throwOnError = false}) async {
    final cached = _districtLocalityIds[districtId];
    if (cached != null) return cached;
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/localities').replace(
        queryParameters: {'district_id': 'eq.$districtId', 'select': 'id'},
      );
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200) {
        final list = List<Map<String, dynamic>>.from(jsonDecode(res.body));
        final ids = list.map((l) => l['id'].toString()).toList();
        if (ids.isNotEmpty) _districtLocalityIds[districtId] = ids;
        return ids;
      }
      if (throwOnError) throw Exception('Server error (${res.statusCode})');
      return [];
    } catch (e) {
      if (throwOnError) rethrow;
      return [];
    }
  }

  Future<Map<String, dynamic>?> getVendorById(String vendorId) async {
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/vendors_public')
          .replace(queryParameters: {'id': 'eq.$vendorId'});
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        if (data.isNotEmpty) return data.first as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> createVendor(Map<String, dynamic> data) async {
    try {
      final res = await http.post(Uri.parse('$_baseUrl/rest/v1/vendors'),
          headers: _headersWithPreference, body: jsonEncode(data));
      if (res.statusCode == 201) {
        final resData = jsonDecode(res.body);
        if (resData is List && resData.isNotEmpty) return _ok(resData.first);
        return _ok(resData);
      }
      return _err('Vendor creation failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> updateVendor(
      String vendorId, Map<String, dynamic> updates) async {
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/vendors')
          .replace(queryParameters: {'id': 'eq.$vendorId'});
      final res = await http.patch(uri,
          headers: _headersWithPreference, body: jsonEncode(updates));
      if (res.statusCode == 200) return _ok(jsonDecode(res.body));
      return _err('Update failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getVendorCategories(
      List<String> vendorIds) async {
    try {
      final ids = vendorIds.map((id) => '"$id"').join(',');
      final uri = Uri.parse('$_baseUrl/rest/v1/vendor_categories')
          .replace(queryParameters: {'vendor_id': 'in.($ids)'});
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200)
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> addVendorCategory(
      String vendorId, String categorySlug) async {
    try {
      final res = await http.post(
          Uri.parse('$_baseUrl/rest/v1/vendor_categories'),
          headers: _headersWithPreference,
          body: jsonEncode(
              {'vendor_id': vendorId, 'category_slug': categorySlug}));
      if (res.statusCode == 201 || res.statusCode == 200) return _ok();
      return _err('Category add failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> removeVendorCategory(
      String vendorId, String categorySlug) async {
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/vendor_categories').replace(
          queryParameters: {
            'vendor_id': 'eq.$vendorId',
            'category_slug': 'eq.$categorySlug'
          });
      final res = await http.delete(uri, headers: _headers);
      if (res.statusCode == 204 || res.statusCode == 200) return _ok();
      return _err('Category remove failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getServiceCategories() async {
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/service_categories').replace(
          queryParameters: {
            'is_active': 'eq.true',
            'order': 'display_order.asc'
          });
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200)
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getFeaturedServiceCategories() async {
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/service_categories').replace(
          queryParameters: {
            'is_active': 'eq.true',
            'is_featured': 'eq.true',
            'order': 'featured_order.asc'
          });
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200)
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> createServiceCategory(
      Map<String, dynamic> data) async {
    try {
      final res = await http.post(
          Uri.parse('$_baseUrl/rest/v1/service_categories'),
          headers: _headersWithPreference,
          body: jsonEncode(data));
      if (res.statusCode == 201 || res.statusCode == 200) return _ok();
      return _err('Creation failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> updateServiceCategory(
      String categoryId, Map<String, dynamic> updates) async {
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/service_categories')
          .replace(queryParameters: {'id': 'eq.$categoryId'});
      final res = await http.patch(uri,
          headers: _headersWithPreference, body: jsonEncode(updates));
      if (res.statusCode == 200) return _ok(jsonDecode(res.body));
      return _err('Update failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> deleteServiceCategory(String categoryId) async {
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/service_categories')
          .replace(queryParameters: {'id': 'eq.$categoryId'});
      final res = await http.delete(uri, headers: _headers);
      if (res.statusCode == 204 || res.statusCode == 200) return _ok();
      return _err('Delete failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> reorderServiceCategories(
      List<String> orderedIds) async {
    try {
      for (int i = 0; i < orderedIds.length; i++) {
        await updateServiceCategory(orderedIds[i], {'display_order': i + 1});
      }
      return _ok();
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/profiles')
          .replace(queryParameters: {'id': 'eq.$userId'});
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        if (data.isNotEmpty) return data.first as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> updateUserProfile(
      String userId, Map<String, dynamic> updates) async {
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/profiles')
          .replace(queryParameters: {'id': 'eq.$userId'});
      final res = await http.patch(uri,
          headers: _headersWithPreference, body: jsonEncode(updates));
      if (res.statusCode == 200) {
        // PostgREST returns the updated rows as a list; empty means no row changed.
        final body = jsonDecode(res.body);
        if (body is List) {
          if (body.isEmpty) return _err('Profile not found');
          return _ok(Map<String, dynamic>.from(body.first as Map));
        }
        return _ok(body as Map<String, dynamic>?);
      }
      return _err('Update failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getUserTransactions(
      {int limit = 50, int offset = 0}) async {
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/credit_transactions').replace(
          queryParameters: {
            'user_id': 'eq.$userId',
            'order': 'created_at.desc',
            'limit': '$limit',
            'offset': '$offset'
          });
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200)
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAvailableAds() async {
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/ads').replace(
          queryParameters: {
            'is_active': 'eq.true',
            'order': 'created_at.desc'
          });
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200)
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> recordAdView(String adId) async {
    try {
      final res = await http.post(Uri.parse('$_baseUrl/rest/v1/ad_views'),
          headers: _headersWithPreference,
          body: jsonEncode({'user_id': userId, 'ad_id': adId}));
      if (res.statusCode == 201 || res.statusCode == 200) return _ok();
      return _err('View recording failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getVendorReviews(String vendorId) async {
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/vendor_reviews_public')
          .replace(queryParameters: {'vendor_id': 'eq.$vendorId'});
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200)
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> submitReview(
      String vendorId, int rating, String reviewText) async {
    try {
      final res = await http.post(
          Uri.parse('$_baseUrl/rest/v1/vendor_reviews'),
          headers: _headersWithPreference,
          body: jsonEncode({
            'vendor_id': vendorId,
            'user_id': userId,
            'rating': rating,
            'review_text': reviewText
          }));
      if (res.statusCode == 201 || res.statusCode == 200) return _ok();
      return _err('Review submission failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> deleteReview(String reviewId) async {
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/vendor_reviews')
          .replace(queryParameters: {'id': 'eq.$reviewId'});
      final res = await http.delete(uri, headers: _headers);
      if (res.statusCode == 204 || res.statusCode == 200) return _ok();
      return _err('Delete failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getJobs(
      {String? vendorId, int limit = 50, int offset = 0}) async {
    try {
      final params = {
        'is_active': 'eq.true',
        'is_approved': 'eq.true',
        'order': 'created_at.desc',
        'limit': '$limit',
        'offset': '$offset',
        if (vendorId != null) 'vendor_id': 'eq.$vendorId',
      };
      final uri =
      Uri.parse('$_baseUrl/rest/v1/jobs').replace(queryParameters: params);
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200)
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getJobById(String jobId) async {
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/jobs')
          .replace(queryParameters: {'id': 'eq.$jobId'});
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        if (data.isNotEmpty) return data.first as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> createJob(Map<String, dynamic> data) async {
    try {
      final res = await http.post(Uri.parse('$_baseUrl/rest/v1/jobs'),
          headers: _headersWithPreference, body: jsonEncode(data));
      if (res.statusCode == 201 || res.statusCode == 200) return _ok();
      return _err('Job creation failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> updateJob(
      String jobId, Map<String, dynamic> updates) async {
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/jobs')
          .replace(queryParameters: {'id': 'eq.$jobId'});
      final res = await http.patch(uri,
          headers: _headersWithPreference, body: jsonEncode(updates));
      if (res.statusCode == 200) return _ok(jsonDecode(res.body));
      return _err('Update failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> deleteJob(String jobId) async {
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/jobs')
          .replace(queryParameters: {'id': 'eq.$jobId'});
      final res = await http.delete(uri, headers: _headers);
      if (res.statusCode == 204 || res.statusCode == 200) return _ok();
      return _err('Delete failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getJobApplications(
      {String? vendorId, String? userId}) async {
    try {
      final params = <String, String>{};
      if (vendorId != null) params['vendor_id'] = 'eq.$vendorId';
      if (userId != null) params['user_id'] = 'eq.$userId';
      final uri = Uri.parse('$_baseUrl/rest/v1/job_applications')
          .replace(queryParameters: params);
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200)
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> applyToJob(String jobId, String applicantName,
      String applicantPhone, String applicantEmail, String coverLetter) async {
    try {
      final res = await http.post(
          Uri.parse('$_baseUrl/rest/v1/job_applications'),
          headers: _headersWithPreference,
          body: jsonEncode({
            'job_id': jobId,
            'user_id': userId,
            'applicant_name': applicantName,
            'applicant_phone': applicantPhone,
            'applicant_email': applicantEmail,
            'cover_letter': coverLetter
          }));
      if (res.statusCode == 201 || res.statusCode == 200) return _ok();
      return _err('Application failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> updateJobApplication(
      String applicationId, String status) async {
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/job_applications')
          .replace(queryParameters: {'id': 'eq.$applicationId'});
      final res = await http.patch(uri,
          headers: _headersWithPreference,
          body: jsonEncode({'status': status}));
      if (res.statusCode == 200) return _ok(jsonDecode(res.body));
      return _err('Update failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getDistricts() async {
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/districts')
          .replace(queryParameters: {'order': 'name.asc'});
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200)
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getLocalities(String districtId) async {
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/localities').replace(
          queryParameters: {
            'district_id': 'eq.$districtId',
            'order': 'name.asc'
          });
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200)
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> createDistrict(String name) async {
    try {
      final res = await http.post(Uri.parse('$_baseUrl/rest/v1/districts'),
          headers: _headersWithPreference, body: jsonEncode({'name': name}));
      if (res.statusCode == 201 || res.statusCode == 200) return _ok();
      return _err('Creation failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> createLocality(
      String districtId, String name) async {
    try {
      final res = await http.post(Uri.parse('$_baseUrl/rest/v1/localities'),
          headers: _headersWithPreference,
          body: jsonEncode({'district_id': districtId, 'name': name}));
      if (res.statusCode == 201 || res.statusCode == 200) return _ok();
      return _err('Creation failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> deleteDistrict(String districtId) async {
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/districts')
          .replace(queryParameters: {'id': 'eq.$districtId'});
      final res = await http.delete(uri, headers: _headers);
      if (res.statusCode == 204 || res.statusCode == 200) return _ok();
      return _err('Delete failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> deleteLocality(String localityId) async {
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/localities')
          .replace(queryParameters: {'id': 'eq.$localityId'});
      final res = await http.delete(uri, headers: _headers);
      if (res.statusCode == 204 || res.statusCode == 200) return _ok();
      return _err('Delete failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getReports(
      {String status = 'all', int limit = 50}) async {
    try {
      final params = {
        'order': 'created_at.desc',
        'limit': '$limit',
        if (status != 'all') 'status': 'eq.$status',
      };
      final uri = Uri.parse('$_baseUrl/rest/v1/reports')
          .replace(queryParameters: params);
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200)
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      return [];
    } catch (e) {
      return [];
    }
  }
  String _normaliseReportType(String displayLabel) {
    const Map<String, String> _map = {
      'Misleading Information': 'misleading_information',
      'False Claims': 'false_claims',
      'Spam or Promotional': 'spam',
      'Inappropriate Behavior': 'inappropriate_behavior',
      'Suspected Fraud': 'fraud',
      'Other': 'other',
    };

    return _map[displayLabel] ??
        displayLabel.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }

  Future<Map<String, dynamic>> submitReport(
      String? vendorId,
      String? reportedUserId,
      String reportType,
      String description,
      ) async {
    if (userId == null) {
      return _err('Not authenticated. Please sign in and try again.');
    }
    try {
      // Normalise the display label to a DB-safe enum value.
      final String normalisedType = _normaliseReportType(reportType);

      final res = await http.post(
        Uri.parse('$_baseUrl/rest/v1/reports'),
        headers: _headersMinimalReturn,
        body: jsonEncode({
          'reporter_id': userId,
          if (vendorId != null) 'reported_vendor_id': vendorId,
          if (reportedUserId != null) 'reported_user_id': reportedUserId,
          'report_type': normalisedType,
          'description': description,
        }),
      );

      // 201 Created    — standard PostgREST INSERT success
      // 204 No Content — returned when return=minimal is respected
      // 200 OK         — some Supabase edge-case responses
      if (res.statusCode == 201 ||
          res.statusCode == 204 ||
          res.statusCode == 200) {
        return _ok();
      }

      // Include the response body in the error to aid future debugging.
      String errorDetail = '';
      try {
        final body = jsonDecode(res.body);
        errorDetail = body['message'] ?? body['error'] ?? res.body;
      } catch (_) {
        errorDetail = res.body;
      }
      return _err(
        'Report submission failed (${res.statusCode})'
            '${errorDetail.isNotEmpty ? ': $errorDetail' : ''}',
      );
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> updateReport(
      String reportId, String status, String adminNotes) async {
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/reports')
          .replace(queryParameters: {'id': 'eq.$reportId'});
      final res = await http.patch(uri,
          headers: _headersWithPreference,
          body: jsonEncode({'status': status, 'admin_notes': adminNotes}));
      if (res.statusCode == 200) return _ok(jsonDecode(res.body));
      return _err('Update failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getUserReferrals() async {
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/referrals').replace(
          queryParameters: {
            'or': '(referrer_user_id.eq.$userId,referred_user_id.eq.$userId)'
          });
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200)
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<int> getUserCreditsRPC() async {
    try {
      final res = await http.post(
          Uri.parse('$_baseUrl/rest/v1/rpc/get_user_credits'),
          headers: _headers,
          body: '{}');
      if (res.statusCode == 200) return int.tryParse(res.body) ?? 0;
      return 0;
    } catch (e) {
      return 0;
    }
  }

  Future<int?> getUserCredits() async {
    final rpcBalance = await getUserCreditsRPC();
    if (rpcBalance > 0) return rpcBalance;
    if (userId != null) {
      final profile = await getUserProfile(userId!);
      if (profile != null) return profile['credit_balance'] as int? ?? 0;
    }
    return 0;
  }

  Future<bool> isAdminRPC(String userId) async {
    try {
      final res = await http.post(
          Uri.parse('$_baseUrl/rest/v1/rpc/is_admin'),
          headers: _headers,
          body: jsonEncode({'_user_id': userId}));
      if (res.statusCode == 200) return res.body.toLowerCase() == 'true';
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isSuperAdminRPC(String userId) async {
    try {
      final res = await http.post(
          Uri.parse('$_baseUrl/rest/v1/rpc/is_super_admin'),
          headers: _headers,
          body: jsonEncode({'_user_id': userId}));
      if (res.statusCode == 200) return res.body.toLowerCase() == 'true';
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> hasRoleRPC(String userId, String role) async {
    try {
      final res = await http.post(
          Uri.parse('$_baseUrl/rest/v1/rpc/has_role'),
          headers: _headers,
          body: jsonEncode({'_user_id': userId, '_role': role}));
      if (res.statusCode == 200) return res.body.toLowerCase() == 'true';
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> hasUnlockedVendorRPC(String vendorId) async {
    try {
      final res = await http.post(
          Uri.parse('$_baseUrl/rest/v1/rpc/has_unlocked_vendor'),
          headers: _headers,
          body: jsonEncode({'vendor_uuid': vendorId}));
      if (res.statusCode == 200) return res.body.toLowerCase() == 'true';
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> userOwnsVendorRPC(String vendorId) async {
    try {
      final res = await http.post(
          Uri.parse('$_baseUrl/rest/v1/rpc/user_owns_vendor'),
          headers: _headers,
          body: jsonEncode({'vendor_uuid': vendorId}));
      if (res.statusCode == 200) return res.body.toLowerCase() == 'true';
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> canAccessVendorContactRPC(String vendorId) async {
    try {
      final res = await http.post(
          Uri.parse('$_baseUrl/rest/v1/rpc/can_access_vendor_contact'),
          headers: _headers,
          body: jsonEncode({'vendor_uuid': vendorId}));
      if (res.statusCode == 200) return res.body.toLowerCase() == 'true';
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> uploadVendorImage(
      String fileName, Uint8List fileData) async {
    try {
      final path = 'vendor-images/$fileName';
      final res = await http.post(
          Uri.parse('$_baseUrl/storage/v1/object/$path'),
          headers: {
            'apikey': _anonKey,
            if (token != null) 'Authorization': 'Bearer $token'
          },
          body: fileData);
      if (res.statusCode == 200)
        return _ok({'publicUrl': '$_baseUrl/storage/v1/object/public/$path'});
      return _err('Upload failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  static String getPublicImageUrl(String fileName) =>
      '$_baseUrl/storage/v1/object/public/vendor-images/$fileName';

  Future<Map<String, dynamic>> deleteVendorImage(String fileName) async {
    try {
      final path = 'vendor-images/$fileName';
      final res = await http.delete(
          Uri.parse('$_baseUrl/storage/v1/object/$path'),
          headers: {
            'apikey': _anonKey,
            if (token != null) 'Authorization': 'Bearer $token'
          });
      if (res.statusCode == 204 || res.statusCode == 200) return _ok();
      return _err('Delete failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getUnlockedVendors() async {
    try {
      final uri =
      Uri.parse('$_baseUrl/rest/v1/unlocked_vendor_contacts').replace(
          queryParameters: {
            'user_id': 'eq.$userId',
            'order': 'created_at.desc'
          });
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200)
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getUserRoles(String userId) async {
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/user_roles')
          .replace(queryParameters: {'user_id': 'eq.$userId'});
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200)
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getActivityLogs(
      {String action = 'all', String role = 'all', int limit = 100}) async {
    try {
      final params = {
        'order': 'id.desc',
        'limit': '$limit',
        if (action != 'all') 'action': 'eq.$action',
        if (role != 'all') 'performer_type': 'eq.$role',
      };
      final uri = Uri.parse('$_baseUrl/rest/v1/activity_logs')
          .replace(queryParameters: params);
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200)
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getPlatformStats() async {
    try {
      final vendors = await http.get(
          Uri.parse(
              '$_baseUrl/rest/v1/vendors_public?select=id&is_approved=eq.true'),
          headers: _headers);
      final districts = await http.get(
          Uri.parse('$_baseUrl/rest/v1/districts?select=id'),
          headers: _headers);
      final categories = await http.get(
          Uri.parse(
              '$_baseUrl/rest/v1/service_categories?select=id&is_active=eq.true'),
          headers: _headers);
      if (vendors.statusCode == 200 &&
          districts.statusCode == 200 &&
          categories.statusCode == 200) {
        return _ok({
          'vendors': (jsonDecode(vendors.body) as List).length,
          'districts': (jsonDecode(districts.body) as List).length,
          'services': (jsonDecode(categories.body) as List).length,
        });
      }
      return _err('Failed to load stats');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, List<String>>> getAdminDistricts() async {
    try {
      final districtRes = await http.get(
          Uri.parse('$_baseUrl/rest/v1/districts?order=name.asc'),
          headers: _headers);
      if (districtRes.statusCode != 200) return {};
      final districtList =
      List<Map<String, dynamic>>.from(jsonDecode(districtRes.body));
      final result = <String, List<String>>{};
      for (final d in districtList) {
        final districtId = d['id'].toString();
        final districtName = d['name'] as String;
        final localityRes = await http.get(
            Uri.parse(
                '$_baseUrl/rest/v1/localities?district_id=eq.$districtId&order=name.asc'),
            headers: _headers);
        if (localityRes.statusCode == 200) {
          final localityList =
          List<Map<String, dynamic>>.from(jsonDecode(localityRes.body));
          result[districtName] =
              localityList.map((l) => l['name'] as String).toList();
        } else {
          result[districtName] = [];
        }
      }
      return result;
    } catch (e) {
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> getAdminServiceCategories() async =>
      getServiceCategories();

  Future<List<Map<String, dynamic>>> getAdminPendingVendors() async {
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/vendors').replace(
          queryParameters: {
            'is_approved': 'eq.false',
            'order': 'created_at.desc'
          });
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200)
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAdminApprovedVendors() async {
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/vendors').replace(
          queryParameters: {
            'is_approved': 'eq.true',
            'order': 'created_at.desc'
          });
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200)
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAdminReviews() async {
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/vendor_reviews')
          .replace(queryParameters: {'order': 'created_at.desc'});
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200)
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAdminReports() async {
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/reports')
          .replace(queryParameters: {'order': 'created_at.desc'});
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200)
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAdminUsers() async {
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/profiles')
          .replace(queryParameters: {'order': 'created_at.desc'});
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200)
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAdminAds() async {
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/ads')
          .replace(queryParameters: {'order': 'created_at.desc'});
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200)
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAdminJobs() async {
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/jobs')
          .replace(queryParameters: {'order': 'created_at.desc'});
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200)
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAdminLogs(
      {String action = 'all', String role = 'all', int limit = 100}) async =>
      getActivityLogs(action: action, role: role, limit: limit);

  Future<Map<String, dynamic>> approveVendor(dynamic vendorId) async {
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/vendors')
          .replace(queryParameters: {'id': 'eq.${vendorId.toString()}'});
      final res = await http.patch(uri,
          headers: _headersWithPreference,
          body: jsonEncode({'is_approved': true}));
      if (res.statusCode == 200) return _ok();
      return _err('Approve failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> revokeVendor(dynamic vendorId) async {
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/vendors')
          .replace(queryParameters: {'id': 'eq.${vendorId.toString()}'});
      final res = await http.patch(uri,
          headers: _headersWithPreference,
          body: jsonEncode({'is_approved': false}));
      if (res.statusCode == 200) return _ok();
      return _err('Revoke failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> deleteAdminVendor(dynamic vendorId) async {
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/vendors')
          .replace(queryParameters: {'id': 'eq.${vendorId.toString()}'});
      final res = await http.delete(uri, headers: _headers);
      if (res.statusCode == 204 || res.statusCode == 200) return _ok();
      return _err('Delete failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> createAdminVendor(
      Map<String, dynamic> data) async {
    try {
      final res = await http.post(Uri.parse('$_baseUrl/rest/v1/vendors'),
          headers: _headersWithPreference,
          body: jsonEncode({...data, 'is_approved': true}));
      if (res.statusCode == 201) {
        final resData = jsonDecode(res.body);
        final vendor =
        resData is List && resData.isNotEmpty ? resData.first : resData;
        return _ok({'vendor_id': vendor['id']});
      }
      return _err('Vendor creation failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> approveReview(dynamic reviewId) async {
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/vendor_reviews')
          .replace(queryParameters: {'id': 'eq.${reviewId.toString()}'});
      final res = await http.patch(uri,
          headers: _headersWithPreference,
          body: jsonEncode({'is_approved': true}));
      if (res.statusCode == 200) return _ok();
      return _err('Approve failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> deleteAdminReview(dynamic reviewId) async {
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/vendor_reviews')
          .replace(queryParameters: {'id': 'eq.${reviewId.toString()}'});
      final res = await http.delete(uri, headers: _headers);
      if (res.statusCode == 204 || res.statusCode == 200) return _ok();
      return _err('Delete failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> updateAdminReport(
      dynamic reportId, String status, String notes) async =>
      updateReport(reportId.toString(), status, notes);

  Future<Map<String, dynamic>> updateUserCredits(
      dynamic userId, int delta) async {
    try {
      final profileRes = await http.get(
          Uri.parse(
              '$_baseUrl/rest/v1/profiles?id=eq.${userId.toString()}&select=credit_balance'),
          headers: _headers);
      if (profileRes.statusCode != 200) return _err('Failed to fetch balance');
      final list =
      List<Map<String, dynamic>>.from(jsonDecode(profileRes.body));
      if (list.isEmpty) return _err('User not found');
      final current = (list.first['credit_balance'] as int? ?? 0);
      final newBalance = (current + delta).clamp(0, 9999);
      final uri = Uri.parse('$_baseUrl/rest/v1/profiles')
          .replace(queryParameters: {'id': 'eq.${userId.toString()}'});
      final res = await http.patch(uri,
          headers: _headersWithPreference,
          body: jsonEncode({'credit_balance': newBalance}));
      if (res.statusCode == 200) return _ok({'newBalance': newBalance});
      return _err('Credit update failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> blockUser(dynamic userId) async {
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/profiles')
          .replace(queryParameters: {'id': 'eq.${userId.toString()}'});
      final res = await http.patch(uri,
          headers: _headersWithPreference,
          body: jsonEncode({
            'is_blocked': true,
            'blocked_at': DateTime.now().toIso8601String()
          }));
      if (res.statusCode == 200) return _ok();
      return _err('Block failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> unblockUser(dynamic userId) async {
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/profiles')
          .replace(queryParameters: {'id': 'eq.${userId.toString()}'});
      final res = await http.patch(uri,
          headers: _headersWithPreference,
          body: jsonEncode({'is_blocked': false, 'blocked_at': null}));
      if (res.statusCode == 200) return _ok();
      return _err('Unblock failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> deleteAdminUser(dynamic userId) async =>
      deleteUser(userId.toString());

  Future<Map<String, dynamic>> editAdminUser(
      dynamic userId, Map<String, dynamic> data) async {
    try {
      final updates = <String, dynamic>{};
      if (data['name'] != null) updates['full_name'] = data['name'];
      if (updates.isEmpty) return _ok();
      final uri = Uri.parse('$_baseUrl/rest/v1/profiles')
          .replace(queryParameters: {'id': 'eq.${userId.toString()}'});
      final res = await http.patch(uri,
          headers: _headersWithPreference, body: jsonEncode(updates));
      if (res.statusCode == 200) return _ok();
      return _err('Edit failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> createAdminAd(Map<String, dynamic> data) async {
    try {
      final res = await http.post(Uri.parse('$_baseUrl/rest/v1/ads'),
          headers: _headersWithPreference,
          body: jsonEncode({
            'title': data['title'],
            'description': data['description'] ?? '',
            'url': data['url'],
            'credits_reward': data['credits'] ?? 1,
            'max_views_per_user': data['maxViews'] ?? 1,
            'is_active': data['isEnabled'] ?? true,
          }));
      if (res.statusCode == 201) {
        final resData = jsonDecode(res.body);
        final ad =
        resData is List && resData.isNotEmpty ? resData.first : resData;
        return _ok({'id': ad['id']});
      }
      return _err('Ad creation failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> updateAdminAd(
      dynamic adId, Map<String, dynamic> updates) async {
    try {
      final dbUpdates = <String, dynamic>{};
      if (updates.containsKey('title')) dbUpdates['title'] = updates['title'];
      if (updates.containsKey('description'))
        dbUpdates['description'] = updates['description'];
      if (updates.containsKey('url')) dbUpdates['url'] = updates['url'];
      if (updates.containsKey('credits'))
        dbUpdates['credits_reward'] = updates['credits'];
      if (updates.containsKey('maxViews'))
        dbUpdates['max_views_per_user'] = updates['maxViews'];
      if (updates.containsKey('isEnabled'))
        dbUpdates['is_active'] = updates['isEnabled'];
      if (dbUpdates.isEmpty) return _ok();
      final uri = Uri.parse('$_baseUrl/rest/v1/ads')
          .replace(queryParameters: {'id': 'eq.${adId.toString()}'});
      final res = await http.patch(uri,
          headers: _headersWithPreference, body: jsonEncode(dbUpdates));
      if (res.statusCode == 200) return _ok();
      return _err('Ad update failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> deleteAdminAd(dynamic adId) async {
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/ads')
          .replace(queryParameters: {'id': 'eq.${adId.toString()}'});
      final res = await http.delete(uri, headers: _headers);
      if (res.statusCode == 204 || res.statusCode == 200) return _ok();
      return _err('Ad delete failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> approveJob(dynamic jobId) async {
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/jobs')
          .replace(queryParameters: {'id': 'eq.${jobId.toString()}'});
      final res = await http.patch(uri,
          headers: _headersWithPreference,
          body: jsonEncode({'is_approved': true}));
      if (res.statusCode == 200) return _ok();
      return _err('Approve failed (${res.statusCode})');
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> deleteAdminJob(dynamic jobId) async =>
      deleteJob(jobId.toString());

  Future<Map<String, dynamic>> addAdminDistrict(String name) async =>
      createDistrict(name);

  Future<Map<String, dynamic>> deleteAdminDistrict(String districtName) async {
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/districts').replace(
          queryParameters: {'name': 'eq.$districtName', 'select': 'id'});
      final lookupRes = await http.get(uri, headers: _headers);
      if (lookupRes.statusCode != 200) return _err('District lookup failed');
      final list =
      List<Map<String, dynamic>>.from(jsonDecode(lookupRes.body));
      if (list.isEmpty) return _err('District not found');
      return deleteDistrict(list.first['id'].toString());
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> addAdminLocality(
      String districtName, String localityName) async {
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/districts').replace(
          queryParameters: {'name': 'eq.$districtName', 'select': 'id'});
      final lookupRes = await http.get(uri, headers: _headers);
      if (lookupRes.statusCode != 200) return _err('District lookup failed');
      final list =
      List<Map<String, dynamic>>.from(jsonDecode(lookupRes.body));
      if (list.isEmpty) return _err('District not found');
      return createLocality(list.first['id'].toString(), localityName);
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> deleteAdminLocality(
      String districtName, String localityName) async {
    try {
      final districtUri = Uri.parse('$_baseUrl/rest/v1/districts').replace(
          queryParameters: {'name': 'eq.$districtName', 'select': 'id'});
      final districtRes = await http.get(districtUri, headers: _headers);
      if (districtRes.statusCode != 200) return _err('District lookup failed');
      final districts =
      List<Map<String, dynamic>>.from(jsonDecode(districtRes.body));
      if (districts.isEmpty) return _err('District not found');
      final districtId = districts.first['id'].toString();
      final localityUri = Uri.parse('$_baseUrl/rest/v1/localities').replace(
          queryParameters: {
            'district_id': 'eq.$districtId',
            'name': 'eq.$localityName',
            'select': 'id'
          });
      final localityRes = await http.get(localityUri, headers: _headers);
      if (localityRes.statusCode != 200) return _err('Locality lookup failed');
      final localities =
      List<Map<String, dynamic>>.from(jsonDecode(localityRes.body));
      if (localities.isEmpty) return _err('Locality not found');
      return deleteLocality(localities.first['id'].toString());
    } catch (e) {
      return _err('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> createAdminServiceCategory(
      Map<String, dynamic> entry) async =>
      createServiceCategory(entry);

  Future<Map<String, dynamic>> updateAdminServiceCategory(
      dynamic categoryId, Map<String, dynamic> entry) async =>
      updateServiceCategory(categoryId.toString(), entry);

  Future<Map<String, dynamic>> deleteAdminServiceCategory(
      dynamic categoryId) async =>
      deleteServiceCategory(categoryId.toString());

  Future<Map<String, dynamic>> reorderAdminServiceCategories(
      List<int> orderedIds) async =>
      reorderServiceCategories(orderedIds.map((id) => id.toString()).toList());

  Future<Map<String, String>> buildLocalityLookup() async {
    try {
      final res = await http.get(
          Uri.parse('$_baseUrl/rest/v1/localities?select=id,name'),
          headers: _headers);
      if (res.statusCode == 200) {
        final list = List<Map<String, dynamic>>.from(jsonDecode(res.body));
        return {
          for (final item in list)
            item['id'].toString(): item['name'] as String? ?? ''
        };
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> getAdminReviewsWithNames() async {
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/vendor_reviews').replace(
          queryParameters: {
            'select':
            'id,vendor_id,user_id,rating,review_text,is_approved,created_at,vendors(business_name),profiles(full_name)',
            'order': 'created_at.desc'
          });
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200)
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      return await getAdminReviews();
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAdminReportsWithDetails() async {
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/reports').replace(
          queryParameters: {
            'select': 'id,reporter_id,reported_vendor_id,report_type,description,status,admin_notes,created_at,vendors(business_name,phone)',
            'order': 'created_at.desc'
          });
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200) {
        final reports = List<Map<String, dynamic>>.from(jsonDecode(res.body));

        // Fetch reporter phones separately
        final reporterIds = reports
            .where((r) => r['reporter_id'] != null)
            .map((r) => r['reporter_id'].toString())
            .toList();

        Map<String, String> reporterPhones = {};
        if (reporterIds.isNotEmpty) {
          final phoneResult = await getUserPhones(reporterIds);
          if (phoneResult['success'] == true) {
            final phones = phoneResult['phones'] as Map<String, dynamic>? ?? {};
            reporterPhones = phones.map((k, v) => MapEntry(k, v.toString()));
          }
        }

        // Attach reporter phone to each report
        return reports.map((r) {
          final reporterId = r['reporter_id']?.toString() ?? '';
          return {
            ...r,
            'reporter_phone': reporterPhones[reporterId] ?? '',
          };
        }).toList();
      }
      return await getAdminReports();
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAdminLogsWithNames(
      {String action = 'all', String role = 'all', int limit = 100}) async {
    try {
      final params = <String, String>{
        'select':
        'id,action,entity_type,entity_id,entity_name,performed_by,performer_type,details,created_at,profiles(full_name)',
        'order': 'id.desc',
        'limit': '$limit',
        if (action != 'all') 'action': 'eq.$action',
        if (role != 'all') 'performer_type': 'eq.$role',
      };
      final uri = Uri.parse('$_baseUrl/rest/v1/activity_logs')
          .replace(queryParameters: params);
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200)
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      return await getAdminLogs(action: action, role: role, limit: limit);
    } catch (e) {
      return [];
    }
  }

  Future<bool> isVendorAlreadyUnlocked(String vendorId) async {
    try {
      if (userId == null) return false;
      final uri =
      Uri.parse('$_baseUrl/rest/v1/unlocked_vendor_contacts').replace(
          queryParameters: {
            'user_id': 'eq.$userId',
            'vendor_id': 'eq.$vendorId',
            'select': 'id'
          });
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200)
        return (jsonDecode(res.body) as List).isNotEmpty;
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<Set<String>> getAlreadyUnlockedVendorIds() async {
    try {
      final list = await getUnlockedVendors();
      return list.map((e) => e['vendor_id'].toString()).toSet();
    } catch (e) {
      return {};
    }
  }

  Future<Map<String, int>> getUserAdViewCounts() async {
    try {
      if (userId == null) return {};
      final uri = Uri.parse('$_baseUrl/rest/v1/ad_views').replace(
          queryParameters: {'user_id': 'eq.$userId', 'select': 'ad_id'});
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200) {
        final list = List<Map<String, dynamic>>.from(jsonDecode(res.body));
        final counts = <String, int>{};
        for (final row in list) {
          final id = row['ad_id'].toString();
          counts[id] = (counts[id] ?? 0) + 1;
        }
        return counts;
      }
      return {};
    } catch (e) {
      return {};
    }
  }
  Future<Map<String, dynamic>> deleteSelf() async {
    try {
      // Supabase Auth allows a user to delete themselves
      // via DELETE /auth/v1/user with their own Bearer token
      final res = await http.delete(
        Uri.parse('$_baseUrl/auth/v1/user'),
        headers: _headers,
      );
      if (res.statusCode == 200) return _ok();

      String errorMsg = 'Delete failed (${res.statusCode})';
      try {
        final body = jsonDecode(res.body);
        errorMsg = body['message'] ?? body['error_description'] ?? errorMsg;
      } catch (_) {}

      return _err(errorMsg);
    } catch (e) {
      return _err('Network error: $e');
    }
  }
}
