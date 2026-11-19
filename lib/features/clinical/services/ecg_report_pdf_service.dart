import 'dart:typed_data';
import 'dart:ui';

import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../whiteboard/services/whiteboard_pdf_saver_stub.dart'
    if (dart.library.io) '../../whiteboard/services/whiteboard_pdf_saver_io.dart'
    if (dart.library.js_interop) '../../whiteboard/services/whiteboard_pdf_saver_web.dart';
import '../models/ecg_interpreter_model.dart';
import 'ecg_narrative_builder.dart';

/// Met en page le compte rendu ECG rédigé par [EcgNarrativeBuilder] dans un
/// PDF A4 prêt à imprimer, avec en-tête, pied de page, pagination et blocs
/// « conclusion / conduite à tenir ».
class EcgReportPdfService {
  EcgReportPdfService._();

  static const double _marginLeft = 46;
  static const double _marginRight = 46;
  static const double _marginTop = 104;
  static const double _marginBottom = 66;
  static const double _headerHeight = 88;

  static final PdfColor teal = PdfColor(13, 148, 136);
  static final PdfColor navy = PdfColor(15, 23, 42);
  static final PdfColor muted = PdfColor(100, 116, 139);
  static final PdfColor line = PdfColor(226, 232, 240);
  static final PdfColor soft = PdfColor(248, 250, 252);
  static final PdfColor critical = PdfColor(220, 38, 38);
  static final PdfColor warning = PdfColor(217, 119, 6);
  static final PdfColor stable = PdfColor(5, 150, 105);

  /// Construit le PDF en mémoire.
  static Future<Uint8List> buildBytes({
    required EcgFindings findings,
    required EcgInterpretationResult result,
    EcgPatientInfo patient = const EcgPatientInfo(),
    DateTime? generatedAt,
  }) async {
    final report = EcgNarrativeBuilder.build(
      findings: findings,
      result: result,
      patient: patient,
    );
    final now = generatedAt ?? DateTime.now();

    final document = PdfDocument();
    document.pageSettings.size = PdfPageSize.a4;
    document.pageSettings.margins.left = _marginLeft;
    document.pageSettings.margins.right = _marginRight;
    document.pageSettings.margins.top = _marginTop;
    document.pageSettings.margins.bottom = _marginBottom;

    final canvas = _EcgPdfCanvas(document);
    final fonts = _EcgPdfFonts();
    final brushes = _EcgPdfBrushes();

    canvas.start();
    document.template.top = _buildHeader(document, canvas.width, fonts, brushes, now);
    document.template.bottom = _buildFooter(document, canvas.width, fonts, brushes);

    _drawPatientBlock(canvas, fonts, brushes, patient, findings);
    _drawVerdictBanner(canvas, fonts, brushes, report);
    _drawMetrics(canvas, fonts, brushes, findings, result);
    _drawSections(canvas, fonts, brushes, report);
    _drawConclusion(canvas, fonts, brushes, report);
    _drawActions(canvas, fonts, brushes, report);
    _drawSignature(canvas, fonts, brushes, now);
    _drawConfidence(canvas, fonts, brushes, report);

    final bytes = await document.save();
    document.dispose();
    return Uint8List.fromList(bytes);
  }

  /// Génère le compte rendu puis l'enregistre et l'ouvre sur l'appareil.
  static Future<String?> exportAndOpen({
    required EcgFindings findings,
    required EcgInterpretationResult result,
    EcgPatientInfo patient = const EcgPatientInfo(),
    String? fileName,
  }) async {
    final bytes = await buildBytes(
      findings: findings,
      result: result,
      patient: patient,
    );
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    return saveAndOpenPdfBytes(
      bytes: bytes,
      fileName: fileName ?? 'compte_rendu_ecg_$stamp',
    );
  }

  // ---------------------------------------------------------------------------
  // En-tête et pied de page
  // ---------------------------------------------------------------------------

  static PdfPageTemplateElement _buildHeader(
    PdfDocument document,
    double width,
    _EcgPdfFonts fonts,
    _EcgPdfBrushes brushes,
    DateTime generatedAt,
  ) {
    final header = PdfPageTemplateElement(
      Rect.fromLTWH(0, 0, width, _headerHeight),
      document.pages[0],
    );
    final g = header.graphics;

    g.drawRectangle(brush: brushes.teal, bounds: const Rect.fromLTWH(0, 0, 22, 22));
    g.drawString(
      'M',
      PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold),
      brush: brushes.white,
      bounds: const Rect.fromLTWH(0, 3, 22, 17),
      format: PdfStringFormat(
        alignment: PdfTextAlignment.center,
        lineAlignment: PdfVerticalAlignment.middle,
      ),
    );
    g.drawString(
      'MEDSINA',
      fonts.brand,
      brush: brushes.teal,
      bounds: const Rect.fromLTWH(30, 1, 220, 12),
      format: PdfStringFormat(characterSpacing: 1.6),
    );
    g.drawString(
      'Assistant ECG & QTc  ·  interprétation assistée',
      fonts.brandSub,
      brush: brushes.muted,
      bounds: const Rect.fromLTWH(30, 13, 280, 11),
    );
    g.drawString(
      'Généré le ${DateFormat('dd/MM/yyyy à HH:mm').format(generatedAt)}',
      fonts.meta,
      brush: brushes.muted,
      bounds: Rect.fromLTWH(width * 0.55, 2, width * 0.45, 11),
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
    );

    g.drawString(
      'Compte rendu d\'électrocardiogramme',
      fonts.title,
      brush: brushes.navy,
      bounds: Rect.fromLTWH(0, 32, width, 20),
    );
    g.drawString(
      'Rythme, conduction, axe, morphologie, repolarisation et intervalle QT',
      fonts.subtitle,
      brush: brushes.muted,
      bounds: Rect.fromLTWH(0, 54, width, 12),
    );
    g.drawLine(
      PdfPen(teal, width: 1.2),
      Offset(0, 74),
      Offset(width, 74),
    );
    return header;
  }

  static PdfPageTemplateElement _buildFooter(
    PdfDocument document,
    double width,
    _EcgPdfFonts fonts,
    _EcgPdfBrushes brushes,
  ) {
    final footer = PdfPageTemplateElement(
      Rect.fromLTWH(0, 0, width, 44),
      document.pages[0],
    );
    final g = footer.graphics;
    g.drawLine(PdfPen(line, width: 0.8), Offset(0, 2), Offset(width, 2));
    g.drawString(
      'Document généré par Medsina. Outil d\'aide à l\'interprétation : il ne remplace '
      'ni l\'avis d\'un médecin ni un ECG 12 dérivations sur papier.',
      fonts.footer,
      brush: brushes.muted,
      bounds: Rect.fromLTWH(0, 7, width * 0.76, 24),
    );

    final pageNumber = PdfPageNumberField(font: fonts.pageNumber, brush: brushes.muted);
    final pageCount = PdfPageCountField(font: fonts.pageNumber, brush: brushes.muted);
    final composite = PdfCompositeField(
      font: fonts.pageNumber,
      brush: brushes.muted,
      text: 'Page {0} sur {1}',
      fields: <PdfAutomaticField>[pageNumber, pageCount],
    );
    composite.draw(g, Offset(width - 96, 8));
    return footer;
  }

  // ---------------------------------------------------------------------------
  // Blocs de contenu
  // ---------------------------------------------------------------------------

  static void _drawPatientBlock(
    _EcgPdfCanvas canvas,
    _EcgPdfFonts fonts,
    _EcgPdfBrushes brushes,
    EcgPatientInfo patient,
    EcgFindings findings,
  ) {
    canvas.ensure(86);
    canvas.y += 2;
    canvas.textAt(
      'PATIENT',
      fonts.cardLabel,
      brushes.teal,
      Rect.fromLTWH(0, canvas.y, canvas.width, 10),
      format: PdfStringFormat(characterSpacing: 1.2),
    );
    canvas.y += 15;

    final identityY = canvas.y;
    canvas.textAt(
      'Nom : ${_plain(_valueOr(patient.name, '........................................'))}',
      fonts.cardText,
      brushes.navy,
      Rect.fromLTWH(0, identityY, 250, 12),
    );
    canvas.textAt(
      'Âge : ${_plain(_valueOr(patient.age, '......'))}',
      fonts.cardText,
      brushes.navy,
      Rect.fromLTWH(258, identityY, 96, 12),
    );
    canvas.textAt(
      'Sexe : ${findings.isFemale ? 'féminin' : 'masculin'}',
      fonts.cardText,
      brushes.navy,
      Rect.fromLTWH(360, identityY, 143, 12),
    );
    canvas.y += 15;

    final indication = patient.indication.trim().isEmpty
        ? 'Indication : non renseignée'
        : 'Indication : ${patient.indication.trim()}';
    canvas.text(_plain(indication), font: fonts.cardText, brush: brushes.navy, lineSpacing: 2.6);
    canvas.y += 2;

    if (patient.notes.trim().isNotEmpty) {
      canvas.text(
        _plain('Renseignements complémentaires : ${patient.notes.trim()}'),
        font: fonts.cardText,
        brush: brushes.navy,
        lineSpacing: 2.6,
      );
      canvas.y += 2;
    }
    canvas.y += 10;
  }

  static void _drawVerdictBanner(
    _EcgPdfCanvas canvas,
    _EcgPdfFonts fonts,
    _EcgPdfBrushes brushes,
    EcgNarrativeReport report,
  ) {
    canvas.ensure(34);
    final color = switch (report.verdict) {
      EcgReportVerdict.normal => stable,
      EcgReportVerdict.abnormal => critical,
      EcgReportVerdict.incomplete => warning,
    };
    canvas.page.graphics.drawRectangle(
      brush: PdfSolidBrush(color),
      bounds: Rect.fromLTWH(0, canvas.y, canvas.width, 26),
    );
    canvas.textAt(
      _plain(report.verdictLabel.toUpperCase()),
      fonts.banner,
      brushes.white,
      Rect.fromLTWH(10, canvas.y, canvas.width - 20, 26),
      format: PdfStringFormat(lineAlignment: PdfVerticalAlignment.middle),
    );
    canvas.y += 26 + 12;
  }

  static void _drawMetrics(
    _EcgPdfCanvas canvas,
    _EcgPdfFonts fonts,
    _EcgPdfBrushes brushes,
    EcgFindings findings,
    EcgInterpretationResult result,
  ) {
    canvas.ensure(42);
    final top = canvas.y;
    canvas.page.graphics.drawRectangle(
      brush: brushes.soft,
      bounds: Rect.fromLTWH(0, top, canvas.width, 34),
    );

    final items = <({String label, String value})>[
      (label: 'FRÉQUENCE', value: '${findings.heartRateBpm.round()} bpm'),
      (label: 'RYTHME', value: _compactRhythm(findings)),
      (label: 'PR', value: findings.prMs == null ? '—' : '${findings.prMs!.round()} ms'),
      (label: 'QRS', value: '${findings.qrsMs.round()} ms'),
      (label: 'QTc', value: '${result.qtcBazett.round()} ms'),
      (label: 'AXE', value: _compactAxis(result.axisLabel)),
    ];
    final columnWidth = canvas.width / items.length;
    for (var i = 0; i < items.length; i++) {
      final x = i * columnWidth;
      if (i > 0) {
        canvas.page.graphics.drawLine(
          PdfPen(line, width: 0.7),
          Offset(x, top + 7),
          Offset(x, top + 27),
        );
      }
      canvas.textAt(
        items[i].label,
        fonts.metricLabel,
        brushes.muted,
        Rect.fromLTWH(x + 8, top + 6, columnWidth - 12, 9),
        format: PdfStringFormat(characterSpacing: 0.6),
      );
      canvas.textAt(
        items[i].value,
        fonts.metricValue,
        brushes.navy,
        Rect.fromLTWH(x + 8, top + 16, columnWidth - 12, 14),
      );
    }
    canvas.y = top + 34 + 12;
  }

  static void _drawSections(
    _EcgPdfCanvas canvas,
    _EcgPdfFonts fonts,
    _EcgPdfBrushes brushes,
    EcgNarrativeReport report,
  ) {
    for (var i = 0; i < report.sections.length; i++) {
      final section = report.sections[i];
      canvas.ensure(52);
      canvas.textAt(
        '${i + 1}. ${section.title.toUpperCase()}',
        fonts.sectionTitle,
        brushes.teal,
        Rect.fromLTWH(0, canvas.y, canvas.width, 12),
        format: PdfStringFormat(characterSpacing: 0.4),
      );
      canvas.y += 13;
      canvas.text(_plain(section.body), font: fonts.body, brush: brushes.navy, lineSpacing: 3);
      canvas.y += 9;

    }
  }

  static void _drawConclusion(
    _EcgPdfCanvas canvas,
    _EcgPdfFonts fonts,
    _EcgPdfBrushes brushes,
    EcgNarrativeReport report,
  ) {
    // Conclusion et conduite à tenir forment un même bloc : on évite de
    // séparer la synthèse de la prise en charge recommandée.
    canvas.ensure(124);
    canvas.rule(brushes.linePen, spaceAfter: 10);
    final top = canvas.y;
    canvas.textAt(
      'CONCLUSION',
      fonts.blockLabel,
      brushes.teal,
      Rect.fromLTWH(12, top, canvas.width - 12, 10),
      format: PdfStringFormat(characterSpacing: 1.2),
    );
    canvas.y += 13;
    canvas.text(
      _plain(report.conclusion),
      font: fonts.conclusion,
      brush: brushes.navy,
      lineSpacing: 3,
      xOffset: 12,
      widthInset: 12,
    );
    canvas.y += 5;
    canvas.page.graphics.drawRectangle(
      brush: brushes.teal,
      bounds: Rect.fromLTWH(0, top, 2.6, canvas.y - 5 - top),
    );
    canvas.y += 10;
  }

  static void _drawActions(
    _EcgPdfCanvas canvas,
    _EcgPdfFonts fonts,
    _EcgPdfBrushes brushes,
    EcgNarrativeReport report,
  ) {
    final actions = report.urgentActions;
    canvas.ensure(58);
    final accent = actions.isEmpty ? stable : critical;
    final top = canvas.y;
    final label = actions.isEmpty ? 'SURVEILLANCE' : 'CONDUITE À TENIR';
    final textTop = top;

    canvas.page.graphics.drawRectangle(
      brush: PdfSolidBrush(accent),
      bounds: Rect.fromLTWH(0, top, 2.6, 12),
    );
    canvas.textAt(
      label,
      fonts.blockLabel,
      PdfSolidBrush(accent),
      Rect.fromLTWH(12, top, canvas.width - 12, 10),
      format: PdfStringFormat(characterSpacing: 1.2),
    );
    canvas.y += 13;

    if (actions.isEmpty) {
      canvas.text(
        'Aucune mesure urgente n\'est nécessaire. Remettre le tracé au dossier, '
        'le comparer à un ECG antérieur et l\'interpréter au regard du contexte clinique.',
        font: fonts.body,
        brush: brushes.navy,
        lineSpacing: 3,
        xOffset: 12,
        widthInset: 12,
      );
    } else {
      for (final action in actions) {
        canvas.ensure(34);
        final bulletPage = canvas.page;
        final bulletTop = canvas.y + 5;
        canvas.text(
          _plain(action),
          font: fonts.body,
          brush: brushes.navy,
          lineSpacing: 3,
          xOffset: 22,
          widthInset: 22,
        );
        bulletPage.graphics.drawEllipse(
          Rect.fromLTWH(10, bulletTop, 3.4, 3.4),
          brush: PdfSolidBrush(accent),
        );
        canvas.y += 4;
      }
    }
    canvas.y = canvas.y > textTop ? canvas.y : textTop + 14;
    canvas.y += 10;
  }

  static void _drawSignature(
    _EcgPdfCanvas canvas,
    _EcgPdfFonts fonts,
    _EcgPdfBrushes brushes,
    DateTime generatedAt,
  ) {
    canvas.ensure(62);
    canvas.rule(brushes.linePen, spaceAfter: 10);
    final top = canvas.y;
    canvas.textAt(
      'Date : ${DateFormat('dd/MM/yyyy').format(generatedAt)}',
      fonts.small,
      brushes.muted,
      Rect.fromLTWH(0, top, canvas.width * 0.5, 12),
    );
    canvas.textAt(
      'Visa et cachet du praticien',
      fonts.small,
      brushes.muted,
      Rect.fromLTWH(canvas.width * 0.5, top, canvas.width * 0.5, 12),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );
    canvas.page.graphics.drawLine(
      PdfPen(line, width: 0.9),
      Offset(canvas.width - 190, top + 40),
      Offset(canvas.width, top + 40),
    );
    canvas.y = top + 52;
  }

  static void _drawConfidence(
    _EcgPdfCanvas canvas,
    _EcgPdfFonts fonts,
    _EcgPdfBrushes brushes,
    EcgNarrativeReport report,
  ) {
    canvas.ensure(22);
    canvas.text(
      _plain(report.confidenceNote),
      font: fonts.tinyItalic,
      brush: brushes.muted,
      lineSpacing: 2.4,
    );
  }

  // ---------------------------------------------------------------------------
  // Utilitaires
  // ---------------------------------------------------------------------------

  static String _compactRhythm(EcgFindings findings) {
    if (findings.atrial == EcgAtrialActivity.sinus) {
      return findings.regularity == EcgRegularity.regular ? 'sinusal' : 'sinusal irrégulier';
    }
    return switch (findings.atrial) {
      EcgAtrialActivity.fibrillation => 'fibrillation',
      EcgAtrialActivity.flutter => 'flutter',
      EcgAtrialActivity.absent => 'sans P',
      EcgAtrialActivity.sinus => 'sinusal',
    };
  }

  static String _compactAxis(String axisLabel) {
    if (axisLabel.startsWith('normal')) return 'normal';
    if (axisLabel.startsWith('déviation gauche')) return 'gauche';
    if (axisLabel.startsWith('déviation droite')) return 'droite';
    return 'extrême';
  }

  static String _valueOr(String value, String fallback) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  /// Remplace les caractères absents de l'encodage WinAnsi des polices
  /// standard (≥, ≈, →, apostrophes typographiques…) par des équivalents
  /// imprimables, puis neutralise tout code non supporté.
  static String _plain(String input) {
    var value = input
        .replaceAll('≥', 'au moins ')
        .replaceAll('≤', 'au plus ')
        .replaceAll('≈', 'environ ')
        .replaceAll('→', 'vers ')
        .replaceAll('−', '-')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('’', '\'')
        .replaceAll('‘', '\'')
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('…', '...')
        .replaceAll('œ', 'oe')
        .replaceAll('Œ', 'OE')
        .replaceAll('±', '+/-')
        .replaceAll('·', '-')
        .replaceAll('\u00A0', ' ')
        .replaceAll('\r', ' ')
        .replaceAll('\n', ' ');

    final buffer = StringBuffer();
    for (final rune in value.runes) {
      if (rune >= 32 && rune <= 255 && !(rune >= 127 && rune <= 159)) {
        buffer.writeCharCode(rune);
      } else {
        buffer.write(' ');
      }
    }
    value = buffer.toString().replaceAll(RegExp(r'\s{2,}'), ' ');
    return value.trim();
  }
}

/// Zone de dessin paginée : suit la page courante et l'ordonnée du curseur.
class _EcgPdfCanvas {
  _EcgPdfCanvas(this.document) {
    width = document.pageSettings.size.width -
        EcgReportPdfService._marginLeft -
        EcgReportPdfService._marginRight;
  }

  final PdfDocument document;
  late final double width;
  late PdfPage page;
  double y = 0;

  /// Hauteur utile d'une page : Syncfusion déduit déjà les en-têtes et pieds
  /// de page du client size lorsque des gabarits sont définis.
  double get maxY => page.getClientSize().height;

  void start() {
    page = document.pages.add();
    y = 0;
  }

  void ensure(double height) {
    if (y + height > maxY) {
      page = document.pages.add();
      y = 0;
    }
  }

  /// Trace un filet horizontal à la position courante.
  void rule(PdfPen pen, {double spaceBefore = 0, double spaceAfter = 0}) {
    y += spaceBefore;
    page.graphics.drawLine(pen, Offset(0, y), Offset(width, y));
    y += spaceAfter;
  }

  void textAt(
    String value,
    PdfFont font,
    PdfBrush brush,
    Rect bounds, {
    PdfStringFormat? format,
  }) {
    page.graphics.drawString(value, font, brush: brush, bounds: bounds, format: format);
  }

  /// Dessine un paragraphe avec retour à la ligne et saut de page automatique.
  void text(
    String value, {
    required PdfFont font,
    required PdfBrush brush,
    double lineSpacing = 3,
    double xOffset = 0,
    double widthInset = 0,
  }) {
    if (value.trim().isEmpty) return;
    ensure(24);
    final usableWidth = width - xOffset - widthInset;
    final element = PdfTextElement(
      text: value,
      font: font,
      brush: brush,
      format: PdfStringFormat(lineSpacing: lineSpacing),
    );
    final layout = element.draw(
      page: page,
      bounds: Rect.fromLTWH(xOffset, y, usableWidth, maxY - y),
      format: PdfLayoutFormat(
        layoutType: PdfLayoutType.paginate,
        breakType: PdfLayoutBreakType.fitPage,
        paginateBounds: Rect.fromLTWH(xOffset, 0, usableWidth, maxY),
      ),
    );
    if (layout == null) return;
    page = layout.page;
    y = layout.bounds.bottom;
  }
}

class _EcgPdfFonts {
  final brand = PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.bold);
  final brandSub = PdfStandardFont(PdfFontFamily.helvetica, 7.4);
  final title = PdfStandardFont(PdfFontFamily.helvetica, 15, style: PdfFontStyle.bold);
  final subtitle = PdfStandardFont(PdfFontFamily.helvetica, 8.4);
  final meta = PdfStandardFont(PdfFontFamily.helvetica, 7.6);
  final cardLabel = PdfStandardFont(PdfFontFamily.helvetica, 7.2, style: PdfFontStyle.bold);
  final cardText = PdfStandardFont(PdfFontFamily.helvetica, 9.6);
  final banner = PdfStandardFont(PdfFontFamily.helvetica, 10.4, style: PdfFontStyle.bold);
  final metricLabel = PdfStandardFont(PdfFontFamily.helvetica, 6.6, style: PdfFontStyle.bold);
  final metricValue = PdfStandardFont(PdfFontFamily.helvetica, 10.2, style: PdfFontStyle.bold);
  final sectionTitle = PdfStandardFont(PdfFontFamily.helvetica, 8.6, style: PdfFontStyle.bold);
  final blockLabel = PdfStandardFont(PdfFontFamily.helvetica, 8.2, style: PdfFontStyle.bold);
  final body = PdfStandardFont(PdfFontFamily.helvetica, 10);
  final conclusion = PdfStandardFont(PdfFontFamily.helvetica, 10.2, style: PdfFontStyle.bold);
  final small = PdfStandardFont(PdfFontFamily.helvetica, 8.2);
  final tinyItalic = PdfStandardFont(PdfFontFamily.helvetica, 7.6, style: PdfFontStyle.italic);
  final footer = PdfStandardFont(PdfFontFamily.helvetica, 7, style: PdfFontStyle.italic);
  final pageNumber = PdfStandardFont(PdfFontFamily.helvetica, 8);
}

class _EcgPdfBrushes {
  final teal = PdfSolidBrush(EcgReportPdfService.teal);
  final navy = PdfSolidBrush(EcgReportPdfService.navy);
  final muted = PdfSolidBrush(EcgReportPdfService.muted);
  final white = PdfSolidBrush(PdfColor(255, 255, 255));
  final soft = PdfSolidBrush(EcgReportPdfService.soft);
  final linePen = PdfPen(EcgReportPdfService.line, width: 0.8);
}
