import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/widgets/category_meta.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  group('CategoryMeta uses the website\'s icons', () {
    test('the icon_name the database gives wins (Lucide names, any case)', () {
      expect(CategoryMeta.of('electrician', iconName: 'Zap').icon, LucideIcons.zap);
      expect(CategoryMeta.of('new-one', iconName: 'HousePlug').icon, LucideIcons.housePlug);
      expect(CategoryMeta.of('new-one', iconName: 'house-plug').icon, LucideIcons.housePlug);
      expect(CategoryMeta.of('new-one', iconName: 'PAINTROLLER').icon, LucideIcons.paintRoller);
    });

    test('with only the slug, the website\'s icon for that category is used', () {
      expect(CategoryMeta.of('electrician').icon, LucideIcons.zap);
      expect(CategoryMeta.of('plumber').icon, LucideIcons.wrench);
      expect(CategoryMeta.of('mechanic').icon, LucideIcons.wrench);
      expect(CategoryMeta.of('cctv_security').icon, LucideIcons.cctv);
      expect(CategoryMeta.of('heating-hamams').icon, LucideIcons.flame);
      expect(CategoryMeta.of('grocery').icon, LucideIcons.shoppingCart);
      expect(CategoryMeta.of('Furniture & Fixture').icon, LucideIcons.armchair);
    });

    test('a category that was missing an icon now has one', () {
      for (final slug in [
        'flooring_and_furnishing',
        'building_material',
        'interior-designers',
        'clinics',
        'labs_diagnostics',
        'training_fitness',
        'agriculture_farming',
        'car_bike',
        'jobseekers',
        'mens-clothing',
        'womens-clothing',
        'shoes',
        'kidswear',
        'beverages',
        'food-items',
      ]) {
        expect(CategoryMeta.websiteIcon(slug), isNotNull, reason: slug);
        expect(CategoryMeta.of(slug).icon, isNot(Icons.category_rounded), reason: slug);
      }
    });

    test('Instagram Shops has the Instagram logo and its own colour', () {
      final byName = CategoryMeta.of('instagram-shops', name: 'Instagram Shops', iconName: 'Instagram');
      final bySlug = CategoryMeta.of('instagram-shops');
      expect(byName.icon, bySlug.icon);
      expect(byName.icon.fontFamily, 'FontAwesomeBrands');
      expect(byName.icon.fontPackage, 'font_awesome_flutter');
      expect(byName.icon.codePoint, 0xf16d);
      expect(byName.color, const Color(0xFFE8508C));
    });

    test('every database icon name is understood, with no two kinds mixed up', () {
      // The icon_name values of service_categories at the time of writing.
      const names = [
        'Activity', 'Anvil', 'Armchair', 'Baby', 'BookOpen', 'Brain', 'BrickWall',
        'BriefcaseBusiness', 'Cake', 'Calculator', 'Camera', 'Car', 'CarFront', 'Cctv',
        'ChefHat', 'Code', 'Compass', 'Construction', 'CupSoda', 'Droplets', 'FileText',
        'Flame', 'Flower2', 'Footprints', 'Gift', 'Globe', 'GraduationCap', 'Hammer',
        'Hand', 'Handshake', 'HardHat', 'Heart', 'HeartHandshake', 'HousePlug',
        'Instagram', 'KeyRound', 'LandPlot', 'Megaphone', 'MonitorSmartphone',
        'MoreHorizontal', 'Music', 'Package', 'PaintRoller', 'Palette', 'PawPrint',
        'PenTool', 'Plane', 'Recycle', 'Ruler', 'Sandwich', 'Scale', 'Scissors',
        'Shirt', 'ShoppingCart', 'Sparkles', 'SprayCan', 'Stethoscope', 'Sun', 'Tent',
        'TreeDeciduous', 'Truck', 'Users', 'WashingMachine', 'Wrench', 'Zap',
      ];
      for (final n in names) {
        final icon = CategoryMeta.of('x-$n', iconName: n).icon;
        expect(icon, isNot(Icons.category_rounded), reason: n);
        if (n != 'Instagram') {
          expect(icon.fontFamily, 'Lucide', reason: n);
        }
      }
    });

    test('colours do not change for the categories the app already had', () {
      expect(CategoryMeta.of('electrician').color, const Color(0xFFF2B01E));
      expect(CategoryMeta.of('plumber').color, const Color(0xFF29A3E0));
      expect(CategoryMeta.of('other').color, const Color(0xFF8A9A98));
    });

    test('a category the website has no icon for still gets the old fallbacks', () {
      expect(CategoryMeta.websiteIcon('something-new', 'NotAnIcon'), isNull);
      // keyword in the name
      expect(CategoryMeta.of('something-new', name: 'Pet Salon').icon, Icons.pets);
      // nothing matches
      expect(CategoryMeta.of('zzz', name: 'Qqq').icon, Icons.category_rounded);
    });

    test('the offline list has an icon for each category', () {
      for (final c in CategoryMeta.allCategories) {
        final slug = c['slug'] as String;
        expect(CategoryMeta.of(slug, name: c['name'] as String).icon, isNotNull, reason: slug);
      }
    });
  });
}
