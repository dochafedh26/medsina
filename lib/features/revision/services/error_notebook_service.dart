import '../../revision/data/residency_repository.dart';
import '../../revision/models/flashcard_fsrs_model.dart';
import '../../revision/models/module_model.dart';
import '../../revision/models/qcm_model.dart';
import '../../revision/services/user_qcm_annotation_service.dart';

class ErrorCourseGroup {
  final String moduleId;
  final String courseId;
  final String courseName;
  final List<UserQuestionAnnotation> annotations;
  final List<QcmQuestion> resolvedQuestions;

  const ErrorCourseGroup({
    required this.moduleId,
    required this.courseId,
    required this.courseName,
    required this.annotations,
    this.resolvedQuestions = const [],
  });

  int get errorCount => annotations.length;
  int get totalWrongAttempts =>
      annotations.fold<int>(0, (sum, a) => sum + a.wrongCount + a.partialCount);
}

class ErrorNotebookService {
  static final ErrorNotebookService instance = ErrorNotebookService._();
  ErrorNotebookService._();

  /// Loads all missed QCMs grouped by course.
  Future<List<ErrorCourseGroup>> loadGroupedErrors() async {
    await UserQcmAnnotationService.instance.ensureInitialized();
    final allAnnotations = UserQcmAnnotationService.instance.annotations;
    final modules = await ResidencyRepository.loadModulesAsync();

    final courseNames = <String, String>{};
    for (final m in modules) {
      for (final c in m.courses) {
        courseNames[c.id] = c.name;
      }
    }

    final missed = allAnnotations.values
        .where((a) => a.isWrongLastTime || a.wrongCount > 0)
        .toList();

    return groupAnnotationsByCourse(
      missed: missed,
      courseNames: courseNames,
    );
  }

  /// Pure grouping helper for unit testing.
  static List<ErrorCourseGroup> groupAnnotationsByCourse({
    required List<UserQuestionAnnotation> missed,
    Map<String, String> courseNames = const {},
  }) {
    final grouped = <String, List<UserQuestionAnnotation>>{};
    for (final ann in missed) {
      final key = ann.courseId.isNotEmpty ? ann.courseId : 'general';
      grouped.putIfAbsent(key, () => []).add(ann);
    }

    final groups = grouped.entries.map((entry) {
      final list = entry.value
        ..sort((a, b) => b.wrongCount.compareTo(a.wrongCount));
      final first = list.first;
      return ErrorCourseGroup(
        moduleId: first.moduleId,
        courseId: entry.key,
        courseName: courseNames[entry.key] ??
            (entry.key == 'general' ? 'Questions diverses' : entry.key),
        annotations: list,
      );
    }).toList()
      ..sort((a, b) => b.errorCount.compareTo(a.errorCount));

    return groups;
  }

  /// Resolves the actual [QcmQuestion] objects for a given error group.
  Future<List<QcmQuestion>> resolveQuestionsForGroup(
      ErrorCourseGroup group) async {
    if (group.moduleId.isEmpty) return const [];
    final course = CourseModel(
      id: group.courseId,
      moduleId: group.moduleId,
      name: group.courseName,
      questionsCount: group.errorCount,
      hasPdf: false,
    );
    final courseQuestions =
        await ResidencyRepository.getQuestionsForCourseAsync(course);
    final ids = group.annotations.map((a) => a.questionId).toSet();
    final matched = courseQuestions.where((q) => ids.contains(q.id)).toList();
    return matched.isNotEmpty ? matched : courseQuestions;
  }

  /// Converts a list of missed QCM questions into FSRS v4.5 flashcards in bulk.
  Future<int> convertQuestionsToFsrsFlashcards(
      List<QcmQuestion> questions) async {
    if (questions.isEmpty) return 0;
    final fsrs = FlashcardFsrsService.instance;
    await fsrs.ensureInitialized();

    int added = 0;
    for (final q in questions) {
      if (fsrs.hasFlashcardForQuestion(q.id)) continue;
      await fsrs.createFromQuestion(q);
      added++;
    }
    return added;
  }
}
