import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/supabase_service.dart';
import '../../../core/services/gemini_service.dart';
import '../models/course_summary_model.dart';
import '../models/module_model.dart';

class CourseSummaryRepository {
  static final Map<String, CourseSummaryModel> _cache = {};
  static final Set<String> _knownSummaryIds = {};
  static bool _hasLoadedLocal = false;

  /// Synchronous check whether a course has a summary
  static bool hasSummarySync(String courseId) {
    if (_cache.containsKey(courseId)) return true;
    if (_knownSummaryIds.contains(courseId)) return true;
    return false;
  }

  /// Loads all available course summaries, prioritizing Supabase Cloud with fallback to local JSON.
  static Future<Map<String, CourseSummaryModel>> loadAllSummariesAsync({
    bool forceRefresh = false,
  }) async {
    if (_cache.isNotEmpty && !forceRefresh) {
      return _cache;
    }

    // 1. Load bundled local JSON asset first
    if (!_hasLoadedLocal || forceRefresh) {
      try {
        final jsonStr = await rootBundle.loadString('assets/data/course_summaries.json');
        final list = jsonDecode(jsonStr) as List<dynamic>;
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            final model = CourseSummaryModel.fromJson(item);
            _cache[model.courseId] = model;
            _knownSummaryIds.add(model.courseId);
          }
        }
        _hasLoadedLocal = true;
      } catch (e) {
        debugPrint('Notice: Local course_summaries.json not found or empty: $e');
      }
    }

    // 2. Fetch latest live from Supabase Cloud
    try {
      final remoteRows = await SupabaseService.fetchCourseSummaries();
      for (final row in remoteRows) {
        final model = CourseSummaryModel.fromJson(row);
        _cache[model.courseId] = model;
        _knownSummaryIds.add(model.courseId);
      }
    } catch (e) {
      debugPrint('Notice: Supabase course_summaries fetch failed: $e');
    }

    return _cache;
  }

  /// Retrieves summary for a specific course ID
  static Future<CourseSummaryModel?> getSummaryForCourse(
    String courseId, {
    CourseModel? course,
    String? moduleName,
  }) async {
    if (_cache.containsKey(courseId)) {
      return _cache[courseId];
    }

    // 1. Try fetching single from Supabase
    try {
      final row = await SupabaseService.fetchCourseSummary(courseId);
      if (row != null) {
        final model = CourseSummaryModel.fromJson(row);
        _cache[courseId] = model;
        return model;
      }
    } catch (_) {}

    // 2. Try fetching from local SharedPreferences cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final localJson = prefs.getString('cached_summary_$courseId');
      if (localJson != null && localJson.isNotEmpty) {
        final map = jsonDecode(localJson) as Map<String, dynamic>;
        final model = CourseSummaryModel.fromJson(map);
        _cache[courseId] = model;
        return model;
      }
    } catch (_) {}

    // 3. Fall back to loading all from JSON asset
    await loadAllSummariesAsync();
    return _cache[courseId];
  }

  /// Generates a summary via Medsina AI, saves to Cache & Supabase, and returns the model
  static Future<CourseSummaryModel?> generateAndSaveSummary({
    required CourseModel course,
    String? moduleName,
  }) async {
    try {
      final json = await GeminiService.generateCourseSummary(
        courseName: course.name,
        moduleName: moduleName ?? 'Médecine',
        courseId: course.id,
        moduleId: course.moduleId,
      );

      if (json != null) {
        final model = CourseSummaryModel.fromJson(json);
        // 1. Save in memory cache
        _cache[course.id] = model;

        // 2. Persist to Supabase Cloud so all users and future sessions have it
        try {
          await SupabaseService.upsertCourseSummary(model.toJson());
        } catch (e) {
          debugPrint('Notice: Error syncing generated summary to Supabase: $e');
        }

        // 3. Persist locally to SharedPreferences for offline reading
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_summary_${course.id}', jsonEncode(model.toJson()));
        } catch (_) {}

        return model;
      }
    } catch (e) {
      debugPrint('Error generating course summary with AI: $e');
    }
    return null;
  }

  /// Synchronous cache lookup
  static CourseSummaryModel? getCachedSummary(String courseId) {
    return _cache[courseId];
  }
}

