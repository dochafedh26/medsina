import '../../auth/bloc/auth_bloc.dart';
import '../../exam/models/exam_session_model.dart';
import '../../exam/presentation/exam_runner_screen.dart';
import '../data/residency_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../bloc/revision_bloc.dart';
import '../bloc/revision_event.dart';
import '../models/module_model.dart';
import '../models/revision_session_model.dart';
import 'qcm_study_screen.dart';

class CustomSessionBuilderDialog extends StatefulWidget {
  final List<MedicalModuleModel> allModules;

  const CustomSessionBuilderDialog({super.key, required this.allModules});

  static Future<void> show(BuildContext context, List<MedicalModuleModel> modules) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CustomSessionBuilderDialog(allModules: modules),
    );
  }

  @override
  State<CustomSessionBuilderDialog> createState() => _CustomSessionBuilderDialogState();
}

class _CustomSessionBuilderDialogState extends State<CustomSessionBuilderDialog> {
  late TextEditingController _titleController;
  final Set<String> _selectedModuleIds = {};
  final Set<String> _selectedCourseIds = {};
  int _questionLimit = 20;
  bool _shuffle = true;
  String _sessionMode = 'revision'; // 'revision' or 'exam'
  String _correctionStyle = 'allOrNothing'; // 'allOrNothing' or 'partial'
  int _durationMinutes = 30;
  String _historyFilter = 'all'; // 'all', 'unseen', 'wrong', 'marked', 'withNotes', 'highYield'
  final Set<String> _allowedTypes = {'qcs', 'qcm', 'casClinique'};
  String _moduleFilter = '';

  @override
  void initState() {
    super.initState();
    final dateStr = DateTime.now().toString().substring(0, 10);
    final authUser = context.read<AuthBloc>().state.user;
    final isStudent = authUser?.isStudent == true;
    final defaultTitle = isStudent ? 'Session EMD $dateStr' : 'Session Révision $dateStr';
    _titleController = TextEditingController(text: defaultTitle);

    // Pre-select first module if available
    if (widget.allModules.isNotEmpty) {
      final first = widget.allModules.first;
      _selectedModuleIds.add(first.id);
      for (final c in first.courses.take(3)) {
        _selectedCourseIds.add(c.id);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _toggleModule(MedicalModuleModel module, bool selected) {
    setState(() {
      if (selected) {
        _selectedModuleIds.add(module.id);
        // Automatically select all courses of this module by default
        for (final c in module.courses) {
          _selectedCourseIds.add(c.id);
        }
      } else {
        _selectedModuleIds.remove(module.id);
        for (final c in module.courses) {
          _selectedCourseIds.remove(c.id);
        }
      }
    });
  }

  void _toggleCourse(String courseId, bool selected) {
    setState(() {
      if (selected) {
        _selectedCourseIds.add(courseId);
      } else {
        _selectedCourseIds.remove(courseId);
      }
    });
  }

  void _startSession() async {
    if (_selectedCourseIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner au moins un cours pour cette session.')),
      );
      return;
    }

    final chosenModules = widget.allModules.where((m) => _selectedModuleIds.contains(m.id)).toList();
    final chosenCourses = <CourseModel>[];
    for (final m in chosenModules) {
      chosenCourses.addAll(m.courses.where((c) => _selectedCourseIds.contains(c.id)));
    }

    final session = CustomRevisionSession(
      id: 'session_${DateTime.now().millisecondsSinceEpoch}',
      title: _titleController.text.trim().isEmpty ? 'Session Sur-Mesure' : _titleController.text.trim(),
      moduleIds: _selectedModuleIds.toList(),
      moduleNames: chosenModules.map((m) => m.name).toList(),
      courseIds: _selectedCourseIds.toList(),
      courseNames: chosenCourses.map((c) => c.name).toList(),
      questionLimit: _questionLimit,
      shuffleQuestions: _shuffle,
      sessionMode: _sessionMode,
      correctionStyle: _correctionStyle,
      durationMinutes: _sessionMode == 'exam' ? _durationMinutes : null,
      historyFilter: _historyFilter,
      allowedTypes: _allowedTypes.isEmpty ? const ['qcs', 'qcm', 'casClinique'] : _allowedTypes.toList(),
      totalQuestions: 0,
      createdAt: DateTime.now(),
      lastActiveAt: DateTime.now(),
    );

    Navigator.of(context).pop();

    if (_sessionMode == 'exam') {
      final rawPool = await ResidencyRepository.getQuestionsForMultipleCoursesAsync(
        courseIds: _selectedCourseIds.toList(),
        moduleIds: _selectedModuleIds.toList(),
        limit: _questionLimit,
        shuffle: _shuffle,
      );
      if (rawPool.isNotEmpty && context.mounted) {
        final examSession = ExamSessionModel(
          id: session.id,
          title: session.title,
          questions: rawPool,
          durationMinutes: _durationMinutes,
          startedAt: DateTime.now(),
        );
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ExamRunnerScreen(
              session: examSession,
              correctionStyle: _correctionStyle,
            ),
          ),
        );
        return;
      }
    }

    final isStudent = context.read<AuthBloc>().state.user?.isStudent == true;
    context.read<RevisionBloc>().add(StartCustomSessionEvent(session, resume: false, filterForStudent: isStudent));
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const QcmStudyScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authUser = context.read<AuthBloc>().state.user;
    final isStudent = authUser?.isStudent == true;
    final studentYear = authUser?.studyYear ?? 1;

    final filteredModules = widget.allModules.where((m) {
      if (isStudent && _moduleFilter.isEmpty) {
        return ResidencyRepository.getYearForModule(m) == studentYear;
      }
      if (_moduleFilter.isEmpty) return true;
      return m.name.toLowerCase().contains(_moduleFilter.toLowerCase());
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.dashboard_customize_rounded, color: AppTheme.primaryTeal, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Créer une Session Sur-Mesure',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                      ),
                      Text(
                        'Combinez plusieurs modules et cours pour réviser',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
          const Divider(height: 20),

          // Scrollable Settings & Selector
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                // 1. Session Title
                const Text('1. Nom de la session', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.edit_note_rounded),
                    hintText: 'Ex: Cardio + Urgences concours blanc',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
                const SizedBox(height: 20),

                // 2. Question Limit & Options
                const Text('2. Volume & Ordre des Questions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [10, 20, 30, 50, -1].map((lim) {
                    final label = lim == -1 ? 'Toutes' : '$lim QCMs';
                    final isSel = _questionLimit == lim;
                    return ChoiceChip(
                      label: Text(label),
                      selected: isSel,
                      selectedColor: AppTheme.primaryTeal.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        color: isSel ? AppTheme.primaryTeal : null,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (_) => setState(() => _questionLimit = lim),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Mélanger les questions (Aléatoire)', style: TextStyle(fontSize: 13)),
                  subtitle: const Text('Simule les conditions du concours national', style: TextStyle(fontSize: 11)),
                  value: _shuffle,
                  activeThumbColor: AppTheme.primaryTeal,
                  onChanged: (v) => setState(() => _shuffle = v),
                ),
                const SizedBox(height: 14),

                // 2.5 Mode Examen, Style de Correction & Filtres Intelligents (Medsina Ultra)
                const Text(
                  '3. Mode d\'Entraînement & Filtres Intelligents',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ChoiceChip(
                      label: const Text('📖 Mode Révision (Corrigé immédiat)'),
                      selected: _sessionMode == 'revision',
                      selectedColor: AppTheme.primaryTeal.withValues(alpha: 0.16),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: _sessionMode == 'revision' ? FontWeight.bold : FontWeight.normal,
                        color: _sessionMode == 'revision' ? AppTheme.primaryTeal : null,
                      ),
                      onSelected: (_) => setState(() => _sessionMode = 'revision'),
                    ),
                    ChoiceChip(
                      label: const Text('⏱️ Mode Examen Blanc Chronométré'),
                      selected: _sessionMode == 'exam',
                      selectedColor: const Color(0xFFEA580C).withValues(alpha: 0.16),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: _sessionMode == 'exam' ? FontWeight.bold : FontWeight.normal,
                        color: _sessionMode == 'exam' ? const Color(0xFFEA580C) : null,
                      ),
                      onSelected: (_) => setState(() => _sessionMode = 'exam'),
                    ),
                  ],
                ),
                if (_sessionMode == 'exam') ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Durée chrono :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ...[15, 30, 45, 60, 120].map((mins) {
                        final isSel = _durationMinutes == mins;
                        return ChoiceChip(
                          label: Text('$mins min', style: const TextStyle(fontSize: 11.5)),
                          selected: isSel,
                          visualDensity: VisualDensity.compact,
                          onSelected: (_) => setState(() => _durationMinutes = mins),
                        );
                      }),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ChoiceChip(
                      label: const Text('⚖️ Tout ou Rien (Standard Concours)'),
                      selected: _correctionStyle == 'allOrNothing',
                      visualDensity: VisualDensity.compact,
                      selectedColor: AppTheme.primaryTeal.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        fontSize: 11.5,
                        fontWeight: _correctionStyle == 'allOrNothing' ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (_) => setState(() => _correctionStyle = 'allOrNothing'),
                    ),
                    ChoiceChip(
                      label: const Text('📊 Notation Partielle Pondérée'),
                      selected: _correctionStyle == 'partial',
                      visualDensity: VisualDensity.compact,
                      selectedColor: AppTheme.primaryTeal.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        fontSize: 11.5,
                        fontWeight: _correctionStyle == 'partial' ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (_) => setState(() => _correctionStyle = 'partial'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Ciblage selon votre historique personnel :',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ('all', 'Toutes les questions'),
                    ('unseen', '🆕 Jamais consultées'),
                    ('wrong', '❌ Mes Erreurs à retravailler'),
                    ('marked', '⭐ Mes Favoris marqués'),
                    ('withNotes', '📝 Avec mes Notes'),
                    ('highYield', '🔥 Haute Tombabilité & Pièges'),
                  ].map((entry) {
                    final isSel = _historyFilter == entry.$1;
                    return ChoiceChip(
                      label: Text(entry.$2),
                      selected: isSel,
                      visualDensity: VisualDensity.compact,
                      selectedColor: AppTheme.primaryTeal.withValues(alpha: 0.18),
                      labelStyle: TextStyle(
                        fontSize: 11.5,
                        color: isSel ? AppTheme.primaryTeal : null,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (_) => setState(() => _historyFilter = entry.$1),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Types :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ...[
                      ('qcs', 'QCS (Choix Unique)'),
                      ('qcm', 'QCM (Choix Multiple)'),
                      ('casClinique', 'Cas Cliniques'),
                    ].map((t) {
                      final isSel = _allowedTypes.contains(t.$1);
                      return FilterChip(
                        label: Text(t.$2, style: const TextStyle(fontSize: 11.5)),
                        selected: isSel,
                        visualDensity: VisualDensity.compact,
                        selectedColor: AppTheme.primaryTeal.withValues(alpha: 0.16),
                        onSelected: (val) {
                          setState(() {
                            if (val) {
                              _allowedTypes.add(t.$1);
                            } else if (_allowedTypes.length > 1) {
                              _allowedTypes.remove(t.$1);
                            }
                          });
                        },
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 18),

                // 4. Selection of Modules and Courses
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('4. Modules & Cours ciblés', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    Text(
                      '${_selectedCourseIds.length} cours choisis',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryTeal),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    hintText: 'Filtrer les modules (ex: Cardiologie, Pneumo)...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _moduleFilter = v),
                ),
                const SizedBox(height: 10),

                // Modules Accordion
                ...filteredModules.map((mod) {
                  final isModSelected = _selectedModuleIds.contains(mod.id);
                  final modCourses = mod.courses;
                  final selectedInMod = modCourses.where((c) => _selectedCourseIds.contains(c.id)).length;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isModSelected ? AppTheme.primaryTeal.withValues(alpha: 0.04) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isModSelected ? AppTheme.primaryTeal.withValues(alpha: 0.3) : Colors.grey.shade200,
                      ),
                    ),
                    child: ExpansionTile(
                      key: PageStorageKey(mod.id),
                      leading: Checkbox(
                        value: isModSelected,
                        activeColor: AppTheme.primaryTeal,
                        onChanged: (val) => _toggleModule(mod, val == true),
                      ),
                      title: Text(
                        mod.name,
                        style: TextStyle(
                          fontWeight: isModSelected ? FontWeight.bold : FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        '$selectedInMod / ${modCourses.length} cours sélectionnés',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      children: [
                        Container(
                          color: Theme.of(context).cardColor,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: Column(
                            children: modCourses.map((c) {
                              final isCourseSel = _selectedCourseIds.contains(c.id);
                              return CheckboxListTile(
                                dense: true,
                                controlAffinity: ListTileControlAffinity.leading,
                                activeColor: AppTheme.primaryTeal,
                                contentPadding: EdgeInsets.zero,
                                title: Text(c.name, style: const TextStyle(fontSize: 12.5)),
                                subtitle: Text('${c.questionsCount} questions', style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500)),
                                value: isCourseSel,
                                onChanged: (val) {
                                  _toggleCourse(c.id, val == true);
                                  // Update module state if any course is selected
                                  if (val == true && !isModSelected) {
                                    setState(() => _selectedModuleIds.add(mod.id));
                                  }
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: theme.cardColor,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2)),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedCourseIds.isNotEmpty ? AppTheme.primaryTeal : Colors.grey.shade400,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 22),
                  label: Text(
                    'Démarrer la session (${_selectedCourseIds.length} cours • ${_questionLimit == -1 ? "Tous" : _questionLimit} QCMs)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                  onPressed: _selectedCourseIds.isNotEmpty ? _startSession : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
