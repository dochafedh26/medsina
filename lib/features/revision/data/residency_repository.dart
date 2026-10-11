import 'dart:convert';
import 'package:flutter/services.dart';
import '../../../core/network/supabase_service.dart';
import '../models/module_model.dart';
import '../models/qcm_model.dart';

class ResidencyRepository {
  static List<MedicalModuleModel> _cachedModules = [];

  /// Loads all 47 official modules, either live from Supabase or from local JSON assets
  static Future<List<MedicalModuleModel>> loadModulesAsync() async {
    if (_cachedModules.isNotEmpty) return _cachedModules;

    // 1. Try fetching live from Supabase
    try {
      final supaData = await SupabaseService.fetchModules();
      if (supaData.isNotEmpty) {
        _cachedModules = supaData.map((m) => MedicalModuleModel.fromJson(m)).toList();
        return _cachedModules;
      }
    } catch (_) {}

    // 2. Fallback to bundled local JSON asset (all 47 modules & 1,205 courses)
    try {
      final jsonStr = await rootBundle.loadString('assets/data/modules_catalog_47.json');
      final list = jsonDecode(jsonStr) as List<dynamic>;
      _cachedModules = list.map((m) => MedicalModuleModel.fromJson(m as Map<String, dynamic>)).toList();
      return _cachedModules;
    } catch (_) {}

    return _fallbackMockModules();
  }

  /// Synchronous getter with instant fallback
  static List<MedicalModuleModel> getModules() {
    if (_cachedModules.isNotEmpty) return _cachedModules;
    return _fallbackMockModules();
  }

  static List<MedicalModuleModel> _fallbackMockModules() {
    return [
      const MedicalModuleModel(
        id: 'Blida_CARDIOLOGIE',
        name: 'Cardiologie',
        category: 'Clinique & Concours Résidanat',
        totalQuestions: 1677,
        totalCourses: 38,
        iconName: 'favorite',
        courses: [
          CourseModel(
            id: 'c_cardio_hta',
            moduleId: 'Blida_CARDIOLOGIE',
            name: 'Hypertension Artérielle de l\'Adulte (HTA)',
            questionsCount: 340,
            hasPdf: true,
            completedQuestions: 24,
          ),
          CourseModel(
            id: 'c_cardio_sca',
            moduleId: 'Blida_CARDIOLOGIE',
            name: 'Syndromes Coronariens Aigus (SCA ST+ / ST-)',
            questionsCount: 412,
            hasPdf: true,
            completedQuestions: 50,
          ),
        ],
      ),
    ];
  }

  static List<QcmQuestion> getQuestionsForCourse(String courseId) {
    return [
      const QcmQuestion(
        id: 'q_001',
        moduleId: 'Blida_CARDIOLOGIE',
        courseId: 'c_cardio_hta',
        courseName: 'Hypertension Artérielle de l\'Adulte',
        type: QuestionType.qcm,
        questionText: 'Parmi les propositions suivantes concernant l\'hypertension artérielle essentielle chez l\'adulte, lesquelles sont EXACTES ?',
        options: [
          QcmOption(key: 'A', text: 'Le diagnostic d\'HTA permanente repose sur des mesures répétées au cabinet >= 140/90 mmHg lors de plusieurs consultations.'),
          QcmOption(key: 'B', text: 'L\'automesure tensionnelle (AMT) utilise la règle des 3 : 3 mesures le matin, 3 mesures le soir pendant 3 jours consécutifs.'),
          QcmOption(key: 'C', text: 'Le seuil diagnostique d\'HTA en automesure tensionnelle à domicile est >= 140/90 mmHg.'),
          QcmOption(key: 'D', text: 'La baisse de la pression artérielle réduit significativement le risque d\'accident vasculaire cérébral et d\'insuffisance cardiaque.'),
          QcmOption(key: 'E', text: 'Une bithiothérapie synergique d\'emblée est recommandée pour la majorité des patients en première intention.'),
        ],
        correctAnswers: ['A', 'B', 'D', 'E'],
        explanation: 'Justification clinique :\n'
            '• A : VRAI. Au cabinet médical, le seuil d\'HTA est défini par PAS >= 140 mmHg et/ou PAD >= 90 mmHg confirmée sur au moins 2 consultations.\n'
            '• B : VRAI. La règle des 3 de l\'automesure est standardisée (3 mesures matin à jeun + 3 mesures soir avant coucher pendant 3 jours).\n'
            '• C : FAUX ! Le seuil en automesure à domicile est plus bas qu\'au cabinet : il est de >= 135/85 mmHg (et 130/80 mmHg en MAPA des 24h).\n'
            '• D : VRAI. C\'est l\'objectif principal du traitement pour prévenir les événements cardiovasculaires majeurs.\n'
            '• E : VRAI. Selon les dernières recommandations (ESH 2023), une bithérapie fixe (ex: IEC/ARA2 + Inhibiteur calcique ou Diurétique thiazidique) est préconisée d\'emblée, sauf sujet très âgé ou HTA grade 1 à faible risque.',
        source: 'Résidanat Blida 2024',
        year: 2024,
      ),
      const QcmQuestion(
        id: 'q_002',
        moduleId: 'Blida_CARDIOLOGIE',
        courseId: 'c_cardio_hta',
        courseName: 'Hypertension Artérielle de l\'Adulte',
        type: QuestionType.qcs,
        questionText: 'Quel est le bilan minimal recommandé (OMS/HAS) chez tout hypertendu lors du diagnostic initial ?',
        options: [
          QcmOption(key: 'A', text: 'Coronarographie et scanner cérébral'),
          QcmOption(key: 'B', text: 'Iono sanguin, créatininémie, DFG, glycémie à jeun, bilan lipidique, bandelette urinaire et ECG de repos'),
          QcmOption(key: 'C', text: 'Échocardiographie transthoracique et scintigraphie rénale'),
          QcmOption(key: 'D', text: 'Dosage de l\'aldostérone et de la rénine plasmatique d\'emblée'),
          QcmOption(key: 'E', text: 'IRM cérébrale et fond d\'œil systématique chez tous les patients'),
        ],
        correctAnswers: ['B'],
        explanation: 'Justification clinique :\n'
            'Le bilan initial systématique (recherche de retentissement et de facteurs de risque associés) comprend :\n'
            '1. Créatinine sanguine et estimation du DFG\n'
            '2. Ionogramme sanguin (kaliémie)\n'
            '3. Glycémie à jeun\n'
            '4. Bilan lipidique (EAL)\n'
            '5. Recherche de protéinurie/hématurie à la bandelette urinaire\n'
            '6. ECG de repos 12 dérivations (recherche d\'HVG ou ischémie).\n'
            'Les bilans secondaires (Echo, dosages hormonaux) ne sont demandés qu\'en cas d\'anomalie ou de suspicion d\'HTA secondaire.',
        source: 'Concours Blanc National 2025',
        year: 2025,
      ),
      const QcmQuestion(
        id: 'q_003',
        moduleId: 'Blida_CARDIOLOGIE',
        courseId: 'c_cardio_sca',
        courseName: 'Syndromes Coronariens Aigus',
        type: QuestionType.casClinique,
        clinicalCaseText: 'Un homme de 58 ans, diabétique et tabagique, se présente aux urgences pour une douleur rétrosternale constrictive apparue au repos il y a 45 minutes, irradiant à la mâchoire et au bras gauche, accompagnée de sueurs froides et d\'angoisse. TA : 155/95 mmHg, FC : 88 bpm. L\'ECG montre un sus-décalage persistant du segment ST de 3 mm en DII, DIII, aVF avec miroir en DI et aVL.',
        questionText: 'Quelle est la conduite à tenir thérapeutique en extrême urgence ?',
        options: [
          QcmOption(key: 'A', text: 'Attendre le résultat du dosage de la troponine ultrasensible avant tout geste.'),
          QcmOption(key: 'B', text: 'Transférer en salle de coronarographie pour angioplastie primaire dans un délai < 120 minutes.'),
          QcmOption(key: 'C', text: 'Administrer de l\'Aspirine 250 mg IV et une dose de charge d\'un inhibiteur P2Y12 (ex: Ticagrélor).'),
          QcmOption(key: 'D', text: 'Enregistrer impérativement les dérivations V7-V8-V9 et V3R-V4R pour éliminer une extension au ventricule droit ou postérieure.'),
          QcmOption(key: 'E', text: 'Prescrire une corticothérapie à forte dose pour réduire l\'inflammation péricardique.'),
        ],
        correctAnswers: ['B', 'C', 'D'],
        explanation: 'Justification clinique :\n'
            'Le patient présente un SCA ST+ inférieur typique en phase hyperaiguë.\n'
            '• A : FAUX. Dans le SCA ST+, la reperfusion ne doit JAMAIS attendre les marqueurs biologiques (le retard entraîne une nécrose irréversible).\n'
            '• B : VRAI. L\'angioplastie primaire est le gold standard si réalisée en < 120 min après le diagnostic ECG.\n'
            '• C : VRAI. La double antiagrégation plaquettaire immédiate est indispensable.\n'
            '• D : VRAI. Tout IDM inférieur justifie l\'enregistrement des dérivations droites (V3R-V4R) et postérieures (V7-V8-V9) pour rechercher un infarctus du ventricule droit ou une extension basale.\n'
            '• E : FAUX. Les corticoïdes sont contre-indiqués dans l\'infarctus aigu.',
        source: 'Résidanat Blida 2023',
        year: 2023,
      ),
    ];
  }
}
