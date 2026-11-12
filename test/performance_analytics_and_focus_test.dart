import 'package:flutter_test/flutter_test.dart';
import 'package:medsina/core/services/user_study_progress_service.dart';
import 'package:medsina/features/analytics/services/performance_analytics_service.dart';
import 'package:medsina/features/focus/services/focus_timer_service.dart';
import 'package:medsina/features/notifications/services/smart_reminder_service.dart';
import 'package:medsina/features/revision/models/module_model.dart';
import 'package:medsina/features/revision/services/error_notebook_service.dart';
import 'package:medsina/features/revision/services/user_qcm_annotation_service.dart';

void main() {
  group('PerformanceAnalyticsService', () {
    test('computeSnapshot aggregates disciplines, weaknesses, evolution and 53w heatmap', () {
      const modules = [
        MedicalModuleModel(
          id: 'Blida_CARDIOLOGIE',
          name: 'Cardiologie',
          category: 'Clinique',
          totalQuestions: 100,
          totalCourses: 2,
          iconName: 'favorite',
          courses: [
            CourseModel(
              id: 'c_hta',
              moduleId: 'Blida_CARDIOLOGIE',
              name: 'HTA',
              questionsCount: 50,
              hasPdf: true,
            ),
            CourseModel(
              id: 'c_sca',
              moduleId: 'Blida_CARDIOLOGIE',
              name: 'SCA',
              questionsCount: 50,
              hasPdf: true,
            ),
          ],
        ),
      ];

      const annotations = [
        UserQuestionAnnotation(
          questionId: 'q1',
          moduleId: 'Blida_CARDIOLOGIE',
          courseId: 'c_hta',
          attemptsCount: 10,
          correctCount: 8,
          wrongCount: 2,
          lastResult: 'correct',
        ),
        UserQuestionAnnotation(
          questionId: 'q2',
          moduleId: 'Blida_CARDIOLOGIE',
          courseId: 'c_sca',
          attemptsCount: 10,
          correctCount: 3,
          wrongCount: 7,
          lastResult: 'wrong',
        ),
      ];

      final now = DateTime(2026, 11, 12);
      final progress = UserStudyProgress.initial().copyWith(
        totalQcmSolved: 20,
        averageAccuracy: 55.0,
        currentStreak: 4,
        accomplishedDates: {'2026-11-12', '2026-11-11'},
      );

      final snap = PerformanceAnalyticsService.computeSnapshot(
        progress: progress,
        activeDaysHistory: ['2026-11-10', '2026-11-11', '2026-11-12'],
        annotations: annotations,
        modules: modules,
        now: now,
      );

      expect(snap.disciplines.length, 1);
      expect(snap.disciplines.first.name, 'Cardiologie');
      expect(snap.disciplines.first.accuracyPercent, closeTo(55.0, 0.001));
      expect(snap.evolution30d.length, 30);
      expect(snap.evolution90d.length, 90);
      expect(snap.activityHeatmap53w.length, 371);
      expect(snap.activityHeatmap53w['2026-11-12'], 4);
      expect(snap.activityHeatmap53w['2026-11-10'], 2);
      expect(snap.topWeaknesses.first.courseId, 'c_sca');
      expect(snap.topWeaknesses.first.wrongCount, 7);
    });
  });

  group('ErrorNotebookService', () {
    test('groupAnnotationsByCourse groups missed QCMs and sorts by error count', () {
      const missed = [
        UserQuestionAnnotation(
          questionId: 'q1',
          moduleId: 'm1',
          courseId: 'c1',
          wrongCount: 3,
          lastResult: 'wrong',
        ),
        UserQuestionAnnotation(
          questionId: 'q2',
          moduleId: 'm1',
          courseId: 'c1',
          wrongCount: 1,
          lastResult: 'wrong',
        ),
        UserQuestionAnnotation(
          questionId: 'q3',
          moduleId: 'm2',
          courseId: 'c2',
          wrongCount: 2,
          lastResult: 'partial',
        ),
      ];

      final groups = ErrorNotebookService.groupAnnotationsByCourse(
        missed: missed,
        courseNames: {'c1': 'Cardiologie HTA', 'c2': 'Pneumologie'},
      );

      expect(groups.length, 2);
      expect(groups.first.courseName, 'Cardiologie HTA');
      expect(groups.first.errorCount, 2);
      expect(groups.first.totalWrongAttempts, 4);
    });
  });

  group('FocusTimerService', () {
    test('presets, tick countdown and formattedRemaining work deterministically', () async {
      final timer = FocusTimerService.instance;
      timer.selectPreset(FocusPreset.sprint15_3);
      expect(timer.remainingSeconds, 15 * 60);
      expect(timer.formattedRemaining, '15:00');
      expect(timer.phase, FocusPhase.focus);

      await timer.tick();
      expect(timer.remainingSeconds, 15 * 60 - 1);
      expect(timer.formattedRemaining, '14:59');

      timer.selectPreset(FocusPreset.deepWork50_10);
      expect(timer.remainingSeconds, 50 * 60);
    });
  });

  group('SmartReminderService', () {
    test('computeDaysUntil and evening streak alert logic', () {
      final now = DateTime(2026, 11, 12, 20, 30);
      final target = DateTime(2026, 11, 22);
      expect(SmartReminderService.computeDaysUntil(target, now: now), 10);

      expect(
        SmartReminderService.shouldTriggerEveningStreakAlert(
          isTodayAccomplished: false,
          currentStreak: 5,
          now: now,
        ),
        isTrue,
      );
      expect(
        SmartReminderService.shouldTriggerEveningStreakAlert(
          isTodayAccomplished: true,
          currentStreak: 5,
          now: now,
        ),
        isFalse,
      );
    });
  });
}
