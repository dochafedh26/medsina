import 'dart:math' as math;
import '../models/course_schedule_model.dart';
import '../models/laureate_study_plan_model.dart';
import 'package:medsina_study_engine/features/revision/models/module_model.dart';
import 'laureate_study_plan_service.dart';
import 'package:medsina_study_engine/features/revision/services/user_qcm_annotation_service.dart';

class RealisticCourseScheduleService {
  RealisticCourseScheduleService._();
  static final RealisticCourseScheduleService instance =
      RealisticCourseScheduleService._();

  /// Generates a realistic, timing-accurate schedule of courses from today until the selected targetExamDate.
  RealisticSchedulePlan generateSchedule({
    required List<MedicalModuleModel> allModules,
    required DateTime targetExamDate,
    LaureateStudyPlanModel? activePlan,
    required UserQcmAnnotationService annotationService,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(targetExamDate.year, targetExamDate.month, targetExamDate.day);

    // Days remaining (at least 1 day)
    final rawDaysRemaining = target.difference(today).inDays;
    final totalDaysRemaining = math.max(1, rawDaysRemaining);
    final totalWeeksRemaining = math.max(1, (totalDaysRemaining / 7).ceil());

    // 1. Gather all courses with their respective parent modules
    final allPairs = <_ModuleCoursePair>[];
    for (final mod in allModules) {
      for (final course in mod.courses) {
        allPairs.add(_ModuleCoursePair(module: mod, course: course));
      }
    }

    final totalCoursesCount = allPairs.length;

    // 2. Prioritize courses realistically according to Active Plan phases & High-Yield weight
    final prioritizedPairs = _prioritizeCourses(
      allPairs: allPairs,
      activePlan: activePlan,
      annotationService: annotationService,
    );

    // 3. Count completed courses
    int completedCoursesCount = 0;
    for (final pair in allPairs) {
      final entry = annotationService.getPlannerEntry(pair.course.id);
      if (entry.layer1Done) {
        completedCoursesCount++;
      }
    }
    final remainingCoursesCount = math.max(0, totalCoursesCount - completedCoursesCount);

    // 4. Calculate realistic active study days (6 days study + 1 day consolidation/week, buffer reserve)
    // Buffer days at the end reserved for mock exams / final rush if timeline is long enough
    final bufferWeeks = totalWeeksRemaining >= 12
        ? 2
        : (totalWeeksRemaining >= 4 ? 1 : 0);
    final bufferDays = bufferWeeks * 7;

    final studyWeeks = math.max(1, totalWeeksRemaining - bufferWeeks);
    final consolidationDays = studyWeeks; // 1 day per study week
    final rawActiveStudyDays = (studyWeeks * 6);
    final effectiveStudyDays = math.max(1, math.min(rawActiveStudyDays, totalDaysRemaining - consolidationDays - bufferDays));

    // Realistic daily cadence
    final int defaultPlanPace = activePlan?.targetDailyCourses ?? 2;
    double calculatedCadence = remainingCoursesCount > 0 && effectiveStudyDays > 0
        ? remainingCoursesCount / effectiveStudyDays
        : defaultPlanPace.toDouble();

    // Bound realistic cadence between 1 and 4 courses per day to stay physically & cognitively realistic
    int dailyQuota = calculatedCadence <= 0
        ? defaultPlanPace
        : math.max(1, math.min(4, calculatedCadence.ceil()));

    if (activePlan != null && activePlan.targetDailyCourses > 0) {
      // If user selected a specific Laureate plan, prioritize that plan's intended cadence
      dailyQuota = math.max(dailyQuota, activePlan.targetDailyCourses);
    }

    // 5. Build Day-by-Day timeline
    final scheduledDays = <ScheduledDay>[];
    final scheduledWeeks = <ScheduledWeek>[];

    // Separate uncompleted and completed queue to allocate remaining courses
    final uncompletedQueue = <_ModuleCoursePair>[];
    final completedQueue = <_ModuleCoursePair>[];

    for (final pair in prioritizedPairs) {
      final isDone = annotationService.getPlannerEntry(pair.course.id).layer1Done;
      if (isDone) {
        completedQueue.add(pair);
      } else {
        uncompletedQueue.add(pair);
      }
    }

    // Allocate day by day
    int courseQueuePointer = 0;
    final allUncompletedList = uncompletedQueue;

    DateTime currentDayDate = today;
    int currentDayNumber = 1;
    int currentWeekNumber = 1;
    List<ScheduledDay> currentWeekDays = [];
    DateTime currentWeekStartDate = today;

    // We schedule up to totalDaysRemaining or until target date (capped at 730 days for safety)
    final daysToGenerate = math.min(totalDaysRemaining, 730);

    for (int dayOffset = 0; dayOffset < daysToGenerate; dayOffset++) {
      currentDayDate = today.add(Duration(days: dayOffset));
      currentDayNumber = dayOffset + 1;
      currentWeekNumber = (dayOffset ~/ 7) + 1;

      if (dayOffset % 7 == 0) {
        currentWeekStartDate = currentDayDate;
      }

      // Check if it's a consolidation / review day (every 7th day) or in buffer period
      final isBufferDay = dayOffset >= (totalDaysRemaining - bufferDays);
      final isSeventhDay = (dayOffset + 1) % 7 == 0;
      final isRestOrReview = isSeventhDay || isBufferDay;

      final dayCourses = <ScheduledCourseItem>[];

      // Determine phase name for this week
      final phaseInfo = _getPhaseForWeek(
        weekIndex: currentWeekNumber,
        activePlan: activePlan,
        totalWeeks: totalWeeksRemaining,
      );

      if (isBufferDay) {
        // Final buffer day: no new courses assigned
      } else if (isSeventhDay) {
        // Consolidation day: reserve for review and catch-up
      } else {
        // Active study day: assign up to dailyQuota uncompleted courses
        int assignedCount = 0;
        while (assignedCount < dailyQuota && courseQueuePointer < allUncompletedList.length) {
          final pair = allUncompletedList[courseQueuePointer];
          courseQueuePointer++;
          assignedCount++;

          final isDone = annotationService.getPlannerEntry(pair.course.id).layer1Done;
          final isPastDay = currentDayDate.isBefore(today);

          dayCourses.add(ScheduledCourseItem(
            course: pair.course,
            module: pair.module,
            scheduledDate: currentDayDate,
            dayIndex: dayOffset,
            weekIndex: currentWeekNumber,
            isCompleted: isDone,
            isToday: dayOffset == 0,
            isOverdue: isPastDay && !isDone,
            phaseName: phaseInfo.name,
            phaseIndex: phaseInfo.index,
          ));
        }
      }

      String dayLabel = '';
      if (dayOffset == 0) {
        dayLabel = "Aujourd'hui";
      } else if (dayOffset == 1) {
        dayLabel = 'Demain';
      } else if (isBufferDay) {
        dayLabel = 'Sprint Final & Annales Blanches';
      } else if (isSeventhDay) {
        dayLabel = 'Consolidation & Rattrapage QCM';
      }

      final scheduledDay = ScheduledDay(
        date: currentDayDate,
        dayNumber: currentDayNumber,
        weekNumber: currentWeekNumber,
        isRestOrReviewDay: isRestOrReview,
        courses: dayCourses,
        label: dayLabel,
      );

      scheduledDays.add(scheduledDay);
      currentWeekDays.add(scheduledDay);

      // Finalize week block on day 7 or on last day
      if ((dayOffset + 1) % 7 == 0 || dayOffset == daysToGenerate - 1) {
        scheduledWeeks.add(ScheduledWeek(
          weekNumber: currentWeekNumber,
          startDate: currentWeekStartDate,
          endDate: currentDayDate,
          phaseName: phaseInfo.name,
          phaseIndex: phaseInfo.index,
          days: List<ScheduledDay>.from(currentWeekDays),
        ));
        currentWeekDays = [];
      }
    }

    // 6. Gather quick lookup lists
    final todayScheduled = scheduledDays.isNotEmpty
        ? scheduledDays.first.courses
        : <ScheduledCourseItem>[];

    // If today is a rest day or has 0 assigned courses (e.g. all done or buffer),
    // provide next upcoming 2 courses as suggestions
    final List<ScheduledCourseItem> resolvedTodayCourses;
    if (todayScheduled.isEmpty && uncompletedQueue.isNotEmpty) {
      resolvedTodayCourses = uncompletedQueue.take(dailyQuota).map((p) {
        final isDone = annotationService.getPlannerEntry(p.course.id).layer1Done;
        return ScheduledCourseItem(
          course: p.course,
          module: p.module,
          scheduledDate: today,
          dayIndex: 0,
          weekIndex: 1,
          isCompleted: isDone,
          isToday: true,
          isOverdue: false,
          phaseName: 'Objectif du Jour',
          phaseIndex: 1,
        );
      }).toList();
    } else {
      resolvedTodayCourses = todayScheduled;
    }

    final overdueList = <ScheduledCourseItem>[];
    final thisWeekList = <ScheduledCourseItem>[];

    for (final day in scheduledDays) {
      if (day.dayNumber <= 7) {
        thisWeekList.addAll(day.courses);
      }
      for (final c in day.courses) {
        if (c.isOverdue) overdueList.add(c);
      }
    }

    return RealisticSchedulePlan(
      targetExamDate: targetExamDate,
      startDate: today,
      totalDaysRemaining: totalDaysRemaining,
      totalWeeksRemaining: totalWeeksRemaining,
      effectiveStudyDays: effectiveStudyDays,
      consolidationDaysCount: consolidationDays + bufferDays,
      totalCoursesCount: totalCoursesCount,
      completedCoursesCount: completedCoursesCount,
      remainingCoursesCount: remainingCoursesCount,
      dailyCadence: calculatedCadence,
      days: scheduledDays,
      weeks: scheduledWeeks,
      todayCourses: resolvedTodayCourses,
      overdueCourses: overdueList,
      thisWeekCourses: thisWeekList,
      activePlanTitle: activePlan?.strategyTitle ?? 'Planning Réaliste & Échéance',
      activePlanBadge: activePlan?.rankBadge ?? 'MEDSINA',
    );
  }

  /// Prioritizes courses according to Laureate Plan phases, Focus Modules, and High-Yield QCM weight
  List<_ModuleCoursePair> _prioritizeCourses({
    required List<_ModuleCoursePair> allPairs,
    required LaureateStudyPlanModel? activePlan,
    required UserQcmAnnotationService annotationService,
  }) {
    final list = List<_ModuleCoursePair>.from(allPairs);

    // Build module weight dictionary from active plan phases
    final modulePhaseRank = <String, int>{};
    if (activePlan != null && activePlan.phases.isNotEmpty) {
      for (final phase in activePlan.phases) {
        for (final focusMod in phase.focusModules) {
          final normalized = _normalize(focusMod);
          if (!modulePhaseRank.containsKey(normalized)) {
            modulePhaseRank[normalized] = phase.phaseIndex;
          }
        }
      }
    }

    list.sort((a, b) {
      // 1. Completion status: uncompleted first
      final aDone = annotationService.getPlannerEntry(a.course.id).layer1Done;
      final bDone = annotationService.getPlannerEntry(b.course.id).layer1Done;
      if (aDone != bDone) {
        return aDone ? 1 : -1;
      }

      // 2. Active plan phase rank
      final rankA = modulePhaseRank[_normalize(a.module.name)] ?? 99;
      final rankB = modulePhaseRank[_normalize(b.module.name)] ?? 99;
      if (rankA != rankB) {
        return rankA.compareTo(rankB);
      }

      // 3. High-Yield & QCM Count (heavier exam weight first)
      if (a.course.isHypertombable != b.course.isHypertombable) {
        return a.course.isHypertombable ? -1 : 1;
      }
      return b.course.questionsCount.compareTo(a.course.questionsCount);
    });

    return list;
  }

  _PhaseInfo _getPhaseForWeek({
    required int weekIndex,
    required LaureateStudyPlanModel? activePlan,
    required int totalWeeks,
  }) {
    if (activePlan == null || activePlan.phases.isEmpty) {
      if (weekIndex <= (totalWeeks * 0.5).ceil()) {
        return const _PhaseInfo(index: 1, name: 'Couche 1 : Compréhension & Socle Fondamental');
      } else if (weekIndex <= (totalWeeks * 0.8).ceil()) {
        return const _PhaseInfo(index: 2, name: 'Couche 2 : Fiches & Consolidation QCM');
      } else {
        return const _PhaseInfo(index: 3, name: 'Couche 3 : Rush Final & Annales Concours');
      }
    }

    int accumulatedWeeks = 0;
    for (final phase in activePlan.phases) {
      accumulatedWeeks += phase.durationWeeks;
      if (weekIndex <= accumulatedWeeks) {
        return _PhaseInfo(index: phase.phaseIndex, name: phase.name);
      }
    }

    return _PhaseInfo(
      index: activePlan.phases.last.phaseIndex,
      name: activePlan.phases.last.name,
    );
  }

  static String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[àáâãäå]'), 'a')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[òóôõö]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  /// Mark a course layer 1 toggled and synchronize with LaureateStudyPlanService
  Future<void> toggleCourseCompletion({
    required String courseId,
    required String moduleId,
  }) async {
    final annService = UserQcmAnnotationService.instance;
    await annService.togglePlannerLayer(
      courseId: courseId,
      moduleId: moduleId,
      layerIndex: 1,
    );
    await LaureateStudyPlanService.instance.toggleTodayCourse(courseId);
  }

  /// Update the target deadline across both services
  Future<void> setTargetDeadline(DateTime newDate) async {
    await UserQcmAnnotationService.instance.setTargetExamDate(newDate);
    await LaureateStudyPlanService.instance.updateTargetExamDate(newDate);
  }
}

class _ModuleCoursePair {
  final MedicalModuleModel module;
  final CourseModel course;

  const _ModuleCoursePair({required this.module, required this.course});
}

class _PhaseInfo {
  final int index;
  final String name;

  const _PhaseInfo({required this.index, required this.name});
}
