import 'package:flutter/material.dart';

import 'local_store_service.dart';

/// Controls Gemini report language only — app UI stays English.
class LocaleService extends ChangeNotifier {
  LocaleService._();
  static final instance = LocaleService._();

  static const _key = 'report_language';
  static const _legacyKey = 'app_locale';

  bool _hindiReports = false;

  /// Always English — kept for callers that still read a Flutter locale.
  Locale get locale => const Locale('en');

  bool get hindiReports => _hindiReports;

  /// Whether AI reports should be generated in Hindi/Hinglish.
  bool get isHindi => _hindiReports;

  /// Sent to backend: `en` or `hi`.
  String get reportLanguageCode => _hindiReports ? 'hi' : 'en';

  /// TTS when reading Hindi report content aloud.
  String get ttsLanguage => _hindiReports ? 'hi-IN' : 'en-US';

  Future<void> init() async {
    await LocalStoreService.init();
    final stored = LocalStoreService.prefs.getString(_key);
    if (stored == 'hi') {
      _hindiReports = true;
      return;
    }
    if (stored == 'en') {
      _hindiReports = false;
      return;
    }
    // Migrate older builds that stored UI locale.
    final legacy = LocalStoreService.prefs.getString(_legacyKey);
    _hindiReports = legacy == 'hi';
  }

  Future<void> setHindiReports(bool enabled) async {
    if (_hindiReports == enabled) return;
    _hindiReports = enabled;
    await LocalStoreService.prefs.setString(
      _key,
      enabled ? 'hi' : 'en',
    );
    notifyListeners();
  }

  Future<void> setEnglish() => setHindiReports(false);

  Future<void> setHindi() => setHindiReports(true);
}
