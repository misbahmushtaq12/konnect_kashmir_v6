/// The groups the service categories are shown in: the same nine, in the same
/// order, as the website's Home and Browse pages (Featured, Home & Repair, ...).
///
/// Which group a category belongs to is decided by an admin, in the database
/// (`service_categories.group_key`), and the order inside a group by
/// `display_order`. Nothing here knows any category: a category that is added or
/// moved shows up in its group with no change to the app.
///
/// [CategoryGroup.featured] has no key of its own: it holds the categories an
/// admin has pinned (`is_pinned`, for example Instagram Shops). A pinned category
/// is shown there and also stays in its own group.
enum CategoryGroup {
  featured(null, 'Featured'),
  homeRepair('home_repair', 'Home & Repair'),
  healthEducation('health_education', 'Health & Education'),
  foodGrocery('food_grocery', 'Food & Grocery'),
  fashionShopping('fashion_shopping', 'Fashion & Shopping'),
  businessProfessional('business_professional', 'Business & Professional'),
  eventsTravel('events_travel', 'Events & Travel'),
  moreServices('more_services', 'More Services'),
  other('other', 'Other');

  /// The value of `service_categories.group_key` (null for Featured).
  final String? key;

  /// English name (Hindi and Urdu are in l10n/category_names.dart).
  final String label;
  const CategoryGroup(this.key, this.label);

  /// The group a `group_key` names. A category that has no group yet (null: the
  /// admin has not placed it), or one with a key this app does not know, is shown
  /// under [other], as on the website.
  static CategoryGroup fromKey(Object? key) {
    final k = key?.toString().trim();
    if (k == null || k.isEmpty) return other;
    for (final g in values) {
      if (g.key == k) return g;
    }
    return other;
  }
}

class CategoryGroups {
  CategoryGroups._();

  /// [items] split into groups, in the groups' fixed order. Groups with nothing in
  /// them are left out (so Featured is hidden when nothing is pinned).
  ///
  /// Inside every group the categories are in `display_order` ([orderOf]), then by
  /// name ([nameOf]); two with both the same keep the order they came in.
  ///
  /// Items for which [pinned] says true form the Featured group (in the same
  /// order). They also stay in their own group. With [limit], only the first
  /// [limit] categories counting group by group are kept (the collapsed Home
  /// view); Featured is never cut by it.
  static List<({CategoryGroup group, List<T> items})> group<T>(
    Iterable<T> items, {
    required String? Function(T item) groupKeyOf,
    bool Function(T item)? pinned,
    int Function(T item)? orderOf,
    String Function(T item)? nameOf,
    int? limit,
  }) {
    final all = items.toList();
    // Sorted by display order, then name; ties keep the order they came in.
    final order = List<int>.generate(all.length, (i) => i)
      ..sort((i, j) {
        final byOrder = (orderOf?.call(all[i]) ?? 0).compareTo(
          orderOf?.call(all[j]) ?? 0,
        );
        if (byOrder != 0) return byOrder;
        final byName = (nameOf?.call(all[i]) ?? '').toLowerCase().compareTo(
          (nameOf?.call(all[j]) ?? '').toLowerCase(),
        );
        return byName != 0 ? byName : i.compareTo(j);
      });
    final sorted = [for (final i in order) all[i]];

    final byGroup = {for (final g in CategoryGroup.values) g: <T>[]};
    for (final it in sorted) {
      // A category with no group (or an unknown one) is under Other.
      byGroup[CategoryGroup.fromKey(groupKeyOf(it))]!.add(it);
      // Pinned ones are also shown first, under Featured.
      if (pinned != null && pinned(it)) {
        byGroup[CategoryGroup.featured]!.add(it);
      }
    }

    final out = <({CategoryGroup group, List<T> items})>[];
    var left = limit;
    for (final g in CategoryGroup.values) {
      var list = byGroup[g]!;
      if (list.isEmpty) continue;
      if (g == CategoryGroup.featured) {
        out.add((group: g, items: list));
        continue;
      }
      if (left != null) {
        if (left <= 0) break;
        if (list.length > left) list = list.sublist(0, left);
        left -= list.length;
      }
      out.add((group: g, items: list));
    }
    return out;
  }
}
