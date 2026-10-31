import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Icon + color for each service category slug.
/// Shared so Home, Search and Dashboard all show the same icons.
class CategoryMeta {
  final IconData icon;
  final Color color;
  const CategoryMeta(this.icon, this.color);

  /// Default common icon & brand color when a category has no specific icon.
  static const CategoryMeta fallback = CategoryMeta(
    Icons.category_rounded,
    Color(0xFF339985),
  );

  static const List<Color> _palette = [
    Color(0xFF339985), // Konnect Teal
    Color(0xFF43A857), // Green
    Color(0xFF29A3E0), // Sky Blue
    Color(0xFFE0652E), // Orange
    Color(0xFF9B59D0), // Purple
    Color(0xFFF2B01E), // Amber
    Color(0xFF1BB5C9), // Cyan
    Color(0xFFE8508C), // Pink
    Color(0xFF4A5FC1), // Indigo
    Color(0xFFC07B3E), // Brown/Wood
    Color(0xFF6C63D9), // Violet
    Color(0xFF5F7D95), // Slate
  ];

  /// Generates a consistent, harmonious palette color for new categories.
  static Color dynamicColor(String seed) {
    if (seed.isEmpty) return fallback.color;
    final hash = seed.codeUnits.fold(0, (acc, c) => acc + c);
    return _palette[hash.abs() % _palette.length];
  }

  /// Parses hex color strings like "#339985" or "339985".
  static Color? tryParseHex(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) {
      final val = int.tryParse('0xFF$clean');
      if (val != null) return Color(val);
    } else if (clean.length == 8) {
      final val = int.tryParse('0x$clean');
      if (val != null) return Color(val);
    }
    return null;
  }

  /// Font Awesome's Instagram logo (the same glyph as `FontAwesomeIcons.instagram`,
  /// which is not an [IconData] itself).
  static const IconData _instagram = IconData(
    0xf16d,
    fontFamily: 'FontAwesomeBrands',
    fontPackage: 'font_awesome_flutter',
  );

  /// The icons the website draws for the categories. The database gives each
  /// category an `icon_name` that is a Lucide icon name ("HousePlug", "Zap"...);
  /// the keys here are those names in lowercase. Lucide has no brand icons, so
  /// Instagram's comes from Font Awesome.
  static const Map<String, IconData> _websiteIcons = {
    'activity': LucideIcons.activity,
    'anvil': LucideIcons.anvil,
    'armchair': LucideIcons.armchair,
    'baby': LucideIcons.baby,
    'bookopen': LucideIcons.bookOpen,
    'brain': LucideIcons.brain,
    'brickwall': LucideIcons.brickWall,
    'briefcasebusiness': LucideIcons.briefcaseBusiness,
    'cake': LucideIcons.cake,
    'calculator': LucideIcons.calculator,
    'camera': LucideIcons.camera,
    'car': LucideIcons.car,
    'carfront': LucideIcons.carFront,
    'cctv': LucideIcons.cctv,
    'chefhat': LucideIcons.chefHat,
    'code': LucideIcons.code,
    'compass': LucideIcons.compass,
    'construction': LucideIcons.construction,
    'cupsoda': LucideIcons.cupSoda,
    'droplets': LucideIcons.droplets,
    'filetext': LucideIcons.fileText,
    'flame': LucideIcons.flame,
    'flower2': LucideIcons.flower2,
    'footprints': LucideIcons.footprints,
    'gift': LucideIcons.gift,
    'globe': LucideIcons.globe,
    'graduationcap': LucideIcons.graduationCap,
    'hammer': LucideIcons.hammer,
    'hand': LucideIcons.hand,
    'handshake': LucideIcons.handshake,
    'hardhat': LucideIcons.hardHat,
    'heart': LucideIcons.heart,
    'hearthandshake': LucideIcons.heartHandshake,
    'houseplug': LucideIcons.housePlug,
    'instagram': _instagram,
    'keyround': LucideIcons.keyRound,
    'landplot': LucideIcons.landPlot,
    'megaphone': LucideIcons.megaphone,
    'monitorsmartphone': LucideIcons.monitorSmartphone,
    'morehorizontal': LucideIcons.moreHorizontal,
    'music': LucideIcons.music,
    'package': LucideIcons.package,
    'paintroller': LucideIcons.paintRoller,
    'palette': LucideIcons.palette,
    'pawprint': LucideIcons.pawPrint,
    'pentool': LucideIcons.penTool,
    'plane': LucideIcons.plane,
    'recycle': LucideIcons.recycle,
    'ruler': LucideIcons.ruler,
    'sandwich': LucideIcons.sandwich,
    'scale': LucideIcons.scale,
    'scissors': LucideIcons.scissors,
    'shirt': LucideIcons.shirt,
    'shoppingcart': LucideIcons.shoppingCart,
    'sparkles': LucideIcons.sparkles,
    'spraycan': LucideIcons.sprayCan,
    'stethoscope': LucideIcons.stethoscope,
    'sun': LucideIcons.sun,
    'tent': LucideIcons.tent,
    'treedeciduous': LucideIcons.treeDeciduous,
    'truck': LucideIcons.truck,
    'users': LucideIcons.users,
    'washingmachine': LucideIcons.washingMachine,
    'wrench': LucideIcons.wrench,
    'zap': LucideIcons.zap,
  };

  /// The website's icon (a key of [_websiteIcons]) for each category slug, as the
  /// database has them. Used where only the slug is known (the offline list,
  /// Search, a business's category); the live `icon_name` wins where it is given.
  static const Map<String, String> _websiteIconOfSlug = {
    'instagram-shops': 'instagram',
    'home_services': 'houseplug',
    'electrician': 'zap',
    'plumber': 'wrench',
    'carpenter': 'hammer',
    'painter': 'paintroller',
    'mason_dasil': 'brickwall',
    'labour': 'hardhat',
    'gardener': 'treedeciduous',
    'tailor': 'scissors',
    'cleaner': 'sparkles',
    'home_tutor': 'graduationcap',
    'professional_instructor': 'users',
    'education_consultant': 'bookopen',
    'pharmacy': 'stethoscope',
    'psychiatrist_therapist': 'brain',
    'physiotherapist': 'activity',
    'laptop_mobile_repair': 'monitorsmartphone',
    'appliance_repair': 'washingmachine',
    'laundry': 'shirt',
    'mechanic': 'wrench',
    'driver': 'carfront',
    'car_rental': 'keyround',
    'car_detailing': 'spraycan',
    'Furniture & Fixture': 'armchair',
    'architect': 'compass',
    'lawyer': 'scale',
    'chartered_accountant': 'calculator',
    'property_dealer': 'landplot',
    'buliders_developers': 'construction',
    'insurance_agent': 'filetext',
    'designer': 'pentool',
    'web_mobile': 'code',
    'kashmiri_art_artisans': 'handshake',
    'copperware': 'anvil',
    'steel_iron_works': 'anvil',
    'Transport_cargo': 'truck',
    'courier_cargo_services': 'package',
    'wedding': 'heart',
    'middleman_manzimyor': 'hearthandshake',
    'photography': 'camera',
    'tent': 'tent',
    'catering': 'chefhat',
    'bakery': 'cake',
    'mehndi_artist': 'hand',
    'makeup_artist': 'palette',
    'custom_gifting': 'gift',
    'tour_travels': 'globe',
    'advertisement_hoardings': 'megaphone',
    'hajj_umrah': 'plane',
    'hijama': 'droplets',
    'flooring_and_furnishing': 'morehorizontal',
    'cctv_security': 'cctv',
    'pet_care': 'pawprint',
    'solar_installer': 'sun',
    'scrap_dealer': 'recycle',
    'sales_marketing': 'briefcasebusiness',
    'musician': 'music',
    'training_fitness': 'activity',
    'agriculture_farming': 'treedeciduous',
    'labs_diagnostics': 'stethoscope',
    'building_material': 'brickwall',
    'car_bike': 'car',
    'mens-clothing': 'shirt',
    'womens-clothing': 'flower2',
    'shoes': 'footprints',
    'kidswear': 'baby',
    'jobseekers': 'briefcasebusiness',
    'clinics': 'stethoscope',
    'heating-hamams': 'flame',
    'interior-designers': 'ruler',
    'food-items': 'sandwich',
    'beverages': 'cupsoda',
    'grocery': 'shoppingcart',
    'other': 'morehorizontal',
  };

  static String _iconKey(String name) => name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// The website's icon for a category: by the `icon_name` the database gives
  /// it, else by its slug. Null for a category the website has no icon for.
  static IconData? websiteIcon(String? slug, [String? iconName]) {
    if (iconName != null && iconName.trim().isNotEmpty) {
      final byName = _websiteIcons[_iconKey(iconName)];
      if (byName != null) return byName;
    }
    final viaSlug = slug == null ? null : _websiteIconOfSlug[slug];
    return viaSlug == null ? null : _websiteIcons[viaSlug];
  }

  static const Map<String, IconData> _namedIcons = {
    'category': Icons.category_rounded,
    'services': Icons.home_repair_service,
    'home': Icons.home_repair_service,
    'electrician': Icons.bolt,
    'bolt': Icons.bolt,
    'plumber': Icons.plumbing,
    'plumbing': Icons.plumbing,
    'carpenter': Icons.handyman,
    'handyman': Icons.handyman,
    'build': Icons.build,
    'painter': Icons.format_paint,
    'paint': Icons.format_paint,
    'mason': Icons.foundation,
    'labour': Icons.engineering,
    'gardener': Icons.park,
    'park': Icons.park,
    'tailor': Icons.content_cut,
    'cleaner': Icons.cleaning_services,
    'cleaning': Icons.cleaning_services,
    'tutor': Icons.school,
    'school': Icons.school,
    'education': Icons.menu_book,
    'doctor': Icons.medical_services,
    'hospital': Icons.local_hospital,
    'medical': Icons.medical_services,
    'health': Icons.monitor_heart,
    'pharmacy': Icons.medical_services,
    'laptop': Icons.devices,
    'mobile': Icons.phone_android,
    'repair': Icons.build,
    'car': Icons.directions_car,
    'driver': Icons.directions_car,
    'food': Icons.restaurant,
    'restaurant': Icons.restaurant,
    'lawyer': Icons.balance,
    'property': Icons.real_estate_agent,
    'camera': Icons.camera_alt,
    'photography': Icons.camera_alt,
    'pet': Icons.pets,
    'pets': Icons.pets,
    'gym': Icons.fitness_center,
    'fitness': Icons.fitness_center,
    'security': Icons.security,
    'cctv': Icons.videocam,
    'solar': Icons.solar_power,
    'event': Icons.celebration,
    'wedding': Icons.favorite,
    'hotel': Icons.hotel,
    'travel': Icons.flight_takeoff,
    'spa': Icons.spa,
    'beauty': Icons.palette,
    'shopping': Icons.shopping_bag,
    'store': Icons.storefront,
    'work': Icons.work,
  };

  static const Map<String, CategoryMeta> _map = {
    'all': CategoryMeta(Icons.grid_view_rounded, Color(0xFF43A857)),
    'home_services': CategoryMeta(Icons.home_repair_service, Color(0xFFC07B3E)),
    'electrician': CategoryMeta(Icons.bolt, Color(0xFFF2B01E)),
    'plumber': CategoryMeta(Icons.plumbing, Color(0xFF29A3E0)),
    'carpenter': CategoryMeta(Icons.handyman, Color(0xFFE0652E)),
    'painter': CategoryMeta(Icons.format_paint, Color(0xFF9B59D0)),
    'mason_dasil': CategoryMeta(Icons.foundation, Color(0xFF5F7D95)),
    'labour': CategoryMeta(Icons.engineering, Color(0xFF5F7D95)),
    'gardener': CategoryMeta(Icons.park, Color(0xFF43A857)),
    'tailor': CategoryMeta(Icons.content_cut, Color(0xFF4A5FC1)),
    'cleaner': CategoryMeta(Icons.cleaning_services, Color(0xFF1BB5C9)),
    'home_tutor': CategoryMeta(Icons.school, Color(0xFF339985)),
    'professional_instructor': CategoryMeta(Icons.badge, Color(0xFFE8508C)),
    'education_consultant': CategoryMeta(Icons.menu_book, Color(0xFF3F8EDB)),
    'pharmacy': CategoryMeta(Icons.medical_services, Color(0xFFD64545)),
    'psychiatrist_therapist': CategoryMeta(Icons.psychology, Color(0xFF9B59D0)),
    'physiotherapist': CategoryMeta(Icons.monitor_heart, Color(0xFF43A857)),
    'laptop_mobile_repair': CategoryMeta(Icons.devices, Color(0xFF5F7D95)),
    'appliance_repair': CategoryMeta(Icons.local_laundry_service, Color(0xFF1BB5C9)),
    'laundry': CategoryMeta(Icons.checkroom, Color(0xFF4A5FC1)),
    'food_beverages': CategoryMeta(Icons.restaurant, Color(0xFFE0652E)),
    'mechanic': CategoryMeta(Icons.car_repair, Color(0xFF29A3E0)),
    'driver': CategoryMeta(Icons.directions_car, Color(0xFF3F8EDB)),
    'car_rental': CategoryMeta(Icons.vpn_key, Color(0xFF6C63D9)),
    'car_detailing': CategoryMeta(Icons.local_car_wash, Color(0xFF1BB5C9)),
    'Furniture & Fixture': CategoryMeta(Icons.chair, Color(0xFFC07B3E)),
    'architect': CategoryMeta(Icons.architecture, Color(0xFF5F7D95)),
    'lawyer': CategoryMeta(Icons.balance, Color(0xFF4A5FC1)),
    'chartered_accountant': CategoryMeta(Icons.calculate, Color(0xFF339985)),
    'property_dealer': CategoryMeta(Icons.real_estate_agent, Color(0xFF43A857)),
    'buliders_developers': CategoryMeta(Icons.construction, Color(0xFFF2B01E)),
    'insurance_agent': CategoryMeta(Icons.shield, Color(0xFFE8508C)),
    'designer': CategoryMeta(Icons.draw, Color(0xFF6C63D9)),
    'web_mobile': CategoryMeta(Icons.code, Color(0xFF3F8EDB)),
    'kashmiri_art_artisans': CategoryMeta(Icons.handshake, Color(0xFF9B59D0)),
    'copperware': CategoryMeta(Icons.kitchen, Color(0xFFD64545)),
    'steel_iron_works': CategoryMeta(Icons.hardware, Color(0xFF5F7D95)),
    'Transport_cargo': CategoryMeta(Icons.local_shipping, Color(0xFFD64545)),
    'courier_cargo_services': CategoryMeta(Icons.inventory_2, Color(0xFFE0652E)),
    'wedding': CategoryMeta(Icons.favorite, Color(0xFFE8508C)),
    'middleman_manzimyor': CategoryMeta(Icons.volunteer_activism, Color(0xFF43A857)),
    'photography': CategoryMeta(Icons.camera_alt, Color(0xFFF08A3C)),
    'tent': CategoryMeta(Icons.festival, Color(0xFF9B59D0)),
    'catering': CategoryMeta(Icons.restaurant_menu, Color(0xFFC07B3E)),
    'bakery': CategoryMeta(Icons.cake, Color(0xFFF2B01E)),
    'mehndi_artist': CategoryMeta(Icons.pan_tool, Color(0xFFD64545)),
    'makeup_artist': CategoryMeta(Icons.palette, Color(0xFFE8508C)),
    'custom_gifting': CategoryMeta(Icons.card_giftcard, Color(0xFF1BB5C9)),
    'tour_travels': CategoryMeta(Icons.public, Color(0xFF3F8EDB)),
    'hijama': CategoryMeta(Icons.water_drop, Color(0xFFD64545)),
    'advertisement_hoardings': CategoryMeta(Icons.campaign, Color(0xFFF08A3C)),
    'hajj_umrah': CategoryMeta(Icons.flight_takeoff, Color(0xFF43A857)),
    'pet_care': CategoryMeta(Icons.pets, Color(0xFFF2B01E)),
    'cctv_security': CategoryMeta(Icons.videocam, Color(0xFF5F7D95)),
    'solar_installer': CategoryMeta(Icons.solar_power, Color(0xFFF2B01E)),
    'scrap_dealer': CategoryMeta(Icons.recycling, Color(0xFF43A857)),
    'sales_marketing': CategoryMeta(Icons.work, Color(0xFF6C63D9)),
    'musician': CategoryMeta(Icons.music_note, Color(0xFF9B59D0)),
    'other': CategoryMeta(Icons.more_horiz, Color(0xFF8A9A98)),
    'instagram-shops': CategoryMeta(_instagram, Color(0xFFE8508C)),
  };

  /// Resolves the icon and color for a category.
  /// The icon is the website's (see [websiteIcon]) whenever it has one. The color
  /// is the category's own if it is a known one; otherwise the backend's color or
  /// a harmonious palette color.
  /// A category the website has no icon for checks the explicit iconName, keyword
  /// matches, or falls back to a common clean category icon.
  static CategoryMeta of(
    String? slug, {
    String? name,
    String? iconName,
    String? colorHex,
  }) {
    final website = websiteIcon(slug, iconName);

    // 1. If slug exists in our predefined map, use its color (and the website's icon)
    if (slug != null && _map.containsKey(slug)) {
      final known = _map[slug]!;
      return website == null ? known : CategoryMeta(website, known.color);
    }

    // 2. Resolve custom/parsed color if provided, or generate dynamically
    final parsedColor = tryParseHex(colorHex);
    final chosenColor = parsedColor ?? dynamicColor(slug ?? name ?? '');

    if (website != null) return CategoryMeta(website, chosenColor);

    // 3. If explicit iconName was passed from backend
    if (iconName != null && iconName.isNotEmpty) {
      final normalized = iconName.toLowerCase().trim();
      if (_namedIcons.containsKey(normalized)) {
        return CategoryMeta(_namedIcons[normalized]!, chosenColor);
      }
    }

    // 4. Keyword heuristic based on slug or category name
    final text = '${slug ?? ''} ${name ?? ''}'.toLowerCase();
    for (final entry in _namedIcons.entries) {
      if (entry.key != 'category' && text.contains(entry.key)) {
        return CategoryMeta(entry.value, chosenColor);
      }
    }

    // 5. Default common category icon with vibrant theme/palette color
    return CategoryMeta(Icons.category_rounded, chosenColor);
  }

  static const List<Map<String, dynamic>> allCategories = [
    {'slug': 'home_services', 'name': 'Home Services'},
    {'slug': 'electrician', 'name': 'Electrician'},
    {'slug': 'plumber', 'name': 'Plumber'},
    {'slug': 'carpenter', 'name': 'Carpenter'},
    {'slug': 'painter', 'name': 'Painter'},
    {'slug': 'mason_dasil', 'name': 'Mason (Dasil)'},
    {'slug': 'labour', 'name': 'Labour / Helper'},
    {'slug': 'gardener', 'name': 'Gardener'},
    {'slug': 'tailor', 'name': 'Tailor'},
    {'slug': 'cleaner', 'name': 'Cleaning'},
    {'slug': 'home_tutor', 'name': 'Tutors'},
    {'slug': 'professional_instructor', 'name': 'Professional Trainers'},
    {'slug': 'education_consultant', 'name': 'Education'},
    {'slug': 'pharmacy', 'name': 'Health & Medicine'},
    {'slug': 'psychiatrist_therapist', 'name': 'Psychiatrist / Therapist'},
    {'slug': 'physiotherapist', 'name': 'Physio'},
    {'slug': 'laptop_mobile_repair', 'name': 'Laptop / Mobile Repair'},
    {'slug': 'appliance_repair', 'name': 'Appliance Repair'},
    {'slug': 'laundry', 'name': 'Laundry'},
    {'slug': 'food_beverages', 'name': 'Food & Beverages'},
    {'slug': 'mechanic', 'name': 'Mechanic'},
    {'slug': 'driver', 'name': 'Driver'},
    {'slug': 'car_rental', 'name': 'Car Rental'},
    {'slug': 'car_detailing', 'name': 'Car Wash / Detailing'},
    {'slug': 'Furniture & Fixture', 'name': 'Furniture'},
    {'slug': 'architect', 'name': 'Architect & Engineers'},
    {'slug': 'lawyer', 'name': 'Lawyer'},
    {'slug': 'chartered_accountant', 'name': 'CA & Accounting'},
    {'slug': 'property_dealer', 'name': 'Property Dealers'},
    {'slug': 'buliders_developers', 'name': 'Builders & Developers'},
    {'slug': 'insurance_agent', 'name': 'Insurance Agents / Broker'},
    {'slug': 'designer', 'name': 'Digital / Online Services'},
    {'slug': 'web_mobile', 'name': 'Web / Mobile Development'},
    {'slug': 'kashmiri_art_artisans', 'name': 'Kashmiri Art & Artisans'},
    {'slug': 'copperware', 'name': 'Copperware'},
    {'slug': 'steel_iron_works', 'name': 'Steel & Iron works'},
    {'slug': 'Transport_cargo', 'name': 'Transport & Cargo'},
    {'slug': 'courier_cargo_services', 'name': 'Movers & Packers'},
    {'slug': 'wedding', 'name': 'Wedding Services'},
    {'slug': 'middleman_manzimyor', 'name': 'MiddleMan (Manzimyor)'},
    {'slug': 'photography', 'name': 'Photography'},
    {'slug': 'tent', 'name': 'Tent & Events'},
    {'slug': 'catering', 'name': 'Catering'},
    {'slug': 'bakery', 'name': 'Bakery'},
    {'slug': 'mehndi_artist', 'name': 'Mehndi'},
    {'slug': 'makeup_artist', 'name': 'Makeup'},
    {'slug': 'custom_gifting', 'name': 'Custom Gifting'},
    {'slug': 'tour_travels', 'name': 'Tour & Travels'},
    {'slug': 'hijama', 'name': 'Hijama'},
    {'slug': 'advertisement_hoardings', 'name': 'Advertising & Hoardings'},
    {'slug': 'hajj_umrah', 'name': 'Hajj & Umrah'},
    {'slug': 'pet_care', 'name': 'Pet Care'},
    {'slug': 'cctv_security', 'name': 'CCTV'},
    {'slug': 'solar_installer', 'name': 'Solar'},
    {'slug': 'scrap_dealer', 'name': 'Scrap Dealers'},
    {'slug': 'sales_marketing', 'name': 'Sales & Marketing'},
    {'slug': 'musician', 'name': 'Music & Arts'},
    {'slug': 'other', 'name': 'Other'},
  ];
}
