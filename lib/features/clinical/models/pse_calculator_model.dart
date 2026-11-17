import 'package:equatable/equatable.dart';

/// Unité de posologie pour un protocole de Pousse-Seringue Électrique (PSE)
enum PseDoseUnit {
  mcgPerKgPerMin, // γ/kg/min (Noradrénaline, Adrénaline, Dobutamine, Dopamine)
  mcgPerKgPerHour, // γ/kg/h (Fentanyl, Sufentanil)
  mgPerHour, // mg/h (Nicardipine/Loxen, Cordarone, Midazolam, Furosémide)
  uiPerKgPerHour, // UI/kg/h (Insuline IVSE, Héparine HNF)
  uiPerHour, // UI/h (Héparine HNF standard adulte)
}

extension PseDoseUnitExtension on PseDoseUnit {
  String get label {
    switch (this) {
      case PseDoseUnit.mcgPerKgPerMin:
        return 'γ/kg/min';
      case PseDoseUnit.mcgPerKgPerHour:
        return 'γ/kg/h';
      case PseDoseUnit.mgPerHour:
        return 'mg/h';
      case PseDoseUnit.uiPerKgPerHour:
        return 'UI/kg/h';
      case PseDoseUnit.uiPerHour:
        return 'UI/h';
    }
  }

  bool get isWeightDependent {
    return this == PseDoseUnit.mcgPerKgPerMin ||
        this == PseDoseUnit.mcgPerKgPerHour ||
        this == PseDoseUnit.uiPerKgPerHour;
  }
}

/// Option de dilution standard en seringue de garde (50 ml ou 20 ml)
class PseDilutionPreset extends Equatable {
  final String id;
  final String label;
  final String preparationInstruction;
  final double totalAmountMgOrUi; // en mg ou en UI dans la seringue
  final double syringeVolumeMl; // ex: 50 ml ou 48 ml
  final String solvent; // 'SG 5%', 'NaCl 0,9%', 'Pur ou SG 5% / NaCl 0,9%'

  const PseDilutionPreset({
    required this.id,
    required this.label,
    required this.preparationInstruction,
    required this.totalAmountMgOrUi,
    required this.syringeVolumeMl,
    required this.solvent,
  });

  /// Concentration finale en mg/ml (ou UI/ml)
  double get concentrationPerMl =>
      syringeVolumeMl > 0 ? totalAmountMgOrUi / syringeVolumeMl : 0.0;

  /// Concentration finale en µg/ml (γ/ml)
  double get concentrationMcgPerMl => concentrationPerMl * 1000.0;

  @override
  List<Object?> get props => [
        id,
        label,
        preparationInstruction,
        totalAmountMgOrUi,
        syringeVolumeMl,
        solvent,
      ];
}

/// Modèle d'un médicament injectable au Pousse-Seringue Électrique (PSE)
class PseDrugProtocol extends Equatable {
  final String id;
  final String dciName;
  final String commercialNamesDz;
  final String category;
  final String ampoulePresentation;
  final PseDoseUnit doseUnit;
  final double minDose;
  final double maxDose;
  final double defaultDose;
  final double stepDose;
  final List<PseDilutionPreset> dilutions;
  final List<String> indications;
  final List<String> redFlagsAndPrecautions;
  final String venousAccessRequirement;

  const PseDrugProtocol({
    required this.id,
    required this.dciName,
    required this.commercialNamesDz,
    required this.category,
    required this.ampoulePresentation,
    required this.doseUnit,
    required this.minDose,
    required this.maxDose,
    required this.defaultDose,
    required this.stepDose,
    required this.dilutions,
    required this.indications,
    required this.redFlagsAndPrecautions,
    required this.venousAccessRequirement,
  });

  /// Calcule la vitesse du PSE en ml/h à partir de la dose cible et du poids (kg)
  double calculateFlowRateMlPerHour({
    required double doseValue,
    required double weightKg,
    PseDilutionPreset? dilution,
  }) {
    final activeDilution = dilution ?? dilutions.first;
    final concMgOrUiPerMl = activeDilution.concentrationPerMl;
    if (concMgOrUiPerMl <= 0) return 0.0;

    switch (doseUnit) {
      case PseDoseUnit.mcgPerKgPerMin:
        // Débit (ml/h) = [Dose (γ/kg/min) * Poids (kg) * 60] / Concentration (γ/ml)
        final concMcg = activeDilution.concentrationMcgPerMl;
        return (doseValue * weightKg * 60.0) / concMcg;
      case PseDoseUnit.mcgPerKgPerHour:
        final concMcg = activeDilution.concentrationMcgPerMl;
        return (doseValue * weightKg) / concMcg;
      case PseDoseUnit.mgPerHour:
      case PseDoseUnit.uiPerHour:
        // Débit (ml/h) = Dose (mg/h ou UI/h) / Concentration (mg/ml ou UI/ml)
        return doseValue / concMgOrUiPerMl;
      case PseDoseUnit.uiPerKgPerHour:
        // Débit (ml/h) = [Dose (UI/kg/h) * Poids (kg)] / Concentration (UI/ml)
        return (doseValue * weightKg) / concMgOrUiPerMl;
    }
  }

  /// Calcule la dose délivrée à partir d'une vitesse PSE affichée (ml/h)
  double calculateDeliveredDose({
    required double flowRateMlPerHour,
    required double weightKg,
    PseDilutionPreset? dilution,
  }) {
    final activeDilution = dilution ?? dilutions.first;
    final concMgOrUiPerMl = activeDilution.concentrationPerMl;
    if (concMgOrUiPerMl <= 0 || weightKg <= 0) return 0.0;

    switch (doseUnit) {
      case PseDoseUnit.mcgPerKgPerMin:
        final concMcg = activeDilution.concentrationMcgPerMl;
        return (flowRateMlPerHour * concMcg) / (weightKg * 60.0);
      case PseDoseUnit.mcgPerKgPerHour:
        final concMcg = activeDilution.concentrationMcgPerMl;
        return (flowRateMlPerHour * concMcg) / weightKg;
      case PseDoseUnit.mgPerHour:
      case PseDoseUnit.uiPerHour:
        return flowRateMlPerHour * concMgOrUiPerMl;
      case PseDoseUnit.uiPerKgPerHour:
        return (flowRateMlPerHour * concMgOrUiPerMl) / weightKg;
    }
  }

  @override
  List<Object?> get props => [id, dciName, commercialNamesDz, doseUnit];
}

/// Catalogue officiel des protocoles PSE de Garde en Algérie
class PseProtocolsCatalog {
  static const List<PseDrugProtocol> allProtocols = [
    PseDrugProtocol(
      id: 'pse_noradrenaline',
      dciName: 'Noradrénaline',
      commercialNamesDz: 'Noradrénaline Aguettant® / Razes®',
      category: 'Catécholamines & Choc',
      ampoulePresentation: 'Ampoule 8 mg / 4 ml (2 mg/ml)',
      doseUnit: PseDoseUnit.mcgPerKgPerMin,
      minDose: 0.05,
      maxDose: 2.0,
      defaultDose: 0.20,
      stepDose: 0.05,
      venousAccessRequirement: 'Voie Veineuse Centrale (ou VVP dédiée proximale en attente)',
      dilutions: [
        PseDilutionPreset(
          id: 'nora_8mg_48ml',
          label: 'Dilution Standard : 8 mg / 48 ml (166,7 γ/ml)',
          preparationInstruction: '1 ampoule (8 mg = 4 ml) + 44 ml de SG 5% ou NaCl 0,9% (Total 48 ml)',
          totalAmountMgOrUi: 8.0,
          syringeVolumeMl: 48.0,
          solvent: 'SG 5% ou NaCl 0,9%',
        ),
        PseDilutionPreset(
          id: 'nora_16mg_48ml',
          label: 'Dilution Concentrée : 16 mg / 48 ml (333,3 γ/ml)',
          preparationInstruction: '2 ampoules (16 mg = 8 ml) + 40 ml de SG 5% ou NaCl 0,9% (Total 48 ml)',
          totalAmountMgOrUi: 16.0,
          syringeVolumeMl: 48.0,
          solvent: 'SG 5% ou NaCl 0,9%',
        ),
        PseDilutionPreset(
          id: 'nora_10mg_50ml',
          label: 'Dilution Décimale : 10 mg / 50 ml (200 γ/ml)',
          preparationInstruction: '5 ml (10 mg) + 45 ml de SG 5% ou NaCl 0,9% (Total 50 ml)',
          totalAmountMgOrUi: 10.0,
          syringeVolumeMl: 50.0,
          solvent: 'SG 5% ou NaCl 0,9%',
        ),
      ],
      indications: [
        'Choc septique (vasopresseur de 1ère intention — cible PAM ≥ 65 mmHg)',
        'Choc vasoplégique / états de choc distributifs',
        'Choc cardiogénique avec hypotension sévère réfractaire',
      ],
      redFlagsAndPrecautions: [
        'Ne jamais purger ni faire de bolus sur la ligne de Noradrénaline.',
        'Risque de nécrose cutanée grave en cas d\'extravasation sur VVP.',
        'Relais de seringue en double pousse-seringue pour éviter tout collapsus.',
      ],
    ),
    PseDrugProtocol(
      id: 'pse_dobutamine',
      dciName: 'Dobutamine',
      commercialNamesDz: 'Dobutrex® / Dobutamine Mylan®',
      category: 'Inotropes & Choc Cardiogénique',
      ampoulePresentation: 'Flacon / Ampoule 250 mg / 20 ml',
      doseUnit: PseDoseUnit.mcgPerKgPerMin,
      minDose: 2.5,
      maxDose: 20.0,
      defaultDose: 5.0,
      stepDose: 2.5,
      venousAccessRequirement: 'Voie Centrale recommandée (VVP de bon calibre possible)',
      dilutions: [
        PseDilutionPreset(
          id: 'dobu_250mg_50ml',
          label: 'Standard Réa : 250 mg / 50 ml (5 000 γ/ml)',
          preparationInstruction: '1 flacon (250 mg = 20 ml) + 30 ml de NaCl 0,9% ou SG 5% (Total 50 ml)',
          totalAmountMgOrUi: 250.0,
          syringeVolumeMl: 50.0,
          solvent: 'NaCl 0,9% ou SG 5%',
        ),
      ],
      indications: [
        'Choc cardiogénique avec bas débit cardiaque',
        'Défaillance myocardique septique (associée à la Noradrénaline)',
        'Œdème aigu du poumon (OAP) cardiogénique en bas débit',
      ],
      redFlagsAndPrecautions: [
        'Surveillance scopique continue : risque de tachycardie sinusale et troubles du rythme ventriculaire.',
        'Incompatible avec les solutions alcalines (Bicarbonate de sodium).',
      ],
    ),
    PseDrugProtocol(
      id: 'pse_adrenaline',
      dciName: 'Adrénaline (Épinéphrine)',
      commercialNamesDz: 'Adrénaline Aguettant® / Razes®',
      category: 'Catécholamines & Choc',
      ampoulePresentation: 'Ampoules 1 mg / 1 ml ou 5 mg / 5 ml',
      doseUnit: PseDoseUnit.mcgPerKgPerMin,
      minDose: 0.05,
      maxDose: 1.5,
      defaultDose: 0.10,
      stepDose: 0.05,
      venousAccessRequirement: 'Voie Veineuse Centrale',
      dilutions: [
        PseDilutionPreset(
          id: 'adre_10mg_50ml',
          label: 'Standard : 10 mg / 50 ml (200 γ/ml)',
          preparationInstruction: '10 ampoules de 1 mg (10 ml) + 40 ml de NaCl 0,9% ou SG 5% (Total 50 ml)',
          totalAmountMgOrUi: 10.0,
          syringeVolumeMl: 50.0,
          solvent: 'NaCl 0,9% ou SG 5%',
        ),
        PseDilutionPreset(
          id: 'adre_5mg_50ml',
          label: 'Dilution Fine : 5 mg / 50 ml (100 γ/ml)',
          preparationInstruction: '5 ampoules de 1 mg (5 ml) + 45 ml de NaCl 0,9% (Total 50 ml)',
          totalAmountMgOrUi: 5.0,
          syringeVolumeMl: 50.0,
          solvent: 'NaCl 0,9% ou SG 5%',
        ),
      ],
      indications: [
        'Choc anaphylactique réfractaire aux bolus IM/IV',
        'Choc cardiogénique sévère / Post-arrêt cardiaque (RACS)',
      ],
      redFlagsAndPrecautions: [
        'Surveillance lactatémie et glycémie (effet hyperglycémiant et hyperlactatémiant bêta-2).',
        'Risque arythmogène majeur.',
      ],
    ),
    PseDrugProtocol(
      id: 'pse_nicardipine',
      dciName: 'Nicardipine IVSE',
      commercialNamesDz: 'Loxen® Injectable',
      category: 'Urgences Hypertensives',
      ampoulePresentation: 'Ampoule 10 mg / 10 ml (1 mg/ml)',
      doseUnit: PseDoseUnit.mgPerHour,
      minDose: 1.0,
      maxDose: 10.0,
      defaultDose: 2.0,
      stepDose: 0.5,
      venousAccessRequirement: 'VVP dédiée (changer de site toutes les 24h) ou VVC',
      dilutions: [
        PseDilutionPreset(
          id: 'loxen_50mg_50ml',
          label: 'Pur : 50 mg / 50 ml (1 mg/ml => 1 ml/h = 1 mg/h)',
          preparationInstruction: '5 ampoules de Loxen 10 mg/10 ml pures dans une seringue de 50 ml',
          totalAmountMgOrUi: 50.0,
          syringeVolumeMl: 50.0,
          solvent: 'Pur ou SG 5%',
        ),
        PseDilutionPreset(
          id: 'loxen_20mg_40ml',
          label: 'Dilué : 20 mg / 40 ml (0,5 mg/ml => 2 ml/h = 1 mg/h)',
          preparationInstruction: '2 ampoules (20 ml) + 20 ml de SG 5% (Total 40 ml)',
          totalAmountMgOrUi: 20.0,
          syringeVolumeMl: 40.0,
          solvent: 'SG 5% (éviter NaCl si veine fragile)',
        ),
      ],
      indications: [
        'Urgence hypertensive avec atteinte d\'organe cible (OAP hypertensif, Dissection aortique, AVC hémorragique, Pré-éclampsie sévère)',
      ],
      redFlagsAndPrecautions: [
        'Ne pas faire baisser la PA de plus de 20-25% la 1ère heure (sauf dissection aortique).',
        'Veinotoxique en périphérique : surveiller le point de ponction.',
      ],
    ),
    PseDrugProtocol(
      id: 'pse_insuline',
      dciName: 'Insuline Rapide Humaine IVSE',
      commercialNamesDz: 'Actrapid® / NovoRapid® / Humulin R®',
      category: 'Métabolique & Réanimation',
      ampoulePresentation: 'Flacon 10 ml à 100 UI/ml',
      doseUnit: PseDoseUnit.uiPerKgPerHour,
      minDose: 0.05,
      maxDose: 0.20,
      defaultDose: 0.10,
      stepDose: 0.02,
      venousAccessRequirement: 'VVP dédiée',
      dilutions: [
        PseDilutionPreset(
          id: 'insuline_50ui_50ml',
          label: 'Standard universel : 50 UI / 50 ml (1 UI/ml)',
          preparationInstruction: '0,5 ml (50 UI à la seringue à insuline) + 49,5 ml de NaCl 0,9% (Purger 5 ml de tubulure avant branchement)',
          totalAmountMgOrUi: 50.0,
          syringeVolumeMl: 50.0,
          solvent: 'NaCl 0,9%',
        ),
      ],
      indications: [
        'Acidocétose diabétique (ACD) : posologie standard 0,1 UI/kg/h sans bolus (max 10 UI/h)',
        ' Syndrome d\'hyperglycémie hyperosmolaire (0,05 UI/kg/h après réhydratation initiale)',
      ],
      redFlagsAndPrecautions: [
        'Vérifier la kaliémie AVANT de démarrer l\'insuline : si K+ < 3,3 mmol/L, différer l\'insuline et recharger en KCl d\'abord !',
        'Ajouter du SG 5% ou SG 10% dès que la glycémie capillaire passe sous 2,50 g/L tout en maintenant l\'insuline jusqu\'à disparition de la cétonémie.',
      ],
    ),
    PseDrugProtocol(
      id: 'pse_heparine',
      dciName: 'Héparine Sodique (HNF)',
      commercialNamesDz: 'Héparine Choay® / Héparine Sodique',
      category: 'Anticoagulation Curative',
      ampoulePresentation: 'Flacon 25 000 UI / 5 ml (5 000 UI/ml)',
      doseUnit: PseDoseUnit.uiPerKgPerHour,
      minDose: 15.0,
      maxDose: 25.0,
      defaultDose: 18.0,
      stepDose: 1.0,
      venousAccessRequirement: 'VVP dédiée',
      dilutions: [
        PseDilutionPreset(
          id: 'hnf_25000_50ml',
          label: 'Standard : 25 000 UI / 50 ml (500 UI/ml)',
          preparationInstruction: '1 flacon (5 ml = 25 000 UI) + 45 ml de NaCl 0,9% (Total 50 ml)',
          totalAmountMgOrUi: 25000.0,
          syringeVolumeMl: 50.0,
          solvent: 'NaCl 0,9%',
        ),
        PseDilutionPreset(
          id: 'hnf_20000_48ml',
          label: 'Protocole 48 ml : 20 000 UI / 48 ml (416,7 UI/ml)',
          preparationInstruction: '4 ml (20 000 UI) + 44 ml de NaCl 0,9% (Total 48 ml => 2 ml/h = 20 000 UI/24h)',
          totalAmountMgOrUi: 20000.0,
          syringeVolumeMl: 48.0,
          solvent: 'NaCl 0,9%',
        ),
      ],
      indications: [
        'Embolie pulmonaire grave / TVP avec insuffisance rénale sévère (DFG < 30 ml/min)',
        'Syndrome coronarien aigu (SCA) : bolus 60-70 UI/kg puis 15-18 UI/kg/h',
        'Ischémie aiguë de membre',
      ],
      redFlagsAndPrecautions: [
        'Surveillance TCA 4 à 6h après le début et après chaque changement de vitesse (cible TCA 1,5 à 2,5x témoin ou Héparinémie anti-Xa 0,3-0,7 UI/ml).',
        'Surveillance plaquettes 2x/semaine (risque de TIH type 2) — Antidote : Sulfate de Protamine.',
      ],
    ),
    PseDrugProtocol(
      id: 'pse_cordarone',
      dciName: 'Amiodarone IVSE',
      commercialNamesDz: 'Cordarone® / Sedacoron®',
      category: 'Rythmologie d\'Urgence',
      ampoulePresentation: 'Ampoule 150 mg / 3 ml',
      doseUnit: PseDoseUnit.mgPerHour,
      minDose: 15.0,
      maxDose: 300.0,
      defaultDose: 37.5,
      stepDose: 12.5,
      venousAccessRequirement: 'Voie Veineuse Centrale fortement recommandée (très veinotoxique)',
      dilutions: [
        PseDilutionPreset(
          id: 'cordarone_300mg_30ml',
          label: 'Dose de Charge : 300 mg / 30 ml SG 5% (10 mg/ml)',
          preparationInstruction: '2 ampoules (300 mg = 6 ml) + 24 ml UNIQUEMENT de SG 5% (Total 30 ml à passer en 30-60 min)',
          totalAmountMgOrUi: 300.0,
          syringeVolumeMl: 30.0,
          solvent: 'SG 5% EXCLUSIVEMENT',
        ),
        PseDilutionPreset(
          id: 'cordarone_900mg_48ml',
          label: 'Entretien 24h : 900 mg / 48 ml SG 5% (18,75 mg/ml)',
          preparationInstruction: '6 ampoules (900 mg = 18 ml) + 30 ml UNIQUEMENT de SG 5% (Total 48 ml => 2 ml/h sur 24h)',
          totalAmountMgOrUi: 900.0,
          syringeVolumeMl: 48.0,
          solvent: 'SG 5% EXCLUSIVEMENT',
        ),
      ],
      indications: [
        'Fibrillation atriale (FA) rapide mal tolérée / réduction pharmacologique',
        'Tachycardie ventriculaire (TV) bien tolérée ou FV réfractaire post-CEE',
      ],
      redFlagsAndPrecautions: [
        'JAMAIS dans du NaCl 0,9% (précipitation physico-chimique) : diluer EXCLUSIVEMENT dans du SG 5%.',
        'Haute phlébotoxicité en périphérique si concentration > 2 mg/ml.',
      ],
    ),
  ];
}
