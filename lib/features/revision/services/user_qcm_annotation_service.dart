import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a student's personal history, bookmark, and note on a single QCM question.
class UserQuestionAnnotation {
  final String questionId;
  final String moduleId;
  final String courseId;
  final bool isMarked;
  final String personalNote;
  final int attemptsCount;
  final int correctCount;
  final int partialCount;
  final int wrongCount;
  final String lastResult; // 'none', 'correct', 'partial', 'wrong'
  final int totalTimeSeconds;
  final DateTime? updatedAt;

  const UserQuestionAnnotation({
    required this.questionId,
    this.moduleId = '',
    this.courseId = '',
    this.isMarked = false,
    this.personalNote = '',
    this.attemptsCount = 0,
    this.correctCount = 0,
    this.partialCount = 0,
    this.wrongCount = 0,
    this.lastResult = 'none',
    this.totalTimeSeconds = 0,
    this.updatedAt,
  });

  bool get hasNote => personalNote.trim().isNotEmpty;
  bool get isConsulted => attemptsCount > 0;
  bool get isWrongLastTime => lastResult == 'wrong' || lastResult == 'partial';

  UserQuestionAnnotation copyWith({
    String? moduleId,
    String? courseId,
    bool? isMarked,
    String? personalNote,
    int? attemptsCount,
    int? correctCount,
    int? partialCount,
    int? wrongCount,
    String? lastResult,
    int? totalTimeSeconds,
    DateTime? updatedAt,
  }) {
    return UserQuestionAnnotation(
      questionId: questionId,
      moduleId: moduleId ?? this.moduleId,
      courseId: courseId ?? this.courseId,
      isMarked: isMarked ?? this.isMarked,
      personalNote: personalNote ?? this.personalNote,
      attemptsCount: attemptsCount ?? this.attemptsCount,
      correctCount: correctCount ?? this.correctCount,
      partialCount: partialCount ?? this.partialCount,
      wrongCount: wrongCount ?? this.wrongCount,
      lastResult: lastResult ?? this.lastResult,
      totalTimeSeconds: totalTimeSeconds ?? this.totalTimeSeconds,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory UserQuestionAnnotation.fromJson(Map<String, dynamic> json) {
    return UserQuestionAnnotation(
      questionId: json['questionId']?.toString() ?? '',
      moduleId: json['moduleId']?.toString() ?? '',
      courseId: json['courseId']?.toString() ?? '',
      isMarked: json['isMarked'] == true,
      personalNote: json['personalNote']?.toString() ?? '',
      attemptsCount: (json['attemptsCount'] as num?)?.toInt() ?? 0,
      correctCount: (json['correctCount'] as num?)?.toInt() ?? 0,
      partialCount: (json['partialCount'] as num?)?.toInt() ?? 0,
      wrongCount: (json['wrongCount'] as num?)?.toInt() ?? 0,
      lastResult: json['lastResult']?.toString() ?? 'none',
      totalTimeSeconds: (json['totalTimeSeconds'] as num?)?.toInt() ?? 0,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'questionId': questionId,
        'moduleId': moduleId,
        'courseId': courseId,
        'isMarked': isMarked,
        'personalNote': personalNote,
        'attemptsCount': attemptsCount,
        'correctCount': correctCount,
        'partialCount': partialCount,
        'wrongCount': wrongCount,
        'lastResult': lastResult,
        'totalTimeSeconds': totalTimeSeconds,
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };
}

/// Represents a student's Study Planner progress for a specific course (Couche 1, Couche 2, Couche 3, Note).
class CourseStudyPlannerEntry {
  final String courseId;
  final String moduleId;
  final bool layer1Done; // Lecture & Compréhension
  final bool layer2Done; // Fiche & Mémorisation active
  final bool layer3Done; // Révision finale & Annales
  final String plannerNote;
  final DateTime? updatedAt;

  const CourseStudyPlannerEntry({
    required this.courseId,
    this.moduleId = '',
    this.layer1Done = false,
    this.layer2Done = false,
    this.layer3Done = false,
    this.plannerNote = '',
    this.updatedAt,
  });

  int get completedLayersCount =>
      (layer1Done ? 1 : 0) + (layer2Done ? 1 : 0) + (layer3Done ? 1 : 0);

  CourseStudyPlannerEntry copyWith({
    String? moduleId,
    bool? layer1Done,
    bool? layer2Done,
    bool? layer3Done,
    String? plannerNote,
    DateTime? updatedAt,
  }) {
    return CourseStudyPlannerEntry(
      courseId: courseId,
      moduleId: moduleId ?? this.moduleId,
      layer1Done: layer1Done ?? this.layer1Done,
      layer2Done: layer2Done ?? this.layer2Done,
      layer3Done: layer3Done ?? this.layer3Done,
      plannerNote: plannerNote ?? this.plannerNote,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory CourseStudyPlannerEntry.fromJson(Map<String, dynamic> json) {
    return CourseStudyPlannerEntry(
      courseId: json['courseId']?.toString() ?? '',
      moduleId: json['moduleId']?.toString() ?? '',
      layer1Done: json['layer1Done'] == true,
      layer2Done: json['layer2Done'] == true,
      layer3Done: json['layer3Done'] == true,
      plannerNote: json['plannerNote']?.toString() ?? '',
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'courseId': courseId,
        'moduleId': moduleId,
        'layer1Done': layer1Done,
        'layer2Done': layer2Done,
        'layer3Done': layer3Done,
        'plannerNote': plannerNote,
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };
}

/// Offline-first service managing question annotations, bookmarks, personal notes,
/// answer statistics, and Study Planner layers.
class UserQcmAnnotationService extends ChangeNotifier {
  UserQcmAnnotationService._();
  static final UserQcmAnnotationService instance = UserQcmAnnotationService._();

  static const String _annotationsPrefKey = 'medsina_user_qcm_annotations_v1';
  static const String _plannerPrefKey = 'medsina_study_planner_entries_v1';
  static const String _examDatePrefKey = 'medsina_study_planner_exam_date_v1';

  Map<String, UserQuestionAnnotation> _annotations = {};
  Map<String, CourseStudyPlannerEntry> _plannerEntries = {};
  DateTime? _targetExamDate;
  bool _initialized = false;

  Map<String, UserQuestionAnnotation> get annotations => _annotations;
  Map<String, CourseStudyPlannerEntry> get plannerEntries => _plannerEntries;
  DateTime get targetExamDate =>
      _targetExamDate ?? DateTime.now().add(const Duration(days: 90));

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();

    final rawAnn = prefs.getString(_annotationsPrefKey);
    if (rawAnn != null && rawAnn.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawAnn) as Map<String, dynamic>;
        _annotations = decoded.map(
          (k, v) => MapEntry(
            k,
            UserQuestionAnnotation.fromJson(Map<String, dynamic>.from(v as Map)),
          ),
        );
      } catch (e) {
        debugPrint('Error loading QCM annotations: $e');
      }
    }

    final rawPlan = prefs.getString(_plannerPrefKey);
    if (rawPlan != null && rawPlan.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawPlan) as Map<String, dynamic>;
        _plannerEntries = decoded.map(
          (k, v) => MapEntry(
            k,
            CourseStudyPlannerEntry.fromJson(Map<String, dynamic>.from(v as Map)),
          ),
        );
      } catch (e) {
        debugPrint('Error loading Study Planner entries: $e');
      }
    }

    final rawExamDate = prefs.getString(_examDatePrefKey);
    if (rawExamDate != null) {
      _targetExamDate = DateTime.tryParse(rawExamDate);
    }

    _initialized = true;
  }

  UserQuestionAnnotation getAnnotation(String questionId) {
    return _annotations[questionId] ??
        UserQuestionAnnotation(questionId: questionId);
  }

  CourseStudyPlannerEntry getPlannerEntry(String courseId, {String moduleId = ''}) {
    return _plannerEntries[courseId] ??
        CourseStudyPlannerEntry(courseId: courseId, moduleId: moduleId);
  }

  Future<void> toggleBookmark({
    required String questionId,
    String moduleId = '',
    String courseId = '',
  }) async {
    await ensureInitialized();
    final current = getAnnotation(questionId);
    final updated = current.copyWith(
      moduleId: moduleId.isNotEmpty ? moduleId : current.moduleId,
      courseId: courseId.isNotEmpty ? courseId : current.courseId,
      isMarked: !current.isMarked,
      updatedAt: DateTime.now(),
    );
    _annotations[questionId] = updated;
    await _persistAnnotations();
    notifyListeners();
  }

  Future<void> savePersonalNote({
    required String questionId,
    required String note,
    String moduleId = '',
    String courseId = '',
  }) async {
    await ensureInitialized();
    final current = getAnnotation(questionId);
    final updated = current.copyWith(
      moduleId: moduleId.isNotEmpty ? moduleId : current.moduleId,
      courseId: courseId.isNotEmpty ? courseId : current.courseId,
      personalNote: note.trim(),
      updatedAt: DateTime.now(),
    );
    _annotations[questionId] = updated;
    await _persistAnnotations();
    notifyListeners();
  }

  Future<void> recordQuestionAttempt({
    required String questionId,
    required String moduleId,
    required String courseId,
    required Set<String> selectedOptions,
    required List<String> correctAnswers,
    int timeSpentSeconds = 12,
  }) async {
    await ensureInitialized();
    final current = getAnnotation(questionId);
    final correctSet = correctAnswers.toSet();
    final isFullyCorrect = selectedOptions.length == correctSet.length &&
        selectedOptions.containsAll(correctSet);
    final hasAnyCorrect = selectedOptions.any(correctSet.contains);
    final hasAnyWrong = selectedOptions.any((k) => !correctSet.contains(k));

    String resultType = 'wrong';
    if (isFullyCorrect) {
      resultType = 'correct';
    } else if (hasAnyCorrect && !hasAnyWrong) {
      resultType = 'partial';
    }

    final updated = current.copyWith(
      moduleId: moduleId,
      courseId: courseId,
      attemptsCount: current.attemptsCount + 1,
      correctCount: current.correctCount + (resultType == 'correct' ? 1 : 0),
      partialCount: current.partialCount + (resultType == 'partial' ? 1 : 0),
      wrongCount: current.wrongCount + (resultType == 'wrong' ? 1 : 0),
      lastResult: resultType,
      totalTimeSeconds: current.totalTimeSeconds + timeSpentSeconds,
      updatedAt: DateTime.now(),
    );

    _annotations[questionId] = updated;
    await _persistAnnotations();
    notifyListeners();
  }

  Future<void> togglePlannerLayer({
    required String courseId,
    required String moduleId,
    required int layerIndex, // 1, 2, or 3
  }) async {
    await ensureInitialized();
    final current = getPlannerEntry(courseId, moduleId: moduleId);
    final updated = current.copyWith(
      moduleId: moduleId,
      layer1Done: layerIndex == 1 ? !current.layer1Done : current.layer1Done,
      layer2Done: layerIndex == 2 ? !current.layer2Done : current.layer2Done,
      layer3Done: layerIndex == 3 ? !current.layer3Done : current.layer3Done,
      updatedAt: DateTime.now(),
    );
    _plannerEntries[courseId] = updated;
    await _persistPlanner();
    notifyListeners();
  }

  Future<void> savePlannerCourseNote({
    required String courseId,
    required String moduleId,
    required String note,
  }) async {
    await ensureInitialized();
    final current = getPlannerEntry(courseId, moduleId: moduleId);
    final updated = current.copyWith(
      moduleId: moduleId,
      plannerNote: note.trim(),
      updatedAt: DateTime.now(),
    );
    _plannerEntries[courseId] = updated;
    await _persistPlanner();
    notifyListeners();
  }

  Future<void> setTargetExamDate(DateTime date) async {
    await ensureInitialized();
    _targetExamDate = date;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_examDatePrefKey, date.toIso8601String());
    notifyListeners();
  }

  /// Calculates mastery percentage (0..100) for a given courseId based on answered questions.
  double getCourseMasteryPercent(String courseId) {
    final courseAnns = _annotations.values
        .where((a) => a.courseId == courseId && a.attemptsCount > 0)
        .toList();
    if (courseAnns.isEmpty) return 0.0;
    final correct = courseAnns.where((a) => a.lastResult == 'correct').length;
    return (correct / courseAnns.length) * 100.0;
  }

  /// Summary counts for quick badges in the UI.
  Map<String, int> getGlobalSummaryCounts() {
    int consulted = 0;
    int wrong = 0;
    int marked = 0;
    int withNotes = 0;
    for (final a in _annotations.values) {
      if (a.attemptsCount > 0) consulted++;
      if (a.isWrongLastTime) wrong++;
      if (a.isMarked) marked++;
      if (a.hasNote) withNotes++;
    }
    return {
      'consulted': consulted,
      'wrong': wrong,
      'marked': marked,
      'withNotes': withNotes,
    };
  }

  Future<void> _persistAnnotations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = _annotations.map((k, v) => MapEntry(k, v.toJson()));
      await prefs.setString(_annotationsPrefKey, jsonEncode(map));
    } catch (e) {
      debugPrint('Error saving QCM annotations: $e');
    }
  }

  Future<void> _persistPlanner() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = _plannerEntries.map((k, v) => MapEntry(k, v.toJson()));
      await prefs.setString(_plannerPrefKey, jsonEncode(map));
    } catch (e) {
      debugPrint('Error saving Study Planner entries: $e');
    }
  }
}
