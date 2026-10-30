class StudyCoachPlan {
  final String title;
  final String summary;
  final String focus;
  final int minutesPerDay;
  final List<String> priorities;
  final List<String> dailyRoutine;
  final String rationale;
  final String nextCheckpoint;

  const StudyCoachPlan({
    required this.title,
    required this.summary,
    required this.focus,
    required this.minutesPerDay,
    required this.priorities,
    required this.dailyRoutine,
    required this.rationale,
    required this.nextCheckpoint,
  });
}
