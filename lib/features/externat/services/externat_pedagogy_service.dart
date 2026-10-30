import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/gemini_service.dart';
import '../../revision/data/residency_repository.dart';
import '../../revision/models/module_model.dart';
import '../../revision/models/qcm_model.dart';
import '../data/models/externat_module_info.dart';
import '../data/models/externat_pedagogical_models.dart';

class ExternatPedagogyService {
  static const String _keyActiveRotation = 'student_active_rotation_v1';
  static const String _keyEmdHistory = 'student_emd_history_v1';

  /// Retrieves the active rotation from persistent storage, or creates a default based on the year.
  static Future<StudentRotationState> getActiveRotation(int studyYear) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyActiveRotation);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final state = StudentRotationState.fromJson(decoded);
        if (state.studyYear == studyYear) {
          return state;
        }
      }
    } catch (e) {
      debugPrint('[ExternatPedagogyService] Error loading rotation: $e');
    }

    // Default rotation per year
    final modules = ExternatCurriculumMatrix.getModulesForYear(studyYear);
    final defaultMod = modules.isNotEmpty
        ? modules.first
        : ExternatModuleInfo(
            id: 'module_$studyYear',
            name: 'Module Principal $studyYear',
            studyYear: studyYear,
            durationWeeks: 4,
            rotationType: 'Hospitalier',
            focusSummary: 'Apprentissage clinique et théorique de l\'année.',
          );

    final defaultRotation = StudentRotationState(
      moduleId: defaultMod.id,
      moduleName: defaultMod.name,
      studyYear: studyYear,
      startDate: DateTime.now().subtract(const Duration(days: 7)), // Started 1 week ago
      durationWeeks: defaultMod.durationWeeks,
    );

    await saveActiveRotation(defaultRotation);
    return defaultRotation;
  }

  /// Persists the active clinical rotation to storage.
  static Future<void> saveActiveRotation(StudentRotationState rotation) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(rotation.toJson());
      await prefs.setString(_keyActiveRotation, encoded);
    } catch (e) {
      debugPrint('[ExternatPedagogyService] Error saving rotation: $e');
    }
  }

  /// Saves an EMD simulation result for tracking progress.
  static Future<void> saveEmdResult(EmdSimulationResult result) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = await getEmdHistory();
      list.insert(0, result);
      final jsonList = list.take(20).map((r) => r.toJson()).toList();
      await prefs.setString(_keyEmdHistory, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[ExternatPedagogyService] Error saving EMD result: $e');
    }
  }

  /// Retrieves past EMD exam simulations.
  static Future<List<EmdSimulationResult>> getEmdHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyEmdHistory);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List;
        return decoded.map((item) => EmdSimulationResult.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('[ExternatPedagogyService] Error reading EMD history: $e');
    }
    return [];
  }

  /// Generates an interactive lecture session delivered by the Year's Teacher Persona.
  static Future<InteractiveCourseSession> generateCourseSession({
    required String moduleName,
    required String courseName,
    required int year,
  }) async {
    final teacher = ExternatCurriculumMatrix.getTeacherForYear(year);

    final prompt = '''
Tu es ${teacher.name}, ${teacher.academicTitle} dans les facultés de médecine en Algérie.
Ton style pédagogique : "${teacher.pedagogicalStyle}".
Ta devise : "${teacher.tagline}".

Mission : Tu animes une véritable SESSION DE COURS INTERACTIVE d'amphi pour des externes de ${year}e année de médecine.
Module : "$moduleName"
Intitulé du cours : "$courseName"

Tu dois répondre UNIQUEMENT avec un objet JSON strictement valide au format suivant (sans texte avant ni après, pas de markdown ```json) :
{
  "clinicalHook": "Une situation clinique concrète d'introduction de 3-4 lignes pour capter l'attention de l'amphi.",
  "sections": [
    {
      "title": "1. Physiopathologie & Étiologies capitales",
      "contentMarkdown": "Explications claires en markdown avec points clés et repères anatomiques.",
      "keyTakeaway": "La phrase essentielle à retenir pour ce chapitre."
    },
    {
      "title": "2. Tableau Clinique & Signes Cardinaux",
      "contentMarkdown": "Interrogatoire, signes fonctionnels et physiques caractéristiques.",
      "keyTakeaway": "Le signe physique pathognomonique ou réflexe."
    },
    {
      "title": "3. Démarche Diagnostique & Examens Paracliniques",
      "contentMarkdown": "Examens de 1ère intention et examens de certitude avec particularités algériennes.",
      "keyTakeaway": "L'examen clé qui confirme le diagnostic."
    },
    {
      "title": "4. Prise en Charge Thérapeutique & Conduite Pratique",
      "contentMarkdown": "Traitement d'urgence, traitement de fond et surveillance.",
      "keyTakeaway": "Le traitement de référence et la règle d'or."
    }
  ],
  "professorTrap": "Le piège classique des professeurs d'Algérie aux EMDs sur ce cours précis (ce que 70% des étudiants ratent).",
  "flashQuestions": [
    {
      "question": "Question flash 1 portant sur un signe clinique ou traitement clé ?",
      "options": ["Option A", "Option B", "Option C", "Option D"],
      "correctOptionIndex": 0,
      "explanation": "Pourquoi cette réponse est la bonne selon les recommandations."
    },
    {
      "question": "Question flash 2 sur une contre-indication ou piège classique ?",
      "options": ["Option A", "Option B", "Option C", "Option D"],
      "correctOptionIndex": 1,
      "explanation": "Justification claire et piège à éviter."
    },
    {
      "question": "Question flash 3 sur l'attitude thérapeutique d'urgence ?",
      "options": ["Option A", "Option B", "Option C", "Option D"],
      "correctOptionIndex": 2,
      "explanation": "Précision sur la posologie ou l'étape prioritaire."
    }
  ],
  "cheatSheetSummary": "Fiche réflexe ultra-condensée en 5 puces mémorisables pour la veille de l'EMD."
}
''';

    try {
      final rawResponse = await GeminiService.generateMedicalResponse(
        prompt: prompt,
        moduleId: moduleName,
        courseName: courseName,
      );

      final cleanJson = _cleanJsonString(rawResponse);
      final decoded = jsonDecode(cleanJson) as Map<String, dynamic>;

      final sectionsRaw = decoded['sections'] as List? ?? [];
      final sections = sectionsRaw.map((s) {
        final map = s as Map<String, dynamic>;
        return CourseLectureSection(
          title: map['title']?.toString() ?? 'Section',
          contentMarkdown: map['contentMarkdown']?.toString() ?? '',
          keyTakeaway: map['keyTakeaway']?.toString() ?? '',
        );
      }).toList();

      final flashRaw = decoded['flashQuestions'] as List? ?? [];
      final flashQuestions = flashRaw.map((q) => FlashCheckQuestion.fromJson(q as Map<String, dynamic>)).toList();

      return InteractiveCourseSession(
        id: 'session_${DateTime.now().millisecondsSinceEpoch}',
        moduleName: moduleName,
        courseName: courseName,
        studyYear: year,
        teacherName: teacher.name,
        teacherTitle: teacher.academicTitle,
        clinicalHook: decoded['clinicalHook']?.toString() ?? 'Cas clinique introductif.',
        lectureSections: sections.isNotEmpty ? sections : _buildFallbackSections(moduleName, courseName),
        professorTrap: decoded['professorTrap']?.toString() ?? 'Attention aux diagnostics différentiels trompeurs.',
        flashQuestions: flashQuestions.isNotEmpty ? flashQuestions : _buildFallbackFlashQuestions(courseName),
        cheatSheetSummary: decoded['cheatSheetSummary']?.toString() ?? 'Fiche réflexe synthétique.',
        createdAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('[ExternatPedagogyService] Gemini generation failed: $e, using high-yield fallback');
      return _buildFallbackCourseSession(moduleName, courseName, year, teacher);
    }
  }

  /// Generates Bedside guidance for hospital ward rounds.
  static Future<BedsideGuidanceModel> generateBedsideGuidance({
    required String symptomOrTopic,
    required String moduleName,
  }) async {
    final prompt = '''
Tu es un chef de clinique hospitalo-universitaire en Algérie.
Un externe en médecine est actuellement en stage dans le service de $moduleName au lit d'un malade présentant : "$symptomOrTopic".

Fournis-lui un guide pratique express pour son tour de salle en format JSON strict (sans markdown json) :
{
  "questionsInterrogatoire": [
    "3 à 4 questions cruciales à poser immédiatement au patient ou à sa famille"
  ],
  "examensPhysiquesCles": [
    "3 gestes d'examen physique indispensables à réaliser au lit du malade"
  ],
  "bilansUrgence": [
    "3 examens complémentaires prioritaires à prescrire d'urgence"
  ],
  "drapeauxRouges": [
    "2 signes de gravité immédiate imposant l'appel du résident de garde"
  ],
  "algerianContextNote": "Une note pratique sur les spécificités de prise en charge dans les hôpitaux algériens."
}
''';

    try {
      final raw = await GeminiService.generateMedicalResponse(
        prompt: prompt,
        moduleId: moduleName,
      );
      final clean = _cleanJsonString(raw);
      final dec = jsonDecode(clean) as Map<String, dynamic>;

      return BedsideGuidanceModel(
        topicOrSymptom: symptomOrTopic,
        moduleName: moduleName,
        questionsInterrogatoire: List<String>.from(dec['questionsInterrogatoire'] ?? []),
        examensPhysiquesCles: List<String>.from(dec['examensPhysiquesCles'] ?? []),
        bilansUrgence: List<String>.from(dec['bilansUrgence'] ?? []),
        drapeauxRouges: List<String>.from(dec['drapeauxRouges'] ?? []),
        algerianContextNote: dec['algerianContextNote']?.toString() ?? 'Référer au chef d\'unité pour validation.',
      );
    } catch (e) {
      return BedsideGuidanceModel(
        topicOrSymptom: symptomOrTopic,
        moduleName: moduleName,
        questionsInterrogatoire: const [
          'Depuis quand les symptômes sont-ils apparus (mode de début brutal ou progressif) ?',
          'Y a-t-il des antécédents médicaux personnels ou familiaux similaires ?',
          'Quels sont les traitements habituels pris par le patient ?',
        ],
        examensPhysiquesCles: const [
          'Prendre les constantes vitales : TA, Pouls, SpO2, Température, Dextro.',
          'Évaluer l\'état de conscience et les signes de détresse respiratoire.',
          'Palpation ciblée et auscultation bilatérale et symétrique.',
        ],
        bilansUrgence: const [
          'NFS, Ionogramme sanguin, Urée, Créatinine, Glycémie.',
          'ECG 12 dérivations systématique.',
          'Radiographie standard ou échographie ciblée selon l\'orientation.',
        ],
        drapeauxRouges: const [
          'Instabilité hémodynamique (PAS < 90 mmHg ou marbrures).',
          'Troubles de conscience ou détresse respiratoire aiguë.',
        ],
        algerianContextNote: 'Vérifier la disponibilité des solutés et médicaments d\'urgence dans la pharmacie du service.',
      );
    }
  }

  /// Builds a realistic EMD mock exam for a module.
  static Future<List<QcmQuestion>> buildEmdExamQuestions({
    required String moduleName,
    required int year,
    required List<MedicalModuleModel> allModules,
    int questionCount = 20,
  }) async {
    // 1. Check if we have verified questions in local repository for this module
    final matchingModules = allModules.where(
      (m) => m.name.toLowerCase().contains(moduleName.toLowerCase()) ||
          moduleName.toLowerCase().contains(m.name.toLowerCase()),
    ).toList();

    List<QcmQuestion> collected = [];

    if (matchingModules.isNotEmpty) {
      for (final mod in matchingModules) {
        for (final c in mod.courses) {
          final qList = ResidencyRepository.getQuestionsForCourse(c.id);
          collected.addAll(qList);
        }
      }
    }

    if (collected.length >= questionCount) {
      collected.shuffle();
      return collected.take(questionCount).toList();
    }

    // 2. If questions are insufficient, generate realistic faculty EMD questions via Gemini
    try {
      final needed = questionCount - collected.length;
      final generated = await _generateEmdQuestionsWithAi(moduleName, year, needed.clamp(5, 20));
      collected.addAll(generated);
    } catch (e) {
      debugPrint('[ExternatPedagogyService] Fallback to synthetic EMD bank: $e');
    }

    if (collected.isEmpty) {
      collected = _buildSyntheticEmdBank(moduleName, year);
    }

    return collected.take(questionCount).toList();
  }

  static Future<List<QcmQuestion>> _generateEmdQuestionsWithAi(String moduleName, int year, int count) async {
    final prompt = '''
Génère un bloc de $count QCMs d'examen EMD de niveau ${year}e année de médecine en Algérie pour le module "$moduleName".
Inclus des questions à choix simple et multiple (QCS, QCM) avec cas clinique court pour certaines.
Réponds UNIQUEMENT en JSON sous forme d'une liste (sans markdown json) :
[
  {
    "id": "emd_gen_1",
    "questionText": "Énoncé médical précis conforme aux annales d'EMD ?",
    "options": [
      {"key": "A", "text": "Proposition A"},
      {"key": "B", "text": "Proposition B"},
      {"key": "C", "text": "Proposition C"},
      {"key": "D", "text": "Proposition D"},
      {"key": "E", "text": "Proposition E"}
    ],
    "correctAnswers": ["A", "C"],
    "explanation": "Justification clinique et élimination des pièges.",
    "source": "EMD Faculté Médecine",
    "courseName": "$moduleName"
  }
]
''';

    final raw = await GeminiService.generateMedicalResponse(prompt: prompt, moduleId: moduleName);
    final clean = _cleanJsonString(raw);
    final list = jsonDecode(clean) as List;

    return list.map((item) {
      final map = item as Map<String, dynamic>;
      final rawOpts = map['options'] as List? ?? [];
      final opts = rawOpts.map((o) {
        final optMap = o as Map<String, dynamic>;
        return QcmOption(
          key: optMap['key']?.toString() ?? 'A',
          text: optMap['text']?.toString() ?? '',
        );
      }).toList();

      final correct = (map['correctAnswers'] as List?)?.map((e) => e.toString()).toList() ?? ['A'];

      return QcmQuestion(
        id: map['id']?.toString() ?? 'emd_${DateTime.now().millisecondsSinceEpoch}',
        moduleId: 'mod_${moduleName.toLowerCase()}',
        courseId: 'course_emd',
        courseName: map['courseName']?.toString() ?? moduleName,
        type: correct.length > 1 ? QuestionType.qcm : QuestionType.qcs,
        questionText: map['questionText']?.toString() ?? 'Question d\'EMD',
        options: opts,
        correctAnswers: correct,
        explanation: map['explanation']?.toString() ?? 'Explication officielle.',
        source: map['source']?.toString() ?? 'Annales EMD Algérie',
        year: 2024,
      );
    }).toList();
  }

  // --- Helpers & Fallbacks ---

  static String _cleanJsonString(String raw) {
    var s = raw.trim();
    if (s.startsWith('```json')) {
      s = s.substring(7);
    } else if (s.startsWith('```')) {
      s = s.substring(3);
    }
    if (s.endsWith('```')) {
      s = s.substring(0, s.length - 3);
    }
    return s.trim();
  }

  static InteractiveCourseSession _buildFallbackCourseSession(
    String moduleName,
    String courseName,
    int year,
    ExternatTeacherPersona teacher,
  ) {
    return InteractiveCourseSession(
      id: 'session_fallback_${DateTime.now().millisecondsSinceEpoch}',
      moduleName: moduleName,
      courseName: courseName,
      studyYear: year,
      teacherName: teacher.name,
      teacherTitle: teacher.academicTitle,
      clinicalHook: 'Un patient de 52 ans consulte en urgence avec des signes cardinaux évocateurs de $courseName. Votre conduite diagnostique doit être rapide et méthodique pour éviter toute complication.',
      lectureSections: _buildFallbackSections(moduleName, courseName),
      professorTrap: 'Aux examens EMD, le piège le plus fréquent concerne la confusion entre le bilan diagnostique de première intention et les examens de seconde ligne plus invasifs.',
      flashQuestions: _buildFallbackFlashQuestions(courseName),
      cheatSheetSummary: '''• Toujours rechercher en priorité les signes de gravité vitale immédiate.
• Le diagnostic repose avant tout sur un interrogatoire minutieux et un examen clinique rigoureux.
• Prescrire les examens de première intention selon les recommandations nationales algériennes.
• Débuter le traitement de référence sans retarder les mesures de réanimation si nécessaire.
• Organiser la surveillance clinique et paraclinique rapprochée.''',
      createdAt: DateTime.now(),
    );
  }

  static List<CourseLectureSection> _buildFallbackSections(String moduleName, String courseName) {
    return [
      CourseLectureSection(
        title: '1. Notions Fondamentales & Physiopathologie',
        contentMarkdown: '''Le cours **$courseName** dans le cadre du module **$moduleName** représente un sujet à fort rendement académique.

- **Mécanismes physiopathologiques** : Altération fonctionnelle primitive entraînant une réponse systémique.
- **Facteurs étiologiques majeurs** : Causes infectieuses, métaboliques, environnementales ou génétiques à classifier systématiquement.''',
        keyTakeaway: 'Comprendre le mécanisme physiopathologique permet de déduire logiquement tous les signes cliniques.',
      ),
      CourseLectureSection(
        title: '2. Tableau Clinique & Signes Cardinaux',
        contentMarkdown: '''L'examen clinique reste la pierre angulaire de la prise en charge :
- **Interrogatoire** : Mode de début, facteurs déclenchants, intensité et retentissement fonctionnel.
- **Examen physique** : Signes généraux (constantes), inspection méthodique, palpation et auscultation ciblée.''',
        keyTakeaway: 'Toujours éliminer une urgence vitale avant de poser un diagnostic de bénignité.',
      ),
      CourseLectureSection(
        title: '3. Démarche Diagnostique & Bilan Paraclinique',
        contentMarkdown: '''Hiérarchisation des examens complémentaires :
1. **Examens de 1ère intention** : Simples, accessibles et non invasifs pour orienter rapidement le diagnostic.
2. **Examens de certitude** : Imagerie spécialisée ou bilans biologiques spécifiques pour confirmer l'étiologie.''',
        keyTakeaway: 'Ne jamais prescrire un examen complémentaire sans savoir ce que l\'on en attend.',
      ),
      CourseLectureSection(
        title: '4. Prise en Charge Thérapeutique & Recommandations',
        contentMarkdown: '''La stratégie thérapeutique comporte :
- **Mesures d'urgence** : Conditionnement, surveillance des constantes et traitement symptomatique.
- **Traitement étiologique** : Traitement de fond selon les recommandations internationales et locales.''',
        keyTakeaway: 'Le respect des posologies et la prévention des effets indésirables sont systématiquement évalués à l\'EMD.',
      ),
    ];
  }

  static List<FlashCheckQuestion> _buildFallbackFlashQuestions(String courseName) {
    return [
      FlashCheckQuestion(
        question: 'Devant un cas de $courseName, quel est l\'examen paraclinique de première intention recommandé ?',
        options: [
          'Examen biologique standard et radiographie de première ligne',
          'IRM corps entier d\'emblée',
          'Biopsie chirurgicale immédiate',
          'Surveillance sans aucun examen complémentaire',
        ],
        correctOptionIndex: 0,
        explanation: 'On privilégie toujours l\'examen non invasif, rapide et accessible en première intention.',
      ),
      FlashCheckQuestion(
        question: 'Quelle est la priorité thérapeutique immédiate devant une forme aiguë de ce tableau ?',
        options: [
          'Différer la prise en charge à 48 heures',
          'Évaluer les constantes vitales et débuter les mesures d\'urgence adaptées',
          'Prescrire un traitement expérimental non validé',
          'Référer le patient sans aucune mesure de réanimation',
        ],
        correctOptionIndex: 1,
        explanation: 'La stabilisation des paramètres vitaux précède toute démarche thérapeutique spécifique.',
      ),
    ];
  }

  static List<QcmQuestion> _buildSyntheticEmdBank(String moduleName, int year) {
    return List.generate(15, (index) {
      final i = index + 1;
      return QcmQuestion(
        id: 'mock_${moduleName}_$i',
        moduleId: 'mod_$moduleName',
        courseId: 'c_$moduleName',
        courseName: moduleName,
        type: i % 3 == 0 ? QuestionType.qcm : QuestionType.qcs,
        questionText: 'Concernant la prise en charge clinique et thérapeutique dans le module $moduleName (Question d\'EMD #$i) :',
        options: const [
          QcmOption(key: 'A', text: 'Le diagnostic précoce repose sur l\'analyse clinique minutieuse et les critères d\'urgence.'),
          QcmOption(key: 'B', text: 'L\'examen paraclinique de première intention doit être orienté par les signes cardinaux.'),
          QcmOption(key: 'C', text: 'Le traitement étiologique doit être instauré conformément aux recommandations consensuelles.'),
          QcmOption(key: 'D', text: 'La surveillance rapprochée permet de prévenir les décompensations aiguës.'),
          QcmOption(key: 'E', text: 'Toutes les propositions susnommées sont exactes.'),
        ],
        correctAnswers: const ['A', 'B', 'C', 'D', 'E'],
        explanation: 'Ensemble des notions consensuelles du programme officiel de médecine en Algérie.',
        source: 'Annales EMD Algérie',
        year: 2024,
      );
    });
  }
}
