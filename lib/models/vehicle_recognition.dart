import 'vehicle.dart';

class VehicleSuggestion {
  const VehicleSuggestion(
      {required this.category,
      required this.make,
      required this.model,
      required this.confidence,
      this.year,
      this.fuelType});
  final VehicleCategory category;
  final String make;
  final String model;
  final int? year;
  final FuelType? fuelType;
  final double confidence;

  factory VehicleSuggestion.fromJson(Map<String, dynamic> json) =>
      VehicleSuggestion(
        category: VehicleCategory.values
                .where((v) => v.name == json['category'])
                .firstOrNull ??
            VehicleCategory.other,
        make: json['make'] as String? ?? '',
        model: json['model'] as String? ?? '',
        year: (json['year'] as num?)?.toInt(),
        fuelType: FuelType.values
            .where((v) => v.name == json['fuel_type'])
            .firstOrNull,
        confidence: ((json['confidence'] as num?)?.toDouble() ?? 0).clamp(0, 1),
      );
  String get label =>
      [category.label, make, model].where((v) => v.isNotEmpty).join(' · ');
}

class VehicleRecognition {
  const VehicleRecognition(
      {required this.candidates,
      required this.needsAnotherPhoto,
      required this.guidance});
  final List<VehicleSuggestion> candidates;
  final bool needsAnotherPhoto;
  final String guidance;
  factory VehicleRecognition.fromJson(Map<String, dynamic> json) =>
      VehicleRecognition(
        candidates: (json['candidates'] as List? ?? [])
            .whereType<Map>()
            .map((row) =>
                VehicleSuggestion.fromJson(Map<String, dynamic>.from(row)))
            .take(3)
            .toList(),
        needsAnotherPhoto: json['needs_another_photo'] == true,
        guidance: json['guidance'] as String? ??
            'Confirm the suggestion, type details, or skip for now.',
      );
}
