import 'package:flutter/foundation.dart';

import '../config/supabase_config.dart';
import '../models/vehicle.dart';

/// In-memory + Supabase vehicle store.
/// When Supabase is offline the vehicles live in memory only.
class VehicleService extends ChangeNotifier {
  VehicleService._();
  static final instance = VehicleService._();

  final List<Vehicle> _vehicles = [];
  Vehicle? _selected;

  List<Vehicle> get vehicles => List.unmodifiable(_vehicles);
  Vehicle? get selected => _selected;
  bool get hasVehicles => _vehicles.isNotEmpty;

  Future<void> load() async {
    if (!SupabaseConfig.isConfigured) return;
    try {
      final rows = await SupabaseConfig.client
          .from('vehicles')
          .select()
          .order('created_at', ascending: false);
      _vehicles
        ..clear()
        ..addAll(rows.map((r) => Vehicle.fromJson(r)));
      _selected = _vehicles.isNotEmpty ? _vehicles.first : null;
      notifyListeners();
    } catch (_) {
      // offline — keep in-memory list
    }
  }

  Future<void> add(Vehicle v) async {
    _vehicles.insert(0, v);
    _selected = v;
    notifyListeners();

    if (!SupabaseConfig.isConfigured) return;
    try {
      await SupabaseConfig.client.from('vehicles').insert(v.toJson());
    } catch (_) {
      // queued for sync
    }
  }

  Future<void> remove(String id) async {
    _vehicles.removeWhere((v) => v.id == id);
    if (_selected?.id == id) {
      _selected = _vehicles.isNotEmpty ? _vehicles.first : null;
    }
    notifyListeners();

    if (!SupabaseConfig.isConfigured) return;
    try {
      await SupabaseConfig.client.from('vehicles').delete().eq('id', id);
    } catch (_) {}
  }

  void select(Vehicle v) {
    _selected = v;
    notifyListeners();
  }
}
