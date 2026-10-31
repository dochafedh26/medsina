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
              padding: const EdgeInsets.only(bottom: 6),
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
                    child: Text(
                      '${item.module.name} • ${item.course.name}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${entry.completedLayersCount}/3 couches',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: () {
                      final isStudent = context.read<AuthBloc>().state.user?.isStudent == true;
                      context.read<RevisionBloc>().add(
                            OpenCourseQuestionsEvent(item.course, resume: false, filterForStudent: isStudent),
                          );
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const QcmStudyScreen()),
                      );
                    },
                    child: const Text('Lancer QCM →', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  ),
                ],
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        course.name,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
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
                  ],
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
                      avatar: const Icon(Icons.play_circle_outline_rounded, size: 15, color: AppTheme.primaryTeal),
                      label: const Text('QCM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        final isStudent = context.read<AuthBloc>().state.user?.isStudent == true;
                        context.read<RevisionBloc>().add(
                              OpenCourseQuestionsEvent(course, resume: false, filterForStudent: isStudent),
                            );
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const QcmStudyScreen()),
                        );
                      },
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
}

class _CourseWithModule {
  final MedicalModuleModel module;
  final CourseModel course;

  const _CourseWithModule({required this.module, required this.course});
}
