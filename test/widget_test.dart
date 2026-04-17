import 'package:flutter_test/flutter_test.dart';

import 'package:fixease/main.dart';
import 'package:fixease/models/ai_response.dart';
import 'package:fixease/models/diagnostic.dart';
import 'package:fixease/models/vehicle.dart';
import 'package:fixease/services/subscription_service.dart';

void main() {
  group('App launch', () {
    testWidgets('FixEase app loads and shows splash', (tester) async {
      await tester.pumpWidget(const FixEaseApp());
      expect(find.text('FixEase'), findsWidgets);
      expect(find.text('AI Car Diagnostics'), findsOneWidget);
      // Drain the splash timer so the framework doesn't complain
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });
  });

  group('Vehicle model', () {
    test('Vehicle serialization round-trip', () {
      final v = Vehicle(
        id: 'test-1',
        make: 'Honda',
        model: 'Civic',
        year: 2024,
        variant: 'EX',
        fuelType: FuelType.petrol,
        mileageKm: 15000,
      );
      final json = v.toJson();
      final v2 = Vehicle.fromJson(json);
      expect(v2.id, 'test-1');
      expect(v2.make, 'Honda');
      expect(v2.model, 'Civic');
      expect(v2.year, 2024);
      expect(v2.variant, 'EX');
      expect(v2.fuelType, FuelType.petrol);
      expect(v2.mileageKm, 15000);
      expect(v2.displayName, '2024 Honda Civic EX');
    });

    test('Vehicle displayName without variant', () {
      final v = Vehicle(id: 'x', make: 'BMW', model: 'X5', year: 2023);
      expect(v.displayName, '2023 BMW X5');
    });

    test('VehicleData has Indian brands', () {
      expect(VehicleData.makes, contains('Maruti Suzuki'));
      expect(VehicleData.makes, contains('Tata'));
      expect(VehicleData.makes, contains('Mahindra'));
    });

    test('VehicleData.modelsFor returns models', () {
      final models = VehicleData.modelsFor('Honda');
      expect(models, isNotEmpty);
      expect(models, contains('Civic'));
      expect(models, contains('BR-V'));
    });

    test('VehicleData.modelsFor unknown brand returns generic', () {
      final models = VehicleData.modelsFor('UnknownBrand');
      expect(models, contains('Sedan'));
      expect(models, contains('SUV'));
    });
  });

  group('Diagnostic model', () {
    test('DiagnosticSession serialization round-trip', () {
      final s = DiagnosticSession(
        id: 'diag-1',
        vehicleId: 'v-1',
        type: DiagnosticType.urgent,
        symptoms: ['Engine misfiring', 'Rough idle'],
        severity: Severity.high,
        description: 'Car shaking',
        healthScore: 4.5,
        vehicleName: '2024 Honda Civic',
      );
      final json = s.toJson();
      final s2 = DiagnosticSession.fromJson(json);
      expect(s2.id, 'diag-1');
      expect(s2.type, DiagnosticType.urgent);
      expect(s2.symptoms.length, 2);
      expect(s2.severity, Severity.high);
      expect(s2.healthScore, 4.5);
      expect(s2.vehicleName, '2024 Honda Civic');
    });

    test('severityLabel returns correct labels', () {
      for (final s in Severity.values) {
        final session = DiagnosticSession(
          id: 'x', vehicleId: 'v', type: DiagnosticType.urgent, severity: s,
        );
        expect(session.severityLabel.isNotEmpty, true);
      }
    });

    test('dateLabel and timeLabel format correctly', () {
      final s = DiagnosticSession(
        id: 'x',
        vehicleId: 'v',
        type: DiagnosticType.photo,
        createdAt: DateTime(2026, 4, 14, 15, 30),
      );
      expect(s.dateLabel, '14 Apr 2026');
      expect(s.timeLabel, '15:30');
    });
  });

  group('AI Response model', () {
    test('fromJson parses correctly', () {
      final json = {
        'summary': 'Test summary',
        'health_score': 7.5,
        'confidence': 0.85,
        'possible_causes': ['Cause A', 'Cause B'],
        'recommendations': ['Fix X'],
        'sub_scores': {'Engine': 8.0, 'Brakes': 6.5},
        'urgency_note': 'Check soon',
        'provider': 'gemini',
        'is_fallback': false,
        'error_code': null,
      };
      final r = AiDiagnosticResponse.fromJson(json);
      expect(r.summary, 'Test summary');
      expect(r.healthScore, 7.5);
      expect(r.confidence, 0.85);
      expect(r.possibleCauses.length, 2);
      expect(r.subScores['Engine'], 8.0);
      expect(r.urgencyNote, 'Check soon');
      expect(r.provider, 'gemini');
      expect(r.isFallback, false);
      expect(r.healthLabel, 'Fair');
      expect(r.confidenceLabel, '85%');
    });

    test('fromJson handles missing fields gracefully', () {
      final r = AiDiagnosticResponse.fromJson({});
      expect(r.summary, '');
      expect(r.healthScore, 5.0);
      expect(r.confidence, 0.5);
      expect(r.possibleCauses, isEmpty);
      expect(r.subScores, isEmpty);
      expect(r.provider, 'local');
      expect(r.isFallback, false);
    });

    test('subScores parsing handles string values', () {
      final json = {
        'summary': 'test',
        'health_score': 5,
        'confidence': 0.5,
        'sub_scores': {'Engine': '7.5', 'Brakes': 'bad', 'Tires': 9},
      };
      final r = AiDiagnosticResponse.fromJson(json);
      expect(r.subScores['Engine'], 7.5);
      expect(r.subScores.containsKey('Brakes'), false);
      expect(r.subScores['Tires'], 9.0);
    });

    test('fallback factory creates valid response', () {
      final r = AiDiagnosticResponse.fallback('Raw text here');
      expect(r.healthScore, 5.0);
      expect(r.confidence, 0.3);
      expect(r.rawText, 'Raw text here');
      expect(r.provider, 'local');
      expect(r.isFallback, true);
      expect(r.errorCode, 'parse_failed');
    });

    test('healthLabel categories', () {
      expect(AiDiagnosticResponse(
        summary: '', healthScore: 9, confidence: 1,
      ).healthLabel, 'Good');
      expect(AiDiagnosticResponse(
        summary: '', healthScore: 7, confidence: 1,
      ).healthLabel, 'Fair');
      expect(AiDiagnosticResponse(
        summary: '', healthScore: 5, confidence: 1,
      ).healthLabel, 'Needs Attention');
      expect(AiDiagnosticResponse(
        summary: '', healthScore: 2, confidence: 1,
      ).healthLabel, 'Critical');
    });
  });

  group('Subscription service', () {
    test('Plans are correctly defined', () {
      expect(SubscriptionService.plans.length, 3);
      expect(SubscriptionService.plans[0].tier, SubscriptionTier.free);
      expect(SubscriptionService.plans[1].tier, SubscriptionTier.premium);
      expect(SubscriptionService.plans[2].tier, SubscriptionTier.pro);
    });

    test('Free plan limits', () {
      final free = SubscriptionService.plans[0].limits;
      expect(free.diagnosticsPerMonth, 3);
      expect(free.photosPerDiagnosis, 2);
      expect(free.hasRadarChart, false);
      expect(free.hasGeminiLive, false);
    });

    test('Pro plan has all features', () {
      final pro = SubscriptionService.plans[2].limits;
      expect(pro.hasRadarChart, true);
      expect(pro.hasGeminiLive, true);
      expect(pro.hasExportPdf, true);
      expect(pro.hasPrioritySupport, true);
      expect(pro.hasMultiVehicle, true);
    });

    test('Default tier is free', () {
      expect(SubscriptionService.instance.tier, SubscriptionTier.free);
      expect(SubscriptionService.instance.tierLabel, 'Free');
    });
  });
}
