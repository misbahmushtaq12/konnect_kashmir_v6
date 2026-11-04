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
  String get legal => 'Terms & Policies';

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
  String get salam => 'Aadab';

  @override
  String greeting(String name) {
    return 'Aadab, $name';
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
  String deenQiblaFromNorth(String deg) {
    return 'Qibla: $deg° from North';
  }

  @override
  String get audioNowPlaying => 'Now playing';

  @override
  String get audioQueue => 'Queue';

  @override
  String get audioRead => 'Read';

  @override
  String get audioShuffle => 'Shuffle';

  @override
  String get audioRepeat => 'Repeat this surah';

  @override
  String get audioPrevious => 'Previous';

  @override
  String get audioNext => 'Next';

  @override
  String get audioPlay => 'Play';

  @override
  String get audioPause => 'Pause';

  @override
  String get deenQiblaAligned => 'You are facing the Qibla';

  @override
  String get deenQiblaHint =>
      'Hold your phone flat and turn until the arrow points toward Qibla.';

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

  @override
  String get prayerSettings => 'Prayer Settings';

  @override
  String get madhhabAsr => 'Madhhab / Asr Calculation';

  @override
  String get madhhabHanafi => 'Hanafi';

  @override
  String get madhhabShafi => 'Shafi';

  @override
  String get madhhabMaliki => 'Maliki';

  @override
  String get madhhabHanbali => 'Hanbali';

  @override
  String get madhhabJafari => 'Ja\'fari';

  @override
  String get calcMethod => 'Calculation Method';

  @override
  String get prayerSettingsInfo =>
      'Madhhab affects Asr timing. Calculation method affects astronomical prayer calculations.';

  @override
  String get prayerSettingsJafariNote =>
      'Ja\'fari uses the Jafari calculation method.';

  @override
  String get doneLabel => 'Done';

  @override
  String get deenGreeting => 'Assalamu Alaikum';

  @override
  String get deenQiblaTurnTo => 'Turn towards Qibla';

  @override
  String deenVerseN(String verse) {
    return 'Verse $verse';
  }

  @override
  String get deenContinue => 'Continue';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountTitle => 'Delete your account?';

  @override
  String get deleteAccountMsg =>
      'This permanently deletes your account, your business listings, leads and credits. This cannot be undone.';

  @override
  String get deleteAccountFailed =>
      'We couldn\'t delete your account right now. Please email info@konnectkashmir.com and we\'ll do it for you.';

  @override
  String get filterLabel => 'Filter';

  @override
  String get textSize => 'Text size';

  @override
  String get deleteAccountEnterPhone =>
      'Enter your registered phone number to confirm';

  @override
  String get deleteAccountDone =>
      'Account deleted successfully. You can sign up again anytime.';

  @override
  String get deleteAccountBadPhone =>
      'Enter the 10-digit phone number of this account.';

  @override
  String get watchAdsTitle => 'Watch Ads to Earn Credits';

  @override
  String get watchAdsSubtitle => 'Watch a short video to earn free credits';

  @override
  String plusCredits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count credits',
      one: '+1 credit',
    );
    return '$_temp0';
  }

  @override
  String adsLeft(int count) {
    return '$count left';
  }

  @override
  String creditsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count credits',
      one: '1 credit',
    );
    return '$_temp0';
  }

  @override
  String get findServices => 'Find services';

  @override
  String hiName(String name) {
    return 'Hi, $name';
  }

  @override
  String get searchByNameOrService => 'Search by name or service';

  @override
  String get searchMinChars => 'Enter at least 3 characters to search';

  @override
  String get useMyLocation => 'Use my current location';

  @override
  String get findingLocation => 'Finding your location…';

  @override
  String get showInMap => 'Show in map';

  @override
  String get replaceAddressTitle => 'Replace your address?';

  @override
  String get replaceAddressBody =>
      'This will replace the address and map location you entered.';

  @override
  String get replaceLabel => 'Replace';

  @override
  String get addressLocationOff => 'Turn on location to fill in your address';

  @override
  String get addressLocationDenied =>
      'Location permission is needed to fill in your address. Allow it in your phone settings.';

  @override
  String get addressNotFound =>
      'Couldn\'t find an address for this spot. The map pin was saved; please type the address.';

  @override
  String get couldntOpenMap => 'Couldn\'t open Google Maps';

  @override
  String get filterVerifiedOnly => 'Verified only';

  @override
  String get filterSaved => 'Saved';

  @override
  String creditsEarned(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count credits earned!',
      one: '+1 credit earned!',
    );
    return '$_temp0';
  }

  @override
  String creditsEarnedBalance(int count, int balance) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count credits earned! You now have $balance credits.',
      one: '+1 credit earned! You now have $balance credits.',
    );
    return '$_temp0';
  }

  @override
  String get couldntAddCredits => 'Couldn\'t add credits. Try again.';

  @override
  String callingPhone(String phone) {
    return 'Calling +91 $phone…';
  }

  @override
  String get creditUnlocksOne => '1 credit unlocks 1 provider contact.';

  @override
  String adRewardProgress(int reward, int watched, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      reward,
      locale: localeName,
      other: '+$reward credits',
      one: '+1 credit',
    );
    return '$_temp0 · $watched/$max watched';
  }

  @override
  String creditsAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count credits added!',
      one: '+1 credit added!',
    );
    return '$_temp0';
  }

  @override
  String get seeMore => 'See more';

  @override
  String get seeLess => 'See less';

  @override
  String get sameAsBusinessNumber => 'Same as business number';

  @override
  String get prayerAlarms => 'Prayer alarms';

  @override
  String get prayerAlarmsMaster => 'Beep at prayer times';

  @override
  String prayerAlarmNotifTitle(String prayer) {
    return '$prayer prayer time';
  }

  @override
  String prayerAlarmNotifBody(String prayer) {
    return 'It\'s time for $prayer prayer.';
  }

  @override
  String prayerAlarmNotifEndsTomorrow(String prayer) {
    return 'Prayer alarms end tomorrow: open the app to keep them going. It\'s time for $prayer prayer.';
  }

  @override
  String prayerAlarmNotifEndsToday(String prayer) {
    return 'Prayer alarms end today: open the app to keep them going. It\'s time for $prayer prayer.';
  }

  @override
  String get prayerAlarmNotifLastTitle => 'Prayer alarms have ended';

  @override
  String prayerAlarmNotifLastBody(String prayer) {
    return 'Open Konnect Kashmir to continue: you won\'t get prayer notifications now. It\'s time for $prayer prayer.';
  }

  @override
  String get prayerAlarmNotifBlocked =>
      'Notifications are off for Konnect Kashmir, so the alarms cannot sound.';

  @override
  String get prayerAlarmAllowNotifications => 'Allow notifications';

  @override
  String get prayerAlarmOpenSettings => 'Open settings';

  @override
  String get prayerAlarmExactOff =>
      'Exact alarm permission is off, so prayer alarms may not ring until you allow it.';

  @override
  String get prayerAlarmAllowExact => 'Allow exact alarms';

  @override
  String get prayerAlarmNoLocation =>
      'Allow location once so we can work out prayer times for where you are.';

  @override
  String get prayerAlarmNoTimes =>
      'Prayer times could not be loaded yet. Connect to the internet and try again.';

  @override
  String get prayerAlarmNoRoom =>
      'This phone has no room left for more alarms.';

  @override
  String get prayerAlarmFooter =>
      'The beep follows your phone\'s volume, silent mode and Do Not Disturb settings.';

  @override
  String get prayerAlarmRefresh => 'Refresh alarms';

  @override
  String get prayerAlarmFailed =>
      'Some alarms could not be set. Try Refresh alarms.';

  @override
  String get shareBusiness => 'Share';

  @override
  String shareBusinessIntro(String name) {
    return 'Check out $name on Konnect Kashmir';
  }

  @override
  String shareBusinessCategory(String value) {
    return 'Category: $value';
  }

  @override
  String shareBusinessAddress(String value) {
    return 'Address: $value';
  }

  @override
  String shareBusinessArea(String value) {
    return 'Area: $value';
  }

  @override
  String shareBusinessPhone(String value) {
    return 'Phone: $value';
  }

  @override
  String shareBusinessLink(String url) {
    return 'View details: $url';
  }

  @override
  String get shareBusinessFailed =>
      'Couldn\'t open the share sheet. Please try again.';

  @override
  String get sharedBusinessTitle => 'Shared with you';

  @override
  String get sharedBusinessMissing =>
      'This business is not available any more.';

  @override
  String get detailsAbout => 'About';

  @override
  String get detailsServices => 'Services';

  @override
  String get detailsWorkingHours => 'Working hours';

  @override
  String get detailsPriceRange => 'Price range';

  @override
  String get detailsExperience => 'Experience';

  @override
  String get detailsContactLocation => 'Contact & location';

  @override
  String get detailsPhone => 'Phone';

  @override
  String get detailsAddress => 'Address';

  @override
  String get detailsArea => 'Area';

  @override
  String get detailsDirections => 'Directions';

  @override
  String get detailsLocked =>
      'Unlock this business to see its phone number and exact address.';

  @override
  String get detailsReviews => 'Reviews';

  @override
  String get detailsNoReviews => 'No reviews yet';

  @override
  String detailsReviewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reviews',
      one: '1 review',
    );
    return '$_temp0';
  }

  @override
  String detailsShowAllReviews(int count) {
    return 'Show all $count reviews';
  }

  @override
  String get detailsShowFewerReviews => 'Show fewer';

  @override
  String get detailsReport => 'Report this business';

  @override
  String get detailsNotFound => 'This business is not available any more.';

  @override
  String detailsPhotoLabel(int n, int total) {
    return 'Photo $n of $total';
  }

  @override
  String get detailsVerified => 'Verified';

  @override
  String get prayerAlarmExactDialogTitle => 'Allow exact alarms';

  @override
  String get prayerAlarmExactDialogBody =>
      'To ring at the exact prayer time, Android needs your permission for exact alarms. Without it, prayer alarms can be late or may not ring.\n\nTap Grant permission, then switch on Konnect Kashmir on the next screen.';

  @override
  String get prayerAlarmGrantPermission => 'Grant permission';

  @override
  String get prayerAlarmExactStillNeeded =>
      'Exact alarm permission is still needed for prayer alarms to ring at the exact time.';

  @override
  String get prayerAlarmWarningTooltip => 'Prayer alarms need permission';

  @override
  String get prayerAlarmNotifDialogTitle => 'Allow notifications';

  @override
  String get prayerAlarmNotifDialogBody =>
      'Tap Open settings, then switch on Notifications (and Sounds).';

  @override
  String get prayerAlarmNotSetTooltip => 'Prayer alarms could not be set';

  @override
  String get prayerAlarmNotifBlockedAndroid =>
      'The “Prayer alarms” notifications are off or silent for Konnect Kashmir, so the beep cannot sound.';

  @override
  String get prayerAlarmNotifDialogBodyAndroid =>
      'Tap Open settings, then Notifications, and switch on “Prayer alarms”.';

  @override
  String get blockedTitle => 'Account Blocked';

  @override
  String get blockedBody =>
      'Your account has been blocked for misuse or policy violation.';

  @override
  String blockedReason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get blockedContactHelp =>
      'If you think this is a mistake, please contact support.';

  @override
  String get blockedContactButton => 'Contact support';

  @override
  String get deenWeather => 'Weather';

  @override
  String weatherFeelsLike(String temp) {
    return 'Feels like $temp';
  }

  @override
  String get weatherHumidity => 'Humidity';

  @override
  String get weatherWind => 'Wind';

  @override
  String weatherWindValue(String speed) {
    return '$speed km/h';
  }

  @override
  String get weatherSunrise => 'Sunrise';

  @override
  String get weatherSunset => 'Sunset';

  @override
  String get weatherClear => 'Clear sky';

  @override
  String get weatherPartlyCloudy => 'Partly cloudy';

  @override
  String get weatherCloudy => 'Cloudy';

  @override
  String get weatherDrizzle => 'Drizzle';

  @override
  String get weatherRain => 'Rain';

  @override
  String get weatherThunderstorm => 'Thunderstorm';

  @override
  String get weatherSnow => 'Snow';

  @override
  String get weatherFog => 'Fog';

  @override
  String get weatherHaze => 'Haze';

  @override
  String get weatherDust => 'Dust';

  @override
  String get weatherStorm => 'Stormy winds';

  @override
  String get signInToContinue => 'Please sign in to continue';

  @override
  String get weatherCreditMet => 'Data from MET Norway';

  @override
  String get businessPhotos => 'Business Photos';

  @override
  String get optionalTag => 'Optional';

  @override
  String photosSubtitle(int max) {
    return 'Add up to $max photos to showcase your business';
  }

  @override
  String photosCount(int count, int max) {
    return 'Photos ($count/$max)';
  }

  @override
  String get addPhotos => 'Add photos';

  @override
  String photosLimitReached(int max) {
    return 'You have reached the limit of $max photos. Delete one to add another.';
  }

  @override
  String get photosUploadedOnSubmit =>
      'Your photos are uploaded when you submit.';

  @override
  String get movePhotoEarlier => 'Move earlier';

  @override
  String get movePhotoLater => 'Move later';

  @override
  String get deletePhoto => 'Delete photo';

  @override
  String get deletePhotoTitle => 'Delete this photo?';

  @override
  String get deletePhotoBody =>
      'It will be removed from your business for everyone.';

  @override
  String photoCompressed(String name, int before, int after) {
    return 'Compressed: $name: $before KB -> $after KB';
  }

  @override
  String photoCompressedMore(int count) {
    return '+$count more';
  }

  @override
  String photosNotAddedLimit(int count, int max) {
    return '$count photos were not added. A business can have up to $max photos.';
  }

  @override
  String photoTooLarge(String name, int mb) {
    return '$name is larger than $mb MB, so it was not added.';
  }

  @override
  String photoUnsupported(String name) {
    return '$name is not a JPG, PNG or WEBP photo, so it was not added.';
  }

  @override
  String photoUnreadable(String name) {
    return '$name could not be read, so it was not added.';
  }

  @override
  String photosSkipped(int count, int mb) {
    return '$count photos were not added. Only JPG, PNG or WEBP files up to $mb MB can be used.';
  }

  @override
  String photosUploadFailed(int count) {
    return '$count photos could not be uploaded. Check your connection and try again.';
  }

  @override
  String get photoDeleteFailed =>
      'The photo could not be deleted. Check your connection and try again.';

  @override
  String get photoMoveFailed =>
      'The new order could not be saved. Check your connection and try again.';

  @override
  String get photosLoadFailed =>
      'Your photos could not be loaded. Check your connection.';

  @override
  String businessSubmittedPhotosFailed(int count) {
    return '$count photos could not be uploaded. Open Edit Business to add them again.';
  }

  @override
  String get noPhotosTitle => 'No photos available';

  @override
  String get noPhotosSubtitle => 'Business photos will appear here';
}
