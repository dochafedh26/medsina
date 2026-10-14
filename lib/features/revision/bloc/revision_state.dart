import 'package:equatable/equatable.dart';
import '../models/module_model.dart';
import '../models/qcm_model.dart';
import '../models/revision_session_model.dart';

enum RevisionStatus { initial, loading, loaded, studySession, error }

class RevisionState extends Equatable {
  final RevisionStatus status;
  final List<MedicalModuleModel> modules;
  final MedicalModuleModel? selectedModule;
  final CourseModel? selectedCourse;
  final List<QcmQuestion> currentQuestions;
  final int currentQuestionIndex;
  // Map of questionId -> Set of selected keys {'A', 'C'}
  final Map<String, Set<String>> userAnswers;
  // Set of questionId where answer has been revealed
  final Set<String> revealedQuestions;
  final String? errorMessage;

  // Persistence & Custom Session fields
  final String sessionTitle;
  final bool isCustomSession;
  final CustomRevisionSession? activeCustomSession;
  final Map<String, CourseRevisionProgress> activeCourseProgresses;
  final List<CustomRevisionSession> customSessions;

  const RevisionState({
    this.status = RevisionStatus.initial,
    this.modules = const [],
    this.selectedModule,
    this.selectedCourse,
    this.currentQuestions = const [],
    this.currentQuestionIndex = 0,
    this.userAnswers = const {},
    this.revealedQuestions = const {},
    this.errorMessage,
    this.sessionTitle = 'Révision QCM',
    this.isCustomSession = false,
    this.activeCustomSession,
    this.activeCourseProgresses = const {},
    this.customSessions = const [],
  });

  QcmQuestion? get activeQuestion =>
      currentQuestions.isNotEmpty && currentQuestionIndex < currentQuestions.length
          ? currentQuestions[currentQuestionIndex]
          : null;

  bool get isCurrentAnswerRevealed =>
      activeQuestion != null && revealedQuestions.contains(activeQuestion!.id);

  Set<String> get currentSelectedOptions =>
      activeQuestion != null ? (userAnswers[activeQuestion!.id] ?? {}) : {};

  bool get isCurrentAnswerFullyCorrect {
    if (activeQuestion == null) return false;
    final selected = currentSelectedOptions;
    final correct = activeQuestion!.correctAnswers.toSet();
    return selected.length == correct.length && selected.containsAll(correct);
  }

  RevisionState copyWith({
    RevisionStatus? status,
    List<MedicalModuleModel>? modules,
    MedicalModuleModel? selectedModule,
    CourseModel? selectedCourse,
    List<QcmQuestion>? currentQuestions,
    int? currentQuestionIndex,
    Map<String, Set<String>>? userAnswers,
    Set<String>? revealedQuestions,
    String? errorMessage,
    String? sessionTitle,
    bool? isCustomSession,
    CustomRevisionSession? activeCustomSession,
    Map<String, CourseRevisionProgress>? activeCourseProgresses,
    List<CustomRevisionSession>? customSessions,
  }) {
    return RevisionState(
      status: status ?? this.status,
      modules: modules ?? this.modules,
      selectedModule: selectedModule ?? this.selectedModule,
      selectedCourse: selectedCourse ?? this.selectedCourse,
      currentQuestions: currentQuestions ?? this.currentQuestions,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      userAnswers: userAnswers ?? this.userAnswers,
      revealedQuestions: revealedQuestions ?? this.revealedQuestions,
      errorMessage: errorMessage ?? this.errorMessage,
      sessionTitle: sessionTitle ?? this.sessionTitle,
      isCustomSession: isCustomSession ?? this.isCustomSession,
      activeCustomSession: activeCustomSession ?? this.activeCustomSession,
      activeCourseProgresses: activeCourseProgresses ?? this.activeCourseProgresses,
      customSessions: customSessions ?? this.customSessions,
    );
  }

  @override
  List<Object?> get props => [
        status,
        modules,
        selectedModule,
        selectedCourse,
        currentQuestions,
        currentQuestionIndex,
        userAnswers,
        revealedQuestions,
        errorMessage,
        sessionTitle,
        isCustomSession,
        activeCustomSession,
        activeCourseProgresses,
        customSessions,
      ];
}
