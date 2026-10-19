/// The groups the service categories are shown in, the same ones the website's
/// Browse page uses (Home & Repair, Health & Education, ...).
///
/// The database has no group column, so the website decides the group of each
/// category by its slug. This copies that table; a slug it does not know goes to
/// [CategoryGroup.moreServices], as on the website.
enum CategoryGroup {
  homeRepair('Home & Repair'),
  healthEducation('Health & Education'),
  foodGrocery('Food & Grocery'),
  fashionShopping('Fashion & Shopping'),
  businessProfessional('Business & Professional'),
  eventsTravel('Events & Travel'),
  moreServices('More Services'),
  other('Other');

  /// English name (Hindi and Urdu are in l10n/category_names.dart).
  final String label;
  const CategoryGroup(this.label);
}

class CategoryGroups {
  CategoryGroups._();

  static const Map<String, CategoryGroup> _bySlug = {
    // Home & Repair
    'home_services': CategoryGroup.homeRepair,
    'electrician': CategoryGroup.homeRepair,
    'plumber': CategoryGroup.homeRepair,
    'carpenter': CategoryGroup.homeRepair,
    'painter': CategoryGroup.homeRepair,
    'mason_dasil': CategoryGroup.homeRepair,
    'labour': CategoryGroup.homeRepair,
    'gardener': CategoryGroup.homeRepair,
    'cleaner': CategoryGroup.homeRepair,
    'laptop_mobile_repair': CategoryGroup.homeRepair,
    'appliance_repair': CategoryGroup.homeRepair,
    'laundry': CategoryGroup.homeRepair,
    'cctv_security': CategoryGroup.homeRepair,
    'solar_installer': CategoryGroup.homeRepair,
    'building_material': CategoryGroup.homeRepair,
    'interior-designers': CategoryGroup.homeRepair,
    'flooring_and_furnishing': CategoryGroup.homeRepair,
    'steel_iron_works': CategoryGroup.homeRepair,
    'heating-hamams': CategoryGroup.homeRepair,
    // Health & Education
    'home_tutor': CategoryGroup.healthEducation,
    'professional_instructor': CategoryGroup.healthEducation,
    'education_consultant': CategoryGroup.healthEducation,
    'pharmacy': CategoryGroup.healthEducation,
    'psychiatrist_therapist': CategoryGroup.healthEducation,
    'physiotherapist': CategoryGroup.healthEducation,
    'hijama': CategoryGroup.healthEducation,
    'clinics': CategoryGroup.healthEducation,
    'labs_diagnostics': CategoryGroup.healthEducation,
    'training_fitness': CategoryGroup.healthEducation,
    // Food & Grocery
    'food-items': CategoryGroup.foodGrocery,
    'beverages': CategoryGroup.foodGrocery,
    'grocery': CategoryGroup.foodGrocery,
    'bakery': CategoryGroup.foodGrocery,
    'catering': CategoryGroup.foodGrocery,
    // Fashion & Shopping
    'tailor': CategoryGroup.fashionShopping,
    'mens-clothing': CategoryGroup.fashionShopping,
    'womens-clothing': CategoryGroup.fashionShopping,
    'shoes': CategoryGroup.fashionShopping,
    'kidswear': CategoryGroup.fashionShopping,
    'makeup_artist': CategoryGroup.fashionShopping,
    'mehndi_artist': CategoryGroup.fashionShopping,
    // Business & Professional
    'architect': CategoryGroup.businessProfessional,
    'lawyer': CategoryGroup.businessProfessional,
    'chartered_accountant': CategoryGroup.businessProfessional,
    'property_dealer': CategoryGroup.businessProfessional,
    'buliders_developers': CategoryGroup.businessProfessional,
    'insurance_agent': CategoryGroup.businessProfessional,
    'designer': CategoryGroup.businessProfessional,
    'web_mobile': CategoryGroup.businessProfessional,
    'sales_marketing': CategoryGroup.businessProfessional,
    'advertisement_hoardings': CategoryGroup.businessProfessional,
    // Events & Travel
    'wedding': CategoryGroup.eventsTravel,
    'photography': CategoryGroup.eventsTravel,
    'tent': CategoryGroup.eventsTravel,
    'tour_travels': CategoryGroup.eventsTravel,
    'hajj_umrah': CategoryGroup.eventsTravel,
    'musician': CategoryGroup.eventsTravel,
    'custom_gifting': CategoryGroup.eventsTravel,
    // Other
    'other': CategoryGroup.other,
  };

  /// The group of a category slug.
  static CategoryGroup of(String slug) =>
      _bySlug[slug] ?? CategoryGroup.moreServices;

  /// [items] split into groups, in the groups' order. A group keeps its
  /// categories in the order given (the database's display order), and groups
  /// with nothing in them are left out. With [limit], only the first [limit]
  /// categories counting group by group are kept (the collapsed Home view).
  static List<({CategoryGroup group, List<T> items})> group<T>(
    Iterable<T> items,
    String Function(T item) slugOf, {
    int? limit,
  }) {
    final byGroup = {for (final g in CategoryGroup.values) g: <T>[]};
    for (final it in items) {
      byGroup[of(slugOf(it))]!.add(it);
    }
    final out = <({CategoryGroup group, List<T> items})>[];
    var left = limit;
    for (final g in CategoryGroup.values) {
      var list = byGroup[g]!;
      if (list.isEmpty) continue;
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
