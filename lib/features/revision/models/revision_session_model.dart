import 'package:equatable/equatable.dart';

/// Tracks local saved progress for an individual course revision.
class CourseRevisionProgress extends Equatable {
  final String courseId;
  final String courseName;
  final String moduleId;
  final int currentQuestionIndex;
  final int totalQuestions;
  final Map<String, Set<String>> userAnswers; // questionId -> Set of chosen keys {'A', 'B'}
  final Set<String> revealedQuestions; // questionIds where answer was revealed
  final bool isCompleted;
  final DateTime lastActiveAt;

  const CourseRevisionProgress({
    required this.courseId,
    required this.courseName,
    required this.moduleId,
    required this.currentQuestionIndex,
    required this.totalQuestions,
    required this.userAnswers,
    required this.revealedQuestions,
    this.isCompleted = false,
    required this.lastActiveAt,
  });

  double get progressPercentage {
    if (totalQuestions <= 0) return 0.0;
    return (currentQuestionIndex + 1) / totalQuestions;
  }

  factory CourseRevisionProgress.fromJson(Map<String, dynamic> json) {
    final answersRaw = json['userAnswers'] as Map<String, dynamic>? ?? {};
    final parsedAnswers = <String, Set<String>>{};
    answersRaw.forEach((qId, keys) {
      if (keys is List) {
        parsedAnswers[qId] = keys.map((e) => e.toString()).toSet();
      }
    });

    final revealedRaw = json['revealedQuestions'] as List<dynamic>? ?? [];
    final parsedRevealed = revealedRaw.map((e) => e.toString()).toSet();

    return CourseRevisionProgress(
      courseId: json['courseId']?.toString() ?? '',
      courseName: json['courseName']?.toString() ?? '',
      moduleId: json['moduleId']?.toString() ?? '',
      currentQuestionIndex: (json['currentQuestionIndex'] as num?)?.toInt() ?? 0,
      totalQuestions: (json['totalQuestions'] as num?)?.toInt() ?? 0,
      userAnswers: parsedAnswers,
      revealedQuestions: parsedRevealed,
      isCompleted: json['isCompleted'] == true,
      lastActiveAt: json['lastActiveAt'] != null
          ? DateTime.tryParse(json['lastActiveAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'courseId': courseId,
        'courseName': courseName,
        'moduleId': moduleId,
        'currentQuestionIndex': currentQuestionIndex,
        'totalQuestions': totalQuestions,
        'userAnswers': userAnswers.map((k, v) => MapEntry(k, v.toList())),
        'revealedQuestions': revealedQuestions.toList(),
        'isCompleted': isCompleted,
        'lastActiveAt': lastActiveAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [
        courseId,
        currentQuestionIndex,
        totalQuestions,
        userAnswers,
        revealedQuestions,
        isCompleted,
        lastActiveAt,
      ];
}

/// Model for custom multi-course / multi-module revision sessions created by the user.
class CustomRevisionSession extends Equatable {
  final String id;
  final String title;
  final List<String> moduleIds;
  final List<String> moduleNames;
  final List<String> courseIds;
  final List<String> courseNames;
  final int questionLimit; // -1 for all
  final bool shuffleQuestions;
  final int currentQuestionIndex;
  final int totalQuestions;
  final Map<String, Set<String>> userAnswers;
  final Set<String> revealedQuestions;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime lastActiveAt;

  const CustomRevisionSession({
    required this.id,
    required this.title,
    required this.moduleIds,
    this.moduleNames = const [],
    required this.courseIds,
    this.courseNames = const [],
    this.questionLimit = 20,
    this.shuffleQuestions = true,
    this.currentQuestionIndex = 0,
    this.totalQuestions = 0,
    this.userAnswers = const {},
    this.revealedQuestions = const {},
    this.isCompleted = false,
    required this.createdAt,
    required this.lastActiveAt,
  });

  double get progressPercentage {
    if (totalQuestions <= 0) return 0.0;
    return (currentQuestionIndex + 1) / totalQuestions;
  }

  CustomRevisionSession copyWith({
    String? id,
    String? title,
    List<String>? moduleIds,
    List<String>? moduleNames,
    List<String>? courseIds,
    List<String>? courseNames,
    int? questionLimit,
    bool? shuffleQuestions,
    int? currentQuestionIndex,
    int? totalQuestions,
    Map<String, Set<String>>? userAnswers,
    Set<String>? revealedQuestions,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? lastActiveAt,
  }) {
    return CustomRevisionSession(
      id: id ?? this.id,
      title: title ?? this.title,
      moduleIds: moduleIds ?? this.moduleIds,
      moduleNames: moduleNames ?? this.moduleNames,
      courseIds: courseIds ?? this.courseIds,
      courseNames: courseNames ?? this.courseNames,
      questionLimit: questionLimit ?? this.questionLimit,
      shuffleQuestions: shuffleQuestions ?? this.shuffleQuestions,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      userAnswers: userAnswers ?? this.userAnswers,
      revealedQuestions: revealedQuestions ?? this.revealedQuestions,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }

  factory CustomRevisionSession.fromJson(Map<String, dynamic> json) {
    final answersRaw = json['userAnswers'] as Map<String, dynamic>? ?? {};
    final parsedAnswers = <String, Set<String>>{};
    answersRaw.forEach((qId, keys) {
      if (keys is List) {
        parsedAnswers[qId] = keys.map((e) => e.toString()).toSet();
      }
    });

    final revealedRaw = json['revealedQuestions'] as List<dynamic>? ?? [];
    final parsedRevealed = revealedRaw.map((e) => e.toString()).toSet();

    return CustomRevisionSession(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Session Sur-Mesure',
      moduleIds: (json['moduleIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      moduleNames: (json['moduleNames'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      courseIds: (json['courseIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      courseNames: (json['courseNames'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      questionLimit: (json['questionLimit'] as num?)?.toInt() ?? 20,
      shuffleQuestions: json['shuffleQuestions'] != false,
      currentQuestionIndex: (json['currentQuestionIndex'] as num?)?.toInt() ?? 0,
      totalQuestions: (json['totalQuestions'] as num?)?.toInt() ?? 0,
      userAnswers: parsedAnswers,
      revealedQuestions: parsedRevealed,
      isCompleted: json['isCompleted'] == true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lastActiveAt: json['lastActiveAt'] != null
          ? DateTime.tryParse(json['lastActiveAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'moduleIds': moduleIds,
        'moduleNames': moduleNames,
        'courseIds': courseIds,
        'courseNames': courseNames,
        'questionLimit': questionLimit,
        'shuffleQuestions': shuffleQuestions,
        'currentQuestionIndex': currentQuestionIndex,
        'totalQuestions': totalQuestions,
        'userAnswers': userAnswers.map((k, v) => MapEntry(k, v.toList())),
        'revealedQuestions': revealedQuestions.toList(),
        'isCompleted': isCompleted,
        'createdAt': createdAt.toIso8601String(),
        'lastActiveAt': lastActiveAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [
        id,
        title,
        moduleIds,
        courseIds,
        currentQuestionIndex,
        totalQuestions,
        userAnswers,
        revealedQuestions,
        isCompleted,
        lastActiveAt,
      ];
}

