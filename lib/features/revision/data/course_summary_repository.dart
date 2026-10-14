import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/network/supabase_service.dart';
import '../models/course_summary_model.dart';
import '../models/module_model.dart';

class CourseSummaryRepository {
  static final Map<String, CourseSummaryModel> _cache = {};
  static bool _hasLoadedLocal = false;

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

    // Try fetching single from Supabase
    try {
      final row = await SupabaseService.fetchCourseSummary(courseId);
      if (row != null) {
        final model = CourseSummaryModel.fromJson(row);
        _cache[courseId] = model;
        return model;
      }
    } catch (_) {}

    // Fall back to loading all from JSON
    await loadAllSummariesAsync();
    return _cache[courseId];
  }

  /// Synchronous cache lookup
  static CourseSummaryModel? getCachedSummary(String courseId) {
    return _cache[courseId];
  }
}
