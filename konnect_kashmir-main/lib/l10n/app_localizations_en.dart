// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navHome => 'Home';

  @override
  String get navMyBusiness => 'My Business';

  @override
  String get navProfile => 'Profile';

  @override
  String get continueLabel => 'Continue';

  @override
  String get language => 'Language';

  @override
  String get chooseLanguage => 'Choose your language';

  @override
  String get chooseLanguageHint => 'You can change this anytime from Profile.';

  @override
  String get retry => 'Retry';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get signIn => 'Sign in';

  @override
  String get signOut => 'Sign out';

  @override
  String get noInternet => 'No internet connection';

  @override
  String get checkConnection => 'Check your connection and try again.';

  @override
  String get somethingWrong => 'Something went wrong';

  @override
  String get tryAgainMoment => 'Please try again in a moment.';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get fullName => 'Full name';

  @override
  String get enterYourName => 'Enter your name';

  @override
  String phoneLabel(String phone) {
    return 'Phone: $phone';
  }

  @override
  String get saveChanges => 'Save changes';

  @override
  String get validNameError => 'Please enter a valid name';

  @override
  String get profileUpdated => 'Profile updated';

  @override
  String get couldntSave => 'Couldn\'t save. Try again.';

  @override
  String get legal => 'Legal';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get refundPolicy => 'Refund Policy';

  @override
  String get grievanceRedressal => 'Grievance Redressal';

  @override
  String get signOutConfirm => 'Are you sure you want to sign out?';

  @override
  String get yourName => 'Your name';

  @override
  String get adCredits => 'Ad credits';

  @override
  String get transactionHistory => 'Transaction history';

  @override
  String get contactUs => 'Contact us';

  @override
  String get theme => 'Theme';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get sessionExpiredTitle => 'Session expired';

  @override
  String get sessionExpiredMsg =>
      'For your security you need to sign in again to load your leads and credits.';

  @override
  String get noCreditsBanner => 'No credits left. Watch an ad to reveal leads.';

  @override
  String get watchAd => 'Watch ad';

  @override
  String get noBusinessYet => 'You haven\'t listed a business yet';

  @override
  String get listBusinessIntro =>
      'List your services and get discovered by customers across Kashmir.';

  @override
  String get listMyBusiness => 'List my business';

  @override
  String get edit => 'Edit';

  @override
  String get leads => 'Leads';

  @override
  String get noLeadsYet => 'No leads yet';

  @override
  String get noLeadsHint => 'Customers who show interest will appear here.';

  @override
  String get revealCostsCredit => 'Revealing a contact costs 1 credit.';

  @override
  String get call => 'Call';

  @override
  String get chatOnWhatsapp => 'Chat on WhatsApp';

  @override
  String get getLead => 'Get Lead';

  @override
  String get statusActive => 'Active';

  @override
  String get statusPending => 'Pending';

  @override
  String get customer => 'Customer';

  @override
  String get timeJustNow => 'Just now';

  @override
  String minutesAgo(int count) {
    return '$count min ago';
  }

  @override
  String hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get snackRevealedNoBalance =>
      'Contact revealed, but your credit balance could not be updated.';

  @override
  String get snackNotEnoughCredits =>
      'Not enough credits. Watch an ad to earn credits.';

  @override
  String get snackCouldNotReveal => 'Could not reveal contact. Try again.';

  @override
  String get snackNetworkError => 'Network error. Please try again.';

  @override
  String get snackSessionExpiredLeads =>
      'Your session has expired, so leads cannot load. Please sign in again.';

  @override
  String snackCouldntRefreshLeads(String detail) {
    return 'Couldn\'t refresh leads. $detail';
  }

  @override
  String get couldntLoadBusiness => 'Couldn\'t load your business';

  @override
  String get couldntOpenWhatsapp => 'Couldn\'t open WhatsApp';

  @override
  String get salam => 'Salam';

  @override
  String greeting(String name) {
    return 'Salam, $name';
  }

  @override
  String get heroLine1 => 'Trusted local pros,';

  @override
  String get heroLine2 => 'one tap away.';

  @override
  String get searchVendors => 'Search vendors...';

  @override
  String get allDistricts => 'All districts';

  @override
  String get allLocalities => 'All localities';

  @override
  String get selectDistrictFirst => 'Select a district first';

  @override
  String get filterByDistrict => 'Filter by district';

  @override
  String localitiesIn(String district) {
    return 'Localities in $district';
  }

  @override
  String get ourServices => 'Our services';

  @override
  String get showAll => 'Show all';

  @override
  String get showLess => 'Show less';

  @override
  String get showMore => 'Show more';

  @override
  String providerCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString providers',
      one: '1 provider',
    );
    return '$_temp0';
  }

  @override
  String get findingProviders => 'Finding providers…';

  @override
  String get noProvidersFound => 'No providers found';

  @override
  String get noSavedProviders => 'You haven\'t saved any providers here yet.';

  @override
  String get tryDifferentSearch =>
      'Try a different search or change your filters.';

  @override
  String get clearAllFilters => 'Clear all filters';

  @override
  String get homeVisit => 'Home visit';

  @override
  String get onlinePay => 'Online pay';

  @override
  String yrs(String years) {
    return '$years yrs';
  }

  @override
  String get whatsapp => 'WhatsApp';

  @override
  String get unlocked => 'Unlocked';

  @override
  String get contact => 'Contact';

  @override
  String get hide => 'Hide';

  @override
  String get rateReviewReport => 'Rate, review or report';

  @override
  String get signInToUnlock => 'Sign in to unlock';

  @override
  String get unlockOneCredit => 'Unlock · 1 credit';

  @override
  String get unlockContact => 'Unlock Contact';

  @override
  String get watchAdToUnlock => 'Watch ad to unlock';

  @override
  String get filters => 'Filters';

  @override
  String get reset => 'Reset';

  @override
  String get district => 'District';

  @override
  String get locality => 'Locality';

  @override
  String get loading => 'Loading…';

  @override
  String get verifiedProvidersOnly => 'Verified providers only';

  @override
  String get savedProvidersOnly => 'Saved providers only';

  @override
  String get sortBy => 'Sort by';

  @override
  String get sortNewest => 'Newest';

  @override
  String get sortExperienced => 'Most experienced';

  @override
  String get sortPriceLow => 'Price low to high';

  @override
  String get showResults => 'Show results';

  @override
  String get snackNoAds => 'No ads available right now.';

  @override
  String get snackNoCreditsNoAds =>
      'No credits & no ads available. Check back later.';

  @override
  String get snackNotEnoughAfterAd =>
      'Not enough credits after ad. Please try again.';

  @override
  String get snackCouldNotUnlock =>
      'Could not unlock contact. Please try again.';

  @override
  String get contactUnlocked => 'Contact Unlocked!';

  @override
  String get contactDetails => 'Contact Details';

  @override
  String contactInfoFor(String name) {
    return 'Contact information for $name';
  }

  @override
  String get phoneNotAvailable => 'Phone not available';

  @override
  String get callNow => 'Call Now';

  @override
  String get loginTagline => 'Kashmir\'s Local Services & Business Directory';

  @override
  String get signInRegister => 'Sign In / Register';

  @override
  String get enterMobileToStart => 'Enter your mobile number to get started';

  @override
  String get mobileNumber => 'Mobile Number';

  @override
  String get sendVerificationOtp => 'Send Verification OTP';

  @override
  String get safeSecure => 'Safe & secure';

  @override
  String get byContinuing => 'By continuing, you agree to KonnectKashmir\'s';

  @override
  String get andWord => 'and';

  @override
  String get errPhoneRequired => 'Please enter a phone number';

  @override
  String get errPhoneInvalid => 'Enter a valid 10-digit Indian mobile number';

  @override
  String get errAuthFailed => 'Auth failed';

  @override
  String get errSendOtp => 'Failed to send OTP';

  @override
  String get otpEnterComplete => 'Please enter the complete 4-digit OTP';

  @override
  String get otpInvalid => 'Invalid OTP';

  @override
  String get otpExpired => 'This OTP has expired. Please request a new one.';

  @override
  String get otpResendFailed => 'Failed to resend OTP';

  @override
  String get verifyYourPhone => 'Verify your phone number';

  @override
  String get otpVerification => 'OTP Verification';

  @override
  String get otpCodeSentTo => 'Enter the 4-digit code sent to';

  @override
  String get verifyAndProceed => 'Verify & Proceed';

  @override
  String get resendOtp => 'Resend OTP';

  @override
  String resendOtpIn(String seconds) {
    return 'Resend OTP in ${seconds}s';
  }

  @override
  String get otpResent => 'OTP resent successfully';

  @override
  String get editBusinessTitle => 'Edit Business';

  @override
  String get listYourBusiness => 'List Your Business';

  @override
  String get updateBusinessInfo => 'Update your business information';

  @override
  String get getBusinessListed => 'Get your business listed on KonnectKashmir';

  @override
  String get businessDetails => 'Business Details';

  @override
  String get businessName => 'Business Name *';

  @override
  String get businessNameHint => 'e.g., Ahmed\'s Plumbing Service';

  @override
  String get serviceCategoriesLabel => 'Service Categories * (select up to 3)';

  @override
  String get selectUpTo3 => 'Select up to 3 categories';

  @override
  String get searchCategories => 'Search categories...';

  @override
  String categoriesSelected(int count) {
    return '$count/3 categories selected';
  }

  @override
  String get districtLabel => 'District *';

  @override
  String get selectDistrict => 'Select district';

  @override
  String get localityLabel => 'Locality *';

  @override
  String get selectLocality => 'Select locality';

  @override
  String get businessDescriptionOptional => 'Business Description (optional)';

  @override
  String get descriptionHint => 'Tell customers about your services...';

  @override
  String get contactInfo => 'Contact Info';

  @override
  String get businessPhoneLabel => 'Business Phone Number *';

  @override
  String get sameOrDifferent => 'Same or different';

  @override
  String get email => 'Email';

  @override
  String get address => 'Address';

  @override
  String get shopOfficeAddress => 'Shop/Office address';

  @override
  String get homeServiceAvailable => 'Home Service Available';

  @override
  String get acceptOnlinePayment => 'Accept Online Payment';

  @override
  String get listingReviewNote =>
      'Your listing will be reviewed within 24-48 hours';

  @override
  String get submit => 'Submit';

  @override
  String get fieldRequired => 'This field is required';

  @override
  String get pleaseSelectOption => 'Please select an option';

  @override
  String get selectAtLeastOneService => 'Please select at least one service';

  @override
  String get fillRequiredFields => 'Please fill in all required fields';

  @override
  String get networkCheckConnection =>
      'Network error. Please check your connection.';

  @override
  String get successTitle => 'Success';

  @override
  String get errorTitle => 'Error';

  @override
  String get ok => 'OK';

  @override
  String get businessUpdatedMsg =>
      'Your business has been updated successfully!';

  @override
  String get businessSubmittedMsg =>
      'Your business listing has been submitted for review!';

  @override
  String get yourBalance => 'Your balance';

  @override
  String get watchAndEarn => 'Watch & earn';

  @override
  String get noAdsNow => 'No ads available right now';

  @override
  String get noAdsHint => 'Check back later for new ways to earn credits.';

  @override
  String get sponsoredVideo => 'Sponsored video';

  @override
  String get watchBtn => 'Watch';

  @override
  String get txnContactUnlocked => 'Contact unlocked';

  @override
  String get txnVendorRevealed => 'Vendor contact revealed';

  @override
  String get txnWelcomeBonus => 'Welcome bonus';

  @override
  String get txnNewAccountReward => 'New account reward';

  @override
  String get txnReferralBonus => 'Referral bonus';

  @override
  String get txnReferralReward => 'Referral credit reward';

  @override
  String get txnCreditPurchase => 'Credit purchase';

  @override
  String get txnCreditsAdded => 'Credits added';

  @override
  String get txnRefund => 'Refund';

  @override
  String get txnCreditsRefunded => 'Credits refunded';

  @override
  String get txnAdReward => 'Ad reward';

  @override
  String get txnWatchedAd => 'Watched an ad';

  @override
  String get txnCreditsSpent => 'Credits spent';

  @override
  String get txnCreditUsed => 'Credit used';

  @override
  String get noTransactionsYet => 'No transactions yet';

  @override
  String get noTransactionsHint =>
      'Credits you earn or spend will show up here.';

  @override
  String get errNameRequired => 'Please enter your full name';

  @override
  String get errNameShort => 'Name must be at least 2 characters';

  @override
  String get errRequestTimeout => 'Request timed out. Please try again.';

  @override
  String get completeYourProfile => 'Complete Your Profile';

  @override
  String get enterNameToContinue =>
      'Please enter your name to continue using KonnectKashmir';

  @override
  String get yourFullName => 'Your Full Name';

  @override
  String get enterFullName => 'Enter your full name';

  @override
  String get visibleToVendors =>
      'This will be visible to vendors when you contact them';

  @override
  String get backToHome => 'Back to Home';

  @override
  String get ourOffice => 'Our Office';

  @override
  String get callUs => 'Call Us';

  @override
  String get chatWithUsWhatsapp => 'Chat with us on WhatsApp';

  @override
  String get businessHours => 'Business Hours';

  @override
  String get mondaySaturday => 'Monday - Saturday';

  @override
  String get sunday => 'Sunday';

  @override
  String get closed => 'Closed';

  @override
  String get categoryAll => 'All';

  @override
  String get navDeen => 'Deen';

  @override
  String get addCredit => 'Add Credit';

  @override
  String get deenPrayerTimes => 'Prayer Times';

  @override
  String get prayerFajr => 'Fajr';

  @override
  String get prayerDhuhr => 'Dhuhr';

  @override
  String get prayerAsr => 'Asr';

  @override
  String get prayerMaghrib => 'Maghrib';

  @override
  String get prayerIsha => 'Isha';

  @override
  String get deenCurrentLocation => 'Current location';

  @override
  String get deenLocating => 'Finding your location…';

  @override
  String deenNextPrayer(String name, String time) {
    return 'Next: $name in $time';
  }

  @override
  String get deenQibla => 'Qibla';

  @override
  String deenQiblaAngle(String deg) {
    return 'Qibla angle: $deg° from North';
  }

  @override
  String get deenQiblaAligned => 'You are facing the Qibla';

  @override
  String get deenQiblaHint =>
      'Hold your phone flat and turn until the arrow points up';

  @override
  String get deenCompassMissing =>
      'Compass is not available on this device. Use the angle above with a compass.';

  @override
  String get deenLocationOff =>
      'Turn on location to see prayer times and the Qibla direction';

  @override
  String get deenLocationDenied =>
      'Location permission is needed for prayer times and the Qibla direction';

  @override
  String get deenLocationBlocked =>
      'Location is blocked. Allow it from the app settings.';

  @override
  String get deenAllowLocation => 'Allow location';

  @override
  String get deenOpenSettings => 'Open settings';

  @override
  String get deenQuran => 'Quran';

  @override
  String get deenAudio => 'Audio';

  @override
  String get deenDuas => 'Duas';

  @override
  String get deenIslamicAudio => 'Islamic Audio';

  @override
  String get deenContinueReading => 'Continue Reading';

  @override
  String get deenStartReading => 'Start reading the Quran';

  @override
  String deenLastRead(String surah, String verse) {
    return '$surah · Verse $verse';
  }

  @override
  String get deenSearchSurah => 'Search surah';

  @override
  String deenVerses(String count) {
    return '$count verses';
  }

  @override
  String get deenShowEarlier => 'Show earlier verses';

  @override
  String get deenReciter => 'Reciter';

  @override
  String get deenAudioError =>
      'Couldn\'t play this recitation. Check your internet.';

  @override
  String deenDuaSource(String source) {
    return 'Source: $source';
  }

  @override
  String txnReference(String id) {
    return 'Ref #$id';
  }

  @override
  String txnStatusIs(String status) {
    return 'Status: $status';
  }
}
