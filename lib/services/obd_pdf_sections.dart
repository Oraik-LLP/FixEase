import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/dtc_database.dart';
import '../models/obd.dart';
import '../services/obd_processing_service.dart';

/// Builds OBD-specific PDF sections (telemetry tables + line charts).
abstract final class ObdPdfSections {
  static List<pw.Widget> build(ObdScanRecord record) {
    DtcDatabase.ensureInitialized();
    return [
      _scanOverview(record),
      if (record.staticSnapshot.hasAnyData) _staticSnapshot(record.staticSnapshot),
      if (record.kind == ObdScanKind.idle && record.processedScan.idleStats.isNotEmpty)
        _idleStatsSection(record.processedScan.idleStats),
      if (record.kind == ObdScanKind.drive &&
          record.processedScan.timelineSummary.isNotEmpty)
        _driveSummarySection(record.processedScan.timelineSummary),
      if (record.kind == ObdScanKind.drive &&
          record.processedScan.driveTimeline.isNotEmpty)
        ..._driveCharts(record.processedScan.driveTimeline),
    ];
  }

  static pw.Widget _scanOverview(ObdScanRecord record) {
    return _section('OBD Scan Overview', [
      _detailRow('Scan Type', record.kind.name.toUpperCase()),
      _detailRow('Status', record.isPartial ? 'Partial' : 'Complete'),
      _detailRow(
        'Duration',
        '${record.capturedDurationSeconds}s / ${record.targetDurationSeconds}s',
      ),
      _detailRow('Completion', _completionLabel(record.completionReason)),
      _detailRow('Samples', '${record.processedScan.sampleCount}'),
    ]);
  }

  static pw.Widget _staticSnapshot(ObdStaticSnapshot snapshot) {
    final children = <pw.Widget>[];
    if (snapshot.vin?.trim().isNotEmpty == true) {
      children.add(_detailRow('VIN', snapshot.vin!.trim()));
    }
    if (snapshot.controlModuleVoltage != null) {
      children.add(_detailRow(
        'Module Voltage',
        '${snapshot.controlModuleVoltage!.toStringAsFixed(2)} V',
      ));
    }
    if (snapshot.distanceSinceCodesClearedKm != null) {
      children.add(_detailRow(
        'Distance Since Clear',
        '${snapshot.distanceSinceCodesClearedKm} km',
      ));
    }
    if (snapshot.ambientAirTempC != null) {
      children.add(_detailRow(
        'Ambient Air',
        '${snapshot.ambientAirTempC!.toStringAsFixed(1)} C',
      ));
    }
    if (snapshot.storedDtcs.isNotEmpty) {
      children.add(pw.SizedBox(height: 8));
      children.add(pw.Text('Stored DTCs', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)));
      children.addAll(snapshot.storedDtcs.map(_dtcRow));
    }
    if (snapshot.pendingDtcs.isNotEmpty) {
      children.add(pw.SizedBox(height: 8));
      children.add(pw.Text('Pending DTCs', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)));
      children.addAll(snapshot.pendingDtcs.map(_dtcRow));
    }
    return _section('Static ECU Snapshot', children);
  }

  static pw.Widget _dtcRow(String code) {
    final info = DtcDatabase.get(code);
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(code, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(info?.description ?? 'Unknown code — check service manual'),
        ],
      ),
    );
  }

  static pw.Widget _idleStatsSection(Map<String, ObdMetricStats> stats) {
    return _section(
      'Idle Scan Metrics',
      [
        pw.TableHelper.fromTextArray(
          headers: ['Metric', 'Min', 'Avg', 'Max', 'Samples'],
          data: stats.entries.map((entry) {
            final label = ObdMetricCatalog.labels[entry.key] ?? entry.key;
            final unit = ObdMetricCatalog.units[entry.key] ?? '';
            final s = entry.value;
            return [
              label,
              '${s.minimum.toStringAsFixed(1)} $unit',
              '${s.average.toStringAsFixed(1)} $unit',
              '${s.maximum.toStringAsFixed(1)} $unit',
              '${s.sampleCount}',
            ];
          }).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellAlignment: pw.Alignment.centerLeft,
        ),
        pw.SizedBox(height: 12),
        ...stats.entries.take(4).map((entry) => _statsBarChart(entry.key, entry.value)),
      ],
    );
  }

  static pw.Widget _driveSummarySection(Map<String, ObdMetricStats> summary) {
    return _section(
      'Drive Scan Summary',
      [
        pw.TableHelper.fromTextArray(
          headers: ['Metric', 'Min', 'Avg', 'Max'],
          data: summary.entries.map((entry) {
            final label = ObdMetricCatalog.labels[entry.key] ?? entry.key;
            final unit = ObdMetricCatalog.units[entry.key] ?? '';
            final s = entry.value;
            return [
              label,
              '${s.minimum.toStringAsFixed(1)} $unit',
              '${s.average.toStringAsFixed(1)} $unit',
              '${s.maximum.toStringAsFixed(1)} $unit',
            ];
          }).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          cellStyle: const pw.TextStyle(fontSize: 9),
        ),
      ],
    );
  }

  static List<pw.Widget> _driveCharts(List<ObdDriveSnapshotFrame> frames) {
    const chartMetrics = ['rpm', 'speed_kph', 'coolant_temp_c'];
    return chartMetrics
        .where((metric) => frames.any((f) => f.values.containsKey(metric)))
        .map((metric) => _lineChart(metric, frames))
        .toList();
  }

  static pw.Widget _lineChart(String metric, List<ObdDriveSnapshotFrame> frames) {
    final label = ObdMetricCatalog.labels[metric] ?? metric;
    final unit = ObdMetricCatalog.units[metric] ?? '';
    final values = frames
        .map((f) => f.values[metric])
        .whereType<double>()
        .toList();
    if (values.isEmpty) return pw.SizedBox();

    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final minVal = values.reduce((a, b) => a < b ? a : b);
    final range = (maxVal - minVal).abs() < 0.01 ? 1.0 : (maxVal - minVal);

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('$label over drive ($unit)',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
          pw.SizedBox(height: 8),
          pw.Container(
            height: 120,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.CustomPaint(
              painter: (canvas, size) {
                final w = size.x;
                final h = size.y;
                const pad = 8.0;
                final plotW = w - pad * 2;
                final plotH = h - pad * 2;

                for (var i = 0; i < values.length - 1; i++) {
                  final x1 = pad + (i / (values.length - 1)) * plotW;
                  final x2 = pad + ((i + 1) / (values.length - 1)) * plotW;
                  final y1 = pad + plotH - ((values[i] - minVal) / range) * plotH;
                  final y2 =
                      pad + plotH - ((values[i + 1] - minVal) / range) * plotH;
                  canvas
                    ..setStrokeColor(PdfColor.fromHex('#009DFF'))
                    ..setLineWidth(1.5)
                    ..moveTo(x1, y1)
                    ..lineTo(x2, y2)
                    ..strokePath();
                }
              },
            ),
          ),
          pw.Text(
            'Min ${minVal.toStringAsFixed(1)} · Max ${maxVal.toStringAsFixed(1)} · ${values.length} points',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  static pw.Widget _statsBarChart(String metric, ObdMetricStats stats) {
    final label = ObdMetricCatalog.labels[metric] ?? metric;
    final maxBar = stats.maximum <= 0 ? 1.0 : stats.maximum;
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 4),
          pw.Row(
            children: [
              _bar('Min', stats.minimum / maxBar, PdfColors.blue300),
              pw.SizedBox(width: 4),
              _bar('Avg', stats.average / maxBar, PdfColors.blue),
              pw.SizedBox(width: 4),
              _bar('Max', stats.maximum / maxBar, PdfColors.blue900),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _bar(String label, double fraction, PdfColor color) {
    return pw.Expanded(
      child: pw.Column(
        children: [
          pw.Container(
            height: 40 * fraction.clamp(0.05, 1.0),
            decoration: pw.BoxDecoration(
              color: color,
              borderRadius: pw.BorderRadius.circular(4),
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
        ],
      ),
    );
  }

  static String _completionLabel(ObdCompletionReason reason) => switch (reason) {
        ObdCompletionReason.completed => 'Completed',
        ObdCompletionReason.bluetoothDisconnect => 'Bluetooth disconnected',
        ObdCompletionReason.vehicleMoved => 'Vehicle moved',
        ObdCompletionReason.cancelled => 'Cancelled',
        ObdCompletionReason.backgroundInterrupted => 'Background interrupted',
      };

  static pw.Widget _section(String title, List<pw.Widget> children) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  static pw.Widget _detailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(label, style: pw.TextStyle(color: PdfColors.grey700)),
          ),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }
}
