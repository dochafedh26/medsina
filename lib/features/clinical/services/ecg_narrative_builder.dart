import '../models/ecg_interpreter_model.dart';

/// Identité du patient pour l'en-tête du compte rendu imprimé.
class EcgPatientInfo {
  final String name;
  final String age;
  final String indication;
  final String notes;

  const EcgPatientInfo({
    this.name = '',
    this.age = '',
    this.indication = '',
    this.notes = '',
  });
}

/// Verdict global du compte rendu.
enum EcgReportVerdict { normal, abnormal, incomplete }

/// Une rubrique rédigée du compte rendu.
class EcgNarrativeSection {
  final String title;
  final String body;

  const EcgNarrativeSection({required this.title, required this.body});
}

/// Compte rendu rédigé, prêt à être imprimé.
class EcgNarrativeReport {
  final EcgReportVerdict verdict;
  final String verdictLabel;
  final List<EcgNarrativeSection> sections;
  final String conclusion;
  final List<String> urgentActions;
  final String confidenceNote;

  const EcgNarrativeReport({
    required this.verdict,
    required this.verdictLabel,
    required this.sections,
    required this.conclusion,
    required this.urgentActions,
    required this.confidenceNote,
  });

  bool get isNormal => verdict == EcgReportVerdict.normal;
}

/// Transforme les mesures et le résultat du moteur en texte médical rédigé,
/// dans l'ordre habituel d'un compte rendu d'électrocardiogramme.
class EcgNarrativeBuilder {
  static EcgNarrativeReport build({
    required EcgFindings findings,
    required EcgInterpretationResult result,
    EcgPatientInfo patient = const EcgPatientInfo(),
  }) {
    final sections = <EcgNarrativeSection>[
      EcgNarrativeSection(
        title: 'Qualité technique et conditions d\'enregistrement',
        body: _technique(findings, result),
      ),
      EcgNarrativeSection(
        title: 'Fréquence et rythme',
        body: _rhythm(findings, result),
      ),
      EcgNarrativeSection(
        title: 'Conduction auriculo-ventriculaire et intraventriculaire',
        body: _conduction(findings, result),
      ),
      EcgNarrativeSection(
        title: 'Axe électrique',
        body: _axis(findings, result),
      ),
      EcgNarrativeSection(
        title: 'Morphologie et repolarisation',
        body: _repolarisation(findings, result),
      ),
      EcgNarrativeSection(
        title: 'Intervalle QT',
        body: _qt(findings, result),
      ),
    ];

    final verdict = _verdict(findings, result);
    final conclusion = _conclusion(findings, result, verdict);

    final actions = <String>[...result.criticalAlerts];
    if (result.warnings.isNotEmpty) {
      actions.addAll(result.warnings);
    }

    return EcgNarrativeReport(
      verdict: verdict,
      verdictLabel: switch (verdict) {
        EcgReportVerdict.normal => 'Électrocardiogramme sans anomalie significative',
        EcgReportVerdict.abnormal => 'Électrocardiogramme anormal',
        EcgReportVerdict.incomplete => 'Interprétation incomplète ou à confirmer',
      },
      sections: sections,
      conclusion: conclusion,
      urgentActions: actions,
      confidenceNote: _confidenceNote(result, patient),
    );
  }

  // ---------------------------------------------------------------------------
  // Rédaction des rubriques
  // ---------------------------------------------------------------------------

  static String _technique(EcgFindings f, EcgInterpretationResult r) {
    final buffer = StringBuffer();
    if (r.isTechnicallyValid && f.standardCalibration) {
      buffer.write(
        'L\'enregistrement a été réalisé dans des conditions techniques satisfaisantes, '
        'avec un calibrage standard à 25 mm/s et 10 mm/mV et des électrodes correctement positionnées. '
        'Les dérivations des membres comme les dérivations précordiales sont exploitables.',
      );
    } else {
      buffer.write('L\'interprétation doit tenir compte de plusieurs limites techniques. ');
      if (r.technicalIssues.isNotEmpty) {
        buffer.write('${_capitalize(_joinSentences(r.technicalIssues))} ');
      }
      if (!f.standardCalibration) {
        buffer.write(
          'Le calibrage n\'est pas standard : les mesures exprimées en carreaux ont été interprétées avec prudence. ',
        );
      }
      buffer.write(
        'Ces éléments invitent à contrôler le branchement puis à renouveler le tracé avant de conclure.',
      );
    }
    return buffer.toString().trim();
  }

  static String _rhythm(EcgFindings f, EcgInterpretationResult r) {
    final hr = f.heartRateBpm;
    final rateWord = _rateWord(hr);

    switch (f.atrial) {
      case EcgAtrialActivity.sinus:
        if (f.regularity == EcgRegularity.irregularlyIrregular) {
          return 'Le rythme est sinusal mais irrégulièrement irrégulier, avec une fréquence moyenne '
              'de ${hr.toStringAsFixed(0)} par minute (${rateWord.label}). Chaque complexe QRS est précédé '
              'd\'une onde P positive en D1 et D2 ; l\'irrégularité évoque une arythmie sinusale ou '
              'des extrasystoles, à préciser sur un tracé plus long.';
        }
        return 'Le rythme est sinusal et régulier, à ${hr.toStringAsFixed(0)} par minute (${rateWord.label}). '
            'Chaque complexe QRS est précédé d\'une onde P positive en D1 et D2, ce qui confirme '
            'l\'origine sinusale de l\'activation auriculaire.';

      case EcgAtrialActivity.fibrillation:
        return 'Le rythme est irrégulièrement irrégulier, sans onde P identifiable, avec une ligne de base '
            'tremblée : cet aspect est celui d\'une fibrillation atriale, avec une fréquence ventriculaire '
            'moyenne de ${hr.toStringAsFixed(0)} par minute (${rateWord.label}).';

      case EcgAtrialActivity.flutter:
        return 'Il existe une activité atriale régulière en dents de scie, à environ 300 par minute, '
            'avec une réponse ventriculaire à ${hr.toStringAsFixed(0)} par minute (${rateWord.label}) : '
            'il s\'agit d\'un flutter atrial, le plus souvent conduit en 2:1.';

      case EcgAtrialActivity.absent:
        if (f.qrsMs >= EcgInterpreter.normalQrsMax && f.regularity == EcgRegularity.regular) {
          return 'Aucune activité auriculaire n\'est identifiable. Les complexes QRS sont larges et '
              'réguliers, à ${hr.toStringAsFixed(0)} par minute : ce tracé doit être considéré comme une '
              'tachycardie ventriculaire jusqu\'à preuve du contraire, et traité comme telle en urgence.';
        }
        return 'Aucune onde P n\'est visible, ce qui écarte un rythme sinusal. Les complexes QRS sont '
            '${f.qrsMs >= EcgInterpreter.normalQrsMax ? 'larges' : 'fins'} et réguliers à '
            '${hr.toStringAsFixed(0)} par minute (${rateWord.label}), évoquant un rythme '
            '${f.qrsMs >= EcgInterpreter.normalQrsMax ? 'ventriculaire' : 'jonctionnel'}.';
    }
  }

  static String _conduction(EcgFindings f, EcgInterpretationResult r) {
    final buffer = StringBuffer();

    switch (f.avBlock) {
      case EcgAvBlock.none:
        final pr = f.prMs;
        if (f.atrial != EcgAtrialActivity.sinus) {
          buffer.write(
            'L\'espace PR n\'est pas mesurable en l\'absence d\'onde P organisée. ',
          );
        } else if (pr == null) {
          buffer.write(
            'L\'espace PR n\'a pas été mesuré ; il reste à préciser du début de l\'onde P au début du QRS. ',
          );
        } else if (pr < EcgInterpreter.normalPrMin) {
          buffer.write(
            'L\'espace PR est court, mesuré à ${pr.toStringAsFixed(0)} ms '
            '(${(pr / EcgInterpreter.smallBoxMs).toStringAsFixed(1)} petit(s) carreau(x)). '
            'Un PR court fait rechercher une onde delta et une pré-excitation de type Wolff-Parkinson-White. ',
          );
        } else if (pr > EcgInterpreter.normalPrMax) {
          buffer.write(
            'L\'espace PR est allongé à ${pr.toStringAsFixed(0)} ms '
            '(${(pr / EcgInterpreter.smallBoxMs).toStringAsFixed(1)} petit(s) carreau(x)), au-delà de la '
            'limite de 200 ms : il existe un bloc auriculo-ventriculaire du premier degré, complet sur '
            'chaque cycle. ',
          );
        } else {
          buffer.write(
            'L\'espace PR mesure ${pr.toStringAsFixed(0)} ms '
            '(${(pr / EcgInterpreter.smallBoxMs).toStringAsFixed(1)} petit(s) carreau(x)) et se situe dans '
            'les limites de la normale, entre 120 et 200 ms, avec une onde P conduite à chaque QRS. ',
          );
        }
        break;
      case EcgAvBlock.firstDegree:
        buffer.write(
          'Il existe un bloc auriculo-ventriculaire du premier degré : l\'espace PR est constant et '
          'supérieur à 200 ms, chaque onde P étant suivie d\'un complexe QRS. ',
        );
        break;
      case EcgAvBlock.secondDegreeWenckebach:
        buffer.write(
          'Il existe un bloc auriculo-ventriculaire du deuxième degré de type Wenckebach (Mobitz 1) : '
          'l\'espace PR s\'allonge progressivement jusqu\'à ce qu\'un complexe QRS soit manquant. ',
        );
        break;
      case EcgAvBlock.secondDegreeMobitz2:
        buffer.write(
          'Il existe un bloc auriculo-ventriculaire du deuxième degré de type Mobitz 2 : l\'espace PR est '
          'constant, puis un complexe QRS est brutalement absent, ce qui expose à une évolution vers le '
          'bloc complet. ',
        );
        break;
      case EcgAvBlock.thirdDegree:
        buffer.write(
          'Il existe un bloc auriculo-ventriculaire du troisième degré : les ondes P et les complexes QRS '
          'sont totalement dissociés, sans relation entre eux. ',
        );
        break;
    }

    if (f.qrsMs >= EcgInterpreter.normalQrsMax) {
      buffer.write(
        'Le complexe QRS est élargi, mesuré à ${f.qrsMs.toStringAsFixed(0)} ms '
        '(${(f.qrsMs / EcgInterpreter.smallBoxMs).toStringAsFixed(1)} petits carreaux). ',
      );
    } else {
      buffer.write(
        'Le complexe QRS est fin, mesuré à ${f.qrsMs.toStringAsFixed(0)} ms, inférieur à la limite de '
        '120 ms. ',
      );
    }

    switch (f.bundleBranch) {
      case EcgBundleBranch.left:
        buffer.write(
          'Sa morphologie est celle d\'un bloc de branche gauche, avec une onde W en V1 et une onde M en V6. '
          'Dans ce contexte, le segment ST n\'est plus interprétable et une douleur thoracique récente '
          'imposerait de considérer un équivalent de syndrome coronarien aigu.',
        );
        break;
      case EcgBundleBranch.right:
        buffer.write(
          'Sa morphologie est celle d\'un bloc de branche droit, avec un aspect rSR\' en V1 et qRs en V6. '
          'Il peut être complet ou partiel et rester isolé chez un sujet sain, mais peut aussi traduire '
          'une cardiopathie sous-jacente.',
        );
        break;
      case EcgBundleBranch.none:
        buffer.write('Il ne comporte pas de bloc de branche.');
        break;
    }

    return buffer.toString().trim();
  }

  static String _axis(EcgFindings f, EcgInterpretationResult r) {
    if (f.qrsPositiveInLeadI && f.qrsPositiveInLeadAvf) {
      return 'L\'axe du QRS est normal, situé entre 0° et +90° (D1 et aVF positifs).';
    }
    if (f.qrsPositiveInLeadI && !f.qrsPositiveInLeadAvf) {
      return 'L\'axe du QRS est dévié à gauche (D1 positif, aVF négatif). Cette déviation reste '
          'physiologique lorsque D2 est positif ; dans le cas contraire, elle évoque un hémibloc '
          'antérieur gauche.';
    }
    if (!f.qrsPositiveInLeadI && f.qrsPositiveInLeadAvf) {
      return 'L\'axe du QRS est dévié à droite (D1 négatif, aVF positif), ce qui peut correspondre à une '
          'hypertrophie droite, à un bloc de branche droit ou à une inversion des électrodes des membres.';
    }
    return 'L\'axe du QRS est en position extrême, dite « nord-ouest » (D1 et aVF négatifs). Cet aspect '
        'impose de contrôler le branchement des électrodes et fait évoquer un rythme ventriculaire.';
  }

  static String _repolarisation(EcgFindings f, EcgInterpretationResult r) {
    final buffer = StringBuffer();

    if (f.pathologicQ) {
      buffer.write(
        'Une onde Q pathologique est présente : sa profondeur dépasse 0,2 mV et/ou sa largeur dépasse '
        '0,04 s. Elle témoigne d\'une nécrose myocardique ou d\'une séquelle d\'infarctus. ',
      );
    }

    final voltage = (f.sokolowSV1mm != null && f.sokolowRV6mm != null)
        ? f.sokolowSV1mm! + f.sokolowRV6mm!
        : null;
    if (voltage != null && voltage > EcgInterpreter.lvhSokolowThresholdMm) {
      buffer.write(
        'Les voltages sont augmentés, avec un indice de Sokolow-Lyon à ${voltage.toStringAsFixed(0)} mm '
        '(S en V1 + R en V6), en faveur d\'une hypertrophie ventriculaire gauche. ',
      );
    }

    final territory = f.territory == EcgTerritory.none ? '' : _territoryPhrase(f.territory);

    switch (f.stFinding) {
      case EcgStFinding.isoelectric:
        buffer.write('Le segment ST est isoélectrique dans toutes les dérivations. ');
        break;
      case EcgStFinding.elevation:
        final threshold = f.territory == EcgTerritory.anterior ? 2.0 : 1.0;
        final significant = f.stElevationMm >= threshold && f.stTwoContiguousLeads;
        if (significant) {
          buffer.write(
            'Il existe un sus-décalage du segment ST de ${f.stElevationMm.toStringAsFixed(1)} mm '
            '$territory, présent dans au moins deux dérivations contiguës. Cet aspect est en faveur d\'un '
            'syndrome coronarien aigu avec élévation du ST et impose une prise en charge immédiate. ',
          );
        } else {
          buffer.write(
            'Un sus-décalage du segment ST de ${f.stElevationMm.toStringAsFixed(1)} mm est noté '
            '$territory, sans atteindre le seuil de significativité (2 mm en V2-V3, 1 mm dans les autres '
            'dérivations, sur deux dérivations contiguës) ; il doit être comparé à un tracé antérieur. ',
          );
        }
        break;
      case EcgStFinding.depression:
        buffer.write(
          'Le segment ST est abaissé $territory, ce qui évoque une ischémie sous-endocardique, une '
          'surcharge ventriculaire ou un effet médicamenteux. ',
        );
        break;
    }

    switch (f.tWave) {
      case EcgTWave.normal:
        buffer.write('Les ondes T sont de morphologie normale.');
        break;
      case EcgTWave.peaked:
        buffer.write(
          'Les ondes T sont amples et pointues, un aspect à corréler à la kaliémie et à une ischémie '
          'débutante (ondes T hyperaiguës).',
        );
        break;
      case EcgTWave.inverted:
        buffer.write(
          'Les ondes T sont inversées, dans un contexte d\'ischémie, de surcharge ou de séquelle '
          'd\'infarctus de plus de 24 heures.',
        );
        break;
      case EcgTWave.flat:
        buffer.write(
          'Les ondes T sont aplaties, possiblement en rapport avec une hypokaliémie, une ischémie ou un '
          'traitement en cours.',
        );
        break;
    }

    return buffer.toString().trim();
  }

  static String _qt(EcgFindings f, EcgInterpretationResult r) {
    final boxes = f.qtMs / EcgInterpreter.largeBoxMs;
    final limit = EcgInterpreter.qtcUpperLimit(isFemale: f.isFemale);
    final base = 'L\'intervalle QT mesure ${f.qtMs.toStringAsFixed(0)} ms, soit '
        '${boxes.toStringAsFixed(1)} grands carreaux, avec un QTc corrigé de '
        '${r.qtcBazett.toStringAsFixed(0)} ms selon Bazett et de '
        '${r.qtcFridericia.toStringAsFixed(0)} ms selon Fridericia. ';

    if (r.qtcBazett >= EcgInterpreter.qtcCriticalMs) {
      return '$base Cette valeur dépasse 500 ms et constitue un facteur de risque majeur de torsades de '
          'pointes : il convient d\'interrompre les traitements allongeant le QT et de corriger la '
          'kaliémie ainsi que la magnésémie.';
    }
    if (r.qtcBazett > limit) {
      return '$base Le QTc est allongé au-delà de ${limit.toStringAsFixed(0)} ms : une surveillance '
          'électrocardiographique et un contrôle du ionogramme sont indiqués, en réévaluant les '
          'médicaments en cours.';
    }
    if (r.qtcBazett < EcgInterpreter.qtcShortMs) {
      return '$base Le QTc est court, inférieur à 340 ms, ce qui invite à rechercher une hypercalcémie ou '
          'un syndrome du QT court.';
    }
    return '$base Ces valeurs se situent dans les limites de la normale, en deçà de '
        '${limit.toStringAsFixed(0)} ms.';
  }

  static String _conclusion(
    EcgFindings f,
    EcgInterpretationResult r,
    EcgReportVerdict verdict,
  ) {
    final hr = f.heartRateBpm.toStringAsFixed(0);

    if (verdict == EcgReportVerdict.normal) {
      final intervals = f.prMs == null
          ? 'l\'espace QRS est dans les limites'
          : 'les espaces PR et QRS sont dans les limites';
      return 'En conclusion, cet électrocardiogramme est de qualité satisfaisante et ne met pas en '
          'évidence d\'anomalie significative : le rythme est sinusal et régulier à $hr par minute, '
          'l\'axe est normal, $intervals, le segment ST est isoélectrique '
          'et le QTc est normal.';
    }

    final anomalies = <String>[];
    if (f.atrial != EcgAtrialActivity.sinus) {
      anomalies.add('un trouble du rythme (${r.rhythmLabel.toLowerCase()})');
    }
    if (f.atrial == EcgAtrialActivity.sinus && f.regularity == EcgRegularity.irregularlyIrregular) {
      anomalies.add('une irrégularité du rythme sinusal');
    }
    if (!(f.qrsPositiveInLeadI && f.qrsPositiveInLeadAvf)) {
      anomalies.add('une déviation de l\'axe (${r.axisLabel})');
    }
    if (f.avBlock != EcgAvBlock.none) {
      anomalies.add('un trouble de la conduction auriculo-ventriculaire');
    }
    if (f.qrsMs >= EcgInterpreter.normalQrsMax) {
      anomalies.add('un élargissement du QRS');
    }
    if (f.bundleBranch == EcgBundleBranch.left) {
      anomalies.add('un bloc de branche gauche');
    } else if (f.bundleBranch == EcgBundleBranch.right) {
      anomalies.add('un bloc de branche droit');
    }
    if (f.pathologicQ) {
      anomalies.add('des ondes Q pathologiques');
    }
    if (f.stFinding != EcgStFinding.isoelectric) {
      anomalies.add(f.stFinding == EcgStFinding.elevation
          ? 'un sus-décalage du segment ST'
          : 'un sous-décalage du segment ST');
    }
    if (f.tWave != EcgTWave.normal) {
      anomalies.add('une anomalie de l\'onde T');
    }
    if (r.qtcBazett > EcgInterpreter.qtcUpperLimit(isFemale: f.isFemale)) {
      anomalies.add('un allongement du QTc');
    }

    if (verdict == EcgReportVerdict.incomplete) {
      return 'En conclusion, cet enregistrement ne peut être interprété avec certitude en raison d\'une '
          'qualité technique insuffisante. Les éléments recueillis sont les '
          'suivants : ${anomalies.isEmpty ? 'rythme à $hr par minute sans anomalie évidente' : anomalies.join(', ')}. '
          'Un nouveau tracé de bonne qualité est recommandé avant toute conclusion.';
    }

    final list = anomalies.isEmpty
        ? 'des éléments à confronter au contexte clinique'
        : _joinFrench(anomalies);
    return 'En conclusion, cet électrocardiogramme met en évidence $list. Le rythme est à $hr par minute '
        'et l\'ensemble doit être interprété au regard du contexte clinique, des antécédents et d\'un '
        'tracé de comparaison.';
  }

  static EcgReportVerdict _verdict(EcgFindings f, EcgInterpretationResult r) {
    if (!r.isTechnicallyValid) {
      return EcgReportVerdict.incomplete;
    }

    final rateOk = f.heartRateBpm >= 50 && f.heartRateBpm <= 100;
    final prOk = f.prMs == null || (f.prMs! >= EcgInterpreter.normalPrMin && f.prMs! <= EcgInterpreter.normalPrMax);
    final qtcOk = r.qtcBazett <= EcgInterpreter.qtcUpperLimit(isFemale: f.isFemale) &&
        r.qtcBazett >= EcgInterpreter.qtcShortMs;
    final voltage = (f.sokolowSV1mm != null && f.sokolowRV6mm != null)
        ? f.sokolowSV1mm! + f.sokolowRV6mm!
        : 0.0;

    final normal = rateOk &&
        prOk &&
        qtcOk &&
        f.atrial == EcgAtrialActivity.sinus &&
        f.regularity == EcgRegularity.regular &&
        f.avBlock == EcgAvBlock.none &&
        f.qrsMs < EcgInterpreter.normalQrsMax &&
        f.bundleBranch == EcgBundleBranch.none &&
        !f.pathologicQ &&
        f.stFinding == EcgStFinding.isoelectric &&
        f.tWave == EcgTWave.normal &&
        f.qrsPositiveInLeadI &&
        f.qrsPositiveInLeadAvf &&
        voltage <= EcgInterpreter.lvhSokolowThresholdMm;

    return normal ? EcgReportVerdict.normal : EcgReportVerdict.abnormal;
  }

  static String _confidenceNote(EcgInterpretationResult r, EcgPatientInfo patient) {
    final level = switch (r.confidence) {
      EcgConfidence.high => 'élevée',
      EcgConfidence.medium => 'moyenne',
      EcgConfidence.low => 'faible',
    };
    final buffer = StringBuffer('Niveau de confiance de l\'interprétation : $level.');
    if (r.missingData.isNotEmpty) {
      buffer.write(' Mesures à compléter pour l\'affiner : ${r.missingData.join(', ')}.');
    }
    if (patient.indication.trim().isEmpty) {
      buffer.write(' L\'indication de l\'examen n\'a pas été renseignée.');
    }
    return buffer.toString();
  }

  // ---------------------------------------------------------------------------
  // Utilitaires rédactionnels
  // ---------------------------------------------------------------------------

  static ({String label, String detail}) _rateWord(double hr) {
    if (hr < 40) return (label: 'bradycardie sévère', detail: 'urgence');
    if (hr < 50) return (label: 'bradycardie', detail: 'à explorer');
    if (hr < 60) return (label: 'fréquence basse', detail: 'souvent physiologique');
    if (hr <= 100) return (label: 'fréquence normale', detail: '');
    if (hr < 150) return (label: 'tachycardie', detail: 'à préciser');
    return (label: 'tachycardie rapide', detail: 'à traiter');
  }

  static String _territoryPhrase(EcgTerritory territory) {
    switch (territory) {
      case EcgTerritory.anterior:
        return 'en territoire antérieur (V1 à V4)';
      case EcgTerritory.inferior:
        return 'en territoire inférieur (D2, D3 et aVF)';
      case EcgTerritory.lateral:
        return 'en territoire latéral (D1, aVL, V5 et V6)';
      case EcgTerritory.none:
        return '';
    }
  }

  static String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  static String _joinSentences(List<String> items) {
    return items.map((e) => e.endsWith('.') ? e : '$e.').join(' ');
  }

  static String _joinFrench(List<String> items) {
    if (items.length == 1) return items.first;
    return '${items.sublist(0, items.length - 1).join(', ')} et ${items.last}';
  }
}
