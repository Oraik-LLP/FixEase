import 'package:flutter/foundation.dart';

import '../config/supabase_config.dart';
import '../models/diagnostic.dart';

/// Manages diagnostic sessions — local-first with Supabase sync.
class DiagnosticService extends ChangeNotifier {
  DiagnosticService._();
  static final instance = DiagnosticService._();

  final List<DiagnosticSession> _sessions = [];

  List<DiagnosticSession> get sessions => List.unmodifiable(_sessions);

  List<DiagnosticSession> sessionsForVehicle(String vehicleId) =>
      _sessions.where((s) => s.vehicleId == vehicleId).toList();

  Future<void> load() async {
    if (!SupabaseConfig.isConfigured) return;
    try {
      final rows = await SupabaseConfig.client
          .from('diagnostics')
          .select()
          .order('created_at', ascending: false);
      _sessions
        ..clear()
        ..addAll(rows.map((r) => DiagnosticSession.fromJson(r)));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> save(DiagnosticSession s) async {
    _sessions.insert(0, s);
    notifyListeners();

    if (!SupabaseConfig.isConfigured) return;
    try {
      await SupabaseConfig.client.from('diagnostics').insert(s.toJson());
    } catch (_) {}
  }

  Future<void> delete(String id) async {
    _sessions.removeWhere((s) => s.id == id);
    notifyListeners();

    if (!SupabaseConfig.isConfigured) return;
    try {
      await SupabaseConfig.client.from('diagnostics').delete().eq('id', id);
    } catch (_) {}
  }
}
