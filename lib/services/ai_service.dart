import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/ai_config.dart';
import '../models/ai_response.dart';
import '../models/diagnostic.dart';
import '../models/vehicle.dart';

/// Orchestrates AI diagnostic calls through a backend proxy.
/// Falls back to a heuristic-based local analysis when the backend is unavailable.
class AiService {
  AiService._();
  static final instance = AiService._();

  Future<AiDiagnosticResponse> analyzeSymptoms({
    required Vehicle vehicle,
    required List<String> symptoms,
    required Severity severity,
    String? description,
  }) async {
    if (!AiConfig.isConfigured) {
      return _localSymptomAnalysis(
        symptoms,
        severity,
        errorCode: 'backend_not_configured',
      );
    }

    try {
      final payload = await _postJson(
        '/api/diagnose/symptoms',
        {
          'vehicle': _vehiclePayload(vehicle),
          'symptoms': symptoms,
          'severity': severity.name,
          'description': description,
        },
      );
      return AiDiagnosticResponse.fromJson(payload);
    } catch (e) {
      return _localSymptomAnalysis(
        symptoms,
        severity,
        errorCode: _extractErrorCode(e),
      );
    }
  }

  Future<AiDiagnosticResponse> analyzePhotos({
    required Vehicle vehicle,
    required List<File> images,
    String? description,
  }) async {
    if (!AiConfig.isConfigured || images.isEmpty) {
      return _localPhotoFallback(
        description,
        errorCode: !AiConfig.isConfigured
            ? 'backend_not_configured'
            : 'missing_images',
      );
    }

    try {
      final encodedImages = <Map<String, dynamic>>[];
      for (final img in images.take(8)) {
        final bytes = await img.readAsBytes();
        encodedImages.add({
          'mime_type': img.path.toLowerCase().endsWith('.png')
              ? 'image/png'
              : 'image/jpeg',
          'data': base64Encode(bytes),
        });
      }

      final payload = await _postJson(
        '/api/diagnose/photos',
        {
          'vehicle': _vehiclePayload(vehicle),
          'images': encodedImages,
          'description': description,
        },
      );
      return AiDiagnosticResponse.fromJson(payload);
    } catch (e) {
      return _localPhotoFallback(
        description,
        errorCode: _extractErrorCode(e),
      );
    }
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final resp = await http
        .post(
          AiConfig.endpoint(path),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 90));

    final payload = resp.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(resp.body) as Map<String, dynamic>;

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return payload;
    }

    final message = payload['message'] as String? ?? 'AI request failed';
    final code = payload['error_code'] as String? ?? 'request_failed';
    throw AiRequestException(code, message);
  }

  Map<String, dynamic> _vehiclePayload(Vehicle vehicle) => {
        'display_name': vehicle.displayName,
        'fuel_label': vehicle.fuelLabel,
        'mileage_km': vehicle.mileageKm,
        'last_service_date': vehicle.lastServiceDate?.toIso8601String(),
      };

  AiDiagnosticResponse _localSymptomAnalysis(
    List<String> symptoms,
    Severity severity, {
    String? errorCode,
  }) {
    final count = symptoms.length;
    final sevMult = switch (severity) {
      Severity.low => 1.0,
      Severity.medium => 0.8,
      Severity.high => 0.55,
      Severity.critical => 0.3,
    };
    final score = (10.0 - count * 0.6).clamp(1.0, 10.0) * sevMult;

    final hasEngine = symptoms.any((s) =>
        s.toLowerCase().contains('engine') ||
        s.toLowerCase().contains('power') ||
        s.toLowerCase().contains('smoke'));
    final hasBrake = symptoms.any((s) =>
        s.toLowerCase().contains('brake') ||
        s.toLowerCase().contains('stopping'));
    final hasElectrical = symptoms.any((s) =>
        s.toLowerCase().contains('battery') ||
        s.toLowerCase().contains('light') ||
        s.toLowerCase().contains('starter'));

    return AiDiagnosticResponse(
      summary:
          'AI diagnosis is unavailable right now, so this is an on-device estimate based on your reported symptoms.',
      healthScore: double.parse(score.toStringAsFixed(1)),
      confidence: 0.35,
      possibleCauses: [
        if (hasEngine) 'Possible engine or powertrain issue',
        if (hasBrake) 'Brake system may need inspection',
        if (hasElectrical) 'Electrical system fault detected',
        if (!hasEngine && !hasBrake && !hasElectrical)
          'Multiple subsystems may be affected',
      ],
      recommendations: [
        'Check that the AI backend is running and reachable',
        'Visit a certified mechanic for hands-on inspection',
        if (severity == Severity.critical || severity == Severity.high)
          'Do not drive until inspected; consider towing',
      ],
      subScores: {
        'Engine': hasEngine ? score * 0.6 : score * 0.9,
        'Brakes': hasBrake ? score * 0.5 : score * 0.9,
        'Electrical': hasElectrical ? score * 0.55 : score * 0.85,
        'Transmission': score * 0.8,
        'Suspension': score * 0.85,
      },
      urgencyNote: severity == Severity.critical
          ? 'CRITICAL: Avoid driving this vehicle until inspected.'
          : null,
      provider: 'local',
      isFallback: true,
      errorCode: errorCode,
    );
  }

  AiDiagnosticResponse _localPhotoFallback(
    String? description, {
    String? errorCode,
  }) {
    return AiDiagnosticResponse(
      summary: 'AI photo analysis is unavailable right now, so no remote image analysis was performed.'
          '${description != null ? ' You noted: "$description"' : ''}',
      healthScore: 5.0,
      confidence: 0.15,
      possibleCauses: const ['Requires a reachable AI backend for photo analysis'],
      recommendations: const [
        'Check that the AI backend is running and reachable',
        'Visit a mechanic for visual inspection',
      ],
      provider: 'local',
      isFallback: true,
      errorCode: errorCode,
    );
  }

  String? _extractErrorCode(Object error) {
    if (error is AiRequestException) return error.code;
    return null;
  }
}

class AiRequestException implements Exception {
  const AiRequestException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}
