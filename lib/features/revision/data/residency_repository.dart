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

  /// Loads official questions specifically for the selected course.
  /// 1. Tries Supabase if live questions exist.
  /// 2. Loads bundled JSON asset for that module from `assets/data/qcms/<module_id>.json`.
  /// 3. Filters exclusively for the specified course.
  static Future<List<QcmQuestion>> getQuestionsForCourseAsync(CourseModel course) async {
    // 1. Try fetching live from Supabase
    try {
      final supaData = await SupabaseService.fetchCourseQuestions(course.id);
      if (supaData.isNotEmpty) {
        return supaData.map((q) => QcmQuestion.fromJson(q)).toList();
      }
    } catch (_) {}

    // 2. Load from local bundled module JSON
    final safeModId = _sanitizeModuleId(course.moduleId);
    List<QcmQuestion>? modQuestions = _moduleQuestionsCache[safeModId];

    if (modQuestions == null) {
      try {
        final path = 'assets/data/qcms/$safeModId.json';
        final jsonStr = await rootBundle.loadString(path);
        final list = jsonDecode(jsonStr) as List<dynamic>;
        modQuestions = list.map((item) => QcmQuestion.fromJson(item as Map<String, dynamic>)).toList();
        _moduleQuestionsCache[safeModId] = modQuestions;
      } catch (e) {
        // Fallback: search in any other loaded or common module caches
        modQuestions = [];
      }
    }

    // 3. Match questions by exact course.id
    final byId = modQuestions.where((q) => q.courseId == course.id).toList();
    if (byId.isNotEmpty) return byId;

    // 4. Match questions by normalized course title
    final targetNorm = _normalize(course.name);
    final byName = modQuestions.where((q) => _normalize(q.courseName) == targetNorm).toList();
    if (byName.isNotEmpty) return byName;

    // 5. Match by substring / keyword containment
    final byFuzzy = modQuestions.where((q) {
      final qNorm = _normalize(q.courseName);
      if (qNorm.isEmpty || targetNorm.isEmpty) return false;
      return qNorm.contains(targetNorm) || targetNorm.contains(qNorm);
    }).toList();
    if (byFuzzy.isNotEmpty) return byFuzzy;

    return [];
  }

  /// Synchronous fallback helper for course questions
  static List<QcmQuestion> getQuestionsForCourse(String courseId) {
    for (final list in _moduleQuestionsCache.values) {
      final match = list.where((q) => q.courseId == courseId).toList();
      if (match.isNotEmpty) return match;
    }
    return [];
  }

  /// Loads and aggregates questions across multiple courses & modules for custom revision sessions.
  static Future<List<QcmQuestion>> getQuestionsForMultipleCoursesAsync({
    required List<String> courseIds,
    required List<String> moduleIds,
    int limit = -1,
    bool shuffle = true,
  }) async {
    final allQuestions = <QcmQuestion>[];
    final courseIdSet = courseIds.toSet();

    for (final modId in moduleIds.toSet()) {
      final safeModId = _sanitizeModuleId(modId);
      List<QcmQuestion>? modQuestions = _moduleQuestionsCache[safeModId];

      if (modQuestions == null) {
        try {
          final path = 'assets/data/qcms/$safeModId.json';
          final jsonStr = await rootBundle.loadString(path);
          final list = jsonDecode(jsonStr) as List<dynamic>;
          modQuestions = list.map((item) => QcmQuestion.fromJson(item as Map<String, dynamic>)).toList();
          _moduleQuestionsCache[safeModId] = modQuestions;
        } catch (_) {
          modQuestions = [];
        }
      }

      if (courseIdSet.isEmpty) {
        allQuestions.addAll(modQuestions);
      } else {
        allQuestions.addAll(modQuestions.where((q) => courseIdSet.contains(q.courseId)));
      }
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
}

