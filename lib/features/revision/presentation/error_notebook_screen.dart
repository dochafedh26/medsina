import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/medsina_colors.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../bloc/revision_bloc.dart';
import '../bloc/revision_event.dart';
import '../models/module_model.dart';
import '../services/error_notebook_service.dart';
import 'qcm_study_screen.dart';

class ErrorNotebookScreen extends StatefulWidget {
  const ErrorNotebookScreen({super.key});

  @override
  State<ErrorNotebookScreen> createState() => _ErrorNotebookScreenState();
}

class _ErrorNotebookScreenState extends State<ErrorNotebookScreen> {
  List<ErrorCourseGroup> _groups = [];
  bool _loading = true;
  bool _converting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final groups = await ErrorNotebookService.instance.loadGroupedErrors();
    if (!mounted) return;
    setState(() {
      _groups = groups;
      _loading = false;
    });
  }

  Future<void> _convertGroupToFlashcards(ErrorCourseGroup group) async {
    setState(() => _converting = true);
    final questions =
        await ErrorNotebookService.instance.resolveQuestionsForGroup(group);
    final added = await ErrorNotebookService.instance
        .convertQuestionsToFsrsFlashcards(questions);
    await HapticFeedbackHelper.onMilestone();
    if (!mounted) return;
    setState(() => _converting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added > 0
              ? '$added flashcard(s) FSRS v4.5 créées pour "${group.courseName}".'
              : 'Toutes les erreurs de ce cours sont déjà dans vos flashcards FSRS.',
        ),
      ),
    );
  }

  void _launchTargetedPractice(ErrorCourseGroup group) {
    final course = CourseModel(
      id: group.courseId,
      moduleId: group.moduleId,
      name: group.courseName,
      questionsCount: group.errorCount,
      hasPdf: false,
    );
    context.read<RevisionBloc>().add(OpenCourseQuestionsEvent(course));
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const QcmStudyScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    final totalErrors = _groups.fold<int>(0, (s, g) => s + g.errorCount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carnet d\'Erreurs Intelligent'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const SkeletonCardList(itemCount: 4, itemHeight: 110)
          : _groups.isEmpty
              ? EmptyStateView(
                  icon: Icons.verified_rounded,
                  title: 'Aucune erreur enregistrée',
                  subtitle:
                      'Vos QCMs manqués apparaîtront automatiquement ici, regroupés par cours pour une révision ciblée.',
                  accentColor: mc.success,
                )
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: mc.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: mc.error.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded, color: mc.error),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '$totalErrors QCM(s) à consolider répartis sur ${_groups.length} cours.',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: mc.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _groups.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final g = _groups[index];
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: mc.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: mc.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        g.courseName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: mc.textPrimary,
                                            ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: mc.error.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '${g.errorCount} erreur(s)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: mc.error,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _converting
                                            ? null
                                            : () =>
                                                _convertGroupToFlashcards(g),
                                        icon: const Icon(
                                          Icons.style_rounded,
                                          size: 18,
                                        ),
                                        label: const Text('→ Flashcards FSRS'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () =>
                                            _launchTargetedPractice(g),
                                        icon: const Icon(
                                          Icons.play_arrow_rounded,
                                          size: 18,
                                        ),
                                        label: const Text('Réviser'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
