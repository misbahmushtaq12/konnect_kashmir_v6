import 'package:flutter/widgets.dart';

/// Hindi / Urdu names for the service categories, keyed by slug: [hindi, urdu].
/// English comes from the category data itself, so unknown slugs fall back to it.
const Map<String, List<String>> _categoryNames = {
  'home_services': ['घरेलू सेवाएँ', 'گھریلو خدمات'],
  'electrician': ['इलेक्ट्रीशियन', 'الیکٹریشن'],
  'plumber': ['प्लंबर', 'پلمبر'],
  'carpenter': ['बढ़ई', 'بڑھئی'],
  'painter': ['पेंटर', 'پینٹر'],
  'mason_dasil': ['राजमिस्त्री (दासिल)', 'معمار (دسِل)'],
  'labour': ['मज़दूर / हेल्पर', 'مزدور / ہیلپر'],
  'gardener': ['माली', 'مالی'],
  'tailor': ['दर्ज़ी', 'درزی'],
  'cleaner': ['सफ़ाई', 'صفائی'],
  'home_tutor': ['ट्यूटर', 'ٹیوٹرز'],
  'professional_instructor': ['पेशेवर प्रशिक्षक', 'پیشہ ور انسٹرکٹرز'],
  'education_consultant': ['शिक्षा', 'تعلیم'],
  'pharmacy': ['स्वास्थ्य और दवाइयाँ', 'صحت اور ادویات'],
  'psychiatrist_therapist': ['मनोचिकित्सक / थेरेपिस्ट', 'ماہرِ نفسیات / تھراپسٹ'],
  'physiotherapist': ['फ़िज़ियो', 'فزیو'],
  'laptop_mobile_repair': ['लैपटॉप / मोबाइल मरम्मत', 'لیپ ٹاپ / موبائل مرمت'],
  'appliance_repair': ['उपकरण मरम्मत', 'آلات کی مرمت'],
  'laundry': ['लॉन्ड्री', 'لانڈری'],
  'food_beverages': ['खान-पान', 'کھانا پینا'],
  'mechanic': ['मैकेनिक', 'مکینک'],
  'driver': ['ड्राइवर', 'ڈرائیور'],
  'car_rental': ['कार किराया', 'کار کرایہ'],
  'car_detailing': ['कार वॉश / डिटेलिंग', 'کار واش / ڈیٹیلنگ'],
  'Furniture & Fixture': ['फ़र्नीचर', 'فرنیچر'],
  'architect': ['आर्किटेक्ट और इंजीनियर', 'آرکیٹیکٹ اور انجینئرز'],
  'lawyer': ['वकील', 'وکیل'],
  'chartered_accountant': ['सीए और अकाउंटिंग', 'سی اے اور اکاؤنٹنگ'],
  'property_dealer': ['प्रॉपर्टी डीलर', 'پراپرٹی ڈیلرز'],
  'buliders_developers': ['बिल्डर और डेवलपर', 'بلڈرز اور ڈویلپرز'],
  'insurance_agent': ['बीमा एजेंट / ब्रोकर', 'انشورنس ایجنٹ / بروکر'],
  'designer': ['डिजिटल / ऑनलाइन सेवाएँ', 'ڈیجیٹل / آن لائن خدمات'],
  'web_mobile': ['वेब / मोबाइल डेवलपमेंट', 'ویب / موبائل ڈویلپمنٹ'],
  'kashmiri_art_artisans': ['कश्मीरी कला और कारीगर', 'کشمیری فن اور کاریگر'],
  'copperware': ['तांबे के बर्तन', 'تانبے کے برتن'],
  'steel_iron_works': ['स्टील और लोहे का काम', 'اسٹیل اور لوہے کا کام'],
  'Transport_cargo': ['परिवहन और कार्गो', 'ٹرانسپورٹ اور کارگو'],
  'courier_cargo_services': ['मूवर्स और पैकर्स', 'موورز اور پیکرز'],
  'wedding': ['शादी की सेवाएँ', 'شادی کی خدمات'],
  'middleman_manzimyor': ['बिचौलिया (मंज़िमयोर)', 'ثالث (منزِمیور)'],
  'photography': ['फ़ोटोग्राफ़ी', 'فوٹوگرافی'],
  'tent': ['टेंट और इवेंट', 'ٹینٹ اور ایونٹس'],
  'catering': ['कैटरिंग', 'کیٹرنگ'],
  'bakery': ['बेकरी', 'بیکری'],
  'mehndi_artist': ['मेहंदी', 'مہندی'],
  'makeup_artist': ['मेकअप', 'میک اپ'],
  'custom_gifting': ['कस्टम गिफ़्टिंग', 'کسٹم گفٹنگ'],
  'tour_travels': ['टूर और ट्रैवल्स', 'ٹور اینڈ ٹریولز'],
  'hijama': ['हिजामा', 'حجامہ'],
  'advertisement_hoardings': ['विज्ञापन और होर्डिंग', 'اشتہارات اور ہورڈنگز'],
  'hajj_umrah': ['हज और उमरा', 'حج اور عمرہ'],
  'pet_care': ['पालतू जानवरों की देखभाल', 'پالتو جانوروں کی دیکھ بھال'],
  'cctv_security': ['सीसीटीवी', 'سی سی ٹی وی'],
  'solar_installer': ['सोलर', 'سولر'],
  'scrap_dealer': ['कबाड़ी', 'کباڑی'],
  'sales_marketing': ['सेल्स और मार्केटिंग', 'سیلز اور مارکیٹنگ'],
  'musician': ['संगीत और कला', 'موسیقی اور فنون'],
  'other': ['अन्य', 'دیگر'],
};

/// Category name in the current app language (English = the data's own name).
String categoryName(BuildContext context, String? slug, String fallback) {
  final code = Localizations.localeOf(context).languageCode;
  if (code == 'en') return fallback;
  final names = _categoryNames[slug];
  if (names == null) return fallback;
  return code == 'hi' ? names[0] : names[1];
}
