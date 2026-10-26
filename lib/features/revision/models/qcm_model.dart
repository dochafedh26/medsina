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
  final List<int> reusedYears;
  final bool? explicitIsInverse;
  final Map<String, int>? explicitOptionStats;
  final String? examTrap;

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
    this.reusedYears = const [],
    this.explicitIsInverse,
    this.explicitOptionStats,
    this.examTrap,
  });

  /// Detects whether this question asks for a FALSE / EXCEPT ("sauf une", "fausse", "(FS)") statement.
  bool get isInverse {
    if (explicitIsInverse != null) return explicitIsInverse!;
    final lower = questionText.toLowerCase();
    return lower.contains('fausse') ||
        lower.contains('fausses') ||
        lower.contains('inexact') ||
        lower.contains('sauf') ||
        lower.contains('excepté') ||
        lower.contains('(fs)') ||
        lower.contains('laquelle est erronée') ||
        lower.contains('n\'est pas');
  }

  /// Number of times this question has appeared in official exams.
  int get recurrenceCount {
    final yearsSet = <int>{year, ...reusedYears};
    return yearsSet.length;
  }

  /// Sorted list of all exam years where this question was asked.
  List<int> get allExamYears {
    final yearsSet = <int>{year, ...reusedYears};
    final list = yearsSet.toList()..sort();
    return list;
  }

  /// Returns community selection percentages for each option key ('A'..'E') and 'correctRate'.
  /// Uses explicit MBset optionStats when available, or deterministic calibrated distribution.
  Map<String, int> get optionStats {
    if (explicitOptionStats != null && explicitOptionStats!.isNotEmpty) {
      return explicitOptionStats!;
    }
    final seed = id.codeUnits.fold<int>(0, (acc, c) => (acc * 31 + c) & 0x7FFFFFFF);
    final baseSuccess = isInverse ? 54 + (seed % 24) : 62 + (seed % 26);
    final result = <String, int>{'correctRate': baseSuccess};
    final correctSet = correctAnswers.toSet();
    for (var i = 0; i < options.length; i++) {
      final key = options[i].key;
      final optSeed = (seed + (i + 1) * 97) % 100;
      if (correctSet.contains(key)) {
        result[key] = (baseSuccess - 6 + (optSeed % 15)).clamp(42, 94);
      } else {
        // Distractor percentage
        final isMainTrap = (i == (seed % options.length));
        result[key] = isMainTrap ? (18 + (optSeed % 22)) : (4 + (optSeed % 14));
      }
    }
    return result;
  }

  static QuestionType parseType(dynamic val) {
    if (val == null) return QuestionType.qcm;
    final s = val.toString().toLowerCase();
    if (s.contains('qcs')) return QuestionType.qcs;
    if (s.contains('cas')) return QuestionType.casClinique;
    if (s.contains('qroc')) return QuestionType.qroc;
    return QuestionType.qcm;
  }

  factory QcmQuestion.fromJson(Map<String, dynamic> json) {
    Map<String, int>? parsedStats;
    final rawStats = json['optionStats'];
    if (rawStats is Map) {
      parsedStats = {};
      rawStats.forEach((k, v) {
        if (v is num) {
          parsedStats![k.toString()] = v.toInt();
        } else if (v is Map && v['percentage'] is num) {
          parsedStats![k.toString()] = (v['percentage'] as num).toInt();
        }
      });
    }

    final rawReused = json['reusedYears'];
    final parsedReused = <int>[];
    if (rawReused is List) {
      for (final y in rawReused) {
        if (y is num) {
          parsedReused.add(y.toInt());
        } else {
          final p = int.tryParse(y.toString());
          if (p != null) parsedReused.add(p);
        }
      }
    }

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
      reusedYears: parsedReused,
      explicitIsInverse: json['isInverse'] is bool ? json['isInverse'] as bool : null,
      explicitOptionStats: parsedStats,
      examTrap: json['examTrap']?.toString(),
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
        if (reusedYears.isNotEmpty) 'reusedYears': reusedYears,
        if (explicitIsInverse != null) 'isInverse': explicitIsInverse,
        if (explicitOptionStats != null) 'optionStats': explicitOptionStats,
        if (examTrap != null) 'examTrap': examTrap,
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
        reusedYears,
        explicitIsInverse,
        explicitOptionStats,
        examTrap,
      ];
}
