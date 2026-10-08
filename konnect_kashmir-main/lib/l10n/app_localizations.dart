import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_ur.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
    Locale('ur'),
  ];

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navMyBusiness.
  ///
  /// In en, this message translates to:
  /// **'My Business'**
  String get navMyBusiness;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @chooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get chooseLanguage;

  /// No description provided for @chooseLanguageHint.
  ///
  /// In en, this message translates to:
  /// **'You can change this anytime from Profile.'**
  String get chooseLanguageHint;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @noInternet.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get noInternet;

  /// No description provided for @checkConnection.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get checkConnection;

  /// No description provided for @somethingWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWrong;

  /// No description provided for @tryAgainMoment.
  ///
  /// In en, this message translates to:
  /// **'Please try again in a moment.'**
  String get tryAgainMoment;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @enterYourName.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get enterYourName;

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone: {phone}'**
  String phoneLabel(String phone);

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChanges;

  /// No description provided for @validNameError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid name'**
  String get validNameError;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get profileUpdated;

  /// No description provided for @couldntSave.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save. Try again.'**
  String get couldntSave;

  /// No description provided for @legal.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get legal;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @refundPolicy.
  ///
  /// In en, this message translates to:
  /// **'Refund Policy'**
  String get refundPolicy;

  /// No description provided for @grievanceRedressal.
  ///
  /// In en, this message translates to:
  /// **'Grievance Redressal'**
  String get grievanceRedressal;

  /// No description provided for @signOutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get signOutConfirm;

  /// No description provided for @yourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get yourName;

  /// No description provided for @adCredits.
  ///
  /// In en, this message translates to:
  /// **'Ad credits'**
  String get adCredits;

  /// No description provided for @transactionHistory.
  ///
  /// In en, this message translates to:
  /// **'Transaction history'**
  String get transactionHistory;

  /// No description provided for @contactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact us'**
  String get contactUs;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @sessionExpiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Session expired'**
  String get sessionExpiredTitle;

  /// No description provided for @sessionExpiredMsg.
  ///
  /// In en, this message translates to:
  /// **'For your security you need to sign in again to load your leads and credits.'**
  String get sessionExpiredMsg;

  /// No description provided for @noCreditsBanner.
  ///
  /// In en, this message translates to:
  /// **'No credits left. Watch an ad to reveal leads.'**
  String get noCreditsBanner;

  /// No description provided for @watchAd.
  ///
  /// In en, this message translates to:
  /// **'Watch ad'**
  String get watchAd;

  /// No description provided for @noBusinessYet.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t listed a business yet'**
  String get noBusinessYet;

  /// No description provided for @listBusinessIntro.
  ///
  /// In en, this message translates to:
  /// **'List your services and get discovered by customers across Kashmir.'**
  String get listBusinessIntro;

  /// No description provided for @listMyBusiness.
  ///
  /// In en, this message translates to:
  /// **'List my business'**
  String get listMyBusiness;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @leads.
  ///
  /// In en, this message translates to:
  /// **'Leads'**
  String get leads;

  /// No description provided for @noLeadsYet.
  ///
  /// In en, this message translates to:
  /// **'No leads yet'**
  String get noLeadsYet;

  /// No description provided for @noLeadsHint.
  ///
  /// In en, this message translates to:
  /// **'Customers who show interest will appear here.'**
  String get noLeadsHint;

  /// No description provided for @revealCostsCredit.
  ///
  /// In en, this message translates to:
  /// **'Revealing a contact costs 1 credit.'**
  String get revealCostsCredit;

  /// No description provided for @call.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get call;

  /// No description provided for @chatOnWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'Chat on WhatsApp'**
  String get chatOnWhatsapp;

  /// No description provided for @getLead.
  ///
  /// In en, this message translates to:
  /// **'Get Lead'**
  String get getLead;

  /// No description provided for @statusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get statusActive;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @customer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get customer;

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get timeJustNow;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String minutesAgo(int count);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour ago} other{{count} hours ago}}'**
  String hoursAgo(int count);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day ago} other{{count} days ago}}'**
  String daysAgo(int count);

  /// No description provided for @snackRevealedNoBalance.
  ///
  /// In en, this message translates to:
  /// **'Contact revealed, but your credit balance could not be updated.'**
  String get snackRevealedNoBalance;

  /// No description provided for @snackNotEnoughCredits.
  ///
  /// In en, this message translates to:
  /// **'Not enough credits. Watch an ad to earn credits.'**
  String get snackNotEnoughCredits;

  /// No description provided for @snackCouldNotReveal.
  ///
  /// In en, this message translates to:
  /// **'Could not reveal contact. Try again.'**
  String get snackCouldNotReveal;

  /// No description provided for @snackNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please try again.'**
  String get snackNetworkError;

  /// No description provided for @snackSessionExpiredLeads.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired, so leads cannot load. Please sign in again.'**
  String get snackSessionExpiredLeads;

  /// No description provided for @snackCouldntRefreshLeads.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t refresh leads. {detail}'**
  String snackCouldntRefreshLeads(String detail);

  /// No description provided for @couldntLoadBusiness.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your business'**
  String get couldntLoadBusiness;

  /// No description provided for @couldntOpenWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open WhatsApp'**
  String get couldntOpenWhatsapp;

  /// No description provided for @salam.
  ///
  /// In en, this message translates to:
  /// **'Salam'**
  String get salam;

  /// No description provided for @greeting.
  ///
  /// In en, this message translates to:
  /// **'Salam, {name}'**
  String greeting(String name);

  /// No description provided for @heroLine1.
  ///
  /// In en, this message translates to:
  /// **'Trusted local pros,'**
  String get heroLine1;

  /// No description provided for @heroLine2.
  ///
  /// In en, this message translates to:
  /// **'one tap away.'**
  String get heroLine2;

  /// No description provided for @searchVendors.
  ///
  /// In en, this message translates to:
  /// **'Search vendors...'**
  String get searchVendors;

  /// No description provided for @allDistricts.
  ///
  /// In en, this message translates to:
  /// **'All districts'**
  String get allDistricts;

  /// No description provided for @allLocalities.
  ///
  /// In en, this message translates to:
  /// **'All localities'**
  String get allLocalities;

  /// No description provided for @selectDistrictFirst.
  ///
  /// In en, this message translates to:
  /// **'Select a district first'**
  String get selectDistrictFirst;

  /// No description provided for @filterByDistrict.
  ///
  /// In en, this message translates to:
  /// **'Filter by district'**
  String get filterByDistrict;

  /// No description provided for @localitiesIn.
  ///
  /// In en, this message translates to:
  /// **'Localities in {district}'**
  String localitiesIn(String district);

  /// No description provided for @ourServices.
  ///
  /// In en, this message translates to:
  /// **'Our services'**
  String get ourServices;

  /// No description provided for @showAll.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get showAll;

  /// No description provided for @showLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get showLess;

  /// No description provided for @showMore.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get showMore;

  /// No description provided for @providerCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 provider} other{{count} providers}}'**
  String providerCount(int count);

  /// No description provided for @findingProviders.
  ///
  /// In en, this message translates to:
  /// **'Finding providers…'**
  String get findingProviders;

  /// No description provided for @noProvidersFound.
  ///
  /// In en, this message translates to:
  /// **'No providers found'**
  String get noProvidersFound;

  /// No description provided for @noSavedProviders.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t saved any providers here yet.'**
  String get noSavedProviders;

  /// No description provided for @tryDifferentSearch.
  ///
  /// In en, this message translates to:
  /// **'Try a different search or change your filters.'**
  String get tryDifferentSearch;

  /// No description provided for @clearAllFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear all filters'**
  String get clearAllFilters;

  /// No description provided for @homeVisit.
  ///
  /// In en, this message translates to:
  /// **'Home visit'**
  String get homeVisit;

  /// No description provided for @onlinePay.
  ///
  /// In en, this message translates to:
  /// **'Online pay'**
  String get onlinePay;

  /// No description provided for @yrs.
  ///
  /// In en, this message translates to:
  /// **'{years} yrs'**
  String yrs(String years);

  /// No description provided for @whatsapp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get whatsapp;

  /// No description provided for @unlocked.
  ///
  /// In en, this message translates to:
  /// **'Unlocked'**
  String get unlocked;

  /// No description provided for @contact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get contact;

  /// No description provided for @hide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hide;

  /// No description provided for @rateReviewReport.
  ///
  /// In en, this message translates to:
  /// **'Rate, review or report'**
  String get rateReviewReport;

  /// No description provided for @signInToUnlock.
  ///
  /// In en, this message translates to:
  /// **'Sign in to unlock'**
  String get signInToUnlock;

  /// No description provided for @unlockOneCredit.
  ///
  /// In en, this message translates to:
  /// **'Unlock · 1 credit'**
  String get unlockOneCredit;

  /// No description provided for @unlockContact.
  ///
  /// In en, this message translates to:
  /// **'Unlock Contact'**
  String get unlockContact;

  /// No description provided for @watchAdToUnlock.
  ///
  /// In en, this message translates to:
  /// **'Watch ad to unlock'**
  String get watchAdToUnlock;

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @district.
  ///
  /// In en, this message translates to:
  /// **'District'**
  String get district;

  /// No description provided for @locality.
  ///
  /// In en, this message translates to:
  /// **'Locality'**
  String get locality;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @verifiedProvidersOnly.
  ///
  /// In en, this message translates to:
  /// **'Verified providers only'**
  String get verifiedProvidersOnly;

  /// No description provided for @savedProvidersOnly.
  ///
  /// In en, this message translates to:
  /// **'Saved providers only'**
  String get savedProvidersOnly;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortBy;

  /// No description provided for @sortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get sortNewest;

  /// No description provided for @sortExperienced.
  ///
  /// In en, this message translates to:
  /// **'Most experienced'**
  String get sortExperienced;

  /// No description provided for @sortPriceLow.
  ///
  /// In en, this message translates to:
  /// **'Price low to high'**
  String get sortPriceLow;

  /// No description provided for @showResults.
  ///
  /// In en, this message translates to:
  /// **'Show results'**
  String get showResults;

  /// No description provided for @snackNoAds.
  ///
  /// In en, this message translates to:
  /// **'No ads available right now.'**
  String get snackNoAds;

  /// No description provided for @snackNoCreditsNoAds.
  ///
  /// In en, this message translates to:
  /// **'No credits & no ads available. Check back later.'**
  String get snackNoCreditsNoAds;

  /// No description provided for @snackNotEnoughAfterAd.
  ///
  /// In en, this message translates to:
  /// **'Not enough credits after ad. Please try again.'**
  String get snackNotEnoughAfterAd;

  /// No description provided for @snackCouldNotUnlock.
  ///
  /// In en, this message translates to:
  /// **'Could not unlock contact. Please try again.'**
  String get snackCouldNotUnlock;

  /// No description provided for @contactUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Contact Unlocked!'**
  String get contactUnlocked;

  /// No description provided for @contactDetails.
  ///
  /// In en, this message translates to:
  /// **'Contact Details'**
  String get contactDetails;

  /// No description provided for @contactInfoFor.
  ///
  /// In en, this message translates to:
  /// **'Contact information for {name}'**
  String contactInfoFor(String name);

  /// No description provided for @phoneNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Phone not available'**
  String get phoneNotAvailable;

  /// No description provided for @callNow.
  ///
  /// In en, this message translates to:
  /// **'Call Now'**
  String get callNow;

  /// No description provided for @loginTagline.
  ///
  /// In en, this message translates to:
  /// **'Kashmir\'s Local Services & Business Directory'**
  String get loginTagline;

  /// No description provided for @signInRegister.
  ///
  /// In en, this message translates to:
  /// **'Sign In / Register'**
  String get signInRegister;

  /// No description provided for @enterMobileToStart.
  ///
  /// In en, this message translates to:
  /// **'Enter your mobile number to get started'**
  String get enterMobileToStart;

  /// No description provided for @mobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Mobile Number'**
  String get mobileNumber;

  /// No description provided for @sendVerificationOtp.
  ///
  /// In en, this message translates to:
  /// **'Send Verification OTP'**
  String get sendVerificationOtp;

  /// No description provided for @safeSecure.
  ///
  /// In en, this message translates to:
  /// **'Safe & secure'**
  String get safeSecure;

  /// No description provided for @byContinuing.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to KonnectKashmir\'s'**
  String get byContinuing;

  /// No description provided for @andWord.
  ///
  /// In en, this message translates to:
  /// **'and'**
  String get andWord;

  /// No description provided for @errPhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a phone number'**
  String get errPhoneRequired;

  /// No description provided for @errPhoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 10-digit Indian mobile number'**
  String get errPhoneInvalid;

  /// No description provided for @errAuthFailed.
  ///
  /// In en, this message translates to:
  /// **'Auth failed'**
  String get errAuthFailed;

  /// No description provided for @errSendOtp.
  ///
  /// In en, this message translates to:
  /// **'Failed to send OTP'**
  String get errSendOtp;

  /// No description provided for @otpEnterComplete.
  ///
  /// In en, this message translates to:
  /// **'Please enter the complete 4-digit OTP'**
  String get otpEnterComplete;

  /// No description provided for @otpInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid OTP'**
  String get otpInvalid;

  /// No description provided for @otpExpired.
  ///
  /// In en, this message translates to:
  /// **'This OTP has expired. Please request a new one.'**
  String get otpExpired;

  /// No description provided for @otpResendFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to resend OTP'**
  String get otpResendFailed;

  /// No description provided for @verifyYourPhone.
  ///
  /// In en, this message translates to:
  /// **'Verify your phone number'**
  String get verifyYourPhone;

  /// No description provided for @otpVerification.
  ///
  /// In en, this message translates to:
  /// **'OTP Verification'**
  String get otpVerification;

  /// No description provided for @otpCodeSentTo.
  ///
  /// In en, this message translates to:
  /// **'Enter the 4-digit code sent to'**
  String get otpCodeSentTo;

  /// No description provided for @verifyAndProceed.
  ///
  /// In en, this message translates to:
  /// **'Verify & Proceed'**
  String get verifyAndProceed;

  /// No description provided for @resendOtp.
  ///
  /// In en, this message translates to:
  /// **'Resend OTP'**
  String get resendOtp;

  /// No description provided for @resendOtpIn.
  ///
  /// In en, this message translates to:
  /// **'Resend OTP in {seconds}s'**
  String resendOtpIn(String seconds);

  /// No description provided for @otpResent.
  ///
  /// In en, this message translates to:
  /// **'OTP resent successfully'**
  String get otpResent;

  /// No description provided for @editBusinessTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Business'**
  String get editBusinessTitle;

  /// No description provided for @listYourBusiness.
  ///
  /// In en, this message translates to:
  /// **'List Your Business'**
  String get listYourBusiness;

  /// No description provided for @updateBusinessInfo.
  ///
  /// In en, this message translates to:
  /// **'Update your business information'**
  String get updateBusinessInfo;

  /// No description provided for @getBusinessListed.
  ///
  /// In en, this message translates to:
  /// **'Get your business listed on KonnectKashmir'**
  String get getBusinessListed;

  /// No description provided for @businessDetails.
  ///
  /// In en, this message translates to:
  /// **'Business Details'**
  String get businessDetails;

  /// No description provided for @businessName.
  ///
  /// In en, this message translates to:
  /// **'Business Name *'**
  String get businessName;

  /// No description provided for @businessNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Ahmed\'s Plumbing Service'**
  String get businessNameHint;

  /// No description provided for @serviceCategoriesLabel.
  ///
  /// In en, this message translates to:
  /// **'Service Categories * (select up to 3)'**
  String get serviceCategoriesLabel;

  /// No description provided for @selectUpTo3.
  ///
  /// In en, this message translates to:
  /// **'Select up to 3 categories'**
  String get selectUpTo3;

  /// No description provided for @searchCategories.
  ///
  /// In en, this message translates to:
  /// **'Search categories...'**
  String get searchCategories;

  /// No description provided for @categoriesSelected.
  ///
  /// In en, this message translates to:
  /// **'{count}/3 categories selected'**
  String categoriesSelected(int count);

  /// No description provided for @districtLabel.
  ///
  /// In en, this message translates to:
  /// **'District *'**
  String get districtLabel;

  /// No description provided for @selectDistrict.
  ///
  /// In en, this message translates to:
  /// **'Select district'**
  String get selectDistrict;

  /// No description provided for @localityLabel.
  ///
  /// In en, this message translates to:
  /// **'Locality *'**
  String get localityLabel;

  /// No description provided for @selectLocality.
  ///
  /// In en, this message translates to:
  /// **'Select locality'**
  String get selectLocality;

  /// No description provided for @businessDescriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Business Description (optional)'**
  String get businessDescriptionOptional;

  /// No description provided for @descriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Tell customers about your services...'**
  String get descriptionHint;

  /// No description provided for @contactInfo.
  ///
  /// In en, this message translates to:
  /// **'Contact Info'**
  String get contactInfo;

  /// No description provided for @businessPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Business Phone Number *'**
  String get businessPhoneLabel;

  /// No description provided for @sameOrDifferent.
  ///
  /// In en, this message translates to:
  /// **'Same or different'**
  String get sameOrDifferent;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @shopOfficeAddress.
  ///
  /// In en, this message translates to:
  /// **'Shop/Office address'**
  String get shopOfficeAddress;

  /// No description provided for @homeServiceAvailable.
  ///
  /// In en, this message translates to:
  /// **'Home Service Available'**
  String get homeServiceAvailable;

  /// No description provided for @acceptOnlinePayment.
  ///
  /// In en, this message translates to:
  /// **'Accept Online Payment'**
  String get acceptOnlinePayment;

  /// No description provided for @listingReviewNote.
  ///
  /// In en, this message translates to:
  /// **'Your listing will be reviewed within 24-48 hours'**
  String get listingReviewNote;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get fieldRequired;

  /// No description provided for @pleaseSelectOption.
  ///
  /// In en, this message translates to:
  /// **'Please select an option'**
  String get pleaseSelectOption;

  /// No description provided for @selectAtLeastOneService.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one service'**
  String get selectAtLeastOneService;

  /// No description provided for @fillRequiredFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all required fields'**
  String get fillRequiredFields;

  /// No description provided for @networkCheckConnection.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please check your connection.'**
  String get networkCheckConnection;

  /// No description provided for @successTitle.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get successTitle;

  /// No description provided for @errorTitle.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get errorTitle;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @businessUpdatedMsg.
  ///
  /// In en, this message translates to:
  /// **'Your business has been updated successfully!'**
  String get businessUpdatedMsg;

  /// No description provided for @businessSubmittedMsg.
  ///
  /// In en, this message translates to:
  /// **'Your business listing has been submitted for review!'**
  String get businessSubmittedMsg;

  /// No description provided for @yourBalance.
  ///
  /// In en, this message translates to:
  /// **'Your balance'**
  String get yourBalance;

  /// No description provided for @watchAndEarn.
  ///
  /// In en, this message translates to:
  /// **'Watch & earn'**
  String get watchAndEarn;

  /// No description provided for @noAdsNow.
  ///
  /// In en, this message translates to:
  /// **'No ads available right now'**
  String get noAdsNow;

  /// No description provided for @noAdsHint.
  ///
  /// In en, this message translates to:
  /// **'Check back later for new ways to earn credits.'**
  String get noAdsHint;

  /// No description provided for @sponsoredVideo.
  ///
  /// In en, this message translates to:
  /// **'Sponsored video'**
  String get sponsoredVideo;

  /// No description provided for @watchBtn.
  ///
  /// In en, this message translates to:
  /// **'Watch'**
  String get watchBtn;

  /// No description provided for @txnContactUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Contact unlocked'**
  String get txnContactUnlocked;

  /// No description provided for @txnVendorRevealed.
  ///
  /// In en, this message translates to:
  /// **'Vendor contact revealed'**
  String get txnVendorRevealed;

  /// No description provided for @txnWelcomeBonus.
  ///
  /// In en, this message translates to:
  /// **'Welcome bonus'**
  String get txnWelcomeBonus;

  /// No description provided for @txnNewAccountReward.
  ///
  /// In en, this message translates to:
  /// **'New account reward'**
  String get txnNewAccountReward;

  /// No description provided for @txnReferralBonus.
  ///
  /// In en, this message translates to:
  /// **'Referral bonus'**
  String get txnReferralBonus;

  /// No description provided for @txnReferralReward.
  ///
  /// In en, this message translates to:
  /// **'Referral credit reward'**
  String get txnReferralReward;

  /// No description provided for @txnCreditPurchase.
  ///
  /// In en, this message translates to:
  /// **'Credit purchase'**
  String get txnCreditPurchase;

  /// No description provided for @txnCreditsAdded.
  ///
  /// In en, this message translates to:
  /// **'Credits added'**
  String get txnCreditsAdded;

  /// No description provided for @txnRefund.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get txnRefund;

  /// No description provided for @txnCreditsRefunded.
  ///
  /// In en, this message translates to:
  /// **'Credits refunded'**
  String get txnCreditsRefunded;

  /// No description provided for @txnAdReward.
  ///
  /// In en, this message translates to:
  /// **'Ad reward'**
  String get txnAdReward;

  /// No description provided for @txnWatchedAd.
  ///
  /// In en, this message translates to:
  /// **'Watched an ad'**
  String get txnWatchedAd;

  /// No description provided for @txnCreditsSpent.
  ///
  /// In en, this message translates to:
  /// **'Credits spent'**
  String get txnCreditsSpent;

  /// No description provided for @txnCreditUsed.
  ///
  /// In en, this message translates to:
  /// **'Credit used'**
  String get txnCreditUsed;

  /// No description provided for @noTransactionsYet.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get noTransactionsYet;

  /// No description provided for @noTransactionsHint.
  ///
  /// In en, this message translates to:
  /// **'Credits you earn or spend will show up here.'**
  String get noTransactionsHint;

  /// No description provided for @errNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your full name'**
  String get errNameRequired;

  /// No description provided for @errNameShort.
  ///
  /// In en, this message translates to:
  /// **'Name must be at least 2 characters'**
  String get errNameShort;

  /// No description provided for @errRequestTimeout.
  ///
  /// In en, this message translates to:
  /// **'Request timed out. Please try again.'**
  String get errRequestTimeout;

  /// No description provided for @completeYourProfile.
  ///
  /// In en, this message translates to:
  /// **'Complete Your Profile'**
  String get completeYourProfile;

  /// No description provided for @enterNameToContinue.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name to continue using KonnectKashmir'**
  String get enterNameToContinue;

  /// No description provided for @yourFullName.
  ///
  /// In en, this message translates to:
  /// **'Your Full Name'**
  String get yourFullName;

  /// No description provided for @enterFullName.
  ///
  /// In en, this message translates to:
  /// **'Enter your full name'**
  String get enterFullName;

  /// No description provided for @visibleToVendors.
  ///
  /// In en, this message translates to:
  /// **'This will be visible to vendors when you contact them'**
  String get visibleToVendors;

  /// No description provided for @backToHome.
  ///
  /// In en, this message translates to:
  /// **'Back to Home'**
  String get backToHome;

  /// No description provided for @ourOffice.
  ///
  /// In en, this message translates to:
  /// **'Our Office'**
  String get ourOffice;

  /// No description provided for @callUs.
  ///
  /// In en, this message translates to:
  /// **'Call Us'**
  String get callUs;

  /// No description provided for @chatWithUsWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'Chat with us on WhatsApp'**
  String get chatWithUsWhatsapp;

  /// No description provided for @businessHours.
  ///
  /// In en, this message translates to:
  /// **'Business Hours'**
  String get businessHours;

  /// No description provided for @mondaySaturday.
  ///
  /// In en, this message translates to:
  /// **'Monday - Saturday'**
  String get mondaySaturday;

  /// No description provided for @sunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get sunday;

  /// No description provided for @closed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get closed;

  /// No description provided for @categoryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get categoryAll;

  /// No description provided for @navDeen.
  ///
  /// In en, this message translates to:
  /// **'Deen'**
  String get navDeen;

  /// No description provided for @addCredit.
  ///
  /// In en, this message translates to:
  /// **'Add Credit'**
  String get addCredit;

  /// No description provided for @deenPrayerTimes.
  ///
  /// In en, this message translates to:
  /// **'Prayer Times'**
  String get deenPrayerTimes;

  /// No description provided for @prayerFajr.
  ///
  /// In en, this message translates to:
  /// **'Fajr'**
  String get prayerFajr;

  /// No description provided for @prayerDhuhr.
  ///
  /// In en, this message translates to:
  /// **'Dhuhr'**
  String get prayerDhuhr;

  /// No description provided for @prayerAsr.
  ///
  /// In en, this message translates to:
  /// **'Asr'**
  String get prayerAsr;

  /// No description provided for @prayerMaghrib.
  ///
  /// In en, this message translates to:
  /// **'Maghrib'**
  String get prayerMaghrib;

  /// No description provided for @prayerIsha.
  ///
  /// In en, this message translates to:
  /// **'Isha'**
  String get prayerIsha;

  /// No description provided for @deenCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Current location'**
  String get deenCurrentLocation;

  /// No description provided for @deenLocating.
  ///
  /// In en, this message translates to:
  /// **'Finding your location…'**
  String get deenLocating;

  /// No description provided for @deenNextPrayer.
  ///
  /// In en, this message translates to:
  /// **'Next: {name} in {time}'**
  String deenNextPrayer(String name, String time);

  /// No description provided for @deenQibla.
  ///
  /// In en, this message translates to:
  /// **'Qibla'**
  String get deenQibla;

  /// No description provided for @deenQiblaAngle.
  ///
  /// In en, this message translates to:
  /// **'Qibla angle: {deg}° from North'**
  String deenQiblaAngle(String deg);

  /// No description provided for @deenQiblaAligned.
  ///
  /// In en, this message translates to:
  /// **'You are facing the Qibla'**
  String get deenQiblaAligned;

  /// No description provided for @deenQiblaHint.
  ///
  /// In en, this message translates to:
  /// **'Hold your phone flat and turn until the arrow points up'**
  String get deenQiblaHint;

  /// No description provided for @deenCompassMissing.
  ///
  /// In en, this message translates to:
  /// **'Compass is not available on this device. Use the angle above with a compass.'**
  String get deenCompassMissing;

  /// No description provided for @deenLocationOff.
  ///
  /// In en, this message translates to:
  /// **'Turn on location to see prayer times and the Qibla direction'**
  String get deenLocationOff;

  /// No description provided for @deenLocationDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission is needed for prayer times and the Qibla direction'**
  String get deenLocationDenied;

  /// No description provided for @deenLocationBlocked.
  ///
  /// In en, this message translates to:
  /// **'Location is blocked. Allow it from the app settings.'**
  String get deenLocationBlocked;

  /// No description provided for @deenAllowLocation.
  ///
  /// In en, this message translates to:
  /// **'Allow location'**
  String get deenAllowLocation;

  /// No description provided for @deenOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get deenOpenSettings;

  /// No description provided for @deenQuran.
  ///
  /// In en, this message translates to:
  /// **'Quran'**
  String get deenQuran;

  /// No description provided for @deenAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get deenAudio;

  /// No description provided for @deenDuas.
  ///
  /// In en, this message translates to:
  /// **'Duas'**
  String get deenDuas;

  /// No description provided for @deenIslamicAudio.
  ///
  /// In en, this message translates to:
  /// **'Islamic Audio'**
  String get deenIslamicAudio;

  /// No description provided for @deenContinueReading.
  ///
  /// In en, this message translates to:
  /// **'Continue Reading'**
  String get deenContinueReading;

  /// No description provided for @deenStartReading.
  ///
  /// In en, this message translates to:
  /// **'Start reading the Quran'**
  String get deenStartReading;

  /// No description provided for @deenLastRead.
  ///
  /// In en, this message translates to:
  /// **'{surah} · Verse {verse}'**
  String deenLastRead(String surah, String verse);

  /// No description provided for @deenSearchSurah.
  ///
  /// In en, this message translates to:
  /// **'Search surah'**
  String get deenSearchSurah;

  /// No description provided for @deenVerses.
  ///
  /// In en, this message translates to:
  /// **'{count} verses'**
  String deenVerses(String count);

  /// No description provided for @deenShowEarlier.
  ///
  /// In en, this message translates to:
  /// **'Show earlier verses'**
  String get deenShowEarlier;

  /// No description provided for @deenReciter.
  ///
  /// In en, this message translates to:
  /// **'Reciter'**
  String get deenReciter;

  /// No description provided for @deenAudioError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t play this recitation. Check your internet.'**
  String get deenAudioError;

  /// No description provided for @deenDuaSource.
  ///
  /// In en, this message translates to:
  /// **'Source: {source}'**
  String deenDuaSource(String source);

  /// No description provided for @txnReference.
  ///
  /// In en, this message translates to:
  /// **'Ref #{id}'**
  String txnReference(String id);

  /// No description provided for @txnStatusIs.
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String txnStatusIs(String status);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi', 'ur'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'ur':
      return AppLocalizationsUr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
