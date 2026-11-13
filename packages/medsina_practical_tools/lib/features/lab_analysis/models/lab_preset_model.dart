import 'package:equatable/equatable.dart';

class LabPreset extends Equatable {
  final String id;
  final String title;
  final String category;
  final String icon;
  final String description;
  final String sampleText;
  final String? clinicalContext;

  const LabPreset({
    required this.id,
    required this.title,
    required this.category,
    required this.icon,
    required this.description,
    required this.sampleText,
    this.clinicalContext,
  });

  @override
  List<Object?> get props => [id, title, category, icon, description, sampleText, clinicalContext];
}

class LabCalculatorResult {
  final String title;
  final String value;
  final String unit;
  final String interpretation;
  final bool isAlert;

  const LabCalculatorResult({
    required this.title,
    required this.value,
    required this.unit,
    required this.interpretation,
    this.isAlert = false,
  });
}

class LabAnalysisHelper {
  /// Extracts deterministic calculations if parameters are present in text
  static List<LabCalculatorResult> extractCalculations(String text) {
    final results = <LabCalculatorResult>[];
    final lower = text.toLowerCase();

    // Helper regex to extract numeric values following parameter names
    double? findValue(List<String> patterns) {
      for (final p in patterns) {
        final reg = RegExp('$p\\s*[:=]?\\s*([0-9]+[.,]?[0-9]*)', caseSensitive: false);
        final match = reg.firstMatch(lower);
        if (match != null) {
          final raw = match.group(1)!.replaceAll(',', '.');
          final v = double.tryParse(raw);
          if (v != null) return v;
        }
      }
      return null;
    }

    final na = findValue(['natrémie', 'sodium', 'na\\+?', 'na']);
    final cl = findValue(['chlorémie', 'chlore', 'cl-?', 'cl']);
    final hco3 = findValue(['bicarbonates?', 'reserve alcaline', 'hco3-?', 'hco3', 'ra']);
    final glycemia = findValue(['glycémie', 'glycemie', 'glucose']);
    final ca = findValue(['calcémie', 'calcium', 'ca\\+?2?']);
    final alb = findValue(['albuminémie', 'albumine', 'alb']);
    final asat = findValue(['asat', 'got', 'tgo']);
    final alat = findValue(['alat', 'gpt', 'tgp']);

    // 1. Trou Anionique Plasmatique = Na - (Cl + HCO3)
    if (na != null && cl != null && hco3 != null && na > 50 && cl > 40 && hco3 > 2) {
      final ta = na - (cl + hco3);
      final isHigh = ta > 16;
      final isLow = ta < 8;
      String interp = 'Normal (8 - 16 mmol/L)';
      if (isHigh) {
        interp = 'Élevé ⚠️ (Acidose avec trou anionique : Acidocétose, Lactates, Toxiques, IRA)';
      } else if (isLow) {
        interp = 'Bas (Hypoalbuminémie majeure ou gammapathie)';
      }
      results.add(LabCalculatorResult(
        title: 'Trou Anionique Plasmatique (Na - [Cl + HCO3])',
        value: ta.toStringAsFixed(1),
        unit: 'mmol/L',
        interpretation: interp,
        isAlert: isHigh,
      ));
    }

    // 2. Natrémie Corrigée (Formule de Katz) = Na + 1.6 * (Glycémie g/L - 1)
    if (na != null && glycemia != null && glycemia > 1.2) {
      // If glycemia is given in mmol/L (e.g. > 15), convert to g/L (/ 5.55)
      final glyGPerL = glycemia > 15 ? (glycemia / 5.55) : glycemia;
      final naCorr = na + 1.6 * (glyGPerL - 1.0);
      final isHigh = naCorr > 145;
      final isLow = naCorr < 135;
      String interp = 'Normonatrémique';
      if (isHigh) interp = 'Hypernatrémie vraie démasquée ⚠️';
      if (isLow) interp = 'Hyponatrémie vraie persistante 🔻';
      results.add(LabCalculatorResult(
        title: 'Natrémie Corrigée de Katz (Hyperglycémie)',
        value: naCorr.toStringAsFixed(1),
        unit: 'mmol/L',
        interpretation: '$interp (glycémie réf: ${glyGPerL.toStringAsFixed(2)} g/L)',
        isAlert: isHigh || isLow,
      ));
    }

    // 3. Calcémie Corrigée = Ca (mmol/L) + 0.02 * (40 - Albuminémie g/L)
    if (ca != null && alb != null && alb < 40 && ca > 1.0 && ca < 5.0) {
      final caCorr = ca + 0.02 * (40.0 - alb);
      final isHigh = caCorr > 2.60;
      final isLow = caCorr < 2.20;
      String interp = 'Normal (2.20 - 2.60 mmol/L)';
      if (isHigh) interp = 'Hypercalcémie démasquée ⚠️';
      if (isLow) interp = 'Hypocalcémie vraie 🔻';
      results.add(LabCalculatorResult(
        title: 'Calcémie Corrigée sur l\'Albumine',
        value: caCorr.toStringAsFixed(2),
        unit: 'mmol/L',
        interpretation: interp,
        isAlert: isHigh || isLow,
      ));
    }

    // 4. Ratio De Ritis = ASAT / ALAT
    if (asat != null && alat != null && asat > 10 && alat > 10) {
      final ratio = asat / alat;
      String interp = 'Ratio standard (< 1, cytolyse à prédominance ALAT)';
      bool alert = false;
      if (ratio > 2.0) {
        interp = 'Ratio > 2 ⚠️ (Hépatopathie alcoolique aiguë, ischémie aiguë hépatique ou myocardique)';
        alert = true;
      } else if (ratio > 1.0) {
        interp = 'Ratio 1 - 2 (Évolution possible vers cirrhose ou atteinte mixte)';
      }
      results.add(LabCalculatorResult(
        title: 'Ratio De Ritis (ASAT / ALAT)',
        value: ratio.toStringAsFixed(2),
        unit: '',
        interpretation: interp,
        isAlert: alert,
      ));
    }

    return results;
  }

  /// Master list of high-yield presets for Algerian medical residents
  static const List<LabPreset> defaultPresets = [
    LabPreset(
      id: 'dka',
      title: 'Acidocétose Diabétique Inaugurale',
      category: 'Urgences Métaboliques',
      icon: 'bolt_rounded',
      description: 'Glycémie 4.8 g/L, acidose métabolique sévère avec trou anionique élargi et dyskaliémie.',
      clinicalContext: 'Patient de 22 ans, asthénie brutale, polypnée de Kussmaul, odeur acétonique de l\'haleine.',
      sampleText: '''Glycémie : 4.85 g/L
Gazométrie artérielle :
  pH : 7.12
  PaO2 : 98 mmHg
  PaCO2 : 21 mmHg
  HCO3- : 8.5 mmol/L
  SaO2 : 98%
Ionogramme sanguin :
  Sodium (Na+) : 131 mmol/L
  Potassium (K+) : 5.8 mmol/L
  Chlore (Cl-) : 96 mmol/L
Fonction rénale :
  Urée : 14.2 mmol/L
  Créatinine : 165 µmol/L
BU : Cétonurie ++++, Glycosurie ++++''',
    ),
    LabPreset(
      id: 'aki_hyperk',
      title: 'IRA & Hyperkaliémie Menacée',
      category: 'Néphrologie & Réanimation',
      icon: 'emergency_rounded',
      description: 'Hyperkaliémie sévère à 6.6 mmol/L avec altération aiguë du DFG.',
      clinicalContext: 'Patiente de 72 ans hypertendue sous IEC et Spironolactone, anurie depuis 18 heures.',
      sampleText: '''Ionogramme sanguin :
  Potassium (K+) : 6.6 mmol/L
  Sodium (Na+) : 136 mmol/L
  Chlore (Cl-) : 102 mmol/L
  Bicarbonates : 15 mmol/L
Fonction rénale :
  Créatinine : 510 µmol/L
  Urée sanguine : 34 mmol/L
NFS :
  Hémoglobine : 10.4 g/dL
  Globules blancs : 8 400 /mm³
  Plaquettes : 210 000 /mm³''',
    ),
    LabPreset(
      id: 'anemia_ferriprive',
      title: 'Anémie Microcytaire Arégénérative',
      category: 'Hématologie',
      icon: 'bloodtype_rounded',
      description: 'Anémie sévère hypochrome microcytaire avec ferritinémie effondrée.',
      clinicalContext: 'Femme de 36 ans, pâleur cutanéo-muqueuse, ménorragies abondantes, dyspnée d\'effort.',
      sampleText: '''NFS / Hémogramme :
  Hémoglobine : 7.4 g/dL
  Hématocrite : 24%
  VGM : 63 fL
  CCMH : 28 g/dL
  TCMH : 21 pg
  Réticulocytes : 32 000 /mm³
  Globules Blancs : 6 200 /mm³
  Plaquettes : 490 000 /mm³
Bilan Martial :
  Ferritine sérique : 6 µg/L
  Fer sérique : 4 µmol/L
  Transferrine : 3.8 g/L
  Capacité totale de fixation (CTF) : 95 µmol/L
  Coefficient de saturation (CST) : 4.2%''',
    ),
    LabPreset(
      id: 'hepatic_cytolysis',
      title: 'Cytolyse Hépatique Aiguë',
      category: 'Gastro-Hépatologie',
      icon: 'local_hospital_rounded',
      description: 'Élévation massive des transaminases > 20x la normale avec cholestase débutante.',
      clinicalContext: 'Homme de 45 ans, ictère cutanéo-muqueux d\'apparition brutale, urines foncées, selles décolorées.',
      sampleText: '''Bilan Hépatique :
  ALAT (TGP) : 1240 UI/L
  ASAT (TGO) : 880 UI/L
  Bilirubine Totale : 92 µmol/L
  Bilirubine Conjuguée : 74 µmol/L
  Phosphatases Alcalines (PAL) : 210 UI/L
  Gamma-GT : 195 UI/L
Hémostase :
  Taux de Prothrombine (TP) : 58%
  Facteur V : 62%
  INR : 1.48
Lipasémie : 38 UI/L''',
    ),
    LabPreset(
      id: 'septic_shock',
      title: 'Sepsis Grave & Choc Métabolique',
      category: 'Infectiologie & UMC',
      icon: 'warning_amber_rounded',
      description: 'Hyperlactatémie majeure, procalcitonine et CRP élevées, leucocytose avec PNN.',
      clinicalContext: 'Patient de 68 ans fébrile à 39.4°C, frissons solennels, marbrures aux genoux, PAS à 75 mmHg.',
      sampleText: '''Marqueurs inflammatoires :
  Procalcitonine (PCT) : 28.5 ng/mL
  Protéine C-Réactive (CRP) : 310 mg/L
Lactates plasmatiques : 4.8 mmol/L
Gazométrie artérielle :
  pH : 7.24
  PaO2 : 68 mmHg (sous air)
  PaCO2 : 29 mmHg
  HCO3- : 13.5 mmol/L
NFS :
  Leucocytes : 24 500 /mm³
  Polynucléaires Neutrophiles : 89% (21 800 /mm³)
  Plaquettes : 98 000 /mm³
Hémostase :
  TP : 52%
  D-Dimères : 4200 ng/mL
  Fibrinogène : 1.8 g/L''',
    ),
    LabPreset(
      id: 'shunt_pe',
      title: 'Effet Shunt / Suspicion d\'Embolie Pulmonaire',
      category: 'Cardio-Pneumologie',
      icon: 'air_rounded',
      description: 'Hypoxémie-hypocapnie alcalosique à la GDS avec D-Dimères très positifs.',
      clinicalContext: 'Femme de 52 ans, douleur basi-thoracique brutale à coup de poignard, angoisse, tachycardie à 118 bpm.',
      sampleText: '''Gazométrie Artérielle (air ambiant) :
  pH : 7.49
  PaO2 : 61 mmHg
  PaCO2 : 27 mmHg
  HCO3- : 23 mmol/L
  SaO2 : 91%
Marqueurs Cardiaques & Thrombose :
  D-Dimères : 3450 ng/mL
  Troponine hypersensible (hs-cTnI) : 38 ng/L (norme < 14)
  NT-proBNP : 720 pg/mL
NFS :
  Hémoglobine : 13.6 g/dL
  Plaquettes : 245 000 /mm³''',
    ),
  ];
}

