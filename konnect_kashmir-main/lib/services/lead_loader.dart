import '../providers/auth_provider.dart';
import 'api_service.dart';

/// Loads lead names for the given vendors. If the server rejects the request
/// (e.g. an expired/invalid session token) the token is refreshed once and the
/// request retried, so leads don't silently show up as 0.
///
/// Returns the usual `{success, leads | error}` map from [ApiService].
Future<Map<String, dynamic>> fetchLeadNames(
    AuthProvider auth, List<String> vendorIds) async {
  ApiService api() =>
      ApiService(token: auth.accessToken, userId: auth.userId);

  var result = await api().getLeadNames(vendorIds);
  if (result['success'] != true && await auth.refreshToken()) {
    result = await api().getLeadNames(vendorIds);
  }
  return result;
}
