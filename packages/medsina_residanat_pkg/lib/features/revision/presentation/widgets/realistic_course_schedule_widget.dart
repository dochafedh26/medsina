import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medsina_core/core/theme/app_theme.dart';
import 'package:medsina_core/features/auth/bloc/auth_bloc.dart';
import 'package:medsina_study_engine/features/revision/bloc/revision_bloc.dart';
import 'package:medsina_study_engine/features/revision/bloc/revision_event.dart';
import '../../models/course_schedule_model.dart';
import 'package:medsina_study_engine/features/revision/models/module_model.dart';
import '../../services/laureate_study_plan_service.dart';
import '../../services/realistic_course_schedule_service.dart';
import 'package:medsina_study_engine/features/revision/services/user_qcm_annotation_service.dart';
import '../course_mindmap_screen.dart';
import 'package:medsina_study_engine/features/revision/presentation/course_pdf_viewer_screen.dart';
import '../course_summary_screen.dart';
import 'package:medsina_study_engine/features/revision/presentation/qcm_study_screen.dart';

enum ScheduleViewFilter {
  today,
  thisWeek,
  overdue,
  allWeeks,
}

class RealisticCourseScheduleWidget extends StatefulWidget {
  final List<MedicalModuleModel> allModules;

  const RealisticCourseScheduleWidget({
    super.key,
    required this.allModules,
  });

  @override
  State<RealisticCourseScheduleWidget> createState() =>
      _RealisticCourseScheduleWidgetState();
}

class _RealisticCourseScheduleWidgetState
    extends State<RealisticCourseScheduleWidget> {
  final RealisticCourseScheduleService _scheduleService =
      RealisticCourseScheduleService.instance;
  final UserQcmAnnotationService _annService =
      UserQcmAnnotationService.instance;
  final LaureateStudyPlanService _planService =
      LaureateStudyPlanService.instance;

  ScheduleViewFilter _currentFilter = ScheduleViewFilter.today;
  String _searchFilter = '';
  String? _selectedModuleId;
  final Set<int> _expandedWeeks = {1}; // Week 1 expanded by default

  static const List<String> _frenchMonths = [
    '',
    'Janvier',
    'Février',
    'Mars',
    'Avril',
    'Mai',
    'Juin',
    'Juillet',
    'Août',
    'Septembre',
    'Octobre',
    'Novembre',
    'Décembre',
  ];

  static const List<String> _frenchDays = [
    '',
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];

  String _formatDateShort(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _formatDateFull(DateTime d) {
    final dayName = _frenchDays[d.weekday];
    final monthName = _frenchMonths[d.month];
    return '$dayName ${d.day} $monthName ${d.year}';
  }

  Color _parseHex(String hex, {Color fallback = AppTheme.primaryTeal}) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  Future<void> _pickNewTargetDate(BuildContext context, DateTime currentDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      helpText: "SÉLECTIONNER LA DATE D'ÉCHÉANCE DU CONCOURS",
      cancelText: 'Annuler',
      confirmText: 'Valider',
    );
    if (picked != null) {
      await _scheduleService.setTargetDeadline(picked);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: Listenable.merge([_annService, _planService]),
      builder: (context, _) {
        final activePlan = _planService.activePlan;
        final targetDate = _annService.targetExamDate;

        final plan = _scheduleService.generateSchedule(
          allModules: widget.allModules,
          targetExamDate: targetDate,
          activePlan: activePlan,
          annotationService: _annService,
        );

        final accentColor = activePlan != null
            ? _parseHex(activePlan.accentColorHex)
            : AppTheme.primaryTeal;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Target Exam Countdown & Realistic Cadence Banner
            _buildDeadlineHeaderCard(context, plan, accentColor, isDark),
            const SizedBox(height: 14),

            // 2. View Mode Tabs (Aujourd'hui, Cette Semaine, En retard, Tout le planning)
            _buildNavigationFilters(plan, accentColor, isDark),
            const SizedBox(height: 12),

            // 3. Search & Module filter row
            _buildSearchAndModuleFilterRow(isDark),
            const SizedBox(height: 14),

            // 4. Filtered Content
            _buildScheduleContent(context, plan, accentColor, isDark),
          ],
        );
      },
    );
  }

  Widget _buildDeadlineHeaderCard(
    BuildContext context,
    RealisticSchedulePlan plan,
    Color accentColor,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0F2428), const Color(0xFF0F172A)]
              : [const Color(0xFFF0FDFA), const Color(0xFFE2E8F0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Title & Échéance Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.event_note_rounded, color: accentColor, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Planning Réaliste des Cours',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: accentColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'J-${plan.totalDaysRemaining}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Échéance cible : ${_formatDateFull(plan.targetExamDate)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  side: BorderSide(color: accentColor.withValues(alpha: 0.6)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: Icon(Icons.edit_calendar_rounded, size: 15, color: accentColor),
                label: Text(
                  'Modifier',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: accentColor),
                ),
                onPressed: () => _pickNewTargetDate(context, plan.targetExamDate),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Row 2: Progress indicator
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: plan.globalProgressRatio,
              minHeight: 7,
              backgroundColor: isDark ? Colors.white12 : Colors.black12,
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),

          const SizedBox(height: 12),

          // Row 3: Metrics chips
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildMetricChip(
                label: 'Cadence',
                value: '${plan.dailyCadence.toStringAsFixed(1)} cours/jour',
                icon: Icons.speed_rounded,
                color: accentColor,
                isDark: isDark,
              ),
              _buildMetricChip(
                label: 'Progression',
                value: '${plan.completedCoursesCount}/${plan.totalCoursesCount} cours',
                icon: Icons.check_circle_outline_rounded,
                color: const Color(0xFF10B981),
                isDark: isDark,
              ),
              _buildMetricChip(
                label: 'Temps utile',
                value: '${plan.effectiveStudyDays} j d\'étude + ${plan.consolidationDaysCount} j repos/QCM',
                icon: Icons.calendar_view_week_rounded,
                color: const Color(0xFF3B82F6),
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            '$label : ',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationFilters(
    RealisticSchedulePlan plan,
    Color accentColor,
    bool isDark,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterButton(
            title: "Aujourd'hui",
            count: plan.todayCourses.length,
            selected: _currentFilter == ScheduleViewFilter.today,
            accentColor: accentColor,
            isDark: isDark,
            onTap: () => setState(() => _currentFilter = ScheduleViewFilter.today),
          ),
          const SizedBox(width: 8),
          _buildFilterButton(
            title: 'Cette Semaine',
            count: plan.thisWeekCourses.length,
            selected: _currentFilter == ScheduleViewFilter.thisWeek,
            accentColor: accentColor,
            isDark: isDark,
            onTap: () => setState(() => _currentFilter = ScheduleViewFilter.thisWeek),
          ),
          const SizedBox(width: 8),
          _buildFilterButton(
            title: 'En Retard',
            count: plan.overdueCourses.length,
            selected: _currentFilter == ScheduleViewFilter.overdue,
            accentColor: const Color(0xFFEF4444),
            isDark: isDark,
            badgeColor: const Color(0xFFEF4444),
            onTap: () => setState(() => _currentFilter = ScheduleViewFilter.overdue),
          ),
          const SizedBox(width: 8),
          _buildFilterButton(
            title: 'Planning Complet (${plan.totalWeeksRemaining} sem.)',
            count: null,
            selected: _currentFilter == ScheduleViewFilter.allWeeks,
            accentColor: accentColor,
            isDark: isDark,
            onTap: () => setState(() => _currentFilter = ScheduleViewFilter.allWeeks),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton({
    required String title,
    required int? count,
    required bool selected,
    required Color accentColor,
    required bool isDark,
    Color? badgeColor,
    required VoidCallback onTap,
  }) {
    final activeBg = selected
        ? accentColor.withValues(alpha: 0.16)
        : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: activeBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? accentColor : (isDark ? Colors.white12 : Colors.grey.shade300),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? accentColor : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: (badgeColor ?? accentColor).withValues(alpha: selected ? 1.0 : 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: selected ? Colors.white : (badgeColor ?? accentColor),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndModuleFilterRow(bool isDark) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Filtrer un cours dans le planning...',
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            onChanged: (v) => setState(() => _searchFilter = v),
          ),
        ),
        if (widget.allModules.isNotEmpty) ...[
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade400),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  isExpanded: true,
                  value: _selectedModuleId,
                  hint: const Text('Tous modules', style: TextStyle(fontSize: 11.5)),
                  icon: const Icon(Icons.arrow_drop_down, size: 20),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Tous modules', style: TextStyle(fontSize: 11.5)),
                    ),
                    ...widget.allModules.map((m) => DropdownMenuItem<String?>(
                          value: m.id,
                          child: Text(
                            m.name,
                            style: const TextStyle(fontSize: 11.5),
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                  ],
                  onChanged: (val) => setState(() => _selectedModuleId = val),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildScheduleContent(
    BuildContext context,
    RealisticSchedulePlan plan,
    Color accentColor,
    bool isDark,
  ) {
    switch (_currentFilter) {
      case ScheduleViewFilter.today:
        return _buildTodaySection(context, plan, accentColor, isDark);
      case ScheduleViewFilter.thisWeek:
        return _buildThisWeekSection(context, plan, accentColor, isDark);
      case ScheduleViewFilter.overdue:
        return _buildOverdueSection(context, plan, accentColor, isDark);
      case ScheduleViewFilter.allWeeks:
        return _buildAllWeeksSection(context, plan, accentColor, isDark);
    }
  }

  Widget _buildTodaySection(
    BuildContext context,
    RealisticSchedulePlan plan,
    Color accentColor,
    bool isDark,
  ) {
    final filtered = _filterItems(plan.todayCourses);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Today's Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.today_rounded, color: accentColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cours programmés aujourd\'hui • ${_formatDateFull(DateTime.now())}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${filtered.where((c) => c.isCompleted).length}/${filtered.length} fait',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        if (filtered.isEmpty)
          _buildEmptyStateCard(
            title: 'Aucun cours programmé aujourd\'hui',
            subtitle: 'Vous êtes à jour ou c\'est une journée de repos/consolidation !',
            icon: Icons.celebration_rounded,
            color: const Color(0xFF10B981),
            isDark: isDark,
          )
        else
          ...filtered.map((item) => _buildCourseScheduleCard(
                context,
                item: item,
                accentColor: accentColor,
                isDark: isDark,
              )),

        if (filtered.isNotEmpty && filtered.every((c) => c.isCompleted)) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.stars_rounded, color: Color(0xFF10B981), size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '🎯 Objectif quotidien atteint avec succès ! Félicitations pour votre régularité.',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF047857),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildThisWeekSection(
    BuildContext context,
    RealisticSchedulePlan plan,
    Color accentColor,
    bool isDark,
  ) {
    if (plan.weeks.isEmpty) {
      return _buildEmptyStateCard(
        title: 'Aucune semaine disponible',
        subtitle: 'Vérifiez la date d\'échéance sélectionnée.',
        icon: Icons.calendar_today_rounded,
        color: Colors.grey,
        isDark: isDark,
      );
    }

    final firstWeek = plan.weeks.first;
    return _buildWeekCard(context, firstWeek, accentColor, isDark, initiallyExpanded: true);
  }

  Widget _buildOverdueSection(
    BuildContext context,
    RealisticSchedulePlan plan,
    Color accentColor,
    bool isDark,
  ) {
    final filtered = _filterItems(plan.overdueCourses);

    if (filtered.isEmpty) {
      return _buildEmptyStateCard(
        title: 'Aucun cours en retard !',
        subtitle: 'Vous suivez parfaitement le timing réel de votre échéance.',
        icon: Icons.verified_user_rounded,
        color: const Color(0xFF10B981),
        isDark: isDark,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${filtered.length} cours nécessitent un rattrapage prioritaire',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB91C1C),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ...filtered.map((item) => _buildCourseScheduleCard(
              context,
              item: item,
              accentColor: const Color(0xFFEF4444),
              isDark: isDark,
            )),
      ],
    );
  }

  Widget _buildAllWeeksSection(
    BuildContext context,
    RealisticSchedulePlan plan,
    Color accentColor,
    bool isDark,
  ) {
    if (plan.weeks.isEmpty) {
      return _buildEmptyStateCard(
        title: 'Planning vide',
        subtitle: 'Ajustez votre date d\'échéance.',
        icon: Icons.calendar_month_rounded,
        color: Colors.grey,
        isDark: isDark,
      );
    }

    return Column(
      children: plan.weeks.map((week) {
        final isExpanded = _expandedWeeks.contains(week.weekNumber);
        return _buildWeekCard(
          context,
          week,
          accentColor,
          isDark,
          initiallyExpanded: isExpanded,
          onToggle: () {
            setState(() {
              if (isExpanded) {
                _expandedWeeks.remove(week.weekNumber);
              } else {
                _expandedWeeks.add(week.weekNumber);
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildWeekCard(
    BuildContext context,
    ScheduledWeek week,
    Color accentColor,
    bool isDark, {
    bool initiallyExpanded = false,
    VoidCallback? onToggle,
  }) {
    final completed = week.completedCount;
    final total = week.totalCount;
    final pct = total > 0 ? (completed / total * 100).toInt() : 100;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: week.isCurrentWeek
              ? accentColor.withValues(alpha: 0.6)
              : (isDark ? Colors.white12 : Colors.grey.shade300),
          width: week.isCurrentWeek ? 1.5 : 1,
        ),
      ),
      child: ExpansionTile(
        key: PageStorageKey('week_${week.weekNumber}'),
        initiallyExpanded: initiallyExpanded,
        onExpansionChanged: (_) => onToggle?.call(),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: week.isCurrentWeek
                    ? accentColor
                    : (isDark ? Colors.white12 : Colors.grey.shade200),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Semaine ${week.weekNumber}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: week.isCurrentWeek
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    week.phaseName,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Du ${_formatDateShort(week.startDate)} au ${_formatDateShort(week.endDate)}',
                    style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: pct == 100
                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                    : accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$completed/$total ($pct%)',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: pct == 100 ? const Color(0xFF059669) : accentColor,
                ),
              ),
            ),
          ],
        ),
        children: week.days.map((day) => _buildDaySubSection(context, day, accentColor, isDark)).toList(),
      ),
    );
  }

  Widget _buildDaySubSection(
    BuildContext context,
    ScheduledDay day,
    Color accentColor,
    bool isDark,
  ) {
    final filteredCourses = _filterItems(day.courses);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade100),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day header bar
          Row(
            children: [
              Icon(
                day.isToday ? Icons.radio_button_checked_rounded : Icons.calendar_today_rounded,
                size: 13,
                color: day.isToday ? accentColor : Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(
                '${day.label.isNotEmpty ? "${day.label} • " : ""}${_formatDateFull(day.date)}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: day.isToday ? FontWeight.w800 : FontWeight.w600,
                  color: day.isToday ? accentColor : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
              const Spacer(),
              if (day.isRestOrReviewDay)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Text(
                    '🧠 Repos / Consolidation',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFB45309),
                    ),
                  ),
                )
              else
                Text(
                  '${day.completedCount}/${day.totalCount} validé',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Colors.grey.shade600,
                  ),
                ),
            ],
          ),

          if (day.isRestOrReviewDay && day.courses.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 18),
              child: Text(
                'Pas de nouveau cours. Révision des erreurs & consolidation des QCMs.',
                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade600),
              ),
            )
          else ...[
            const SizedBox(height: 6),
            ...filteredCourses.map((item) => _buildCourseScheduleCard(
                  context,
                  item: item,
                  accentColor: accentColor,
                  isDark: isDark,
                  isDense: true,
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildCourseScheduleCard(
    BuildContext context, {
    required ScheduledCourseItem item,
    required Color accentColor,
    required bool isDark,
    bool isDense = false,
  }) {
    final course = item.course;
    final module = item.module;
    final isDone = item.isCompleted;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(isDense ? 10 : 12),
      decoration: BoxDecoration(
        color: isDone
            ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.25) : const Color(0xFFECFDF5))
            : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDone
              ? const Color(0xFF10B981).withValues(alpha: 0.45)
              : (isDark ? Colors.white12 : Colors.grey.shade300),
          width: isDone ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox Toggle
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: Icon(
                  isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: isDone ? const Color(0xFF10B981) : Colors.grey.shade500,
                  size: 22,
                ),
                tooltip: isDone ? 'Marquer comme non fait' : 'Valider ce cours (Couche 1)',
                onPressed: () async {
                  await _scheduleService.toggleCourseCompletion(
                    courseId: course.id,
                    moduleId: module.id,
                  );
                },
              ),
              const SizedBox(width: 6),

              // Title & Module
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            module.name,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                            ),
                          ),
                        ),
                        if (course.isHypertombable || course.questionsCount >= 20) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '🔥 ${course.questionsCount} QCM',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ],
                        if (item.isOverdue) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '⚠️ Rattrapage',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      course.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        color: isDone ? Colors.grey : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Quick Action buttons row (Cours PDF, Fiche, Mind Map, QCM)
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              ActionChip(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                avatar: const Icon(Icons.picture_as_pdf_rounded, size: 13, color: Color(0xFF0284C7)),
                label: const Text('Cours', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                backgroundColor: const Color(0xFF0284C7).withValues(alpha: 0.1),
                side: BorderSide(color: const Color(0xFF0284C7).withValues(alpha: 0.25)),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CoursePdfViewerScreen(
                        course: course,
                        moduleName: module.name,
                      ),
                    ),
                  );
                },
              ),
              ActionChip(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                avatar: const Icon(Icons.menu_book_rounded, size: 13, color: Color(0xFF8B5CF6)),
                label: const Text('Fiche', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                side: BorderSide(color: const Color(0xFF8B5CF6).withValues(alpha: 0.25)),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CourseSummaryScreen(
                        course: course,
                        moduleName: module.name,
                      ),
                    ),
                  );
                },
              ),
              ActionChip(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                avatar: const Icon(Icons.account_tree_rounded, size: 13, color: Color(0xFF8B5CF6)),
                label: const Text('Mind Map', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                side: BorderSide(color: const Color(0xFF8B5CF6).withValues(alpha: 0.25)),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CourseMindmapScreen(
                        course: course,
                        moduleName: module.name,
                      ),
                    ),
                  );
                },
              ),
              ActionChip(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                avatar: const Icon(Icons.play_circle_fill_rounded, size: 13, color: AppTheme.primaryTeal),
                label: Text(
                  '${course.questionsCount} QCM',
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal),
                ),
                backgroundColor: AppTheme.primaryTeal.withValues(alpha: 0.1),
                side: BorderSide(color: AppTheme.primaryTeal.withValues(alpha: 0.3)),
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
  }

  List<ScheduledCourseItem> _filterItems(List<ScheduledCourseItem> items) {
    return items.where((it) {
      if (_selectedModuleId != null && it.module.id != _selectedModuleId) {
        return false;
      }
      if (_searchFilter.isNotEmpty) {
        final q = _searchFilter.toLowerCase();
        final matches = it.course.name.toLowerCase().contains(q) ||
            it.module.name.toLowerCase().contains(q);
        if (!matches) return false;
      }
      return true;
    }).toList();
  }

  Widget _buildEmptyStateCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: color),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
