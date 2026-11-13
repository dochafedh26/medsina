import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medsina_core/core/interfaces/feature_contracts.dart';
import 'package:medsina_core/core/services/gemini_service.dart';
import 'package:medsina_core/core/services/recent_activity_service.dart';
import 'package:medsina_core/features/notifications/services/smart_reminder_service.dart';

import 'features/revision/bloc/revision_bloc.dart';
import 'features/revision/bloc/revision_event.dart';
import 'features/revision/data/residency_repository.dart';
import 'features/revision/models/flashcard_fsrs_model.dart';
import 'features/revision/models/module_model.dart';
import 'features/revision/models/revision_session_model.dart';
import 'features/revision/presentation/course_pdf_viewer_screen.dart';
import 'features/revision/presentation/qcm_study_screen.dart';
import 'features/revision/services/revision_cloud_sync_participant.dart';
import 'features/revision/services/revision_session_storage.dart';

class _RevisionProgressContributor implements StudyProgressContributor {
  @override
  Future<({int solvedQcms, int completedCourses})> getProgressCounts() async {
    final allProgress = await RevisionSessionStorage.instance.getAllCourseProgress();
    int liveQcmCount = 0;
    final completed = <String>{};
    for (final entry in allProgress.values) {
      liveQcmCount += entry.revealedQuestions.length;
      if (entry.isCompleted) {
        completed.add(entry.courseId);
      }
    }
    return (solvedQcms: liveQcmCount, completedCourses: completed.length);
  }
}

/// Registers study-engine sync, progress, AI catalog, and activity routes
/// with `medsina_core`'s `MedsinaFeatureRegistry`.
void registerStudyEngineContracts() {
  final registry = MedsinaFeatureRegistry.instance;

  registry.registerSyncParticipant(RevisionCloudSyncParticipant.instance);
  registry.registerProgressContributor(_RevisionProgressContributor());

  SmartReminderService.dueFlashcardsCountProvider = () async {
    await FlashcardFsrsService.instance.ensureInitialized();
    return FlashcardFsrsService.instance.cards.where((c) => c.isDueNow).length;
  };

  GeminiService.courseCatalogProvider = () {
    return ResidencyRepository.getModules()
        .map((m) => (
              moduleName: m.name,
              courseNames: m.courses.map((c) => c.name).toList(),
            ))
        .toList();
  };

  RecentActivityService.revisionActivitiesProvider = () async {
    final items = <RecentActivityItem>[];
    final courseProgresses = await RevisionSessionStorage.instance.getAllCourseProgress();
    final activeList = courseProgresses.values.where((p) => !p.isCompleted).toList()
      ..sort((a, b) => b.lastActiveAt.compareTo(a.lastActiveAt));

    if (activeList.isNotEmpty) {
      final latest = activeList.first;
      final currentQ = latest.currentQuestionIndex + 1;
      final totalQ = latest.totalQuestions;
      final pct = totalQ > 0 ? (currentQ / totalQ).clamp(0.0, 1.0) : 0.0;
      items.add(RecentActivityItem(
        id: 'qcm_${latest.courseId}',
        type: ActivityType.qcmCourse,
        title: 'QCM : ${latest.courseName}',
        subtitle: 'Reprendre à la question $currentQ/$totalQ • ${(pct * 100).toInt()}% terminé',
        badgeText: 'Session QCM en pause',
        badgeColor: const Color(0xFF0D9488),
        icon: Icons.quiz_rounded,
        iconColor: const Color(0xFF0D9488),
        timestamp: latest.lastActiveAt,
        progressPercent: pct,
        data: {
          'courseId': latest.courseId,
          'courseName': latest.courseName,
          'moduleId': latest.moduleId,
          'currentQuestionIndex': latest.currentQuestionIndex,
          'totalQuestions': latest.totalQuestions,
        },
      ));
    }

    final customSessions = await RevisionSessionStorage.instance.getCustomSessions();
    final activeCustom = customSessions.where((s) => !s.isCompleted).toList();
    if (activeCustom.isNotEmpty) {
      final session = activeCustom.first;
      final currentQ = session.currentQuestionIndex + 1;
      final totalQ = session.totalQuestions;
      final pct = totalQ > 0 ? (currentQ / totalQ).clamp(0.0, 1.0) : 0.0;
      items.add(RecentActivityItem(
        id: 'custom_${session.id}',
        type: ActivityType.qcmCustomSession,
        title: session.title,
        subtitle: 'Reprendre à la question $currentQ/$totalQ • ${(pct * 100).toInt()}% terminé',
        badgeText: 'Session Sur-Mesure',
        badgeColor: const Color(0xFF8B5CF6),
        icon: Icons.dashboard_customize_rounded,
        iconColor: const Color(0xFF8B5CF6),
        timestamp: session.lastActiveAt,
        progressPercent: pct,
        data: {
          'sessionId': session.id,
          'session': session,
        },
      ));
    }
    return items;
  };

  registry.registerRouteHandler('activity:qcmCourse', (context, data) async {
    final courseId = data['courseId'] as String? ?? 'c_cardio_hta';
    CourseModel? course = await ResidencyRepository.findCourseById(courseId);
    course ??= const CourseModel(
      id: 'c_cardio_hta',
      moduleId: 'Blida_CARDIOLOGIE',
      name: 'Hypertension Artérielle de l\'Adulte (HTA)',
      questionsCount: 340,
      hasPdf: true,
    );
    if (context.mounted) {
      context.read<RevisionBloc>().add(OpenCourseQuestionsEvent(course, resume: true));
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QcmStudyScreen()));
      return true;
    }
    return false;
  });

  registry.registerRouteHandler('activity:qcmCustomSession', (context, data) async {
    final session = data['session'] as CustomRevisionSession?;
    if (session != null && context.mounted) {
      context.read<RevisionBloc>().add(StartCustomSessionEvent(session, resume: true));
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QcmStudyScreen()));
      return true;
    }
    return false;
  });

  registry.registerRouteHandler('activity:courseDocument', (context, data) async {
    final courseId = data['courseId'] as String? ?? 'c_cardio_hta';
    final moduleName = data['moduleName'] as String? ?? 'Cardiologie';
    CourseModel? course = await ResidencyRepository.findCourseById(courseId);
    course ??= const CourseModel(
      id: 'c_cardio_hta',
      moduleId: 'Blida_CARDIOLOGIE',
      name: 'Hypertension Artérielle de l\'Adulte (HTA)',
      questionsCount: 340,
      hasPdf: true,
    );
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CoursePdfViewerScreen(course: course!, moduleName: moduleName),
        ),
      );
      return true;
    }
    return false;
  });
}
