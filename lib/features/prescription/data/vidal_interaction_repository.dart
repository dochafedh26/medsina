import 'dart:convert';
import 'package:flutter/services.dart';
import '../../../core/network/supabase_service.dart';

enum InteractionSeverity {
  contraindicated, // 🔴 Contre-indication
  disadvised,      // 🟠 Association déconseillée
  precaution,      // 🟡 Précaution d'emploi
  info,            // 🔵 À prendre en compte / Information
}

class PrescribedTarget {
  final String name;
  final String? activeDci;

  const PrescribedTarget({
    required this.name,
    this.activeDci,
  });
}

class VidalInteractionRule {
  final List<String> drugA;
  final List<String> drugB;
  final InteractionSeverity severity;
  final int severityLevel;
  final String title;
  final String description;
  final String recommendation;

  const VidalInteractionRule({
    required this.drugA,
    required this.drugB,
    required this.severity,
    required this.severityLevel,
    required this.title,
    required this.description,
    required this.recommendation,
  });

  factory VidalInteractionRule.fromJson(Map<String, dynamic> json) {
    InteractionSeverity sev;
    switch (json['severity']?.toString().toLowerCase()) {
      case 'contraindicated':
        sev = InteractionSeverity.contraindicated;
        break;
      case 'disadvised':
        sev = InteractionSeverity.disadvised;
        break;
      case 'precaution':
        sev = InteractionSeverity.precaution;
        break;
      default:
        sev = InteractionSeverity.info;
        break;
    }

    final rawA = json['drug_a'] ?? json['drugA'];
    final rawB = json['drug_b'] ?? json['drugB'];

    return VidalInteractionRule(
      drugA: (rawA as List<dynamic>?)?.map((e) => e.toString().toUpperCase()).toList() ?? [],
      drugB: (rawB as List<dynamic>?)?.map((e) => e.toString().toUpperCase()).toList() ?? [],
      severity: sev,
      severityLevel: json['severity_level'] is int 
          ? json['severity_level'] 
          : (json['severityLevel'] is int ? json['severityLevel'] : 1),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      recommendation: json['recommendation']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'drug_a': drugA,
      'drug_b': drugB,
      'severity': severity.name,
      'severity_level': severityLevel,
      'title': title,
      'description': description,
      'recommendation': recommendation,
      'source': 'vidal_official',
    };
  }
}

class VidalInteractionRepository {
  static List<VidalInteractionRule>? _cachedRules;

  static Future<List<VidalInteractionRule>> loadRules() async {
    if (_cachedRules != null && _cachedRules!.isNotEmpty) {
      return _cachedRules!;
    }
    // 1. Load local bundle for 0ms instant offline startup
    try {
      final jsonStr = await rootBundle.loadString('assets/data/vidal_drug_interactions.json');
      final List<dynamic> list = json.decode(jsonStr) as List<dynamic>;
      _cachedRules = list.map((item) => VidalInteractionRule.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      _cachedRules = [];
    }

    // 2. Fetch fresh / auto-enriched rules from Supabase in background
    try {
      final cloudInteractions = await SupabaseService.fetchVidalInteractions();
      if (cloudInteractions.isNotEmpty) {
        final existingTitles = _cachedRules!.map((r) => r.title.toLowerCase()).toSet();
        for (final item in cloudInteractions) {
          final rule = VidalInteractionRule.fromJson(item);
          if (!existingTitles.contains(rule.title.toLowerCase())) {
            _cachedRules!.add(rule);
            existingTitles.add(rule.title.toLowerCase());
          }
        }
      }
    } catch (_) {}

    return _cachedRules ?? [];
  }

  /// Auto-enrich repository with a new rule (Local Cache + Supabase Cloud)
  static Future<void> recordNewInteraction(VidalInteractionRule newRule) async {
    _cachedRules ??= [];
    final alreadyExists = _cachedRules!.any((r) => r.title.toLowerCase() == newRule.title.toLowerCase());
    if (!alreadyExists) {
      _cachedRules!.add(newRule);
    }
    try {
      await SupabaseService.insertVidalInteraction(newRule.toJson());
    } catch (_) {}
  }


  static String normalize(String input) {
    var s = input.trim().toUpperCase();
    const accents = {
      'À': 'A', 'Á': 'A', 'Â': 'A', 'Ã': 'A', 'Ä': 'A', 'Å': 'A',
      'È': 'E', 'É': 'E', 'Ê': 'E', 'Ë': 'E',
      'Ì': 'I', 'Í': 'I', 'Î': 'I', 'Ï': 'I',
      'Ò': 'O', 'Ó': 'O', 'Ô': 'O', 'Õ': 'O', 'Ö': 'O',
      'Ù': 'U', 'Ú': 'U', 'Û': 'U', 'Ü': 'U',
      'Ý': 'Y', 'Ÿ': 'Y',
      'Ç': 'C', 'Ñ': 'N',
      'Œ': 'OE', 'Æ': 'AE',
    };
    accents.forEach((key, value) {
      s = s.replaceAll(key, value);
    });
    return s;
  }

  static Set<String> _extractPharmacologicalClasses(String name, String? dci) {
    final combined = '${normalize(name)} ${normalize(dci ?? '')}';
    final classes = <String>{};

    // AVK
    if (combined.contains('ACENOCOUMAROL') ||
        combined.contains('SINTROM') ||
        combined.contains('WARFARINE') ||
        combined.contains('COUMADINE') ||
        combined.contains('FLUINDIONE')) {
      classes.addAll(['AVK', 'ANTIVITAMINE K', 'ANTICOAGULANT', 'ANTICOAGULANTS']);
    }

    // AOD
    if (combined.contains('RIVAROXABAN') ||
        combined.contains('XARELTO') ||
        combined.contains('APIXABAN') ||
        combined.contains('ELIQUIS') ||
        combined.contains('DABIGATRAN') ||
        combined.contains('PRADAXA') ||
        combined.contains('EDOXABAN')) {
      classes.addAll(['AOD', 'ANTICOAGULANT', 'ANTICOAGULANTS']);
    }

    // Antiagrégants plaquettaires
    if (combined.contains('CLOPIDOGREL') ||
        combined.contains('PLAVIX') ||
        combined.contains('DAZIL') ||
        combined.contains('PIDOGREL') ||
        combined.contains('TICAGRELOR') ||
        combined.contains('BRILIQUE') ||
        combined.contains('PRASUGREL') ||
        combined.contains('EFIENT') ||
        combined.contains('KARDEGIC') ||
        combined.contains('ASPEGIC') ||
        combined.contains('ACIDE ACETYLSALICYLIQUE') ||
        combined.contains('ASPIRINE') ||
        combined.contains('TICLOPIDINE')) {
      classes.addAll(['ANTIAGREGANT', 'ANTIAGREGANTS', 'ANTIAGREGANTS PLAQUETTAIRES']);
    }

    // Héparines & HBPM
    if (combined.contains('ENOXAPARINE') ||
        combined.contains('LOVENOX') ||
        combined.contains('NADROPARINE') ||
        combined.contains('FRAXIPARINE') ||
        combined.contains('TINZAPARINE') ||
        combined.contains('INNOHEP') ||
        combined.contains('HEPARINE')) {
      classes.addAll(['HEPARINE', 'HBPM', 'HNF', 'ANTICOAGULANT', 'ANTICOAGULANTS']);
    }

    // AINS
    if (combined.contains('KETOPROFENE') ||
        combined.contains('PROFENID') ||
        combined.contains('DICLOFENAC') ||
        combined.contains('VOLTARENE') ||
        combined.contains('IBUPROFENE') ||
        combined.contains('ADVIL') ||
        combined.contains('NAPROXENE') ||
        combined.contains('APRANAX') ||
        combined.contains('CELECOXIB') ||
        combined.contains('MELOXICAM') ||
        combined.contains('INDOMETACINE') ||
        combined.contains('PIROXICAM') ||
        combined.contains('TIAPROFENIQUE')) {
      classes.addAll(['AINS', 'ANTI-INFLAMMATOIRES NON STEROIDIENS']);
    }

    // Corticoïdes
    if (combined.contains('PREDNISONE') ||
        combined.contains('CORTANCYL') ||
        combined.contains('PREDNISOLONE') ||
        combined.contains('SOLUPRED') ||
        combined.contains('METHYLPREDNISOLONE') ||
        combined.contains('SOLUMEDROL') ||
        combined.contains('BETAMETHASONE') ||
        combined.contains('DEXAMETHASONE') ||
        combined.contains('HYDROCORTISONE')) {
      classes.addAll(['CORTICOIDES', 'CORTICOIDE']);
    }

    // IPP
    if (combined.contains('OMEPRAZOLE') ||
        combined.contains('MOPRAL') ||
        combined.contains('ESOMEPRAZOLE') ||
        combined.contains('INEXIUM') ||
        combined.contains('PANTOPRAZOLE') ||
        combined.contains('RABEPRAZOLE') ||
        combined.contains('LANSOPRAZOLE')) {
      classes.addAll(['IPP', 'INHIBITEURS DE LA POMPE A PROTONS']);
    }

    // Macrolides
    if (combined.contains('CLARITHROMYCINE') ||
        combined.contains('ZECLAR') ||
        combined.contains('ERYTHROMYCINE') ||
        combined.contains('AZITHROMYCINE') ||
        combined.contains('ZITHROMAX') ||
        combined.contains('ROXITHROMYCINE') ||
        combined.contains('JOSAMYCINE') ||
        combined.contains('SPIRAMYCINE') ||
        combined.contains('TELITHROMYCINE')) {
      classes.addAll(['MACROLIDES', 'MACROLIDE']);
    }

    // Statines
    if (combined.contains('ATORVASTATINE') ||
        combined.contains('TAHOR') ||
        combined.contains('SIMVASTATINE') ||
        combined.contains('ZOCOR') ||
        combined.contains('ROSUVASTATINE') ||
        combined.contains('CRESTOR') ||
        combined.contains('PRAVASTATINE')) {
      classes.addAll(['STATINES', 'STATINE']);
    }

    // IEC
    if (combined.contains('PERINDOPRIL') ||
        combined.contains('COVERSYL') ||
        combined.contains('RAMIPRIL') ||
        combined.contains('TRIATEC') ||
        combined.contains('ENALAPRIL') ||
        combined.contains('CAPTOPRIL')) {
      classes.addAll(['IEC']);
    }

    // ARA2
    if (combined.contains('VALSARTAN') ||
        combined.contains('TAREG') ||
        combined.contains('CANDESARTAN') ||
        combined.contains('LOSARTAN') ||
        combined.contains('IRBESARTAN') ||
        combined.contains('TELMISARTAN')) {
      classes.addAll(['ARA2', 'SARTANS']);
    }

    // Diurétiques
    if (combined.contains('SPIRONOLACTONE') ||
        combined.contains('ALDACTONE') ||
        combined.contains('EPLERENONE')) {
      classes.addAll(['DIURETIQUE_HYPERKALIEMIANT', 'SPIRONOLACTONE']);
    }
    if (combined.contains('FUROSEMIDE') ||
        combined.contains('LASILIX') ||
        combined.contains('HYDROCHLOROTHIAZIDE') ||
        combined.contains('INDAPAMIDE')) {
      classes.addAll(['DIURETIQUE', 'DIURETIQUES']);
    }

    // Bêta-bloquants
    if (combined.contains('BISOPROLOL') ||
        combined.contains('CARDENSIEL') ||
        combined.contains('METOPROLOL') ||
        combined.contains('ATENOLOL') ||
        combined.contains('CARVEDILOL') ||
        combined.contains('NEBIVOLOL') ||
        combined.contains('PROPRANOLOL')) {
      classes.addAll(['BETA-BLOQUANTS', 'BETA-BLOQUANT', 'BETABLOQUANT']);
    }

    // Dérivés nitrés
    if (combined.contains('TRINITRINE') ||
        combined.contains('NATISPRAY') ||
        combined.contains('ISOSORBIDE') ||
        combined.contains('RISORDAN') ||
        combined.contains('MOLSIDOMINE')) {
      classes.addAll(['DERIVES NITRES', 'DERIVES_NITRES']);
    }

    // Inhibiteurs PDE5
    if (combined.contains('SILDENAFIL') ||
        combined.contains('VIAGRA') ||
        combined.contains('TADALAFIL') ||
        combined.contains('CIALIS') ||
        combined.contains('VARDENAFIL')) {
      classes.addAll(['INHIBITEURS PDE5', 'INHIBITEURS_PDE5']);
    }

    // Fluoroquinolones
    if (combined.contains('CIPROFLOXACINE') ||
        combined.contains('CIFLOX') ||
        combined.contains('LEVOFLOXACINE') ||
        combined.contains('OFLOXACINE') ||
        combined.contains('MOXIFLOXACINE')) {
      classes.addAll(['FLUOROQUINOLONES', 'FLUOROQUINOLONE']);
    }

    // Aminosides
    if (combined.contains('GENTAMICINE') ||
        combined.contains('AMIKACINE') ||
        combined.contains('TOBRAMYCINE')) {
      classes.addAll(['AMINOSIDES', 'AMINOSIDE']);
    }

    // ISRS
    if (combined.contains('FLUOXETINE') ||
        combined.contains('PAROXETINE') ||
        combined.contains('SERTRALINE') ||
        combined.contains('ESCITALOPRAM') ||
        combined.contains('CITALOPRAM') ||
        combined.contains('VENLAFAXINE')) {
      classes.addAll(['ISRS', 'ANTIDEPRESSEURS SEROTONINERGIQUES']);
    }

    // Opioïdes
    if (combined.contains('MORPHINE') ||
        combined.contains('OXYCODONE') ||
        combined.contains('FENTANYL') ||
        combined.contains('TRAMADOL') ||
        combined.contains('CODEINE')) {
      classes.addAll(['OPIOIDES', 'OPIOIDE']);
    }

    // Benzodiazépines
    if (combined.contains('DIAZEPAM') ||
        combined.contains('VALIUM') ||
        combined.contains('ALPRAZOLAM') ||
        combined.contains('XANAX') ||
        combined.contains('LORAZEPAM') ||
        combined.contains('BROMAZEPAM') ||
        combined.contains('CLONAZEPAM')) {
      classes.addAll(['BENZODIAZEPINES', 'BENZODIAZEPINE']);
    }

    return classes;
  }

  static bool _matchesDrug(String drugInput, String? activeDci, List<String> patterns) {
    final inputUpper = normalize(drugInput);
    final dciUpper = normalize(activeDci ?? '');
    final classes = _extractPharmacologicalClasses(inputUpper, dciUpper);

    for (final pattern in patterns) {
      final p = normalize(pattern);
      if (p.isEmpty) continue;

      // 1. Direct equality on brand, dci or inferred class
      if (inputUpper == p || dciUpper == p || classes.contains(p)) {
        return true;
      }

      // 2. DCI or Brand contains pattern (e.g. "CLOPIDOGREL HYDROGENOSULFATE..." contains "CLOPIDOGREL")
      if (p.length >= 4) {
        if (dciUpper.contains(p) || inputUpper.contains(p)) {
          return true;
        }
      }

      // 3. Pattern contains token (e.g. "SINTROM 4MG" contains "SINTROM")
      if (inputUpper.length >= 4 && p.length >= 4) {
        if (inputUpper.contains(p) || p.contains(inputUpper)) {
          return true;
        }
      }
    }
    return false;
  }

  static List<VidalInteractionRule> findInteractions(
    List<PrescribedTarget> prescribedDrugs,
    List<VidalInteractionRule> rules,
  ) {
    final detected = <VidalInteractionRule>[];
    final seenTitles = <String>{};

    for (int i = 0; i < prescribedDrugs.length; i++) {
      for (int j = i + 1; j < prescribedDrugs.length; j++) {
        final drug1 = prescribedDrugs[i];
        final drug2 = prescribedDrugs[j];

        for (final rule in rules) {
          final matchForward = _matchesDrug(drug1.name, drug1.activeDci, rule.drugA) &&
              _matchesDrug(drug2.name, drug2.activeDci, rule.drugB);
          final matchReverse = _matchesDrug(drug2.name, drug2.activeDci, rule.drugA) &&
              _matchesDrug(drug1.name, drug1.activeDci, rule.drugB);

          if ((matchForward || matchReverse) && !seenTitles.contains(rule.title)) {
            detected.add(rule);
            seenTitles.add(rule.title);
          }
        }
      }
    }

    // Sort descending by severity level
    detected.sort((a, b) => b.severityLevel.compareTo(a.severityLevel));
    return detected;
  }
}

