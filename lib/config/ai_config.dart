/// Configuration for AI providers.
/// Pass your key at build time:
///   flutter run --dart-define=GEMINI_API_KEY=xxx
abstract final class AiConfig {
  static const geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  static bool get isConfigured => geminiApiKey.isNotEmpty;

  static const geminiModel = 'gemini-2.0-flash';

  static String get geminiEndpoint =>
      'https://generativelanguage.googleapis.com/v1beta/models/$geminiModel:generateContent?key=$geminiApiKey';

  static String get geminiVisionEndpoint => geminiEndpoint;
}
