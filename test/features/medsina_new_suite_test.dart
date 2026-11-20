import 'package:flutter_test/flutter_test.dart';
import 'package:medsina/features/clinical/models/abg_ecg_analyzer_model.dart';
import 'package:medsina/features/clinical/models/clinical_procedure_logbook_model.dart';
import 'package:medsina/features/clinical/models/pse_calculator_model.dart';
import 'package:medsina/features/prescription/models/medical_templates_model.dart';
import 'package:medsina/features/prescription/services/medical_document_pdf_exporter.dart';
import 'package:medsina/features/revision/models/mnemonic_reflex_model.dart';
import 'package:medsina/features/revision/models/residency_rank_simulator_model.dart';
import 'package:medsina/features/revision/services/qcm_duel_service.dart';
import 'package:medsina/features/teacher_space/models/teacher_workspace_model.dart';
import 'package:medsina/features/teacher_space/services/teacher_workspace_service.dart';

void main() {
  group('1. Calculateur PSE & Dilutions d\'Urgence', () {
    test('Noradrénaline 8 mg / 48 ml à 0.20 γ/kg/min pour 70 kg => 5.04 ml/h', () {
      final nora = PseProtocolsCatalog.allProtocols
          .firstWhere((p) => p.id == 'pse_noradrenaline');
      final flow = nora.calculateFlowRateMlPerHour(
        doseValue: 0.20,
        weightKg: 70.0,
        dilution: nora.dilutions.first, // 8 mg / 48 ml = 166.666 γ/ml
      );
      expect(flow, closeTo(5.04, 0.05));

      final backDose = nora.calculateDeliveredDose(
        flowRateMlPerHour: flow,
        weightKg: 70.0,
        dilution: nora.dilutions.first,
      );
      expect(backDose, closeTo(0.20, 0.005));
    });

    test('Insuline IVSE 50 UI / 50 ml à 0.10 UI/kg/h pour 65 kg => 6.5 ml/h', () {
      final ins = PseProtocolsCatalog.allProtocols
          .firstWhere((p) => p.id == 'pse_insuline');
      final flow = ins.calculateFlowRateMlPerHour(
        doseValue: 0.10,
        weightKg: 65.0,
      );
      expect(flow, closeTo(6.5, 0.01));
    });
  });

  group('2. Interpréteur Gaz du Sang (GDS) & ECG', () {
    test('Acidocétose diabétique : Acidose métabolique à TA élevé + Winter', () {
      final res = AbgAnalysisEngine.analyze(
        ph: 7.16,
        paco2: 24.0,
        hco3: 8.5,
        pao2: 96.0,
        na: 134.0,
        cl: 98.0,
      );
      expect(res.primaryDisorder, contains('Trou Anionique Élevé'));
      expect(res.anionGap, closeTo(27.5, 0.1));
      expect(res.expectedPaCo2Winter, closeTo(20.75, 0.1));
    });

    test('Calcul QTc Bazett & Fridericia', () {
      final hr = EcgAnalysisHelper.computeHeartRateFromLargeBoxes(4.0);
      expect(hr, closeTo(75.0, 0.1));
      final qtc = EcgAnalysisHelper.computeQtcBazett(qtMs: 400.0, heartRateBpm: 60.0);
      expect(qtc, closeTo(400.0, 0.1));
      expect(EcgAnalysisHelper.interpretQtc(515.0), contains('CRITIQUE'));
    });
  });

  group('3. Ordonnancier Type & Certificats PDF Algérie', () {
    test('Ajustement pédiatrique mg/kg/j et génération PDF A4 valide', () async {
      final angine = MedicalTemplatesCatalog.prescriptions
          .firstWhere((p) => p.id == 'ordo_angine_strepto');
      final formatted = angine.lines.first.formatForPatient(
        isPediatric: true,
        weightKg: 20.0,
      );
      expect(formatted, contains('1000 mg/jour'));

      final bytes = await MedicalDocumentPdfExporter.buildA4DocumentBytes(
        documentTitle: 'CERTIFICAT CBV',
        doctorName: 'Dr. Hafedh',
        establishment: 'CHU Blida',
        city: 'Blida',
        patientName: 'Patient Test',
        patientMeta: '(30 ans)',
        bodyContent: 'Contenu test certificat médical descriptif.',
      );
      expect(bytes.length, greaterThan(500));
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });

    test('Sérialisation JSON PrescriptionTemplate et parsing catalogue dynamique', () {
      const jsonPayload = '''
      [
        {
          "id": "ordo_oma_test",
          "title": "Otite Moyenne Aiguë Purulente",
          "specialty": "ORL / Pédiatrie",
          "clinical_context": "OMA collectée fébrile",
          "supports_pediatric_weight": true,
          "lines": [
            {
              "dci_name": "Amoxicilline",
              "commercial_name_dz": "Clamoxyl® / Amoxil®",
              "formulation": "Susp. buv. 500 mg/5 ml",
              "adult_dosage": "1 g x 3/j",
              "pediatric_mg_per_kg_per_day": 80,
              "max_pediatric_daily_mg": 3000,
              "duration": "8 jours",
              "clinical_note": "Réévaluer à 48-72h"
            },
            {
              "dci_name": "Paracétamol",
              "commercial_name_dz": "Doliprane®",
              "formulation": "Sirop pédiatrique",
              "adult_dosage": "1 g x 3/j",
              "pediatric_mg_per_kg_per_day": "60",
              "max_pediatric_daily_mg": 2000,
              "duration": "3 jours",
              "clinical_note": null
            }
          ],
          "patient_advice": ["Hydratation régulière", "DRP au sérum physiologique"],
          "contraindications_alert": ["Vérifier absence d'allergie aux bêta-lactamines"],
          "scientific_references": "SPILF / SFP OMA"
        }
      ]
      ''';

      final parsed = MedicalTemplatesCatalog.parsePrescriptionsJson(jsonPayload);
      expect(parsed.length, 1);

      final oma = parsed.first;
      expect(oma.id, 'ordo_oma_test');
      expect(oma.supportsPediatricWeight, isTrue);
      expect(oma.patientAdvice.length, 2);
      expect(oma.contraindicationsAlert.single, contains('bêta-lactamines'));
      expect(oma.scientificReferences, 'SPILF / SFP OMA');

      // Numeric pediatric_mg_per_kg_per_day (80 mg/kg/j * 20 kg = 1600 mg/j)
      expect(
        oma.lines[0].formatForPatient(isPediatric: true, weightKg: 20.0),
        contains('1600 mg/jour'),
      );

      // Capping check on string pediatric_mg_per_kg_per_day (60 mg/kg/j * 40 kg = 2400 -> capped at 2000)
      expect(
        oma.lines[1].formatForPatient(isPediatric: true, weightKg: 40.0),
        contains('2000 mg/jour'),
      );

      // Round-trip toJson -> fromJson
      final roundTrip = PrescriptionTemplate.fromJson(oma.toJson());
      expect(roundTrip.id, oma.id);
      expect(roundTrip.lines.length, 2);
      expect(roundTrip.lines.first.pediatricMgPerKgPerDay, '80');
      expect(roundTrip.scientificReferences, 'SPILF / SFP OMA');
    });
  });

  group('4. Mnémotechniques, 5. Duel QCM, 6. Logbook & 7. Simulateur', () {
    test('Catalogue Mnémotechniques, Codes Duel, Guides Logbook & Seuils Résidanat', () {
      expect(MnemonicsReflexRepository.builtinMnemonics.length, greaterThanOrEqualTo(6));
      expect(MnemonicsReflexRepository.builtinReflexes.length, greaterThanOrEqualTo(8));
      expect(QcmDuelService.generateChallengeCode(seed: 42), startsWith('DZ-'));
      expect(ProcedureLogbookRepository.guides.length, greaterThanOrEqualTo(5));

      final avg = ResidencyRankSimulatorData.computeWeightedAverage(
        sciencesFondamentales: 15.0,
        pathologieMedicale: 16.0,
        pathologieChirurgicale: 15.5,
      );
      expect(avg, closeTo(15.5, 0.01));
      expect(ResidencyRankSimulatorData.estimateRank(avg), lessThan(150));
    });
  });

  group('8. Espace Prof / Enseignant HU & Évaluation QROC', () {
    test('Évaluation automatique par mots-clés d\'une QROC et génération code examen', () {
      const qroc = CustomExamQuestion(
        id: 'qroc_1',
        format: CustomQuestionFormat.qroc,
        questionText: 'Traitement de reperfusion si délai > 120 min ?',
        qrocReferenceAnswer: 'Fibrinolyse intraveineuse',
        qrocExpectedKeywords: ['fibrinolyse', 'intraveineuse'],
      );
      expect(qroc.evaluateQrocAnswer('On réalise une fibrinolyse intraveineuse'), 1.0);
      expect(qroc.evaluateQrocAnswer('Fibrinolyse'), 0.5);
      expect(qroc.evaluateQrocAnswer('Repos au lit'), 0.0);

      final code = TeacherWorkspaceService.generateExamAccessCode('Cardiologie');
      expect(code, startsWith('EMD-CAR-'));
    });
  });
}
