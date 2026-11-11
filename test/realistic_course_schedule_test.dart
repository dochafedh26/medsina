import 'package:flutter_test/flutter_test.dart';
import 'package:medsina/features/revision/models/course_schedule_model.dart';
import 'package:medsina/features/revision/models/laureate_study_plan_model.dart';
import 'package:medsina/features/revision/models/module_model.dart';
import 'package:medsina/features/revision/services/realistic_course_schedule_service.dart';
import 'package:medsina/features/revision/services/user_qcm_annotation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RealisticCourseScheduleService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    final mockModules = [
      const MedicalModuleModel(
        id: 'mod_cardio',
        name: 'Cardiologie',
        category: 'Clinique',
        totalQuestions: 500,
        totalCourses: 2,
        courses: [
          CourseModel(
            id: 'c_hta',
            moduleId: 'mod_cardio',
            name: 'Hypertension Artérielle',
            questionsCount: 45,
            isHypertombable: true,
          ),
          CourseModel(
            id: 'c_sca',
            moduleId: 'mod_cardio',
            name: 'Syndromes Coronariens Aigus',
            questionsCount: 60,
            isHypertombable: true,
          ),
        ],
      ),
      const MedicalModuleModel(
        id: 'mod_pneumo',
        name: 'Pneumologie',
        category: 'Clinique',
        totalQuestions: 300,
        totalCourses: 2,
        courses: [
          CourseModel(
            id: 'c_bpco',
            moduleId: 'mod_pneumo',
            name: 'BPCO',
            questionsCount: 30,
            isHypertombable: false,
          ),
          CourseModel(
            id: 'c_asthme',
            moduleId: 'mod_pneumo',
            name: 'Asthme de l\'Adulte',
            questionsCount: 35,
            isHypertombable: false,
          ),
        ],
      ),
    ];

    test('generates realistic plan with accurate timing and rest days', () {
      final now = DateTime.now();
      final targetDate = now.add(const Duration(days: 30));
      final annService = UserQcmAnnotationService.instance;

      final plan = RealisticCourseScheduleService.instance.generateSchedule(
        allModules: mockModules,
        targetExamDate: targetDate,
        annotationService: annService,
      );

      expect(plan.totalCoursesCount, 4);
      expect(plan.totalDaysRemaining, greaterThanOrEqualTo(29));
      expect(plan.totalWeeksRemaining, greaterThanOrEqualTo(4));
      expect(plan.todayCourses.isNotEmpty, isTrue);

      // Check consolidation day exists in week
      final firstWeek = plan.weeks.first;
      expect(firstWeek.days.isNotEmpty, isTrue);
      final hasRestOrReviewDay = firstWeek.days.any((d) => d.isRestOrReviewDay);
      expect(hasRestOrReviewDay, isTrue);
    });

    test('respects laureate plan target pace and focus modules', () {
      final now = DateTime.now();
      final targetDate = now.add(const Duration(days: 60));
      final annService = UserQcmAnnotationService.instance;

      const laureatePlan = LaureateStudyPlanModel(
        id: 'plan_test',
        laureateId: 'l1',
        laureateName: 'Dr Test',
        rankBadge: 'MAJOR',
        faculty: 'Alger',
        strategyTitle: 'Strategie Test',
        strategyTagline: 'Tagline',
        targetAudience: 'Tous',
        totalWeeks: 12,
        recommendedDailyHours: 6,
        targetDailyCourses: 2,
        targetDailyQcms: 40,
        layersCount: 3,
        accentColorHex: '#0D9488',
        keyPrinciples: ['Principe 1'],
        recommendedSources: 'Sources',
        phases: [
          StudyPlanPhase(
            phaseIndex: 1,
            name: 'Phase 1 : Cardio First',
            durationWeeks: 6,
            description: 'Desc',
            focusModules: ['Cardiologie'],
            targetWeeklyCourses: 10,
            targetWeeklyQcms: 150,
          ),
        ],
        dailyQuotes: ['Citation test'],
      );

      final plan = RealisticCourseScheduleService.instance.generateSchedule(
        allModules: mockModules,
        targetExamDate: targetDate,
        activePlan: laureatePlan,
        annotationService: annService,
      );

      expect(plan.activePlanTitle, 'Strategie Test');
      expect(plan.activePlanBadge, 'MAJOR');

      // The prioritized first course should be from Cardiologie (focusModule of Phase 1)
      expect(plan.todayCourses.first.module.name, 'Cardiologie');
    });

    test('scheduled course items reflect completion status correctly', () {
      const item = ScheduledCourseItem(
        course: CourseModel(
          id: 'c1',
          moduleId: 'm1',
          name: 'Pneumopathie',
          questionsCount: 20,
        ),
        module: MedicalModuleModel(
          id: 'm1',
          name: 'Pneumo',
          category: 'Clinique',
          totalQuestions: 20,
          totalCourses: 1,
          courses: [],
        ),
        scheduledDate: DateTime(2027, 10, 15),
        dayIndex: 0,
        weekIndex: 1,
        isCompleted: true,
      );

      expect(item.isCompleted, isTrue);
      expect(item.course.name, 'Pneumopathie');
    });
  });
}
