import '../models/module_model.dart';
import '../models/qcm_model.dart';

class ResidencyRepository {
  static List<MedicalModuleModel> getModules() {
    return [
      const MedicalModuleModel(
        id: 'mod_cardio',
        name: 'Cardiologie',
        category: 'Médecine',
        totalQuestions: 1485,
        totalCourses: 6,
        iconName: 'favorite',
        courses: [
          CourseModel(
            id: 'c_cardio_hta',
            moduleId: 'mod_cardio',
            name: 'Hypertension Artérielle de l\'Adulte (HTA)',
            questionsCount: 340,
            hasPdf: true,
            completedQuestions: 24,
          ),
          CourseModel(
            id: 'c_cardio_sca',
            moduleId: 'mod_cardio',
            name: 'Syndromes Coronariens Aigus (SCA ST+ / ST-)',
            questionsCount: 412,
            hasPdf: true,
            completedQuestions: 50,
          ),
          CourseModel(
            id: 'c_cardio_ic',
            moduleId: 'mod_cardio',
            name: 'Insuffisance Cardiaque Aiguë et Chronique',
            questionsCount: 295,
            hasPdf: true,
            completedQuestions: 12,
          ),
          CourseModel(
            id: 'c_cardio_valvulo',
            moduleId: 'mod_cardio',
            name: 'Valvulopathies (Rao, IM, RM, IA)',
            questionsCount: 210,
            hasPdf: true,
            completedQuestions: 0,
          ),
          CourseModel(
            id: 'c_cardio_pericardite',
            moduleId: 'mod_cardio',
            name: 'Péricardite Aiguë et Tamponnade',
            questionsCount: 128,
            hasPdf: true,
            completedQuestions: 0,
          ),
          CourseModel(
            id: 'c_cardio_endocardite',
            moduleId: 'mod_cardio',
            name: 'Endocardite Infectieuse',
            questionsCount: 100,
            hasPdf: true,
            completedQuestions: 0,
          ),
        ],
      ),
      const MedicalModuleModel(
        id: 'mod_pneumo',
        name: 'Pneumologie',
        category: 'Médecine',
        totalQuestions: 1220,
        totalCourses: 5,
        iconName: 'air',
        courses: [
          CourseModel(
            id: 'c_pneumo_asthme',
            moduleId: 'mod_pneumo',
            name: 'Asthme de l\'Adulte et Crise Aiguë Grave',
            questionsCount: 310,
            hasPdf: true,
            completedQuestions: 45,
          ),
          CourseModel(
            id: 'c_pneumo_bpco',
            moduleId: 'mod_pneumo',
            name: 'Bronchopneumopathie Chronique Obstructive (BPCO)',
            questionsCount: 285,
            hasPdf: true,
            completedQuestions: 18,
          ),
          CourseModel(
            id: 'c_pneumo_pac',
            moduleId: 'mod_pneumo',
            name: 'Pneumonies Aiguës Communautaires',
            questionsCount: 260,
            hasPdf: true,
            completedQuestions: 30,
          ),
          CourseModel(
            id: 'c_pneumo_ep',
            moduleId: 'mod_pneumo',
            name: 'Embolie Pulmonaire',
            questionsCount: 245,
            hasPdf: true,
            completedQuestions: 15,
          ),
          CourseModel(
            id: 'c_pneumo_pleuresie',
            moduleId: 'mod_pneumo',
            name: 'Pleurésies Sérofibrineuses et Purulentes',
            questionsCount: 120,
            hasPdf: true,
            completedQuestions: 0,
          ),
        ],
      ),
      const MedicalModuleModel(
        id: 'mod_neuro',
        name: 'Neurologie',
        category: 'Médecine',
        totalQuestions: 1350,
        totalCourses: 5,
        iconName: 'psychology',
        courses: [
          CourseModel(
            id: 'c_neuro_avc',
            moduleId: 'mod_neuro',
            name: 'Accidents Vasculaires Cérébraux (Ischémique & Hémorragique)',
            questionsCount: 420,
            hasPdf: true,
            completedQuestions: 60,
          ),
          CourseModel(
            id: 'c_neuro_epilepsie',
            moduleId: 'mod_neuro',
            name: 'Épilepsies et État de Mal Épileptique',
            questionsCount: 310,
            hasPdf: true,
            completedQuestions: 20,
          ),
          CourseModel(
            id: 'c_neuro_sep',
            moduleId: 'mod_neuro',
            name: 'Sclérose en Plaques (SEP)',
            questionsCount: 240,
            hasPdf: true,
            completedQuestions: 0,
          ),
          CourseModel(
            id: 'c_neuro_parkinson',
            moduleId: 'mod_neuro',
            name: 'Maladie de Parkinson et Syndromes Parkinsonniens',
            questionsCount: 190,
            hasPdf: true,
            completedQuestions: 0,
          ),
          CourseModel(
            id: 'c_neuro_meningites',
            moduleId: 'mod_neuro',
            name: 'Méningites et Encéphalites Aiguës',
            questionsCount: 190,
            hasPdf: true,
            completedQuestions: 10,
          ),
        ],
      ),
      const MedicalModuleModel(
        id: 'mod_gastro',
        name: 'Hépato-Gastro-Entérologie',
        category: 'Médecine',
        totalQuestions: 1180,
        totalCourses: 4,
        iconName: 'restaurant',
        courses: [
          CourseModel(
            id: 'c_gastro_cirrhose',
            moduleId: 'mod_gastro',
            name: 'Cirrhose du Foie et ses Complications',
            questionsCount: 350,
            hasPdf: true,
            completedQuestions: 15,
          ),
          CourseModel(
            id: 'c_gastro_ugd',
            moduleId: 'mod_gastro',
            name: 'Ulcère Gastro-Duodénal et Hémorragies Digestives',
            questionsCount: 310,
            hasPdf: true,
            completedQuestions: 0,
          ),
          CourseModel(
            id: 'c_gastro_mici',
            moduleId: 'mod_gastro',
            name: 'Maladies Inflammatoires Chroniques de l\'Intestin (MICI)',
            questionsCount: 280,
            hasPdf: true,
            completedQuestions: 0,
          ),
          CourseModel(
            id: 'c_gastro_pancreatite',
            moduleId: 'mod_gastro',
            name: 'Pancréatites Aiguës et Chroniques',
            questionsCount: 240,
            hasPdf: true,
            completedQuestions: 0,
          ),
        ],
      ),
      const MedicalModuleModel(
        id: 'mod_pediatrie',
        name: 'Pédiatrie',
        category: 'Médecine',
        totalQuestions: 1420,
        totalCourses: 4,
        iconName: 'child_care',
        courses: [
          CourseModel(
            id: 'c_ped_deshydratation',
            moduleId: 'mod_pediatrie',
            name: 'Déshydratation Aiguë du Nourrisson',
            questionsCount: 380,
            hasPdf: true,
            completedQuestions: 25,
          ),
          CourseModel(
            id: 'c_ped_bronchiolite',
            moduleId: 'mod_pediatrie',
            name: 'Bronchiolite Aiguë du Nourrisson',
            questionsCount: 310,
            hasPdf: true,
            completedQuestions: 10,
          ),
          CourseModel(
            id: 'c_ped_ictere',
            moduleId: 'mod_pediatrie',
            name: 'Ictère Néonatal (Physiologique et Pathologique)',
            questionsCount: 340,
            hasPdf: true,
            completedQuestions: 0,
          ),
          CourseModel(
            id: 'c_ped_rachitisme',
            moduleId: 'mod_pediatrie',
            name: 'Rachitisme Carentiel et Carence Martiale',
            questionsCount: 390,
            hasPdf: true,
            completedQuestions: 0,
          ),
        ],
      ),
      const MedicalModuleModel(
        id: 'mod_infectieux',
        name: 'Maladies Infectieuses',
        category: 'Médecine',
        totalQuestions: 980,
        totalCourses: 4,
        iconName: 'coronavirus',
        courses: [
          CourseModel(
            id: 'c_inf_tuberculose',
            moduleId: 'mod_infectieux',
            name: 'Tuberculose Pulmonaire et Extra-pulmonaire',
            questionsCount: 320,
            hasPdf: true,
            completedQuestions: 12,
          ),
          CourseModel(
            id: 'c_inf_typhoide',
            moduleId: 'mod_infectieux',
            name: 'Fièvre Typhoïde et Salmonelloses',
            questionsCount: 240,
            hasPdf: true,
            completedQuestions: 0,
          ),
          CourseModel(
            id: 'c_inf_brucellose',
            moduleId: 'mod_infectieux',
            name: 'Brucellose Humaine',
            questionsCount: 220,
            hasPdf: true,
            completedQuestions: 0,
          ),
          CourseModel(
            id: 'c_inf_vih',
            moduleId: 'mod_infectieux',
            name: 'Infection par le VIH et Infections Opportunistes',
            questionsCount: 200,
            hasPdf: true,
            completedQuestions: 0,
          ),
        ],
      ),
    ];
  }

  static List<QcmQuestion> getQuestionsForCourse(String courseId) {
    return [
      const QcmQuestion(
        id: 'q_001',
        moduleId: 'mod_cardio',
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
        moduleId: 'mod_cardio',
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
        moduleId: 'mod_cardio',
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
