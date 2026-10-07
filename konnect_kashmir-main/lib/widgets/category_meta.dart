import 'package:flutter/material.dart';

/// Icon + color for each service category slug.
/// Shared so Home, Search and Dashboard all show the same icons.
class CategoryMeta {
  final IconData icon;
  final Color color;
  const CategoryMeta(this.icon, this.color);

  static const CategoryMeta fallback =
      CategoryMeta(Icons.miscellaneous_services, Color(0xFF8A9A98));

  static const Map<String, CategoryMeta> _map = {
    'plumber': CategoryMeta(Icons.plumbing, Color(0xFF29A3E0)),
    'electrician': CategoryMeta(Icons.bolt, Color(0xFFF2B01E)),
    'carpenter': CategoryMeta(Icons.handyman, Color(0xFFE0652E)),
    'painter': CategoryMeta(Icons.format_paint, Color(0xFF9B59D0)),
    'cleaner': CategoryMeta(Icons.cleaning_services, Color(0xFF1BB5C9)),
    'appliance_repair': CategoryMeta(Icons.settings, Color(0xFF8A9A98)),
    'pest_control': CategoryMeta(Icons.pest_control, Color(0xFF43A857)),
    'interior_designer': CategoryMeta(Icons.design_services, Color(0xFFE8508C)),
    'photography': CategoryMeta(Icons.camera_alt, Color(0xFFF08A3C)),
    'catering': CategoryMeta(Icons.restaurant, Color(0xFFD64545)),
    'mechanic': CategoryMeta(Icons.car_repair, Color(0xFF5F7D95)),
    'home_tutor': CategoryMeta(Icons.school, Color(0xFF339985)),
    'tailor': CategoryMeta(Icons.checkroom, Color(0xFF4A5FC1)),
    'car_rental': CategoryMeta(Icons.directions_car, Color(0xFF3F8EDB)),
    'developer': CategoryMeta(Icons.code, Color(0xFF6C63D9)),
    'home_services': CategoryMeta(Icons.home_repair_service, Color(0xFFC07B3E)),
    'mason': CategoryMeta(Icons.settings, Color(0xFF5F7D95)),
    'labour': CategoryMeta(Icons.engineering, Color(0xFF5F7D95)),
  };

  static CategoryMeta of(String? slug) => _map[slug] ?? fallback;

  static const List<Map<String, dynamic>> allCategories = [
    {'slug': 'electrician', 'name': 'Electrician'},
    {'slug': 'painter', 'name': 'Painter'},
    {'slug': 'carpenter', 'name': 'Carpenter'},
    {'slug': 'home_services', 'name': 'Home Services'},
    {'slug': 'tailor', 'name': 'Tailor'},
    {'slug': 'plumber', 'name': 'Plumber'},
    {'slug': 'mason', 'name': 'Mason (Dasil)'},
    {'slug': 'labour', 'name': 'Labour / Helper'},
    {'slug': 'cleaner', 'name': 'Cleaning'},
    {'slug': 'appliance_repair', 'name': 'Appliance Repair'},
    {'slug': 'pest_control', 'name': 'Pest Control'},
    {'slug': 'interior_designer', 'name': 'Interior Design'},
    {'slug': 'photography', 'name': 'Photography'},
    {'slug': 'catering', 'name': 'Catering'},
    {'slug': 'mechanic', 'name': 'Mechanic'},
    {'slug': 'home_tutor', 'name': 'Tutoring'},
    {'slug': 'car_rental', 'name': 'Car Rental'},
    {'slug': 'developer', 'name': 'Web Development'},
  ];
}
