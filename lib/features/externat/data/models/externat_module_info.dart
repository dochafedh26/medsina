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
      name: 'Pr. Sarah Benali',
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
      name: 'Dr. Karim Mansouri',
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
      name: 'Dr. Amine Charef',
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
      name: 'Pr. Yassine Boudiaf',
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
      name: 'Pr. Meriem Khelifi',
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
      name: 'Dr. Reda Belkacem',
      academicTitle: 'Praticien Spécialiste aux UMC & Enseignant Thérapeutique',
      tagline: 'Objectif Internat & Résidanat : maîtriser l\'urgence vitale et l\'ordonnance parfaite.',
      avatarAsset: 'assets/images/doctor_avatar.png',
      themeColor: Color(0xFFE11D48),
      icon: Icons.emergency_rounded,
      competencies: ['Protocoles UMC', 'Ordonnances types', 'Médecine légale & Certificats', 'Médecine du travail'],
      pedagogicalStyle: 'Simulations de gardes réelles, gestion du stress, ordonnances complètes et justifications.',
    ),
  ];

  static ExternatTeacherPersona getTeacherForYear(int year) {
    return teachers.firstWhere(
      (t) => t.studyYear == year,
      orElse: () => teachers[3], // Default to 4th year
    );
  }

  /// Official durations of Algerian teaching modules
  static const List<ExternatModuleInfo> modulesData = [
    // 4ème Année
    ExternatModuleInfo(
      id: 'cardio',
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
      id: 'pneumo',
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
      id: 'gastro',
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
      id: 'neuro',
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
      id: 'infectieux',
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
      id: 'hemato',
      name: 'Hématologie Clinique',
      studyYear: 4,
      durationWeeks: 4,
      rotationType: 'Hospitalier',
      focusSummary: 'Anémies carentielles et hémolytiques, Leucémies aiguës et chroniques, Lymphomes (Hodgkin/LNH), Troubles de l\'hémostase.',
      defaultEmdQuestions: 40,
      emdDurationMinutes: 50,
      highYieldTopics: ['Anémies mégaloblastiques et ferriprives', 'Leucémies aiguës', 'Transfusion sanguine et sécurité', 'Purpuras et hémostase'],
    ),
    ExternatModuleInfo(
      id: 'ortho',
      name: 'Traumatologie - Orthopédie',
      studyYear: 4,
      durationWeeks: 4,
      rotationType: 'Hospitalier',
      focusSummary: 'Fractures des membres, Luxations, Polytraumatisés, Syndromes des loges, Infections ostéo-articulaires.',
      defaultEmdQuestions: 40,
      emdDurationMinutes: 50,
      highYieldTopics: ['Fractures de l\'extrémité supérieure du fémur', 'Syndrome de Volkmann et loges', 'Prise en charge du polytraumatisé', 'Luxations de l\'épaule'],
    ),

    // 5ème Année
    ExternatModuleInfo(
      id: 'pediatrie',
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
      id: 'gyneco',
      name: 'Gynécologie - Obstétrique',
      studyYear: 5,
      durationWeeks: 12,
      rotationType: 'Hospitalier (Trimestre)',
      focusSummary: 'Accouchement normal et dystocique, Hémorragies du 1er et 3ème trimestre, Pré-éclampsie, Cancers gynécologiques.',
      defaultEmdQuestions: 60,
      emdDurationMinutes: 90,
      highYieldTopics: ['Grossesse extra-utérine (GEU)', 'Pré-éclampsie et éclampsie', 'Hémorragie de la délivrance', 'Métrorragies post-ménopausiques'],
    ),
    ExternatModuleInfo(
      id: 'orl',
      name: 'ORL (Oto-Rhino-Laryngologie)',
      studyYear: 5,
      durationWeeks: 3,
      rotationType: 'Hospitalier (Court)',
      focusSummary: 'Otites moyennes aiguës et chroniques, Vertiges, Sinusites et complications, Cancers du cavum et du larynx, Dyspnée laryngée.',
      defaultEmdQuestions: 35,
      emdDurationMinutes: 45,
      highYieldTopics: ['Dyspnée laryngée aiguë de l\'enfant', 'Vertiges vestibulaires périphériques vs centraux', 'Cancer du nasopharynx (cavum)', 'Complications des otites'],
    ),
    ExternatModuleInfo(
      id: 'ophtalmo',
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
      id: 'dermato',
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
      id: 'rhumato',
      name: 'Rhumatologie',
      studyYear: 5,
      durationWeeks: 4,
      rotationType: 'Hospitalier',
      focusSummary: 'Polyarthrite rhumatoïde (PR), Spondyloarthrites (SPA), Arthrites microcristallines (Goutte), Arthrite septique, Lombalgies et sciatiques.',
      defaultEmdQuestions: 40,
      emdDurationMinutes: 50,
      highYieldTopics: ['Polyarthrite rhumatoïde (critères et bio-thérapies)', 'Arthrite septique aiguë (urgence)', 'Spondyloarthrite ankylosante', 'Goutte articulaire'],
    ),
    ExternatModuleInfo(
      id: 'uro_nephro',
      name: 'Urologie - Néphrologie',
      studyYear: 5,
      durationWeeks: 6,
      rotationType: 'Hospitalier',
      focusSummary: 'Insuffisance rénale aiguë (IRA) vs IRC, Syndromes néphrotiques et néphritiques, Colique néphrétique, Adénome et cancer de la prostate.',
      defaultEmdQuestions: 50,
      emdDurationMinutes: 60,
      highYieldTopics: ['Prise en charge de l\'IRA organique/fonctionnelle', 'Syndrome néphrotique impur/pur', 'Colique néphrétique compliquée', 'Hématuries microscopiques et macroscopiques'],
    ),
    ExternatModuleInfo(
      id: 'endocrino',
      name: 'Endocrinologie - Diabétologie',
      studyYear: 5,
      durationWeeks: 5,
      rotationType: 'Hospitalier',
      focusSummary: 'Diabète de type 1 et 2, Complications aiguës (Acidocétose, Coma hyperosmolaire), Hyperthyroïdies et hypothyroïdies, Insuffisance surrénalienne.',
      defaultEmdQuestions: 45,
      emdDurationMinutes: 55,
      highYieldTopics: ['Acidocétose diabétique et protocoles d\'insuline', 'Crise aiguë d\'insuffisance surrénale (urgence vitale)', 'Maladie de Basedow', 'Nodules thyroïdiens'],
    ),
    ExternatModuleInfo(
      id: 'psy',
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
      id: 'umc',
      name: 'Urgences Médico-Chirurgicales (UMC)',
      studyYear: 6,
      durationWeeks: 6,
      rotationType: 'Hospitalier (Garde & Réa)',
      focusSummary: 'Arrêt cardio-respiratoire (ACR), Chocs (cardiogénique, septique, anaphylactique, hypovolémique), Comas, Brûlures étendues, Intoxications aiguës.',
      defaultEmdQuestions: 50,
      emdDurationMinutes: 60,
      highYieldTopics: ['Algorithme de réanimation cardio-pulmonaire avancée', 'Prise en charge des 4 états de choc', 'Intoxications au monoxyde de carbone (CO)', 'Détresse respiratoire aiguë'],
    ),
    ExternatModuleInfo(
      id: 'therap',
      name: 'Thérapeutique & Pharmacologie Clinique',
      studyYear: 6,
      durationWeeks: 4,
      rotationType: 'Théorique & Stage',
      focusSummary: 'Règles de prescription, Ordonnances types de sortie, Interactions médicamenteuses majeures, Anticoagulants oraux, Douleur et antalgiques de palier 1-3.',
      defaultEmdQuestions: 40,
      emdDurationMinutes: 50,
      highYieldTopics: ['Ordonnance de sortie de l\'insuffisant cardiaque', 'Gestion des anticoagulants directs (AOD) et AVK', 'Prescription chez l\'insuffisant rénal et la femme enceinte', 'Surdosage médicamenteux'],
    ),
    ExternatModuleInfo(
      id: 'legale',
      name: 'Médecine Légale & Déontologie',
      studyYear: 6,
      durationWeeks: 3,
      rotationType: 'Théorique & Pratique',
      focusSummary: 'Certificats médicaux légaux, Constat de décès et levée de corps, Coups et blessures volontaires (ITT), Responsabilité médicale pénale et civile.',
      defaultEmdQuestions: 35,
      emdDurationMinutes: 45,
      highYieldTopics: ['Rédaction d\'un certificat de coups et blessures avec ITT', 'Signes précoces et tardifs de la mort', 'Secret médical et ses dérogations légales', 'Éléments de responsabilité médicale'],
    ),
    ExternatModuleInfo(
      id: 'travail',
      name: 'Médecine du Travail',
      studyYear: 6,
      durationWeeks: 3,
      rotationType: 'Théorique & Visites',
      focusSummary: 'Maladies professionnelles indemnisables, Tableaux de réparation algériens, Accidents du travail, Risques chimiques (plomb, solvants), Silicose et amiante.',
      defaultEmdQuestions: 35,
      emdDurationMinutes: 45,
      highYieldTopics: ['Procédure de déclaration d\'une maladie professionnelle en Algérie', 'Pneumoconioses (Silicose et asbestose)', 'Saturnisme professionnel', 'Aptitude médicale au poste de travail'],
    ),
    ExternatModuleInfo(
      id: 'epidemio',
      name: 'Épidémiologie & Santé Publique',
      studyYear: 6,
      durationWeeks: 3,
      rotationType: 'Théorique',
      focusSummary: 'Types d\'études épidémiologiques (cohorte, cas-témoins, transversales), Mesures d\'association (RR, OR), Dépistage et sensibilité/spécificité, Enquêtes épidémiques.',
      defaultEmdQuestions: 35,
      emdDurationMinutes: 45,
      highYieldTopics: ['Calculs de Risque Relatif et Odds Ratio', 'Sensibilité, Spécificité, VPP et VPN d\'un test de dépistage', 'Investigation d\'une toxi-infection alimentaire collective (TIAC)', 'Biais et facteurs de confusion'],
    ),
    ExternatModuleInfo(
      id: 'geriatrie',
      name: 'Gériatrie',
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
