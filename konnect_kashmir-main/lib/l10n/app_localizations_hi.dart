// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get navHome => 'होम';

  @override
  String get navMyBusiness => 'मेरा व्यवसाय';

  @override
  String get navProfile => 'प्रोफ़ाइल';

  @override
  String get continueLabel => 'जारी रखें';

  @override
  String get language => 'भाषा';

  @override
  String get chooseLanguage => 'अपनी भाषा चुनें';

  @override
  String get chooseLanguageHint => 'आप इसे कभी भी प्रोफ़ाइल से बदल सकते हैं।';

  @override
  String get retry => 'दोबारा कोशिश करें';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get confirm => 'पुष्टि करें';

  @override
  String get signIn => 'साइन इन करें';

  @override
  String get signOut => 'साइन आउट';

  @override
  String get noInternet => 'इंटरनेट कनेक्शन नहीं है';

  @override
  String get checkConnection => 'अपना कनेक्शन जाँचें और फिर कोशिश करें।';

  @override
  String get somethingWrong => 'कुछ गड़बड़ हो गई';

  @override
  String get tryAgainMoment => 'कृपया थोड़ी देर बाद फिर कोशिश करें।';

  @override
  String get editProfile => 'प्रोफ़ाइल संपादित करें';

  @override
  String get fullName => 'पूरा नाम';

  @override
  String get enterYourName => 'अपना नाम दर्ज करें';

  @override
  String phoneLabel(String phone) {
    return 'फ़ोन: $phone';
  }

  @override
  String get saveChanges => 'बदलाव सहेजें';

  @override
  String get validNameError => 'कृपया सही नाम दर्ज करें';

  @override
  String get profileUpdated => 'प्रोफ़ाइल अपडेट हो गई';

  @override
  String get couldntSave => 'सहेजा नहीं जा सका। फिर कोशिश करें।';

  @override
  String get legal => 'कानूनी';

  @override
  String get termsOfService => 'सेवा की शर्तें';

  @override
  String get privacyPolicy => 'गोपनीयता नीति';

  @override
  String get refundPolicy => 'रिफ़ंड नीति';

  @override
  String get grievanceRedressal => 'शिकायत निवारण';

  @override
  String get signOutConfirm => 'क्या आप सच में साइन आउट करना चाहते हैं?';

  @override
  String get yourName => 'आपका नाम';

  @override
  String get adCredits => 'विज्ञापन क्रेडिट';

  @override
  String get transactionHistory => 'लेन-देन का इतिहास';

  @override
  String get contactUs => 'हमसे संपर्क करें';

  @override
  String get theme => 'थीम';

  @override
  String get themeLight => 'लाइट';

  @override
  String get themeDark => 'डार्क';

  @override
  String get sessionExpiredTitle => 'सत्र समाप्त हो गया';

  @override
  String get sessionExpiredMsg =>
      'आपकी सुरक्षा के लिए, अपनी लीड और क्रेडिट देखने के लिए फिर से साइन इन करें।';

  @override
  String get noCreditsBanner =>
      'कोई क्रेडिट नहीं बचा। लीड देखने के लिए विज्ञापन देखें।';

  @override
  String get watchAd => 'विज्ञापन देखें';

  @override
  String get noBusinessYet => 'आपने अभी तक कोई व्यवसाय नहीं जोड़ा है';

  @override
  String get listBusinessIntro =>
      'अपनी सेवाएँ जोड़ें और पूरे कश्मीर के ग्राहकों तक पहुँचें।';

  @override
  String get listMyBusiness => 'मेरा व्यवसाय जोड़ें';

  @override
  String get edit => 'संपादित करें';

  @override
  String get leads => 'लीड';

  @override
  String get noLeadsYet => 'अभी कोई लीड नहीं';

  @override
  String get noLeadsHint => 'रुचि दिखाने वाले ग्राहक यहाँ दिखेंगे।';

  @override
  String get revealCostsCredit => 'संपर्क देखने पर 1 क्रेडिट लगता है।';

  @override
  String get call => 'कॉल';

  @override
  String get chatOnWhatsapp => 'व्हाट्सऐप पर चैट करें';

  @override
  String get getLead => 'लीड पाएँ';

  @override
  String get statusActive => 'सक्रिय';

  @override
  String get statusPending => 'लंबित';

  @override
  String get customer => 'ग्राहक';

  @override
  String get timeJustNow => 'अभी अभी';

  @override
  String minutesAgo(int count) {
    return '$count मिनट पहले';
  }

  @override
  String hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count घंटे पहले',
      one: '1 घंटा पहले',
    );
    return '$_temp0';
  }

  @override
  String daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count दिन पहले',
      one: '1 दिन पहले',
    );
    return '$_temp0';
  }

  @override
  String get snackRevealedNoBalance =>
      'संपर्क दिख गया, लेकिन आपका क्रेडिट बैलेंस अपडेट नहीं हो सका।';

  @override
  String get snackNotEnoughCredits =>
      'क्रेडिट कम हैं। क्रेडिट कमाने के लिए विज्ञापन देखें।';

  @override
  String get snackCouldNotReveal =>
      'संपर्क नहीं दिखाया जा सका। फिर कोशिश करें।';

  @override
  String get snackNetworkError => 'नेटवर्क त्रुटि। कृपया फिर कोशिश करें।';

  @override
  String get snackSessionExpiredLeads =>
      'आपका सत्र समाप्त हो गया है, इसलिए लीड लोड नहीं हो सकीं। कृपया फिर साइन इन करें।';

  @override
  String snackCouldntRefreshLeads(String detail) {
    return 'लीड रिफ़्रेश नहीं हो सकीं। $detail';
  }

  @override
  String get couldntLoadBusiness => 'आपका व्यवसाय लोड नहीं हो सका';

  @override
  String get couldntOpenWhatsapp => 'व्हाट्सऐप नहीं खुल सका';

  @override
  String get salam => 'सलाम';

  @override
  String greeting(String name) {
    return 'सलाम, $name';
  }

  @override
  String get heroLine1 => 'भरोसेमंद स्थानीय विशेषज्ञ,';

  @override
  String get heroLine2 => 'बस एक टैप दूर।';

  @override
  String get searchVendors => 'विक्रेता खोजें...';

  @override
  String get allDistricts => 'सभी ज़िले';

  @override
  String get allLocalities => 'सभी इलाके';

  @override
  String get selectDistrictFirst => 'पहले ज़िला चुनें';

  @override
  String get filterByDistrict => 'ज़िले के अनुसार फ़िल्टर करें';

  @override
  String localitiesIn(String district) {
    return '$district के इलाके';
  }

  @override
  String get ourServices => 'हमारी सेवाएँ';

  @override
  String get showAll => 'सभी दिखाएँ';

  @override
  String get showLess => 'कम दिखाएँ';

  @override
  String get showMore => 'और दिखाएँ';

  @override
  String providerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count प्रदाता',
      one: '1 प्रदाता',
    );
    return '$_temp0';
  }

  @override
  String get findingProviders => 'प्रदाता खोज रहे हैं…';

  @override
  String get noProvidersFound => 'कोई प्रदाता नहीं मिला';

  @override
  String get noSavedProviders => 'आपने यहाँ अभी तक कोई प्रदाता सहेजा नहीं है।';

  @override
  String get tryDifferentSearch => 'कोई और खोज आज़माएँ या फ़िल्टर बदलें।';

  @override
  String get clearAllFilters => 'सभी फ़िल्टर हटाएँ';

  @override
  String get homeVisit => 'घर पर सेवा';

  @override
  String get onlinePay => 'ऑनलाइन भुगतान';

  @override
  String yrs(String years) {
    return '$years वर्ष';
  }

  @override
  String get whatsapp => 'व्हाट्सऐप';

  @override
  String get unlocked => 'अनलॉक हो गया';

  @override
  String get contact => 'संपर्क';

  @override
  String get hide => 'छिपाएँ';

  @override
  String get rateReviewReport => 'रेटिंग, समीक्षा या रिपोर्ट';

  @override
  String get signInToUnlock => 'अनलॉक के लिए साइन इन करें';

  @override
  String get unlockOneCredit => 'अनलॉक · 1 क्रेडिट';

  @override
  String get watchAdToUnlock => 'अनलॉक के लिए विज्ञापन देखें';

  @override
  String get filters => 'फ़िल्टर';

  @override
  String get reset => 'रीसेट';

  @override
  String get district => 'ज़िला';

  @override
  String get locality => 'इलाका';

  @override
  String get loading => 'लोड हो रहा है…';

  @override
  String get verifiedProvidersOnly => 'केवल सत्यापित प्रदाता';

  @override
  String get savedProvidersOnly => 'केवल सहेजे हुए प्रदाता';

  @override
  String get sortBy => 'इसके अनुसार क्रमबद्ध करें';

  @override
  String get sortNewest => 'सबसे नए';

  @override
  String get sortExperienced => 'सबसे अनुभवी';

  @override
  String get sortPriceLow => 'कीमत कम से ज़्यादा';

  @override
  String get showResults => 'नतीजे दिखाएँ';

  @override
  String get snackNoAds => 'अभी कोई विज्ञापन उपलब्ध नहीं है।';

  @override
  String get snackNoCreditsNoAds => 'न क्रेडिट हैं, न विज्ञापन। बाद में देखें।';

  @override
  String get snackNotEnoughAfterAd =>
      'विज्ञापन के बाद भी क्रेडिट कम हैं। कृपया फिर कोशिश करें।';

  @override
  String get snackCouldNotUnlock =>
      'संपर्क अनलॉक नहीं हो सका। कृपया फिर कोशिश करें।';

  @override
  String get contactUnlocked => 'संपर्क अनलॉक हो गया!';

  @override
  String get contactDetails => 'संपर्क विवरण';

  @override
  String contactInfoFor(String name) {
    return '$name की संपर्क जानकारी';
  }

  @override
  String get phoneNotAvailable => 'फ़ोन उपलब्ध नहीं है';

  @override
  String get callNow => 'अभी कॉल करें';

  @override
  String get loginTagline => 'कश्मीर की स्थानीय सेवाएँ और व्यवसाय निर्देशिका';

  @override
  String get signInRegister => 'साइन इन / रजिस्टर';

  @override
  String get enterMobileToStart =>
      'शुरू करने के लिए अपना मोबाइल नंबर दर्ज करें';

  @override
  String get mobileNumber => 'मोबाइल नंबर';

  @override
  String get sendVerificationOtp => 'सत्यापन OTP भेजें';

  @override
  String get safeSecure => 'सुरक्षित और संरक्षित';

  @override
  String get byContinuing => 'जारी रखकर, आप KonnectKashmir की';

  @override
  String get andWord => 'और';

  @override
  String get errPhoneRequired => 'कृपया फ़ोन नंबर दर्ज करें';

  @override
  String get errPhoneInvalid => 'सही 10 अंकों का भारतीय मोबाइल नंबर दर्ज करें';

  @override
  String get errAuthFailed => 'प्रमाणीकरण विफल';

  @override
  String get errSendOtp => 'OTP भेजने में विफल';

  @override
  String get otpEnterComplete => 'कृपया पूरा 6 अंकों का OTP दर्ज करें';

  @override
  String get otpInvalid => 'अमान्य OTP';

  @override
  String get otpResendFailed => 'OTP दोबारा भेजने में विफल';

  @override
  String get verifyYourPhone => 'अपना फ़ोन नंबर सत्यापित करें';

  @override
  String get otpVerification => 'OTP सत्यापन';

  @override
  String get otpCodeSentTo => 'इस नंबर पर भेजा गया 6 अंकों का कोड दर्ज करें';

  @override
  String get verifyAndProceed => 'सत्यापित करें और आगे बढ़ें';

  @override
  String get resendOtp => 'OTP दोबारा भेजें';

  @override
  String resendOtpIn(String seconds) {
    return '$seconds सेकंड में OTP दोबारा भेजें';
  }

  @override
  String get otpResent => 'OTP सफलतापूर्वक दोबारा भेजा गया';

  @override
  String get editBusinessTitle => 'व्यवसाय संपादित करें';

  @override
  String get listYourBusiness => 'अपना व्यवसाय जोड़ें';

  @override
  String get updateBusinessInfo => 'अपने व्यवसाय की जानकारी अपडेट करें';

  @override
  String get getBusinessListed => 'अपने व्यवसाय को KonnectKashmir पर जोड़ें';

  @override
  String get businessDetails => 'व्यवसाय का विवरण';

  @override
  String get businessName => 'व्यवसाय का नाम *';

  @override
  String get businessNameHint => 'जैसे, अहमद प्लंबिंग सर्विस';

  @override
  String get serviceCategoriesLabel => 'सेवा श्रेणियाँ * (अधिकतम 3 चुनें)';

  @override
  String get selectUpTo3 => 'अधिकतम 3 श्रेणियाँ चुनें';

  @override
  String get searchCategories => 'श्रेणियाँ खोजें...';

  @override
  String categoriesSelected(int count) {
    return '$count/3 श्रेणियाँ चुनी गईं';
  }

  @override
  String get districtLabel => 'ज़िला *';

  @override
  String get selectDistrict => 'ज़िला चुनें';

  @override
  String get localityLabel => 'इलाका *';

  @override
  String get selectLocality => 'इलाका चुनें';

  @override
  String get businessDescriptionOptional => 'व्यवसाय का विवरण (वैकल्पिक)';

  @override
  String get descriptionHint => 'ग्राहकों को अपनी सेवाओं के बारे में बताएँ...';

  @override
  String get contactInfo => 'संपर्क जानकारी';

  @override
  String get businessPhoneLabel => 'व्यवसाय का फ़ोन नंबर *';

  @override
  String get sameOrDifferent => 'वही या अलग';

  @override
  String get email => 'ईमेल';

  @override
  String get address => 'पता';

  @override
  String get shopOfficeAddress => 'दुकान/कार्यालय का पता';

  @override
  String get homeServiceAvailable => 'घर पर सेवा उपलब्ध';

  @override
  String get acceptOnlinePayment => 'ऑनलाइन भुगतान स्वीकार करें';

  @override
  String get listingReviewNote =>
      'आपकी लिस्टिंग की 24-48 घंटों में समीक्षा की जाएगी';

  @override
  String get submit => 'जमा करें';

  @override
  String get fieldRequired => 'यह फ़ील्ड आवश्यक है';

  @override
  String get pleaseSelectOption => 'कृपया एक विकल्प चुनें';

  @override
  String get selectAtLeastOneService => 'कृपया कम से कम एक सेवा चुनें';

  @override
  String get fillRequiredFields => 'कृपया सभी ज़रूरी फ़ील्ड भरें';

  @override
  String get networkCheckConnection =>
      'नेटवर्क त्रुटि। कृपया अपना कनेक्शन जाँचें।';

  @override
  String get successTitle => 'सफल';

  @override
  String get errorTitle => 'त्रुटि';

  @override
  String get ok => 'ठीक है';

  @override
  String get businessUpdatedMsg => 'आपका व्यवसाय सफलतापूर्वक अपडेट हो गया है!';

  @override
  String get businessSubmittedMsg =>
      'आपकी व्यवसाय लिस्टिंग समीक्षा के लिए जमा हो गई है!';

  @override
  String get yourBalance => 'आपका बैलेंस';

  @override
  String get watchAndEarn => 'देखें और कमाएँ';

  @override
  String get noAdsNow => 'अभी कोई विज्ञापन उपलब्ध नहीं';

  @override
  String get noAdsHint => 'क्रेडिट कमाने के नए तरीकों के लिए बाद में देखें।';

  @override
  String get sponsoredVideo => 'प्रायोजित वीडियो';

  @override
  String get watchBtn => 'देखें';

  @override
  String get txnContactUnlocked => 'संपर्क अनलॉक हुआ';

  @override
  String get txnVendorRevealed => 'विक्रेता का संपर्क दिखाया गया';

  @override
  String get txnWelcomeBonus => 'स्वागत बोनस';

  @override
  String get txnNewAccountReward => 'नए खाते का इनाम';

  @override
  String get txnReferralBonus => 'रेफ़रल बोनस';

  @override
  String get txnReferralReward => 'रेफ़रल क्रेडिट इनाम';

  @override
  String get txnCreditPurchase => 'क्रेडिट खरीद';

  @override
  String get txnCreditsAdded => 'क्रेडिट जुड़े';

  @override
  String get txnRefund => 'रिफ़ंड';

  @override
  String get txnCreditsRefunded => 'क्रेडिट वापस किए गए';

  @override
  String get txnAdReward => 'विज्ञापन इनाम';

  @override
  String get txnWatchedAd => 'विज्ञापन देखा';

  @override
  String get txnCreditsSpent => 'क्रेडिट खर्च हुए';

  @override
  String get txnCreditUsed => 'क्रेडिट इस्तेमाल हुआ';

  @override
  String get noTransactionsYet => 'अभी कोई लेन-देन नहीं';

  @override
  String get noTransactionsHint =>
      'आपके कमाए या खर्च किए क्रेडिट यहाँ दिखेंगे।';

  @override
  String get errNameRequired => 'कृपया अपना पूरा नाम दर्ज करें';

  @override
  String get errNameShort => 'नाम कम से कम 2 अक्षरों का होना चाहिए';

  @override
  String get errRequestTimeout =>
      'अनुरोध का समय समाप्त हो गया। कृपया फिर कोशिश करें।';

  @override
  String get completeYourProfile => 'अपनी प्रोफ़ाइल पूरी करें';

  @override
  String get enterNameToContinue =>
      'KonnectKashmir का उपयोग जारी रखने के लिए अपना नाम दर्ज करें';

  @override
  String get yourFullName => 'आपका पूरा नाम';

  @override
  String get enterFullName => 'अपना पूरा नाम दर्ज करें';

  @override
  String get visibleToVendors =>
      'जब आप विक्रेताओं से संपर्क करेंगे तब यह उन्हें दिखेगा';

  @override
  String get backToHome => 'होम पर वापस';

  @override
  String get ourOffice => 'हमारा कार्यालय';

  @override
  String get callUs => 'हमें कॉल करें';

  @override
  String get chatWithUsWhatsapp => 'व्हाट्सऐप पर हमसे चैट करें';

  @override
  String get businessHours => 'कार्य समय';

  @override
  String get mondaySaturday => 'सोमवार - शनिवार';

  @override
  String get sunday => 'रविवार';

  @override
  String get closed => 'बंद';

  @override
  String get categoryAll => 'सभी';
}
