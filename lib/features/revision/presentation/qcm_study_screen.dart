import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/medical_text_formatter.dart';
import '../../ai_assistant/presentation/qcm_tutor_sheet.dart';
import '../bloc/revision_bloc.dart';
import '../bloc/revision_event.dart';
import '../bloc/revision_state.dart';
import '../models/flashcard_fsrs_model.dart';
import '../models/qcm_model.dart';
import '../services/user_qcm_annotation_service.dart';

class QcmStudyScreen extends StatelessWidget {
  const QcmStudyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RevisionBloc, RevisionState>(
      builder: (context, state) {
        if (state.status == RevisionStatus.loading) {
          return Scaffold(
            appBar: AppBar(
              title: Text(
                state.selectedCourse?.name ?? 'Révision QCM',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppTheme.primaryTeal),
                  const SizedBox(height: 16),
                  Text(
                    'Chargement des QCMs officiels pour\n"${state.selectedCourse?.name ?? 'ce cours'}"...',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          );
        }

        final q = state.activeQuestion;
        if (q == null) {
          return Scaffold(
            appBar: AppBar(
              title: Text(
                state.selectedCourse?.name ?? 'Entraînement',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.quiz_outlined, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'Aucune question officielle enregistrée pour\n"${state.selectedCourse?.name ?? 'ce cours'}"',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Les séries de questions pour ce cours sont en cours de numérisation.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryTeal,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.arrow_back_rounded, size: 16),
                      onPressed: () {
                        context.read<RevisionBloc>().add(ResetSessionEvent());
                        Navigator.of(context).pop();
                      },
                      label: const Text('Retour au catalogue'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final isRevealed = state.isCurrentAnswerRevealed;
        final selectedOptions = state.currentSelectedOptions;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            _showExitDialog(context);
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                state.sessionTitle,
                style: const TextStyle(fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryTeal.withValues(alpha: 0.12),
                    foregroundColor: AppTheme.primaryTeal,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(0, 32),
                  ),
                  icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                  label: const Text(
                    'MedsinaPilot 🩺',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                  onPressed: () => MedsinaPilotSheet.show(context, q),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.pause_circle_outline_rounded, color: AppTheme.primaryTeal),
                  tooltip: 'Mettre en pause',
                  onPressed: () {
                    context.read<RevisionBloc>().add(PauseCurrentSessionEvent());
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Session mise en pause ⏸️. Progression enregistrée.'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                    Navigator.of(context).pop();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Quitter la session',
                  onPressed: () => _showExitDialog(context),
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: Column(
              children: [
                // Progress Bar & Header
                _buildProgressHeader(context, state),
                const Divider(height: 1),

                // Question Content Scroll Area
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(18),
                    children: [
                      // Question Metadata Chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _buildTypeBadge(q.type),
                          if (state.isCustomSession)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryTeal.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                q.courseName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryTeal,
                                ),
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${q.source} (${q.year})',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (q.recurrenceCount > 1)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                '🔥 Tombée ${q.recurrenceCount}× (${q.allExamYears.join(", ")})',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ),
                          if (isRevealed)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.13),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '👥 ${q.optionStats['correctRate'] ?? 68}% de réussite étudiante',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF4F46E5),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Personal Tools Bar: Bookmark ⭐, Personal Note 📝, 1-Click FSRS Flashcard 🧠
                      _buildUltraQuestionToolsBar(context, q),

                      // Anti-trap warning banner for negative / inverse questions ("Fausse", "Sauf une")
                      if (q.isInverse) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFF59E0B)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFB45309)),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '⚠️ Vigilance Piège : Question à formulation NÉGATIVE (cherchant la proposition FAUSSE / SAUF UNE).',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),

                    // Clinical case card if available
                    if (q.clinicalCaseText != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.folder_shared_rounded, size: 16, color: Color(0xFF1D4ED8)),
                                SizedBox(width: 6),
                                Text(
                                  'Énoncé du Cas Clinique :',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF1D4ED8)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              q.clinicalCaseText!,
                              style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF1E3A8A)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Question Statement
                    Text(
                      MedicalTextFormatter.clean(q.questionText),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.4),
                    ),
                    const SizedBox(height: 20),

                    // Options list
                    ...q.options.map((opt) => _buildOptionTile(
                          context,
                          q,
                          opt,
                          selectedOptions.contains(opt.key),
                          isRevealed,
                        )),

                    const SizedBox(height: 16),

                    // Action: Valider la réponse button
                    if (!isRevealed) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            context.read<RevisionBloc>().add(RevealAnswerEvent(q.id));
                          },
                          icon: const Icon(Icons.check_circle_outline_rounded),
                          label: const Text('Valider & Voir le Corrigé Détaillé', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],

                    // Revealed: Explanation & Result Box
                    if (isRevealed) ...[
                      _buildExplanationCard(context, q, state.isCurrentAnswerFullyCorrect),
                    ],
                  ],
                ),
              ),

              // Bottom Navigation Controls
              _buildBottomControls(context, state, q),
            ],
          ),
        ),
      );
    },
  );
  }

  Widget _buildProgressHeader(BuildContext context, RevisionState state) {
    final current = state.currentQuestionIndex + 1;
    final total = state.currentQuestions.length;
    final progress = total > 0 ? current / total : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      color: Theme.of(context).cardColor,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question $current sur $total',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              Text(
                '${(progress * 100).toInt()}% complété',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.grey.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryTeal),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile(
    BuildContext context,
    QcmQuestion q,
    QcmOption opt,
    bool isSelected,
    bool isRevealed,
  ) {
    final isCorrect = q.isOptionCorrect(opt.key);
    Color borderColor = Colors.grey.shade300;
    Color bgColor = Theme.of(context).cardColor;
    Widget trailingIcon = const SizedBox();

    if (isRevealed) {
      if (isCorrect) {
        borderColor = const Color(0xFF10B981);
        bgColor = const Color(0xFF10B981).withValues(alpha: 0.12);
        trailingIcon = const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20);
      } else if (isSelected && !isCorrect) {
        borderColor = const Color(0xFFEF4444);
        bgColor = const Color(0xFFEF4444).withValues(alpha: 0.12);
        trailingIcon = const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 20);
      }
    } else {
      if (isSelected) {
        borderColor = AppTheme.primaryTeal;
        bgColor = AppTheme.primaryTeal.withValues(alpha: 0.08);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          context.read<RevisionBloc>().add(
                ToggleOptionSelectionEvent(questionId: q.id, optionKey: opt.key),
              );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: isSelected || (isRevealed && isCorrect) ? 1.8 : 1.0),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isRevealed ? (isCorrect ? const Color(0xFF10B981) : const Color(0xFFEF4444)) : AppTheme.primaryTeal)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.transparent : Colors.grey.shade400,
                  ),
                ),
                child: Text(
                  opt.key,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isSelected ? Colors.white : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  MedicalTextFormatter.clean(opt.text),
                  style: const TextStyle(fontSize: 14, height: 1.35),
                ),
              ),
              if (isRevealed) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isCorrect ? const Color(0xFF10B981) : Colors.grey).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    '${q.optionStats[opt.key] ?? 12}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isCorrect ? const Color(0xFF047857) : Colors.grey.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              trailingIcon,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUltraQuestionToolsBar(BuildContext context, QcmQuestion q) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        UserQcmAnnotationService.instance,
        FlashcardFsrsService.instance,
      ]),
      builder: (context, _) {
        final ann = UserQcmAnnotationService.instance.getAnnotation(q.id);
        final hasFlashcard = FlashcardFsrsService.instance.hasFlashcardForQuestion(q.id);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ActionChip(
                  avatar: Icon(
                    ann.isMarked ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 16,
                    color: ann.isMarked ? const Color(0xFFF59E0B) : Colors.grey.shade600,
                  ),
                  label: Text(
                    ann.isMarked ? 'Favori ⭐' : 'Marquer',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: ann.isMarked ? FontWeight.w800 : FontWeight.w600,
                      color: ann.isMarked ? const Color(0xFFB45309) : null,
                    ),
                  ),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: ann.isMarked ? const Color(0xFFFEF3C7) : null,
                  onPressed: () {
                    UserQcmAnnotationService.instance.toggleBookmark(
                      questionId: q.id,
                      moduleId: q.moduleId,
                      courseId: q.courseId,
                    );
                  },
                ),
                ActionChip(
                  avatar: Icon(
                    ann.hasNote ? Icons.sticky_note_2_rounded : Icons.note_add_outlined,
                    size: 16,
                    color: ann.hasNote ? AppTheme.primaryTeal : Colors.grey.shade600,
                  ),
                  label: Text(
                    ann.hasNote ? 'Ma Note 📝' : 'Ajouter Note',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: ann.hasNote ? FontWeight.w800 : FontWeight.w600,
                      color: ann.hasNote ? AppTheme.primaryTeal : null,
                    ),
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _showEditPersonalNoteDialog(context, q, ann.personalNote),
                ),
                ActionChip(
                  avatar: Icon(
                    hasFlashcard ? Icons.check_circle_rounded : Icons.style_rounded,
                    size: 16,
                    color: hasFlashcard ? const Color(0xFF10B981) : const Color(0xFF8B5CF6),
                  ),
                  label: Text(
                    hasFlashcard ? 'En Flashcard FSRS ✅' : 'Créer Flashcard 🧠',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: hasFlashcard ? const Color(0xFF059669) : const Color(0xFF7C3AED),
                    ),
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: () async {
                    await FlashcardFsrsService.instance.createFromQuestion(q);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Color(0xFF7C3AED),
                          content: Text('🧠 Question ajoutée à vos Flashcards FSRS (Répétition Espacée) !'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
            if (ann.hasNote) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _showEditPersonalNoteDialog(context, q, ann.personalNote),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primaryTeal.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.sticky_note_2_rounded, size: 16, color: AppTheme.primaryTeal),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ma Note : ${ann.personalNote}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Icon(Icons.edit_rounded, size: 14, color: AppTheme.primaryTeal),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  void _showEditPersonalNoteDialog(BuildContext context, QcmQuestion q, String initialNote) {
    final ctrl = TextEditingController(text: initialNote);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.sticky_note_2_rounded, color: AppTheme.primaryTeal),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Note Personnelle sur ce QCM',
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Notez votre moyen mnémotechnique, piège à retenir ou référence de cours...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryTeal,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.save_rounded, size: 16),
            label: const Text('Enregistrer'),
            onPressed: () async {
              await UserQcmAnnotationService.instance.savePersonalNote(
                questionId: q.id,
                note: ctrl.text,
                moduleId: q.moduleId,
                courseId: q.courseId,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExplanationCard(BuildContext context, QcmQuestion q, bool isFullyCorrect) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isFullyCorrect ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isFullyCorrect ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isFullyCorrect ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                color: isFullyCorrect ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isFullyCorrect ? 'Excellente réponse ! (+1 point)' : 'Réponse incorrecte ou incomplète',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: isFullyCorrect ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Bonne(s) réponse(s) : ${q.correctAnswers.join(", ")}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF0F766E)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Explication Médicale Détaillée :',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1F2937)),
          ),
          const SizedBox(height: 10),
          MarkdownBody(
            data: MedicalTextFormatter.clean(q.explanation),
            selectable: true,
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(fontSize: 13.5, height: 1.55, color: Color(0xFF374151)),
              h1: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
              h2: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
              h3: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F766E)),
              strong: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF111827)),
              listBullet: const TextStyle(color: AppTheme.primaryTeal),
              tableHead: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF111827), fontSize: 12.5),
              tableBody: const TextStyle(fontSize: 12.5, color: Color(0xFF374151)),
              tableBorder: TableBorder.all(color: Colors.grey.shade300, width: 1),
              tableColumnWidth: const FlexColumnWidth(),
              tableCellsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryTeal,
                side: const BorderSide(color: AppTheme.primaryTeal, width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text(
                'Consulter MedsinaPilot (IA Médicale) ✨',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: () => MedsinaPilotSheet.show(context, q),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(BuildContext context, RevisionState state, QcmQuestion q) {
    final hasPrev = state.currentQuestionIndex > 0;
    final hasNext = state.currentQuestionIndex < state.currentQuestions.length - 1;
    final isCompact = MediaQuery.of(context).size.width < 500;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton.icon(
              onPressed: hasPrev ? () => context.read<RevisionBloc>().add(PreviousQuestionEvent()) : null,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Précédente'),
            ),
            if (isCompact)
              IconButton.filledTonal(
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal.withValues(alpha: 0.12),
                  foregroundColor: AppTheme.primaryTeal,
                ),
                tooltip: 'MedsinaPilot IA (Tuteur Médical)',
                icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                onPressed: () => MedsinaPilotSheet.show(context, q),
              )
            else
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryTeal,
                  side: BorderSide(color: AppTheme.primaryTeal.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                label: const Text('MedsinaPilot 🩺', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                onPressed: () => MedsinaPilotSheet.show(context, q),
              ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryTeal,
                foregroundColor: Colors.white,
              ),
              onPressed: hasNext
                  ? () => context.read<RevisionBloc>().add(NextQuestionEvent())
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Félicitations ! Vous avez terminé cette session de QCMs.')),
                      );
                      context.read<RevisionBloc>().add(const ResetSessionEvent(clearSavedProgress: true));
                      Navigator.of(context).pop();
                    },
              icon: Icon(hasNext ? Icons.arrow_forward_rounded : Icons.check_circle_rounded, size: 18),
              label: Text(hasNext ? 'Suivante' : 'Terminer'),
            ),
          ],
        ),
      ),
    );
  }

  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dlgContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.pause_circle_filled_rounded, color: AppTheme.primaryTeal),
            SizedBox(width: 10),
            Text('Quitter la révision ?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Votre progression actuelle peut être mise en pause pour reprendre plus tard exactement où vous étiez.',
          style: TextStyle(fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlgContext).pop(),
            child: const Text('Continuer'),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700),
            onPressed: () {
              Navigator.of(dlgContext).pop();
              context.read<RevisionBloc>().add(const ResetSessionEvent(clearSavedProgress: true));
              Navigator.of(context).pop();
            },
            child: const Text('Recommencer à zéro plus tard'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryTeal,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.pause_rounded, size: 16),
            onPressed: () {
              Navigator.of(dlgContext).pop();
              context.read<RevisionBloc>().add(PauseCurrentSessionEvent());
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Session mise en pause ⏸️. Progression sauvegardée.'),
                  duration: Duration(seconds: 2),
                ),
              );
              Navigator.of(context).pop();
            },
            label: const Text('Mettre en pause & Quitter'),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBadge(QuestionType type) {
    String label;
    Color bg;
    Color fg;

    switch (type) {
      case QuestionType.qcs:
        label = 'QCS (Choix Unique)';
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0369A1);
        break;
      case QuestionType.qcm:
        label = 'QCM (Choix Multiple)';
        bg = const Color(0xFFCCFBF1);
        fg = const Color(0xFF0F766E);
        break;
      case QuestionType.casClinique:
        label = 'Cas Clinique';
        bg = const Color(0xFFF3E8FF);
        fg = const Color(0xFF7E22CE);
        break;
      case QuestionType.qroc:
        label = 'QROC';
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class LinearProgressProgressIndicator extends StatelessWidget {
  final double value;
  final double minHeight;
  final Color backgroundColor;
  final Animation<Color> valueColor;

  const LinearProgressProgressIndicator({
    super.key,
    required this.value,
    required this.minHeight,
    required this.backgroundColor,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: value,
      minHeight: minHeight,
      backgroundColor: backgroundColor,
      valueColor: valueColor,
    );
  }
}
