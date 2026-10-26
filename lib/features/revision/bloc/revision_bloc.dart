import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/residency_repository.dart';
import '../models/flashcard_fsrs_model.dart';
import '../models/revision_session_model.dart';
import '../services/revision_session_storage.dart';
import '../services/user_qcm_annotation_service.dart';
import 'revision_event.dart';
import 'revision_state.dart';

class RevisionBloc extends Bloc<RevisionEvent, RevisionState> {
  final RevisionSessionStorage _storage = RevisionSessionStorage.instance;

  RevisionBloc() : super(const RevisionState()) {
    on<LoadModulesEvent>(_onLoadModules);
    on<LoadSavedSessionsEvent>(_onLoadSavedSessions);
    on<SelectModuleEvent>(_onSelectModule);
    on<OpenCourseQuestionsEvent>(_onOpenCourseQuestions);
    on<PauseCurrentSessionEvent>(_onPauseCurrentSession);
    on<StartCustomSessionEvent>(_onStartCustomSession);
    on<DeleteCustomSessionEvent>(_onDeleteCustomSession);
    on<ToggleOptionSelectionEvent>(_onToggleOptionSelection);
    on<RevealAnswerEvent>(_onRevealAnswer);
    on<NextQuestionEvent>(_onNextQuestion);
    on<PreviousQuestionEvent>(_onPreviousQuestion);
    on<ResetSessionEvent>(_onResetSession);
  }

  Future<void> _onLoadModules(LoadModulesEvent event, Emitter<RevisionState> emit) async {
    emit(state.copyWith(status: RevisionStatus.loading));
    try {
      await UserQcmAnnotationService.instance.ensureInitialized();
      await FlashcardFsrsService.instance.ensureInitialized();
      final mods = await ResidencyRepository.loadModulesAsync();
      final progresses = await _storage.getAllCourseProgress();
      final customSessions = await _storage.getCustomSessions();

      emit(state.copyWith(
        status: RevisionStatus.loaded,
        modules: mods,
        selectedModule: mods.isNotEmpty ? mods.first : null,
        activeCourseProgresses: progresses,
        customSessions: customSessions,
      ));
    } catch (e) {
      final fallback = ResidencyRepository.getModules();
      final progresses = await _storage.getAllCourseProgress();
      final customSessions = await _storage.getCustomSessions();

      emit(state.copyWith(
        status: RevisionStatus.loaded,
        modules: fallback,
        selectedModule: fallback.isNotEmpty ? fallback.first : null,
        activeCourseProgresses: progresses,
        customSessions: customSessions,
      ));
    }
  }

  Future<void> _onLoadSavedSessions(LoadSavedSessionsEvent event, Emitter<RevisionState> emit) async {
    final progresses = await _storage.getAllCourseProgress();
    final customSessions = await _storage.getCustomSessions();
    emit(state.copyWith(
      activeCourseProgresses: progresses,
      customSessions: customSessions,
    ));
  }

  void _onSelectModule(SelectModuleEvent event, Emitter<RevisionState> emit) {
    emit(state.copyWith(selectedModule: event.module));
  }

  Future<void> _onOpenCourseQuestions(OpenCourseQuestionsEvent event, Emitter<RevisionState> emit) async {
    emit(state.copyWith(
      status: RevisionStatus.loading,
      selectedCourse: event.course,
      sessionTitle: event.course.name,
      isCustomSession: false,
      activeCustomSession: null,
      currentQuestions: [],
      currentQuestionIndex: 0,
      userAnswers: {},
      revealedQuestions: {},
    ));

    var questions = await ResidencyRepository.getQuestionsForCourseAsync(event.course);
    if (event.filterForStudent) {
      questions = ResidencyRepository.filterQuestionsForStudent(questions);
    }

    if (event.resume) {
      final saved = await _storage.getCourseProgress(event.course.id);
      if (saved != null) {
        final safeIndex = (saved.currentQuestionIndex >= 0 && saved.currentQuestionIndex < questions.length)
            ? saved.currentQuestionIndex
            : 0;

        emit(state.copyWith(
          status: RevisionStatus.studySession,
          selectedCourse: event.course,
          sessionTitle: event.course.name,
          isCustomSession: false,
          activeCustomSession: null,
          currentQuestions: questions,
          currentQuestionIndex: safeIndex,
          userAnswers: saved.userAnswers,
          revealedQuestions: saved.revealedQuestions,
        ));
        return;
      }
    }

    // Fresh start: clear previous progress if restarting from zero
    if (!event.resume) {
      await _storage.clearCourseProgress(event.course.id);
    }

    emit(state.copyWith(
      status: RevisionStatus.studySession,
      selectedCourse: event.course,
      sessionTitle: event.course.name,
      isCustomSession: false,
      activeCustomSession: null,
      currentQuestions: questions,
      currentQuestionIndex: 0,
      userAnswers: {},
      revealedQuestions: {},
    ));

    _autoSaveProgress();
  }

  Future<void> _onStartCustomSession(StartCustomSessionEvent event, Emitter<RevisionState> emit) async {
    emit(state.copyWith(
      status: RevisionStatus.loading,
      sessionTitle: event.session.title,
      isCustomSession: true,
      activeCustomSession: event.session,
      currentQuestions: [],
      currentQuestionIndex: 0,
      userAnswers: {},
      revealedQuestions: {},
    ));

    await UserQcmAnnotationService.instance.ensureInitialized();
    final annService = UserQcmAnnotationService.instance;

    // Fetch full pool first, then apply MBset+ advanced filters before limiting
    final rawPool = await ResidencyRepository.getQuestionsForMultipleCoursesAsync(
      courseIds: event.session.courseIds,
      moduleIds: event.session.moduleIds,
      limit: -1,
      shuffle: event.resume ? false : event.session.shuffleQuestions,
    );

    final allowedSet = event.session.allowedTypes.map((e) => e.toLowerCase()).toSet();
    var filtered = rawPool.where((q) {
      if (allowedSet.isNotEmpty && !allowedSet.contains(q.type.name.toLowerCase())) {
        return false;
      }
      if (event.session.minYear != null && q.year < event.session.minYear!) {
        return false;
      }
      if (event.session.maxYear != null && q.year > event.session.maxYear!) {
        return false;
      }
      final ann = annService.getAnnotation(q.id);
      switch (event.session.historyFilter) {
        case 'unseen':
          return !ann.isConsulted;
        case 'wrong':
          return ann.isWrongLastTime;
        case 'marked':
          return ann.isMarked;
        case 'withNotes':
          return ann.hasNote;
        case 'highYield':
          return q.recurrenceCount > 1 || q.isInverse;
        default:
          return true;
      }
    }).toList();

    // Graceful fallback if strict personal filter yielded 0 questions
    if (filtered.isEmpty) {
      filtered = rawPool;
    }

    final limit = event.session.questionLimit;
    final questions = (limit > 0 && filtered.length > limit)
        ? filtered.take(limit).toList()
        : filtered;

    if (event.resume) {
      final safeIndex = (event.session.currentQuestionIndex >= 0 &&
              event.session.currentQuestionIndex < questions.length)
          ? event.session.currentQuestionIndex
          : 0;

      emit(state.copyWith(
        status: RevisionStatus.studySession,
        sessionTitle: event.session.title,
        isCustomSession: true,
        activeCustomSession: event.session,
        currentQuestions: questions,
        currentQuestionIndex: safeIndex,
        userAnswers: event.session.userAnswers,
        revealedQuestions: event.session.revealedQuestions,
      ));
      return;
    }

    final updatedSession = event.session.copyWith(
      totalQuestions: questions.length,
      currentQuestionIndex: 0,
      userAnswers: {},
      revealedQuestions: {},
      isCompleted: false,
      lastActiveAt: DateTime.now(),
    );
    await _storage.saveCustomSession(updatedSession);

    emit(state.copyWith(
      status: RevisionStatus.studySession,
      sessionTitle: event.session.title,
      isCustomSession: true,
      activeCustomSession: updatedSession,
      currentQuestions: questions,
      currentQuestionIndex: 0,
      userAnswers: {},
      revealedQuestions: {},
    ));

    _autoSaveProgress();
  }

  Future<void> _onPauseCurrentSession(PauseCurrentSessionEvent event, Emitter<RevisionState> emit) async {
    await _autoSaveProgress();
    final progresses = await _storage.getAllCourseProgress();
    final customSessions = await _storage.getCustomSessions();

    emit(state.copyWith(
      status: RevisionStatus.loaded,
      activeCourseProgresses: progresses,
      customSessions: customSessions,
      currentQuestions: [],
      currentQuestionIndex: 0,
      userAnswers: {},
      revealedQuestions: {},
    ));
  }

  Future<void> _onDeleteCustomSession(DeleteCustomSessionEvent event, Emitter<RevisionState> emit) async {
    await _storage.deleteCustomSession(event.sessionId);
    final customSessions = await _storage.getCustomSessions();
    emit(state.copyWith(customSessions: customSessions));
  }

  void _onToggleOptionSelection(ToggleOptionSelectionEvent event, Emitter<RevisionState> emit) {
    if (state.revealedQuestions.contains(event.questionId)) return;

    final updatedMap = Map<String, Set<String>>.from(state.userAnswers);
    final currentSet = Set<String>.from(updatedMap[event.questionId] ?? {});

    if (currentSet.contains(event.optionKey)) {
      currentSet.remove(event.optionKey);
    } else {
      currentSet.add(event.optionKey);
    }

    updatedMap[event.questionId] = currentSet;
    emit(state.copyWith(userAnswers: updatedMap));
    _autoSaveProgress();
  }

  void _onRevealAnswer(RevealAnswerEvent event, Emitter<RevisionState> emit) {
    final updatedRevealed = Set<String>.from(state.revealedQuestions);
    updatedRevealed.add(event.questionId);
    emit(state.copyWith(revealedQuestions: updatedRevealed));

    final q = state.activeQuestion;
    if (q != null && q.id == event.questionId) {
      final selected = state.userAnswers[q.id] ?? const <String>{};
      UserQcmAnnotationService.instance.recordQuestionAttempt(
        questionId: q.id,
        moduleId: q.moduleId,
        courseId: q.courseId,
        selectedOptions: selected,
        correctAnswers: q.correctAnswers,
      );
    }

    _autoSaveProgress();
  }

  void _onNextQuestion(NextQuestionEvent event, Emitter<RevisionState> emit) {
    if (state.currentQuestionIndex < state.currentQuestions.length - 1) {
      emit(state.copyWith(currentQuestionIndex: state.currentQuestionIndex + 1));
      _autoSaveProgress();
    }
  }

  void _onPreviousQuestion(PreviousQuestionEvent event, Emitter<RevisionState> emit) {
    if (state.currentQuestionIndex > 0) {
      emit(state.copyWith(currentQuestionIndex: state.currentQuestionIndex - 1));
      _autoSaveProgress();
    }
  }

  Future<void> _onResetSession(ResetSessionEvent event, Emitter<RevisionState> emit) async {
    if (event.clearSavedProgress) {
      if (!state.isCustomSession && state.selectedCourse != null) {
        await _storage.clearCourseProgress(state.selectedCourse!.id);
      } else if (state.isCustomSession && state.activeCustomSession != null) {
        final resetSession = state.activeCustomSession!.copyWith(
          currentQuestionIndex: 0,
          userAnswers: {},
          revealedQuestions: {},
          isCompleted: false,
          lastActiveAt: DateTime.now(),
        );
        await _storage.saveCustomSession(resetSession);
      }
    }

    final progresses = await _storage.getAllCourseProgress();
    final customSessions = await _storage.getCustomSessions();

    emit(state.copyWith(
      status: RevisionStatus.loaded,
      activeCourseProgresses: progresses,
      customSessions: customSessions,
      currentQuestions: [],
      currentQuestionIndex: 0,
      userAnswers: {},
      revealedQuestions: {},
    ));
  }

  Future<void> _autoSaveProgress() async {
    if (state.status != RevisionStatus.studySession || state.currentQuestions.isEmpty) {
      return;
    }

    final isFinished = state.currentQuestionIndex >= state.currentQuestions.length - 1 &&
        state.revealedQuestions.length >= state.currentQuestions.length;

    if (!state.isCustomSession && state.selectedCourse != null) {
      final prog = CourseRevisionProgress(
        courseId: state.selectedCourse!.id,
        courseName: state.selectedCourse!.name,
        moduleId: state.selectedCourse!.moduleId,
        currentQuestionIndex: state.currentQuestionIndex,
        totalQuestions: state.currentQuestions.length,
        userAnswers: state.userAnswers,
        revealedQuestions: state.revealedQuestions,
        isCompleted: isFinished,
        lastActiveAt: DateTime.now(),
      );
      await _storage.saveCourseProgress(prog);
    } else if (state.isCustomSession && state.activeCustomSession != null) {
      final updated = state.activeCustomSession!.copyWith(
        currentQuestionIndex: state.currentQuestionIndex,
        totalQuestions: state.currentQuestions.length,
        userAnswers: state.userAnswers,
        revealedQuestions: state.revealedQuestions,
        isCompleted: isFinished,
        lastActiveAt: DateTime.now(),
      );
      await _storage.saveCustomSession(updated);
    }
  }
}
