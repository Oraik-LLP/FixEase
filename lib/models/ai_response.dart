/// Structured response parsed from Gemini's output.
class AiDiagnosticResponse {
  const AiDiagnosticResponse({
    required this.summary,
    required this.healthScore,
    required this.confidence,
    this.possibleCauses = const [],
    this.recommendations = const [],
    this.subScores = const {},
    this.urgencyNote,
    this.rawText,
    this.provider = 'local',
    this.isFallback = false,
    this.errorCode,
  });

  final String summary;

  /// 0.0 – 10.0
  final double healthScore;

  /// 0.0 – 1.0
  final double confidence;

  final List<String> possibleCauses;
  final List<String> recommendations;

  /// e.g. {"Engine": 7.2, "Brakes": 5.5}
  final Map<String, double> subScores;

  final String? urgencyNote;
  final String? rawText;
  final String provider;
  final bool isFallback;
  final String? errorCode;

  String get healthLabel {
    if (healthScore >= 8) return 'Good';
    if (healthScore >= 6) return 'Fair';
    if (healthScore >= 4) return 'Needs Attention';
    return 'Critical';
  }

  String get confidenceLabel => '${(confidence * 100).round()}%';

  Map<String, dynamic> toJson() => {
        'summary': summary,
        'health_score': healthScore,
        'confidence': confidence,
        'possible_causes': possibleCauses,
        'recommendations': recommendations,
        'sub_scores': subScores,
        'urgency_note': urgencyNote,
        'provider': provider,
        'is_fallback': isFallback,
        'error_code': errorCode,
      };

  factory AiDiagnosticResponse.fromJson(Map<String, dynamic> j) =>
      AiDiagnosticResponse(
        summary: j['summary'] as String? ?? '',
        healthScore: (j['health_score'] as num?)?.toDouble() ?? 5.0,
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0.5,
        possibleCauses:
            (j['possible_causes'] as List?)?.cast<String>() ?? [],
        recommendations:
            (j['recommendations'] as List?)?.cast<String>() ?? [],
        subScores: _parseSubScores(j['sub_scores']),
        urgencyNote: j['urgency_note'] as String?,
        provider: j['provider'] as String? ?? 'local',
        isFallback: j['is_fallback'] as bool? ?? false,
        errorCode: j['error_code'] as String?,
      );

  static Map<String, double> _parseSubScores(dynamic raw) {
    if (raw is! Map) return {};
    final result = <String, double>{};
    for (final entry in raw.entries) {
      final key = entry.key?.toString();
      if (key == null) continue;
      final val = entry.value;
      if (val is num) {
        result[key] = val.toDouble();
      } else if (val is String) {
        final parsed = double.tryParse(val);
        if (parsed != null) result[key] = parsed;
      }
    }
    return result;
  }

  factory AiDiagnosticResponse.fallback(String rawText) =>
      AiDiagnosticResponse(
        summary: rawText.length > 300 ? '${rawText.substring(0, 300)}…' : rawText,
        healthScore: 5.0,
        confidence: 0.3,
        possibleCauses: const ['Unable to parse structured response'],
        recommendations: const ['Please consult a mechanic for verification'],
        rawText: rawText,
        provider: 'local',
        isFallback: true,
        errorCode: 'parse_failed',
      );
}
