import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('hi')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'FixEase'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navDiagnose.
  ///
  /// In en, this message translates to:
  /// **'Diagnose'**
  String get navDiagnose;

  /// No description provided for @navGarage.
  ///
  /// In en, this message translates to:
  /// **'Garage'**
  String get navGarage;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @chooseDiagnosticMode.
  ///
  /// In en, this message translates to:
  /// **'Choose Diagnostic Mode'**
  String get chooseDiagnosticMode;

  /// No description provided for @diagnoseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select how you\'d like to diagnose your vehicle.'**
  String get diagnoseSubtitle;

  /// No description provided for @addVehicleFirst.
  ///
  /// In en, this message translates to:
  /// **'Add a vehicle first'**
  String get addVehicleFirst;

  /// No description provided for @urgentOnTheSpot.
  ///
  /// In en, this message translates to:
  /// **'Urgent On-the-Spot'**
  String get urgentOnTheSpot;

  /// No description provided for @urgentDescription.
  ///
  /// In en, this message translates to:
  /// **'Answer quick questions about symptoms you\'re experiencing right now for an immediate AI analysis.'**
  String get urgentDescription;

  /// No description provided for @photoBased.
  ///
  /// In en, this message translates to:
  /// **'Photo-Based'**
  String get photoBased;

  /// No description provided for @photoDescription.
  ///
  /// In en, this message translates to:
  /// **'Upload or take photos of the issue — our AI analyzes visible damage, fluid leaks, tire wear, and more.'**
  String get photoDescription;

  /// No description provided for @geminiLive.
  ///
  /// In en, this message translates to:
  /// **'Gemini Live'**
  String get geminiLive;

  /// No description provided for @geminiLiveDescription.
  ///
  /// In en, this message translates to:
  /// **'Real-time AI diagnosis via your camera. Point, capture, and chat with Gemini about what it sees.'**
  String get geminiLiveDescription;

  /// No description provided for @obdProSuite.
  ///
  /// In en, this message translates to:
  /// **'OBD Pro Diagnostic Suite'**
  String get obdProSuite;

  /// No description provided for @obdProDescription.
  ///
  /// In en, this message translates to:
  /// **'Connect a Bluetooth ELM327 adapter for live vitals, ECU snapshot, and premium idle and drive scans.'**
  String get obdProDescription;

  /// No description provided for @errorCodeLookup.
  ///
  /// In en, this message translates to:
  /// **'Error Code Lookup'**
  String get errorCodeLookup;

  /// No description provided for @errorCodeLookupDescription.
  ///
  /// In en, this message translates to:
  /// **'Search any OBD-II code (P/C/B/U) — works for all car brands. Find what P0420, C0035, and thousands of other codes mean.'**
  String get errorCodeLookupDescription;

  /// No description provided for @dtcLookupTitle.
  ///
  /// In en, this message translates to:
  /// **'Error Code Lookup'**
  String get dtcLookupTitle;

  /// No description provided for @dtcSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search any OBD-II code'**
  String get dtcSearchHint;

  /// No description provided for @dtcSearchHelp.
  ///
  /// In en, this message translates to:
  /// **'Works for all cars — P (engine), C (chassis), B (body), U (network). Use * as wildcard, e.g. P04* for P0400–P0499.'**
  String get dtcSearchHelp;

  /// No description provided for @lookupAnyCode.
  ///
  /// In en, this message translates to:
  /// **'Lookup any code'**
  String get lookupAnyCode;

  /// No description provided for @storedDtcs.
  ///
  /// In en, this message translates to:
  /// **'Stored DTCs'**
  String get storedDtcs;

  /// No description provided for @pendingDtcs.
  ///
  /// In en, this message translates to:
  /// **'Pending DTCs'**
  String get pendingDtcs;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'FixEase Driver'**
  String get profileTitle;

  /// No description provided for @profileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Guest mode · all core data stays on this device'**
  String get profileSubtitle;

  /// No description provided for @myVehicles.
  ///
  /// In en, this message translates to:
  /// **'My Vehicles'**
  String get myVehicles;

  /// No description provided for @addVehicle.
  ///
  /// In en, this message translates to:
  /// **'Add Vehicle'**
  String get addVehicle;

  /// No description provided for @diagnosticHistory.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic History'**
  String get diagnosticHistory;

  /// No description provided for @subscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get subscription;

  /// No description provided for @support.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @lightTheme.
  ///
  /// In en, this message translates to:
  /// **'Light theme'**
  String get lightTheme;

  /// No description provided for @lightThemeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Switch to a bright, readable interface'**
  String get lightThemeSubtitle;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageHindi.
  ///
  /// In en, this message translates to:
  /// **'Hindi (Hinglish)'**
  String get languageHindi;

  /// No description provided for @languageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'App text aur voice dono ke liye'**
  String get languageSubtitle;

  /// No description provided for @reportPdf.
  ///
  /// In en, this message translates to:
  /// **'Report PDF'**
  String get reportPdf;

  /// No description provided for @sharePdf.
  ///
  /// In en, this message translates to:
  /// **'Share PDF'**
  String get sharePdf;

  /// No description provided for @savePdf.
  ///
  /// In en, this message translates to:
  /// **'Save PDF'**
  String get savePdf;

  /// No description provided for @vehicleHealth.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Health'**
  String get vehicleHealth;

  /// No description provided for @billFairness.
  ///
  /// In en, this message translates to:
  /// **'Bill Fairness'**
  String get billFairness;

  /// No description provided for @buildYourGarage.
  ///
  /// In en, this message translates to:
  /// **'Build Your Garage'**
  String get buildYourGarage;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @saveVehicle.
  ///
  /// In en, this message translates to:
  /// **'Save Vehicle'**
  String get saveVehicle;

  /// No description provided for @enterVin.
  ///
  /// In en, this message translates to:
  /// **'Enter VIN'**
  String get enterVin;

  /// No description provided for @vinStoredSecurely.
  ///
  /// In en, this message translates to:
  /// **'Your full VIN is saved securely. Only the last 4 digits are shown in the app.'**
  String get vinStoredSecurely;
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
      <String>['en', 'hi'].contains(locale.languageCode);

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
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
