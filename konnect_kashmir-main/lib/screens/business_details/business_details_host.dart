import 'package:flutter/widgets.dart';

import '../../services/api_service.dart';

/// Where a business's details come from. The app uses [ApiBusinessDetailsSource];
/// the tests give their own.
abstract class BusinessDetailsSource {
  /// The business, or null when there is no such approved business. Throws when
  /// it could not be asked (no internet), so the screen can offer a retry.
  Future<Map<String, dynamic>?> details(String id);

  /// The slugs of every category the business is listed in.
  Future<List<String>> categorySlugs(String id);

  /// The approved reviews of the business.
  Future<List<Map<String, dynamic>>> reviews(String id);
}

class ApiBusinessDetailsSource implements BusinessDetailsSource {
  final ApiService api;
  const ApiBusinessDetailsSource(this.api);

  @override
  Future<Map<String, dynamic>?> details(String id) => api.getVendorDetails(id);

  @override
  Future<List<String>> categorySlugs(String id) async => [
    for (final r in await api.getVendorCategories([id]))
      if ((r['category_slug'] ?? '').toString().isNotEmpty)
        r['category_slug'].toString(),
  ];

  @override
  Future<List<Map<String, dynamic>>> reviews(String id) =>
      api.getVendorReviews(id);
}

/// What the details screen needs from the screen that opened it.
///
/// Unlocking a contact (spending a credit, or watching an ad for one), the saved
/// numbers, tracking a call as a lead, writing a review and reporting are all
/// done by the Home screen already. Instead of copying that, the details screen
/// asks the Home screen to do it through this, so both always behave the same.
abstract class BusinessDetailsHost {
  BusinessDetailsSource get source;

  /// Fires whenever something the details screen shows may have changed
  /// (a contact was unlocked, the credits changed, the user signed in).
  Listenable get changes;

  bool get isSignedIn;
  int get credits;

  bool isUnlocked(String id);
  bool isUnlocking(String id);

  /// The unlocked phone number; empty while the contact is locked (or the number
  /// has not come back yet; see [resolvePhone]).
  String phoneOf(String id, Map<String, dynamic> vendor);

  /// Asks for the number of a contact that is unlocked but whose number was not
  /// in the list. Safe to call again; it asks once.
  void resolvePhone(String id);

  /// The category's name in the app language.
  String categoryLabel(BuildContext context, String slug);

  /// Unlocks the contact with a credit, or after an ad when there is none.
  Future<void> unlock(Map<String, dynamic> vendor);
  void signIn();

  Future<void> call(String phone, String id);
  Future<void> whatsApp(String phone, String id);
  Future<void> openMap(Uri uri);

  /// The "leave a review" form (only for a contact that is unlocked).
  Widget reviewForm(String id);
  void report(Map<String, dynamic> vendor);
}
