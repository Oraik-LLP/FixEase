// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

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
  String get chooseDiagnosticMode => 'Diagnostic mode chunein';

  @override
  String get diagnoseSubtitle =>
      'Apni gaadi ka diagnose kaise karna hai, woh select karein.';

  @override
  String get addVehicleFirst => 'Pehle gaadi add karein';

  @override
  String get urgentOnTheSpot => 'Urgent On-the-Spot';

  @override
  String get urgentDescription =>
      'Jo problem abhi ho rahi hai uske baare mein quick questions — turant AI analysis milega.';

  @override
  String get photoBased => 'Photo se Diagnose';

  @override
  String get photoDescription =>
      'Issue ki photo upload ya click karein — AI damage, leak, tyre wear sab analyze karega.';

  @override
  String get geminiLive => 'Gemini Live';

  @override
  String get geminiLiveDescription =>
      'Camera se real-time AI diagnosis. Point karo, capture karo, Gemini se baat karo.';

  @override
  String get obdProSuite => 'OBD Pro Diagnostic Suite';

  @override
  String get obdProDescription =>
      'Bluetooth ELM327 connect karein — live vitals, ECU snapshot, idle aur drive scans.';

  @override
  String get errorCodeLookup => 'Error Code Lookup';

  @override
  String get errorCodeLookupDescription =>
      'Koi bhi OBD-II code search karein (P/C/B/U) — sab brands ke liye. P0420, C0035 ka matlab jaanein.';

  @override
  String get dtcLookupTitle => 'Error Code Lookup';

  @override
  String get dtcSearchHint => 'Koi bhi OBD-II code search karein';

  @override
  String get dtcSearchHelp =>
      'Sab gaadiyon ke liye — P (engine), C (chassis), B (body), U (network). Wildcard * use karein, jaise P04*.';

  @override
  String get lookupAnyCode => 'Koi bhi code lookup karein';

  @override
  String get storedDtcs => 'Stored DTCs';

  @override
  String get pendingDtcs => 'Pending DTCs';

  @override
  String get profileTitle => 'FixEase Driver';

  @override
  String get profileSubtitle =>
      'Guest mode · saara data is device par hi rehta hai';

  @override
  String get myVehicles => 'Meri Gaadiyan';

  @override
  String get addVehicle => 'Gaadi Add Karein';

  @override
  String get diagnosticHistory => 'Diagnosis History';

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
  String get lightThemeSubtitle => 'Bright, readable interface ke liye';

  @override
  String get language => 'Bhasha / Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageHindi => 'Hindi (Hinglish)';

  @override
  String get languageSubtitle =>
      'Ye Hinglish hai — app text aur voice dono ke liye';

  @override
  String get reportPdf => 'Report PDF';

  @override
  String get sharePdf => 'PDF Share Karein';

  @override
  String get savePdf => 'PDF Save Karein';

  @override
  String get vehicleHealth => 'Gaadi ki Health';

  @override
  String get billFairness => 'Bill Fairness';

  @override
  String get buildYourGarage => 'Apna Garage Banayein';

  @override
  String get continueLabel => 'Aage badhein';

  @override
  String get saveVehicle => 'Gaadi Save Karein';

  @override
  String get enterVin => 'VIN daalein';

  @override
  String get vinStoredSecurely =>
      'Poora VIN secure save hota hai. App mein sirf last 4 digits dikhte hain.';
}
