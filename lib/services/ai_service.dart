import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../config/ai_config.dart';
import '../models/ai_response.dart';
import '../models/conversation.dart';
import '../models/diagnostic.dart';
import '../models/vehicle.dart';

/// Orchestrates AI diagnostic calls through a backend proxy.
/// Falls back to a heuristic-based local analysis when the backend is unavailable.
class AiService {
  AiService._();
  static final instance = AiService._();
  static const _retryDelay = Duration(seconds: 5);

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
      final payload = await _postJsonWithRetry(
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
      final payload = await _postJsonWithRetry(
        '/api/diagnose/photos',
        {
          'vehicle': _vehiclePayload(vehicle),
          'images': await _encodeFiles(images.take(8).toList()),
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

  Future<AiDiagnosticResponse> analyzeInvoiceAudit({
    required Vehicle vehicle,
    required File document,
    String? purpose,
  }) async {
    if (!AiConfig.isConfigured) {
      return _localInvoiceAuditFallback(
        purpose,
        errorCode: 'backend_not_configured',
      );
    }

    try {
      final payload = await _postJsonWithRetry(
        '/api/diagnose/invoice-audit',
        {
          'vehicle': _vehiclePayload(vehicle),
          'documents': await _encodeFiles([document]),
          'purpose': purpose,
        },
      );
      return AiDiagnosticResponse.fromJson(payload);
    } catch (e) {
      return _localInvoiceAuditFallback(
        purpose,
        errorCode: _extractErrorCode(e),
      );
    }
  }

  Future<ConversationAiResponse> continueConversation({
    Vehicle? vehicle,
    required DiagnosticSession session,
    required List<ConversationMessage> history,
    String? message,
    File? audioFile,
    File? attachment,
  }) async {
    if (!AiConfig.isConfigured) {
      return const ConversationAiResponse(
        text: 'The AI backend is not configured right now, so I cannot continue this conversation yet.',
        provider: 'local',
        isFallback: true,
        errorCode: 'backend_not_configured',
      );
    }

    try {
      final body = <String, dynamic>{
        'vehicle': _conversationVehiclePayload(vehicle, session),
        'session_context': _conversationSessionContext(session),
        'history': history
            .map(
              (item) => {
                'role': item.role.name,
                'text': item.previewText,
                'source': item.source.name,
              },
            )
            .toList(),
      };

      if (message != null && message.trim().isNotEmpty) {
        body['message'] = message.trim();
      }

      if (audioFile != null) {
        final audioBytes = await audioFile.readAsBytes();
        body['audio'] = {
          'data': base64Encode(audioBytes),
          'mimeType': 'audio/wav',
        };
      }

      if (attachment != null) {
        final encoded = await _encodeFiles([attachment]);
        if (encoded.isNotEmpty) {
          body['attachment'] = encoded.first;
        }
      }

      final payload = await _postJsonWithRetry('/api/conversations/respond', body);
      return ConversationAiResponse.fromJson(payload);
    } catch (e) {
      return ConversationAiResponse(
        text: 'I could not continue the conversation right now. Please try again.',
        provider: 'local',
        isFallback: true,
        errorCode: _extractErrorCode(e),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _encodeFiles(List<File> files) async {
    final encoded = <Map<String, dynamic>>[];
    for (final file in files) {
      final bytes = await _readPayloadBytes(file);
      final encodedAsJpeg = _isCompressibleImage(file.path);
      encoded.add({
        'name': encodedAsJpeg
            ? p.setExtension(p.basename(file.path), '.jpg')
            : p.basename(file.path),
        'mime_type': encodedAsJpeg ? 'image/jpeg' : _mimeTypeForPath(file.path),
        'data': base64Encode(bytes),
      });
    }
    return encoded;
  }

  Future<Uint8List> _readPayloadBytes(File file) async {
    if (_isCompressibleImage(file.path)) {
      final compressed = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minWidth: 1920,
        minHeight: 1080,
        quality: 85,
        format: CompressFormat.jpeg,
      );
      if (compressed != null && compressed.isNotEmpty) {
        return compressed;
      }
    }
    return await file.readAsBytes();
  }

  bool _isCompressibleImage(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.heic');
  }

  String _mimeTypeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
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

  Future<Map<String, dynamic>> _postJsonWithRetry(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      return await _postJson(path, body);
    } catch (_) {
      await Future<void>.delayed(_retryDelay);
      return _postJson(path, body);
    }
  }

  Map<String, dynamic> _vehiclePayload(Vehicle vehicle) => {
        'display_name': vehicle.displayName,
        'fuel_label': vehicle.fuelLabel,
        'mileage_km': vehicle.mileageKm,
        'last_service_date': vehicle.lastServiceDate?.toIso8601String(),
      };

  Map<String, dynamic> _conversationVehiclePayload(
    Vehicle? vehicle,
    DiagnosticSession session,
  ) =>
      {
        'display_name': vehicle?.displayName ?? session.vehicleName ?? 'Unknown vehicle',
        'fuel_label': vehicle?.fuelLabel ?? 'Unknown',
        'mileage_km': vehicle?.mileageKm ?? 0,
        'last_service_date': vehicle?.lastServiceDate?.toIso8601String(),
      };

  Map<String, dynamic> _conversationSessionContext(DiagnosticSession session) => {
        'session_id': session.id,
        'session_type': session.type.name,
        'session_title': session.typeTitle,
        'vehicle_name': session.vehicleName,
        'created_at': session.createdAt.toIso8601String(),
        'severity': session.severity.name,
        'description': session.description,
        'symptoms': session.symptoms,
        'image_urls': session.imageUrls,
        'diagnosis_summary': session.aiResponse,
        'diagnosis_json': session.aiResponseJson,
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
      summary:
          'AI photo analysis is unavailable right now, so no remote image analysis was performed.'
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

  AiDiagnosticResponse _localInvoiceAuditFallback(
    String? purpose, {
    String? errorCode,
  }) {
    return AiDiagnosticResponse(
      summary:
          'Invoice auditing is unavailable right now, so this is only a limited on-device fallback.'
          '${purpose != null && purpose.isNotEmpty ? ' Visit purpose: "$purpose".' : ''}',
      healthScore: 5.0,
      confidence: 0.1,
      verdict: 'Mixed',
      topFlags: const [
        'Could not run Gemini invoice extraction',
        'Audit may be partial because the bill was not analyzed remotely',
      ],
      recommendations: const [
        'Retry once the AI backend is reachable',
        'Ask the shop for a written estimate with parts, labor, and fees separated',
        'Get a second opinion before approving major repairs',
      ],
      questionsToAsk: const [
        'Can you break down parts, labor hours, and fees separately?',
        'Was diagnostic time billed anywhere else on this invoice?',
        'What evidence supports each recommended repair?',
      ],
      limitations:
          'This fallback did not read the uploaded invoice document, so confidence is very low.',
      partialAudit: true,
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
