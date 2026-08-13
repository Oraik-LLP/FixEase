import 'dart:isolate';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/ai_response.dart';
import '../models/diagnostic.dart';
import '../models/obd.dart';
import 'obd_pdf_sections.dart';

/// Builds and exports diagnostic reports as PDFs.
abstract final class ReportExportService {
  static Future<File> savePdf({
    required DiagnosticSession session,
    required AiDiagnosticResponse response,
  }) async {
    final bytes = await _buildPdfBytes(session: session, response: response);
    final dir = await _resolveSaveDirectory();
    final filePath = p.join(dir.path, fileName(session));
    await Isolate.run(
      () => File(filePath).writeAsBytesSync(bytes, flush: true),
    );
    final file = File(filePath);
    return file;
  }

  static Future<void> sharePdf({
    required DiagnosticSession session,
    required AiDiagnosticResponse response,
  }) async {
    final bytes = await _buildPdfBytes(session: session, response: response);
    await Printing.sharePdf(
      bytes: bytes,
      filename: fileName(session),
    );
  }

  static String fileName(DiagnosticSession session) {
    final date = session.createdAt.toIso8601String().split('T').first;
    return 'fixease_report_${date}_${session.id}.pdf';
  }

  static Future<Directory> _resolveSaveDirectory() async {
    if (Platform.isAndroid) {
      final dirs =
          await getExternalStorageDirectories(type: StorageDirectory.downloads);
      if (dirs != null && dirs.isNotEmpty) {
        return dirs.first;
      }
    }
    return getApplicationDocumentsDirectory();
  }

  static Future<Uint8List> _buildPdfBytes({
    required DiagnosticSession session,
    required AiDiagnosticResponse response,
  }) {
    final sessionJson = Map<String, dynamic>.from(session.toJson());
    final responseJson = Map<String, dynamic>.from(response.toJson());
    return Isolate.run(() async {
      final rebuiltSession = DiagnosticSession.fromJson(sessionJson);
      final rebuiltResponse = AiDiagnosticResponse.fromJson(responseJson);
      final pdf = _buildPdfDocument(
        session: rebuiltSession,
        response: rebuiltResponse,
      );
      final bytes = await pdf.save();
      return Uint8List.fromList(bytes);
    });
  }

  static pw.Document _buildPdfDocument({
    required DiagnosticSession session,
    required AiDiagnosticResponse response,
  }) {
    final pdf = pw.Document();
    final isUrgent = session.type == DiagnosticType.urgent;
    final isInvoiceAudit = session.type == DiagnosticType.invoiceAudit;
    final isObd = session.isObd;
    final obdRecord = _obdRecordFromSession(session);
    final reportTitle = isObd
        ? (session.type == DiagnosticType.obdDrive
            ? 'OBD Drive Scan Report'
            : 'OBD Idle Scan Report')
        : isUrgent
            ? 'Urgent Diagnosis Report'
            : isInvoiceAudit
                ? 'Invoice Audit Report'
                : 'Photo Diagnosis Report';
    final typeLabel = isObd
        ? (session.type == DiagnosticType.obdDrive ? 'OBD Drive' : 'OBD Idle')
        : isUrgent
            ? 'Urgent'
            : isInvoiceAudit
                ? 'Invoice Audit'
                : 'Photo';

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(28),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerLeft,
          child: pw.Text(
            'FixEase - Powered by Oraik Systems',
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey700,
            ),
          ),
        ),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#111114'),
              borderRadius: pw.BorderRadius.circular(16),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  reportTitle,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  session.vehicleName ?? 'Unknown Vehicle',
                  style: pw.TextStyle(
                    color: PdfColor.fromHex('#8DBDFF'),
                    fontSize: 12,
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Row(
                  children: [
                    _metricChip(
                      isInvoiceAudit ? 'Fairness' : 'Health',
                      response.displayScoreLabel,
                    ),
                    pw.SizedBox(width: 8),
                    _metricChip('Confidence', response.confidenceLabel),
                    pw.SizedBox(width: 8),
                    _metricChip(
                      isInvoiceAudit ? 'Verdict' : 'Severity',
                      isInvoiceAudit
                          ? (response.verdict ?? 'Audit')
                          : session.severityLabel,
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          _section(
            'Report Details',
            [
              _detailRow('Type', typeLabel),
              _detailRow('Date', session.dateLabel),
              _detailRow('Time', session.timeLabel),
              if (isInvoiceAudit &&
                  response.documentType != null &&
                  response.documentType!.isNotEmpty)
                _detailRow('Document', response.documentType!),
              if (session.description != null &&
                  session.description!.isNotEmpty)
                _detailRow(
                  isInvoiceAudit ? 'Visit Purpose' : 'Description',
                  session.description!,
                ),
            ],
          ),
          if (isInvoiceAudit)
            _section(
              'Important',
              [
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#FFF3E0'),
                    borderRadius: pw.BorderRadius.circular(12),
                    border: pw.Border.all(
                      color: PdfColor.fromHex('#E0A04B'),
                      width: 1,
                    ),
                  ),
                  child: pw.Text(
                    'This audit highlights possible overcharges and upsells. It is not a legal or mechanical diagnosis. Always confirm major repairs with a qualified mechanic or a second opinion.',
                    style: pw.TextStyle(
                      color: PdfColor.fromHex('#6A4300'),
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          _section(isInvoiceAudit ? 'Audit Summary' : 'Summary',
              [pw.Text(response.summary)]),
          if (response.urgencyNote != null && response.urgencyNote!.isNotEmpty)
            _section(
              'Urgency',
              [
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#FFF1F1'),
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Text(
                    response.urgencyNote!,
                    style: pw.TextStyle(color: PdfColor.fromHex('#B72A2A')),
                  ),
                ),
              ],
            ),
          if (session.symptoms.isNotEmpty)
            _section(
              'Symptoms',
              session.symptoms.map(_bulletText).toList(),
            ),
          if (!isInvoiceAudit && response.possibleCauses.isNotEmpty)
            _section(
              'Possible Causes',
              response.possibleCauses.map(_bulletText).toList(),
            ),
          if (isInvoiceAudit && response.topFlags.isNotEmpty)
            _section(
              'Top Flags',
              response.topFlags.map(_bulletText).toList(),
            ),
          if (isInvoiceAudit && response.lineItemAudit.isNotEmpty)
            _section(
              'Line Item Audit',
              response.lineItemAudit
                  .map(
                    (item) => pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 8),
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#F6F7FB'),
                        borderRadius: pw.BorderRadius.circular(10),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            '${item.item}${item.charge.isNotEmpty ? ' - ${item.charge}' : ''}',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            item.assessment,
                            style: pw.TextStyle(
                              color: PdfColor.fromHex('#2357A5'),
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(item.reason),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Confidence: ${item.confidence}',
                            style: pw.TextStyle(color: PdfColors.grey700),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          if (isInvoiceAudit && response.paddingPatternsDetected.isNotEmpty)
            _section(
              'Padding Patterns Detected',
              response.paddingPatternsDetected.map(_bulletText).toList(),
            ),
          if (response.recommendations.isNotEmpty)
            _section(
              isInvoiceAudit ? 'Next Steps' : 'Recommendations',
              response.recommendations.map(_bulletText).toList(),
            ),
          if (isInvoiceAudit && response.questionsToAsk.isNotEmpty)
            _section(
              'Questions To Ask The Shop',
              response.questionsToAsk.map(_bulletText).toList(),
            ),
          if (isInvoiceAudit &&
              response.negotiationScript != null &&
              response.negotiationScript!.trim().isNotEmpty)
            _section(
              'Negotiation Script',
              [pw.Text(response.negotiationScript!)],
            ),
          if (isInvoiceAudit &&
              (response.limitations?.trim().isNotEmpty ?? false))
            _section(
              'Limitations',
              [pw.Text(response.limitations!)],
            ),
          if (response.mechanicScript != null &&
              response.mechanicScript!.trim().isNotEmpty)
            _mechanicSection(
              title: isInvoiceAudit
                  ? 'Show This To The Shop'
                  : 'Show This To The Mechanic',
              script: response.mechanicScript!,
            ),
          if (response.subScores.isNotEmpty)
            _section(
              isInvoiceAudit ? 'Fairness Breakdown' : 'Component Scores',
              response.normalizedSubScores.entries
                  .map((entry) => _detailRow(
                        entry.key,
                        response.formatSubScore(entry.value),
                      ))
                  .toList(),
            ),
          if (isObd && obdRecord != null) ...ObdPdfSections.build(obdRecord),
          pw.SizedBox(height: 26),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Mechanic Signature: __________________',
                style: const pw.TextStyle(fontSize: 11),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Date of Repair: __________________',
                style: const pw.TextStyle(fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );

    return pdf;
  }

  static ObdScanRecord? _obdRecordFromSession(DiagnosticSession session) {
    final recordJson = session.contextJson?['obd_record'];
    if (recordJson is! Map) return null;
    try {
      return ObdScanRecord.fromJson(Map<String, dynamic>.from(recordJson));
    } catch (_) {
      return null;
    }
  }

  static pw.Widget _metricChip(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#1D1F24'),
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              color: PdfColors.grey400,
              fontSize: 9,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _section(String title, List<pw.Widget> children) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  static pw.Widget _mechanicSection({
    required String title,
    required String script,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#FFF7D6'),
              borderRadius: pw.BorderRadius.circular(12),
              border: pw.Border.all(
                color: PdfColor.fromHex('#D4A100'),
                width: 1,
              ),
            ),
            child: pw.Text(
              script,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10.5,
                color: PdfColor.fromHex('#5E4300'),
              ),
            ),
          ),
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
            width: 90,
            child: pw.Text(
              label,
              style: pw.TextStyle(color: PdfColors.grey700),
            ),
          ),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }

  static pw.Widget _bulletText(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4, right: 6),
            child: pw.Container(
              width: 4,
              height: 4,
              decoration: const pw.BoxDecoration(
                color: PdfColors.black,
                shape: pw.BoxShape.circle,
              ),
            ),
          ),
          pw.Expanded(child: pw.Text(text)),
        ],
      ),
    );
  }
}
