import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/services/focus_mode_service.dart';
import '../../../core/services/funnel_analytics_service.dart';
import '../bloc/revision_bloc.dart';
import '../bloc/revision_event.dart';
import '../data/residency_repository.dart';
import '../models/module_model.dart';
import '../models/revision_session_model.dart';
import '../presentation/qcm_study_screen.dart';

/// Launches a focused 5-QCM / 3-minute quick-win session from either
/// onboarding completion or the "Aujourd'hui" dashboard hero CTA.
class DailyQuickWinLauncher {
  DailyQuickWinLauncher._();

  static Future<void> launch(
    BuildContext context, {
    int questionCount = 5,
    String source = 'dashboard_today',
    String? role,
  }) async {
    final revisionBloc = context.read<RevisionBloc>();
    List<MedicalModuleModel> modules = revisionBloc.state.modules;

    if (modules.isEmpty) {
      modules = await ResidencyRepository.loadModulesAsync();
      revisionBloc.add(LoadModulesEvent());
    }

    final focus = FocusModeService.instance;
    List<MedicalModuleModel> candidates = modules;
    if (focus.isEnabled) {
      final focused = modules.where((m) => focus.matchesText(m.name)).toList();
      if (focused.isNotEmpty) {
        candidates = focused;
      }
    } else {
      const preferredIds = {
        'mod_cardio',
        'Blida_CARDIOLOGIE',
        'mod_pneumo',
        'Blida_PNEUMOLOGIE',
        'mod_neuro',
        'Blida_NEUROLOGIE',
      };
      final preferred = modules
          .where((m) => preferredIds.contains(m.id) || m.totalQuestions > 0)
          .toList();
      if (preferred.isNotEmpty) {
        candidates = preferred;
      }
    }

    final selectedModules = candidates.take(3).toList();
    final moduleIds = selectedModules.isNotEmpty
        ? selectedModules.map((m) => m.id).toList()
        : <String>['mod_cardio', 'mod_pneumo', 'mod_neuro'];
    final moduleNames = selectedModules.isNotEmpty
        ? selectedModules.map((m) => m.name).toList()
        : <String>['Cardiologie', 'Pneumologie', 'Neurologie'];

    final now = DateTime.now();
    final dayKey =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    final session = CustomRevisionSession(
      id: 'daily_quick_win_${dayKey}_${now.millisecondsSinceEpoch}',
      title: 'QCM du Jour • $questionCount Questions (3 min)',
      moduleIds: moduleIds,
      moduleNames: moduleNames,
      courseIds: const [],
      questionLimit: questionCount,
      shuffleQuestions: true,
      sessionMode: 'revision',
      historyFilter: 'unseen',
      createdAt: now,
      lastActiveAt: now,
    );

    final isStudent = role != null &&
        (role.toLowerCase().contains('externe') ||
            role.toLowerCase().contains('pré-clinique') ||
            role.toLowerCase().contains('pre-clinique'));

    revisionBloc.add(
      StartCustomSessionEvent(
        session,
        filterForStudent: isStudent,
      ),
    );

    FunnelAnalyticsService.instance.trackPlanCreated(
      modules: moduleIds,
      days: 7,
      source: source,
    );

    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const QcmStudyScreen()),
    );
  }
}
