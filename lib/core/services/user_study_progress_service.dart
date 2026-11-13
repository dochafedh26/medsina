import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../interfaces/feature_contracts.dart';
import '../network/supabase_service.dart';
import 'cloud_sync_service.dart';
import 'user_loyalty_service.dart';

/// Represents user study & revision progress metrics
class UserStudyProgress {
  final int totalQcmSolved;
  final int todayQcmSolved;
  final int totalCoursesCompleted;
  final int todayCoursesCompleted;
  final Set<String> completedCourseIds;
  final bool isTodayAccomplished;
  final int currentStreak;
  final int maxStreak;
  final Set<String> accomplishedDates; // YYYY-MM-DD
  final int dailyQcmGoal;
  final int dailyCourseGoal;
  final double averageAccuracy;
  final int totalExamsPassed;
  final Map<String, int> specialtyBreakdown; // Discipline -> QCM count

  const UserStudyProgress({
    required this.totalQcmSolved,
    required this.todayQcmSolved,
    required this.totalCoursesCompleted,
    required this.todayCoursesCompleted,
    required this.completedCourseIds,
    required this.isTodayAccomplished,
    required this.currentStreak,
    required this.maxStreak,
    required this.accomplishedDates,
    required this.dailyQcmGoal,
    required this.dailyCourseGoal,
    required this.averageAccuracy,
    required this.totalExamsPassed,
    required this.specialtyBreakdown,
  });

  factory UserStudyProgress.initial() {
    return const UserStudyProgress(
      totalQcmSolved: 0,
      todayQcmSolved: 0,
      totalCoursesCompleted: 0,
      todayCoursesCompleted: 0,
      completedCourseIds: {},
      isTodayAccomplished: false,
      currentStreak: 0,
      maxStreak: 0,
      accomplishedDates: {},
      dailyQcmGoal: 25,
      dailyCourseGoal: 1,
      averageAccuracy: 0.0,
      totalExamsPassed: 0,
      specialtyBreakdown: {},
    );
  }

  double get todayQcmProgress {
    if (dailyQcmGoal <= 0) return 1.0;
    return (todayQcmSolved / dailyQcmGoal).clamp(0.0, 1.0);
  }

  double get todayCourseProgress {
    if (dailyCourseGoal <= 0) return 1.0;
    return (todayCoursesCompleted / dailyCourseGoal).clamp(0.0, 1.0);
  }

  bool isDateAccomplished(DateTime date) {
    final str = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return accomplishedDates.contains(str);
  }

  UserStudyProgress copyWith({
    int? totalQcmSolved,
    int? todayQcmSolved,
    int? totalCoursesCompleted,
    int? todayCoursesCompleted,
    Set<String>? completedCourseIds,
    bool? isTodayAccomplished,
    int? currentStreak,
    int? maxStreak,
    Set<String>? accomplishedDates,
    int? dailyQcmGoal,
    int? dailyCourseGoal,
    double? averageAccuracy,
    int? totalExamsPassed,
    Map<String, int>? specialtyBreakdown,
  }) {
    return UserStudyProgress(
      totalQcmSolved: totalQcmSolved ?? this.totalQcmSolved,
      todayQcmSolved: todayQcmSolved ?? this.todayQcmSolved,
      totalCoursesCompleted: totalCoursesCompleted ?? this.totalCoursesCompleted,
      todayCoursesCompleted: todayCoursesCompleted ?? this.todayCoursesCompleted,
      completedCourseIds: completedCourseIds ?? this.completedCourseIds,
      isTodayAccomplished: isTodayAccomplished ?? this.isTodayAccomplished,
      currentStreak: currentStreak ?? this.currentStreak,
      maxStreak: maxStreak ?? this.maxStreak,
      accomplishedDates: accomplishedDates ?? this.accomplishedDates,
      dailyQcmGoal: dailyQcmGoal ?? this.dailyQcmGoal,
      dailyCourseGoal: dailyCourseGoal ?? this.dailyCourseGoal,
      averageAccuracy: averageAccuracy ?? this.averageAccuracy,
      totalExamsPassed: totalExamsPassed ?? this.totalExamsPassed,
      specialtyBreakdown: specialtyBreakdown ?? this.specialtyBreakdown,
    );
  }

  Map<String, dynamic> toJson() => {
        'totalQcmSolved': totalQcmSolved,
        'todayQcmSolved': todayQcmSolved,
        'totalCoursesCompleted': totalCoursesCompleted,
        'todayCoursesCompleted': todayCoursesCompleted,
        'completedCourseIds': completedCourseIds.toList(),
        'isTodayAccomplished': isTodayAccomplished,
        'currentStreak': currentStreak,
        'maxStreak': maxStreak,
        'accomplishedDates': accomplishedDates.toList(),
        'dailyQcmGoal': dailyQcmGoal,
        'dailyCourseGoal': dailyCourseGoal,
        'averageAccuracy': averageAccuracy,
        'totalExamsPassed': totalExamsPassed,
        'specialtyBreakdown': specialtyBreakdown,
      };

  factory UserStudyProgress.fromJson(Map<String, dynamic> json) {
    final completedCourses = (json['completedCourseIds'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toSet() ??
        <String>{};

    final accomplished = (json['accomplishedDates'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toSet() ??
        <String>{};

    final breakdownRaw = json['specialtyBreakdown'] as Map<String, dynamic>? ?? {};
    final breakdown = <String, int>{};
    breakdownRaw.forEach((k, v) {
      if (v is num) breakdown[k] = v.toInt();
    });

    return UserStudyProgress(
      totalQcmSolved: (json['totalQcmSolved'] as num?)?.toInt() ?? 0,
      todayQcmSolved: (json['todayQcmSolved'] as num?)?.toInt() ?? 0,
      totalCoursesCompleted: (json['totalCoursesCompleted'] as num?)?.toInt() ?? completedCourses.length,
      todayCoursesCompleted: (json['todayCoursesCompleted'] as num?)?.toInt() ?? 0,
      completedCourseIds: completedCourses,
      isTodayAccomplished: json['isTodayAccomplished'] == true,
      currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
      maxStreak: (json['maxStreak'] as num?)?.toInt() ?? 0,
      accomplishedDates: accomplished,
      dailyQcmGoal: (json['dailyQcmGoal'] as num?)?.toInt() ?? 25,
      dailyCourseGoal: (json['dailyCourseGoal'] as num?)?.toInt() ?? 1,
      averageAccuracy: (json['averageAccuracy'] as num?)?.toDouble() ?? 0.0,
      totalExamsPassed: (json['totalExamsPassed'] as num?)?.toInt() ?? 0,
      specialtyBreakdown: breakdown,
    );
  }
}

/// Service managing user study achievements, daily goals, and accomplishment validation
class UserStudyProgressService {
  static final UserStudyProgressService instance = UserStudyProgressService._();
  UserStudyProgressService._();

  static const String _prefsKey = 'medsina_user_study_progress_v2';
  static const String _todayTrackDateKey = 'medsina_progress_track_date';

  final ValueNotifier<UserStudyProgress> progressNotifier =
      ValueNotifier<UserStudyProgress>(UserStudyProgress.initial());

  UserStudyProgress get progress => progressNotifier.value;

  bool _isInitialized = false;

  /// Formats date to YYYY-MM-DD
  static String formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  /// Initialize and load all progress from SharedPreferences and active study sessions
  Future<UserStudyProgress> initialize() async {
    if (_isInitialized) return progressNotifier.value;
    _isInitialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefsKey);
      UserStudyProgress loaded;

      if (jsonStr != null && jsonStr.isNotEmpty) {
        try {
          loaded = UserStudyProgress.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
        } catch (_) {
          loaded = UserStudyProgress.initial();
        }
      } else {
        loaded = UserStudyProgress.initial();
      }

      // Check date rollover for today's counters
      final todayStr = formatDate(DateTime.now());
      final lastDate = prefs.getString(_todayTrackDateKey) ?? '';

      int todayQcm = loaded.todayQcmSolved;
      int todayCourses = loaded.todayCoursesCompleted;

      if (lastDate != todayStr) {
        // New day! Reset daily counters
        todayQcm = 0;
        todayCourses = 0;
        await prefs.setString(_todayTrackDateKey, todayStr);
      }

      final isAccomplished = loaded.accomplishedDates.contains(todayStr);

      // Aggregate QCMs from registered StudyProgressContributors
      int aggregatedQcm = loaded.totalQcmSolved;
      int aggregatedCourses = loaded.completedCourseIds.length;
      final completedCourses = Set<String>.from(loaded.completedCourseIds);

      try {
        int liveQcmCount = 0;
        int liveCompletedCount = 0;
        for (final contributor in MedsinaFeatureRegistry.instance.progressContributors) {
          final counts = await contributor.getProgressCounts();
          liveQcmCount += counts.solvedQcms;
          liveCompletedCount += counts.completedCourses;
        }
        if (liveQcmCount > aggregatedQcm) {
          aggregatedQcm = liveQcmCount;
        }
        if (liveCompletedCount > aggregatedCourses) {
          aggregatedCourses = liveCompletedCount;
        }
      } catch (_) {}

      // Calculate streak from accomplishedDates
      final computedStreak = _calculateStreak(loaded.accomplishedDates, todayStr);
      final maxStreak = computedStreak > loaded.maxStreak ? computedStreak : loaded.maxStreak;

      final updated = loaded.copyWith(
        todayQcmSolved: todayQcm,
        todayCoursesCompleted: todayCourses,
        totalQcmSolved: aggregatedQcm,
        totalCoursesCompleted: aggregatedCourses,
        completedCourseIds: completedCourses,
        isTodayAccomplished: isAccomplished,
        currentStreak: computedStreak,
        maxStreak: maxStreak,
      );

      progressNotifier.value = updated;
      await _saveLocal(updated);
      return updated;
    } catch (e) {
      debugPrint('Error initializing UserStudyProgressService: $e');
      return progressNotifier.value;
    }
  }

  /// Calculates consecutive accomplished days ending today or yesterday
  int _calculateStreak(Set<String> accomplishedDates, String todayStr) {
    if (accomplishedDates.isEmpty) return 0;
    int streak = 0;
    DateTime checkDate = DateTime.now();

    // If today is not accomplished yet, streak starts from yesterday if yesterday was done
    if (!accomplishedDates.contains(todayStr)) {
      checkDate = checkDate.subtract(const Duration(days: 1));
      final yesterdayStr = formatDate(checkDate);
      if (!accomplishedDates.contains(yesterdayStr)) {
        return 0;
      }
    }

    while (accomplishedDates.contains(formatDate(checkDate))) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Toggle today as accomplished (Accomplir le jour / Annuler)
  Future<bool> toggleTodayAccomplished() async {
    final cur = progressNotifier.value;
    final todayStr = formatDate(DateTime.now());
    final accomplished = Set<String>.from(cur.accomplishedDates);

    bool nowAccomplished;

    if (accomplished.contains(todayStr)) {
      // Unmark today
      accomplished.remove(todayStr);
      nowAccomplished = false;
    } else {
      // Mark today as accomplished!
      accomplished.add(todayStr);
      nowAccomplished = true;

      // Award XP via Loyalty Service (+50 points)
      try {
        await UserLoyaltyService.instance.addPoints(50, reason: 'Validation Journée d\'étude Medsina');
      } catch (_) {}
    }

    final newStreak = _calculateStreak(accomplished, todayStr);
    final maxStreak = newStreak > cur.maxStreak ? newStreak : cur.maxStreak;

    final updated = cur.copyWith(
      isTodayAccomplished: nowAccomplished,
      accomplishedDates: accomplished,
      currentStreak: newStreak,
      maxStreak: maxStreak,
    );

    progressNotifier.value = updated;
    await _saveLocal(updated);
    _syncWithCloud(updated);

    return nowAccomplished;
  }

  /// Manually log external progress (QCMs or course studied outside app)
  Future<void> addManualStudyProgress({
    required int qcmCount,
    required int courseCount,
    String? discipline,
  }) async {
    final cur = progressNotifier.value;
    final breakdown = Map<String, int>.from(cur.specialtyBreakdown);

    if (discipline != null && discipline.trim().isNotEmpty) {
      final key = discipline.trim();
      breakdown[key] = (breakdown[key] ?? 0) + qcmCount;
    }

    final updated = cur.copyWith(
      totalQcmSolved: cur.totalQcmSolved + qcmCount,
      todayQcmSolved: cur.todayQcmSolved + qcmCount,
      totalCoursesCompleted: cur.totalCoursesCompleted + courseCount,
      todayCoursesCompleted: cur.todayCoursesCompleted + courseCount,
      specialtyBreakdown: breakdown,
    );

    progressNotifier.value = updated;
    await _saveLocal(updated);
    _syncWithCloud(updated);
  }

  /// Mark an individual course/livret as completed
  Future<void> markCourseCompleted(String courseId, {String? courseTitle, String? module}) async {
    final cur = progressNotifier.value;
    final completed = Set<String>.from(cur.completedCourseIds);
    final wasAlreadyDone = completed.contains(courseId);

    if (wasAlreadyDone) return;
    completed.add(courseId);

    final updated = cur.copyWith(
      completedCourseIds: completed,
      totalCoursesCompleted: completed.length,
      todayCoursesCompleted: cur.todayCoursesCompleted + 1,
    );

    progressNotifier.value = updated;
    await _saveLocal(updated);
    _syncWithCloud(updated);

    try {
      await UserLoyaltyService.instance.addPoints(30, reason: 'Cours complété : $courseTitle');
    } catch (_) {}
  }

  /// Toggle an individual course completion
  Future<bool> toggleCourseCompleted(String courseId, {String? courseTitle}) async {
    final cur = progressNotifier.value;
    final completed = Set<String>.from(cur.completedCourseIds);
    final isDone = completed.contains(courseId);

    if (isDone) {
      completed.remove(courseId);
    } else {
      completed.add(courseId);
    }

    final updated = cur.copyWith(
      completedCourseIds: completed,
      totalCoursesCompleted: completed.length,
    );

    progressNotifier.value = updated;
    await _saveLocal(updated);
    _syncWithCloud(updated);
    return !isDone;
  }

  /// Update daily targets
  Future<void> updateDailyGoals({required int qcmGoal, required int courseGoal}) async {
    final cur = progressNotifier.value;
    final updated = cur.copyWith(
      dailyQcmGoal: qcmGoal > 0 ? qcmGoal : 25,
      dailyCourseGoal: courseGoal > 0 ? courseGoal : 1,
    );

    progressNotifier.value = updated;
    await _saveLocal(updated);
    _syncWithCloud(updated);
  }

  /// Persist locally to SharedPreferences
  Future<void> _saveLocal(UserStudyProgress progress) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(progress.toJson()));
    } catch (e) {
      debugPrint('Error saving study progress locally: $e');
    }
  }

  /// Sync progress to Supabase Cloud
  Future<void> _syncWithCloud(UserStudyProgress progress) async {
    try {
      final user = SupabaseService.currentUser;
      if (user == null) return;

      CloudSyncService.instance.notifyLocalChange(
        'user_study_progress',
        progress.toJson(),
      );

      // Also upsert in user_cloud_sync
      await SupabaseService.client.from('user_cloud_sync').upsert({
        'id': '${user.id}_study_progress',
        'user_id': user.id,
        'data_type': 'study_progress',
        'payload': progress.toJson(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Cloud sync notice: $e');
    }
  }
}
