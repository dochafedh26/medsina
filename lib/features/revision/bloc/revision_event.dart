import 'package:equatable/equatable.dart';
import '../models/module_model.dart';

abstract class RevisionEvent extends Equatable {
  const RevisionEvent();

  @override
  List<Object?> get props => [];
}

class LoadModulesEvent extends RevisionEvent {}

class SelectModuleEvent extends RevisionEvent {
  final MedicalModuleModel module;

  const SelectModuleEvent(this.module);

  @override
  List<Object?> get props => [module];
}

class OpenCourseQuestionsEvent extends RevisionEvent {
  final CourseModel course;

  const OpenCourseQuestionsEvent(this.course);

  @override
  List<Object?> get props => [course];
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

class ResetSessionEvent extends RevisionEvent {}
