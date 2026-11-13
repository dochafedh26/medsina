class StudyPlanPhase {
  final int phaseIndex;
  final String name;
  final int durationWeeks;
  final String description;
  final List<String> focusModules;
  final int targetWeeklyCourses;
  final int targetWeeklyQcms;

  const StudyPlanPhase({
    required this.phaseIndex,
    required this.name,
    required this.durationWeeks,
    required this.description,
    required this.focusModules,
    required this.targetWeeklyCourses,
    required this.targetWeeklyQcms,
  });

  Map<String, dynamic> toJson() => {
        'phaseIndex': phaseIndex,
        'name': name,
        'durationWeeks': durationWeeks,
        'description': description,
        'focusModules': focusModules,
        'targetWeeklyCourses': targetWeeklyCourses,
        'targetWeeklyQcms': targetWeeklyQcms,
      };

  factory StudyPlanPhase.fromJson(Map<String, dynamic> json) {
    return StudyPlanPhase(
      phaseIndex: json['phaseIndex'] as int? ?? 1,
      name: json['name'] as String? ?? '',
      durationWeeks: json['durationWeeks'] as int? ?? 12,
      description: json['description'] as String? ?? '',
      focusModules: (json['focusModules'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      targetWeeklyCourses: json['targetWeeklyCourses'] as int? ?? 10,
      targetWeeklyQcms: json['targetWeeklyQcms'] as int? ?? 200,
    );
  }
}

class LaureateStudyPlanModel {
  final String id;
  final String laureateId;
  final String laureateName;
  final String rankBadge;
  final String faculty;
  final String strategyTitle;
  final String strategyTagline;
  final String targetAudience;
  final int totalWeeks;
  final int recommendedDailyHours;
  final int targetDailyCourses;
  final int targetDailyQcms;
  final int layersCount;
  final String accentColorHex;
  final List<String> keyPrinciples;
  final String recommendedSources;
  final List<StudyPlanPhase> phases;
  final List<String> dailyQuotes;

  const LaureateStudyPlanModel({
    required this.id,
    required this.laureateId,
    required this.laureateName,
    required this.rankBadge,
    required this.faculty,
    required this.strategyTitle,
    required this.strategyTagline,
    required this.targetAudience,
    required this.totalWeeks,
    required this.recommendedDailyHours,
    required this.targetDailyCourses,
    required this.targetDailyQcms,
    required this.layersCount,
    required this.accentColorHex,
    required this.keyPrinciples,
    required this.recommendedSources,
    required this.phases,
    required this.dailyQuotes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'laureateId': laureateId,
        'laureateName': laureateName,
        'rankBadge': rankBadge,
        'faculty': faculty,
        'strategyTitle': strategyTitle,
        'strategyTagline': strategyTagline,
        'targetAudience': targetAudience,
        'totalWeeks': totalWeeks,
        'recommendedDailyHours': recommendedDailyHours,
        'targetDailyCourses': targetDailyCourses,
        'targetDailyQcms': targetDailyQcms,
        'layersCount': layersCount,
        'accentColorHex': accentColorHex,
        'keyPrinciples': keyPrinciples,
        'recommendedSources': recommendedSources,
        'phases': phases.map((p) => p.toJson()).toList(),
        'dailyQuotes': dailyQuotes,
      };

  factory LaureateStudyPlanModel.fromJson(Map<String, dynamic> json) {
    final rawPhases = json['phases'] as List<dynamic>? ?? [];
    return LaureateStudyPlanModel(
      id: json['id'] as String,
      laureateId: json['laureateId'] as String? ?? '',
      laureateName: json['laureateName'] as String? ?? '',
      rankBadge: json['rankBadge'] as String? ?? '',
      faculty: json['faculty'] as String? ?? '',
      strategyTitle: json['strategyTitle'] as String? ?? '',
      strategyTagline: json['strategyTagline'] as String? ?? '',
      targetAudience: json['targetAudience'] as String? ?? '',
      totalWeeks: json['totalWeeks'] as int? ?? 36,
      recommendedDailyHours: json['recommendedDailyHours'] as int? ?? 6,
      targetDailyCourses: json['targetDailyCourses'] as int? ?? 2,
      targetDailyQcms: json['targetDailyQcms'] as int? ?? 35,
      layersCount: json['layersCount'] as int? ?? 3,
      accentColorHex: json['accentColorHex'] as String? ?? '#0D9488',
      keyPrinciples: (json['keyPrinciples'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      recommendedSources: json['recommendedSources'] as String? ?? '',
      phases: rawPhases
          .map((p) => StudyPlanPhase.fromJson(p as Map<String, dynamic>))
          .toList(),
      dailyQuotes: (json['dailyQuotes'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}
