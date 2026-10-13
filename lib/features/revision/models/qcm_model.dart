import 'package:equatable/equatable.dart';

enum QuestionType { qcs, qcm, casClinique, qroc }

class QcmOption extends Equatable {
  final String key; // 'A', 'B', 'C', 'D', 'E'
  final String text;

  const QcmOption({required this.key, required this.text});

  factory QcmOption.fromJson(Map<String, dynamic> json) {
    return QcmOption(
      key: json['key']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'text': text,
      };

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

  static QuestionType parseType(dynamic val) {
    if (val == null) return QuestionType.qcm;
    final s = val.toString().toLowerCase();
    if (s.contains('qcs')) return QuestionType.qcs;
    if (s.contains('cas')) return QuestionType.casClinique;
    if (s.contains('qroc')) return QuestionType.qroc;
    return QuestionType.qcm;
  }

  factory QcmQuestion.fromJson(Map<String, dynamic> json) {
    return QcmQuestion(
      id: json['id']?.toString() ?? '',
      moduleId: json['moduleId']?.toString() ?? '',
      courseId: json['courseId']?.toString() ?? '',
      courseName: json['courseName']?.toString() ?? '',
      type: parseType(json['type']),
      questionText: json['questionText']?.toString() ?? '',
      clinicalCaseText: json['clinicalCaseText']?.toString(),
      options: (json['options'] as List<dynamic>?)
              ?.map((o) => QcmOption.fromJson(o as Map<String, dynamic>))
              .toList() ??
          [],
      correctAnswers: (json['correctAnswers'] as List<dynamic>?)
              ?.map((a) => a.toString())
              .toList() ??
          [],
      explanation: json['explanation']?.toString() ?? '',
      source: json['source']?.toString() ?? 'Concours',
      year: (json['year'] is num) ? (json['year'] as num).toInt() : 2024,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'moduleId': moduleId,
        'courseId': courseId,
        'courseName': courseName,
        'type': type.name,
        'questionText': questionText,
        'clinicalCaseText': clinicalCaseText,
        'options': options.map((o) => o.toJson()).toList(),
        'correctAnswers': correctAnswers,
        'explanation': explanation,
        'source': source,
        'year': year,
      };

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
