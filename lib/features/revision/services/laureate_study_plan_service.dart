import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/laureate_study_plan_model.dart';
import '../../../core/services/medsina_notification_dispatcher.dart';

/// Progress and tracking state for an active study plan adopted by the candidate
class UserStudyPlanProgress {
  final String planId;
  final DateTime enrolledAt;
  final DateTime targetExamDate;
  int completedCoursesCount;
  int completedQcmsCount;
  bool remindersEnabled;
  int reminderHour;
  int reminderMinute;
  String lastActiveDateIso;
  List<String> todayCompletedCourseIds;
  int todayCompletedQcms;

  UserStudyPlanProgress({
    required this.planId,
    required this.enrolledAt,
    required this.targetExamDate,
    this.completedCoursesCount = 0,
    this.completedQcmsCount = 0,
    this.remindersEnabled = true,
    this.reminderHour = 20,
    this.reminderMinute = 0,
    required this.lastActiveDateIso,
    List<String>? todayCompletedCourseIds,
    this.todayCompletedQcms = 0,
  }) : todayCompletedCourseIds = todayCompletedCourseIds ?? [];

  Map<String, dynamic> toJson() => {
        'planId': planId,
        'enrolledAt': enrolledAt.toIso8601String(),
        'targetExamDate': targetExamDate.toIso8601String(),
        'completedCoursesCount': completedCoursesCount,
        'completedQcmsCount': completedQcmsCount,
        'remindersEnabled': remindersEnabled,
        'reminderHour': reminderHour,
        'reminderMinute': reminderMinute,
        'lastActiveDateIso': lastActiveDateIso,
        'todayCompletedCourseIds': todayCompletedCourseIds,
        'todayCompletedQcms': todayCompletedQcms,
      };

  factory UserStudyPlanProgress.fromJson(Map<String, dynamic> json) {
    return UserStudyPlanProgress(
      planId: json['planId'] as String? ?? 'plan_benouarab_internat',
      enrolledAt: DateTime.tryParse(json['enrolledAt'] as String? ?? '') ??
          DateTime.now(),
      targetExamDate:
          DateTime.tryParse(json['targetExamDate'] as String? ?? '') ??
              DateTime(2027, 10, 20),
      completedCoursesCount: json['completedCoursesCount'] as int? ?? 0,
      completedQcmsCount: json['completedQcmsCount'] as int? ?? 0,
      remindersEnabled: json['remindersEnabled'] as bool? ?? true,
      reminderHour: json['reminderHour'] as int? ?? 20,
      reminderMinute: json['reminderMinute'] as int? ?? 0,
      lastActiveDateIso: json['lastActiveDateIso'] as String? ?? '',
      todayCompletedCourseIds:
          (json['todayCompletedCourseIds'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList(),
      todayCompletedQcms: json['todayCompletedQcms'] as int? ?? 0,
    );
  }
}

/// Service managing the curated Laureate Study Plans and user's chosen revision trajectory
class LaureateStudyPlanService extends ChangeNotifier {
  static final LaureateStudyPlanService instance =
      LaureateStudyPlanService._internal();
  LaureateStudyPlanService._internal();

  static const String _prefStorageKey = 'medsina_active_study_plan_progress_v1';
  bool _initialized = false;
  UserStudyPlanProgress? _activeProgress;

  UserStudyPlanProgress? get activeProgress => _activeProgress;
  bool get hasActivePlan => _activeProgress != null;

  /// 4 Curated Laureate Study Plans extracted directly from `assets/data/temoignages_conseils.json`
  static final List<LaureateStudyPlanModel> defaultPlans = [
    const LaureateStudyPlanModel(
      id: 'plan_benouarab_internat',
      laureateId: 'temoignage_benouarab_2026',
      laureateName: 'Dr Benouarab Ikram',
      rankBadge: 'TOP 04 • BLIDA 2026 🏆',
      faculty: 'Faculté de Médecine de Blida',
      strategyTitle: 'Mega-Révision Internat & Support Unique',
      strategyTagline:
          'Réussir son résidanat sans année préparatoire en optimisant le temps d\'internat et en saturant les annales classées.',
      targetAudience:
          'Internes en cours de 7ème année, candidats avec gardes et temps limité.',
      totalWeeks: 36,
      recommendedDailyHours: 6,
      targetDailyCourses: 2,
      targetDailyQcms: 35,
      layersCount: 3,
      accentColorHex: '#0D9488', // Teal
      keyPrinciples: [
        'Le résidanat est un rizk : personne ne peut prédire son classement, trouvez votre propre rythme et écoutez-vous.',
        'Réviser sans année préparatoire est possible en optimisant le temps d\'internat et en privilégiant la compréhension active.',
        'Fixer une seule source de référence par cours, puis l\'enrichir systématiquement des pièges et notions récurrentes tirées des QCMs.',
        'Compréhension active et association rapide cours-annales le même jour.',
      ],
      recommendedSources:
          'Mega-Drive Benouarab, Résumés Dr Mégateli & Dr Ferhat & Dr Zarota, Supports officiels Faculté de Blida, Annales classées.',
      phases: [
        StudyPlanPhase(
          phaseIndex: 1,
          name: 'Couche 1 : Compréhension Active & Fixation du Support Unique',
          durationWeeks: 18,
          description:
              'Balayer l\'ensemble du programme en fixant un support unique et annotant les pièges des annales.',
          focusModules: ['Cardiologie', 'Neurologie', 'Gastro-entérologie', 'Pédiatrie', 'Biologie Fondamentale'],
          targetWeeklyCourses: 12,
          targetWeeklyQcms: 200,
        ),
        StudyPlanPhase(
          phaseIndex: 2,
          name: 'Couche 2 : Consolidation & Surcharge QCMs Annales',
          durationWeeks: 12,
          description:
              'Deuxième passage beaucoup plus rapide axé sur la rétention et les questions d\'annales 2015-2026.',
          focusModules: ['Tous les modules cliniques', 'Pathologies infectieuses', 'Urgences Médico-Chirurgicales'],
          targetWeeklyCourses: 15,
          targetWeeklyQcms: 300,
        ),
        StudyPlanPhase(
          phaseIndex: 3,
          name: 'Couche 3 : Rush Final & Cahier de Pièges',
          durationWeeks: 6,
          description:
              'Dernier tour ultra-ciblé sur les fiches réflexes, posologies, et perles récurrentes.',
          focusModules: ['Fiches réflexes', 'Scores pronostiques', 'Petits modules à fort coef'],
          targetWeeklyCourses: 20,
          targetWeeklyQcms: 400,
        ),
      ],
      dailyQuotes: [
        '« Le résidanat est un rizk : personne ne peut prédire son classement, trouvez votre propre rythme et écoutez-vous ! »',
        '« Ne multipliez pas les sources : une source unique maîtrisée à 100% vaut dix livres survolés. »',
        '« Chaque heure d\'internat bien négociée est une heure de sommeil et de confiance gagnée pour le concours. »',
        '« Le secret réside dans la constance : 2 cours et 35 QCMs chaque jour battent n\'importe quel sprint désordonné. »',
      ],
    ),
    const LaureateStudyPlanModel(
      id: 'plan_djellata_resilience',
      laureateId: 'temoignage_djellata_youssra_2026',
      laureateName: 'Dr Djellata Youssra',
      rankBadge: 'TOP 09 • OPHTALMOLOGIE 2026 🏆',
      faculty: 'Faculté de Médecine de Blida • Ophtalmologie',
      strategyTitle: 'Résilience, Foi & 4 Couches Méthodiques',
      strategyTagline:
          'De 236ème (démissionnaire) à la 9ème place : discipline de fer, Scopio/Fennec et mental d\'acier.',
      targetAudience:
          'Candidats retentant le concours, candidats en quête d\'une spécialité très sélective (Ophtalmo, Radio, Dermato).',
      totalWeeks: 38,
      recommendedDailyHours: 8,
      targetDailyCourses: 3,
      targetDailyQcms: 50,
      layersCount: 4,
      accentColorHex: '#8B5CF6', // Purple
      keyPrinciples: [
        'Résilience et foi absolue (« أَنْتُم مَعَ رَبِّ المُسْتَحِيلَاتِ ») : Ne laissez personne briser vos rêves avec des "Connais tes limites".',
        'Flexibilité du planning face aux imprévus : soyez souple et réajustez au lieu de paniquer.',
        'Entourage positif & bienveillant : éliminez impérativement les ondes négatives.',
        'Saturation de QCMs (Scopio + Fennec) et lecture assidue des commentaires de confrères.',
        'Appuyez-vous sur les résumés éprouvés (Dr Dilmi, formations Zeemed, Dr Megateli) plutôt que réinventer la roue.',
      ],
      recommendedSources:
          'Scopio & Fennec, Résumés Dr Dilmi (Bioch/Cardio), Formations Zeemed (Immuno/Anapath), Dr Megateli (Parasito), Cours externat 2026.',
      phases: [
        StudyPlanPhase(
          phaseIndex: 1,
          name: 'Couche 1 : Socle Solide & Résumés Éprouvés',
          durationWeeks: 14,
          description:
              'Compréhension en profondeur en utilisant les résumés de référence et démarrage immédiat des QCMs.',
          focusModules: ['Biochimie', 'Cardiologie', 'Immunologie', 'Gastro-entérologie'],
          targetWeeklyCourses: 15,
          targetWeeklyQcms: 300,
        ),
        StudyPlanPhase(
          phaseIndex: 2,
          name: 'Couche 2 : Deuxième Passage & Analyse Fine des QCMs',
          durationWeeks: 10,
          description:
              'Révision intégrée et décorticage des commentaires des confrères sur Scopio et Fennec.',
          focusModules: ['Pneumologie', 'Pédiatrie', 'Gynéco-Obstétrique', 'Neurologie'],
          targetWeeklyCourses: 18,
          targetWeeklyQcms: 350,
        ),
        StudyPlanPhase(
          phaseIndex: 3,
          name: 'Couche 3 : Vitesse & Samedis Pédagogiques',
          durationWeeks: 8,
          description:
              'Synthèse rapide et cas cliniques des Samedis Pédagogiques.',
          focusModules: ['Dermatologie', 'Infectieux', 'Hématologie', 'Néphrologie'],
          targetWeeklyCourses: 20,
          targetWeeklyQcms: 400,
        ),
        StudyPlanPhase(
          phaseIndex: 4,
          name: 'Couche 4 : Rush Ultra-Rapide & Perles Finales',
          durationWeeks: 6,
          description:
              'Relecture des fiches synthétiques et perles de dernière minute.',
          focusModules: ['Mises à jour thérapeutiques 2026', 'Scores et arbres décisionnels', 'Tableaux comparatifs'],
          targetWeeklyCourses: 25,
          targetWeeklyQcms: 500,
        ),
      ],
      dailyQuotes: [
        '« أَنْتُم مَعَ رَبِّ المُسْتَحِيلَاتِ : Ne laissez personne briser vos rêves avec des "Connais tes limites". »',
        '« Not everything is gonna work as planned, you just need to adjust and keep going ! »',
        '« N\'oubliez pas qu\'il n\'y a pas que la médecine dans la vie : souriez, respirez, et gardez votre paix intérieure. »',
        '« La persévérance transforme l\'obstacle d\'hier en la victoire de demain. »',
      ],
    ),
    const LaureateStudyPlanModel(
      id: 'plan_barrag_progressive',
      laureateId: 'temoignage_barrag_belkis_2026',
      laureateName: 'Dr BARRAG Belkis',
      rankBadge: 'TOP 18 • CARDIOLOGIE 2026 🏆',
      faculty: 'Faculté de Médecine de Blida • Cardiologie',
      strategyTitle: 'Internat Lourd, Gardes UMC & Montée Progressive',
      strategyTagline:
          'Montée en puissance de 3h à 12h/j : fiches réflexes dès la couche 1, clinique de terrain, Histo/Génétique et IA.',
      targetAudience:
          'Candidats avec stages très prenants (UMC, Réa, Pédiatrie) cherchant une cadence progressive et réaliste.',
      totalWeeks: 36,
      recommendedDailyHours: 7,
      targetDailyCourses: 2,
      targetDailyQcms: 30,
      layersCount: 3,
      accentColorHex: '#E11D48', // Crimson Rose
      keyPrinciples: [
        'Internat lourd : Il est tout à fait possible de majorer le concours malgré des gardes tous les 8 jours.',
        'S\'investir en stage clinique : Les urgences et conduites à tenir vues en pratique se retiennent 10 fois mieux.',
        'Créer ses résumés dès la couche 1 : Ne révisez pas sur des cours fleuves, vos fiches vous sauveront au rush final.',
        'Ne jamais négliger l\'histologie et la génétique qui tombent abondamment au concours.',
        'Exploiter l\'IA pour générer des tableaux comparatifs et des arbres décisionnels.',
      ],
      recommendedSources:
          'Biologie: Dr Zarouta & Dr Dilmi, Parasito Dr Megateli. Clinique: Réorganisations personnelles, Menacer (Ortho/Endocrino), QCMs UMC & Samedis Anato.',
      phases: [
        StudyPlanPhase(
          phaseIndex: 1,
          name: 'Phase Initiale : Démarrage Doux (3-4h/j) & Fiches Réflexes',
          durationWeeks: 16,
          description:
              'Prise de rythme progressive avec internat. Rédaction immédiate de fiches synthétiques couche 1.',
          focusModules: ['Histologie', 'Génétique', 'Cardiologie', 'Urgences Médico-Chirurgicales'],
          targetWeeklyCourses: 10,
          targetWeeklyQcms: 180,
        ),
        StudyPlanPhase(
          phaseIndex: 2,
          name: 'Phase Intermédiaire : Montée en Cadence (6-8h/j) & QCMs UMC',
          durationWeeks: 12,
          description:
              'Accélération du rythme, simulation de cas cliniques et ancrage des diagnostics différentiels.',
          focusModules: ['Pédiatrie', 'Gynécologie', 'Pneumologie', 'Endocrinologie'],
          targetWeeklyCourses: 14,
          targetWeeklyQcms: 250,
        ),
        StudyPlanPhase(
          phaseIndex: 3,
          name: 'Sprint Final : Hyper-Intensif (10-12h/j) & Tableaux Comparatifs IA',
          durationWeeks: 8,
          description:
              'Saturation maximale sur les résumés personnels, tableaux différentiels et pièges des annales.',
          focusModules: ['Tous les modules', 'Samedis Anato', 'Cas cliniques transversaux'],
          targetWeeklyCourses: 18,
          targetWeeklyQcms: 350,
        ),
      ],
      dailyQuotes: [
        '« La fatigue des gardes passe, la fierté d\'obtenir la spécialité de ses rêves reste pour la vie. »',
        '« Chaque urgence gérée en stage est un QCM réussi le jour du concours. »',
        '« Créez vos propres fiches dès la première couche : ce sont elles qui vous sauveront au sprint final. »',
        '« La régularité commence petit : 3 heures bien concentrées aujourd\'hui préparent les 12 heures de demain. »',
      ],
    ),
    const LaureateStudyPlanModel(
      id: 'plan_boutiouta_megateli_excellence',
      laureateId: 'temoignage_boutiouta_megateli',
      laureateName: 'Dr Boutiouta & Dr Megateli',
      rankBadge: 'MAJORS DE PROMO 🏆',
      faculty: 'Faculté de Médecine d\'Alger & Blida',
      strategyTitle: 'Major Absolue : Zéro Impasse & Biologie Décisive',
      strategyTagline:
          'Exhaustivité clinique + Biologie fondamentale qui fait le gap décisif au classement final.',
      targetAudience:
          'Candidats à temps plein visant le TOP 10 national et une maîtrise intégrale du programme.',
      totalWeeks: 40,
      recommendedDailyHours: 9,
      targetDailyCourses: 3,
      targetDailyQcms: 60,
      layersCount: 4,
      accentColorHex: '#2563EB', // Royal Blue
      keyPrinciples: [
        'C\'est la biologie fondamentale (Anatomie, Embryologie, Histologie, Génétique, Physiologie) qui fait le gap décisif au classement.',
        'Zéro impasse : les petits modules (Médecine Légale, Santé Publique, Droit Médical) rapportent les points qui manquent aux autres.',
        'Répétition espacée rigoureuse et tests chronométrés hebdomadaires.',
        'Confrontation systématique aux dossiers des Samedis Pédagogiques.',
      ],
      recommendedSources:
          'Supports officiels Facultés, Résumés Dr Megateli, Fiches Dr Dilmi & Dr Zarouta, Banques de QCMs exhaustives.',
      phases: [
        StudyPlanPhase(
          phaseIndex: 1,
          name: 'Couche 1 : Fondations Biologiques Exhaustives',
          durationWeeks: 12,
          description:
              'Maîtrise approfondie des modules fondamentaux et anatomie chirurgicale.',
          focusModules: ['Anatomie', 'Physiologie', 'Histologie-Embryologie', 'Génétique', 'Immunologie'],
          targetWeeklyCourses: 15,
          targetWeeklyQcms: 300,
        ),
        StudyPlanPhase(
          phaseIndex: 2,
          name: 'Couche 2 : Grands Modules Cliniques & Thérapeutique',
          durationWeeks: 14,
          description:
              'Clinique lourde avec focus sur les physiopathologies et arbres décisionnels.',
          focusModules: ['Cardiologie', 'Neurologie', 'Gastro-Hépato', 'Pédiatrie', 'Pneumologie'],
          targetWeeklyCourses: 18,
          targetWeeklyQcms: 400,
        ),
        StudyPlanPhase(
          phaseIndex: 3,
          name: 'Couche 3 : Petits Modules Clés & Cas Cliniques Transversaux',
          durationWeeks: 8,
          description:
              'Zéro impasse : médecine légale, travail, épidémiologie et spécialités chirurgicales.',
          focusModules: ['Médecine Légale', 'Santé Publique', 'ORL', 'Ophtalmo', 'Orthopédie'],
          targetWeeklyCourses: 20,
          targetWeeklyQcms: 450,
        ),
        StudyPlanPhase(
          phaseIndex: 4,
          name: 'Couche 4 : Marathon QCMs Chronométrés & Simulation Concours',
          durationWeeks: 6,
          description:
              'Examens blancs hebdomadaires en conditions réelles et révision des scores.',
          focusModules: ['Examens blancs complets', 'Scores cliniques', 'Annales récentes 2020-2026'],
          targetWeeklyCourses: 25,
          targetWeeklyQcms: 550,
        ),
      ],
      dailyQuotes: [
        '« La biologie fondamentale est le filtre des majors : maîtrisez-la et vous dominerez le classement. »',
        '« Pas d\'impasse : le point d\'un QCM de droit médical a exactement la même valeur que celui de l\'infarctus du myocarde. »',
        '« La discipline est la seule passerelle entre vos ambitions et la réussite le jour J. »',
        '« Testez-vous en conditions réelles de temps : la rapidité de lecture est un muscle qui s\'entraîne. »',
      ],
    ),
  ];

  /// Initialize service and restore active progress from SharedPreferences
  Future<void> ensureInitialized() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefStorageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _activeProgress = UserStudyPlanProgress.fromJson(decoded);

        // Reset today's checklist if day has changed
        _checkDayRollover();
      }
    } catch (e) {
      debugPrint('LaureateStudyPlanService init error: $e');
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  /// Get the active Laureate plan model if enrolled
  LaureateStudyPlanModel? get activePlan {
    if (_activeProgress == null) return null;
    return getPlanById(_activeProgress!.planId);
  }

  /// Retrieve a plan by ID
  LaureateStudyPlanModel getPlanById(String planId) {
    return defaultPlans.firstWhere(
      (p) => p.id == planId,
      orElse: () => defaultPlans.first,
    );
  }

  /// Enroll or switch to a Laureate Study Plan
  Future<void> enrollInPlan({
    required String planId,
    DateTime? targetExamDate,
    int? reminderHour,
    int? reminderMinute,
  }) async {
    await ensureInitialized();
    final today = _todayIso();
    _activeProgress = UserStudyPlanProgress(
      planId: planId,
      enrolledAt: DateTime.now(),
      targetExamDate: targetExamDate ?? DateTime(2027, 10, 20),
      remindersEnabled: true,
      reminderHour: reminderHour ?? 20,
      reminderMinute: reminderMinute ?? 0,
      lastActiveDateIso: today,
      completedCoursesCount: _activeProgress?.completedCoursesCount ?? 0,
      completedQcmsCount: _activeProgress?.completedQcmsCount ?? 0,
      todayCompletedCourseIds: [],
      todayCompletedQcms: 0,
    );

    await _saveProgress();
    notifyListeners();
  }

  /// Mark a course completed for today
  Future<void> toggleTodayCourse(String courseId) async {
    if (_activeProgress == null) return;
    _checkDayRollover();

    final list = _activeProgress!.todayCompletedCourseIds;
    if (list.contains(courseId)) {
      list.remove(courseId);
      if (_activeProgress!.completedCoursesCount > 0) {
        _activeProgress!.completedCoursesCount--;
      }
    } else {
      list.add(courseId);
      _activeProgress!.completedCoursesCount++;
    }

    await _saveProgress();
    notifyListeners();
  }

  /// Increment today's QCM counter
  Future<void> addTodayQcms(int count) async {
    if (_activeProgress == null || count <= 0) return;
    _checkDayRollover();
    _activeProgress!.todayCompletedQcms += count;
    _activeProgress!.completedQcmsCount += count;
    await _saveProgress();
    notifyListeners();
  }

  /// Update the target exam deadline for the active plan
  Future<void> updateTargetExamDate(DateTime date) async {
    if (_activeProgress == null) return;
    _activeProgress = UserStudyPlanProgress(
      planId: _activeProgress!.planId,
      enrolledAt: _activeProgress!.enrolledAt,
      targetExamDate: date,
      completedCoursesCount: _activeProgress!.completedCoursesCount,
      completedQcmsCount: _activeProgress!.completedQcmsCount,
      remindersEnabled: _activeProgress!.remindersEnabled,
      reminderHour: _activeProgress!.reminderHour,
      reminderMinute: _activeProgress!.reminderMinute,
      lastActiveDateIso: _activeProgress!.lastActiveDateIso,
      todayCompletedCourseIds: _activeProgress!.todayCompletedCourseIds,
      todayCompletedQcms: _activeProgress!.todayCompletedQcms,
    );
    await _saveProgress();
    notifyListeners();
  }

  /// Update daily reminder settings
  Future<void> updateReminderSettings({
    required bool enabled,
    int? hour,
    int? minute,
  }) async {
    if (_activeProgress == null) return;
    _activeProgress!.remindersEnabled = enabled;
    if (hour != null) _activeProgress!.reminderHour = hour;
    if (minute != null) _activeProgress!.reminderMinute = minute;
    await _saveProgress();
    notifyListeners();
  }

  /// Get today's quote based on day of year
  String getTodayQuote() {
    final plan = activePlan ?? defaultPlans.first;
    if (plan.dailyQuotes.isEmpty) return 'La régularité est la clé de la réussite.';
    final dayIndex = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    return plan.dailyQuotes[dayIndex % plan.dailyQuotes.length];
  }

  /// Determine the current phase based on weeks elapsed since enrollment
  StudyPlanPhase? getCurrentPhase() {
    final plan = activePlan;
    if (plan == null || _activeProgress == null) return null;
    final weeksElapsed =
        (DateTime.now().difference(_activeProgress!.enrolledAt).inDays / 7).floor();

    int accumWeeks = 0;
    for (final phase in plan.phases) {
      accumWeeks += phase.durationWeeks;
      if (weeksElapsed < accumWeeks) {
        return phase;
      }
    }
    return plan.phases.isNotEmpty ? plan.phases.last : null;
  }

  /// Calculate percentage progress based on target weeks
  double calculateWeekProgress() {
    final plan = activePlan;
    if (plan == null || _activeProgress == null) return 0.0;
    final totalDays = plan.totalWeeks * 7;
    if (totalDays <= 0) return 0.0;
    final elapsedDays =
        DateTime.now().difference(_activeProgress!.enrolledAt).inDays;
    return (elapsedDays / totalDays).clamp(0.0, 1.0);
  }

  /// Reset or opt-out of active plan
  Future<void> leavePlan() async {
    _activeProgress = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefStorageKey);
    notifyListeners();
  }

  void _checkDayRollover() {
    if (_activeProgress == null) return;
    final today = _todayIso();
    if (_activeProgress!.lastActiveDateIso != today) {
      _activeProgress!.lastActiveDateIso = today;
      _activeProgress!.todayCompletedCourseIds.clear();
      _activeProgress!.todayCompletedQcms = 0;
    }
  }

  String _todayIso() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _saveProgress() async {
    if (_activeProgress == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefStorageKey, jsonEncode(_activeProgress!.toJson()));
    } catch (e) {
      debugPrint('Error saving study plan progress: $e');
    }
  }
}
