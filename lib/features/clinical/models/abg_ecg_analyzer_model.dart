import 'dart:math' as math;
import 'package:equatable/equatable.dart';

/// Résultat complet d'une analyse de Gazométrie Artérielle (GDS)
class AbgAnalysisResult extends Equatable {
  final String primaryDisorder;
  final String compensationStatus;
  final String oxygenationStatus;
  final double? anionGap;
  final double? correctedAnionGap;
  final double? expectedPaCo2Winter;
  final double? deltaDeltaRatio;
  final double? pao2Fio2Ratio;
  final List<String> clinicalAlerts;
  final List<String> probableEtiologies;

  const AbgAnalysisResult({
    required this.primaryDisorder,
    required this.compensationStatus,
    required this.oxygenationStatus,
    this.anionGap,
    this.correctedAnionGap,
    this.expectedPaCo2Winter,
    this.deltaDeltaRatio,
    this.pao2Fio2Ratio,
    this.clinicalAlerts = const [],
    this.probableEtiologies = const [],
  });

  @override
  List<Object?> get props => [
        primaryDisorder,
        compensationStatus,
        oxygenationStatus,
        anionGap,
        expectedPaCo2Winter,
      ];
}

class AbgPresetCase {
  final String title;
  final double ph;
  final double paco2;
  final double hco3;
  final double pao2;
  final double fio2Percent;
  final double na;
  final double cl;
  final double albuminGPerL;
  final double lactates;

  const AbgPresetCase({
    required this.title,
    required this.ph,
    required this.paco2,
    required this.hco3,
    required this.pao2,
    this.fio2Percent = 21.0,
    this.na = 140.0,
    this.cl = 104.0,
    this.albuminGPerL = 40.0,
    this.lactates = 1.2,
  });
}

class AbgAnalysisEngine {
  static const List<AbgPresetCase> presetCases = [
    AbgPresetCase(
      title: 'Acidocétose Diabétique',
      ph: 7.16,
      paco2: 24.0,
      hco3: 8.5,
      pao2: 96.0,
      na: 134.0,
      cl: 98.0,
      lactates: 2.6,
    ),
    AbgPresetCase(
      title: 'Décompensation BPCO',
      ph: 7.26,
      paco2: 68.0,
      hco3: 30.0,
      pao2: 52.0,
      fio2Percent: 28.0,
      na: 139.0,
      cl: 97.0,
    ),
    AbgPresetCase(
      title: 'Choc Septique / Lactique',
      ph: 7.21,
      paco2: 33.0,
      hco3: 13.0,
      pao2: 72.0,
      fio2Percent: 40.0,
      na: 138.0,
      cl: 102.0,
      lactates: 5.8,
    ),
    AbgPresetCase(
      title: 'Vomissements Prolongés',
      ph: 7.53,
      paco2: 47.0,
      hco3: 38.0,
      pao2: 88.0,
      na: 136.0,
      cl: 88.0,
    ),
  ];

  static AbgAnalysisResult analyze({
    required double ph,
    required double paco2,
    required double hco3,
    double pao2 = 90.0,
    double fio2Percent = 21.0,
    double? na,
    double? cl,
    double albuminGPerL = 40.0,
    double? lactates,
  }) {
    final alerts = <String>[];
    final etiologies = <String>[];

    // 1. Trou Anionique (TA = Na - (Cl + HCO3))
    double? anionGap;
    double? correctedAg;
    double? deltaRatio;
    if (na != null && cl != null) {
      anionGap = na - (cl + hco3);
      // Correction de Figge : TA corrigé = TA + 0.25 * (40 - Albumine en g/L)
      correctedAg = anionGap + 0.25 * (40.0 - albuminGPerL);
      if (correctedAg > 16.0 && (24.0 - hco3) > 1.0) {
        deltaRatio = (correctedAg - 12.0) / (24.0 - hco3);
      }
    }

    // 2. Rapport PaO2 / FiO2 (Horowitz)
    final fio2 = (fio2Percent / 100.0).clamp(0.21, 1.0);
    final pao2Fio2 = pao2 / fio2;
    String oxyStatus;
    if (pao2 < 60) {
      oxyStatus = 'Hypoxémie sévère (PaO2 < 60 mmHg) • PaO2/FiO2 = ${pao2Fio2.toStringAsFixed(0)}';
      alerts.add('Oxygénothérapie urgente requise (cible SpO2 94-98%, ou 88-92% si BPCO hypercapnique).');
    } else if (pao2Fio2 < 100) {
      oxyStatus = 'SDRA Sévère (PaO2/FiO2 = ${pao2Fio2.toStringAsFixed(0)} < 100)';
    } else if (pao2Fio2 < 200) {
      oxyStatus = 'SDRA Modéré (PaO2/FiO2 = ${pao2Fio2.toStringAsFixed(0)})';
    } else if (pao2Fio2 < 300) {
      oxyStatus = 'Hypoxémie / SDRA Léger (PaO2/FiO2 = ${pao2Fio2.toStringAsFixed(0)})';
    } else {
      oxyStatus = 'Hématose normale (PaO2/FiO2 = ${pao2Fio2.toStringAsFixed(0)})';
    }

    if (lactates != null && lactates >= 2.0) {
      alerts.add(
        lactates >= 4.0
            ? 'Hyperlactatémie critique (${lactates.toStringAsFixed(1)} mmol/L) : hypoperfusion tissulaire / état de choc !'
            : 'Hyperlactatémie modérée (${lactates.toStringAsFixed(1)} mmol/L) à contrôler.',
      );
    }

    // 3. Diagnostic du trouble acido-basique primaire & compensation
    String primary;
    String compensation;
    double? winterExpected;

    if (ph < 7.35) {
      // ACIDÉMIE
      if (hco3 < 22 && paco2 <= 45) {
        final effectiveAg = correctedAg ?? anionGap ?? 12.0;
        final isHighAg = effectiveAg > 16.0;
        primary = isHighAg
            ? 'Acidose Métabolique à Trou Anionique Élevé (TA = ${effectiveAg.toStringAsFixed(1)})'
            : 'Acidose Métabolique Hyperchlorémique (à TA normal)';

        winterExpected = 1.5 * hco3 + 8.0;
        if (paco2 < winterExpected - 2.0) {
          compensation =
              'Trouble MIXTE : Alcalose respiratoire associée (PaCO2 mesurée ${paco2.toStringAsFixed(0)} < Winter ${winterExpected.toStringAsFixed(0)} ± 2).';
        } else if (paco2 > winterExpected + 2.0) {
          compensation =
              'Trouble MIXTE : Acidose respiratoire associée (PaCO2 mesurée ${paco2.toStringAsFixed(0)} > Winter ${winterExpected.toStringAsFixed(0)} ± 2).';
        } else {
          compensation =
              'Compensation respiratoire adaptée selon Winter (PaCO2 attendue : ${(winterExpected - 2).toStringAsFixed(0)}–${(winterExpected + 2).toStringAsFixed(0)} mmHg).';
        }

        if (isHighAg) {
          etiologies.addAll([
            'KUSMAUL : Acidocétose (diabétique, alcoolique, jeûne)',
            'Insuffisance rénale aiguë/chronique (Urémie)',
            'Acidose lactique (Choc, hypoxie, Metformine)',
            'Intoxications : Salicylés, Méthanol, Éthylène glycol',
          ]);
        } else {
          etiologies.addAll([
            'Pertes digestives de HCO3- : Diarrhées profuses, fistule biliaire/pancréatique',
            'Acidoses tubulaires rénales (Types 1, 2, 4)',
            'Perfusions massives de NaCl 0,9%',
          ]);
        }
      } else if (paco2 > 45 && hco3 >= 22) {
        primary = 'Acidose Respiratoire (Hypercapnie)';
        final acuteExpectedHco3 = 24.0 + ((paco2 - 40.0) / 10.0) * 1.0;
        final chronicExpectedHco3 = 24.0 + ((paco2 - 40.0) / 10.0) * 3.5;
        if ((hco3 - chronicExpectedHco3).abs() <= 2.5 && hco3 > 27) {
          compensation = 'Acidose respiratoire CHRONIQUE compensée (évocateur de BPCO).';
        } else if ((hco3 - acuteExpectedHco3).abs() <= 2.0) {
          compensation = 'Acidose respiratoire AIGUË (non encore compensée par le rein).';
        } else {
          compensation = 'Acidose respiratoire avec composante métabolique associée.';
        }
        etiologies.addAll([
          'Décompensation aiguë de BPCO / Asthme aigu grave',
          'Dépression respiratoire centrale (Opioïdes, Benzodiazépines, AVC)',
          'Épuisement musculaire / Myasthénie / Guillain-Barré',
        ]);
      } else {
        primary = 'Acidose Mixte (Métabolique + Respiratoire)';
        compensation = 'Défaillance combinée : HCO3- abaissés ET PaCO2 élevée.';
        alerts.add('Acidémie sévère mixte : risque d\'épuisement respiratoire imminent (discuter VNI ou IOT).');
      }
    } else if (ph > 7.45) {
      // ALCALÉMIE
      if (hco3 > 26 && paco2 >= 35) {
        primary = 'Alcalose Métabolique';
        final expectedPaco2 = 40.0 + 0.7 * (hco3 - 24.0);
        if ((paco2 - expectedPaco2).abs() <= 3.0) {
          compensation = 'Compensation respiratoire adaptée (PaCO2 attendue ≈ ${expectedPaco2.toStringAsFixed(0)} mmHg).';
        } else if (paco2 < expectedPaco2 - 3.0) {
          compensation = 'Trouble MIXTE : Alcalose respiratoire associée.';
        } else {
          compensation = 'Hypoventilation alvéolaire marquée associée.';
        }
        etiologies.addAll([
          'Pertes digestives hautes : Vomissements, aspiration gastrique',
          'Diurétiques de l\'anse (Furosémide) / Thiazidiques',
          'Hyperaldostéronisme / Hypokaliémie sévère',
        ]);
      } else if (paco2 < 35 && hco3 <= 26) {
        primary = 'Alcalose Respiratoire (Hypocapnie)';
        compensation = hco3 < 20
            ? 'Alcalose respiratoire chronique ou compensée.'
            : 'Alcalose respiratoire aiguë (hyperventilation).';
        etiologies.addAll([
          'Embolie pulmonaire (à éliminer en priorité en garde !)',
          'Hypoxémie, Pneumonie, Crise d\'asthme débutante',
          'Sepsis débutant, Fièvre, Douleur, Attaque de panique',
        ]);
      } else {
        primary = 'Alcalose Mixte (Métabolique + Respiratoire)';
        compensation = 'Élévation conjointe du pH par excès de HCO3- et hypocapnie.';
      }
    } else {
      // pH normal (7.35 - 7.45)
      if ((paco2 < 35 || paco2 > 45) && (hco3 < 22 || hco3 > 26)) {
        primary = 'Trouble Acido-Basique Compensé ou Mixte Équilibré';
        compensation = 'pH normal malgré des variations opposées de PaCO2 et HCO3-.';
      } else {
        primary = 'Équilibre Acido-Basique Normal';
        compensation = 'Aucune anomalie significative du pH, de la PaCO2 ou des bicarbonates.';
      }
    }

    if (ph < 7.15) {
      alerts.add('Acidémie menaçante (pH < 7,15) : risque de dépression myocardique et d\'hyperkaliémie.');
    } else if (ph > 7.60) {
      alerts.add('Alcalémie sévère (pH > 7,60) : risque de troubles du rythme et tétanie hypocalcémique.');
    }

    return AbgAnalysisResult(
      primaryDisorder: primary,
      compensationStatus: compensation,
      oxygenationStatus: oxyStatus,
      anionGap: anionGap,
      correctedAnionGap: correctedAg,
      expectedPaCo2Winter: winterExpected,
      deltaDeltaRatio: deltaRatio,
      pao2Fio2Ratio: pao2Fio2,
      clinicalAlerts: alerts,
      probableEtiologies: etiologies,
    );
  }
}

/// Moteur de calcul ECG (Fréquence, QTc Bazett & Fridericia) + Guide 7 étapes
class EcgAnalysisHelper {
  static double computeHeartRateFromLargeBoxes(double largeBoxes) {
    if (largeBoxes <= 0) return 0.0;
    return 300.0 / largeBoxes;
  }

  static double computeQtcBazett({required double qtMs, required double heartRateBpm}) {
    if (heartRateBpm <= 0) return 0.0;
    final rrSec = 60.0 / heartRateBpm;
    return qtMs / math.sqrt(rrSec);
  }

  static double computeQtcFridericia({required double qtMs, required double heartRateBpm}) {
    if (heartRateBpm <= 0) return 0.0;
    final rrSec = 60.0 / heartRateBpm;
    return qtMs / math.pow(rrSec, 1.0 / 3.0);
  }

  static String interpretQtc(double qtcMs, {bool isFemale = false}) {
    final upperNormal = isFemale ? 460.0 : 450.0;
    if (qtcMs >= 500.0) {
      return 'QTc CRITIQUE (≥ 500 ms) : Risque majeur de Torsades de Pointes ! Arrêter tout médicament allongeant le QT et corriger K+/Mg2+.';
    } else if (qtcMs > upperNormal) {
      return 'QTc allongé (> ${upperNormal.toInt()} ms) : Surveillance scopique et contrôle ionogramme (K+, Ca2+, Mg2+).';
    } else if (qtcMs < 340.0) {
      return 'QTc court (< 340 ms) : Rechercher une hypercalcémie ou un syndrome du QT court.';
    }
    return 'QTc dans les limites normales.';
  }

  static const List<Map<String, String>> sevenStepsChecklist = [
    {
      'step': '1. Rythme',
      'detail': 'Sinusal ? (Onde P positive en DI, DII, négative en aVR, suivie d\'un QRS). Régulier ou irrégulier (FA si irrégulier sans onde P) ?',
    },
    {
      'step': '2. Fréquence Cardiaque',
      'detail': '300 / nombre de grands carreaux entre 2 R. Normale : 60–100 bpm. Bradycardie < 60, Tachycardie > 100.',
    },
    {
      'step': '3. Axe du QRS',
      'detail': 'Normal (-30° à +90°) : QRS positif en DI et DII/aVF. Déviation gauche (DI+, aVF-) ou droite (DI-, aVF+).',
    },
    {
      'step': '4. Espace PR (N : 120–200 ms)',
      'detail': '3 à 5 petits carreaux. BAV 1er degré si PR > 200 ms. Pré-excitation (WPW) si PR < 120 ms + onde delta.',
    },
    {
      'step': '5. Complexe QRS (N < 120 ms)',
      'detail': 'QRS fin (< 3 petits carreaux) vs QRS large (≥ 120 ms : BBG, BBD ou Tachycardie Ventriculaire).',
    },
    {
      'step': '6. Segment ST & Territoires',
      'detail': 'Sus-décalage ≥ 1 mm dans ≥ 2 dérivations contiguës (≥ 2 mm en V2-V3) = SCA ST+ ! Antérieur (V1-V4), Inférieur (DII-DIII-aVF), Latéral (DI-aVL-V5-V6).',
    },
    {
      'step': '7. Onde T & Espace QTc',
      'detail': 'Onde T ample pointue = hyperkaliémie ou ischémie sous-endocardique. QTc normal < 450 ms (H) / 460 ms (F).',
    },
  ];
}
