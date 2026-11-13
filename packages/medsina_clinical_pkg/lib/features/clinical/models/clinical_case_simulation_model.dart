import 'package:equatable/equatable.dart';

class ClinicalReasoningCase extends Equatable {
  final String id;
  final String title;
  final String patientSummary;
  final List<String> keyFindings;
  final List<String> reasoningSteps;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const ClinicalReasoningCase({
    required this.id,
    required this.title,
    required this.patientSummary,
    required this.keyFindings,
    required this.reasoningSteps,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  @override
  List<Object?> get props => [
    id,
    title,
    patientSummary,
    keyFindings,
    reasoningSteps,
    question,
    options,
    correctIndex,
    explanation,
  ];
}

class ClinicalCaseSimulatorRepository {
  static const List<ClinicalReasoningCase> sampleCases = [
    ClinicalReasoningCase(
      id: 'acs-1',
      title: 'Syndrome coronaire aigu',
      patientSummary: 'Homme 62 ans, tabagique, douleur constrictive rétrosternale depuis 30 minutes, associated with diaphoresis and nausea.',
      keyFindings: [
        'Douleur thoracique intense, irradiant vers la mâchoire',
        'Diaphoresis et anxiété',
        'Antécédent d’hypertension et tabac',
      ],
      reasoningSteps: [
        'Identifier un tableau typique de douleur ischémique aiguë.',
        'Chercher les signes d’alarme et les facteurs de risque cardiovasculaire.',
        'Faire un ECG et initier la prise en charge en urgence.',
      ],
      question: 'Quelle est la décision prioritaire immédiate ?',
      options: [
        'Prescription d’un traitement anti-inflammatoire puis contrôle ambulatoire',
        'ECG urgent + oxygène si nécessaire + aspirin et prise en charge de l’ACS',
        'Surveillance clinique uniquement sans examen complémentaire',
        'Traitement antalgique seul en attendant l’évolution',
      ],
      correctIndex: 1,
      explanation: 'Le tableau correspond à un syndrome coronaire aigu jusqu’à preuve du contraire. L’ECG en urgence avec prise en charge immédiate (aspirine, oxygène si hypoxie, monitorage) est prioritaire.',
    ),
    ClinicalReasoningCase(
      id: 'sepsis-2',
      title: 'Sepsis du patient fébrile',
      patientSummary: 'Femme 74 ans, confusion, tension basse, tachycardie et température 39,2°C après une infection urinaire.',
      keyFindings: [
        'Fièvre élevée avec altération de l’état général',
        'Tachycardie et hypotension',
        'Probable source urinaire',
      ],
      reasoningSteps: [
        'Reconnaitre un sepsis probable devant tachycardie, hypotension et fièvre.',
        'Évaluer la gravité et chercher la source infectieuse.',
        'Mettre en place la prise en charge immédiate avec perfusion et antibiotiques.',
      ],
      question: 'Quel est le bon réflexe clinique ?',
      options: [
        'Attendre les résultats bactériologiques avant tout traitement',
        'Démarrer le protocole de sepsis : perfusion, prélèvements, antibiotiques et réanimation dès que possible',
        'Faire uniquement un bilan urinaire et reprendre le patient en consultation',
        'Traiter comme une simple cystite sans évaluation hémodynamique',
      ],
      correctIndex: 1,
      explanation: 'Le sepsis est une urgence. Il faut immédiatement stabiliser la circulation, contrôler la source, prendre des prélèvements et débuter les antibiotiques adaptés sans attendre les résultats.',
    ),
    ClinicalReasoningCase(
      id: 'dyspnea-3',
      title: 'Dyspnée aiguë et hypoxie',
      patientSummary: 'Homme 50 ans, essoufflement important, cyanose légère, douleur thoracique et antécédent de TVP récente.',
      keyFindings: [
        'Dyspnée brutale',
        'Hypoxémie et douleur thoracique',
        'Facteurs de risque thromboembolique',
      ],
      reasoningSteps: [
        'Chercher les signes de gravité respiratoire et hémodynamique.',
        'Penser à l’embolie pulmonaire massive ou à un autre accident aigu.',
        'Initier la prise en charge et demander les examens urgents adaptés.',
      ],
      question: 'Quelle est la priorité ?',
      options: [
        'Surveillance sans traitement tant qu’aucun diagnostic n’est certain',
        'Évaluation immédiate de la gravité, oxygénation, et bilan d’embolie pulmonaire avec traitement adapté',
        'Prescrire uniquement de la kinésithérapie respiratoire',
        'Traiter comme un simple épisode d’anxiété',
      ],
      correctIndex: 1,
      explanation: 'Une dyspnée aiguë avec hypoxémie et contexte thromboembolique doit être considérée comme une urgence. Le diagnostic et la prise en charge doivent être conduits rapidement, sans attendre une confirmation tardive.',
    ),
  ];
}
