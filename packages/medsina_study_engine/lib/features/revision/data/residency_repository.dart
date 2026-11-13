import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:medsina_core/core/network/supabase_service.dart';
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

  static final Map<String, List<QcmQuestion>> _moduleQuestionsCache = {};

  static String _sanitizeModuleId(String id) {
    return id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }

  static String _normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[àáâãäå]'), 'a')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[òóôõö]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  /// Loads official questions specifically for the selected course from Supabase Cloud.
  /// Enforces server-side Row Level Security (RLS) rules based on user subscription & study year.
  static Future<List<QcmQuestion>> getQuestionsForCourseAsync(CourseModel course) async {
    final safeModId = _sanitizeModuleId(course.moduleId);

    // 1. Check in-memory session cache first for fast repeat access
    final cached = _moduleQuestionsCache[safeModId];
    if (cached != null && cached.isNotEmpty) {
      final byId = cached.where((q) => q.courseId == course.id).toList();
      if (byId.isNotEmpty) return byId;

      final targetNorm = _normalize(course.name);
      final byName = cached.where((q) => _normalize(q.courseName) == targetNorm).toList();
      if (byName.isNotEmpty) return byName;
    }

    // 2. Fetch live questions from Supabase Cloud (RLS protected)
    try {
      final supaData = await SupabaseService.fetchCourseQuestions(course.id);
      if (supaData.isNotEmpty) {
        final questions = supaData.map((q) => QcmQuestion.fromJson(q)).toList();
        
        // Cache questions in session memory
        final list = _moduleQuestionsCache.putIfAbsent(safeModId, () => []);
        for (final q in questions) {
          if (!list.any((existing) => existing.id == q.id)) {
            list.add(q);
          }
        }
        return questions;
      }
    } catch (e) {
      debugPrint('[ResidencyRepository] Error fetching course questions from Supabase: $e');
    }

    return [];
  }

  /// Synchronous fallback helper for course questions from memory cache
  static List<QcmQuestion> getQuestionsForCourse(String courseId) {
    for (final list in _moduleQuestionsCache.values) {
      final match = list.where((q) => q.courseId == courseId).toList();
      if (match.isNotEmpty) return match;
    }
    return [];
  }

  /// Loads and aggregates questions across multiple courses & modules from Supabase Cloud.
  /// Server-side RLS guarantees that only entitled questions (unlocked study year or free sample) are returned.
  static Future<List<QcmQuestion>> getQuestionsForMultipleCoursesAsync({
    required List<String> courseIds,
    required List<String> moduleIds,
    int limit = -1,
    bool shuffle = true,
    List<String>? allowedTypes,
  }) async {
    final allQuestions = <QcmQuestion>[];

    try {
      final supaData = await SupabaseService.fetchQuestionsForModules(
        moduleIds: moduleIds,
        courseIds: courseIds.isNotEmpty ? courseIds : null,
        limit: limit > 0 ? limit * 2 : -1,
      );

      if (supaData.isNotEmpty) {
        for (final raw in supaData) {
          final q = QcmQuestion.fromJson(raw);

          // Exclure les questions sans propositions (ex: QROCs sans choix)
          if (q.options.isEmpty) continue;

          // Filtrer selon les types autorisés (ex: qcs, qcm, casClinique)
          if (allowedTypes != null && allowedTypes.isNotEmpty) {
            final typeName = q.type.name.toLowerCase();
            final matchesType = allowedTypes.any((at) {
              final normAt = at.toLowerCase();
              return normAt == typeName || (normAt == 'casclinique' && typeName == 'casclinique');
            });
            if (!matchesType) continue;
          }

          allQuestions.add(q);
        }
      }
    } catch (e) {
      debugPrint('[ResidencyRepository] Error loading multiple questions from Supabase: $e');
    }

    if (shuffle) {
      allQuestions.shuffle();
    }

    if (limit > 0 && allQuestions.length > limit) {
      return allQuestions.take(limit).toList();
    }

    return allQuestions;
  }

  /// Finds a CourseModel by ID across all loaded modules
  static Future<CourseModel?> findCourseById(String courseId) async {
    final modules = await loadModulesAsync();
    for (final m in modules) {
      for (final c in m.courses) {
        if (c.id == courseId) return c;
      }
    }
    return null;
  }

  /// Finds the MedicalModuleModel containing a given courseId
  static Future<MedicalModuleModel?> findModuleForCourse(String courseId) async {
    final modules = await loadModulesAsync();
    for (final m in modules) {
      if (m.courses.any((c) => c.id == courseId)) return m;
    }
    return null;
  }

  /// Finds a CourseModel by ID or fuzzy name match across all modules
  static Future<CourseModel?> findCourseByNameOrId(String query) async {
    final modules = await loadModulesAsync();
    final cleanQuery = _normalize(query);
    if (cleanQuery.isEmpty) return null;

    // 1. Exact ID
    for (final m in modules) {
      for (final c in m.courses) {
        if (c.id.toLowerCase() == query.toLowerCase()) return c;
      }
    }

    // 2. Exact normalized name
    for (final m in modules) {
      for (final c in m.courses) {
        if (_normalize(c.name) == cleanQuery) return c;
      }
    }

    // 3. Substring containment
    for (final m in modules) {
      for (final c in m.courses) {
        final cNorm = _normalize(c.name);
        if (cNorm.contains(cleanQuery) || cleanQuery.contains(cNorm)) {
          return c;
        }
      }
    }

    return null;
  }

  /// Returns the academic medical year (1 to 6) associated with a given module
  static int getYearForModule(MedicalModuleModel module) {
    final cat = module.category.toLowerCase();
    final name = module.name.toLowerCase();

    if (cat.contains('1ère') || cat.contains('1 ere') || cat.contains('1er') || name.contains('(1 ère)') || name.contains('(1ère)')) {
      return 1;
    }
    if (cat.contains('2ème') || cat.contains('2 eme') || cat.contains('2e') || name.contains('(2 ère)') || name.contains('(2ème)') || name.contains('(2 ème)')) {
      return 2;
    }
    if (cat.contains('3ème') || cat.contains('3 eme') || cat.contains('3e') || name.contains('(3 ère)') || name.contains('(3ème)') || name.contains('(3 ème)')) {
      return 3;
    }

    // 4ème Année: Pathologies Majeures (Cardio, Pneumo, Gastro, Neuro, Infectieux, Hemato)
    if (name.contains('cardio') ||
        name.contains('pneumo') ||
        name.contains('gastro') ||
        name.contains('neuro') ||
        name.contains('infectie') ||
        name.contains('hemato') ||
        name.contains('hémato')) {
      return 4;
    }

    // 5ème Année: Pédiatrie, Gynéco, Locomoteur, Néphro, Endocrino, Psy
    if (name.contains('pédiatr') ||
        name.contains('pediatr') ||
        name.contains('gyneco') ||
        name.contains('gynéco') ||
        name.contains('locomoteur') ||
        name.contains('uro') ||
        name.contains('néphro') ||
        name.contains('nephro') ||
        name.contains('endocrin') ||
        name.contains('psychiatr')) {
      return 5;
    }

    // 6ème Année: Spécialités & Urgences & Médecine Légale/Travail
    if (name.contains('dermat') ||
        name.contains('orl') ||
        name.contains('ophtalm') ||
        name.contains('épidémio') ||
        name.contains('epidemio') ||
        name.contains('légale') ||
        name.contains('legale') ||
        name.contains('travail') ||
        name.contains('système') ||
        name.contains('systeme') ||
        name.contains('urgence') ||
        name.contains('umc') ||
        name.contains('gériatr') ||
        name.contains('geriatr')) {
      return 6;
    }

    // Default to 4th year if clinical
    return 4;
  }

  /// Filters modules specifically for a medical student's study year (1 to 6)
  static List<MedicalModuleModel> filterModulesForStudent(List<MedicalModuleModel> allModules, int studyYear) {
    return allModules.where((m) => getYearForModule(m) == studyYear).toList();
  }

  /// Label for an academic year
  static String getYearTitle(int year) {
    switch (year) {
      case 1:
        return '1ère Année (Sciences Fondamentales I)';
      case 2:
        return '2ème Année (Sciences Fondamentales II)';
      case 3:
        return '3ème Année (Pré-clinique & Sémiologie)';
      case 4:
        return '4ème Année (Externat - Pathologie I)';
      case 5:
        return '5ème Année (Externat - Pathologie II)';
      case 6:
        return '6ème Année (Externat - Thérapeutique & Spécialités)';
      default:
        return 'e Année de Médecine';
    }
  }

  /// Determines if a question is exclusively from a residanat competition
  static bool isResidencyContestQuestion(QcmQuestion question) {
    final src = question.source.toLowerCase();
    return src.contains('résidanat') ||
        src.contains('residanat') ||
        src.contains('concours') ||
        src.contains('national');
  }

  /// Filters out residency contest questions for student mode, keeping faculty/EMD/exams
  static List<QcmQuestion> filterQuestionsForStudent(List<QcmQuestion> questions, {bool allowAllIfEmpty = true}) {
    final filtered = questions.where((q) => !isResidencyContestQuestion(q)).toList();
    if (filtered.isEmpty && allowAllIfEmpty) {
      return questions;
    }
    return filtered;
  }
}
