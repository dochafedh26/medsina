import 'package:equatable/equatable.dart';

/// Statut d'un Concours Blanc / Examen National
enum NationalExamStatus {
  draft,
  scheduled,
  active,
  completed,
}

extension NationalExamStatusExtension on NationalExamStatus {
  String get label {
    switch (this) {
      case NationalExamStatus.draft:
        return 'Brouillon';
      case NationalExamStatus.scheduled:
        return 'Programmé';
      case NationalExamStatus.active:
        return 'En Cours';
      case NationalExamStatus.completed:
        return 'Clôturé & Classé';
    }
  }
}

/// Modèle d'un Examen National / Concours Blanc officiel créé par l'Admin.
class NationalExamModel extends Equatable {
  final String id;
  final String title;
  final String? description;
  final String? createdBy;
  final String targetType; // 'residency', 'module', 'student_emd'
  final String? targetModuleId;
  final String? targetModuleName;
  final List<String> questionIds;
  final int totalQuestions;
  final int durationMinutes;
  final DateTime startTime;
  final DateTime endTime;
  final bool isLiveSynchronous;
  final NationalExamStatus status;
  final bool negativeMarking;
  final String correctionStyle; // 'allOrNothing', 'partial'
  final bool announcementSent;
  final int participantsCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NationalExamModel({
    required this.id,
    required this.title,
    this.description,
    this.createdBy,
    this.targetType = 'residency',
    this.targetModuleId,
    this.targetModuleName,
    required this.questionIds,
    required this.totalQuestions,
    required this.durationMinutes,
    required this.startTime,
    required this.endTime,
    this.isLiveSynchronous = false,
    this.status = NationalExamStatus.scheduled,
    this.negativeMarking = false,
    this.correctionStyle = 'allOrNothing',
    this.announcementSent = false,
    this.participantsCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isUpcoming => DateTime.now().isBefore(startTime) && status == NationalExamStatus.scheduled;
  bool get isActive =>
      (status == NationalExamStatus.active) ||
      (status == NationalExamStatus.scheduled &&
          DateTime.now().isAfter(startTime) &&
          DateTime.now().isBefore(endTime));
  bool get isClosed => status == NationalExamStatus.completed || DateTime.now().isAfter(endTime);

  factory NationalExamModel.fromJson(Map<String, dynamic> json) {
    final rawQIds = json['question_ids'];
    final qIds = rawQIds is List ? rawQIds.map((e) => e.toString()).toList() : <String>[];

    NationalExamStatus parsedStatus;
    switch (json['status']?.toString()) {
      case 'active':
        parsedStatus = NationalExamStatus.active;
        break;
      case 'completed':
        parsedStatus = NationalExamStatus.completed;
        break;
      case 'draft':
        parsedStatus = NationalExamStatus.draft;
        break;
      default:
        parsedStatus = NationalExamStatus.scheduled;
    }

    return NationalExamModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Concours Blanc National',
      description: json['description']?.toString(),
      createdBy: json['created_by']?.toString(),
      targetType: json['target_type']?.toString() ?? 'residency',
      targetModuleId: json['target_module_id']?.toString(),
      targetModuleName: json['target_module_name']?.toString(),
      questionIds: qIds,
      totalQuestions: (json['total_questions'] as num?)?.toInt() ?? qIds.length,
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 60,
      startTime: json['start_time'] != null ? DateTime.parse(json['start_time'].toString()) : DateTime.now(),
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time'].toString()) : DateTime.now().add(const Duration(hours: 48)),
      isLiveSynchronous: json['is_live_synchronous'] == true,
      status: parsedStatus,
      negativeMarking: json['negative_marking'] == true,
      correctionStyle: json['correction_style']?.toString() ?? 'allOrNothing',
      announcementSent: json['announcement_sent'] == true,
      participantsCount: (json['participants_count'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'].toString()) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'].toString()) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'created_by': createdBy,
        'target_type': targetType,
        'target_module_id': targetModuleId,
        'target_module_name': targetModuleName,
        'question_ids': questionIds,
        'total_questions': totalQuestions,
        'duration_minutes': durationMinutes,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        'is_live_synchronous': isLiveSynchronous,
        'status': status.name,
        'negative_marking': negativeMarking,
        'correction_style': correctionStyle,
        'announcement_sent': announcementSent,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        targetType,
        targetModuleId,
        targetModuleName,
        questionIds,
        totalQuestions,
        durationMinutes,
        startTime,
        endTime,
        isLiveSynchronous,
        status,
        negativeMarking,
        correctionStyle,
        announcementSent,
        participantsCount,
      ];
}

/// Représente la participation d'un candidat à un concours blanc.
class ExamParticipationModel extends Equatable {
  final String id;
  final String examId;
  final String userId;
  final String status; // 'registered', 'in_progress', 'submitted', 'abandoned'
  final DateTime? startedAt;
  final DateTime? submittedAt;
  final int timeSpentSeconds;
  final double score;
  final double scoreOutOf20;
  final int correctAnswersCount;
  final int incorrectAnswersCount;
  final int unansweredCount;
  final double averageSecondsPerQuestion;
  final int? rank;
  final double? percentile;
  final bool isAnonymousInLeaderboard;
  final Map<String, dynamic> answers;
  final DateTime createdAt;

  const ExamParticipationModel({
    required this.id,
    required this.examId,
    required this.userId,
    this.status = 'registered',
    this.startedAt,
    this.submittedAt,
    this.timeSpentSeconds = 0,
    this.score = 0.0,
    this.scoreOutOf20 = 0.0,
    this.correctAnswersCount = 0,
    this.incorrectAnswersCount = 0,
    this.unansweredCount = 0,
    this.averageSecondsPerQuestion = 0.0,
    this.rank,
    this.percentile,
    this.isAnonymousInLeaderboard = false,
    this.answers = const {},
    required this.createdAt,
  });

  bool get isSubmitted => status == 'submitted';

  factory ExamParticipationModel.fromJson(Map<String, dynamic> json) {
    return ExamParticipationModel(
      id: json['id']?.toString() ?? '',
      examId: json['exam_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'registered',
      startedAt: json['started_at'] != null ? DateTime.parse(json['started_at'].toString()) : null,
      submittedAt: json['submitted_at'] != null ? DateTime.parse(json['submitted_at'].toString()) : null,
      timeSpentSeconds: (json['time_spent_seconds'] as num?)?.toInt() ?? 0,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      scoreOutOf20: (json['score_out_of_20'] as num?)?.toDouble() ?? 0.0,
      correctAnswersCount: (json['correct_answers_count'] as num?)?.toInt() ?? 0,
      incorrectAnswersCount: (json['incorrect_answers_count'] as num?)?.toInt() ?? 0,
      unansweredCount: (json['unanswered_count'] as num?)?.toInt() ?? 0,
      averageSecondsPerQuestion: (json['average_seconds_per_question'] as num?)?.toDouble() ?? 0.0,
      rank: (json['rank'] as num?)?.toInt(),
      percentile: (json['percentile'] as num?)?.toDouble(),
      isAnonymousInLeaderboard: json['is_anonymous_in_leaderboard'] == true,
      answers: (json['answers'] as Map<String, dynamic>?) ?? {},
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'].toString()) : DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        examId,
        userId,
        status,
        startedAt,
        submittedAt,
        timeSpentSeconds,
        score,
        scoreOutOf20,
        correctAnswersCount,
        incorrectAnswersCount,
        unansweredCount,
        averageSecondsPerQuestion,
        rank,
        percentile,
        isAnonymousInLeaderboard,
      ];
}

/// Ligne d'un candidat dans le Classement National officiel.
class ExamLeaderboardEntry extends Equatable {
  final int rank;
  final String userId;
  final String candidateName;
  final String? faculty;
  final String? avatarUrl;
  final double scoreOutOf20;
  final double accuracyPercentage;
  final int totalQuestions;
  final int correctCount;
  final int timeSpentSeconds;
  final double averageSecondsPerQuestion;
  final bool isCurrentUser;
  final bool isAnonymous;

  const ExamLeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.candidateName,
    this.faculty,
    this.avatarUrl,
    required this.scoreOutOf20,
    required this.accuracyPercentage,
    required this.totalQuestions,
    required this.correctCount,
    required this.timeSpentSeconds,
    required this.averageSecondsPerQuestion,
    this.isCurrentUser = false,
    this.isAnonymous = false,
  });

  String get displayName => isAnonymous && !isCurrentUser ? 'Candidat Anonyme' : candidateName;
  String get displayFaculty => isAnonymous && !isCurrentUser ? 'Faculté d\'Algérie' : (faculty ?? 'Faculté d\'Algérie');

  @override
  List<Object?> get props => [
        rank,
        userId,
        candidateName,
        faculty,
        avatarUrl,
        scoreOutOf20,
        accuracyPercentage,
        totalQuestions,
        correctCount,
        timeSpentSeconds,
        averageSecondsPerQuestion,
        isCurrentUser,
        isAnonymous,
      ];
}

