import 'dart:math' as math;

/// Niveau de gravité d'une rubrique de lecture ECG.
enum EcgSeverity { normal, warning, critical }

/// Activité auriculaire observée.
enum EcgAtrialActivity {
  sinus,
  fibrillation,
  flutter,
  absent,
}

/// Régularité des complexes QRS.
enum EcgRegularity { regular, irregularlyIrregular }

/// Bloc auriculo-ventriculaire.
enum EcgAvBlock {
  none,
  firstDegree,
  secondDegreeWenckebach,
  secondDegreeMobitz2,
  thirdDegree,
}

/// Largeur et morphologie du QRS.
enum EcgBundleBranch { none, left, right }

/// Aspect du segment ST.
enum EcgStFinding { isoelectric, elevation, depression }

/// Territoire concerné par une anomalie ST-T / Q.
enum EcgTerritory { none, anterior, inferior, lateral }

/// Aspect de l'onde T.
enum EcgTWave { normal, peaked, inverted, flat }

/// Une rubrique du compte rendu structuré (P, PR, QRS, ST, T, QT...).
class EcgReportSection {
  final String title;
  final String value;
  final String detail;
  final EcgSeverity severity;

  const EcgReportSection({
    required this.title,
    required this.value,
    required this.detail,
    this.severity = EcgSeverity.normal,
  });
}

/// Mesures et constatations saisies pour l'interprétation.
class EcgFindings {
  final double heartRateBpm;
  final EcgAtrialActivity atrial;
  final EcgRegularity regularity;
  final EcgAvBlock avBlock;
  final double? prMs;
  final double qrsMs;
  final bool qrsPositiveInLeadI;
  final bool qrsPositiveInLeadAvf;
  final EcgBundleBranch bundleBranch;
  final double? sokolowSV1mm;
  final double? sokolowRV6mm;
  final bool pathologicQ;
  final EcgStFinding stFinding;
  final EcgTerritory territory;
  final double stElevationMm;
  final bool stTwoContiguousLeads;
  final EcgTWave tWave;
  final double qtMs;
  final bool isFemale;

  /// Calibrage standard 25 mm/s et 10 mm/mV.
  final bool standardCalibration;

  /// Contrôles techniques : `null` = non renseigné.
  final bool? avrNegative;
  final bool? rProgressionNormal;

  const EcgFindings({
    required this.heartRateBpm,
    this.atrial = EcgAtrialActivity.sinus,
    this.regularity = EcgRegularity.regular,
    this.avBlock = EcgAvBlock.none,
    this.prMs = 160,
    this.qrsMs = 90,
    this.qrsPositiveInLeadI = true,
    this.qrsPositiveInLeadAvf = true,
    this.bundleBranch = EcgBundleBranch.none,
    this.sokolowSV1mm,
    this.sokolowRV6mm,
    this.pathologicQ = false,
    this.stFinding = EcgStFinding.isoelectric,
    this.territory = EcgTerritory.none,
    this.stElevationMm = 0,
    this.stTwoContiguousLeads = true,
    this.tWave = EcgTWave.normal,
    this.qtMs = 400,
    this.isFemale = false,
    this.standardCalibration = true,
    this.avrNegative,
    this.rProgressionNormal,
  });
}

/// Niveau de confiance de la conclusion, dépendant de la qualité du tracé
/// et de l'exhaustivité des mesures saisies.
enum EcgConfidence { high, medium, low }

/// Résultat complet de l'interprétation.
class EcgInterpretationResult {
  final List<EcgReportSection> sections;
  final List<String> criticalAlerts;
  final List<String> warnings;
  final List<String> technicalIssues;
  final List<String> missingData;
  final EcgConfidence confidence;
  final String summary;
  final double qtcBazett;
  final double qtcFridericia;
  final double rrMs;
  final String axisLabel;
  final String rhythmLabel;

  const EcgInterpretationResult({
    required this.sections,
    required this.criticalAlerts,
    required this.warnings,
    required this.technicalIssues,
    required this.missingData,
    required this.confidence,
    required this.summary,
    required this.qtcBazett,
    required this.qtcFridericia,
    required this.rrMs,
    required this.axisLabel,
    required this.rhythmLabel,
  });

  bool get isTechnicallyValid => technicalIssues.isEmpty;
}

/// Moteur d'interprétation ECG fondé sur la méthode du cours
/// « ECG facile » : technique → fréquence → rythme → axe → éléments du tracé.
class EcgInterpreter {
  // ---------------------------------------------------------------------------
  // Constantes de référence (25 mm/s, 10 mm/mV)
  // ---------------------------------------------------------------------------
  static const double smallBoxMs = 40; // 1 mm = 0,04 s
  static const double largeBoxMs = 200; // 5 mm = 0,2 s
  static const double normalPrMin = 120;
  static const double normalPrMax = 200;
  static const double normalQrsMax = 120;
  static const double pathologicQDepthMm = 2; // 0,2 mV
  static const double pathologicQWidthMs = 40; // 0,04 s
  static const double lvhSokolowThresholdMm = 35;
  static const double qtcCriticalMs = 500;
  static const double qtcShortMs = 340;

  static const Map<int, int> rateFromLargeBoxes = {
    1: 300,
    2: 150,
    3: 100,
    4: 75,
    5: 60,
    6: 50,
    7: 43,
    8: 38,
    9: 33,
    10: 30,
  };

  static double qtcUpperLimit({required bool isFemale}) => isFemale ? 460 : 450;

  static String territoryLabel(EcgTerritory territory) {
    switch (territory) {
      case EcgTerritory.anterior:
        return 'Antérieur (V1-V4)';
      case EcgTerritory.inferior:
        return 'Inférieur (D2-D3-aVF)';
      case EcgTerritory.lateral:
        return 'Latéral (D1-aVL-V5-V6)';
      case EcgTerritory.none:
        return 'Non territorialisé';
    }
  }

  static String territoryLeads(EcgTerritory territory) {
    switch (territory) {
      case EcgTerritory.anterior:
        return 'V1, V2, V3, V4 (+ V5-V6 si étendu)';
      case EcgTerritory.inferior:
        return 'D2, D3, aVF';
      case EcgTerritory.lateral:
        return 'D1, aVL, V5, V6';
      case EcgTerritory.none:
        return '—';
    }
  }

  /// Interprétation structurée, dans l'ordre enseigné par le cours.
  static EcgInterpretationResult interpret(EcgFindings f) {
    final hr = f.heartRateBpm <= 0 ? 1.0 : f.heartRateBpm;
    final rrMs = 60000 / hr;
    final qtcBazett = f.qtMs / math.sqrt(rrMs / 1000);
    final qtcFridericia = f.qtMs / math.pow(rrMs / 1000, 1 / 3);

    final technicalIssues = <String>[];
    final missingData = <String>[];
    final criticalAlerts = <String>[];
    final warnings = <String>[];
    final sections = <EcgReportSection>[];

    // -- 1. Contrôles techniques ----------------------------------------------
    if (f.avrNegative == false) {
      technicalIssues.add(
        'aVR positif : inversion probable des électrodes des membres (aVR doit toujours être négatif).',
      );
    }
    if (!f.qrsPositiveInLeadI) {
      technicalIssues.add(
        'D1 négatif : vérifier le branchement des électrodes (D1 est toujours positif sur un ECG correct).',
      );
    }
    if (f.rProgressionNormal == false) {
      technicalIssues.add(
        'Progression de l\'onde R anormale de V1 à V6 (petit → grand) : vérifier les électrodes précordiales.',
      );
    }
    if (f.avrNegative == null) missingData.add('négativité de aVR');
    if (f.rProgressionNormal == null) missingData.add('progression de R en V1-V6');
    if (!f.standardCalibration) {
      warnings.add(
        'Calibrage non standard (25 mm/s, 10 mm/mV) : les mesures en carreaux doivent être recalculées.',
      );
    }

    final qrsWide = f.qrsMs >= normalQrsMax;

    // -- 2. Fréquence ---------------------------------------------------------
    String rateValue;
    EcgSeverity rateSeverity;
    String rateDetail;
    if (hr < 50) {
      rateValue = 'Bradycardie (${hr.toStringAsFixed(0)} bpm)';
      rateSeverity = EcgSeverity.warning;
      rateDetail = 'Fréquence < 50/min : rechercher un bloc, une cause médicamenteuse ou un contexte vagal.';
      if (hr < 40) {
        rateSeverity = EcgSeverity.critical;
        criticalAlerts.add('Bradycardie sévère (< 40/min) : risque de bas débit, avis urgent.');
      }
    } else if (hr < 60) {
      rateValue = 'Fréquence basse (${hr.toStringAsFixed(0)} bpm)';
      rateSeverity = EcgSeverity.normal;
      rateDetail = '50-60/min : bradycardie limite, souvent normale au repos ou chez le sportif.';
    } else if (hr <= 100) {
      rateValue = 'Normale (${hr.toStringAsFixed(0)} bpm)';
      rateSeverity = EcgSeverity.normal;
      rateDetail = 'Fréquence normale, ou tachycardie sinusale modérée.';
    } else {
      rateValue = 'Tachycardie (${hr.toStringAsFixed(0)} bpm)';
      rateSeverity = EcgSeverity.warning;
      rateDetail = 'Fréquence > 100/min : préciser le rythme (sinusal, FA, flutter, jonctionnel, TV).';
      if (hr >= 150) {
        rateSeverity = EcgSeverity.critical;
        criticalAlerts.add(
          'Tachycardie rapide (> 150/min) : éliminer une tachycardie ventriculaire ou un flutter avant tout traitement.',
        );
      }
    }
    sections.add(
      EcgReportSection(
        title: 'Fréquence',
        value: rateValue,
        detail: '$rateDetail RR ≈ ${rrMs.toStringAsFixed(0)} ms '
            '(≈ ${(rrMs / largeBoxMs).toStringAsFixed(1)} grands carreaux, formule 300/RR).',
        severity: rateSeverity,
      ),
    );

    // -- 3. Rythme ------------------------------------------------------------
    String rhythmLabel;
    String rhythmDetail;
    EcgSeverity rhythmSeverity = EcgSeverity.normal;

    switch (f.atrial) {
      case EcgAtrialActivity.sinus:
        rhythmLabel = 'Rythme sinusal';
        rhythmDetail = 'Onde P avant chaque QRS, positive en D1 et D2, négative en aVR.';
        break;
      case EcgAtrialActivity.fibrillation:
        rhythmLabel = 'Fibrillation atriale';
        rhythmDetail =
            'Irrégulièrement irrégulier, absence d\'onde P, ligne de base tremblée (fibrillation).';
        rhythmSeverity = EcgSeverity.warning;
        break;
      case EcgAtrialActivity.flutter:
        rhythmLabel = 'Flutter atrial';
        rhythmDetail =
            'Aspect en dents de scie, activité auriculaire ≈ 300/min (1 flutter toutes les 5 mm) ; '
            'conduction souvent 2:1 (fréquence ventriculaire ≈ 150/min).';
        rhythmSeverity = EcgSeverity.warning;
        break;
      case EcgAtrialActivity.absent:
        if (qrsWide && f.regularity == EcgRegularity.regular) {
          rhythmLabel = 'Tachycardie ventriculaire probable';
          rhythmDetail =
              'Aucune onde P, QRS large et régulier : à traiter comme une TV jusqu\'à preuve du contraire.';
          rhythmSeverity = EcgSeverity.critical;
          criticalAlerts.add(
            'QRS large régulier sans onde P : tachycardie ventriculaire présumée — ne pas donner de bloqueur calcique, avis urgent.',
          );
        } else {
          rhythmLabel = 'Rythme sans onde P';
          rhythmDetail =
              'Aucune activité auriculaire visible : rythme jonctionnel ou ventriculaire selon la largeur du QRS.';
          rhythmSeverity = EcgSeverity.warning;
        }
        break;
    }

    if (f.atrial == EcgAtrialActivity.sinus && f.regularity == EcgRegularity.irregularlyIrregular) {
      rhythmDetail += ' Irrégulièrement irrégulier : rechercher une arythmie sinusale ou des extrasystoles.';
    }

    // -- 4. Axe ---------------------------------------------------------------
    final axisLabel = _axisLabel(f.qrsPositiveInLeadI, f.qrsPositiveInLeadAvf);
    final axisDetail = _axisDetail(f.qrsPositiveInLeadI, f.qrsPositiveInLeadAvf);
    if (!f.qrsPositiveInLeadI && !f.qrsPositiveInLeadAvf) {
      warnings.add(
        'Axe « nord-ouest » (D1 et aVF négatifs) : vérifier les électrodes, sinon évoquer une TV ou un rythme ventriculaire.',
      );
    }

    // -- 5. Bloc auriculo-ventriculaire & PR ----------------------------------
    final pr = f.prMs;
    String prValue;
    String prDetail;
    EcgSeverity prSeverity = EcgSeverity.normal;
    if (pr != null && pr < normalPrMin) {
      prValue = 'PR court ($pr ms)';
      prDetail = 'PR < 120 ms : évoquer une pré-excitation (WPW) si onde delta associée.';
      prSeverity = EcgSeverity.warning;
    } else if (pr != null && pr > normalPrMax) {
      prValue = 'PR allongé ($pr ms)';
      prDetail = 'PR > 200 ms (plus de 5 petits carreaux) : bloc AV du 1er degré.';
      prSeverity = EcgSeverity.warning;
    } else if (pr != null) {
      prValue = 'PR normal ($pr ms)';
      prDetail = 'PR entre 120 et 200 ms (3 à 5 petits carreaux).';
    } else {
      prValue = 'PR non renseigné';
      prDetail = 'Mesurer du début de P au début du QRS (début de Q s\'il existe).';
      prSeverity = EcgSeverity.warning;
      if (!missingData.contains('intervalle PR')) missingData.add('intervalle PR');
    }
    if (f.avBlock != EcgAvBlock.none) {
      final blockText = _avBlockText(f.avBlock);
      prValue = blockText.label;
      prDetail = blockText.detail;
      prSeverity = blockText.severity;
      if (f.avBlock == EcgAvBlock.thirdDegree) {
        criticalAlerts.add('Bloc AV du 3e degré : dissociation P/QRS — risque de syncope, avis urgent.');
      }
    }

    // -- 6. QRS & morphologie -------------------------------------------------
    String qrsValue;
    String qrsDetail;
    EcgSeverity qrsSeverity = EcgSeverity.normal;
    if (qrsWide) {
      qrsSeverity = EcgSeverity.warning;
      qrsValue = 'QRS large (${f.qrsMs.toStringAsFixed(0)} ms)';
      qrsDetail = 'QRS ≥ 120 ms : bloc de branche, rythme ventriculaire ou pré-excitation.';
    } else {
      qrsValue = 'QRS fin (${f.qrsMs.toStringAsFixed(0)} ms)';
      qrsDetail = 'QRS < 120 ms (moins de 3 petits carreaux).';
    }

    String? branchDetail;
    switch (f.bundleBranch) {
      case EcgBundleBranch.left:
        qrsSeverity = EcgSeverity.critical;
        branchDetail =
            'BBDG (W en V1, M en V6 / R échancré) : le segment ST n\'est plus interprétable. '
            'Un BBDG récent avec douleur thoracique doit être traité comme un équivalent de SCA.';
        criticalAlerts.add(
          'BBDG : ST ininterprétable — si douleur thoracique récente, considérer un SCA ST+ (critères de Sgarbossa) et avis cardiologique.',
        );
        break;
      case EcgBundleBranch.right:
        branchDetail =
            'BBDD (rSR\' en V1, qRs en V6) : peut être complet ou banal chez le sujet sain (BBD partiel) ; '
            'contexte d\'infarctus ou de fibrose possible.';
        break;
      case EcgBundleBranch.none:
        branchDetail = null;
        break;
    }

    if (f.pathologicQ) {
      warnings.add(
        'Onde Q pathologique (> 0,2 mV de profondeur et/ou > 0,04 s de large) : nécrose, infarctus ancien. '
        'Un petit Q en D1, D2, D3, aVL, V5-V6 est normal.',
      );
    }

    final lvhRatio =
        (f.sokolowSV1mm != null && f.sokolowRV6mm != null) ? f.sokolowSV1mm! + f.sokolowRV6mm! : null;
    if (lvhRatio == null) {
      if (!missingData.contains('S en V1 + R en V6')) missingData.add('S en V1 + R en V6');
    } else if (lvhRatio > lvhSokolowThresholdMm) {
      warnings.add(
        'Hypertrophie ventriculaire gauche probable : S(V1) + R(V6) = ${lvhRatio.toStringAsFixed(0)} mm '
        '(> 35 mm).',
      );
    }

    sections.add(
      EcgReportSection(
        title: 'Axe du QRS',
        value: axisLabel,
        detail: axisDetail,
        severity: EcgSeverity.normal,
      ),
    );
    sections.add(
      EcgReportSection(
        title: 'Rythme',
        value: rhythmLabel,
        detail: rhythmDetail,
        severity: rhythmSeverity,
      ),
    );
    sections.add(
      EcgReportSection(
        title: 'Espace PR',
        value: prValue,
        detail: prDetail,
        severity: prSeverity,
      ),
    );
    sections.add(
      EcgReportSection(
        title: 'Complexe QRS',
        value: qrsValue,
        detail: branchDetail == null ? qrsDetail : '$qrsDetail $branchDetail',
        severity: qrsSeverity,
      ),
    );

    // -- 7. ST, territoires, onde T -------------------------------------------
    final territoryText = f.territory == EcgTerritory.none
        ? ''
        : ' Territoire ${territoryLabel(f.territory).toLowerCase()} — dérivations ${territoryLeads(f.territory)}.';
    String stValue;
    String stDetail;
    EcgSeverity stSeverity = EcgSeverity.normal;

    switch (f.stFinding) {
      case EcgStFinding.isoelectric:
        stValue = 'ST isoélectrique';
        stDetail = 'Le segment ST doit être isoélectrique sur un ECG normal.';
        break;
      case EcgStFinding.elevation:
        final threshold = f.territory == EcgTerritory.anterior ? 2.0 : 1.0;
        final significant = f.stElevationMm >= threshold && f.stTwoContiguousLeads;
        stValue = 'Sus-décalage ST ${f.stElevationMm.toStringAsFixed(1)} mm';
        if (significant) {
          stSeverity = EcgSeverity.critical;
          stDetail = 'Sus-décalage ≥ $threshold mm dans ≥ 2 dérivations contiguës : SCA ST+ '
              '(syndrome coronarien aigu avec élévation du ST). Reperfusion urgente à discuter.$territoryText';
          criticalAlerts.add(
            'SCA ST+ ${f.territory == EcgTerritory.none ? '' : 'territoire ${territoryLabel(f.territory).toLowerCase()} '}'
            ': alerter immédiatement, ECG à 10 min, double antiagrégation et orientation vers un centre de reperfusion.',
          );
        } else {
          stSeverity = EcgSeverity.warning;
          stDetail = 'Sus-décalage isolé ou < seuil (> $threshold mm en V2-V3, > 1 mm ailleurs, '
              'dans ≥ 2 dérivations contiguës) : à comparer avec un ECG antérieur.$territoryText';
        }
        break;
      case EcgStFinding.depression:
        stValue = 'Sous-décalage ST';
        stSeverity = EcgSeverity.warning;
        stDetail = 'Sous-décalage : ischémie sous-endocardique (SCA non ST+), surcharge ventriculaire '
            'ou effet médicamenteux (digitaliques).$territoryText';
        break;
    }

    String tValue;
    String tDetail;
    EcgSeverity tSeverity = EcgSeverity.normal;
    switch (f.tWave) {
      case EcgTWave.normal:
        tValue = 'Onde T normale';
        tDetail = 'T positive, de taille normale, concordante avec le QRS.';
        break;
      case EcgTWave.peaked:
        tValue = 'Onde T ample et pointue';
        tSeverity = EcgSeverity.warning;
        tDetail = 'T pointue : hyperkaliémie ou ischémie sous-endocardique (T hyperaiguës précoces).';
        warnings.add('Onde T ample pointue : contrôler le potassium (K+) et rechercher une ischémie.');
        break;
      case EcgTWave.inverted:
        tValue = 'Onde T inversée';
        tSeverity = EcgSeverity.warning;
        tDetail = 'T inversée : ischémie, surcharge ou séquelle d\'infarctus (24 h après le début).';
        break;
      case EcgTWave.flat:
        tValue = 'Onde T plate';
        tSeverity = EcgSeverity.warning;
        tDetail = 'Aplatissement de T : hypokaliémie, ischémie ou effet médicamenteux.';
        break;
    }

    sections.add(
      EcgReportSection(
        title: 'Segment ST',
        value: stValue,
        detail: stDetail,
        severity: stSeverity,
      ),
    );
    sections.add(
      EcgReportSection(
        title: 'Onde T',
        value: tValue,
        detail: tDetail,
        severity: tSeverity,
      ),
    );

    // -- 8. QT / QTc ----------------------------------------------------------
    final qtcLimit = qtcUpperLimit(isFemale: f.isFemale);
    String qtValue;
    String qtDetail;
    EcgSeverity qtSeverity = EcgSeverity.normal;
    if (qtcBazett >= qtcCriticalMs) {
      qtValue = 'QTc critique (${qtcBazett.toStringAsFixed(0)} ms)';
      qtSeverity = EcgSeverity.critical;
      qtDetail = 'QTc ≥ 500 ms : risque majeur de torsades de pointes. Arrêter les médicaments '
          'allongeant le QT, corriger K+ et Mg2+, surveillance scopique.';
      criticalAlerts.add('QTc ≥ 500 ms : risque de torsades de pointes, correction ionique et arrêt des QT-longs.');
    } else if (qtcBazett > qtcLimit) {
      qtValue = 'QTc allongé (${qtcBazett.toStringAsFixed(0)} ms)';
      qtSeverity = EcgSeverity.warning;
      qtDetail = 'QTc > ${qtcLimit.toStringAsFixed(0)} ms : surveillance, contrôle K+/Ca2+/Mg2+ et '
          'révision des traitements.';
    } else if (qtcBazett < qtcShortMs) {
      qtValue = 'QTc court (${qtcBazett.toStringAsFixed(0)} ms)';
      qtSeverity = EcgSeverity.warning;
      qtDetail = 'QTc < 340 ms : rechercher une hypercalcémie ou un syndrome du QT court.';
    } else {
      qtValue = 'QTc normal (${qtcBazett.toStringAsFixed(0)} ms)';
      qtDetail = 'QT mesuré ${f.qtMs.toStringAsFixed(0)} ms '
          '(${(f.qtMs / largeBoxMs).toStringAsFixed(1)} grands carreaux) ; '
          'QT normal < 400 ms à 60/min. QTc = QT/√RR.';
    }
    sections.add(
      EcgReportSection(
        title: 'QT / QTc',
        value: qtValue,
        detail: '$qtDetail QTc Fridericia ${qtcFridericia.toStringAsFixed(0)} ms.',
        severity: qtSeverity,
      ),
    );

    // -- 9. Synthèse & confiance ---------------------------------------------
    final conclusions = <String>[];
    conclusions.add('$rhythmLabel à ${hr.toStringAsFixed(0)}/min.');
    conclusions.add('Axe $axisLabel.');
    conclusions.add(qrsWide ? 'QRS large.' : 'QRS fin.');
    if (f.stFinding == EcgStFinding.elevation && f.stElevationMm >= 1 && f.stTwoContiguousLeads) {
      conclusions.add('Sus-décalage du ST significatif.');
    }
    conclusions.add(qtValue.toLowerCase().startsWith('qtc normal') ? 'Repolarisation normale.' : qtValue);

    final valid = technicalIssues.isEmpty;
    EcgConfidence confidence;
    if (!valid) {
      confidence = EcgConfidence.low;
    } else if (missingData.isEmpty && f.prMs != null && f.sokolowRV6mm != null && f.sokolowSV1mm != null) {
      confidence = EcgConfidence.high;
    } else {
      confidence = EcgConfidence.medium;
    }

    final summary = StringBuffer()
      ..write(conclusions.join(' '));
    if (!valid) {
      summary.write(' Conclusion à confirmer : tracé techniquement douteux.');
    } else if (missingData.isNotEmpty) {
      summary.write(' Confiance moyenne : compléter ${missingData.join(', ')}.');
    }

    return EcgInterpretationResult(
      sections: sections,
      criticalAlerts: criticalAlerts,
      warnings: warnings,
      technicalIssues: technicalIssues,
      missingData: missingData,
      confidence: confidence,
      summary: summary.toString(),
      qtcBazett: qtcBazett,
      qtcFridericia: qtcFridericia,
      rrMs: rrMs,
      axisLabel: axisLabel,
      rhythmLabel: rhythmLabel,
    );
  }

  static String _axisLabel(bool leadIPositive, bool avfPositive) {
    if (leadIPositive && avfPositive) return 'normal (0° à +90°)';
    if (leadIPositive && !avfPositive) return 'déviation gauche';
    if (!leadIPositive && avfPositive) return 'déviation droite';
    return 'extrême (nord-ouest)';
  }

  static String _axisDetail(bool leadIPositive, bool avfPositive) {
    if (leadIPositive && avfPositive) {
      return 'D1 et aVF positifs : axe normal. Rappel des axes : D1 0°, aVL -30°, aVR -150°, '
          'D2 +60°, aVF +90°, D3 +120°.';
    }
    if (leadIPositive && !avfPositive) {
      return 'D1 positif et aVF négatif : déviation gauche — normale si D2 reste positif, '
          'sinon hémibloc antérieur gauche.';
    }
    if (!leadIPositive && avfPositive) {
      return 'D1 négatif et aVF positif : déviation droite (hypertrophie droite, bloc de branche droit, '
          'ou inversion des électrodes).';
    }
    return 'D1 et aVF négatifs : axe extrême — vérifier les électrodes et évoquer un rythme ventriculaire.';
  }

  static _AvBlockText _avBlockText(EcgAvBlock block) {
    switch (block) {
      case EcgAvBlock.none:
        return const _AvBlockText(label: 'Pas de bloc AV', detail: '', severity: EcgSeverity.normal);
      case EcgAvBlock.firstDegree:
        return const _AvBlockText(
          label: 'Bloc AV du 1er degré',
          detail: 'PR constant > 200 ms, chaque P est suivie d\'un QRS.',
          severity: EcgSeverity.warning,
        );
      case EcgAvBlock.secondDegreeWenckebach:
        return const _AvBlockText(
          label: 'Bloc AV du 2e degré — Wenckebach (Mobitz 1)',
          detail: 'PR qui s\'allonge progressivement jusqu\'à un QRS manquant.',
          severity: EcgSeverity.warning,
        );
      case EcgAvBlock.secondDegreeMobitz2:
        return const _AvBlockText(
          label: 'Bloc AV du 2e degré — Mobitz 2',
          detail: 'PR constant puis QRS manquant brutalement : risque d\'évolution vers le bloc complet.',
          severity: EcgSeverity.critical,
        );
      case EcgAvBlock.thirdDegree:
        return const _AvBlockText(
          label: 'Bloc AV du 3e degré',
          detail: 'Aucune relation entre les ondes P et les QRS (dissociation auriculo-ventriculaire).',
          severity: EcgSeverity.critical,
        );
    }
  }
}

class _AvBlockText {
  final String label;
  final String detail;
  final EcgSeverity severity;

  const _AvBlockText({required this.label, required this.detail, required this.severity});
}

/// Référentiel de poche repris du cours « ECG facile ».
class EcgReference {
  static const List<Map<String, String>> normalValues = [
    {'param': 'Fréquence', 'value': '50-100 /min (rythme sinusal)', 'box': '300 / nombre de grands carreaux'},
    {'param': 'Axe du QRS', 'value': '+90° à -30°', 'box': 'D1 et D2 positifs'},
    {'param': 'Intervalle PR', 'value': '120-200 ms', 'box': '3 à 5 petits carreaux'},
    {'param': 'Complexe QRS', 'value': '< 120 ms', 'box': 'moins de 3 petits carreaux'},
    {'param': 'Onde Q', 'value': '< 0,2 mV et < 0,04 s', 'box': '< 2 petits de profondeur, < 1 de large'},
    {'param': 'Segment ST', 'value': 'isoélectrique', 'box': 'sur la ligne de base'},
    {'param': 'QT', 'value': '< 400 ms à 60/min', 'box': 'moins de 2 grands carreaux'},
    {'param': 'QTc', 'value': '< 450 ms (H) / < 460 ms (F)', 'box': 'alerte si ≥ 500 ms'},
    {'param': 'Calibrage', 'value': '25 mm/s • 10 mm/mV', 'box': '1 petit = 0,04 s • 1 grand = 0,2 s'},
  ];

  static const List<Map<String, String>> technicalChecks = [
    {
      'check': 'aVR toujours négatif',
      'detail': 'Un aVR positif signe une inversion des électrodes des membres.',
    },
    {
      'check': 'D1 toujours positif',
      'detail': 'Un D1 négatif impose de vérifier le branchement avant d\'interpréter l\'axe.',
    },
    {
      'check': 'Progression de R de V1 à V6',
      'detail': 'L\'onde R grandit du petit (V1) au grand (V6) : sinon, électrodes précordiales à revoir.',
    },
    {
      'check': 'Absence d\'artéfact',
      'detail': 'Tremblement musculaire, interférence électrique 50/60 Hz, ligne de base errante, pacemaker.',
    },
  ];

  static const List<Map<String, String>> territories = [
    {'territory': 'Antérieur', 'leads': 'V1-V4', 'artery': 'Interventriculaire antérieure'},
    {'territory': 'Antéro-septal', 'leads': 'V1-V3', 'artery': 'Septales'},
    {'territory': 'Latéral', 'leads': 'D1, aVL, V5-V6', 'artery': 'Circonflexe / marginale'},
    {'territory': 'Inférieur', 'leads': 'D2, D3, aVF', 'artery': 'Coronaire droite'},
    {'territory': 'Côté droit', 'leads': 'aVR, V1 (V4R en supplémentaire)', 'artery': 'Ventricule droit'},
  ];

  static const List<Map<String, String>> infarctionTimeline = [
    {'time': 'Heures', 'sign': 'Onde T pointue puis sus-décalage du ST'},
    {'time': '24 heures', 'sign': 'T qui s\'inverse, ST qui se résorbe (persiste si anévrisme ventriculaire)'},
    {'time': 'Quelques jours', 'sign': 'Ondes Q pathologiques définitives'},
  ];

  static const List<Map<String, String>> bundleBranchPatterns = [
    {
      'block': 'BBDG (gauche)',
      'pattern': 'W en V1, M en V6 (R échancré) — WiLLiaM : W à gauche, M à droite',
      'note': 'ST non interprétable ; BBDG récent + douleur = équivalent de SCA',
    },
    {
      'block': 'BBDD (droit)',
      'pattern': 'rSR\' en V1, qRs en V6 — MaRRoW',
      'note': 'Peut être banal chez le sujet sain (BBD partiel)',
    },
  ];
}
