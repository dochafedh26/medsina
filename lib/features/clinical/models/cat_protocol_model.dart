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

  factory ClinicalStep.fromJson(Map<String, dynamic> json) {
    return ClinicalStep(
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      bulletPoints: (json['bulletPoints'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          (json['bullet_points'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          [],
    );
  }
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

  factory ClinicalProtocol.fromJson(Map<String, dynamic> json) {
    return ClinicalProtocol(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      specialty: json['specialty'] as String? ?? '',
      urgencyLevel: json['urgency_level'] as String? ?? 'Urgence Vitale',
      definition: json['definition'] as String? ?? '',
      redFlags: (json['red_flags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      steps: (json['steps'] as List<dynamic>?)?.map((s) {
        if (s is Map<String, dynamic>) {
          return ClinicalStep.fromJson(s);
        }
        return ClinicalStep(title: '', content: s.toString());
      }).toList() ?? [],
      treatments: (json['treatments'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      references: (json['scientific_references'] as String?) ?? (json['references'] as String?) ?? '',
    );
  }

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
