import 'package:equatable/equatable.dart';

class CourseSummaryModel extends Equatable {
  final String courseId;
  final String courseName;
  final String moduleId;
  final String moduleName;
  final String summaryMarkdown;
  final List<String> keyTakeaways;
  final List<String> examTraps;
  final String? diagnosticCriteria;
  final String? treatmentSummary;
  final String targetAudience;
  final DateTime updatedAt;

  const CourseSummaryModel({
    required this.courseId,
    required this.courseName,
    required this.moduleId,
    required this.moduleName,
    required this.summaryMarkdown,
    required this.keyTakeaways,
    required this.examTraps,
    this.diagnosticCriteria,
    this.treatmentSummary,
    this.targetAudience = 'Concours Résidanat 2027',
    required this.updatedAt,
  });

  factory CourseSummaryModel.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      return [];
    }

    return CourseSummaryModel(
      courseId: (json['course_id'] ?? json['courseId'] ?? '') as String,
      courseName: (json['course_name'] ?? json['courseName'] ?? '') as String,
      moduleId: (json['module_id'] ?? json['moduleId'] ?? '') as String,
      moduleName: (json['module_name'] ?? json['moduleName'] ?? '') as String,
      summaryMarkdown: (json['summary_markdown'] ?? json['summaryMarkdown'] ?? '') as String,
      keyTakeaways: parseList(json['key_takeaways'] ?? json['keyTakeaways']),
      examTraps: parseList(json['exam_traps'] ?? json['examTraps']),
      diagnosticCriteria: (json['diagnostic_criteria'] ?? json['diagnosticCriteria']) as String?,
      treatmentSummary: (json['treatment_summary'] ?? json['treatmentSummary']) as String?,
      targetAudience: (json['target_audience'] ?? json['targetAudience'] ?? 'Concours Résidanat 2027') as String,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'course_id': courseId,
        'course_name': courseName,
        'module_id': moduleId,
        'module_name': moduleName,
        'summary_markdown': summaryMarkdown,
        'key_takeaways': keyTakeaways,
        'exam_traps': examTraps,
        'diagnostic_criteria': diagnosticCriteria,
        'treatment_summary': treatmentSummary,
        'target_audience': targetAudience,
        'updated_at': updatedAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [
        courseId,
        courseName,
        moduleId,
        moduleName,
        summaryMarkdown,
        keyTakeaways,
        examTraps,
        diagnosticCriteria,
        treatmentSummary,
        targetAudience,
        updatedAt,
      ];
}
