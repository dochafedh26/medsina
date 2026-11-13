import 'package:medsina_study_engine/features/revision/models/module_model.dart';

/// Represents a single course scheduled on a specific date in the realistic study plan.
class ScheduledCourseItem {
  final CourseModel course;
  final MedicalModuleModel module;
  final DateTime scheduledDate;
  final int dayIndex; // 0 for today, 1 for tomorrow, etc.
  final int weekIndex; // 1-indexed (Week 1, Week 2, ...)
  final bool isCompleted;
  final bool isToday;
  final bool isOverdue;
  final String phaseName;
  final int phaseIndex;

  const ScheduledCourseItem({
    required this.course,
    required this.module,
    required this.scheduledDate,
    required this.dayIndex,
    required this.weekIndex,
    this.isCompleted = false,
    this.isToday = false,
    this.isOverdue = false,
    this.phaseName = '',
    this.phaseIndex = 1,
  });

  ScheduledCourseItem copyWith({
    CourseModel? course,
    MedicalModuleModel? module,
    DateTime? scheduledDate,
    int? dayIndex,
    int? weekIndex,
    bool? isCompleted,
    bool? isToday,
    bool? isOverdue,
    String? phaseName,
    int? phaseIndex,
  }) {
    return ScheduledCourseItem(
      course: course ?? this.course,
      module: module ?? this.module,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      dayIndex: dayIndex ?? this.dayIndex,
      weekIndex: weekIndex ?? this.weekIndex,
      isCompleted: isCompleted ?? this.isCompleted,
      isToday: isToday ?? this.isToday,
      isOverdue: isOverdue ?? this.isOverdue,
      phaseName: phaseName ?? this.phaseName,
      phaseIndex: phaseIndex ?? this.phaseIndex,
    );
  }
}

/// Represents one calendar day in the revision timeline.
class ScheduledDay {
  final DateTime date;
  final int dayNumber; // 1-indexed from start
  final int weekNumber; // 1-indexed
  final bool isRestOrReviewDay; // e.g. Day 7 of week for catch-up & QCM review
  final List<ScheduledCourseItem> courses;
  final String label;

  const ScheduledDay({
    required this.date,
    required this.dayNumber,
    required this.weekNumber,
    this.isRestOrReviewDay = false,
    required this.courses,
    this.label = '',
  });

  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  bool get isPast {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dayDate = DateTime(date.year, date.month, date.day);
    return dayDate.isBefore(today);
  }

  int get completedCount => courses.where((c) => c.isCompleted).length;
  int get totalCount => courses.length;
  bool get isAllCompleted => courses.isNotEmpty && completedCount == totalCount;
  double get progressRatio => courses.isEmpty ? 1.0 : completedCount / courses.length;
}

/// Represents a 1-week block in the revision timeline.
class ScheduledWeek {
  final int weekNumber;
  final DateTime startDate;
  final DateTime endDate;
  final String phaseName;
  final int phaseIndex;
  final List<ScheduledDay> days;

  const ScheduledWeek({
    required this.weekNumber,
    required this.startDate,
    required this.endDate,
    required this.phaseName,
    required this.phaseIndex,
    required this.days,
  });

  List<ScheduledCourseItem> get allCourses {
    final list = <ScheduledCourseItem>[];
    for (final day in days) {
      list.addAll(day.courses);
    }
    return list;
  }

  int get completedCount => allCourses.where((c) => c.isCompleted).length;
  int get totalCount => allCourses.length;
  double get progressRatio => totalCount == 0 ? 1.0 : completedCount / totalCount;
  bool get isCurrentWeek {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
    return !today.isBefore(start) && !today.isAfter(end);
  }
}

/// Comprehensive realistic schedule plan calculated for the candidate.
class RealisticSchedulePlan {
  final DateTime targetExamDate;
  final DateTime startDate;
  final int totalDaysRemaining;
  final int totalWeeksRemaining;
  final int effectiveStudyDays;
  final int consolidationDaysCount;
  final int totalCoursesCount;
  final int completedCoursesCount;
  final int remainingCoursesCount;
  final double dailyCadence; // Realistic courses per active study day
  final List<ScheduledDay> days;
  final List<ScheduledWeek> weeks;
  final List<ScheduledCourseItem> todayCourses;
  final List<ScheduledCourseItem> overdueCourses;
  final List<ScheduledCourseItem> thisWeekCourses;
  final String activePlanTitle;
  final String activePlanBadge;

  const RealisticSchedulePlan({
    required this.targetExamDate,
    required this.startDate,
    required this.totalDaysRemaining,
    required this.totalWeeksRemaining,
    required this.effectiveStudyDays,
    required this.consolidationDaysCount,
    required this.totalCoursesCount,
    required this.completedCoursesCount,
    required this.remainingCoursesCount,
    required this.dailyCadence,
    required this.days,
    required this.weeks,
    required this.todayCourses,
    required this.overdueCourses,
    required this.thisWeekCourses,
    this.activePlanTitle = 'Plan Personnalisé',
    this.activePlanBadge = 'OPTIMISÉ',
  });

  double get globalProgressRatio =>
      totalCoursesCount == 0 ? 0.0 : (completedCoursesCount / totalCoursesCount).clamp(0.0, 1.0);

  bool get isTodayComplete =>
      todayCourses.isNotEmpty && todayCourses.every((c) => c.isCompleted);
}
