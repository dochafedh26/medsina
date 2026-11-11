import 'package:equatable/equatable.dart';
 
enum CourseContentFilter {
  all,
  complete,
  pdfOnly,
  withMindmap,
  withSummary,
  withQcm,
  highYield,
  incomplete,
}

class CourseModel extends Equatable {
  final String id;
  final String moduleId;
  final String name;
  final int questionsCount;
  final bool hasPdf;
  final String? pdfDownloadUrl;
  final String? pdfDriveId;
  final int completedQuestions;
  final String? bundlePdfUrl;
  final String? bundleGeneratedAt;
  final bool isHypertombable;
  final List<String> residanatYears;
  final String? teacher;
  final String? mindmapPdfUrl;
  final String? mindmapDriveId;
  final bool hasMindmap;
  final String? mindmapGeneratedAt;

  const CourseModel({
    required this.id,
    required this.moduleId,
    required this.name,
    required this.questionsCount,
    this.hasPdf = true,
    this.pdfDownloadUrl,
    this.pdfDriveId,
    this.completedQuestions = 0,
    this.bundlePdfUrl,
    this.bundleGeneratedAt,
    this.isHypertombable = false,
    this.residanatYears = const [],
    this.teacher,
    this.mindmapPdfUrl,
    this.mindmapDriveId,
    this.hasMindmap = false,
    this.mindmapGeneratedAt,
  });

  bool get hasAnyPdf =>
      hasPdf ||
      (pdfDownloadUrl != null && pdfDownloadUrl!.isNotEmpty) ||
      (pdfDriveId != null && pdfDriveId!.isNotEmpty);

  bool get hasAnyMindmap =>
      hasMindmap ||
      (mindmapPdfUrl != null && mindmapPdfUrl!.isNotEmpty) ||
      (mindmapDriveId != null && mindmapDriveId!.isNotEmpty);

  bool isCompleteCourse({bool hasSummary = false}) =>
      hasAnyPdf && hasAnyMindmap && (questionsCount > 0 || hasSummary);

  bool isPdfOnlyCourse({bool hasSummary = false}) =>
      hasAnyPdf && !hasAnyMindmap && questionsCount == 0 && !hasSummary;

  bool get isHighYield => isHypertombable || questionsCount >= 20;

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
    String? bundlePdfUrl,
    String? bundleGeneratedAt,
    bool? isHypertombable,
    List<String>? residanatYears,
    String? teacher,
    String? mindmapPdfUrl,
    String? mindmapDriveId,
    bool? hasMindmap,
    String? mindmapGeneratedAt,
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
      bundlePdfUrl: bundlePdfUrl ?? this.bundlePdfUrl,
      bundleGeneratedAt: bundleGeneratedAt ?? this.bundleGeneratedAt,
      isHypertombable: isHypertombable ?? this.isHypertombable,
      residanatYears: residanatYears ?? this.residanatYears,
      teacher: teacher ?? this.teacher,
      mindmapPdfUrl: mindmapPdfUrl ?? this.mindmapPdfUrl,
      mindmapDriveId: mindmapDriveId ?? this.mindmapDriveId,
      hasMindmap: hasMindmap ?? this.hasMindmap,
      mindmapGeneratedAt: mindmapGeneratedAt ?? this.mindmapGeneratedAt,
    );
  }

  factory CourseModel.fromJson(Map<String, dynamic> json) {
    final rawQuestionsCount = (json['questions_count'] ?? json['questionsCount'] ?? 0) as int;
    final rawQcmCount = (json['qcm_count'] ?? json['qcmCount'] ?? 0) as int;
    final rawMmUrl = (json['mindmap_pdf_url'] ?? json['mindmapPdfUrl']) as String?;
    final rawMmDriveId = (json['mindmap_drive_id'] ?? json['mindmapDriveId']) as String?;
    final rawHasMm = (json['has_mindmap'] ?? json['hasMindmap'] ?? (rawMmUrl != null || rawMmDriveId != null)) as bool;

    return CourseModel(
      id: json['id'] as String,
      moduleId: (json['module_id'] ?? json['moduleId'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      questionsCount: rawQuestionsCount > 0 ? rawQuestionsCount : rawQcmCount,
      hasPdf: (json['has_pdf'] ?? json['hasPdf'] ?? true) as bool,
      pdfDownloadUrl: (json['pdf_url'] ?? json['pdfDownloadUrl']) as String?,
      pdfDriveId: (json['pdf_drive_id'] ?? json['pdfDriveId']) as String?,
      completedQuestions: (json['completedQuestions'] ?? 0) as int,
      bundlePdfUrl: (json['bundle_pdf_url'] ?? json['bundlePdfUrl']) as String?,
      bundleGeneratedAt: (json['bundle_generated_at'] ?? json['bundleGeneratedAt'])?.toString(),
      isHypertombable: (json['is_hypertombable'] ?? json['isHypertombable'] ?? false) as bool,
      residanatYears: (json['residanat_years'] is List)
          ? (json['residanat_years'] as List).map((e) => e.toString()).toList()
          : (json['residanatYears'] is List)
              ? (json['residanatYears'] as List).map((e) => e.toString()).toList()
              : const [],
      teacher: (json['teacher'] ?? json['professor']) as String?,
      mindmapPdfUrl: rawMmUrl,
      mindmapDriveId: rawMmDriveId,
      hasMindmap: rawHasMm,
      mindmapGeneratedAt: (json['mindmap_generated_at'] ?? json['mindmapGeneratedAt'])?.toString(),
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
        'bundle_pdf_url': bundlePdfUrl,
        'bundle_generated_at': bundleGeneratedAt,
        'is_hypertombable': isHypertombable,
        'residanat_years': residanatYears,
        'teacher': teacher,
        'mindmap_pdf_url': mindmapPdfUrl,
        'mindmap_drive_id': mindmapDriveId,
        'has_mindmap': hasMindmap,
        'mindmap_generated_at': mindmapGeneratedAt,
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
        bundlePdfUrl,
        bundleGeneratedAt,
        isHypertombable,
        residanatYears,
        teacher,
        mindmapPdfUrl,
        mindmapDriveId,
        hasMindmap,
        mindmapGeneratedAt,
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
