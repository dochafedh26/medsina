import '../models/study_coach_plan.dart';

class StudyCoachService {
  static StudyCoachPlan buildPlan({
    int daysLeft = 21,
    int weakTopics = 4,
    int availableMinutes = 75,
  }) {
    final safeDaysLeft = daysLeft.clamp(7, 45);
    final safeWeakTopics = weakTopics.clamp(1, 6);
    final safeMinutes = availableMinutes.clamp(30, 180);

    final priorityPool = <String>[
      'Cardiologie & ECG',
      'Microbiologie & antibiotiques',
      'Anatomie & physiopathologie',
      'Médecine interne',
      'Pédiatrie & urgences',
      'Réanimation & CAT',
    ];

    final priorities = List<String>.generate(
      safeWeakTopics,
      (index) => priorityPool[(index + safeDaysLeft) % priorityPool.length],
    );

    final title = safeDaysLeft <= 14
        ? 'Plan de rattrapage intensif'
        : safeDaysLeft <= 30
        ? 'Plan d’entraînement ciblé'
        : 'Plan de progression stable';

    final focus = priorities.first;
    final dailyRoutine = <String>[
      '10 min : réviser les définitions et les pièges du thème du jour',
      '25 min : faire des QCM et noter les erreurs récurrentes',
      '20 min : revoir les explications de la correction pour consolider la logique',
      if (safeMinutes >= 60)
        '15 min : traiter une petite fiche synthèse ou un cas clinique',
      if (safeMinutes >= 90)
        '15 min : refaire un mini-bloc de questions sur les points à corriger',
    ];

    final summary = safeDaysLeft <= 14
        ? 'La période est courte. Votre objectif est d’éliminer les erreurs répétées et de renforcer la prise de décision en priorité.'
        : 'Le plan vise à améliorer votre taux de réussite sur les thèmes les plus sensibles sans surcharger votre emploi du temps.';

    final rationale =
        'Le coach priorise les sujets où la probabilités d’erreurs est la plus forte, puis les enrichit avec des QCM, des fiches courtes et des cas à résoudre. L’objectif est de maximiser le gain de score avec un effort raisonnable.';

    return StudyCoachPlan(
      title: title,
      summary: summary,
      focus: focus,
      minutesPerDay: safeMinutes,
      priorities: priorities,
      dailyRoutine: dailyRoutine,
      rationale: rationale,
      nextCheckpoint: safeDaysLeft <= 14
          ? 'Checkpoint demain : réviser 2 erreurs récurrentes + 10 questions ciblées.'
          : 'Checkpoint 72 h : valider la progression sur les 3 thèmes prioritaires.',
    );
  }
}
