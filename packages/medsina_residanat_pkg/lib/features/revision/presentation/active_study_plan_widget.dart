import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medsina_core/core/theme/app_theme.dart';
import 'package:medsina_core/features/auth/bloc/auth_bloc.dart';
import 'package:medsina_study_engine/features/revision/bloc/revision_bloc.dart';
import 'package:medsina_study_engine/features/revision/bloc/revision_event.dart';
import 'package:medsina_study_engine/features/revision/data/residency_repository.dart';
import '../models/laureate_study_plan_model.dart';
import 'package:medsina_study_engine/features/revision/models/module_model.dart';
import '../services/laureate_study_plan_service.dart';
import '../services/realistic_course_schedule_service.dart';
import 'package:medsina_study_engine/features/revision/services/user_qcm_annotation_service.dart';
import 'package:medsina_study_engine/features/revision/presentation/course_pdf_viewer_screen.dart';
import 'laureate_study_plans_sheet.dart';
import 'package:medsina_study_engine/features/revision/presentation/qcm_study_screen.dart';

class ActiveStudyPlanWidget extends StatelessWidget {
  final VoidCallback? onPlanChanged;

  const ActiveStudyPlanWidget({super.key, this.onPlanChanged});

  Color _parseHex(String hex, {Color fallback = AppTheme.primaryTeal}) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = LaureateStudyPlanService.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final plan = service.activePlan;
        final progress = service.activeProgress;

        if (plan == null || progress == null) {
          return _buildNoActivePlanBanner(context, isDark);
        }

        final accentColor = _parseHex(plan.accentColorHex);
        final currentPhase = service.getCurrentPhase();
        final progressPct = service.calculateWeekProgress();
        final quote = service.getTodayQuote();

        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: accentColor.withOpacity(0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header banner with Laureate Accent
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        plan.rankBadge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.strategyTitle,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Méthode ${plan.laureateName}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? Colors.white70 : Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.event_available_rounded, size: 12, color: accentColor),
                              const SizedBox(width: 4),
                              Text(
                                'Échéance : ${progress.targetExamDate.day.toString().padLeft(2, '0')}/${progress.targetExamDate.month.toString().padLeft(2, '0')}/${progress.targetExamDate.year} • J-${math.max(1, progress.targetExamDate.difference(DateTime.now()).inDays)}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: accentColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                      tooltip: 'Changer de plan',
                      onPressed: () {
                        LaureateStudyPlansSheet.show(
                          context,
                          onPlanSelected: onPlanChanged,
                        );
                      },
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Daily Laureate Quote Callout
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black.withOpacity(0.25)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border(
                          left: BorderSide(color: accentColor, width: 4),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.format_quote_rounded,
                              size: 18, color: accentColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              quote,
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                height: 1.35,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Today's Goals Row
                    Row(
                      children: [
                        // Courses Goal
                        Expanded(
                          child: _buildGoalCard(
                            context,
                            isDark: isDark,
                            title: 'Cours du Jour',
                            current: progress.todayCompletedCourseIds.length,
                            target: plan.targetDailyCourses,
                            unit: 'cours',
                            accentColor: accentColor,
                            icon: Icons.menu_book_rounded,
                            onIncrement: () {
                              service.toggleTodayCourse(
                                  'manual_${DateTime.now().millisecondsSinceEpoch}');
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        // QCMs Goal
                        Expanded(
                          child: _buildGoalCard(
                            context,
                            isDark: isDark,
                            title: 'QCMs du Jour',
                            current: progress.todayCompletedQcms,
                            target: plan.targetDailyQcms,
                            unit: 'QCMs',
                            accentColor: accentColor,
                            icon: Icons.quiz_rounded,
                            onIncrement: () {
                              service.addTodayQcms(10);
                            },
                          ),
                        ),
                      ],
                    ),

                    // Scheduled Courses Today from Realistic Schedule
                    Builder(
                      builder: (ctx) {
                        final allModules = ctx.read<RevisionBloc>().state.modules.isNotEmpty
                            ? ctx.read<RevisionBloc>().state.modules
                            : ResidencyRepository.getModules();
                        final schedulePlan = RealisticCourseScheduleService.instance.generateSchedule(
                          allModules: allModules,
                          targetExamDate: progress.targetExamDate,
                          activePlan: plan,
                          annotationService: UserQcmAnnotationService.instance,
                        );
                        final todayItems = schedulePlan.todayCourses;

                        if (todayItems.isEmpty) return const SizedBox.shrink();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Icon(Icons.calendar_today_rounded, size: 14, color: accentColor),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Cours au programme aujourd\'hui (${todayItems.where((c) => c.isCompleted).length}/${todayItems.length})',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...todayItems.map((item) {
                              final isDone = item.isCompleted;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isDone
                                      ? (isDark
                                          ? const Color(0xFF064E3B).withValues(alpha: 0.2)
                                          : const Color(0xFFECFDF5))
                                      : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDone
                                        ? const Color(0xFF10B981).withValues(alpha: 0.4)
                                        : (isDark ? Colors.white12 : Colors.grey.shade300),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    InkWell(
                                      borderRadius: BorderRadius.circular(6),
                                      onTap: () async {
                                        await RealisticCourseScheduleService.instance.toggleCourseCompletion(
                                          courseId: item.course.id,
                                          moduleId: item.module.id,
                                        );
                                      },
                                      child: Icon(
                                        isDone
                                            ? Icons.check_circle_rounded
                                            : Icons.radio_button_unchecked_rounded,
                                        size: 20,
                                        color: isDone ? const Color(0xFF10B981) : Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.module.name,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: accentColor,
                                            ),
                                          ),
                                          Text(
                                            item.course.name,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              decoration: isDone ? TextDecoration.lineThrough : null,
                                              color: isDone ? Colors.grey : null,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(6),
                                      onTap: () {
                                        Navigator.of(ctx).push(
                                          MaterialPageRoute(
                                            builder: (_) => CoursePdfViewerScreen(
                                              course: item.course,
                                              moduleName: item.module.name,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'Cours',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0284C7),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(6),
                                      onTap: () {
                                        final isStudent = ctx.read<AuthBloc>().state.user?.isStudent == true;
                                        ctx.read<RevisionBloc>().add(
                                              OpenCourseQuestionsEvent(
                                                item.course,
                                                resume: false,
                                                filterForStudent: isStudent,
                                              ),
                                            );
                                        Navigator.of(ctx).push(
                                          MaterialPageRoute(builder: (_) => const QcmStudyScreen()),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryTeal.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'QCM',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primaryTeal,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),

                    // Phase & Overall Trajectory
                    if (currentPhase != null) ...[
                      Row(
                        children: [
                          Icon(Icons.timeline_rounded,
                              size: 15, color: accentColor),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Phase ${currentPhase.phaseIndex} : ${currentPhase.name}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${(progressPct * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progressPct,
                          minHeight: 6,
                          backgroundColor: isDark ? Colors.white12 : Colors.black12,
                          valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Daily Reminder info bar
                    Row(
                      children: [
                        Icon(
                          progress.remindersEnabled
                              ? Icons.alarm_on_rounded
                              : Icons.alarm_off_rounded,
                          size: 15,
                          color: progress.remindersEnabled
                              ? AppTheme.primaryTeal
                              : Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          progress.remindersEnabled
                              ? 'Rappel à ${progress.reminderHour.toString().padLeft(2, '0')}:${progress.reminderMinute.toString().padLeft(2, '0')}'
                              : 'Rappels désactivés',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? Colors.white60 : Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () {
                            service.updateReminderSettings(
                              enabled: !progress.remindersEnabled,
                            );
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            child: Text(
                              progress.remindersEnabled ? 'Désactiver' : 'Activer',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: accentColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGoalCard(
    BuildContext context, {
    required bool isDark,
    required String title,
    required int current,
    required int target,
    required String unit,
    required Color accentColor,
    required IconData icon,
    required VoidCallback onIncrement,
  }) {
    final isDone = current >= target;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDone
              ? Colors.green.withOpacity(0.4)
              : (isDark ? Colors.white10 : Colors.black12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: isDone ? Colors.green : accentColor),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isDone)
                const Icon(Icons.check_circle_rounded,
                    size: 14, color: Colors.green),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$current',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: isDone ? Colors.green : accentColor,
                ),
              ),
              Text(
                ' / $target $unit',
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: onIncrement,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.add, size: 14, color: accentColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoActivePlanBanner(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFFF0FDFA), const Color(0xFFE0F2FE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primaryTeal.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.stars_rounded,
                    color: AppTheme.primaryTeal, size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plans de Révision des Lauréats',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Adoptez la méthode éprouvée d\'un Major du Résidanat',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Choisissez parmi 4 plans structurés (Dr Benouarab TOP 4, Dr Djellata TOP 9, Dr Barrag TOP 18, Dr Megateli) avec cadences quotidiennes et rappels personnalisés.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryTeal,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
              icon: const Icon(Icons.touch_app_rounded, size: 18),
              label: const Text(
                'Choisir mon Plan de Révision',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                LaureateStudyPlansSheet.show(
                  context,
                  onPlanSelected: onPlanChanged,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
