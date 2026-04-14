import 'package:supabase_flutter/supabase_flutter.dart';

abstract final class SupabaseConfig {
  // ──────────────────────────────────────────────────────────────────────
  // Replace with your own project credentials from supabase.com/dashboard
  // ──────────────────────────────────────────────────────────────────────
  static const _url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://YOUR_PROJECT.supabase.co',
  );
  static const _anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'YOUR_ANON_KEY',
  );

  static bool get isConfigured =>
      !_url.contains('YOUR_PROJECT') && !_anonKey.contains('YOUR_ANON_KEY');

  static Future<void> init() async {
    if (!isConfigured) return;
    await Supabase.initialize(url: _url, anonKey: _anonKey);
  }

  static SupabaseClient get client => Supabase.instance.client;
}
