import 'package:flutter_test/flutter_test.dart';
import 'package:medsina/features/clinical/models/ecg_interpreter_model.dart';
import 'package:medsina/features/clinical/services/ecg_narrative_builder.dart';
import 'package:medsina/features/clinical/services/ecg_report_pdf_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

EcgFindings findings({
  double hr = 70,
  EcgAtrialActivity atrial = EcgAtrialActivity.sinus,
  EcgRegularity regularity = EcgRegularity.regular,
  EcgAvBlock avBlock = EcgAvBlock.none,
  double? prMs = 160,
  double qrsMs = 90,
  bool leadI = true,
  bool avf = true,
  EcgBundleBranch bbb = EcgBundleBranch.none,
  double? sV1,
  double? rV6,
  bool qPath = false,
  EcgStFinding st = EcgStFinding.isoelectric,
  EcgTerritory territory = EcgTerritory.none,
  double stMm = 0,
  bool twoLeads = true,
  EcgTWave t = EcgTWave.normal,
  double qtMs = 400,
  bool female = false,
  bool standard = true,
  bool? avrNegative = true,
  bool? rProgression = true,
}) {
  return EcgFindings(
    heartRateBpm: hr,
    atrial: atrial,
    regularity: regularity,
    avBlock: avBlock,
    prMs: prMs,
    qrsMs: qrsMs,
    qrsPositiveInLeadI: leadI,
    qrsPositiveInLeadAvf: avf,
    bundleBranch: bbb,
    sokolowSV1mm: sV1,
    sokolowRV6mm: rV6,
    pathologicQ: qPath,
    stFinding: st,
    territory: territory,
    stElevationMm: stMm,
    stTwoContiguousLeads: twoLeads,
    tWave: t,
    qtMs: qtMs,
    isFemale: female,
    standardCalibration: standard,
    avrNegative: avrNegative,
    rProgressionNormal: rProgression,
  );
}

EcgNarrativeReport narrative(EcgFindings f) {
  return EcgNarrativeBuilder.build(
    findings: f,
    result: EcgInterpreter.interpret(f),
    patient: const EcgPatientInfo(
      name: 'A. Benali',
      age: '54 ans',
      indication: 'Douleur thoracique aiguë',
    ),
  );
}

void main() {
  group('Compte rendu rédigé', () {
    test('un ECG normal produit un verdict normal et six rubriques', () {
      final report = narrative(findings(sV1: 10, rV6: 12));

      expect(report.verdict, EcgReportVerdict.normal);
      expect(report.isNormal, isTrue);
      expect(report.sections, hasLength(6));
      expect(report.sections.first.title, contains('Qualité technique'));
      expect(report.conclusion, contains('ne met pas en évidence d\'anomalie significative'));
      expect(report.urgentActions, isEmpty);
      expect(report.confidenceNote, contains('confiance'));
    });

    test('un SCA ST+ antérieur est rédigé avec une conduite à tenir', () {
      final report = narrative(
        findings(
          hr: 105,
          st: EcgStFinding.elevation,
          territory: EcgTerritory.anterior,
          stMm: 3,
          t: EcgTWave.peaked,
        ),
      );

      expect(report.verdict, EcgReportVerdict.abnormal);
      expect(report.verdictLabel, 'Électrocardiogramme anormal');
      expect(report.conclusion.toLowerCase(), contains('sus-décalage'));
      expect(report.urgentActions, isNotEmpty);
      final repolarisation =
          report.sections.firstWhere((s) => s.title.contains('repolarisation'));
      expect(repolarisation.body, contains('syndrome coronarien aigu'));
    });

    test('un tracé techniquement invalide reste non conclusif', () {
      final report = narrative(findings(avrNegative: false));

      expect(report.verdict, EcgReportVerdict.incomplete);
      expect(report.verdictLabel, contains('incomplète'));
      expect(report.conclusion, contains('qualité technique insuffisante'));
    });

    test('les caractères non imprimables sont remplacés dans le PDF', () async {
      final f = findings(qtMs: 620, hr: 55);
      final bytes = await EcgReportPdfService.buildBytes(
        findings: f,
        result: EcgInterpreter.interpret(f),
      );
      // La génération ne doit lever aucune exception d'encodage (≥, ≈, →…).
      expect(bytes.length, greaterThan(2000));
    });
  });

  group('Export PDF', () {
    test('le PDF est valide et contient l\'identité du patient', () async {
      final f = findings(sV1: 10, rV6: 12);
      final bytes = await EcgReportPdfService.buildBytes(
        findings: f,
        result: EcgInterpreter.interpret(f),
        patient: const EcgPatientInfo(
          name: 'A. Benali',
          age: '54 ans',
          indication: 'Bilan systématique',
        ),
        generatedAt: DateTime(2026, 11, 19, 14, 32),
      );

      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
      expect(bytes.length, greaterThan(4000));

      final document = PdfDocument(inputBytes: bytes);
      expect(document.pages.count, greaterThanOrEqualTo(1));
      final text = PdfTextExtractor(document).extractText();
      document.dispose();

      expect(text, contains('Compte rendu'));
      expect(text, contains('MEDSINA'));
      expect(text, contains('A. Benali'));
      expect(text, contains('CONCLUSION'));
      expect(text, contains('SURVEILLANCE'));
      expect(text, contains('Page 1 sur'));
    });

    test('un ECG anormal affiche la conduite à tenir', () async {
      final f = findings(
        hr: 128,
        atrial: EcgAtrialActivity.fibrillation,
        regularity: EcgRegularity.irregularlyIrregular,
        qtMs: 420,
      );
      final bytes = await EcgReportPdfService.buildBytes(
        findings: f,
        result: EcgInterpreter.interpret(f),
        patient: const EcgPatientInfo(name: 'M. Kaci', age: '71 ans'),
        generatedAt: DateTime(2026, 11, 19, 9, 5),
      );

      final document = PdfDocument(inputBytes: bytes);
      final text = PdfTextExtractor(document).extractText();
      document.dispose();

      expect(text, contains('CONDUITE À TENIR'));
      expect(text, contains('fibrillation atriale'));
    });

    test('un texte long est paginé sur plusieurs pages', () async {
      final f = findings(st: EcgStFinding.elevation, territory: EcgTerritory.anterior, stMm: 4);
      final longNotes = List<String>.generate(
        40,
        (i) => 'Antécédent $i : épisode douloureux documenté.',
      ).join(' ');
      final bytes = await EcgReportPdfService.buildBytes(
        findings: f,
        result: EcgInterpreter.interpret(f),
        patient: EcgPatientInfo(
          name: 'Patient avec un nom volontairement long pour l\'en-tête',
          age: '83 ans',
          indication: 'Douleur thoracique persistante depuis deux heures',
          notes: longNotes,
        ),
      );

      final document = PdfDocument(inputBytes: bytes);
      expect(document.pages.count, greaterThanOrEqualTo(2));
      document.dispose();
    });
  });
}
