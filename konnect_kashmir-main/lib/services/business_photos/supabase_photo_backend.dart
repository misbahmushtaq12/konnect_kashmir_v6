import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../backend_config.dart';
import '../shared_http.dart';
import 'business_photo_service.dart';
import 'photo_rules.dart';

/// The real [BusinessPhotoBackend]: PostgREST for the `business_photos` table
/// and the Storage API for the private `business-photos` bucket, with the
/// signed-in user's token (the public key alone for reading).
class SupabasePhotoBackend implements BusinessPhotoBackend {
  /// The signed-in user's token, asked for at each request (it is renewed now
  /// and then).
  final String? Function() _token;
  final http.Client _client;

  SupabasePhotoBackend({String? Function()? token, http.Client? client})
    : _token = token ?? (() => null),
      _client = client ?? sharedHttp;

  static const Duration _timeout = Duration(seconds: 30);

  Map<String, String> _headers([Map<String, String>? more]) => {
    'apikey': kSupabaseAnonKey,
    'Authorization': 'Bearer ${_token() ?? kSupabaseAnonKey}',
    ...?more,
  };

  Uri _rest(String path, [Map<String, String>? query]) =>
      Uri.parse('$kSupabaseUrl/rest/v1/$path').replace(queryParameters: query);

  Uri _storage(String path) => Uri.parse('$kSupabaseUrl/storage/v1/$path');

  /// The path with each part escaped, for use inside a URL.
  static String _escaped(String path) =>
      path.split('/').map(Uri.encodeComponent).join('/');

  PhotoBackendException _failure(http.Response res) {
    var message = 'HTTP ${res.statusCode}';
    try {
      final body = jsonDecode(res.body);
      if (body is Map) {
        message = '${body['message'] ?? body['error'] ?? message}';
      }
    } catch (_) {}
    return PhotoBackendException(message, statusCode: res.statusCode);
  }

  @override
  Future<List<BusinessPhoto>> rows(
    String vendorId, {
    bool approvedOnly = false,
  }) async {
    final res = await _client
        .get(
          _rest('business_photos', {
            'select':
                'id,vendor_id,storage_path,sort_order,created_at,status,rejection_reason',
            'vendor_id': 'eq.$vendorId',
            if (approvedOnly) 'status': 'eq.approved',
            'order': 'sort_order.asc,created_at.asc',
          }),
          headers: _headers(),
        )
        .timeout(_timeout);
    if (res.statusCode != 200) throw _failure(res);
    final list = jsonDecode(res.body);
    if (list is! List) throw const PhotoBackendException('Unexpected answer');
    return [
      for (final r in list)
        if (r is Map) BusinessPhoto.fromRow(Map<String, dynamic>.from(r)),
    ];
  }

  @override
  Future<Map<String, String>> signedUrls(List<String> publicPaths) async {
    // Only public copies are ever signed.
    final paths = [
      for (final p in publicPaths)
        if (isPublicPhotoPath(p)) p,
    ];
    if (paths.isEmpty) return const {};
    final res = await _client
        .post(
          _storage('object/sign/$kPhotoBucket'),
          headers: _headers({'Content-Type': 'application/json'}),
          body: jsonEncode({
            'expiresIn': kSignedUrlLifetime.inSeconds,
            'paths': paths,
          }),
        )
        .timeout(_timeout);
    if (res.statusCode != 200) throw _failure(res);
    final list = jsonDecode(res.body);
    final out = <String, String>{};
    if (list is List) {
      for (final e in list) {
        if (e is! Map) continue;
        final path = e['path'];
        final signed = e['signedURL'];
        if (path is String && signed is String && e['error'] == null) {
          // The answer is relative to the Storage API.
          out[path] = signed.startsWith('http')
              ? signed
              : '$kSupabaseUrl/storage/v1${signed.startsWith('/') ? '' : '/'}$signed';
        }
      }
    }
    return out;
  }

  @override
  Future<void> upload(String path, Uint8List bytes, String contentType) async {
    final res = await _client
        .post(
          _storage('object/$kPhotoBucket/${_escaped(path)}'),
          headers: _headers({
            'Content-Type': contentType,
            'Cache-Control': 'max-age=3600',
            'x-upsert': 'false',
          }),
          body: bytes,
        )
        .timeout(const Duration(seconds: 90));
    if (res.statusCode != 200 && res.statusCode != 201) throw _failure(res);
  }

  @override
  Future<void> removeFiles(List<String> paths) async {
    if (paths.isEmpty) return;
    final req = http.Request('DELETE', _storage('object/$kPhotoBucket'))
      ..headers.addAll(_headers({'Content-Type': 'application/json'}))
      ..body = jsonEncode({'prefixes': paths});
    final res = await http.Response.fromStream(
      await _client.send(req).timeout(_timeout),
    );
    if (res.statusCode != 200) throw _failure(res);
  }

  @override
  Future<BusinessPhoto> insertRow({
    required String vendorId,
    required String storagePath,
    required int sortOrder,
  }) async {
    final res = await _client
        .post(
          _rest('business_photos'),
          headers: _headers({
            'Content-Type': 'application/json',
            'Prefer': 'return=representation',
          }),
          body: jsonEncode({
            'vendor_id': vendorId,
            'storage_path': storagePath,
            'sort_order': sortOrder,
          }),
        )
        .timeout(_timeout);
    if (res.statusCode != 201 && res.statusCode != 200) throw _failure(res);
    final list = jsonDecode(res.body);
    if (list is List && list.isNotEmpty && list.first is Map) {
      return BusinessPhoto.fromRow(
        Map<String, dynamic>.from(list.first as Map),
      );
    }
    throw const PhotoBackendException('The photo was not saved');
  }

  @override
  Future<void> deleteRow(String id) async {
    final res = await _client
        .delete(
          _rest('business_photos', {'id': 'eq.$id'}),
          headers: _headers({'Prefer': 'return=representation'}),
        )
        .timeout(_timeout);
    if (res.statusCode != 200 && res.statusCode != 204) throw _failure(res);
    // A policy that hides the row answers "ok" with nothing deleted.
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body);
      if (list is List && list.isEmpty) {
        throw const PhotoBackendException('The photo was not deleted');
      }
    }
  }

  @override
  Future<void> updateSortOrder(String id, int sortOrder) async {
    final res = await _client
        .patch(
          _rest('business_photos', {'id': 'eq.$id'}),
          headers: _headers({
            'Content-Type': 'application/json',
            'Prefer': 'return=representation',
          }),
          body: jsonEncode({'sort_order': sortOrder}),
        )
        .timeout(_timeout);
    if (res.statusCode != 200 && res.statusCode != 204) throw _failure(res);
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body);
      if (list is List && list.isEmpty) {
        throw const PhotoBackendException('The order was not saved');
      }
    }
  }
}
