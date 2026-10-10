class CalculatorResult {
  final num value;
  final String unit;
  final String interpretation;
  final String recommendation;
  final String severityColor; // 'green', 'amber', 'red'

  const CalculatorResult({
    required this.value,
    required this.unit,
    required this.interpretation,
    required this.recommendation,
    required this.severityColor,
  });
}

class ClinicalCalculators {
  // 1. Glasgow Coma Scale (GCS)
  static CalculatorResult calculateGlasgow({
    required int eye,
    required int verbal,
    required int motor,
  }) {
    final total = eye + verbal + motor;
    String interp;
    String reco;
    String color;

    if (total >= 13) {
      interp = 'Traumatisme crânien léger / Vigilance conservée (GCS: $total/15)';
      reco = 'Surveillance clinique neurologique régulière.';
      color = 'green';
    } else if (total >= 9) {
      interp = 'Traumatisme crânien modéré / Somnolence marquée (GCS: $total/15)';
      reco = 'Scanner cérébral recommandé, surveillance rapprochée en soins intensifs.';
      color = 'amber';
    } else {
      interp = 'Coma / Traumatisme crânien grave (GCS: $total/15)';
      reco = 'URGENCE VITALE : Indication formelle d\'intubation orotrachéale et transfert en Réanimation / Déchoquage.';
      color = 'red';
    }

    return CalculatorResult(
      value: total,
      unit: '/15',
      interpretation: interp,
      recommendation: reco,
      severityColor: color,
    );
  }

  // 2. Score de Wells - Embolie Pulmonaire
  static CalculatorResult calculateWellsPE({
    required bool signsDvt,
    required bool altDiagnosisLessLikely,
    required bool heartRateOver100,
    required bool immobilizationOrSurgery,
    required bool previousDvtPe,
    required bool hemoptysis,
    required bool activeCancer,
  }) {
    double score = 0;
    if (signsDvt) score += 3.0;
    if (altDiagnosisLessLikely) score += 3.0;
    if (heartRateOver100) score += 1.5;
    if (immobilizationOrSurgery) score += 1.5;
    if (previousDvtPe) score += 1.5;
    if (hemoptysis) score += 1.0;
    if (activeCancer) score += 1.0;

    String interp;
    String reco;
    String color;

    if (score <= 1.5) {
      interp = 'Probabilité clinique FAIBLE (Score de Wells: $score)';
      reco = 'D-Dimères en première intention : si négatifs (< 500 µg/L), élimine l\'EP sans imagerie.';
      color = 'green';
    } else if (score <= 6.0) {
      interp = 'Probabilité clinique INTERMÉDIAIRE (Score de Wells: $score)';
      reco = 'Dosage des D-Dimères ou Angioscanner thoracique selon la cinétique et le terrain.';
      color = 'amber';
    } else {
      interp = 'Probabilité clinique FORTE (Score de Wells: $score)';
      reco = 'ANGIOSCANNER THORACIQUE D\'URGENCE. Ne pas attendre les D-Dimères. Initier l\'anticoagulation curative sans délai si pas de contre-indication.';
      color = 'red';
    }

    return CalculatorResult(
      value: score,
      unit: 'points',
      interpretation: interp,
      recommendation: reco,
      severityColor: color,
    );
  }

  // 3. Clairance Cockcroft & Gault
  static CalculatorResult calculateCockcroft({
    required int age,
    required double weightKg,
    required double creatinineUmolL,
    required bool isFemale,
  }) {
    if (age <= 0 || weightKg <= 0 || creatinineUmolL <= 0) {
      return const CalculatorResult(
        value: 0,
        unit: 'mL/min',
        interpretation: 'Paramètres invalides',
        recommendation: 'Veuillez saisir un âge, poids et créatininémie valides.',
        severityColor: 'amber',
      );
    }

    // Cockcroft formula: ClCr = ((140 - age) * poids * k) / créatinine(µmol/L)
    // k = 1.23 pour homme, 1.04 pour femme
    final k = isFemale ? 1.04 : 1.23;
    final clcr = ((140 - age) * weightKg * k) / creatinineUmolL;
    final rounded = double.parse(clcr.toStringAsFixed(1));

    String interp;
    String reco;
    String color;

    if (rounded >= 90) {
      interp = 'Fonction rénale normale (Stade 1) : $rounded mL/min';
      reco = 'Adaptation posologique standard.';
      color = 'green';
    } else if (rounded >= 60) {
      interp = 'Insuffisance rénale légère (Stade 2) : $rounded mL/min';
      reco = 'Surveillance de la fonction rénale, attention aux médicaments néphrotoxiques.';
      color = 'green';
    } else if (rounded >= 30) {
      interp = 'Insuffisance rénale modérée (Stade 3) : $rounded mL/min';
      reco = 'Adaptation obligatoire de la posologie des médicaments à élimination rénale (antibiotiques, AOD, etc.).';
      color = 'amber';
    } else if (rounded >= 15) {
      interp = 'Insuffisance rénale sévère (Stade 4) : $rounded mL/min';
      reco = 'Contre-indication relative/absolue à de nombreuses molécules (metformine, AINS, etc.). Consultation néphrologique.';
      color = 'red';
    } else {
      interp = 'Insuffisance rénale terminale (Stade 5) : $rounded mL/min';
      reco = 'Préparation à l\'épuration extrarénale (dialyse) ou greffe.';
      color = 'red';
    }

    return CalculatorResult(
      value: rounded,
      unit: 'mL/min',
      interpretation: interp,
      recommendation: reco,
      severityColor: color,
    );
  }

  // 4. Score CURB-65 (Pneumonie)
  static CalculatorResult calculateCurb65({
    required bool confusion,
    required bool uremiaHigh,
    required bool respiratoryRateHigh,
    required bool lowBloodPressure,
    required bool age65OrMore,
  }) {
    int score = 0;
    if (confusion) score++;
    if (uremiaHigh) score++;
    if (respiratoryRateHigh) score++;
    if (lowBloodPressure) score++;
    if (age65OrMore) score++;

    String interp;
    String reco;
    String color;

    if (score <= 1) {
      interp = 'Risque de mortalité FAIBLE (CURB-65: $score/5)';
      reco = 'Prise en charge ambulatoire (à domicile) possible sous réserve de l\'environnement social et de la tolérance orale.';
      color = 'green';
    } else if (score == 2) {
      interp = 'Risque de mortalité INTERMÉDIAIRE (CURB-65: 2/5)';
      reco = 'Hospitalisation conventionnelle recommandée pour antibiothérapie et surveillance.';
      color = 'amber';
    } else {
      interp = 'Risque de mortalité ÉLEVÉ (CURB-65: $score/5)';
      reco = 'URGENCE : Hospitalisation en soins intensifs ou Réanimation. Antibiothérapie IV précoce à large spectre.';
      color = 'red';
    }

    return CalculatorResult(
      value: score,
      unit: '/5',
      interpretation: interp,
      recommendation: reco,
      severityColor: color,
    );
  }
}
