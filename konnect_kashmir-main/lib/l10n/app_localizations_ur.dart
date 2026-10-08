// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Urdu (`ur`).
class AppLocalizationsUr extends AppLocalizations {
  AppLocalizationsUr([String locale = 'ur']) : super(locale);

  @override
  String get navHome => 'ہوم';

  @override
  String get navMyBusiness => 'میرا کاروبار';

  @override
  String get navProfile => 'پروفائل';

  @override
  String get continueLabel => 'جاری رکھیں';

  @override
  String get language => 'زبان';

  @override
  String get chooseLanguage => 'اپنی زبان منتخب کریں';

  @override
  String get chooseLanguageHint =>
      'آپ اسے کبھی بھی پروفائل سے تبدیل کر سکتے ہیں۔';

  @override
  String get retry => 'دوبارہ کوشش کریں';

  @override
  String get cancel => 'منسوخ کریں';

  @override
  String get confirm => 'تصدیق کریں';

  @override
  String get signIn => 'سائن اِن کریں';

  @override
  String get signOut => 'سائن آؤٹ';

  @override
  String get noInternet => 'انٹرنیٹ کنکشن نہیں ہے';

  @override
  String get checkConnection => 'اپنا کنکشن چیک کریں اور دوبارہ کوشش کریں۔';

  @override
  String get somethingWrong => 'کچھ غلط ہو گیا';

  @override
  String get tryAgainMoment => 'براہِ کرم تھوڑی دیر بعد دوبارہ کوشش کریں۔';

  @override
  String get editProfile => 'پروفائل میں ترمیم کریں';

  @override
  String get fullName => 'پورا نام';

  @override
  String get enterYourName => 'اپنا نام درج کریں';

  @override
  String phoneLabel(String phone) {
    return 'فون: $phone';
  }

  @override
  String get saveChanges => 'تبدیلیاں محفوظ کریں';

  @override
  String get validNameError => 'براہِ کرم درست نام درج کریں';

  @override
  String get profileUpdated => 'پروفائل اپ ڈیٹ ہو گئی';

  @override
  String get couldntSave => 'محفوظ نہیں ہو سکا۔ دوبارہ کوشش کریں۔';

  @override
  String get legal => 'قانونی';

  @override
  String get termsOfService => 'سروس کی شرائط';

  @override
  String get privacyPolicy => 'رازداری کی پالیسی';

  @override
  String get refundPolicy => 'ریفنڈ پالیسی';

  @override
  String get grievanceRedressal => 'شکایات کا ازالہ';

  @override
  String get signOutConfirm => 'کیا آپ واقعی سائن آؤٹ کرنا چاہتے ہیں؟';

  @override
  String get yourName => 'آپ کا نام';

  @override
  String get adCredits => 'اشتہاری کریڈٹس';

  @override
  String get transactionHistory => 'لین دین کی تاریخ';

  @override
  String get contactUs => 'ہم سے رابطہ کریں';

  @override
  String get theme => 'تھیم';

  @override
  String get themeLight => 'لائٹ';

  @override
  String get themeDark => 'ڈارک';

  @override
  String get sessionExpiredTitle => 'سیشن ختم ہو گیا';

  @override
  String get sessionExpiredMsg =>
      'آپ کی حفاظت کے لیے، اپنی لیڈز اور کریڈٹس دیکھنے کے لیے دوبارہ سائن اِن کریں۔';

  @override
  String get noCreditsBanner =>
      'کوئی کریڈٹ باقی نہیں۔ لیڈز دیکھنے کے لیے اشتہار دیکھیں۔';

  @override
  String get watchAd => 'اشتہار دیکھیں';

  @override
  String get noBusinessYet => 'آپ نے ابھی تک کوئی کاروبار درج نہیں کیا';

  @override
  String get listBusinessIntro =>
      'اپنی خدمات درج کریں اور پورے کشمیر کے گاہکوں تک پہنچیں۔';

  @override
  String get listMyBusiness => 'میرا کاروبار درج کریں';

  @override
  String get edit => 'ترمیم';

  @override
  String get leads => 'لیڈز';

  @override
  String get noLeadsYet => 'ابھی کوئی لیڈ نہیں';

  @override
  String get noLeadsHint => 'دلچسپی ظاہر کرنے والے گاہک یہاں نظر آئیں گے۔';

  @override
  String get revealCostsCredit => 'رابطہ دیکھنے پر 1 کریڈٹ لگتا ہے۔';

  @override
  String get call => 'کال';

  @override
  String get chatOnWhatsapp => 'واٹس ایپ پر چیٹ کریں';

  @override
  String get getLead => 'لیڈ حاصل کریں';

  @override
  String get statusActive => 'فعال';

  @override
  String get statusPending => 'زیر التواء';

  @override
  String get customer => 'گاہک';

  @override
  String get timeJustNow => 'ابھی ابھی';

  @override
  String minutesAgo(int count) {
    return '$count منٹ پہلے';
  }

  @override
  String hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count گھنٹے پہلے',
      one: '1 گھنٹہ پہلے',
    );
    return '$_temp0';
  }

  @override
  String daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دن پہلے',
      one: '1 دن پہلے',
    );
    return '$_temp0';
  }

  @override
  String get snackRevealedNoBalance =>
      'رابطہ ظاہر ہو گیا، لیکن آپ کا کریڈٹ بیلنس اپ ڈیٹ نہیں ہو سکا۔';

  @override
  String get snackNotEnoughCredits =>
      'کریڈٹس کم ہیں۔ کریڈٹس کمانے کے لیے اشتہار دیکھیں۔';

  @override
  String get snackCouldNotReveal =>
      'رابطہ ظاہر نہیں کیا جا سکا۔ دوبارہ کوشش کریں۔';

  @override
  String get snackNetworkError =>
      'نیٹ ورک کی خرابی۔ براہِ کرم دوبارہ کوشش کریں۔';

  @override
  String get snackSessionExpiredLeads =>
      'آپ کا سیشن ختم ہو گیا ہے، اس لیے لیڈز لوڈ نہیں ہو سکیں۔ براہِ کرم دوبارہ سائن اِن کریں۔';

  @override
  String snackCouldntRefreshLeads(String detail) {
    return 'لیڈز ریفریش نہیں ہو سکیں۔ $detail';
  }

  @override
  String get couldntLoadBusiness => 'آپ کا کاروبار لوڈ نہیں ہو سکا';

  @override
  String get couldntOpenWhatsapp => 'واٹس ایپ نہیں کھل سکا';

  @override
  String get salam => 'سلام';

  @override
  String greeting(String name) {
    return 'سلام، $name';
  }

  @override
  String get heroLine1 => 'قابلِ اعتماد مقامی ماہرین،';

  @override
  String get heroLine2 => 'بس ایک ٹیپ کی دوری پر۔';

  @override
  String get searchVendors => 'وینڈرز تلاش کریں...';

  @override
  String get allDistricts => 'تمام اضلاع';

  @override
  String get allLocalities => 'تمام علاقے';

  @override
  String get selectDistrictFirst => 'پہلے ضلع منتخب کریں';

  @override
  String get filterByDistrict => 'ضلع کے مطابق فلٹر کریں';

  @override
  String localitiesIn(String district) {
    return '$district کے علاقے';
  }

  @override
  String get ourServices => 'ہماری خدمات';

  @override
  String get showAll => 'سب دکھائیں';

  @override
  String get showLess => 'کم دکھائیں';

  @override
  String get showMore => 'مزید دکھائیں';

  @override
  String providerCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString فراہم کنندگان',
      one: '1 فراہم کنندہ',
    );
    return '$_temp0';
  }

  @override
  String get findingProviders => 'فراہم کنندگان تلاش کیے جا رہے ہیں…';

  @override
  String get noProvidersFound => 'کوئی فراہم کنندہ نہیں ملا';

  @override
  String get noSavedProviders =>
      'آپ نے یہاں ابھی تک کوئی فراہم کنندہ محفوظ نہیں کیا۔';

  @override
  String get tryDifferentSearch => 'کوئی اور تلاش آزمائیں یا فلٹر تبدیل کریں۔';

  @override
  String get clearAllFilters => 'تمام فلٹر ہٹائیں';

  @override
  String get homeVisit => 'گھر پر سروس';

  @override
  String get onlinePay => 'آن لائن ادائیگی';

  @override
  String yrs(String years) {
    return '$years سال';
  }

  @override
  String get whatsapp => 'واٹس ایپ';

  @override
  String get unlocked => 'ان لاک ہو گیا';

  @override
  String get contact => 'رابطہ';

  @override
  String get hide => 'چھپائیں';

  @override
  String get rateReviewReport => 'ریٹنگ، جائزہ یا رپورٹ';

  @override
  String get signInToUnlock => 'ان لاک کے لیے سائن اِن کریں';

  @override
  String get unlockOneCredit => 'ان لاک · 1 کریڈٹ';

  @override
  String get unlockContact => 'رابطہ ان لاک کریں';

  @override
  String get watchAdToUnlock => 'ان لاک کے لیے اشتہار دیکھیں';

  @override
  String get filters => 'فلٹرز';

  @override
  String get reset => 'ری سیٹ';

  @override
  String get district => 'ضلع';

  @override
  String get locality => 'علاقہ';

  @override
  String get loading => 'لوڈ ہو رہا ہے…';

  @override
  String get verifiedProvidersOnly => 'صرف تصدیق شدہ فراہم کنندگان';

  @override
  String get savedProvidersOnly => 'صرف محفوظ کردہ فراہم کنندگان';

  @override
  String get sortBy => 'ترتیب بلحاظ';

  @override
  String get sortNewest => 'سب سے نئے';

  @override
  String get sortExperienced => 'سب سے تجربہ کار';

  @override
  String get sortPriceLow => 'قیمت کم سے زیادہ';

  @override
  String get showResults => 'نتائج دکھائیں';

  @override
  String get snackNoAds => 'اس وقت کوئی اشتہار دستیاب نہیں۔';

  @override
  String get snackNoCreditsNoAds => 'نہ کریڈٹس ہیں نہ اشتہار۔ بعد میں دیکھیں۔';

  @override
  String get snackNotEnoughAfterAd =>
      'اشتہار کے بعد بھی کریڈٹس کم ہیں۔ براہِ کرم دوبارہ کوشش کریں۔';

  @override
  String get snackCouldNotUnlock =>
      'رابطہ ان لاک نہیں ہو سکا۔ براہِ کرم دوبارہ کوشش کریں۔';

  @override
  String get contactUnlocked => 'رابطہ ان لاک ہو گیا!';

  @override
  String get contactDetails => 'رابطے کی تفصیلات';

  @override
  String contactInfoFor(String name) {
    return '$name کی رابطہ معلومات';
  }

  @override
  String get phoneNotAvailable => 'فون دستیاب نہیں';

  @override
  String get callNow => 'ابھی کال کریں';

  @override
  String get loginTagline => 'کشمیر کی مقامی خدمات اور کاروباری ڈائریکٹری';

  @override
  String get signInRegister => 'سائن اِن / رجسٹر';

  @override
  String get enterMobileToStart => 'شروع کرنے کے لیے اپنا موبائل نمبر درج کریں';

  @override
  String get mobileNumber => 'موبائل نمبر';

  @override
  String get sendVerificationOtp => 'تصدیقی OTP بھیجیں';

  @override
  String get safeSecure => 'محفوظ اور سیکیور';

  @override
  String get byContinuing => 'جاری رکھ کر، آپ KonnectKashmir کی';

  @override
  String get andWord => 'اور';

  @override
  String get errPhoneRequired => 'براہِ کرم فون نمبر درج کریں';

  @override
  String get errPhoneInvalid => 'درست 10 ہندسوں کا بھارتی موبائل نمبر درج کریں';

  @override
  String get errAuthFailed => 'تصدیق ناکام';

  @override
  String get errSendOtp => 'OTP بھیجنے میں ناکامی';

  @override
  String get otpEnterComplete => 'براہِ کرم پورا 4 ہندسوں کا OTP درج کریں';

  @override
  String get otpInvalid => 'غلط OTP';

  @override
  String get otpExpired => 'یہ OTP ختم ہو چکا ہے۔ براہِ کرم نیا OTP منگوائیں۔';

  @override
  String get otpResendFailed => 'OTP دوبارہ بھیجنے میں ناکامی';

  @override
  String get verifyYourPhone => 'اپنا فون نمبر تصدیق کریں';

  @override
  String get otpVerification => 'OTP کی تصدیق';

  @override
  String get otpCodeSentTo => 'اس نمبر پر بھیجا گیا 4 ہندسوں کا کوڈ درج کریں';

  @override
  String get verifyAndProceed => 'تصدیق کریں اور آگے بڑھیں';

  @override
  String get resendOtp => 'OTP دوبارہ بھیجیں';

  @override
  String resendOtpIn(String seconds) {
    return '$seconds سیکنڈ میں OTP دوبارہ بھیجیں';
  }

  @override
  String get otpResent => 'OTP کامیابی سے دوبارہ بھیجا گیا';

  @override
  String get editBusinessTitle => 'کاروبار میں ترمیم';

  @override
  String get listYourBusiness => 'اپنا کاروبار درج کریں';

  @override
  String get updateBusinessInfo => 'اپنے کاروبار کی معلومات اپ ڈیٹ کریں';

  @override
  String get getBusinessListed =>
      'اپنے کاروبار کو KonnectKashmir پر درج کروائیں';

  @override
  String get businessDetails => 'کاروبار کی تفصیلات';

  @override
  String get businessName => 'کاروبار کا نام *';

  @override
  String get businessNameHint => 'مثلاً، احمد پلمبنگ سروس';

  @override
  String get serviceCategoriesLabel =>
      'سروس کیٹیگریز * (زیادہ سے زیادہ 3 منتخب کریں)';

  @override
  String get selectUpTo3 => 'زیادہ سے زیادہ 3 کیٹیگریز منتخب کریں';

  @override
  String get searchCategories => 'کیٹیگریز تلاش کریں...';

  @override
  String categoriesSelected(int count) {
    return '$count/3 کیٹیگریز منتخب';
  }

  @override
  String get districtLabel => 'ضلع *';

  @override
  String get selectDistrict => 'ضلع منتخب کریں';

  @override
  String get localityLabel => 'علاقہ *';

  @override
  String get selectLocality => 'علاقہ منتخب کریں';

  @override
  String get businessDescriptionOptional => 'کاروبار کی تفصیل (اختیاری)';

  @override
  String get descriptionHint => 'گاہکوں کو اپنی خدمات کے بارے میں بتائیں...';

  @override
  String get contactInfo => 'رابطہ معلومات';

  @override
  String get businessPhoneLabel => 'کاروباری فون نمبر *';

  @override
  String get sameOrDifferent => 'وہی یا مختلف';

  @override
  String get email => 'ای میل';

  @override
  String get address => 'پتہ';

  @override
  String get shopOfficeAddress => 'دکان/دفتر کا پتہ';

  @override
  String get homeServiceAvailable => 'گھر پر سروس دستیاب';

  @override
  String get acceptOnlinePayment => 'آن لائن ادائیگی قبول کریں';

  @override
  String get listingReviewNote =>
      'آپ کی لسٹنگ کا 24-48 گھنٹوں میں جائزہ لیا جائے گا';

  @override
  String get submit => 'جمع کریں';

  @override
  String get fieldRequired => 'یہ فیلڈ ضروری ہے';

  @override
  String get pleaseSelectOption => 'براہِ کرم ایک آپشن منتخب کریں';

  @override
  String get selectAtLeastOneService =>
      'براہِ کرم کم از کم ایک سروس منتخب کریں';

  @override
  String get fillRequiredFields => 'براہِ کرم تمام ضروری فیلڈز پُر کریں';

  @override
  String get networkCheckConnection =>
      'نیٹ ورک کی خرابی۔ براہِ کرم اپنا کنکشن چیک کریں۔';

  @override
  String get successTitle => 'کامیابی';

  @override
  String get errorTitle => 'خرابی';

  @override
  String get ok => 'ٹھیک ہے';

  @override
  String get businessUpdatedMsg => 'آپ کا کاروبار کامیابی سے اپ ڈیٹ ہو گیا ہے!';

  @override
  String get businessSubmittedMsg =>
      'آپ کی کاروباری لسٹنگ جائزے کے لیے جمع ہو گئی ہے!';

  @override
  String get yourBalance => 'آپ کا بیلنس';

  @override
  String get watchAndEarn => 'دیکھیں اور کمائیں';

  @override
  String get noAdsNow => 'اس وقت کوئی اشتہار دستیاب نہیں';

  @override
  String get noAdsHint => 'کریڈٹس کمانے کے نئے طریقوں کے لیے بعد میں دیکھیں۔';

  @override
  String get sponsoredVideo => 'اسپانسرڈ ویڈیو';

  @override
  String get watchBtn => 'دیکھیں';

  @override
  String get txnContactUnlocked => 'رابطہ ان لاک ہوا';

  @override
  String get txnVendorRevealed => 'وینڈر کا رابطہ ظاہر کیا گیا';

  @override
  String get txnWelcomeBonus => 'ویلکم بونس';

  @override
  String get txnNewAccountReward => 'نئے اکاؤنٹ کا انعام';

  @override
  String get txnReferralBonus => 'ریفرل بونس';

  @override
  String get txnReferralReward => 'ریفرل کریڈٹ انعام';

  @override
  String get txnCreditPurchase => 'کریڈٹ خریداری';

  @override
  String get txnCreditsAdded => 'کریڈٹس شامل ہوئے';

  @override
  String get txnRefund => 'ریفنڈ';

  @override
  String get txnCreditsRefunded => 'کریڈٹس واپس کیے گئے';

  @override
  String get txnAdReward => 'اشتہار کا انعام';

  @override
  String get txnWatchedAd => 'اشتہار دیکھا';

  @override
  String get txnCreditsSpent => 'کریڈٹس خرچ ہوئے';

  @override
  String get txnCreditUsed => 'کریڈٹ استعمال ہوا';

  @override
  String get noTransactionsYet => 'ابھی کوئی لین دین نہیں';

  @override
  String get noTransactionsHint =>
      'آپ کے کمائے یا خرچ کیے گئے کریڈٹس یہاں نظر آئیں گے۔';

  @override
  String get errNameRequired => 'براہِ کرم اپنا پورا نام درج کریں';

  @override
  String get errNameShort => 'نام کم از کم 2 حروف کا ہونا چاہیے';

  @override
  String get errRequestTimeout =>
      'درخواست کا وقت ختم ہو گیا۔ براہِ کرم دوبارہ کوشش کریں۔';

  @override
  String get completeYourProfile => 'اپنی پروفائل مکمل کریں';

  @override
  String get enterNameToContinue =>
      'KonnectKashmir کا استعمال جاری رکھنے کے لیے اپنا نام درج کریں';

  @override
  String get yourFullName => 'آپ کا پورا نام';

  @override
  String get enterFullName => 'اپنا پورا نام درج کریں';

  @override
  String get visibleToVendors =>
      'جب آپ وینڈرز سے رابطہ کریں گے تو یہ انہیں نظر آئے گا';

  @override
  String get backToHome => 'ہوم پر واپس';

  @override
  String get ourOffice => 'ہمارا دفتر';

  @override
  String get callUs => 'ہمیں کال کریں';

  @override
  String get chatWithUsWhatsapp => 'واٹس ایپ پر ہم سے چیٹ کریں';

  @override
  String get businessHours => 'کاروباری اوقات';

  @override
  String get mondaySaturday => 'پیر - ہفتہ';

  @override
  String get sunday => 'اتوار';

  @override
  String get closed => 'بند';

  @override
  String get categoryAll => 'سب';

  @override
  String get navDeen => 'دین';

  @override
  String get addCredit => 'کریڈٹ شامل کریں';

  @override
  String get deenPrayerTimes => 'نماز کے اوقات';

  @override
  String get prayerFajr => 'فجر';

  @override
  String get prayerDhuhr => 'ظہر';

  @override
  String get prayerAsr => 'عصر';

  @override
  String get prayerMaghrib => 'مغرب';

  @override
  String get prayerIsha => 'عشاء';

  @override
  String get deenCurrentLocation => 'موجودہ مقام';

  @override
  String get deenLocating => 'آپ کا مقام تلاش کیا جا رہا ہے…';

  @override
  String deenNextPrayer(String name, String time) {
    return 'اگلی: $name، $time میں';
  }

  @override
  String get deenQibla => 'قبلہ';

  @override
  String deenQiblaAngle(String deg) {
    return 'قبلہ زاویہ: شمال سے $deg°';
  }

  @override
  String get deenQiblaAligned => 'آپ کا رخ قبلے کی طرف ہے';

  @override
  String get deenQiblaHint =>
      'فون کو سیدھا پکڑیں اور تیر کے قبلے کی طرف آنے تک گھمائیں۔';

  @override
  String get deenCompassMissing =>
      'اس فون میں کمپاس دستیاب نہیں۔ اوپر دیا گیا زاویہ کمپاس کے ساتھ استعمال کریں۔';

  @override
  String get deenLocationOff =>
      'نماز کے اوقات اور قبلے کی سمت دیکھنے کے لیے لوکیشن آن کریں';

  @override
  String get deenLocationDenied =>
      'نماز کے اوقات اور قبلے کی سمت کے لیے لوکیشن کی اجازت درکار ہے';

  @override
  String get deenLocationBlocked =>
      'لوکیشن بند ہے۔ ایپ کی سیٹنگز سے اجازت دیں۔';

  @override
  String get deenAllowLocation => 'لوکیشن کی اجازت دیں';

  @override
  String get deenOpenSettings => 'سیٹنگز کھولیں';

  @override
  String get deenQuran => 'قرآن';

  @override
  String get deenAudio => 'آڈیو';

  @override
  String get deenDuas => 'دعائیں';

  @override
  String get deenIslamicAudio => 'اسلامی آڈیو';

  @override
  String get deenContinueReading => 'پڑھنا جاری رکھیں';

  @override
  String get deenStartReading => 'قرآن پڑھنا شروع کریں';

  @override
  String deenLastRead(String surah, String verse) {
    return '$surah · آیت $verse';
  }

  @override
  String get deenSearchSurah => 'سورہ تلاش کریں';

  @override
  String deenVerses(String count) {
    return '$count آیات';
  }

  @override
  String get deenShowEarlier => 'پچھلی آیات دکھائیں';

  @override
  String get deenReciter => 'قاری';

  @override
  String get deenAudioError => 'یہ تلاوت نہیں چل سکی۔ انٹرنیٹ چیک کریں۔';

  @override
  String deenDuaSource(String source) {
    return 'ماخذ: $source';
  }

  @override
  String txnReference(String id) {
    return 'حوالہ #$id';
  }

  @override
  String txnStatusIs(String status) {
    return 'حالت: $status';
  }

  @override
  String get prayerSettings => 'نماز کی ترتیبات';

  @override
  String get madhhabAsr => 'مسلک / عصر کا حساب';

  @override
  String get madhhabHanafi => 'حنفی';

  @override
  String get madhhabShafi => 'شافعی';

  @override
  String get madhhabMaliki => 'مالکی';

  @override
  String get madhhabHanbali => 'حنبلی';

  @override
  String get madhhabJafari => 'جعفری';

  @override
  String get calcMethod => 'حساب کا طریقہ';

  @override
  String get prayerSettingsInfo =>
      'مسلک عصر کا وقت طے کرتا ہے۔ حساب کا طریقہ فلکیاتی حساب (فجر، عشاء وغیرہ) طے کرتا ہے۔';

  @override
  String get prayerSettingsJafariNote =>
      'جعفری کے لیے جعفری طریقۂ حساب استعمال ہوتا ہے۔';

  @override
  String get doneLabel => 'ہو گیا';

  @override
  String get deenGreeting => 'السلام علیکم';

  @override
  String get deenQiblaTurnTo => 'قبلے کی طرف مڑیں';

  @override
  String deenVerseN(String verse) {
    return 'آیت $verse';
  }

  @override
  String get deenContinue => 'جاری رکھیں';
}
