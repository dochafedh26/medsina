import 'package:equatable/equatable.dart';
import '../../revision/models/qcm_model.dart';

/// Détail d'une question analysée post-examen.
class ExamQuestionResult extends Equatable {
  final QcmQuestion question;
  final Set<String> userSelectedKeys;
  final Set<String> correctKeys;
  final bool isCorrect;
  final bool isPartiallyCorrect;
  final bool isUnanswered;
  final int timeSpentSeconds;

  const ExamQuestionResult({
    required this.question,
    required this.userSelectedKeys,
    required this.correctKeys,
    required this.isCorrect,
    required this.isPartiallyCorrect,
    required this.isUnanswered,
    this.timeSpentSeconds = 0,
  });

  @override
  List<Object?> get props => [
        question.id,
        userSelectedKeys,
        correctKeys,
        isCorrect,
        isPartiallyCorrect,
        isUnanswered,
        timeSpentSeconds,
      ];
}

/// Modèle complet d'une session en Mode Examen Chronométré.
class ExamSessionModel extends Equatable {
  final String id;
  final String title;
  final List<QcmQuestion> questions;
  final int durationMinutes;
  final Map<String, Set<String>> userAnswers; // questionId -> {'A', 'C'}
  final Set<String> flaggedQuestionIds; // Questions marquées pour révision
  final Map<String, int> timePerQuestionSeconds;
  final DateTime startedAt;
  final DateTime? submittedAt;
  final bool isSubmitted;

  const ExamSessionModel({
    required this.id,
    required this.title,
    required this.questions,
    required this.durationMinutes,
    this.userAnswers = const {},
    this.flaggedQuestionIds = const {},
    this.timePerQuestionSeconds = const {},
    required this.startedAt,
    this.submittedAt,
    this.isSubmitted = false,
  });

  int get totalQuestions => questions.length;
  int get answeredCount => userAnswers.entries.where((e) => e.value.isNotEmpty).length;
  int get unansweredCount => totalQuestions - answeredCount;
  int get flaggedCount => flaggedQuestionIds.length;

  int get totalTimeSpentSeconds {
    if (submittedAt != null) {
      return submittedAt!.difference(startedAt).inSeconds;
    }
    return DateTime.now().difference(startedAt).inSeconds;
  }

  double get averageSecondsPerQuestion {
    if (totalQuestions <= 0) return 0.0;
    return totalTimeSpentSeconds / totalQuestions;
  }

  /// Évalue l'ensemble des questions selon le barème officiel du concours
  List<ExamQuestionResult> evaluateResults({String correctionStyle = 'allOrNothing'}) {
    final results = <ExamQuestionResult>[];

    for (final q in questions) {
      final userKeys = userAnswers[q.id] ?? <String>{};
      final correctKeys = q.correctAnswers.map((k) => k.toUpperCase().trim()).toSet();

      final isUnanswered = userKeys.isEmpty;
      bool isCorrect = false;
      bool isPartiallyCorrect = false;

      if (!isUnanswered) {
        if (correctionStyle == 'allOrNothing') {
          // Tout ou rien : exactement les mêmes touches et aucune fausse
          isCorrect = userKeys.length == correctKeys.length && userKeys.containsAll(correctKeys);
        } else {
          // Notation partielle
          final correctChosen = userKeys.intersection(correctKeys);
          final wrongChosen = userKeys.difference(correctKeys);
          if (wrongChosen.isEmpty && correctChosen.isNotEmpty) {
            if (correctChosen.length == correctKeys.length) {
              isCorrect = true;
            } else {
              isPartiallyCorrect = true;
            }
          }
        }
      }

      results.add(ExamQuestionResult(
        question: q,
        userSelectedKeys: userKeys,
        correctKeys: correctKeys,
        isCorrect: isCorrect,
        isPartiallyCorrect: isPartiallyCorrect,
        isUnanswered: isUnanswered,
        timeSpentSeconds: timePerQuestionSeconds[q.id] ?? 0,
      ));
    }

    return results;
  }

  /// Note sur 20
  double calculateScoreOutOf20({String correctionStyle = 'allOrNothing'}) {
    if (totalQuestions <= 0) return 0.0;
    final results = evaluateResults(correctionStyle: correctionStyle);
    double points = 0.0;
    for (final r in results) {
      if (r.isCorrect) {
        points += 1.0;
      } else if (r.isPartiallyCorrect) {
        points += 0.5;
      }
    }
    return (points / totalQuestions) * 20.0;
  }

  /// Pourcentage de bonnes réponses (ex: 85.0%)
  double calculateAccuracyPercentage({String correctionStyle = 'allOrNothing'}) {
    if (totalQuestions <= 0) return 0.0;
    final results = evaluateResults(correctionStyle: correctionStyle);
    double points = 0.0;
    for (final r in results) {
      if (r.isCorrect) {
        points += 1.0;
      } else if (r.isPartiallyCorrect) {
        points += 0.5;
      }
    }
    return (points / totalQuestions) * 100.0;
  }

  /// Fiche de synthèse : filtre et isole les questions où l'étudiant s'est trompé
  List<ExamQuestionResult> getFalseAndMissedQuestions({String correctionStyle = 'allOrNothing'}) {
    return evaluateResults(correctionStyle: correctionStyle).where((r) => !r.isCorrect).toList();
  }

  ExamSessionModel copyWith({
    String? id,
    String? title,
    List<QcmQuestion>? questions,
    int? durationMinutes,
    Map<String, Set<String>>? userAnswers,
    Set<String>? flaggedQuestionIds,
    Map<String, int>? timePerQuestionSeconds,
    DateTime? startedAt,
    DateTime? submittedAt,
    bool? isSubmitted,
  }) {
    return ExamSessionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      questions: questions ?? this.questions,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      userAnswers: userAnswers ?? this.userAnswers,
      flaggedQuestionIds: flaggedQuestionIds ?? this.flaggedQuestionIds,
      timePerQuestionSeconds: timePerQuestionSeconds ?? this.timePerQuestionSeconds,
      startedAt: startedAt ?? this.startedAt,
      submittedAt: submittedAt ?? this.submittedAt,
      isSubmitted: isSubmitted ?? this.isSubmitted,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        questions,
        durationMinutes,
        userAnswers,
        flaggedQuestionIds,
        timePerQuestionSeconds,
        startedAt,
        submittedAt,
        isSubmitted,
      ];
}
