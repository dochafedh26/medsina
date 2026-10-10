import 'package:equatable/equatable.dart';

enum QuestionType { qcs, qcm, casClinique, qroc }

class QcmOption extends Equatable {
  final String key; // 'A', 'B', 'C', 'D', 'E'
  final String text;

  const QcmOption({required this.key, required this.text});

  @override
  List<Object?> get props => [key, text];
}

class QcmQuestion extends Equatable {
  final String id;
  final String moduleId;
  final String courseId;
  final String courseName;
  final QuestionType type;
  final String questionText;
  final String? clinicalCaseText; // For cas clinique
  final List<QcmOption> options;
  final List<String> correctAnswers; // ['A', 'C']
  final String explanation;
  final String source; // e.g. "Blida 2024", "Alger 2023", "Constantine"
  final int year;

  const QcmQuestion({
    required this.id,
    required this.moduleId,
    required this.courseId,
    required this.courseName,
    required this.type,
    required this.questionText,
    this.clinicalCaseText,
    required this.options,
    required this.correctAnswers,
    required this.explanation,
    required this.source,
    required this.year,
  });

  bool isOptionCorrect(String key) => correctAnswers.contains(key);

  @override
  List<Object?> get props => [
        id,
        moduleId,
        courseId,
        courseName,
        type,
        questionText,
        clinicalCaseText,
        options,
        correctAnswers,
        explanation,
        source,
        year,
      ];
}
