import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/revision_session_model.dart';

class RevisionSessionStorage {
  static const String _courseProgressPrefix = 'medsina_rev_course_';
  static const String _customSessionsKey = 'medsina_rev_custom_sessions';

  static final RevisionSessionStorage instance = RevisionSessionStorage._();
  RevisionSessionStorage._();

  // --- SINGLE COURSE REVISION PROGRESS ---

  Future<void> saveCourseProgress(CourseRevisionProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(progress.toJson());
    await prefs.setString('$_courseProgressPrefix${progress.courseId}', jsonStr);
  }

  Future<CourseRevisionProgress?> getCourseProgress(String courseId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('$_courseProgressPrefix$courseId');
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return CourseRevisionProgress.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearCourseProgress(String courseId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_courseProgressPrefix$courseId');
  }

  /// Returns all active course progresses (to show badges in the catalog)
  Future<Map<String, CourseRevisionProgress>> getAllCourseProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    final result = <String, CourseRevisionProgress>{};

    for (final key in allKeys) {
      if (key.startsWith(_courseProgressPrefix)) {
        final courseId = key.substring(_courseProgressPrefix.length);
        final jsonStr = prefs.getString(key);
        if (jsonStr != null && jsonStr.isNotEmpty) {
          try {
            final map = jsonDecode(jsonStr) as Map<String, dynamic>;
            final prog = CourseRevisionProgress.fromJson(map);
            if (!prog.isCompleted) {
              result[courseId] = prog;
            }
          } catch (_) {}
        }
      }
    }
    return result;
  }

  // --- CUSTOM REVISION SESSIONS ---

  Future<List<CustomRevisionSession>> getCustomSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_customSessionsKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];

    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((item) => CustomRevisionSession.fromJson(item as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.lastActiveAt.compareTo(a.lastActiveAt));
    } catch (_) {
      return [];
    }
  }

  Future<void> saveCustomSession(CustomRevisionSession session) async {
    final sessions = await getCustomSessions();
    final existingIdx = sessions.indexWhere((s) => s.id == session.id);
    if (existingIdx >= 0) {
      sessions[existingIdx] = session;
    } else {
      sessions.insert(0, session);
    }

    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(sessions.map((s) => s.toJson()).toList());
    await prefs.setString(_customSessionsKey, jsonStr);
  }

  Future<void> deleteCustomSession(String sessionId) async {
    final sessions = await getCustomSessions();
    sessions.removeWhere((s) => s.id == sessionId);

    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(sessions.map((s) => s.toJson()).toList());
    await prefs.setString(_customSessionsKey, jsonStr);
  }
}

