import 'package:equatable/equatable.dart';

class CourseModel extends Equatable {
  final String id;
  final String moduleId;
  final String name;
  final int questionsCount;
  final bool hasPdf;
  final String? pdfDownloadUrl;
  final String? pdfDriveId;
  final int completedQuestions;

  const CourseModel({
    required this.id,
    required this.moduleId,
    required this.name,
    required this.questionsCount,
    this.hasPdf = true,
    this.pdfDownloadUrl,
    this.pdfDriveId,
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
    String? pdfDriveId,
    int? completedQuestions,
  }) {
    return CourseModel(
      id: id ?? this.id,
      moduleId: moduleId ?? this.moduleId,
      name: name ?? this.name,
      questionsCount: questionsCount ?? this.questionsCount,
      hasPdf: hasPdf ?? this.hasPdf,
      pdfDownloadUrl: pdfDownloadUrl ?? this.pdfDownloadUrl,
      pdfDriveId: pdfDriveId ?? this.pdfDriveId,
      completedQuestions: completedQuestions ?? this.completedQuestions,
    );
  }

  factory CourseModel.fromJson(Map<String, dynamic> json) {
    return CourseModel(
      id: json['id'] as String,
      moduleId: (json['module_id'] ?? json['moduleId'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      questionsCount: (json['questions_count'] ?? json['questionsCount'] ?? 0) as int,
      hasPdf: (json['has_pdf'] ?? json['hasPdf'] ?? true) as bool,
      pdfDownloadUrl: (json['pdf_url'] ?? json['pdfDownloadUrl']) as String?,
      pdfDriveId: (json['pdf_drive_id'] ?? json['pdfDriveId']) as String?,
      completedQuestions: (json['completedQuestions'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'moduleId': moduleId,
        'name': name,
        'questionsCount': questionsCount,
        'hasPdf': hasPdf,
        'pdfDownloadUrl': pdfDownloadUrl,
        'pdfDriveId': pdfDriveId,
        'completedQuestions': completedQuestions,
      };

  @override
  List<Object?> get props => [
        id,
        moduleId,
        name,
        questionsCount,
        hasPdf,
        pdfDownloadUrl,
        pdfDriveId,
        completedQuestions,
      ];
}

class MedicalModuleModel extends Equatable {
  final String id;
  final String name;
  final String category; // '1ère Année (Fondamental)', 'Clinique & Concours Résidanat', etc.
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

  factory MedicalModuleModel.fromJson(Map<String, dynamic> json) {
    final rawCourses = json['courses'] as List<dynamic>? ?? [];
    return MedicalModuleModel(
      id: json['id'] as String,
      name: (json['name'] ?? '') as String,
      category: (json['category'] ?? 'Clinique & Concours Résidanat') as String,
      totalQuestions: (json['total_questions'] ?? json['totalQuestions'] ?? 0) as int,
      totalCourses: (json['total_courses'] ?? json['totalCourses'] ?? rawCourses.length) as int,
      iconName: (json['icon_name'] ?? json['iconName'] ?? 'medical') as String,
      courses: rawCourses.map((c) => CourseModel.fromJson(c as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'totalQuestions': totalQuestions,
        'totalCourses': totalCourses,
        'iconName': iconName,
        'courses': courses.map((c) => c.toJson()).toList(),
      };

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
