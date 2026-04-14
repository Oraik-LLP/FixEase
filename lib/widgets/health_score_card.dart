import 'package:flutter/material.dart';

import '../models/ai_response.dart';
import '../theme/app_theme.dart';
import 'neuomorphic.dart';

/// Full diagnostic result card — health ring + sub-scores + recommendations.
class DiagnosticResultCard extends StatelessWidget {
  const DiagnosticResultCard({super.key, required this.response});
  final AiDiagnosticResponse response;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Health score + confidence ──
        NeuPane(
          child: Column(
            children: [
              Row(
                children: [
                  NeuProgressRing(
                    progress: (response.healthScore / 10).clamp(0, 1),
                    size: 96,
                    label: response.healthScore.toStringAsFixed(1),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Vehicle Health', style: tt.titleLarge),
                        const SizedBox(height: 4),
                        _HealthBadge(label: response.healthLabel, score: response.healthScore),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.verified_rounded,
                                size: 14, color: AppColors.textTertiary),
                            const SizedBox(width: 4),
                            Text(
                              'Confidence: ${response.confidenceLabel}',
                              style: tt.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (response.urgencyNote != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0x22FF5252),
                    border: Border.all(
                      color: const Color(0x44FF5252),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.priority_high_rounded,
                          size: 18, color: Color(0xFFFF5252)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          response.urgencyNote!,
                          style: tt.bodySmall?.copyWith(
                            color: const Color(0xFFFF8A80),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Summary ──
        NeuPane(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AI Summary', style: tt.titleMedium),
              const SizedBox(height: 8),
              Text(response.summary, style: tt.bodyMedium),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Sub-scores ──
        if (response.subScores.isNotEmpty) ...[
          NeuPane(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Component Scores', style: tt.titleMedium),
                const SizedBox(height: 12),
                for (final e in response.subScores.entries) ...[
                  _SubScoreRow(label: e.key, score: e.value),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // ── Possible causes ──
        if (response.possibleCauses.isNotEmpty) ...[
          NeuPane(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Possible Causes', style: tt.titleMedium),
                const SizedBox(height: 8),
                for (final c in response.possibleCauses)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Icon(Icons.circle,
                              size: 6, color: AppColors.accent),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(c, style: tt.bodyMedium),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // ── Recommendations ──
        if (response.recommendations.isNotEmpty)
          NeuPane(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Recommendations', style: tt.titleMedium),
                const SizedBox(height: 8),
                for (var i = 0; i < response.recommendations.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accent.withValues(alpha: 0.15),
                          ),
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: tt.bodySmall?.copyWith(
                                color: AppColors.accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            response.recommendations[i],
                            style: tt.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _HealthBadge extends StatelessWidget {
  const _HealthBadge({required this.label, required this.score});
  final String label;
  final double score;

  Color get _color {
    if (score >= 8) return const Color(0xFF4CAF50);
    if (score >= 6) return const Color(0xFFFFC107);
    if (score >= 4) return const Color(0xFFFF9800);
    return const Color(0xFFFF5252);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: _color.withValues(alpha: 0.18),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _SubScoreRow extends StatelessWidget {
  const _SubScoreRow({required this.label, required this.score});
  final String label;
  final double score;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final pct = (score / 10).clamp(0.0, 1.0);

    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: tt.bodySmall),
        ),
        Expanded(child: NeuSlider(value: pct)),
        const SizedBox(width: 8),
        SizedBox(
          width: 30,
          child: Text(
            score.toStringAsFixed(1),
            style: tt.bodySmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
