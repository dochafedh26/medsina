import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/laureate_study_plan_model.dart';
import '../services/laureate_study_plan_service.dart';

class LaureateStudyPlansSheet extends StatefulWidget {
  final VoidCallback? onPlanSelected;

  const LaureateStudyPlansSheet({super.key, this.onPlanSelected});

  static Future<void> show(BuildContext context, {VoidCallback? onPlanSelected}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LaureateStudyPlansSheet(onPlanSelected: onPlanSelected),
    );
  }

  @override
  State<LaureateStudyPlansSheet> createState() => _LaureateStudyPlansSheetState();
}

class _LaureateStudyPlansSheetState extends State<LaureateStudyPlansSheet> {
  final LaureateStudyPlanService _planService = LaureateStudyPlanService.instance;
  String? _selectedPlanId;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);

  @override
  void initState() {
    super.initState();
    _selectedPlanId = _planService.activeProgress?.planId ??
        LaureateStudyPlanService.defaultPlans.first.id;
    if (_planService.activeProgress != null) {
      _reminderTime = TimeOfDay(
        hour: _planService.activeProgress!.reminderHour,
        minute: _planService.activeProgress!.reminderMinute,
      );
    }
  }

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final plans = LaureateStudyPlanService.defaultPlans;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: AppTheme.primaryTeal,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Plans de Révision des Lauréats',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Tirés des 19 témoignages des Majors du Résidanat',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Plans list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: plans.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final plan = plans[index];
                final isSelected = _selectedPlanId == plan.id;
                final isCurrentlyActive =
                    _planService.activeProgress?.planId == plan.id;
                final accentColor = _parseHex(plan.accentColorHex);

                return _buildPlanCard(
                  context,
                  plan: plan,
                  accentColor: accentColor,
                  isSelected: isSelected,
                  isCurrentlyActive: isCurrentlyActive,
                  isDark: isDark,
                );
              },
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
            ),
            child: Row(
              children: [
                // Reminder settings button
                InkWell(
                  onTap: _pickReminderTime,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark ? Colors.white24 : Colors.black12,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.alarm_rounded,
                            size: 18, color: AppTheme.primaryTeal),
                        const SizedBox(width: 6),
                        Text(
                          _reminderTime.format(context),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Adopt button
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryTeal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 20),
                    label: Text(
                      _planService.activeProgress?.planId == _selectedPlanId
                          ? 'Plan Actuellement Suivi'
                          : 'Adopter ce Plan de Lauréat',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () async {
                      if (_selectedPlanId == null) return;
                      await _planService.enrollInPlan(
                        planId: _selectedPlanId!,
                        reminderHour: _reminderTime.hour,
                        reminderMinute: _reminderTime.minute,
                      );
                      widget.onPlanSelected?.call();
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppTheme.primaryTeal,
                            behavior: SnackBarBehavior.floating,
                            content: Row(
                              children: [
                                const Icon(Icons.verified_rounded, color: Colors.white),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Plan de révision activé avec succès ! Rappel quotidien à ${_reminderTime.format(context)}.',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(
    BuildContext context, {
    required LaureateStudyPlanModel plan,
    required Color accentColor,
    required bool isSelected,
    required bool isCurrentlyActive,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () => setState(() => _selectedPlanId = plan.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? accentColor
                : (isDark ? Colors.white12 : Colors.black12),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withOpacity(0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top badges
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    plan.rankBadge,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (isCurrentlyActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check, size: 12, color: Colors.green),
                        SizedBox(width: 4),
                        Text(
                          'Actif',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                Radio<String>(
                  value: plan.id,
                  groupValue: _selectedPlanId,
                  activeColor: accentColor,
                  onChanged: (val) => setState(() => _selectedPlanId = val),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Plan Title & Laureate
            Text(
              plan.strategyTitle,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.person_rounded, size: 14, color: accentColor),
                const SizedBox(width: 4),
                Text(
                  '${plan.laureateName} • ${plan.faculty}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Tagline
            Text(
              plan.strategyTagline,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? Colors.white60 : Colors.black87,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),

            // Metrics row: Hours, Courses/day, QCMs/day, Couches
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withOpacity(0.2)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _metricPill(
                    icon: Icons.schedule_rounded,
                    label: '${plan.recommendedDailyHours}h / jour',
                    accentColor: accentColor,
                  ),
                  _metricPill(
                    icon: Icons.auto_stories_rounded,
                    label: '${plan.targetDailyCourses} cours / j',
                    accentColor: accentColor,
                  ),
                  _metricPill(
                    icon: Icons.quiz_rounded,
                    label: '${plan.targetDailyQcms} QCM / j',
                    accentColor: accentColor,
                  ),
                  _metricPill(
                    icon: Icons.layers_rounded,
                    label: '${plan.layersCount} couches',
                    accentColor: accentColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Key Principles
            const Text(
              'Principes clés & Méthode :',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            ...plan.keyPrinciples.take(2).map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle_outline_rounded,
                            size: 14, color: accentColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            p,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? Colors.white70 : Colors.black87,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: 8),

            // Phases Preview
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: plan.phases.map((phase) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                  ),
                  child: Text(
                    'P${phase.phaseIndex} : ${phase.durationWeeks} sem.',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricPill({
    required IconData icon,
    required String label,
    required Color accentColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: accentColor),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _reminderTime = picked);
    }
  }
}
