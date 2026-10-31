import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../revision/models/module_model.dart';
import '../../data/models/externat_module_info.dart';
import '../../data/models/externat_pedagogical_models.dart';
import '../../services/externat_pedagogy_service.dart';
import '../externat_course_session_screen.dart';
import '../externat_emd_simulation_screen.dart';
import 'externat_bedside_dialog.dart';

class ExternatRotationBanner extends StatefulWidget {
  final int studyYear;
  final List<MedicalModuleModel> yearModules;
  final VoidCallback? onRotationChanged;

  const ExternatRotationBanner({
    super.key,
    required this.studyYear,
    required this.yearModules,
    this.onRotationChanged,
  });

  @override
  State<ExternatRotationBanner> createState() => _ExternatRotationBannerState();
}

class _ExternatRotationBannerState extends State<ExternatRotationBanner> {
  StudentRotationState? _activeRotation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRotation();
  }

  @override
  void didUpdateWidget(covariant ExternatRotationBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.studyYear != widget.studyYear) {
      _loadRotation();
    }
  }

  Future<void> _loadRotation() async {
    setState(() => _isLoading = true);
    final rot = await ExternatPedagogyService.getActiveRotation(widget.studyYear);
    if (mounted) {
      setState(() {
        _activeRotation = rot;
        _isLoading = false;
      });
    }
  }

  void _showChangeRotationDialog() {
    final modules = ExternatCurriculumMatrix.getModulesForYear(widget.studyYear);
    if (modules.isEmpty) return;

    ExternatModuleInfo selectedMod = modules.firstWhere(
      (m) => m.name == _activeRotation?.moduleName || m.id == _activeRotation?.moduleId,
      orElse: () => modules.first,
    );

    int elapsedDays = _activeRotation?.daysElapsed ?? 7;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.school_rounded, color: AppTheme.primaryTeal, size: 22),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Définir mon Stage en cours',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sélectionnez le module hospitalier ou l\'unité que vous suivez actuellement :',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<ExternatModuleInfo>(
                    initialValue: selectedMod,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Module / Stage',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: modules.map((m) {
                      return DropdownMenuItem(
                        value: m,
                        child: Text('${m.name} (${m.durationWeeks} sem.)', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDlgState(() => selectedMod = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Durée officielle : ${selectedMod.durationWeeks} semaines (${selectedMod.durationWeeks * 7} jours).',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Focus : ${selectedMod.focusSummary}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  const Text('Depuis combien de jours avez-vous débuté ce stage ?', style: TextStyle(fontSize: 12)),
                  Slider(
                    value: elapsedDays.toDouble().clamp(0.0, (selectedMod.durationWeeks * 7).toDouble()),
                    min: 0,
                    max: (selectedMod.durationWeeks * 7).toDouble(),
                    divisions: selectedMod.durationWeeks * 7,
                    label: '$elapsedDays jours',
                    activeColor: AppTheme.primaryTeal,
                    onChanged: (v) => setDlgState(() => elapsedDays = v.round()),
                  ),
                  Center(
                    child: Text(
                      'Débuté il y a $elapsedDays jour(s) • Semaine ${(elapsedDays / 7).floor() + 1} sur ${selectedMod.durationWeeks}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  final newRotation = StudentRotationState(
                    moduleId: selectedMod.id,
                    moduleName: selectedMod.name,
                    studyYear: widget.studyYear,
                    startDate: DateTime.now().subtract(Duration(days: elapsedDays)),
                    durationWeeks: selectedMod.durationWeeks,
                  );
                  await ExternatPedagogyService.saveActiveRotation(newRotation);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadRotation();
                  widget.onRotationChanged?.call();
                },
                child: const Text('Enregistrer mon Stage'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showLecturePicker() {
    final rot = _activeRotation;
    if (rot == null) return;

    // Find courses for this rotation
    final matching = widget.yearModules.where(
      (m) => m.name.toLowerCase().contains(rot.moduleName.toLowerCase()) ||
          rot.moduleName.toLowerCase().contains(m.name.toLowerCase()),
    ).toList();

    final List<CourseModel> courses = [];
    for (final m in matching) {
      courses.addAll(m.courses);
    }

    if (courses.isEmpty) {
      // Default sample course
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExternatCourseSessionScreen(
            moduleName: rot.moduleName,
            courseName: 'Diagnostic & Conduite Pratique',
            studyYear: widget.studyYear,
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.psychology_rounded, color: AppTheme.primaryTeal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Session Enseignant IA • ${rot.moduleName}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Sélectionnez un cours pour lancer la session interactive type amphi :',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: courses.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final c = courses[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      leading: const CircleAvatar(
                        radius: 16,
                        backgroundColor: Color(0xFFF1F5F9),
                        child: Icon(Icons.menu_book_rounded, size: 16, color: AppTheme.primaryTeal),
                      ),
                      title: Text(c.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ExternatCourseSessionScreen(
                              moduleName: rot.moduleName,
                              courseName: c.name,
                              studyYear: widget.studyYear,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _launchEmdSimulation() {
    final rot = _activeRotation;
    if (rot == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExternatEmdSimulationScreen(
          moduleName: rot.moduleName,
          studyYear: widget.studyYear,
          allModules: widget.yearModules,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    }

    final rot = _activeRotation;
    if (rot == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEmdWindow = rot.isEmdWindowOpen;
    final teacher = ExternatCurriculumMatrix.getTeacherForYear(widget.studyYear);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isEmdWindow ? const Color(0xFFF59E0B) : AppTheme.primaryTeal.withValues(alpha: 0.3),
          width: isEmdWindow ? 1.6 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isEmdWindow ? const Color(0xFFF59E0B) : AppTheme.primaryTeal).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1 : Stage Title, Week & Change Button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isEmdWindow ? const Color(0xFFF59E0B) : AppTheme.primaryTeal).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isEmdWindow ? Icons.alarm_on_rounded : Icons.local_hospital_rounded,
                  color: isEmdWindow ? const Color(0xFFD97706) : AppTheme.primaryTeal,
                  size: 20,
                ),
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
                            'Stage en cours : ${rot.moduleName}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isEmdWindow
                                ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                                : const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isEmdWindow ? 'J-${rot.daysRemaining} EMD ⚠️' : 'Semaine ${rot.currentWeek}/${rot.durationWeeks}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isEmdWindow ? const Color(0xFFD97706) : const Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tuteur : ${teacher.name} (${teacher.tagline})',
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_calendar_rounded, size: 20),
                tooltip: 'Modifier mon stage en cours',
                color: AppTheme.primaryTeal,
                onPressed: _showChangeRotationDialog,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: rot.progressPercentage,
              minHeight: 6,
              backgroundColor: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
              color: isEmdWindow ? const Color(0xFFF59E0B) : AppTheme.primaryTeal,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Progression : ${(rot.progressPercentage * 100).toInt()}% (${rot.daysElapsed}/${rot.totalDays} jours)',
                  style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white60 : Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  rot.daysRemaining > 0
                      ? 'EMD dans ${rot.daysRemaining} jour(s)'
                      : 'Session EMD ouverte',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: isEmdWindow ? const Color(0xFFD97706) : AppTheme.primaryTeal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Action Buttons Bar (Responsive Wrap)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // 1. Session de cours type enseignant
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 1,
                ),
                icon: const Icon(Icons.psychology_rounded, size: 16),
                label: const Text('Cours Enseignant IA 👨‍🏫', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                onPressed: _showLecturePicker,
              ),

              // 2. EMD Blanc chronométré
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isEmdWindow ? const Color(0xFFF59E0B) : const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 1,
                ),
                icon: const Icon(Icons.timer_rounded, size: 16),
                label: Text(
                  isEmdWindow ? 'EMD Blanc J-7 (/20) ⏱️' : 'Simuler EMD Blanc ⏱️',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
                onPressed: _launchEmdSimulation,
              ),

              // 3. Mode Lit du Malade
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF10B981),
                  side: const BorderSide(color: Color(0xFF10B981)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.hotel_rounded, size: 16),
                label: const Text('Lit du Malade 🩺', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                onPressed: () {
                  ExternatBedsideDialog.show(context, moduleName: rot.moduleName);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
