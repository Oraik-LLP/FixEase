import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/ai_config.dart';
import '../models/ai_response.dart';
import '../models/diagnostic.dart';
import '../models/vehicle.dart';

/// Orchestrates AI diagnostic calls to Gemini.
/// Falls back to a heuristic-based local analysis when the API is unavailable.
class AiService {
  AiService._();
  static final instance = AiService._();

  // ── Symptom-based (urgent) diagnosis ────────────────────────────────────

  Future<AiDiagnosticResponse> analyzeSymptoms({
    required Vehicle vehicle,
    required List<String> symptoms,
    required Severity severity,
    String? description,
  }) async {
    final prompt = _buildSymptomPrompt(
      vehicle: vehicle,
      symptoms: symptoms,
      severity: severity,
      description: description,
    );

    if (!AiConfig.isConfigured) {
      return _localSymptomAnalysis(symptoms, severity);
    }

    try {
      return await _callGeminiText(prompt);
    } catch (_) {
      return _localSymptomAnalysis(symptoms, severity);
    }
  }

  // ── Photo-based diagnosis ──────────────────────────────────────────────

  Future<AiDiagnosticResponse> analyzePhotos({
    required Vehicle vehicle,
    required List<File> images,
    String? description,
  }) async {
    if (!AiConfig.isConfigured || images.isEmpty) {
      return _localPhotoFallback(description);
    }

    try {
      return await _callGeminiVision(
        vehicle: vehicle,
        images: images,
        description: description,
      );
    } catch (_) {
      return _localPhotoFallback(description);
    }
  }

  // ── Gemini text call ──────────────────────────────────────────────────

  Future<AiDiagnosticResponse> _callGeminiText(String prompt) async {
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.3,
        'maxOutputTokens': 2048,
        'responseMimeType': 'application/json',
      },
    });

    final resp = await http
        .post(
          Uri.parse(AiConfig.geminiEndpoint),
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 30));

    if (resp.statusCode != 200) {
      throw HttpException('Gemini returned ${resp.statusCode}');
    }

    return _parseGeminiResponse(resp.body);
  }

  // ── Gemini vision call ────────────────────────────────────────────────

  Future<AiDiagnosticResponse> _callGeminiVision({
    required Vehicle vehicle,
    required List<File> images,
    String? description,
  }) async {
    final parts = <Map<String, dynamic>>[
      {'text': _buildPhotoPrompt(vehicle: vehicle, description: description)},
    ];

    for (final img in images.take(4)) {
      final bytes = await img.readAsBytes();
      final b64 = base64Encode(bytes);
      final mime = img.path.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';
      parts.add({
        'inlineData': {'mimeType': mime, 'data': b64},
      });
    }

    final body = jsonEncode({
      'contents': [
        {'parts': parts},
      ],
      'generationConfig': {
        'temperature': 0.3,
        'maxOutputTokens': 2048,
        'responseMimeType': 'application/json',
      },
    });

    final resp = await http
        .post(
          Uri.parse(AiConfig.geminiVisionEndpoint),
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 45));

    if (resp.statusCode != 200) {
      throw HttpException('Gemini vision returned ${resp.statusCode}');
    }

    return _parseGeminiResponse(resp.body);
  }

  // ── Response parsing ──────────────────────────────────────────────────

  AiDiagnosticResponse _parseGeminiResponse(String responseBody) {
    final json = jsonDecode(responseBody) as Map<String, dynamic>;

    final candidates = json['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      return AiDiagnosticResponse.fallback('No response from AI');
    }

    final content = candidates[0]['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      return AiDiagnosticResponse.fallback('Empty AI response');
    }

    final text = parts[0]['text'] as String? ?? '';

    try {
      final parsed = jsonDecode(text) as Map<String, dynamic>;
      return AiDiagnosticResponse.fromJson(parsed);
    } catch (_) {
      return AiDiagnosticResponse.fallback(text);
    }
  }

  // ── Prompt builders ───────────────────────────────────────────────────

  String _buildSymptomPrompt({
    required Vehicle vehicle,
    required List<String> symptoms,
    required Severity severity,
    String? description,
  }) {
    return '''
You are FixEase, an expert automotive diagnostic AI. Analyze the following vehicle symptoms and return a JSON object.

VEHICLE:
- ${vehicle.displayName}
- Fuel: ${vehicle.fuelLabel}
- Mileage: ${vehicle.mileageKm} km
${vehicle.lastServiceDate != null ? '- Last service: ${vehicle.lastServiceDate!.day}/${vehicle.lastServiceDate!.month}/${vehicle.lastServiceDate!.year}' : '- Last service: Unknown'}

REPORTED SYMPTOMS:
${symptoms.map((s) => '- $s').join('\n')}

SEVERITY: ${severity.name}
${description != null ? '\nADDITIONAL NOTES: $description' : ''}

Return ONLY a JSON object with this exact structure:
{
  "summary": "Brief 2-3 sentence overview of the likely issue",
  "health_score": <number 0.0-10.0 where 10 is perfect health>,
  "confidence": <number 0.0-1.0 indicating confidence in diagnosis>,
  "possible_causes": ["cause1", "cause2", ...],
  "recommendations": ["action1", "action2", ...],
  "sub_scores": {"Engine": <0-10>, "Brakes": <0-10>, "Transmission": <0-10>, "Electrical": <0-10>, "Suspension": <0-10>},
  "urgency_note": "string or null — only if immediate action needed"
}
''';
  }

  String _buildPhotoPrompt({
    required Vehicle vehicle,
    String? description,
  }) {
    return '''
You are FixEase, an expert automotive diagnostic AI with computer vision. Analyze the attached vehicle photos and return a JSON diagnosis.

VEHICLE:
- ${vehicle.displayName}
- Fuel: ${vehicle.fuelLabel}
- Mileage: ${vehicle.mileageKm} km

${description != null ? 'USER DESCRIPTION: $description\n' : ''}
Examine the images for:
- Visible damage (dents, scratches, cracks)
- Fluid leaks (oil, coolant, brake fluid)
- Tire condition (tread depth, uneven wear, bulges)
- Rust or corrosion
- Worn belts, hoses, or connectors
- Dashboard warning lights
- Any other anomalies

Return ONLY a JSON object with this exact structure:
{
  "summary": "Brief 2-3 sentence overview of what you see",
  "health_score": <number 0.0-10.0 where 10 is perfect>,
  "confidence": <number 0.0-1.0 indicating how confident you are>,
  "possible_causes": ["issue1", "issue2", ...],
  "recommendations": ["action1", "action2", ...],
  "sub_scores": {"Body": <0-10>, "Tires": <0-10>, "Engine Bay": <0-10>, "Fluids": <0-10>, "Interior": <0-10>},
  "urgency_note": "string or null — only if immediate action needed"
}
''';
  }

  // ── Offline / fallback analysis ───────────────────────────────────────

  AiDiagnosticResponse _localSymptomAnalysis(
    List<String> symptoms,
    Severity severity,
  ) {
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
          'Based on $count reported symptom(s) at ${severity.name} severity, '
          'your vehicle may need professional inspection. '
          'This is an offline estimate — connect to AI for a detailed analysis.',
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
        'Visit a certified mechanic for hands-on inspection',
        if (severity == Severity.critical || severity == Severity.high)
          'Do not drive until inspected — consider towing',
        'Enable AI analysis for a more accurate diagnosis',
        if (hasEngine) 'Check engine oil level and coolant',
        if (hasBrake) 'Check brake fluid level and pad thickness',
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
    );
  }

  AiDiagnosticResponse _localPhotoFallback(String? description) {
    return AiDiagnosticResponse(
      summary: 'Photo analysis requires an active AI connection. '
          'Your images have been saved and will be analyzed once '
          'the Gemini API key is configured.'
          '${description != null ? ' You noted: "$description"' : ''}',
      healthScore: 5.0,
      confidence: 0.15,
      possibleCauses: const ['Requires AI vision model for analysis'],
      recommendations: const [
        'Configure your Gemini API key for photo analysis',
        'Visit a mechanic for visual inspection',
      ],
    );
  }
}
