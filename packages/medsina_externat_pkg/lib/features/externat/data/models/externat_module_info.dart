import 'package:flutter/material.dart';

/// Information regarding an academic module, its teaching duration in weeks,
/// and pedagogical specifications across Algerian medical faculties.
class ExternatModuleInfo {
  final String id;
  final String name;
  final int studyYear;
  final int durationWeeks;
  final String rotationType; // 'Hospitalier', 'Pré-clinique', 'Théorique / Intégré'
  final String focusSummary;
  final int defaultEmdQuestions;
  final int emdDurationMinutes;
  final List<String> highYieldTopics;

  const ExternatModuleInfo({
    required this.id,
    required this.name,
    required this.studyYear,
    required this.durationWeeks,
    required this.rotationType,
    required this.focusSummary,
    this.defaultEmdQuestions = 40,
    this.emdDurationMinutes = 60,
    this.highYieldTopics = const [],
  });
}

/// Represents the Virtual Medical Professor / Tutor for a specific study year.
class ExternatTeacherPersona {
  final int studyYear;
  final String name;
  final String academicTitle;
  final String tagline;
  final String avatarAsset;
  final Color themeColor;
  final IconData icon;
  final List<String> competencies;
  final String pedagogicalStyle;

  const ExternatTeacherPersona({
    required this.studyYear,
    required this.name,
    required this.academicTitle,
    required this.tagline,
    required this.avatarAsset,
    required this.themeColor,
    required this.icon,
    required this.competencies,
    required this.pedagogicalStyle,
  });
}

/// Repository & Matrix of module durations in Algerian Medical Curriculum.
class ExternatCurriculumMatrix {
  static const List<ExternatTeacherPersona> teachers = [
    ExternatTeacherPersona(
      studyYear: 1,
      name: 'MedsinaTeacher - Sciences Fondamentales & Anatomie',
      academicTitle: 'Professeur en Sciences Fondamentales & Anatomie',
      tagline: 'Maîtrisez les bases anatomiques et biochimiques sans apprendre par cœur inutilement.',
      avatarAsset: 'assets/images/doctor_avatar.png',
      themeColor: Color(0xFF0284C7),
      icon: Icons.science_rounded,
      competencies: ['Anatomie descriptive', 'Schémas fonctionnels', 'Voies métaboliques', 'Cytologie'],
      pedagogicalStyle: 'Vulgarisation visuelle, mnémotechniques de rétention et schémas légendés.',
    ),
    ExternatTeacherPersona(
      studyYear: 2,
      name: 'MedsinaTeacher - Physiologie & Unités Intégrées',
      academicTitle: 'Maître-Assistant en Physiologie & Unités Intégrées',
      tagline: 'Comprendre la physiologie normale, c\'est résoudre d\'avance toutes les pathologies.',
      avatarAsset: 'assets/images/doctor_avatar.png',
      themeColor: Color(0xFF0D9488),
      icon: Icons.biotech_rounded,
      competencies: ['Boucles de régulation', 'Hémodynamique', 'Physiologie respiratoire & rénale'],
      pedagogicalStyle: 'Raisonnement systémique, corrélation entre les organes et schémas de régulation.',
    ),
    ExternatTeacherPersona(
      studyYear: 3,
      name: 'MedsinaTeacher - Sémiologie & Pré-Clinique',
      academicTitle: 'Chef de Clinique en Sémiologie & Diagnostic',
      tagline: 'De l\'amphi au lit du malade : l\'examen clinique rigoureux fait 80% du diagnostic.',
      avatarAsset: 'assets/images/doctor_avatar.png',
      themeColor: Color(0xFF6366F1),
      icon: Icons.psychology_rounded,
      competencies: ['Inspection & Palpation', 'Auscultation cardio-pulmonaire', 'Orientation paraclinique'],
      pedagogicalStyle: 'Cas concrets de stage, démarche sémiologique pas à pas, pièges de l\'interrogatoire.',
    ),
    ExternatTeacherPersona(
      studyYear: 4,
      name: 'MedsinaTeacher - Pathologie Médicale & Chirurgicale I',
      academicTitle: 'Professeur Hospitalo-Universitaire en Médecine Interne & Clinique I',
      tagline: 'Grandes pathologies d\'hospitalisation : raisonnement rapide, consensus et zéro impasse.',
      avatarAsset: 'assets/images/doctor_avatar.png',
      themeColor: Color(0xFF10B981),
      icon: Icons.medical_services_rounded,
      competencies: ['Cardiologie & ECG', 'Pneumologie', 'Gastro-Hépatologie', 'Neurologie clinique'],
      pedagogicalStyle: 'Orientation EMD et résidanat, conduite à tenir immédiate, arbres décisionnels.',
    ),
    ExternatTeacherPersona(
      studyYear: 5,
      name: 'MedsinaTeacher - Pathologie Médico-Chirurgicale II',
      academicTitle: 'Professeur en Spécialités Médico-Chirurgicales',
      tagline: 'Gérer les rotations courtes avec intensité : Pédiatrie, Gynécologie, ORL et Ophtalmo.',
      avatarAsset: 'assets/images/doctor_avatar.png',
      themeColor: Color(0xFFF59E0B),
      icon: Icons.child_care_rounded,
      competencies: ['Urgences pédiatriques', 'Obstétrique', 'ORL & Ophtalmologie en 3 semaines', 'Dermatologie'],
      pedagogicalStyle: 'Fiches réflexes d\'urgence, calculs de posologie pédiatrique, diagnostic visuel.',
    ),
    ExternatTeacherPersona(
      studyYear: 6,
      name: 'MedsinaTeacher - Urgences (UMC) & Thérapeutique',
      academicTitle: 'Praticien Spécialiste aux UMC & Enseignant Thérapeutique',
      tagline: 'Objectif Internat & Résidanat : maîtriser l\'urgence vitale et l\'ordonnance parfaite.',
      avatarAsset: 'assets/images/doctor_avatar.png',
      themeColor: Color(0xFFE11D48),
      icon: Icons.emergency_rounded,
      competencies: ['Protocoles UMC', 'Ordonnances types', 'Médecine légale & Certificats', 'Médecine du travail'],
      pedagogicalStyle: 'Simulations de gardes réelles, gestion du stress, ordonnances complètes et justifications.',
    ),
  ];

  /// Official Google Drive folders for Algerian Medical Curriculum & Blida Faculty
  static const Map<int, String> officialYearDrives = {
    1: 'https://drive.google.com/drive/folders/1OpTSOfoyXF8sTK1tW2323KmAqXzBVUzV',
    2: 'https://drive.google.com/drive/folders/1mNbDj7B936Tm2O87ycOCqqXvCvOUI5EL',
    3: 'https://drive.google.com/drive/folders/1TZhLE7o-QQVemz5oxAqO46SoM2rCcYep',
    4: 'https://drive.google.com/drive/folders/1TZhLE7o-QQVemz5oxAqO46SoM2rCcYep',
    5: 'https://drive.google.com/drive/folders/13Z89CeV8bpQlL74OVFMfjrone2M0XQ--',
    6: 'https://drive.google.com/drive/folders/1-4j0fd19TOa4jyAFeIIzbh6zIu085O5q',
  };

  static const String blidaGeneralDrive = 'https://drive.google.com/drive/folders/1fPjicGWf2sFz5oJ6nTxWExlT5FggBVml';
  static const String blidaCollectionDrive = 'https://drive.google.com/drive/folders/13sszUJvcPvFFROkVxFLcF2FcFnm2QAKz';
  static const String samediPedagogique2026Drive = 'https://drive.google.com/drive/folders/1NXSP4l7Eip9eKxsRKgUy5qRZDG4zEF1k';
  static const String residanatBlidaYouTube = 'https://www.youtube.com/@residanatblida';
  static const String drAladdinYouTube = 'https://www.youtube.com/@dr_aladdin_helper';

  static ExternatTeacherPersona getTeacherForYear(int year) {
    return teachers.firstWhere(
      (t) => t.studyYear == year,
      orElse: () => teachers[3], // Default to 4th year
    );
  }

  /// Official durations of Algerian teaching modules mapped to real Blida QCM bank IDs
  static const List<ExternatModuleInfo> modulesData = [
    // 1ère Année
    ExternatModuleInfo(
      id: 'Blida_ANATOMIE_1_ERE',
      name: 'Anatomie (1 ère)',
      studyYear: 1,
      durationWeeks: 12,
      rotationType: 'Fondamental & TP',
      focusSummary: 'Ostéologie, arthrologie, myologie, vascularisation et innervation des membres, parois du tronc.',
      defaultEmdQuestions: 30,
      emdDurationMinutes: 45,
      highYieldTopics: ['Plexus brachial et nerf radial', 'Plexus lombaire et nerf sciatique', 'Ostéologie du membre supérieur et inférieur', 'Vascularisation artérielle des membres'],
    ),
    ExternatModuleInfo(
      id: 'Blida_BIOCHIMIE_1_ERE',
      name: 'Biochimie (1 ère)',
      studyYear: 1,
      durationWeeks: 10,
      rotationType: 'Fondamental',
      focusSummary: 'Glucides, lipides, acides aminés, protéines, enzymologie et bioénergétique cellulaire.',
      defaultEmdQuestions: 30,
      emdDurationMinutes: 45,
      highYieldTopics: ['Glycolyse et cycle de Krebs', 'Enzymologie et cinétique de Michaelis', 'Métabolisme des lipides et bêta-oxydation', 'Structure des acides aminés et protéines'],
    ),
    ExternatModuleInfo(
      id: 'Blida_CYTOLOGIE',
      name: 'Cytologie',
      studyYear: 1,
      durationWeeks: 8,
      rotationType: 'Fondamental',
      focusSummary: 'Membrane plasmique, cytosquelette, noyau, système endomembranaire, mitochondrie et cycle cellulaire.',
      defaultEmdQuestions: 30,
      emdDurationMinutes: 45,
      highYieldTopics: ['Transports membranaires actifs et passifs', 'Système endomembranaire et appareil de Golgi', 'Respiration mitochondriale', 'Cycle cellulaire et mitose'],
    ),
    ExternatModuleInfo(
      id: 'Blida_PHYSIOLOGIE_1_ERE',
      name: 'Physiologie (1 ère)',
      studyYear: 1,
      durationWeeks: 8,
      rotationType: 'Fondamental',
      focusSummary: 'Compartiments liquidiens, homéostasie, électrophysiologie membranaire, potentiel d\'action et contraction musculaire.',
      defaultEmdQuestions: 30,
      emdDurationMinutes: 45,
      highYieldTopics: ['Potentiel de repos et potentiel d\'action', 'Transmission synaptique neuromusculaire', 'Compartiments liquidiens de l\'organisme', 'Physiologie du système nerveux autonome'],
    ),
    ExternatModuleInfo(
      id: 'Blida_EMBRYOLOGIE',
      name: 'Embryologie',
      studyYear: 1,
      durationWeeks: 6,
      rotationType: 'Fondamental',
      focusSummary: 'Gamétogenèse, fécondation, segmentation, gastrulation, neurulation et annexes embryonnaires.',
      defaultEmdQuestions: 25,
      emdDurationMinutes: 40,
      highYieldTopics: ['1ère à 4ème semaine du développement embryonnaire', 'Gastrulation et dérivés des 3 feuillets', 'Placenta et annexes embryonnaires', 'Fécondation et nidation'],
    ),
    ExternatModuleInfo(
      id: 'Blida_HISTOLOGIE_1_ERE',
      name: 'Histologie (1 ère)',
      studyYear: 1,
      durationWeeks: 6,
      rotationType: 'Fondamental',
      focusSummary: 'Épithéliums de revêtement et glandulaires, tissus conjonctifs, cartilagineux, osseux, sanguin, musculaire et nerveux.',
      defaultEmdQuestions: 25,
      emdDurationMinutes: 40,
      highYieldTopics: ['Classification des épithéliums', 'Tissu osseux et ostéogenèse', 'Tissu musculaire strié et lisse', 'Tissu nerveux et névroglie'],
    ),
    ExternatModuleInfo(
      id: 'Blida_BIOPHYSIQUE_1_ERE',
      name: 'Biophysique (1 ère)',
      studyYear: 1,
      durationWeeks: 6,
      rotationType: 'Fondamental',
      focusSummary: 'États de la matière, micromolécules en solution, diffusion, osmose, électrophysiologie et rayonnements.',
      defaultEmdQuestions: 25,
      emdDurationMinutes: 40,
      highYieldTopics: ['Pression osmotique et loi de Van\'t Hoff', 'Équilibre de Donnan', 'Acido-basique et tampon bicarbonate', 'Radioactivité et radioprotection'],
    ),

    // 2ème Année
    ExternatModuleInfo(
      id: 'Blida_UNITE_1_2_EME',
      name: 'Unité 1 cardio-respiratoire (2 ème)',
      studyYear: 2,
      durationWeeks: 7,
      rotationType: 'Théorique / Intégré',
      focusSummary: 'Anatomie, histologie, physiologie et biophysique intégrées des appareils cardiovasculaire et respiratoire.',
      defaultEmdQuestions: 40,
      emdDurationMinutes: 60,
      highYieldTopics: ['Cycle cardiaque et débit cardiaque', 'Régulation de la pression artérielle', 'Mécanique ventilatoire et échanges gazeux', 'Électrocardiogramme normal'],
    ),
    ExternatModuleInfo(
      id: 'Blida_UNITE_2_2_EME',
      name: 'Unité 2 digestive (2 ème)',
      studyYear: 2,
      durationWeeks: 6,
      rotationType: 'Théorique / Intégré',
      focusSummary: 'Anatomie, histologie, physiologie et biochimie du tube digestif et des glandes annexes (foie, pancréas).',
      defaultEmdQuestions: 40,
      emdDurationMinutes: 60,
      highYieldTopics: ['Sécrétions gastriques, biliaires et pancréatiques', 'Motricité digestive', 'Digestion et absorption intestinale', 'Anatomie du foie et système porte'],
    ),
    ExternatModuleInfo(
      id: 'Blida_UNITE_3_2_EME',
      name: 'Unité 3 urinaire (2 ème)',
      studyYear: 2,
      durationWeeks: 6,
      rotationType: 'Théorique / Intégré',
      focusSummary: 'Anatomie, histologie et physiologie rénale, filtration glomérulaire, fonctions tubulaires et équilibre acido-basique.',
      defaultEmdQuestions: 40,
      emdDurationMinutes: 60,
      highYieldTopics: ['Filtration glomérulaire et clairance rénale', 'Réabsorption et sécrétion tubulaire', 'Concentration et dilution des urines', 'Régulation rénale de l\'équilibre acido-basique'],
    ),
    ExternatModuleInfo(
      id: 'Blida_UNITE_4_2_EME',
      name: 'Unité 4 endo (2 ème)',
      studyYear: 2,
      durationWeeks: 6,
      rotationType: 'Théorique / Intégré',
      focusSummary: 'Axe hypothalamo-hypophysaire, thyroïde, surrénales, pancréas endocrine, métabolisme phosphocalcique et reproduction.',
      defaultEmdQuestions: 40,
      emdDurationMinutes: 60,
      highYieldTopics: ['Hormones thyroïdiennes et régulation', 'Corticosurrénale et médullosurrénale', 'Homéostasie glycémique et insuline', 'Métabolisme phosphocalcique (PTH, Vit D)'],
    ),
    ExternatModuleInfo(
      id: 'Blida_UNITE_5_2_EME',
      name: 'Unité 5 neuro (2 ème)',
      studyYear: 2,
      durationWeeks: 6,
      rotationType: 'Théorique / Intégré',
      focusSummary: 'Neuroanatomie centrale et périphérique, voies de la sensibilité et de la motricité, organes des sens.',
      defaultEmdQuestions: 40,
      emdDurationMinutes: 60,
      highYieldTopics: ['Voies pyramidales et extrapyramidales', 'Voies de la sensibilité consciente et inconsciente', 'Nerfs crâniens et tronc cérébral', 'Cervelet et noyaux gris centraux'],
    ),
    ExternatModuleInfo(
      id: 'Blida_IMMUNOLOGIE_2_EME',
      name: 'Immunologie (2 ème)',
      studyYear: 2,
      durationWeeks: 5,
      rotationType: 'Fondamental',
      focusSummary: 'Organes lymphoïdes, immunité innée et adaptative, antigènes, anticorps, système du complément, CMH, lymphocytes T et B.',
      defaultEmdQuestions: 35,
      emdDurationMinutes: 50,
      highYieldTopics: ['Structure et fonctions des immunoglobulines', 'Complexe Majeur d\'Histocompatibilité (CMH)', 'Activation du système du complément', 'Coopération cellulaire et réponse immune'],
    ),

    // 3ème Année
    ExternatModuleInfo(
      id: 'Blida_UNITE_1_3_EME',
      name: 'Unité 1 cardio-respiratoire (3 ème)',
      studyYear: 3,
      durationWeeks: 6,
      rotationType: 'Pré-clinique & Stage',
      focusSummary: 'Sémiologie cardiovasculaire et respiratoire, auscultation, radiologie thoracique, ECG pathologique et explorations.',
      defaultEmdQuestions: 40,
      emdDurationMinutes: 60,
      highYieldTopics: ['Souffles cardiaques et valvulopathies', 'Douleurs thoraciques et dyspnées', 'Syndromes pleuraux et parenchymateux', 'Sémiologie de l\'insuffisance cardiaque'],
    ),
    ExternatModuleInfo(
      id: 'Blida_UNITE_2_3_EME',
      name: 'Unité 2 neuro (3 ème)',
      studyYear: 3,
      durationWeeks: 6,
      rotationType: 'Pré-clinique & Stage',
      focusSummary: 'Sémiologie neurologique et locomotrice, syndromes moteurs, sensitifs, cérébelleux, méningés et nerfs crâniens.',
      defaultEmdQuestions: 40,
      emdDurationMinutes: 60,
      highYieldTopics: ['Syndrome pyramidal vs neurogène périphérique', 'Syndrome méningé et hypertension intracrânienne', 'Syndrome cérébelleux et vestibulaire', 'Examen clinique des paires crâniennes'],
    ),
    ExternatModuleInfo(
      id: 'Blida_UNITE_3_3_EME',
      name: 'Unité 3 endo (3 ème)',
      studyYear: 3,
      durationWeeks: 5,
      rotationType: 'Pré-clinique & Stage',
      focusSummary: 'Sémiologie endocrinienne, métabolique, urinaire et néphrologique, syndromes glomérulaires et désordres hydro-électrolytiques.',
      defaultEmdQuestions: 40,
      emdDurationMinutes: 60,
      highYieldTopics: ['Syndrome d\'hyperthyroïdie et d\'hypothyroïdie', 'Syndrome de Cushing et insuffisance surrénalienne', 'Syndromes néphrotique et néphritique', 'Sémiologie du diabète sucré'],
    ),
    ExternatModuleInfo(
      id: 'Blida_UNITE_4_3_EME',
      name: 'Unité 4 digestive (3 ème)',
      studyYear: 3,
      durationWeeks: 5,
      rotationType: 'Pré-clinique & Stage',
      focusSummary: 'Sémiologie hépato-gastro-entérologique et hématologique : ictères, hémorragies digestives, ascite, splénomégalie, adénopathies.',
      defaultEmdQuestions: 40,
      emdDurationMinutes: 60,
      highYieldTopics: ['Hypertension portale et insuffisance hépatocellulaire', 'Sémiologie des ictères et douleurs abdominales', 'Hémogramme pathologique et anémies', 'Adénopathies et splénomégalie'],
    ),
    ExternatModuleInfo(
      id: 'Blida_PHARMACOLOGIE',
      name: 'Pharmacologie',
      studyYear: 3,
      durationWeeks: 6,
      rotationType: 'Pré-clinique',
      focusSummary: 'Pharmacocinétique (ADME), pharmacodynamie, système nerveux autonome, antibiotiques, anti-inflammatoires et cardiotropes.',
      defaultEmdQuestions: 35,
      emdDurationMinutes: 50,
      highYieldTopics: ['Pharmacocinétique : biodisponibilité, demi-vie, clairance', 'Médicaments adrénergiques et cholinergiques', 'Classes d\'antibiotiques et mécanismes d\'action', 'AINS, corticoïdes et anticoagulants'],
    ),
    ExternatModuleInfo(
      id: 'Blida_MICROBIOLOGIE',
      name: 'Microbiologie',
      studyYear: 3,
      durationWeeks: 6,
      rotationType: 'Pré-clinique',
      focusSummary: 'Bactériologie générale et systématique, virologie médicale, résistance bactérienne aux antibiotiques et diagnostic biologique.',
      defaultEmdQuestions: 35,
      emdDurationMinutes: 50,
      highYieldTopics: ['Cocci à Gram positif (Staphylocoques, Streptocoques)', 'Entérobactéries et bacilles à Gram négatif', 'Mycobactéries (BK) et diagnostic de la tuberculose', 'Virus des hépatites et VIH'],
    ),
    ExternatModuleInfo(
      id: 'Blida_ANAPATHOLOGIE',
      name: 'Anapathologie',
      studyYear: 3,
      durationWeeks: 5,
      rotationType: 'Pré-clinique',
      focusSummary: 'Lésions cellulaires, inflammation aiguë et chronique, troubles hémodynamiques, athérosclérose et pathologie tumorale générale.',
      defaultEmdQuestions: 35,
      emdDurationMinutes: 50,
      highYieldTopics: ['Inflammation aiguë, chronique et granulomateuse', 'Tumeurs bénignes vs malignes et métastases', 'Thrombose, embolie et infarctus', 'Méthodes d\'étude en anatomie pathologique'],
    ),
    ExternatModuleInfo(
      id: 'Blida_PARASITOLOGIE',
      name: 'Parasitologie',
      studyYear: 3,
      durationWeeks: 5,
      rotationType: 'Pré-clinique',
      focusSummary: 'Protozooses (Paludisme, Leishmanioses, Toxoplasmose, Amibiase), Helminthiases (Hydatidose) et Mycologie médicale.',
      defaultEmdQuestions: 35,
      emdDurationMinutes: 50,
      highYieldTopics: ['Paludisme : cycle et diagnostic d\'urgence', 'Leishmanioses viscérale et cutanée en Algérie', 'Kyste hydatique (Échinococcose)', 'Toxoplasmose et grossesse'],
    ),

    // 4ème Année
    ExternatModuleInfo(
      id: 'Blida_CARDIOLOGIE',
      name: 'Cardiologie',
      studyYear: 4,
      durationWeeks: 6,
      rotationType: 'Hospitalier',
      focusSummary: 'Insuffisance cardiaque, SCA, HTA, Valvulopathies, Troubles du rythme et de la conduction, ECG.',
      defaultEmdQuestions: 50,
      emdDurationMinutes: 60,
      highYieldTopics: ['Syndromes coronariens aigus', 'Insuffisance cardiaque aiguë/chronique', 'Interprétation ECG', 'Infarctus du myocarde'],
    ),
    ExternatModuleInfo(
      id: 'Blida_PNEUMOLOGIE',
      name: 'Pneumologie',
      studyYear: 4,
      durationWeeks: 6,
      rotationType: 'Hospitalier',
      focusSummary: 'BPCO, Asthme aigu grave, Tuberculose pulmonaire (Programme National), Pneumonies aiguës, Pleurésies.',
      defaultEmdQuestions: 50,
      emdDurationMinutes: 60,
      highYieldTopics: ['Tuberculose pulmonaire en Algérie', 'Asthme et crise grave', 'BPCO et exacerbations', 'Cancer broncho-pulmonaire'],
    ),
    ExternatModuleInfo(
      id: 'Blida_HEPATO_GASTRO_ENTEROLOGIE',
      name: 'Hépato-Gastro-Entérologie',
      studyYear: 4,
      durationWeeks: 6,
      rotationType: 'Hospitalier',
      focusSummary: 'Cirrhoses et complications, Ulcère gastro-duodénal, Hémorragies digestives, MICI (Crohn/RCH), Pancréatites.',
      defaultEmdQuestions: 50,
      emdDurationMinutes: 60,
      highYieldTopics: ['Hémorragies digestives hautes/basses', 'Complications de la cirrhose', 'Syndrome occlusif', 'MICI'],
    ),
    ExternatModuleInfo(
      id: 'Blida_NEUROLOGIE',
      name: 'Neurologie',
      studyYear: 4,
      durationWeeks: 6,
      rotationType: 'Hospitalier',
      focusSummary: 'Accidents Vasculaires Cérébraux (AVC), Épilepsies, Sclérose en plaques, Céphalées & Algies, Syndromes médullaires.',
      defaultEmdQuestions: 50,
      emdDurationMinutes: 60,
      highYieldTopics: ['AVC ischémiques et hémorragiques', 'État de mal épileptique', 'Syndromes radiculaires et médullaires', 'Méningites & encéphalites'],
    ),
    ExternatModuleInfo(
      id: 'Blida_MALADIES_INFECTIEUSES',
      name: 'Maladies Infectieuses',
      studyYear: 4,
      durationWeeks: 4,
      rotationType: 'Hospitalier',
      focusSummary: 'Fièvres prolongées, Méningites purulentes, Sepsis, Antibiothérapie rationnelle, Infection par le VIH, Paludisme.',
      defaultEmdQuestions: 40,
      emdDurationMinutes: 50,
      highYieldTopics: ['Méningites bactériennes vs virales', 'Choc septique', 'Fièvre typhoïde', 'Règles d\'antibiothérapie'],
    ),
    ExternatModuleInfo(
      id: 'Blida_HEMATOLOGIE',
      name: 'Hemato-oncologie',
      studyYear: 4,
      durationWeeks: 4,
      rotationType: 'Hospitalier',
      focusSummary: 'Anémies carentielles et hémolytiques, Leucémies aiguës et chroniques, Lymphomes (Hodgkin/LNH), Troubles de l\'hémostase.',
      defaultEmdQuestions: 40,
      emdDurationMinutes: 50,
      highYieldTopics: ['Anémies mégaloblastiques et ferriprives', 'Leucémies aiguës', 'Transfusion sanguine et sécurité', 'Purpuras et hémostase'],
    ),
    ExternatModuleInfo(
      id: 'Blida_APPAREIL_LOCOMOTEUR',
      name: 'Appareil locomoteur',
      studyYear: 4,
      durationWeeks: 4,
      rotationType: 'Hospitalier',
      focusSummary: 'Fractures des membres, Luxations, Polytraumatisés, Syndromes des loges, Infections ostéo-articulaires, Rhumatologie.',
      defaultEmdQuestions: 40,
      emdDurationMinutes: 50,
      highYieldTopics: ['Fractures de l\'extrémité supérieure du fémur', 'Syndrome de Volkmann et loges', 'Prise en charge du polytraumatisé', 'Luxations de l\'épaule'],
    ),

    // 5ème Année
    ExternatModuleInfo(
      id: 'Blida_PEDIATRIE',
      name: 'Pédiatrie',
      studyYear: 5,
      durationWeeks: 12,
      rotationType: 'Hospitalier (Trimestre)',
      focusSummary: 'Déshydratation aiguë, Malnutrition, Détresses respiratoires du nourrisson, Convulsions fébriles, Néonatalogie.',
      defaultEmdQuestions: 60,
      emdDurationMinutes: 90,
      highYieldTopics: ['Déshydratation aiguë du nourrisson & solutés', 'Bronchiolite & pneumopathies', 'Ictères néonatals', 'Calendrier vaccinal algérien'],
    ),
    ExternatModuleInfo(
      id: 'Blida_GYNECOLOGIE_OBSTETRIQUE',
      name: 'Gynecologie obstétrique',
      studyYear: 5,
      durationWeeks: 12,
      rotationType: 'Hospitalier (Trimestre)',
      focusSummary: 'Accouchement normal et dystocique, Hémorragies du 1er et 3ème trimestre, Pré-éclampsie, Cancers gynécologiques.',
      defaultEmdQuestions: 60,
      emdDurationMinutes: 90,
      highYieldTopics: ['Grossesse extra-utérine (GEU)', 'Pré-éclampsie et éclampsie', 'Hémorragie de la délivrance', 'Métrorragies post-ménopausiques'],
    ),
    ExternatModuleInfo(
      id: 'Blida_ORL',
      name: 'ORL',
      studyYear: 5,
      durationWeeks: 3,
      rotationType: 'Hospitalier (Court)',
      focusSummary: 'Otites moyennes aiguës et chroniques, Vertiges, Sinusites et complications, Cancers du cavum et du larynx, Dyspnée laryngée.',
      defaultEmdQuestions: 35,
      emdDurationMinutes: 45,
      highYieldTopics: ['Dyspnée laryngée aiguë de l\'enfant', 'Vertiges vestibulaires périphériques vs centraux', 'Cancer du nasopharynx (cavum)', 'Complications des otites'],
    ),
    ExternatModuleInfo(
      id: 'Blida_OPHTALMOLOGIE',
      name: 'Ophtalmologie',
      studyYear: 5,
      durationWeeks: 3,
      rotationType: 'Hospitalier (Court)',
      focusSummary: 'Oeil rouge douloureux / non douloureux, Baisse d\'acuité visuelle brutale / progressive, Glaucome aigu par fermeture de l\'angle, Cataracte.',
      defaultEmdQuestions: 35,
      emdDurationMinutes: 45,
      highYieldTopics: ['Glaucome aigu par fermeture de l\'angle (GAFA)', 'Diagnostic différentiel de l\'œil rouge', 'Décollement de rétine', 'Occlusion artérielle rétinienne'],
    ),
    ExternatModuleInfo(
      id: 'Blida_DERMATOLOGIE',
      name: 'Dermatologie',
      studyYear: 5,
      durationWeeks: 3,
      rotationType: 'Hospitalier (Court)',
      focusSummary: 'Psoriasis, Eczéma, Dermatoses bulleuses, Toxidermies graves (Lyell / Stevens-Johnson), Tumeurs cutanées (Mélanome).',
      defaultEmdQuestions: 35,
      emdDurationMinutes: 45,
      highYieldTopics: ['Toxidermies médicamenteuses sévères', 'Dermatoses bulleuses auto-immunes', 'Érysipèle et dermohypodermites', 'Mélanome malin'],
    ),
    ExternatModuleInfo(
      id: 'Blida_URO_NEPHROLOGIE',
      name: 'Uro-Néphrologie',
      studyYear: 5,
      durationWeeks: 6,
      rotationType: 'Hospitalier',
      focusSummary: 'Insuffisance rénale aiguë (IRA) vs IRC, Syndromes néphrotiques et néphritiques, Colique néphrétique, Adénome et cancer de la prostate.',
      defaultEmdQuestions: 50,
      emdDurationMinutes: 60,
      highYieldTopics: ['Prise en charge de l\'IRA organique/fonctionnelle', 'Syndrome néphrotique impur/pur', 'Colique néphrétique compliquée', 'Hématuries microscopiques et macroscopiques'],
    ),
    ExternatModuleInfo(
      id: 'Blida_ENDOCRINO',
      name: 'Endocrino',
      studyYear: 5,
      durationWeeks: 5,
      rotationType: 'Hospitalier',
      focusSummary: 'Diabète de type 1 et 2, Complications aiguës (Acidocétose, Coma hyperosmolaire), Hyperthyroïdies et hypothyroïdies, Insuffisance surrénalienne.',
      defaultEmdQuestions: 45,
      emdDurationMinutes: 55,
      highYieldTopics: ['Acidocétose diabétique et protocoles d\'insuline', 'Crise aiguë d\'insuffisance surrénale (urgence vitale)', 'Maladie de Basedow', 'Nodules thyroïdiens'],
    ),
    ExternatModuleInfo(
      id: 'Blida_PSYCHIATRIE',
      name: 'Psychiatrie',
      studyYear: 5,
      durationWeeks: 4,
      rotationType: 'Hospitalier',
      focusSummary: 'Schizophrénies, Troubles bipolaires, Dépression majeure et risque suicidaire, États anxieux, Addictions, Hospitalisation sous contrainte.',
      defaultEmdQuestions: 40,
      emdDurationMinutes: 50,
      highYieldTopics: ['Évaluation et prévention de la crise suicidaire', 'Bouffée délirante aiguë vs schizophrénie', 'Troubles de l\'humeur et thymorégulateurs', 'Agitation aiguë aux urgences'],
    ),

    // 6ème Année
    ExternatModuleInfo(
      id: 'Blida_URGENCES_UMC',
      name: 'Urgences (UMC)',
      studyYear: 6,
      durationWeeks: 6,
      rotationType: 'Hospitalier (Garde & Réa)',
      focusSummary: 'Arrêt cardio-respiratoire (ACR), Chocs (cardiogénique, septique, anaphylactique, hypovolémique), Comas, Brûlures étendues, Intoxications aiguës.',
      defaultEmdQuestions: 50,
      emdDurationMinutes: 60,
      highYieldTopics: ['Algorithme de réanimation cardio-pulmonaire avancée', 'Prise en charge des 4 états de choc', 'Intoxications au monoxyde de carbone (CO)', 'Détresse respiratoire aiguë'],
    ),
    ExternatModuleInfo(
      id: 'Blida_MALADIES_DE_SYSTEME',
      name: 'Maladies de système',
      studyYear: 6,
      durationWeeks: 4,
      rotationType: 'Théorique & Stage',
      focusSummary: 'Lupus érythémateux systémique, Maladie de Behçet, Sarcoïdose, Sclérodermie, Vascularites systémiques et corticothérapie au long cours.',
      defaultEmdQuestions: 40,
      emdDurationMinutes: 50,
      highYieldTopics: ['Critères diagnostiques et atteinte rénale du Lupus (LES)', 'Maladie de Behçet et atteinte oculaire/vasculaire', 'Sarcoïdose médiastino-pulmonaire', 'Complications et surveillance de la corticothérapie'],
    ),
    ExternatModuleInfo(
      id: 'Blida_MEDECINE_LEGALE',
      name: 'Médecine légale',
      studyYear: 6,
      durationWeeks: 3,
      rotationType: 'Théorique & Pratique',
      focusSummary: 'Certificats médicaux légaux, Constat de décès et levée de corps, Coups et blessures volontaires (ITT), Responsabilité médicale pénale et civile.',
      defaultEmdQuestions: 35,
      emdDurationMinutes: 45,
      highYieldTopics: ['Rédaction d\'un certificat de coups et blessures avec ITT', 'Signes précoces et tardifs de la mort', 'Secret médical et ses dérogations légales', 'Éléments de responsabilité médicale'],
    ),
    ExternatModuleInfo(
      id: 'Blida_SANTE_AU_TRAVAIL_ET_ENVIRONNEMENT',
      name: 'Sante au travail et environnement',
      studyYear: 6,
      durationWeeks: 3,
      rotationType: 'Théorique & Visites',
      focusSummary: 'Maladies professionnelles indemnisables, Tableaux de réparation algériens, Accidents du travail, Risques chimiques (plomb, solvants), Silicose et amiante.',
      defaultEmdQuestions: 35,
      emdDurationMinutes: 45,
      highYieldTopics: ['Procédure de déclaration d\'une maladie professionnelle en Algérie', 'Pneumoconioses (Silicose et asbestose)', 'Saturnisme professionnel', 'Aptitude médicale au poste de travail'],
    ),
    ExternatModuleInfo(
      id: 'Blida_EPIDEMIOLOGIE',
      name: 'Epidémiologie',
      studyYear: 6,
      durationWeeks: 3,
      rotationType: 'Théorique',
      focusSummary: 'Types d\'études épidémiologiques (cohorte, cas-témoins, transversales), Mesures d\'association (RR, OR), Dépistage et sensibilité/spécificité, Enquêtes épidémiques.',
      defaultEmdQuestions: 35,
      emdDurationMinutes: 45,
      highYieldTopics: ['Calculs de Risque Relatif et Odds Ratio', 'Sensibilité, Spécificité, VPP et VPN d\'un test de dépistage', 'Investigation d\'une toxi-infection alimentaire collective (TIAC)', 'Biais et facteurs de confusion'],
    ),
    ExternatModuleInfo(
      id: 'Blida_GERIATRIE',
      name: 'Geriatrie',
      studyYear: 6,
      durationWeeks: 2,
      rotationType: 'Stage & Théorique',
      focusSummary: 'Fragilité du sujet âgé, Chutes répétées, Syndromes démentiels (Alzheimer), Syndrome confusionnel aigu, Dénutrition protéino-énergétique.',
      defaultEmdQuestions: 30,
      emdDurationMinutes: 40,
      highYieldTopics: ['Diagnostic étiologique d\'un syndrome confusionnel aigu', 'Évaluation de la fragilité et de l\'autonomie (ADL/IADL)', 'Iatrogénie médicamenteuse chez le sujet âgé', 'Prévention des escarres et de la dénutrition'],
    ),
  ];

  /// Find duration and module info by name or id
  static ExternatModuleInfo? findModuleInfo(String query, int? year) {
    final q = query.toLowerCase().trim();
    for (final m in modulesData) {
      if (year != null && m.studyYear != year) continue;
      if (m.id.toLowerCase() == q || m.name.toLowerCase().contains(q) || q.contains(m.name.toLowerCase())) {
        return m;
      }
    }
    // Fallback search ignoring year
    for (final m in modulesData) {
      if (m.name.toLowerCase().contains(q) || q.contains(m.name.toLowerCase())) {
        return m;
      }
    }
    return null;
  }

  /// Get all registered modules for a given year
  static List<ExternatModuleInfo> getModulesForYear(int year) {
    return modulesData.where((m) => m.studyYear == year).toList();
  }
}

