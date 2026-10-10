import 'package:equatable/equatable.dart';

class CourseModel extends Equatable {
  final String id;
  final String moduleId;
  final String name;
  final int questionsCount;
  final bool hasPdf;
  final String? pdfDownloadUrl;
  final int completedQuestions;

  const CourseModel({
    required this.id,
    required this.moduleId,
    required this.name,
    required this.questionsCount,
    this.hasPdf = true,
    this.pdfDownloadUrl,
    this.completedQuestions = 0,
  });

  double get progressPercentage =>
      questionsCount > 0 ? (completedQuestions / questionsCount).clamp(0.0, 1.0) : 0.0;

  CourseModel copyWith({
    String? id,
    String? moduleId,
    String? name,
    int? questionsCount,
    bool? hasPdf,
    String? pdfDownloadUrl,
    int? completedQuestions,
  }) {
    return CourseModel(
      id: id ?? this.id,
      moduleId: moduleId ?? this.moduleId,
      name: name ?? this.name,
      questionsCount: questionsCount ?? this.questionsCount,
      hasPdf: hasPdf ?? this.hasPdf,
      pdfDownloadUrl: pdfDownloadUrl ?? this.pdfDownloadUrl,
      completedQuestions: completedQuestions ?? this.completedQuestions,
    );
  }

  @override
  List<Object?> get props => [
        id,
        moduleId,
        name,
        questionsCount,
        hasPdf,
        pdfDownloadUrl,
        completedQuestions,
      ];
}

class MedicalModuleModel extends Equatable {
  final String id;
  final String name;
  final String category; // 'Médecine', 'Chirurgie', 'Biologie / Fondamental'
  final int totalQuestions;
  final int totalCourses;
  final List<CourseModel> courses;
  final String iconName;

  const MedicalModuleModel({
    required this.id,
    required this.name,
    required this.category,
    required this.totalQuestions,
    required this.totalCourses,
    required this.courses,
    this.iconName = 'medical',
  });

  int get totalCompletedQuestions =>
      courses.fold(0, (sum, c) => sum + c.completedQuestions);

  double get overallProgress =>
      totalQuestions > 0 ? (totalCompletedQuestions / totalQuestions).clamp(0.0, 1.0) : 0.0;

  @override
  List<Object?> get props => [
        id,
        name,
        category,
        totalQuestions,
        totalCourses,
        courses,
        iconName,
      ];
}
