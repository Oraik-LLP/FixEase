import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// Wraps Supabase Auth, exposing a [ValueNotifier] that the UI can listen to.
/// Falls back to a local guest mode when Supabase isn't configured.
class AuthService extends ChangeNotifier {
  AuthService._();
  static final instance = AuthService._();

  StreamSubscription<AuthState>? _sub;
  User? _user;
  bool _loading = false;

  User? get user => _user;
  bool get isSignedIn => _user != null;
  bool get loading => _loading;
  String get displayName {
    final meta = _user?.userMetadata?['display_name'] as String?;
    if (meta != null && meta.isNotEmpty) return meta;
    final emailPart = _user?.email?.split('@').first;
    if (emailPart != null && emailPart.isNotEmpty) return emailPart;
    return 'Guest';
  }

  void init() {
    if (!SupabaseConfig.isConfigured) return;
    _user = SupabaseConfig.client.auth.currentUser;
    _sub = SupabaseConfig.client.auth.onAuthStateChange.listen((data) {
      _user = data.session?.user;
      notifyListeners();
    });
  }

  Future<String?> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    if (!SupabaseConfig.isConfigured) return 'Supabase not configured';
    _loading = true;
    notifyListeners();
    try {
      await SupabaseConfig.client.auth.signUp(
        email: email,
        password: password,
        data: displayName != null ? {'display_name': displayName} : null,
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    if (!SupabaseConfig.isConfigured) return 'Supabase not configured';
    _loading = true;
    notifyListeners();
    try {
      await SupabaseConfig.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    if (!SupabaseConfig.isConfigured) return;
    await SupabaseConfig.client.auth.signOut();
    _user = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
