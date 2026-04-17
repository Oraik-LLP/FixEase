import 'package:flutter/foundation.dart';

import '../models/diagnostic.dart';
import 'local_store_service.dart';

/// Manages diagnostic sessions on-device.
class DiagnosticService extends ChangeNotifier {
  DiagnosticService._();
  static final instance = DiagnosticService._();
  static const _storageKey = 'diagnostics.v1';

  final List<DiagnosticSession> _sessions = [];

  List<DiagnosticSession> get sessions => List.unmodifiable(_sessions);

  List<DiagnosticSession> sessionsForVehicle(String vehicleId) =>
      _sessions.where((s) => s.vehicleId == vehicleId).toList();

  Future<void> load() async {
    final rows = LocalStoreService.readJsonList(_storageKey);
    _sessions
      ..clear()
      ..addAll(rows.map(DiagnosticSession.fromJson));
    notifyListeners();
  }

  Future<void> save(DiagnosticSession s) async {
    _sessions.insert(0, s);
    notifyListeners();
    await _persist();
  }

  Future<void> delete(String id) async {
    _sessions.removeWhere((s) => s.id == id);
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() {
    return LocalStoreService.writeJsonList(
      _storageKey,
      _sessions.map((s) => s.toJson()).toList(),
    );
  }
}
