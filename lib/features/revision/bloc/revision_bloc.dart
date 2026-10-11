import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/residency_repository.dart';
import 'revision_event.dart';
import 'revision_state.dart';

class RevisionBloc extends Bloc<RevisionEvent, RevisionState> {
  RevisionBloc() : super(const RevisionState()) {
    on<LoadModulesEvent>(_onLoadModules);
    on<SelectModuleEvent>(_onSelectModule);
    on<OpenCourseQuestionsEvent>(_onOpenCourseQuestions);
    on<ToggleOptionSelectionEvent>(_onToggleOptionSelection);
    on<RevealAnswerEvent>(_onRevealAnswer);
    on<NextQuestionEvent>(_onNextQuestion);
    on<PreviousQuestionEvent>(_onPreviousQuestion);
    on<ResetSessionEvent>(_onResetSession);
  }

  Future<void> _onLoadModules(LoadModulesEvent event, Emitter<RevisionState> emit) async {
    emit(state.copyWith(status: RevisionStatus.loading));
    try {
      final mods = await ResidencyRepository.loadModulesAsync();
      emit(state.copyWith(
        status: RevisionStatus.loaded,
        modules: mods,
        selectedModule: mods.isNotEmpty ? mods.first : null,
      ));
    } catch (e) {
      final fallback = ResidencyRepository.getModules();
      emit(state.copyWith(
        status: RevisionStatus.loaded,
        modules: fallback,
        selectedModule: fallback.isNotEmpty ? fallback.first : null,
      ));
    }
  }

  void _onSelectModule(SelectModuleEvent event, Emitter<RevisionState> emit) {
    emit(state.copyWith(selectedModule: event.module));
  }

  void _onOpenCourseQuestions(OpenCourseQuestionsEvent event, Emitter<RevisionState> emit) {
    emit(state.copyWith(status: RevisionStatus.loading));
    final questions = ResidencyRepository.getQuestionsForCourse(event.course.id);
    emit(state.copyWith(
      status: RevisionStatus.studySession,
      selectedCourse: event.course,
      currentQuestions: questions,
      currentQuestionIndex: 0,
      userAnswers: {},
      revealedQuestions: {},
    ));
  }

  void _onToggleOptionSelection(ToggleOptionSelectionEvent event, Emitter<RevisionState> emit) {
    // If answer already revealed, don't allow modifying
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
  }

  void _onRevealAnswer(RevealAnswerEvent event, Emitter<RevisionState> emit) {
    final updatedRevealed = Set<String>.from(state.revealedQuestions);
    updatedRevealed.add(event.questionId);
    emit(state.copyWith(revealedQuestions: updatedRevealed));
  }

  void _onNextQuestion(NextQuestionEvent event, Emitter<RevisionState> emit) {
    if (state.currentQuestionIndex < state.currentQuestions.length - 1) {
      emit(state.copyWith(currentQuestionIndex: state.currentQuestionIndex + 1));
    }
  }

  void _onPreviousQuestion(PreviousQuestionEvent event, Emitter<RevisionState> emit) {
    if (state.currentQuestionIndex > 0) {
      emit(state.copyWith(currentQuestionIndex: state.currentQuestionIndex - 1));
    }
  }

  void _onResetSession(ResetSessionEvent event, Emitter<RevisionState> emit) {
    emit(state.copyWith(
      status: RevisionStatus.loaded,
      currentQuestions: [],
      currentQuestionIndex: 0,
      userAnswers: {},
      revealedQuestions: {},
    ));
  }
}
