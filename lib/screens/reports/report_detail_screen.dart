import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/ai_response.dart';
import '../../models/diagnostic.dart';
import '../../services/diagnostic_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neuomorphic.dart';

class ReportDetailScreen extends StatelessWidget {
  const ReportDetailScreen({super.key, required this.session});
  final DiagnosticSession session;

  AiDiagnosticResponse? get _aiResponse {
    try {
      if (session.aiResponseJson != null) {
        return AiDiagnosticResponse.fromJson(session.aiResponseJson!);
      }
      if (session.aiResponse != null) {
        return AiDiagnosticResponse.fallback(session.aiResponse!);
      }
    } catch (_) {
      if (session.aiResponse != null) {
        return AiDiagnosticResponse.fallback(session.aiResponse!);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final resp = _aiResponse;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              // top bar
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
                child: Row(
                  children: [
                    FixEaseStepBackButton(
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => _confirmDelete(context),
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 20, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // header
                      _ReportHeader(session: session),
                      const SizedBox(height: 20),

                      if (resp != null) ...[
                        // health ring + badge
                        _HealthSection(response: resp),
                        const SizedBox(height: 16),

                        // sub-score bars
                        if (resp.subScores.isNotEmpty) ...[
                          _SubScoresSection(subScores: resp.subScores),
                          const SizedBox(height: 16),
                        ],

                        // radar chart for sub-scores
                        if (resp.subScores.length >= 3) ...[
                          _RadarSection(subScores: resp.subScores),
                          const SizedBox(height: 16),
                        ],

                        // urgency alert
                        if (resp.urgencyNote != null) ...[
                          _UrgencyBanner(note: resp.urgencyNote!),
                          const SizedBox(height: 16),
                        ],

                        // AI summary
                        NeuPane(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.auto_awesome_rounded,
                                      size: 18, color: AppColors.accent),
                                  const SizedBox(width: 8),
                                  Text('AI Summary', style: tt.titleMedium),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(resp.summary, style: tt.bodyMedium),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // possible causes
                        if (resp.possibleCauses.isNotEmpty) ...[
                          _CausesSection(causes: resp.possibleCauses),
                          const SizedBox(height: 16),
                        ],

                        // recommendations
                        if (resp.recommendations.isNotEmpty) ...[
                          _RecommendationsSection(
                              items: resp.recommendations),
                          const SizedBox(height: 16),
                        ],
                      ] else
                        NeuPane(
                          child: Column(
                            children: [
                              const Icon(Icons.info_outline_rounded,
                                  size: 40, color: AppColors.textTertiary),
                              const SizedBox(height: 12),
                              Text('No detailed AI data available',
                                  style: tt.bodyMedium),
                              const SizedBox(height: 4),
                              Text(
                                'This report was created before detailed '
                                'AI analysis was stored.',
                                style: tt.bodySmall,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),

                      // symptoms detail
                      if (session.symptoms.isNotEmpty) ...[
                        _SymptomsSection(symptoms: session.symptoms),
                        const SizedBox(height: 16),
                      ],

                      // metadata
                      _MetadataSection(session: session),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    HapticFeedback.mediumImpact();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Delete Report',
            style: Theme.of(ctx).textTheme.titleLarge),
        content: Text(
          'This report will be permanently deleted.',
          style: Theme.of(ctx).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              DiagnosticService.instance.delete(session.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Delete',
                style: TextStyle(color: Color(0xFFFF5252))),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Report header — vehicle name, type, date/time
// ═══════════════════════════════════════════════════════════════════════════════

class _ReportHeader extends StatelessWidget {
  const _ReportHeader({required this.session});
  final DiagnosticSession session;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final isUrgent = session.type == DiagnosticType.urgent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isUrgent
                        ? const Color(0xFFFF9800)
                        : AppColors.accent)
                    .withValues(alpha: 0.15),
              ),
              child: Icon(
                isUrgent
                    ? Icons.warning_amber_rounded
                    : Icons.camera_alt_rounded,
                color:
                    isUrgent ? const Color(0xFFFF9800) : AppColors.accent,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isUrgent ? 'Urgent Diagnosis' : 'Photo Diagnosis',
                    style: tt.headlineMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    session.vehicleName ?? 'Unknown Vehicle',
                    style: tt.bodyMedium?.copyWith(color: AppColors.accent),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.calendar_today_rounded,
                size: 13, color: AppColors.textTertiary),
            const SizedBox(width: 6),
            Text(session.dateLabel, style: tt.bodySmall),
            const SizedBox(width: 16),
            const Icon(Icons.schedule_rounded,
                size: 13, color: AppColors.textTertiary),
            const SizedBox(width: 6),
            Text(session.timeLabel, style: tt.bodySmall),
            const SizedBox(width: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: AppColors.accent.withValues(alpha: 0.12),
              ),
              child: Text(
                session.severityLabel,
                style: tt.bodySmall?.copyWith(
                  color: AppColors.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Health section — big ring + label + confidence
// ═══════════════════════════════════════════════════════════════════════════════

class _HealthSection extends StatelessWidget {
  const _HealthSection({required this.response});
  final AiDiagnosticResponse response;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return NeuPane(
      child: Row(
        children: [
          NeuProgressRing(
            progress: (response.healthScore / 10).clamp(0, 1),
            size: 100,
            label: response.healthScore.toStringAsFixed(1),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Overall Health', style: tt.titleLarge),
                const SizedBox(height: 6),
                _HealthChip(
                  label: response.healthLabel,
                  score: response.healthScore,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.verified_rounded,
                        size: 14, color: AppColors.textTertiary),
                    const SizedBox(width: 6),
                    Text(
                      'AI Confidence: ${response.confidenceLabel}',
                      style: tt.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _ConfidenceBar(confidence: response.confidence),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthChip extends StatelessWidget {
  const _HealthChip({required this.label, required this.score});
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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

class _ConfidenceBar extends StatelessWidget {
  const _ConfidenceBar({required this.confidence});
  final double confidence;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 6,
        child: LinearProgressIndicator(
          value: confidence.clamp(0, 1),
          backgroundColor: AppColors.surfaceHighlight,
          color: AppColors.accent.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Sub-scores — horizontal bar chart table
// ═══════════════════════════════════════════════════════════════════════════════

class _SubScoresSection extends StatelessWidget {
  const _SubScoresSection({required this.subScores});
  final Map<String, double> subScores;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return NeuPane(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded,
                  size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Text('Component Breakdown', style: tt.titleMedium),
            ],
          ),
          const SizedBox(height: 14),
          for (final e in subScores.entries) ...[
            _ScoreBar(label: e.key, score: e.value),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.label, required this.score});
  final String label;
  final double score;

  Color get _barColor {
    if (score >= 8) return const Color(0xFF4CAF50);
    if (score >= 6) return const Color(0xFFFFC107);
    if (score >= 4) return const Color(0xFFFF9800);
    return const Color(0xFFFF5252);
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final pct = (score / 10).clamp(0.0, 1.0);

    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label,
              style: tt.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 14,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  color: AppColors.surfaceHighlight,
                ),
              ),
              FractionallySizedBox(
                widthFactor: pct,
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    gradient: LinearGradient(
                      colors: [
                        _barColor.withValues(alpha: 0.6),
                        _barColor,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 32,
          child: Text(
            score.toStringAsFixed(1),
            style: tt.bodySmall?.copyWith(
              color: _barColor,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Radar / Spider chart for sub-scores
// ═══════════════════════════════════════════════════════════════════════════════

class _RadarSection extends StatelessWidget {
  const _RadarSection({required this.subScores});
  final Map<String, double> subScores;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return NeuPane(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.radar_rounded,
                  size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Text('Health Radar', style: tt.titleMedium),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: Center(
              child: CustomPaint(
                size: const Size(220, 220),
                painter: _RadarPainter(
                  labels: subScores.keys.toList(),
                  values: subScores.values
                      .map((v) => (v / 10).clamp(0.0, 1.0))
                      .toList(),
                  accentColor: AppColors.accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.labels,
    required this.values,
    required this.accentColor,
  });
  final List<String> labels;
  final List<double> values;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 28;
    final n = labels.length;
    final angleStep = 2 * math.pi / n;
    const startAngle = -math.pi / 2;

    // grid rings
    final gridPaint = Paint()
      ..color = const Color(0x18FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;

    for (var ring = 1; ring <= 5; ring++) {
      final rr = r * ring / 5;
      final path = Path();
      for (var i = 0; i < n; i++) {
        final a = startAngle + i * angleStep;
        final p = Offset(c.dx + rr * math.cos(a), c.dy + rr * math.sin(a));
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // axis lines
    for (var i = 0; i < n; i++) {
      final a = startAngle + i * angleStep;
      final end =
          Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      canvas.drawLine(c, end, gridPaint);
    }

    // data polygon
    final fillPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final dataPath = Path();
    for (var i = 0; i < n; i++) {
      final a = startAngle + i * angleStep;
      final v = values[i] * r;
      final p = Offset(c.dx + v * math.cos(a), c.dy + v * math.sin(a));
      if (i == 0) {
        dataPath.moveTo(p.dx, p.dy);
      } else {
        dataPath.lineTo(p.dx, p.dy);
      }
    }
    dataPath.close();
    canvas.drawPath(dataPath, fillPaint);
    canvas.drawPath(dataPath, strokePaint);

    // data dots
    final dotPaint = Paint()..color = accentColor;
    for (var i = 0; i < n; i++) {
      final a = startAngle + i * angleStep;
      final v = values[i] * r;
      final p = Offset(c.dx + v * math.cos(a), c.dy + v * math.sin(a));
      canvas.drawCircle(p, 3.5, dotPaint);
    }

    // labels
    final labelStyle = TextStyle(
      color: const Color(0x99FFFFFF),
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );
    for (var i = 0; i < n; i++) {
      final a = startAngle + i * angleStep;
      final lp = Offset(
        c.dx + (r + 18) * math.cos(a),
        c.dy + (r + 18) * math.sin(a),
      );

      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      var dx = lp.dx - tp.width / 2;
      var dy = lp.dy - tp.height / 2;

      // nudge labels that overlap
      if (a.abs() < 0.1 || (a + math.pi).abs() < 0.1) {
        // top / bottom — center horizontally
      } else if (math.cos(a) > 0) {
        dx = lp.dx;
      } else {
        dx = lp.dx - tp.width;
      }

      tp.paint(canvas, Offset(dx, dy));
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) =>
      !_listEq(old.values, values);

  bool _listEq(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Urgency banner
// ═══════════════════════════════════════════════════════════════════════════════

class _UrgencyBanner extends StatelessWidget {
  const _UrgencyBanner({required this.note});
  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0x22FF5252),
        border: Border.all(color: const Color(0x44FF5252), width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.priority_high_rounded,
              size: 20, color: Color(0xFFFF5252)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Urgency Alert',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: const Color(0xFFFF8A80),
                        )),
                const SizedBox(height: 4),
                Text(
                  note,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFFF8A80),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Possible causes table
// ═══════════════════════════════════════════════════════════════════════════════

class _CausesSection extends StatelessWidget {
  const _CausesSection({required this.causes});
  final List<String> causes;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return NeuPane(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.troubleshoot_rounded,
                  size: 18, color: Color(0xFFFF9800)),
              const SizedBox(width: 8),
              Text('Possible Causes', style: tt.titleMedium),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < causes.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(top: 1),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFF9800).withValues(alpha: 0.15),
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: tt.bodySmall?.copyWith(
                          color: const Color(0xFFFF9800),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(causes[i], style: tt.bodyMedium),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Recommendations
// ═══════════════════════════════════════════════════════════════════════════════

class _RecommendationsSection extends StatelessWidget {
  const _RecommendationsSection({required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return NeuPane(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded,
                  size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Text('Recommendations', style: tt.titleMedium),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(top: 1),
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
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(items[i], style: tt.bodyMedium),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Symptoms chips
// ═══════════════════════════════════════════════════════════════════════════════

class _SymptomsSection extends StatelessWidget {
  const _SymptomsSection({required this.symptoms});
  final List<String> symptoms;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return NeuPane(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checklist_rounded,
                  size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text('Reported Symptoms', style: tt.titleMedium),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: symptoms
                .map((s) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: AppColors.accent.withValues(alpha: 0.1),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.25),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        s,
                        style: tt.bodySmall?.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Metadata footer
// ═══════════════════════════════════════════════════════════════════════════════

class _MetadataSection extends StatelessWidget {
  const _MetadataSection({required this.session});
  final DiagnosticSession session;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return NeuPane(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Report Details', style: tt.titleSmall),
          const SizedBox(height: 8),
          _MetaRow('Report ID', session.id),
          _MetaRow('Type',
              session.type == DiagnosticType.urgent ? 'Urgent' : 'Photo'),
          _MetaRow('Severity', session.severityLabel),
          _MetaRow('Date', '${session.dateLabel} ${session.timeLabel}'),
          if (session.description != null && session.description!.isNotEmpty)
            _MetaRow('Description', session.description!),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: tt.bodySmall
                    ?.copyWith(color: AppColors.textTertiary)),
          ),
          Expanded(
            child: Text(value, style: tt.bodySmall),
          ),
        ],
      ),
    );
  }
}
