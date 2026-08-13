import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/ai_config.dart';
import '../models/vehicle.dart';
import '../utils/vin_utils.dart';
import 'device_identity_service.dart';

class VehicleSyncResult {
  const VehicleSyncResult({this.vehicleId, this.errorMessage});

  final String? vehicleId;
  final String? errorMessage;

  bool get isSuccess => vehicleId != null && errorMessage == null;
}

/// Syncs consumer garage vehicles (with VIN) to the FixEase backend.
abstract final class VehicleSyncService {
  static Future<VehicleSyncResult> saveVehicle(Vehicle vehicle) async {
    final vin = vehicle.vin;
    if (vin == null || !VinUtils.isValid(vin)) {
      return const VehicleSyncResult(
        errorMessage: 'Valid 17-character VIN required',
      );
    }
    if (!AiConfig.isConfigured) {
      return const VehicleSyncResult(errorMessage: 'Backend URL not configured');
    }
    final deviceId = await DeviceIdentityService.getDeviceId();
    if (deviceId == null || deviceId.isEmpty) {
      return const VehicleSyncResult(errorMessage: 'Device ID unavailable');
    }

    try {
      final response = await http
          .post(
            AiConfig.endpoint('/api/vehicles'),
            headers: {
              'Content-Type': 'application/json',
              'x-fixease-device-id': deviceId,
            },
            body: jsonEncode({
              'id': vehicle.id,
              'vin': VinUtils.normalize(vin),
              'make': vehicle.make,
              'model': vehicle.model,
              'year': vehicle.year,
              'variant': vehicle.variant,
              'fuel_type': vehicle.fuelType.name,
              'mileage_km': vehicle.mileageKm,
              'source': 'consumer_app',
            }),
          )
          .timeout(const Duration(seconds: 8));

      Map<String, dynamic>? json;
      try {
        json = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return VehicleSyncResult(
          errorMessage: 'Invalid server response (${response.statusCode})',
        );
      }

      if (response.statusCode != 201) {
        return VehicleSyncResult(
          errorMessage: json['message'] as String? ??
              'Save failed (${response.statusCode})',
        );
      }

      final saved = json['vehicle'];
      if (saved is Map) {
        final id = (saved['id'] as String?)?.trim();
        if (id != null && id.isNotEmpty) {
          return VehicleSyncResult(vehicleId: id);
        }
      }

      return const VehicleSyncResult(errorMessage: 'No vehicle id returned');
    } on TimeoutException {
      return const VehicleSyncResult(
        errorMessage: 'Cloud sync timed out',
      );
    }
  }
}
