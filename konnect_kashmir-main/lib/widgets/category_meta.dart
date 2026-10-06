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
    'all': CategoryMeta(Icons.auto_awesome, Color(0xFF2E9A7B)),
    'home_services': CategoryMeta(Icons.home_repair_service, Color(0xFFE5872A)),
    'electrician': CategoryMeta(Icons.bolt, Color(0xFFF2B01E)),
    'plumber': CategoryMeta(Icons.plumbing, Color(0xFF29A3E0)),
    'carpenter': CategoryMeta(Icons.handyman, Color(0xFFE0652E)),
    'painter': CategoryMeta(Icons.format_paint, Color(0xFF9B59D0)),
    'mason': CategoryMeta(Icons.construction, Color(0xFFE28B54)),
    'labour': CategoryMeta(Icons.engineering, Color(0xFF7A8C99)),
    'gardener': CategoryMeta(Icons.park, Color(0xFF43A857)),
    'tailor': CategoryMeta(Icons.checkroom, Color(0xFF9D4EDD)),
    'cleaner': CategoryMeta(Icons.cleaning_services, Color(0xFF1BB5C9)),
    'tutor': CategoryMeta(Icons.school, Color(0xFF339985)),
    'professional_trainers': CategoryMeta(Icons.sports, Color(0xFFDB4C7B)),
    'education': CategoryMeta(Icons.menu_book, Color(0xFF4A5FC1)),
    'health_medicine': CategoryMeta(Icons.medical_services, Color(0xFF1B998B)),
    'psychiatrist': CategoryMeta(Icons.psychology, Color(0xFF2E9A7B)),
    'physio': CategoryMeta(Icons.monitor_heart, Color(0xFF5ABCB9)),
    'laptop_repair': CategoryMeta(Icons.devices, Color(0xFF6C63D9)),
    'appliance_repair': CategoryMeta(Icons.kitchen, Color(0xFF8A9A98)),
    'laundry': CategoryMeta(Icons.local_laundry_service, Color(0xFF3F8EDB)),
    'food_beverages': CategoryMeta(Icons.restaurant, Color(0xFFD64545)),
    'mechanic': CategoryMeta(Icons.car_repair, Color(0xFF5F7D95)),
    'driver': CategoryMeta(Icons.directions_car, Color(0xFF3F8EDB)),
    'car_rental': CategoryMeta(Icons.car_rental, Color(0xFF6C63D9)),
    'car_wash': CategoryMeta(Icons.local_car_wash, Color(0xFF1BB5C9)),
    'furniture': CategoryMeta(Icons.chair, Color(0xFFD68A2E)),
    'architect': CategoryMeta(Icons.architecture, Color(0xFF7A8C99)),
    'lawyer': CategoryMeta(Icons.balance, Color(0xFF4A5FC1)),
    'accounting': CategoryMeta(Icons.calculate, Color(0xFF43A857)),
    'property_dealers': CategoryMeta(Icons.real_estate_agent, Color(0xFF2E9A7B)),
    'builders': CategoryMeta(Icons.location_city, Color(0xFF5F7D95)),
    'insurance': CategoryMeta(Icons.shield, Color(0xFF339985)),
    'digital_services': CategoryMeta(Icons.computer, Color(0xFF9B59D0)),
    'developer': CategoryMeta(Icons.code, Color(0xFF4A5FC1)),
    'artisan': CategoryMeta(Icons.brush, Color(0xFFE0652E)),
    'copperware': CategoryMeta(Icons.coffee_maker, Color(0xFFD64545)),
    'steel': CategoryMeta(Icons.hardware, Color(0xFF7A8C99)),
    'transport': CategoryMeta(Icons.local_shipping, Color(0xFFD64545)),
    'movers': CategoryMeta(Icons.inventory_2, Color(0xFFE5872A)),
    'wedding': CategoryMeta(Icons.favorite, Color(0xFFE8508C)),
    'middleman': CategoryMeta(Icons.handshake, Color(0xFF8A9A98)),
    'photography': CategoryMeta(Icons.camera_alt, Color(0xFF1BB5C9)),
    'tent': CategoryMeta(Icons.festival, Color(0xFF9B59D0)),
    'catering': CategoryMeta(Icons.room_service, Color(0xFFD64545)),
    'bakery': CategoryMeta(Icons.cake, Color(0xFF7A8C99)),
    'mehndi': CategoryMeta(Icons.back_hand, Color(0xFFE5872A)),
    'makeup': CategoryMeta(Icons.face_retouching_natural, Color(0xFFE8508C)),
    'gifting': CategoryMeta(Icons.card_giftcard, Color(0xFF43A857)),
    'tour': CategoryMeta(Icons.flight_takeoff, Color(0xFF3F8EDB)),
    'hijama': CategoryMeta(Icons.spa, Color(0xFFD64545)),
    'advertising': CategoryMeta(Icons.campaign, Color(0xFF6C63D9)),
    'hajj': CategoryMeta(Icons.mosque, Color(0xFF2E9A7B)),
    'pet': CategoryMeta(Icons.pets, Color(0xFFF2B01E)),
    'cctv': CategoryMeta(Icons.videocam, Color(0xFF3F8EDB)),
    'solar': CategoryMeta(Icons.solar_power, Color(0xFFE5872A)),
    'scrap': CategoryMeta(Icons.recycling, Color(0xFF43A857)),
    'sales': CategoryMeta(Icons.business_center, Color(0xFF9B59D0)),
    'music': CategoryMeta(Icons.music_note, Color(0xFF4A5FC1)),
    'other': CategoryMeta(Icons.more_horiz, Color(0xFF8A9A98)),
  };

  static CategoryMeta of(String? slug) => _map[slug] ?? fallback;

  static List<Map<String, dynamic>> get allCategories {
    return _map.entries.map((e) => {
      'slug': e.key,
      'name': e.key.split('_').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' '),
    }).toList();
  }
}
