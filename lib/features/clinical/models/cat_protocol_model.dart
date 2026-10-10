import 'package:equatable/equatable.dart';

class ClinicalStep extends Equatable {
  final String title;
  final String content;
  final List<String> bulletPoints;

  const ClinicalStep({
    required this.title,
    required this.content,
    this.bulletPoints = const [],
  });

  @override
  List<Object?> get props => [title, content, bulletPoints];
}

class ClinicalProtocol extends Equatable {
  final String id;
  final String title;
  final String specialty;
  final String urgencyLevel; // 'Urgence Vitale', 'Urgence Relative', 'Prise en charge réglée'
  final String definition;
  final List<String> redFlags;
  final List<ClinicalStep> steps;
  final List<String> treatments;
  final String references;

  const ClinicalProtocol({
    required this.id,
    required this.title,
    required this.specialty,
    required this.urgencyLevel,
    required this.definition,
    required this.redFlags,
    required this.steps,
    required this.treatments,
    required this.references,
  });

  @override
  List<Object?> get props => [
        id,
        title,
        specialty,
        urgencyLevel,
        definition,
        redFlags,
        steps,
        treatments,
        references,
      ];
}
