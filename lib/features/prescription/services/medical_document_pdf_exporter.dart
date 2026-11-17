import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../whiteboard/services/whiteboard_pdf_saver_stub.dart'
    if (dart.library.io) '../../whiteboard/services/whiteboard_pdf_saver_io.dart'
    if (dart.library.js_interop) '../../whiteboard/services/whiteboard_pdf_saver_web.dart';

class MedicalDocumentPdfExporter {
  static Future<Uint8List> buildA4DocumentBytes({
    required String documentTitle,
    required String doctorName,
    required String establishment,
    required String city,
    required String patientName,
    required String patientMeta,
    required String bodyContent,
    String footerNote = 'Document généré via Medsina Algérie — À signer et cacheter par le praticien.',
  }) async {
    final PdfDocument document = PdfDocument();
    document.pageSettings.size = PdfPageSize.a4;
    document.pageSettings.margins.all = 36;

    final PdfPage page = document.pages.add();
    final Size size = page.getClientSize();
    final PdfGraphics g = page.graphics;

    final headerFont = PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold);
    final subFont = PdfStandardFont(PdfFontFamily.helvetica, 10);
    final titleFont = PdfStandardFont(PdfFontFamily.helvetica, 15, style: PdfFontStyle.bold);
    final bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 11);
    final footerFont = PdfStandardFont(PdfFontFamily.helvetica, 8.5, style: PdfFontStyle.italic);

    final tealBrush = PdfSolidBrush(PdfColor(13, 148, 136));
    final navyBrush = PdfSolidBrush(PdfColor(15, 23, 42));
    final mutedBrush = PdfSolidBrush(PdfColor(100, 116, 139));

    // En-tête Praticien & Établissement
    g.drawString(
      doctorName.isEmpty ? 'Dr. ........................' : doctorName,
      headerFont,
      brush: navyBrush,
      bounds: Rect.fromLTWH(0, 0, size.width * 0.65, 20),
    );
    g.drawString(
      establishment.isEmpty ? 'Établissement Hospitalier / Cabinet' : establishment,
      subFont,
      brush: mutedBrush,
      bounds: Rect.fromLTWH(0, 20, size.width * 0.65, 16),
    );

    final dateStr = DateFormat('dd/MM/yyyy').format(DateTime.now());
    g.drawString(
      '$city, le $dateStr',
      subFont,
      brush: navyBrush,
      bounds: Rect.fromLTWH(size.width * 0.65, 4, size.width * 0.35, 18),
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
    );

    g.drawLine(
      PdfPen(PdfColor(13, 148, 136), width: 1.5),
      const Offset(0, 46),
      Offset(size.width, 46),
    );

    // Identité Patient
    g.drawString(
      'Patient(e) : ${patientName.isEmpty ? "........................................" : patientName}   $patientMeta',
      PdfStandardFont(PdfFontFamily.helvetica, 10.5, style: PdfFontStyle.bold),
      brush: navyBrush,
      bounds: Rect.fromLTWH(0, 58, size.width, 20),
    );

    // Titre du Document (ORDONNANCE MÉDICALE ou CERTIFICAT)
    g.drawString(
      documentTitle.toUpperCase(),
      titleFont,
      brush: tealBrush,
      bounds: Rect.fromLTWH(0, 92, size.width, 24),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );

    // Corps du document (multi-lignes avec retour à la ligne automatique)
    final textElement = PdfTextElement(
      text: bodyContent,
      font: bodyFont,
      brush: navyBrush,
      format: PdfStringFormat(lineSpacing: 5),
    );
    textElement.draw(
      page: page,
      bounds: Rect.fromLTWH(0, 132, size.width, size.height - 230),
    );

    // Zone Signature & Cachet
    g.drawString(
      'Signature & Cachet du Médecin',
      PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold),
      brush: navyBrush,
      bounds: Rect.fromLTWH(size.width - 210, size.height - 95, 210, 18),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );

    // Pied de page
    g.drawLine(
      PdfPen(PdfColor(203, 213, 225), width: 0.8),
      Offset(0, size.height - 24),
      Offset(size.width, size.height - 24),
    );
    g.drawString(
      footerNote,
      footerFont,
      brush: mutedBrush,
      bounds: Rect.fromLTWH(0, size.height - 18, size.width, 16),
    );

    final List<int> saved = await document.save();
    document.dispose();
    return Uint8List.fromList(saved);
  }

  static Future<String?> exportAndOpenPdf({
    required String fileName,
    required String documentTitle,
    required String doctorName,
    required String establishment,
    required String city,
    required String patientName,
    required String patientMeta,
    required String bodyContent,
  }) async {
    final bytes = await buildA4DocumentBytes(
      documentTitle: documentTitle,
      doctorName: doctorName,
      establishment: establishment,
      city: city,
      patientName: patientName,
      patientMeta: patientMeta,
      bodyContent: bodyContent,
    );
    return saveAndOpenPdfBytes(bytes: bytes, fileName: fileName);
  }
}
