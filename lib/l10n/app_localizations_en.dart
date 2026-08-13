// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'FixEase';

  @override
  String get navHome => 'Home';

  @override
  String get navDiagnose => 'Diagnose';

  @override
  String get navGarage => 'Garage';

  @override
  String get navProfile => 'Profile';

  @override
  String get chooseDiagnosticMode => 'Choose Diagnostic Mode';

  @override
  String get diagnoseSubtitle =>
      'Select how you\'d like to diagnose your vehicle.';

  @override
  String get addVehicleFirst => 'Add a vehicle first';

  @override
  String get urgentOnTheSpot => 'Urgent On-the-Spot';

  @override
  String get urgentDescription =>
      'Answer quick questions about symptoms you\'re experiencing right now for an immediate AI analysis.';

  @override
  String get photoBased => 'Photo-Based';

  @override
  String get photoDescription =>
      'Upload or take photos of the issue — our AI analyzes visible damage, fluid leaks, tire wear, and more.';

  @override
  String get geminiLive => 'Gemini Live';

  @override
  String get geminiLiveDescription =>
      'Real-time AI diagnosis via your camera. Point, capture, and chat with Gemini about what it sees.';

  @override
  String get obdProSuite => 'OBD Pro Diagnostic Suite';

  @override
  String get obdProDescription =>
      'Connect a Bluetooth ELM327 adapter for live vitals, ECU snapshot, and premium idle and drive scans.';

  @override
  String get errorCodeLookup => 'Error Code Lookup';

  @override
  String get errorCodeLookupDescription =>
      'Search any OBD-II code (P/C/B/U) — works for all car brands. Find what P0420, C0035, and thousands of other codes mean.';

  @override
  String get dtcLookupTitle => 'Error Code Lookup';

  @override
  String get dtcSearchHint => 'Search any OBD-II code';

  @override
  String get dtcSearchHelp =>
      'Works for all cars — P (engine), C (chassis), B (body), U (network). Use * as wildcard, e.g. P04* for P0400–P0499.';

  @override
  String get lookupAnyCode => 'Lookup any code';

  @override
  String get storedDtcs => 'Stored DTCs';

  @override
  String get pendingDtcs => 'Pending DTCs';

  @override
  String get profileTitle => 'FixEase Driver';

  @override
  String get profileSubtitle =>
      'Guest mode · all core data stays on this device';

  @override
  String get myVehicles => 'My Vehicles';

  @override
  String get addVehicle => 'Add Vehicle';

  @override
  String get diagnosticHistory => 'Diagnostic History';

  @override
  String get subscription => 'Subscription';

  @override
  String get support => 'Support';

  @override
  String get about => 'About';

  @override
  String get settings => 'Settings';

  @override
  String get lightTheme => 'Light theme';

  @override
  String get lightThemeSubtitle => 'Switch to a bright, readable interface';

  @override
  String get language => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageHindi => 'Hindi (Hinglish)';

  @override
  String get languageSubtitle => 'App text aur voice dono ke liye';

  @override
  String get reportPdf => 'Report PDF';

  @override
  String get sharePdf => 'Share PDF';

  @override
  String get savePdf => 'Save PDF';

  @override
  String get vehicleHealth => 'Vehicle Health';

  @override
  String get billFairness => 'Bill Fairness';

  @override
  String get buildYourGarage => 'Build Your Garage';

  @override
  String get continueLabel => 'Continue';

  @override
  String get saveVehicle => 'Save Vehicle';

  @override
  String get enterVin => 'Enter VIN';

  @override
  String get vinStoredSecurely =>
      'Your full VIN is saved securely. Only the last 4 digits are shown in the app.';
}
