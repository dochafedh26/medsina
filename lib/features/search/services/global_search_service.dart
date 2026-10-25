import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../clinical/data/clinical_repository.dart';
import '../../clinical/models/cat_protocol_model.dart';
import '../../clinical/models/emergency_drug_model.dart';
import '../../practical_tools/models/lab_value_model.dart';
import '../../revision/data/course_summary_repository.dart';
import '../../revision/data/residency_repository.dart';
import '../../revision/models/course_summary_model.dart';
import '../../revision/models/module_model.dart';
import '../../revision/models/qcm_model.dart';
import '../models/search_result_item.dart';

class GlobalSearchService {
  GlobalSearchService._();
  static final GlobalSearchService instance = GlobalSearchService._();

  static const String _recentSearchesKey = 'medsina_omnisearch_recents';

  // In-memory data caches for sub-millisecond search
  List<MedicalModuleModel> _modules = [];
  Map<String, CourseSummaryModel> _summaries = {};
  List<ClinicalProtocol> _protocols = [];
  List<OnCallMemento> _mementos = [];
  List<EmergencyDrugModel> _drugs = [];
  List<LabValue> _labs = [];
  bool _isPrewarmed = false;

  /// Clinical calculators catalog for instant search
  final List<Map<String, dynamic>> _clinicalScores = [
    {
      'id': 'score_glasgow',
      'title': 'Score de Glasgow (GCS)',
      'subtitle': 'Neurologie & Traumatologie Crânienne',
      'tags': ['glasgow', 'gcs', 'coma', 'conscience', 'traumatisme cranien', 'intubation', 'vigilance'],
      'snippet': 'Évaluation du niveau de conscience : réponse oculaire, verbale et motrice (Score 3 à 15). Indication IOT si GCS <= 8.',
      'action': 'Calculer le score',
    },
    {
      'id': 'score_wells_pe',
      'title': 'Score de Wells - Embolie Pulmonaire (EP)',
      'subtitle': 'Cardiologie & Pneumologie d\'Urgence',
      'tags': ['wells', 'embolie', 'pulmonaire', 'thrombose', 'd-dimeres', 'angioscanner', 'dyspnee', 'hemoptysie'],
      'snippet': 'Stratification du risque d\'embolie pulmonaire : probabilité faible, intermédiaire ou forte pour guider D-Dimères ou Angioscanner.',
      'action': 'Calculer le score',
    },
    {
      'id': 'score_cockcroft',
      'title': 'Clairance Cockcroft-Gault & DFG',
      'subtitle': 'Néphrologie & Pharmacologie',
      'tags': ['cockcroft', 'clairance', 'creatinine', 'rein', 'insuffisance renale', 'dfg', 'filtration'],
      'snippet': 'Estimation de la fonction rénale et de la clairance de la créatinine pour l\'adaptation des posologies médicamenteuses.',
      'action': 'Calculer la clairance',
    },
    {
      'id': 'score_curb65',
      'title': 'Score CURB-65 - Gravité Pneumonie (PAC)',
      'subtitle': 'Pneumologie & Infectiologie',
      'tags': ['curb', 'curb65', 'pneumonie', 'pac', 'confusion', 'uree', 'frequence respiratoire', 'hospitalisation', 'reanimation'],
      'snippet': 'Score pronostique des pneumonies aiguës communautaires pour guider le lieu de prise en charge (ambulatoire vs hospit vs réa).',
      'action': 'Calculer le score',
    },
    {
      'id': 'score_qsofa',
      'title': 'Score qSOFA - Dépistage Rapide du Sepsis',
      'subtitle': 'Réanimation & Urgences Médicales',
      'tags': ['qsofa', 'sofa', 'sepsis', 'choc septique', 'frequence respiratoire', 'pas', 'glasgow', 'lactates'],
      'snippet': 'Dépistage précoce au lit du malade : FR >= 22, altération conscience, PAS <= 100 mmHg. Risque de mortalité élevé si score >= 2.',
      'action': 'Calculer le score',
    },
    {
      'id': 'score_cha2ds2_vasc',
      'title': 'Score CHA2DS2-VASc - Fibrillation Atriale',
      'subtitle': 'Cardiologie & Rythmologie',
      'tags': ['cha2ds2', 'vasc', 'chads', 'fa', 'fibrillation atriale', 'avc', 'anticoagulant', 'aod', 'avk'],
      'snippet': 'Évaluation du risque thromboembolique dans la FA non valvulaire pour indication de l\'anticoagulation curative.',
      'action': 'Calculer le score',
    },
    {
      'id': 'score_apgar',
      'title': 'Score d\'Apgar Néonatal (1, 5, 10 min)',
      'subtitle': 'Pédiatrie & Maternité',
      'tags': ['apgar', 'nouveau-ne', 'naissance', 'reanimation neonatale', 'teint', 'pouls', 'respiration', 'tonus'],
      'snippet': 'Évaluation immédiate de l\'adaptation extra-utérine du nouveau-né : cœur, respiration, tonus, réactivité, coloration.',
      'action': 'Calculer le score',
    },
  ];

  /// Official Guide Chapters for instant discovery search
  final List<Map<String, dynamic>> _userGuidePages = [
    {
      'page': 1,
      'title': 'Guide Medsina - Chapitre 1 : Vision & Présentation Générale',
      'subtitle': 'Documentation Officielle • Page 1',
      'tags': ['guide', 'presentation', 'vision', 'aide', 'manuel', 'documentation', 'hors ligne', 'offline'],
      'snippet': 'Medsina est la plateforme médicale numérique tout-en-un conçue pour la préparation au Concours de Résidanat et la pratique clinique.',
    },
    {
      'page': 2,
      'title': 'Guide Medsina - Chapitre 2 : Préparation Concours & QCMs',
      'subtitle': 'Documentation Officielle • Page 2',
      'tags': ['concours', 'residanat', 'qcms', 'annales', 'blida', 'alger', 'constantine', 'revision', 'sessions'],
      'snippet': 'Catalogue des 47 modules officiels, 6 240+ QCMs avec corrections détaillées, sessions personnalisées et suivi de progression.',
    },
    {
      'page': 3,
      'title': 'Guide Medsina - Chapitre 3 : Pratique Clinique & Urgences (CAT)',
      'subtitle': 'Documentation Officielle • Page 3',
      'tags': ['cat', 'urgences', 'clinique', 'protocoles', 'gardes', 'mementos', 'red flags', 'posologies'],
      'snippet': 'Fiches de conduites à tenir synthétiques, drapeaux rouges, algorithmes décisionnels étape par étape et pharmacopée d\'urgence.',
    },
    {
      'page': 4,
      'title': 'Guide Medsina - Chapitre 4 : IA Médicale & Outils Pratiques',
      'subtitle': 'Documentation Officielle • Page 4',
      'tags': ['ia', 'intelligence artificielle', 'assistant', 'analyseur', 'ordonnance', 'scores', 'normes bio'],
      'snippet': 'Assistant IA spécialisé pour éclaircissements physiopathologiques, analyse d\'ordonnances et interprétation des bilans biologiques.',
    },
    {
      'page': 5,
      'title': 'Guide Medsina - Chapitre 5 : Formules, Tarifs & Abonnements',
      'subtitle': 'Documentation Officielle • Page 5',
      'tags': ['tarifs', 'prix', 'abonnements', 'plans', 'resident elite', 'clinique pro', 'all-access', 'baridimob', 'gratuit'],
      'snippet': 'Grille complète des formules : Pass Découverte (14J gratuits), Résident Élite, Clinique Pro, All-Access VIP et parrainage.',
    },
    {
      'page': 6,
      'title': 'Guide Medsina - Chapitre 6 : Multiplateforme & Synchronisation',
      'subtitle': 'Documentation Officielle • Page 6',
      'tags': ['multiplateforme', 'android', 'windows', 'web', 'synchronisation', 'cloud', 'support', 'mise a jour'],
      'snippet': 'Disponibilité multi-écrans sur Android (APK), Windows 64-bit et Web avec synchronisation Supabase temps réel et révision offline.',
    },
  ];

  /// Pre-warms in-memory collections for zero-lag searches
  Future<void> prewarm() async {
    if (_isPrewarmed) return;

    try {
      final futures = await Future.wait([
        ResidencyRepository.loadModulesAsync(),
        CourseSummaryRepository.loadAllSummariesAsync(),
        PracticalToolsRepository.getOnCallMementosAsync(),
        PracticalToolsRepository.getLabValuesAsync(),
        ClinicalRepository.fetchEmergencyDrugs(),
      ]);

      _modules = futures[0] as List<MedicalModuleModel>;
      _summaries = futures[1] as Map<String, CourseSummaryModel>;
      _mementos = futures[2] as List<OnCallMemento>;
      _labs = futures[3] as List<LabValue>;
      _drugs = futures[4] as List<EmergencyDrugModel>;
      _protocols = ClinicalRepository.getInitialProtocols();

      _isPrewarmed = true;
    } catch (e) {
      debugPrint('Omnisearch prewarm notice: $e');
      _modules = ResidencyRepository.getModules();
      _protocols = ClinicalRepository.getInitialProtocols();
      _mementos = PracticalToolsRepository.getOnCallMementos();
      _labs = PracticalToolsRepository.getLabValues();
    }
  }

  /// String normalizer removing accents, hyphens and lowercasing
  static String normalize(String s) {
    if (s.isEmpty) return '';
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[àáâãäå]'), 'a')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[òóôõö]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll(RegExp(r'[ýÿ]'), 'y')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll('œ', 'oe')
        .replaceAll('æ', 'ae')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Extracts a context snippet around the matched term
  static String extractSnippet(String source, String queryTerm, {int radius = 45}) {
    if (source.isEmpty || queryTerm.isEmpty) return '';
    final normSource = normalize(source);
    final normQuery = normalize(queryTerm);

    final idx = normSource.indexOf(normQuery);
    if (idx == -1) {
      return source.length > 90 ? '${source.substring(0, 90)}...' : source;
    }

    final start = (idx - radius).clamp(0, source.length);
    final end = (idx + queryTerm.length + radius).clamp(0, source.length);

    String prefix = start > 0 ? '...' : '';
    String suffix = end < source.length ? '...' : '';

    return '$prefix${source.substring(start, end).replaceAll('\n', ' ').trim()}$suffix';
  }

  /// Master search execution across all domains
  Future<List<SearchResultItem>> search(
    String rawQuery, {
    SearchResultType? filterType,
    int limit = 60,
  }) async {
    final query = rawQuery.trim();
    if (query.length < 2) return [];

    await prewarm();

    final normQuery = normalize(query);
    final queryTokens = normQuery.split(' ').where((t) => t.isNotEmpty).toList();
    if (queryTokens.isEmpty) return [];

    final results = <SearchResultItem>[];

    // -------------------------------------------------------------------------
    // 1. COURSES & MODULES (modules_catalog_47)
    // -------------------------------------------------------------------------
    if (filterType == null || filterType == SearchResultType.course) {
      for (final module in _modules) {
        final normModName = normalize(module.name);
        for (final course in module.courses) {
          final normCourseName = normalize(course.name);

          int score = 0;
          if (normCourseName == normQuery) {
            score += 150;
          } else if (normCourseName.startsWith(normQuery)) {
            score += 90;
          } else if (normCourseName.contains(normQuery)) {
            score += 70;
          } else {
            bool allTokens = true;
            for (final token in queryTokens) {
              if (!normCourseName.contains(token) && !normModName.contains(token)) {
                allTokens = false;
                break;
              }
            }
            if (allTokens) score += 50;
          }

          if (score > 0) {
            results.add(SearchResultItem(
              id: course.id,
              title: course.name,
              subtitle: 'Module ${module.name} • ${course.questionsCount} QCMs',
              snippet: 'Cours officiel du programme de résidanat avec support PDF complet.',
              type: SearchResultType.course,
              relevanceScore: score,
              tags: [module.name, 'cours', 'pdf'],
              payload: {'course': course, 'module': module},
            ));
          }
        }
      }
    }

    // -------------------------------------------------------------------------
    // 2. COURSE SUMMARIES & EXAM TRAPS (course_summaries.json)
    // -------------------------------------------------------------------------
    if (filterType == null || filterType == SearchResultType.courseSummary || filterType == SearchResultType.course) {
      _summaries.forEach((courseId, summary) {
        final normName = normalize(summary.courseName);
        final normTraps = normalize(summary.examTraps.join(' '));
        final normPoints = normalize(summary.keyTakeaways.join(' '));
        final normDiag = normalize(summary.diagnosticCriteria ?? '');
        final normTreatment = normalize(summary.treatmentSummary ?? '');

        int score = 0;
        String matchSnippet = '';

        if (normName.contains(normQuery)) {
          score += 85;
          matchSnippet = summary.keyTakeaways.isNotEmpty ? summary.keyTakeaways.first : summary.summaryMarkdown;
        } else if (normTraps.contains(normQuery)) {
          score += 75;
          matchSnippet = '⚠️ Piège Concours : ${extractSnippet(summary.examTraps.join(' • '), query)}';
        } else if (normPoints.contains(normQuery)) {
          score += 65;
          matchSnippet = 'Point Clé : ${extractSnippet(summary.keyTakeaways.join(' • '), query)}';
        } else if (normDiag.isNotEmpty && normDiag.contains(normQuery)) {
          score += 60;
          matchSnippet = 'Critères Diagnostiques : ${extractSnippet(summary.diagnosticCriteria ?? '', query)}';
        } else if (normTreatment.isNotEmpty && normTreatment.contains(normQuery)) {
          score += 55;
          matchSnippet = 'Traitement : ${extractSnippet(summary.treatmentSummary ?? '', query)}';
        } else if (normalize(summary.summaryMarkdown).contains(normQuery)) {
          score += 45;
          matchSnippet = extractSnippet(summary.summaryMarkdown, query);
        }

        if (score > 0) {
          results.add(SearchResultItem(
            id: 'summary_${summary.courseId}',
            title: 'Synthèse : ${summary.courseName}',
            subtitle: 'Module ${summary.moduleName} • Fiche de révision',
            snippet: matchSnippet.isNotEmpty ? matchSnippet : summary.summaryMarkdown,
            type: SearchResultType.courseSummary,
            relevanceScore: score,
            tags: [summary.moduleName, 'fiche', 'résumé', 'pièges'],
            payload: summary,
          ));
        }
      });
    }

    // -------------------------------------------------------------------------
    // 3. CONDUITES À TENIR & PROTOCOLES D'URGENCES (CAT)
    // -------------------------------------------------------------------------
    if (filterType == null || filterType == SearchResultType.catProtocol) {
      for (final protocol in _protocols) {
        final normTitle = normalize(protocol.title);
        final normDef = normalize(protocol.definition);
        final normRedFlags = normalize(protocol.redFlags.join(' '));
        final normTreatments = normalize(protocol.treatments.join(' '));
        final normSteps = normalize(protocol.steps.map((s) => '${s.title} ${s.content} ${s.bulletPoints.join(' ')}').join(' '));

        int score = 0;
        String snippet = '';

        if (normTitle == normQuery) {
          score += 160;
          snippet = protocol.definition;
        } else if (normTitle.contains(normQuery)) {
          score += 95;
          snippet = protocol.definition;
        } else if (normRedFlags.contains(normQuery)) {
          score += 80;
          snippet = '🚨 Drapeau Rouge : ${extractSnippet(protocol.redFlags.join(' • '), query)}';
        } else if (normTreatments.contains(normQuery)) {
          score += 70;
          snippet = '💊 Traitement d\'urgence : ${extractSnippet(protocol.treatments.join(' • '), query)}';
        } else if (normSteps.contains(normQuery)) {
          score += 60;
          snippet = 'Étape de prise en charge : ${extractSnippet(protocol.steps.map((s) => s.content).join(' '), query)}';
        } else if (normDef.contains(normQuery)) {
          score += 50;
          snippet = extractSnippet(protocol.definition, query);
        }

        if (score > 0) {
          results.add(SearchResultItem(
            id: protocol.id,
            title: protocol.title,
            subtitle: '${protocol.urgencyLevel} • ${protocol.specialty}',
            snippet: snippet.isNotEmpty ? snippet : protocol.definition,
            type: SearchResultType.catProtocol,
            relevanceScore: score,
            tags: [protocol.specialty, protocol.urgencyLevel, 'urgence', 'cat'],
            payload: protocol,
          ));
        }
      }
    }

    // -------------------------------------------------------------------------
    // 4. MÉMENTOS DE GARDE HOSPITALIÈRE (on_call_mementos.json)
    // -------------------------------------------------------------------------
    if (filterType == null || filterType == SearchResultType.memento) {
      for (final memento in _mementos) {
        final normTitle = normalize(memento.title);
        final normCat = normalize(memento.category);
        final normPoints = normalize(memento.points.join(' '));

        int score = 0;
        String snippet = '';

        if (normTitle.contains(normQuery)) {
          score += 90;
          snippet = memento.points.isNotEmpty ? memento.points.first : memento.category;
        } else if (normPoints.contains(normQuery)) {
          score += 65;
          snippet = 'Pratique Garde : ${extractSnippet(memento.points.join(' • '), query)}';
        } else if (normCat.contains(normQuery)) {
          score += 45;
          snippet = memento.points.isNotEmpty ? memento.points.first : '';
        }

        if (score > 0) {
          results.add(SearchResultItem(
            id: memento.id,
            title: memento.title,
            subtitle: 'Mémento de Garde • ${memento.category}',
            snippet: snippet.isNotEmpty ? snippet : 'Fiche réflexe et checklist pratique hospitalière.',
            type: SearchResultType.memento,
            relevanceScore: score,
            tags: [memento.category, 'garde', 'astreinte', 'checklist'],
            payload: memento,
          ));
        }
      }
    }

    // -------------------------------------------------------------------------
    // 5. MÉDICAMENTS D'URGENCE (emergency_drugs_algeria.json)
    // -------------------------------------------------------------------------
    if (filterType == null || filterType == SearchResultType.emergencyDrug) {
      for (final drug in _drugs) {
        final normDci = normalize(drug.dci);
        final normBrand = normalize(drug.brand);
        final normInd = normalize(drug.indication);
        final normDose = normalize(drug.dose);

        int score = 0;
        String snippet = '';

        if (normDci.contains(normQuery) || normBrand.contains(normQuery)) {
          score += 95;
          snippet = '${drug.dose} • Indication : ${drug.indication}';
        } else if (normInd.contains(normQuery)) {
          score += 70;
          snippet = 'Indication : ${drug.indication} (Dose : ${drug.dose})';
        } else if (normDose.contains(normQuery)) {
          score += 50;
          snippet = drug.dose;
        }

        if (score > 0) {
          results.add(SearchResultItem(
            id: drug.id,
            title: '${drug.dci} (${drug.brand})',
            subtitle: 'Médicament Urgence • ${drug.category}',
            snippet: snippet.isNotEmpty ? snippet : '${drug.dose} • ${drug.indication}',
            type: SearchResultType.emergencyDrug,
            relevanceScore: score,
            tags: [drug.category, 'médicament', 'dci', 'posologie'],
            payload: drug,
          ));
        }
      }
    }

    // -------------------------------------------------------------------------
    // 6. NORMES BIOLOGIQUES & LABORATOIRE (lab_reference_values.json)
    // -------------------------------------------------------------------------
    if (filterType == null || filterType == SearchResultType.labValue) {
      for (final lab in _labs) {
        final normName = normalize(lab.name);
        final normHigh = normalize(lab.highInterpretation);
        final normLow = normalize(lab.lowInterpretation);
        final normNotes = normalize(lab.clinicalNotes.join(' '));

        int score = 0;
        String snippet = '';

        if (normName.contains(normQuery)) {
          score += 90;
          snippet = 'Norme : ${lab.normalRange} ${lab.unit} • Élevé : ${lab.highInterpretation}';
        } else if (normHigh.contains(normQuery)) {
          score += 65;
          snippet = 'Si Élevé : ${extractSnippet(lab.highInterpretation, query)}';
        } else if (normLow.contains(normQuery)) {
          score += 65;
          snippet = 'Si Bas : ${extractSnippet(lab.lowInterpretation, query)}';
        } else if (normNotes.contains(normQuery)) {
          score += 50;
          snippet = 'Note bio : ${extractSnippet(lab.clinicalNotes.join(' • '), query)}';
        }

        if (score > 0) {
          results.add(SearchResultItem(
            id: lab.id,
            title: lab.name,
            subtitle: 'Norme Bio • ${lab.category} (${lab.normalRange} ${lab.unit})',
            snippet: snippet.isNotEmpty ? snippet : 'Valeurs de référence et interprétations diagnostiques.',
            type: SearchResultType.labValue,
            relevanceScore: score,
            tags: [lab.category, 'laboratoire', 'biologie', 'norme'],
            payload: lab,
          ));
        }
      }
    }

    // -------------------------------------------------------------------------
    // 7. SCORES & CALCULATEURS CLINIQUES
    // -------------------------------------------------------------------------
    if (filterType == null || filterType == SearchResultType.clinicalScore) {
      for (final item in _clinicalScores) {
        final normTitle = normalize(item['title'] as String);
        final tags = (item['tags'] as List<String>).map(normalize).toList();
        final normSnippet = normalize(item['snippet'] as String);

        int score = 0;
        if (normTitle.contains(normQuery)) {
          score += 110;
        } else if (tags.any((t) => t.contains(normQuery))) {
          score += 80;
        } else if (normSnippet.contains(normQuery)) {
          score += 55;
        }

        if (score > 0) {
          results.add(SearchResultItem(
            id: item['id'] as String,
            title: item['title'] as String,
            subtitle: item['subtitle'] as String,
            snippet: item['snippet'] as String,
            type: SearchResultType.clinicalScore,
            relevanceScore: score,
            tags: (item['tags'] as List<String>),
            payload: item,
          ));
        }
      }
    }

    // -------------------------------------------------------------------------
    // 8. GUIDE OFFICIEL MEDSINA (PDF 6 PAGES)
    // -------------------------------------------------------------------------
    if (filterType == null || filterType == SearchResultType.userGuide) {
      for (final page in _userGuidePages) {
        final normTitle = normalize(page['title'] as String);
        final tags = (page['tags'] as List<String>).map(normalize).toList();
        final normSnippet = normalize(page['snippet'] as String);

        int score = 0;
        if (normTitle.contains(normQuery)) {
          score += 80;
        } else if (tags.any((t) => t.contains(normQuery))) {
          score += 65;
        } else if (normSnippet.contains(normQuery)) {
          score += 45;
        }

        if (score > 0) {
          results.add(SearchResultItem(
            id: 'guide_page_${page['page']}',
            title: page['title'] as String,
            subtitle: page['subtitle'] as String,
            snippet: page['snippet'] as String,
            type: SearchResultType.userGuide,
            relevanceScore: score,
            tags: (page['tags'] as List<String>),
            payload: page,
          ));
        }
      }
    }

    // -------------------------------------------------------------------------
    // 9. QCMs ANNALES
    // -------------------------------------------------------------------------
    if (filterType == null || filterType == SearchResultType.qcm) {
      final qcmResults = await _searchQcmsAsync(normQuery, queryTokens);
      results.addAll(qcmResults);
    }

    // Sort descending by relevanceScore
    results.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));

    if (results.length > limit) {
      return results.sublist(0, limit);
    }
    return results;
  }

  /// Searches QCMs dynamically in relevant modules
  Future<List<SearchResultItem>> _searchQcmsAsync(String normQuery, List<String> tokens) async {
    final list = <SearchResultItem>[];

    final candidateModuleIds = <String>{};
    for (final mod in _modules) {
      final normMod = normalize(mod.name);
      if (tokens.any((t) => normMod.contains(t))) {
        candidateModuleIds.add(mod.id);
      }
      for (final c in mod.courses) {
        if (tokens.any((t) => normalize(c.name).contains(t))) {
          candidateModuleIds.add(mod.id);
          break;
        }
      }
    }

    for (final modId in candidateModuleIds.take(3)) {
      try {
        final safeModId = modId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
        final path = 'assets/data/qcms/$safeModId.json';
        final jsonStr = await rootBundle.loadString(path);
        final rawList = jsonDecode(jsonStr) as List<dynamic>;

        int countFound = 0;
        for (final item in rawList) {
          if (item is! Map<String, dynamic>) continue;
          final question = QcmQuestion.fromJson(item);
          final normQ = normalize(question.questionText);
          final normExpl = normalize(question.explanation);

          int score = 0;
          String matchSnippet = '';

          if (normQ.contains(normQuery)) {
            score = 75;
            matchSnippet = extractSnippet(question.questionText, normQuery);
          } else if (normExpl.contains(normQuery)) {
            score = 60;
            matchSnippet = 'Correction : ${extractSnippet(question.explanation, normQuery)}';
          } else if (tokens.length > 1 && tokens.every((t) => normQ.contains(t) || normExpl.contains(t))) {
            score = 50;
            matchSnippet = extractSnippet(question.questionText, tokens.first);
          }

          if (score > 0) {
            countFound++;
            list.add(SearchResultItem(
              id: question.id,
              title: question.questionText,
              subtitle: 'QCM ${question.courseName} • ${question.source} ${question.year}'.trim(),
              snippet: matchSnippet.isNotEmpty ? matchSnippet : question.explanation,
              type: SearchResultType.qcm,
              relevanceScore: score,
              tags: [question.courseName, 'qcm', 'annales'],
              payload: question,
            ));
            if (countFound >= 10) break;
          }
        }
      } catch (_) {}
    }

    return list;
  }

  // ---------------------------------------------------------------------------
  // Recent Searches Storage
  // ---------------------------------------------------------------------------
  Future<List<String>> getRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_recentSearchesKey) ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<void> saveRecentSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      var list = prefs.getStringList(_recentSearchesKey) ?? [];
      list.removeWhere((item) => item.toLowerCase() == trimmed.toLowerCase());
      list.insert(0, trimmed);
      if (list.length > 8) {
        list = list.sublist(0, 8);
      }
      await prefs.setStringList(_recentSearchesKey, list);
    } catch (_) {}
  }

  Future<void> clearRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentSearchesKey);
    } catch (_) {}
  }
}
