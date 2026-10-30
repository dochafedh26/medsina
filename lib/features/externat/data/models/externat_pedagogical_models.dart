import 'package:equatable/equatable.dart';

/// Tracks an extern student's active clinical rotation and its official timeline.
class StudentRotationState extends Equatable {
  final String moduleId;
  final String moduleName;
  final int studyYear;
  final DateTime startDate;
  final int durationWeeks;

  const StudentRotationState({
    required this.moduleId,
    required this.moduleName,
    required this.studyYear,
    required this.startDate,
    required this.durationWeeks,
  });

  DateTime get endDate => startDate.add(Duration(days: durationWeeks * 7));

  int get totalDays => durationWeeks * 7;

  int get daysElapsed {
    final now = DateTime.now();
    final diff = now.difference(startDate).inDays;
    return diff.clamp(0, totalDays);
  }

  int get daysRemaining {
    final rem = totalDays - daysElapsed;
    return rem < 0 ? 0 : rem;
  }

  int get currentWeek {
    final week = (daysElapsed / 7).floor() + 1;
    return week.clamp(1, durationWeeks);
  }

  double get progressPercentage {
    if (totalDays <= 0) return 1.0;
    return (daysElapsed / totalDays).clamp(0.0, 1.0);
  }

  /// Whether the student is in the final preparation phase (J-7 or less before the official EMD)
  bool get isEmdWindowOpen => daysRemaining <= 7;

  StudentRotationState copyWith({
    String? moduleId,
    String? moduleName,
    int? studyYear,
    DateTime? startDate,
    int? durationWeeks,
  }) {
    return StudentRotationState(
      moduleId: moduleId ?? this.moduleId,
      moduleName: moduleName ?? this.moduleName,
      studyYear: studyYear ?? this.studyYear,
      startDate: startDate ?? this.startDate,
      durationWeeks: durationWeeks ?? this.durationWeeks,
    );
  }

  Map<String, dynamic> toJson() => {
        'moduleId': moduleId,
        'moduleName': moduleName,
        'studyYear': studyYear,
        'startDate': startDate.toIso8601String(),
        'durationWeeks': durationWeeks,
      };

  factory StudentRotationState.fromJson(Map<String, dynamic> json) {
    return StudentRotationState(
      moduleId: json['moduleId'] as String? ?? 'orl',
      moduleName: json['moduleName'] as String? ?? 'ORL',
      studyYear: json['studyYear'] as int? ?? 5,
      startDate: DateTime.tryParse(json['startDate'] as String? ?? '') ?? DateTime.now(),
      durationWeeks: json['durationWeeks'] as int? ?? 3,
    );
  }

  @override
  List<Object?> get props => [moduleId, moduleName, studyYear, startDate, durationWeeks];
}

/// A rapid flash-check question embedded in an active lecture.
class FlashCheckQuestion extends Equatable {
  final String question;
  final List<String> options;
  final int correctOptionIndex;
  final String explanation;

  const FlashCheckQuestion({
    required this.question,
    required this.options,
    required this.correctOptionIndex,
    required this.explanation,
  });

  factory FlashCheckQuestion.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    final list = <String>[];
    if (rawOptions is List) {
      for (final opt in rawOptions) {
        list.add(opt.toString());
      }
    }
    return FlashCheckQuestion(
      question: json['question']?.toString() ?? '',
      options: list.isNotEmpty ? list : const ['Option A', 'Option B', 'Option C', 'Option D'],
      correctOptionIndex: (json['correctOptionIndex'] as num?)?.toInt() ?? 0,
      explanation: json['explanation']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'question': question,
        'options': options,
        'correctOptionIndex': correctOptionIndex,
        'explanation': explanation,
      };

  @override
  List<Object?> get props => [question, options, correctOptionIndex, explanation];
}

/// An interactive lecture session delivered by the Year's Virtual Professor.
class InteractiveCourseSession extends Equatable {
  final String id;
  final String moduleName;
  final String courseName;
  final int studyYear;
  final String teacherName;
  final String teacherTitle;
  final String clinicalHook;
  final List<CourseLectureSection> lectureSections;
  final String professorTrap;
  final List<FlashCheckQuestion> flashQuestions;
  final String cheatSheetSummary;
  final DateTime createdAt;

  const InteractiveCourseSession({
    required this.id,
    required this.moduleName,
    required this.courseName,
    required this.studyYear,
    required this.teacherName,
    required this.teacherTitle,
    required this.clinicalHook,
    required this.lectureSections,
    required this.professorTrap,
    required this.flashQuestions,
    required this.cheatSheetSummary,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, moduleName, courseName, studyYear, teacherName, clinicalHook];
}

class CourseLectureSection extends Equatable {
  final String title;
  final String contentMarkdown;
  final String keyTakeaway;

  const CourseLectureSection({
    required this.title,
    required this.contentMarkdown,
    required this.keyTakeaway,
  });

  @override
  List<Object?> get props => [title, contentMarkdown, keyTakeaway];
}

/// Bedside Guidance Checklist for clinical rounds and hospital wards.
class BedsideGuidanceModel extends Equatable {
  final String topicOrSymptom;
  final String moduleName;
  final List<String> questionsInterrogatoire;
  final List<String> examensPhysiquesCles;
  final List<String> bilansUrgence;
  final List<String> drapeauxRouges;
  final String algerianContextNote;

  const BedsideGuidanceModel({
    required this.topicOrSymptom,
    required this.moduleName,
    required this.questionsInterrogatoire,
    required this.examensPhysiquesCles,
    required this.bilansUrgence,
    required this.drapeauxRouges,
    required this.algerianContextNote,
  });

  @override
  List<Object?> get props => [topicOrSymptom, moduleName];
}

/// Result of an EMD simulation exam.
class EmdSimulationResult extends Equatable {
  final String examId;
  final String moduleName;
  final int studyYear;
  final int totalQuestions;
  final int correctAnswers;
  final double scoreOn20;
  final bool isPassed;
  final int durationSeconds;
  final DateTime completedAt;
  final Map<String, int> performanceByTopic;

  const EmdSimulationResult({
    required this.examId,
    required this.moduleName,
    required this.studyYear,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.scoreOn20,
    required this.isPassed,
    required this.durationSeconds,
    required this.completedAt,
    required this.performanceByTopic,
  });

  Map<String, dynamic> toJson() => {
        'examId': examId,
        'moduleName': moduleName,
        'studyYear': studyYear,
        'totalQuestions': totalQuestions,
        'correctAnswers': correctAnswers,
        'scoreOn20': scoreOn20,
        'isPassed': isPassed,
        'durationSeconds': durationSeconds,
        'completedAt': completedAt.toIso8601String(),
        'performanceByTopic': performanceByTopic,
      };

  factory EmdSimulationResult.fromJson(Map<String, dynamic> json) {
    return EmdSimulationResult(
      examId: json['examId'] as String? ?? '',
      moduleName: json['moduleName'] as String? ?? '',
      studyYear: json['studyYear'] as int? ?? 4,
      totalQuestions: json['totalQuestions'] as int? ?? 20,
      correctAnswers: json['correctAnswers'] as int? ?? 0,
      scoreOn20: (json['scoreOn20'] as num?)?.toDouble() ?? 0.0,
      isPassed: json['isPassed'] as bool? ?? false,
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      completedAt: DateTime.tryParse(json['completedAt'] as String? ?? '') ?? DateTime.now(),
      performanceByTopic: (json['performanceByTopic'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toInt()),
          ) ??
          {},
    );
  }

  @override
  List<Object?> get props => [examId, scoreOn20, completedAt];
}
