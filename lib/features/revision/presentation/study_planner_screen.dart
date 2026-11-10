import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/revision_bloc.dart';
import '../bloc/revision_event.dart';
import '../bloc/revision_state.dart';
import '../models/module_model.dart';
import '../services/user_qcm_annotation_service.dart';
import 'active_study_plan_widget.dart';
import 'course_pdf_viewer_screen.dart';
import 'course_summary_screen.dart';
import 'laureate_study_plans_sheet.dart';
import 'qcm_study_screen.dart';

class StudyPlannerScreen extends StatefulWidget {
  const StudyPlannerScreen({super.key});

  @override
  State<StudyPlannerScreen> createState() => _StudyPlannerScreenState();
}

class _StudyPlannerScreenState extends State<StudyPlannerScreen> {
  final UserQcmAnnotationService _annService = UserQcmAnnotationService.instance;
  String _searchQuery = '';
  bool _onlyHighYield = false;
  bool _onlyIncomplete = false;

  @override
  void initState() {
    super.initState();
    _annService.ensureInitialized().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<RevisionBloc, RevisionState>(
      builder: (context, state) {
        return ListenableBuilder(
          listenable: _annService,
          builder: (context, _) {
            final allModules = state.modules;
            final allCourses = <_CourseWithModule>[];
            for (final m in allModules) {
              for (final c in m.courses) {
                allCourses.add(_CourseWithModule(module: m, course: c));
              }
            }

            // Compute global layer progress
            int totalLayersPossible = allCourses.length * 3;
            int completedLayers = 0;
            int layer1Total = 0;
            int layer2Total = 0;
            int layer3Total = 0;

            for (final item in allCourses) {
              final entry = _annService.getPlannerEntry(
                item.course.id,
                moduleId: item.module.id,
              );
              completedLayers += entry.completedLayersCount;
              if (entry.layer1Done) layer1Total++;
              if (entry.layer2Done) layer2Total++;
              if (entry.layer3Done) layer3Total++;
            }

            final globalPct = totalLayersPossible > 0
                ? (completedLayers / totalLayersPossible) * 100
                : 0.0;

            // Top 3 recommended courses today (Highest exam question weight * incomplete layers)
            final recommended = List<_CourseWithModule>.from(allCourses)
              ..sort((a, b) {
                final ea = _annService.getPlannerEntry(a.course.id);
                final eb = _annService.getPlannerEntry(b.course.id);
                final scoreA = a.course.questionsCount * (3 - ea.completedLayersCount);
                final scoreB = b.course.questionsCount * (3 - eb.completedLayersCount);
                return scoreB.compareTo(scoreA);
              });
            final top3Recommendations = recommended.take(3).toList();

            return Scaffold(
              appBar: AppBar(
                title: const Row(
                  children: [
                    Icon(Icons.calendar_month_rounded, color: AppTheme.primaryTeal, size: 22),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Study Planner par Couches & Analytics',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton.icon(
                    icon: const Icon(Icons.workspace_premium_rounded, size: 17, color: Color(0xFFF59E0B)),
                    label: const Text('Plans Lauréats', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => LaureateStudyPlansSheet.show(context),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.event_available_rounded, size: 17),
                    label: const Text('Échéance', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => _pickTargetExamDate(context),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 0. Plan de Révision des Lauréats & Objectifs Quotidiens
                  const ActiveStudyPlanWidget(),
                  const SizedBox(height: 16),

                  // 1. Countdown & Cadence Calculator Banner
                  _buildCadenceOverviewCard(
                    context,
                    totalCourses: allCourses.length,
                    layer1Done: layer1Total,
                    layer2Done: layer2Total,
                    layer3Done: layer3Total,
                    globalPct: globalPct,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),

                  // 2. Diagnostic IA : Top 3 High-Yield Courses to study today
                  if (top3Recommendations.isNotEmpty) ...[
                    _buildTopRecommendationsCard(context, top3Recommendations, isDark),
                    const SizedBox(height: 18),
                  ],

                  // 3. Search & Filters
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search_rounded, size: 20),
                            hintText: 'Rechercher un module ou un cours...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          onChanged: (v) => setState(() => _searchQuery = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      FilterChip(
                        label: const Text('🔥 Cours à Haute Tombabilité (>20 QCM)', style: TextStyle(fontSize: 11.5)),
                        selected: _onlyHighYield,
                        selectedColor: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                        visualDensity: VisualDensity.compact,
                        onSelected: (v) => setState(() => _onlyHighYield = v),
                      ),
                      FilterChip(
                        label: const Text('⏳ Non terminés (< 3 couches)', style: TextStyle(fontSize: 11.5)),
                        selected: _onlyIncomplete,
                        selectedColor: AppTheme.primaryTeal.withValues(alpha: 0.16),
                        visualDensity: VisualDensity.compact,
                        onSelected: (v) => setState(() => _onlyIncomplete = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 4. Modules & 3-Layer Courses Matrix
                  ...allModules.map((mod) => _buildModulePlannerCard(context, mod, isDark)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCadenceOverviewCard(
    BuildContext context, {
    required int totalCourses,
    required int layer1Done,
    required int layer2Done,
    required int layer3Done,
    required double globalPct,
    required bool isDark,
  }) {
    final examDate = _annService.targetExamDate;
    final daysRemaining = math.max(1, examDate.difference(DateTime.now()).inDays);
    final remainingLayer1 = math.max(0, totalCourses - layer1Done);
    final coursesPerDay = (remainingLayer1 / daysRemaining).toStringAsFixed(1);
    final summaryCounts = _annService.getGlobalSummaryCounts();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0F292E), const Color(0xFF0F172A)]
              : [const Color(0xFFF0FDFA), const Color(0xFFE0F2FE)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryTeal.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_rounded, color: AppTheme.primaryTeal, size: 20),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'J-$daysRemaining avant votre échéance (${examDate.day.toString().padLeft(2, '0')}/${examDate.month.toString().padLeft(2, '0')}/${examDate.year})',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Cadence cible : $coursesPerDay cours/jour',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryTeal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (globalPct / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryTeal),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _buildLayerCounterBadge('Couche 1 (Lecture)', '$layer1Done/$totalCourses', const Color(0xFF0284C7), isDark),
              _buildLayerCounterBadge('Couche 2 (Mémorisation)', '$layer2Done/$totalCourses', const Color(0xFF8B5CF6), isDark),
              _buildLayerCounterBadge('Couche 3 (Finale)', '$layer3Done/$totalCourses', const Color(0xFF10B981), isDark),
              _buildLayerCounterBadge('QCM pratiqués', '${summaryCounts['consulted']}', const Color(0xFFF59E0B), isDark),
              _buildLayerCounterBadge('Erreurs à revoir', '${summaryCounts['wrong']}', const Color(0xFFEF4444), isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLayerCounterBadge(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.grey.shade700)),
          const SizedBox(width: 6),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _buildTopRecommendationsCard(
    BuildContext context,
    List<_CourseWithModule> top3,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bolt_rounded, color: Color(0xFFD97706), size: 20),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Priorités du Jour (Haut Rendement Examens Blida × Couches restantes)',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...top3.map((item) {
            final entry = _annService.getPlannerEntry(item.course.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _showCourseActionsSheet(
                  context,
                  course: item.course,
                  moduleName: item.module.name,
                  module: item.module,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          '🔥 ${item.course.questionsCount} QCM',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item.module.name} • ${item.course.name}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${entry.completedLayersCount}/3 couches validées',
                              style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: const Size(0, 30),
                          side: BorderSide(color: const Color(0xFF0284C7).withValues(alpha: 0.5)),
                        ),
                        icon: const Icon(Icons.menu_book_rounded, size: 13, color: Color(0xFF0284C7)),
                        label: const Text(
                          'Cours',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                        ),
                        onPressed: () => _openCoursePdf(context, item.course, item.module.name),
                      ),
                      const SizedBox(width: 6),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: AppTheme.primaryTeal,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: const Size(0, 30),
                        ),
                        icon: const Icon(Icons.play_circle_fill_rounded, size: 13, color: Colors.white),
                        label: const Text(
                          'QCM',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        onPressed: () => _startCourseQcm(context, item.course),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildModulePlannerCard(
    BuildContext context,
    MedicalModuleModel mod,
    bool isDark,
  ) {
    final filteredCourses = mod.courses.where((c) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matches = mod.name.toLowerCase().contains(q) ||
            c.name.toLowerCase().contains(q);
        if (!matches) return false;
      }
      if (_onlyHighYield && c.questionsCount < 20) return false;
      if (_onlyIncomplete) {
        final entry = _annService.getPlannerEntry(c.id);
        if (entry.completedLayersCount >= 3) return false;
      }
      return true;
    }).toList();

    if (filteredCourses.isEmpty) return const SizedBox.shrink();

    int modLayersDone = 0;
    for (final c in mod.courses) {
      modLayersDone += _annService.getPlannerEntry(c.id).completedLayersCount;
    }
    final modTotalLayers = math.max(1, mod.courses.length * 3);
    final modPct = ((modLayersDone / modTotalLayers) * 100).round();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade200),
      ),
      child: ExpansionTile(
        key: PageStorageKey('planner_${mod.id}'),
        initiallyExpanded: _searchQuery.isNotEmpty,
        title: Row(
          children: [
            Expanded(
              child: Text(
                mod.name,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$modPct% ($modLayersDone/$modTotalLayers)',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryTeal,
                ),
              ),
            ),
          ],
        ),
        children: filteredCourses.map((course) {
          final entry = _annService.getPlannerEntry(course.id, moduleId: mod.id);
          final mastery = _annService.getCourseMasteryPercent(course.id).round();

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade100),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _showCourseActionsSheet(
                    context,
                    course: course,
                    moduleName: mod.name,
                    module: mod,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.menu_book_rounded,
                          size: 16,
                          color: AppTheme.primaryTeal,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            course.name,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: course.questionsCount >= 25
                                ? const Color(0xFFF59E0B).withValues(alpha: 0.16)
                                : Colors.grey.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            '${course.questionsCount} QCM',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: course.questionsCount >= 25 ? const Color(0xFFB45309) : null,
                            ),
                          ),
                        ),
                        if (mastery > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              'Maîtrise: $mastery%',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: isDark ? Colors.white38 : Colors.grey.shade400,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildLayerCheckChip(
                      label: 'Couche 1',
                      checked: entry.layer1Done,
                      color: const Color(0xFF0284C7),
                      onTap: () => _annService.togglePlannerLayer(
                        courseId: course.id,
                        moduleId: mod.id,
                        layerIndex: 1,
                      ),
                    ),
                    _buildLayerCheckChip(
                      label: 'Couche 2',
                      checked: entry.layer2Done,
                      color: const Color(0xFF8B5CF6),
                      onTap: () => _annService.togglePlannerLayer(
                        courseId: course.id,
                        moduleId: mod.id,
                        layerIndex: 2,
                      ),
                    ),
                    _buildLayerCheckChip(
                      label: 'Couche 3',
                      checked: entry.layer3Done,
                      color: const Color(0xFF10B981),
                      onTap: () => _annService.togglePlannerLayer(
                        courseId: course.id,
                        moduleId: mod.id,
                        layerIndex: 3,
                      ),
                    ),
                    ActionChip(
                      avatar: const Icon(
                        Icons.menu_book_rounded,
                        size: 14,
                        color: Color(0xFF0284C7),
                      ),
                      label: const Text(
                        'Cours',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                      ),
                      tooltip: 'Ouvrir le support complet du cours (PDF)',
                      visualDensity: VisualDensity.compact,
                      backgroundColor: const Color(0xFF0284C7).withValues(alpha: 0.1),
                      side: BorderSide(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
                      onPressed: () => _openCoursePdf(context, course, mod.name),
                    ),
                    ActionChip(
                      avatar: const Icon(
                        Icons.article_outlined,
                        size: 14,
                        color: Color(0xFF8B5CF6),
                      ),
                      label: const Text(
                        'Fiche',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                      ),
                      tooltip: 'Consulter la fiche de synthèse High-Yield',
                      visualDensity: VisualDensity.compact,
                      backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                      side: BorderSide(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                      onPressed: () => _openCourseSummary(context, course, mod.name),
                    ),
                    ActionChip(
                      avatar: const Icon(
                        Icons.play_circle_outline_rounded,
                        size: 14,
                        color: AppTheme.primaryTeal,
                      ),
                      label: const Text(
                        'QCM',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal),
                      ),
                      tooltip: 'S\'entraîner aux QCMs du cours',
                      visualDensity: VisualDensity.compact,
                      backgroundColor: AppTheme.primaryTeal.withValues(alpha: 0.1),
                      side: BorderSide(color: AppTheme.primaryTeal.withValues(alpha: 0.3)),
                      onPressed: () => _startCourseQcm(context, course),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLayerCheckChip({
    required String label,
    required bool checked,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: checked ? color.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: checked ? color : Colors.grey.shade400,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              checked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
              size: 15,
              color: checked ? color : Colors.grey.shade500,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: checked ? FontWeight.w800 : FontWeight.w600,
                color: checked ? color : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTargetExamDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _annService.targetExamDate,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) {
      await _annService.setTargetExamDate(picked);
    }
  }

  void _openCoursePdf(BuildContext context, CourseModel course, String moduleName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CoursePdfViewerScreen(
          course: course,
          moduleName: moduleName,
        ),
      ),
    );
  }

  void _openCourseSummary(BuildContext context, CourseModel course, String moduleName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CourseSummaryScreen(
          course: course,
          moduleName: moduleName,
        ),
      ),
    );
  }

  void _startCourseQcm(BuildContext context, CourseModel course) {
    final isStudent = context.read<AuthBloc>().state.user?.isStudent == true;
    context.read<RevisionBloc>().add(
          OpenCourseQuestionsEvent(course, resume: false, filterForStudent: isStudent),
        );
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const QcmStudyScreen()),
    );
  }

  void _showCourseActionsSheet(
    BuildContext context, {
    required CourseModel course,
    required String moduleName,
    required MedicalModuleModel module,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mastery = _annService.getCourseMasteryPercent(course.id).round();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final currentEntry = _annService.getPlannerEntry(course.id, moduleId: module.id);
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryTeal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.school_rounded, color: AppTheme.primaryTeal, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                moduleName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                course.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Badges
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '🔥 ${course.questionsCount} QCMs',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFB45309),
                            ),
                          ),
                        ),
                        if (mastery > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Maîtrise: $mastery%',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryTeal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${currentEntry.completedLayersCount}/3 Couches',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryTeal,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Actions section
                    Text(
                      'ACCÉDER AU COURS & RÉVISIONS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 1. Lire le cours (PDF)
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: const Color(0xFF0284C7).withValues(alpha: 0.25)),
                      ),
                      tileColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF0F9FF),
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        radius: 18,
                        child: Icon(Icons.picture_as_pdf_rounded, size: 18),
                      ),
                      title: const Text(
                        'Lire le Cours (Support PDF)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                      subtitle: const Text(
                        'Support officiel complet (Couche 1 : Lecture & Compréhension)',
                        style: TextStyle(fontSize: 11),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () {
                        Navigator.pop(ctx);
                        _openCoursePdf(context, course, moduleName);
                      },
                    ),
                    const SizedBox(height: 8),

                    // 2. Fiche de synthèse High-Yield
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: const Color(0xFF8B5CF6).withValues(alpha: 0.25)),
                      ),
                      tileColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFFAF5FF),
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        radius: 18,
                        child: Icon(Icons.menu_book_rounded, size: 18),
                      ),
                      title: const Text(
                        'Fiche de Synthèse High-Yield',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                      subtitle: const Text(
                        'Points clés, pièges & perles de concours (Couche 2 : Mémorisation)',
                        style: TextStyle(fontSize: 11),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () {
                        Navigator.pop(ctx);
                        _openCourseSummary(context, course, moduleName);
                      },
                    ),
                    const SizedBox(height: 8),

                    // 3. Entraînement QCM
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppTheme.primaryTeal.withValues(alpha: 0.25)),
                      ),
                      tileColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF0FDFA),
                      leading: const CircleAvatar(
                        backgroundColor: AppTheme.primaryTeal,
                        foregroundColor: Colors.white,
                        radius: 18,
                        child: Icon(Icons.play_arrow_rounded, size: 20),
                      ),
                      title: const Text(
                        'S\'entraîner aux QCMs',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                      subtitle: Text(
                        '${course.questionsCount} questions d\'annales corrigées (Couche 3 : Finale)',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () {
                        Navigator.pop(ctx);
                        _startCourseQcm(context, course);
                      },
                    ),

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Toggle Layers in Modal
                    Text(
                      'VALIDATION DES COUCHES D\'APPRENTISSAGE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildLayerCheckChip(
                            label: 'Couche 1',
                            checked: currentEntry.layer1Done,
                            color: const Color(0xFF0284C7),
                            onTap: () async {
                              await _annService.togglePlannerLayer(
                                courseId: course.id,
                                moduleId: module.id,
                                layerIndex: 1,
                              );
                              setModalState(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildLayerCheckChip(
                            label: 'Couche 2',
                            checked: currentEntry.layer2Done,
                            color: const Color(0xFF8B5CF6),
                            onTap: () async {
                              await _annService.togglePlannerLayer(
                                courseId: course.id,
                                moduleId: module.id,
                                layerIndex: 2,
                              );
                              setModalState(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildLayerCheckChip(
                            label: 'Couche 3',
                            checked: currentEntry.layer3Done,
                            color: const Color(0xFF10B981),
                            onTap: () async {
                              await _annService.togglePlannerLayer(
                                courseId: course.id,
                                moduleId: module.id,
                                layerIndex: 3,
                              );
                              setModalState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _CourseWithModule {
  final MedicalModuleModel module;
  final CourseModel course;

  const _CourseWithModule({required this.module, required this.course});
}
