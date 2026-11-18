import 'package:flutter_test/flutter_test.dart';
import 'package:medsina/features/clinical/models/ecg_interpreter_model.dart';

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

EcgReportSection section(EcgInterpretationResult r, String title) {
  return r.sections.firstWhere((s) => s.title == title);
}

void main() {
  group('Fréquence', () {
    test('70/min est une fréquence normale', () {
      final r = EcgInterpreter.interpret(findings());
      expect(section(r, 'Fréquence').value, contains('Normale'));
      expect(section(r, 'Fréquence').severity, EcgSeverity.normal);
    });

    test('45/min est une bradycardie', () {
      final r = EcgInterpreter.interpret(findings(hr: 45));
      expect(section(r, 'Fréquence').value, contains('Bradycardie'));
      expect(section(r, 'Fréquence').severity, EcgSeverity.warning);
    });

    test('35/min déclenche une alerte critique', () {
      final r = EcgInterpreter.interpret(findings(hr: 35));
      expect(section(r, 'Fréquence').severity, EcgSeverity.critical);
      expect(r.criticalAlerts.join(' '), contains('Bradycardie sévère'));
    });

    test('la fréquence est déduite des grands carreaux (300/RR)', () {
      expect(EcgInterpreter.interpret(findings(hr: 75)).rrMs, closeTo(800, 0.1));
    });
  });

  group('Rythme', () {
    test('rythme sinusal', () {
      final r = EcgInterpreter.interpret(findings());
      expect(r.rhythmLabel, 'Rythme sinusal');
      expect(r.sections.first.title, 'Fréquence');
    });

    test('fibrillation atriale', () {
      final r = EcgInterpreter.interpret(
        findings(atrial: EcgAtrialActivity.fibrillation, regularity: EcgRegularity.irregularlyIrregular),
      );
      expect(r.rhythmLabel, 'Fibrillation atriale');
      expect(section(r, 'Rythme').detail, contains('rrégulièrement irrégulier'));
    });

    test('flutter atrial à 300/min d\'activité auriculaire', () {
      final r = EcgInterpreter.interpret(findings(atrial: EcgAtrialActivity.flutter, hr: 150));
      expect(r.rhythmLabel, 'Flutter atrial');
      expect(section(r, 'Rythme').detail, contains('300/min'));
    });

    test('QRS large régulier sans P = tachycardie ventriculaire', () {
      final r = EcgInterpreter.interpret(
        findings(atrial: EcgAtrialActivity.absent, qrsMs: 170, hr: 180),
      );
      expect(r.rhythmLabel, contains('ventriculaire'));
      expect(r.criticalAlerts.join(' '), contains('tachycardie ventriculaire'));
    });
  });

  group('Axe', () {
    test('D1 et aVF positifs = axe normal', () {
      expect(EcgInterpreter.interpret(findings()).axisLabel, contains('normal'));
    });

    test('D1 positif et aVF négatif = déviation gauche', () {
      expect(EcgInterpreter.interpret(findings(avf: false)).axisLabel, contains('gauche'));
    });

    test('D1 négatif et aVF positif = déviation droite', () {
      expect(EcgInterpreter.interpret(findings(leadI: false)).axisLabel, contains('droite'));
    });

    test('D1 et aVF négatifs = axe extrême et avertissement', () {
      final r = EcgInterpreter.interpret(findings(leadI: false, avf: false));
      expect(r.axisLabel, contains('extrême'));
      expect(r.warnings.join(' '), contains('nord-ouest'));
    });
  });

  group('Conduction', () {
    test('PR normal entre 120 et 200 ms', () {
      final r = EcgInterpreter.interpret(findings(prMs: 160));
      expect(section(r, 'Espace PR').value, contains('normal'));
    });

    test('PR à 240 ms = bloc AV du 1er degré', () {
      final r = EcgInterpreter.interpret(findings(prMs: 240));
      expect(section(r, 'Espace PR').value, contains('allongé'));
      expect(section(r, 'Espace PR').detail, contains('1er degré'));
    });

    test('PR court évoque un WPW', () {
      final r = EcgInterpreter.interpret(findings(prMs: 100));
      expect(section(r, 'Espace PR').detail, contains('WPW'));
    });

    test('bloc AV du 3e degré = alerte critique', () {
      final r = EcgInterpreter.interpret(findings(avBlock: EcgAvBlock.thirdDegree));
      expect(section(r, 'Espace PR').severity, EcgSeverity.critical);
      expect(r.criticalAlerts.join(' '), contains('3e degré'));
    });

    test('bloc AV Mobitz 2 = alerte critique', () {
      final r = EcgInterpreter.interpret(findings(avBlock: EcgAvBlock.secondDegreeMobitz2));
      expect(section(r, 'Espace PR').severity, EcgSeverity.critical);
    });

    test('QRS ≥ 120 ms est large', () {
      final r = EcgInterpreter.interpret(findings(qrsMs: 140));
      expect(section(r, 'Complexe QRS').value, contains('large'));
    });
  });

  group('Blocs de branche', () {
    test('BBDG rend le ST ininterprétable et alerte', () {
      final r = EcgInterpreter.interpret(findings(qrsMs: 150, bbb: EcgBundleBranch.left));
      expect(section(r, 'Complexe QRS').severity, EcgSeverity.critical);
      expect(section(r, 'Complexe QRS').detail, contains('ST n\'est plus interprétable'));
      expect(r.criticalAlerts.join(' '), contains('BBDG'));
    });

    test('BBDD reste un avertissement sans alerte critique', () {
      final r = EcgInterpreter.interpret(findings(qrsMs: 130, bbb: EcgBundleBranch.right));
      expect(section(r, 'Complexe QRS').detail, contains('rSR'));
      expect(r.criticalAlerts, isEmpty);
    });
  });

  group('ST, T et territoires', () {
    test('sus-décalage antérieur ≥ 2 mm dans 2 dérivations = SCA ST+', () {
      final r = EcgInterpreter.interpret(
        findings(st: EcgStFinding.elevation, territory: EcgTerritory.anterior, stMm: 3),
      );
      expect(section(r, 'Segment ST').severity, EcgSeverity.critical);
      expect(r.criticalAlerts.join(' '), contains('SCA ST+'));
    });

    test('sus-décalage antérieur de 1,5 mm reste sous le seuil de 2 mm', () {
      final r = EcgInterpreter.interpret(
        findings(st: EcgStFinding.elevation, territory: EcgTerritory.anterior, stMm: 1.5),
      );
      expect(section(r, 'Segment ST').severity, EcgSeverity.warning);
      expect(r.criticalAlerts.join(' '), isNot(contains('SCA ST+')));
    });

    test('sus-décalage inférieur de 1 mm suffit', () {
      final r = EcgInterpreter.interpret(
        findings(st: EcgStFinding.elevation, territory: EcgTerritory.inferior, stMm: 1),
      );
      expect(r.criticalAlerts.join(' '), contains('SCA ST+'));
      expect(section(r, 'Segment ST').detail, contains('D2, D3, aVF'));
    });

    test('sus-décalage isolé sans 2 dérivations contiguës n\'est pas critique', () {
      final r = EcgInterpreter.interpret(
        findings(
          st: EcgStFinding.elevation,
          territory: EcgTerritory.inferior,
          stMm: 2,
          twoLeads: false,
        ),
      );
      expect(section(r, 'Segment ST').severity, EcgSeverity.warning);
    });

    test('onde T pointue alerte sur le potassium', () {
      final r = EcgInterpreter.interpret(findings(t: EcgTWave.peaked));
      expect(r.warnings.join(' '), contains('potassium'));
    });

    test('onde Q pathologique signalée', () {
      final r = EcgInterpreter.interpret(findings(qPath: true));
      expect(r.warnings.join(' '), contains('Onde Q pathologique'));
    });

    test('HVG si S(V1) + R(V6) > 35 mm', () {
      final r = EcgInterpreter.interpret(findings(sV1: 25, rV6: 15));
      expect(r.warnings.join(' '), contains('Hypertrophie ventriculaire gauche'));
    });

    test('pas d\'HVG à 30 mm', () {
      final r = EcgInterpreter.interpret(findings(sV1: 18, rV6: 12));
      expect(r.warnings.join(' '), isNot(contains('Hypertrophie')));
    });
  });

  group('QT / QTc', () {
    test('QT 400 ms à 60/min = QTc normal', () {
      final r = EcgInterpreter.interpret(findings(hr: 60, qtMs: 400));
      expect(r.qtcBazett, closeTo(400, 0.5));
      expect(section(r, 'QT / QTc').value, contains('normal'));
    });

    test('QTc ≥ 500 ms = alerte torsades de pointes', () {
      final r = EcgInterpreter.interpret(findings(hr: 60, qtMs: 520));
      expect(section(r, 'QT / QTc').severity, EcgSeverity.critical);
      expect(r.criticalAlerts.join(' '), contains('torsades de pointes'));
    });

    test('seuil QTc plus bas chez la femme (450 vs 460)', () {
      final male = EcgInterpreter.interpret(findings(hr: 60, qtMs: 455));
      final female = EcgInterpreter.interpret(findings(hr: 60, qtMs: 455, female: true));
      expect(section(male, 'QT / QTc').value, contains('allongé'));
      expect(section(female, 'QT / QTc').value, contains('normal'));
    });

    test('QTc court sous 340 ms', () {
      final r = EcgInterpreter.interpret(findings(hr: 60, qtMs: 320));
      expect(section(r, 'QT / QTc').value, contains('court'));
    });
  });

  group('Contrôles techniques et confiance', () {
    test('aVR positif invalide le tracé', () {
      final r = EcgInterpreter.interpret(findings(avrNegative: false));
      expect(r.isTechnicallyValid, isFalse);
      expect(r.technicalIssues.join(' '), contains('aVR'));
      expect(r.confidence, EcgConfidence.low);
    });

    test('D1 négatif invalide le branchement', () {
      final r = EcgInterpreter.interpret(findings(leadI: false));
      expect(r.technicalIssues.join(' '), contains('D1 négatif'));
    });

    test('progression de R anormale signalée', () {
      final r = EcgInterpreter.interpret(findings(rProgression: false));
      expect(r.technicalIssues.join(' '), contains('Progression de l\'onde R'));
    });

    test('mesures incomplètes = confiance moyenne', () {
      final r = EcgInterpreter.interpret(findings(prMs: null));
      expect(r.confidence, EcgConfidence.medium);
      expect(r.missingData, contains('intervalle PR'));
    });

    test('toutes les mesures = confiance élevée', () {
      final r = EcgInterpreter.interpret(findings(sV1: 10, rV6: 12));
      expect(r.confidence, EcgConfidence.high);
      expect(r.missingData, isEmpty);
    });

    test('calibrage non standard averti', () {
      final r = EcgInterpreter.interpret(findings(standard: false));
      expect(r.warnings.join(' '), contains('Calibrage non standard'));
    });
  });

  group('Référentiel', () {
    test('le référentiel reprend les valeurs du cours', () {
      expect(EcgReference.normalValues.length, 9);
      expect(EcgReference.territories.length, 5);
      expect(EcgReference.infarctionTimeline.length, 3);
      final pr = EcgReference.normalValues.firstWhere((r) => r['param'] == 'Intervalle PR');
      expect(pr['value'], '120-200 ms');
    });

    test('table de fréquence 300/RR', () {
      expect(EcgInterpreter.rateFromLargeBoxes[4], 75);
      expect(EcgInterpreter.rateFromLargeBoxes[5], 60);
      expect(EcgInterpreter.rateFromLargeBoxes[10], 30);
    });
  });
}
