import 'package:equatable/equatable.dart';
import '../models/module_model.dart';
import '../models/revision_session_model.dart';

abstract class RevisionEvent extends Equatable {
  const RevisionEvent();

  @override
  List<Object?> get props => [];
}

class LoadModulesEvent extends RevisionEvent {}

class LoadSavedSessionsEvent extends RevisionEvent {}

class SelectModuleEvent extends RevisionEvent {
  final MedicalModuleModel module;

  const SelectModuleEvent(this.module);

  @override
  List<Object?> get props => [module];
}

class OpenCourseQuestionsEvent extends RevisionEvent {
  final CourseModel course;
  final bool resume;
  final bool filterForStudent;

  const OpenCourseQuestionsEvent(this.course, {this.resume = false, this.filterForStudent = false});

  @override
  List<Object?> get props => [course, resume, filterForStudent];
}

class PauseCurrentSessionEvent extends RevisionEvent {}

class StartCustomSessionEvent extends RevisionEvent {
  final CustomRevisionSession session;
  final bool resume;
  final bool filterForStudent;

  const StartCustomSessionEvent(this.session, {this.resume = false, this.filterForStudent = false});

  @override
  List<Object?> get props => [session, resume, filterForStudent];
}

class DeleteCustomSessionEvent extends RevisionEvent {
  final String sessionId;

  const DeleteCustomSessionEvent(this.sessionId);

  @override
  List<Object?> get props => [sessionId];
}

class ToggleOptionSelectionEvent extends RevisionEvent {
  final String questionId;
  final String optionKey;

  const ToggleOptionSelectionEvent({required this.questionId, required this.optionKey});

  @override
  List<Object?> get props => [questionId, optionKey];
}

class RevealAnswerEvent extends RevisionEvent {
  final String questionId;

  const RevealAnswerEvent(this.questionId);

  @override
  List<Object?> get props => [questionId];
}

class NextQuestionEvent extends RevisionEvent {}

class PreviousQuestionEvent extends RevisionEvent {}

class ResetSessionEvent extends RevisionEvent {
  final bool clearSavedProgress;

  const ResetSessionEvent({this.clearSavedProgress = false});

  @override
  List<Object?> get props => [clearSavedProgress];
}
