import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../bloc/revision_bloc.dart';
import '../bloc/revision_event.dart';
import '../bloc/revision_state.dart';
import '../models/qcm_model.dart';

class QcmStudyScreen extends StatelessWidget {
  const QcmStudyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RevisionBloc, RevisionState>(
      builder: (context, state) {
        final q = state.activeQuestion;
        if (q == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Entraînement')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Aucune question disponible pour cette session.'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      context.read<RevisionBloc>().add(ResetSessionEvent());
                      Navigator.of(context).pop();
                    },
                    child: const Text('Retour au catalogue'),
                  ),
                ],
              ),
            ),
          );
        }

        final isRevealed = state.isCurrentAnswerRevealed;
        final selectedOptions = state.currentSelectedOptions;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              state.selectedCourse?.name ?? 'Révision QCM',
              style: const TextStyle(fontSize: 16),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Quitter la session',
                onPressed: () {
                  context.read<RevisionBloc>().add(ResetSessionEvent());
                  Navigator.of(context).pop();
                },
              ),
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
                    Row(
                      children: [
                        _buildTypeBadge(q.type),
                        const SizedBox(width: 8),
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
                      ],
                    ),
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
                      q.questionText,
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
              _buildBottomControls(context, state),
            ],
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
                  opt.text,
                  style: const TextStyle(fontSize: 14, height: 1.35),
                ),
              ),
              trailingIcon,
            ],
          ),
        ),
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
          const SizedBox(height: 6),
          Text(
            q.explanation,
            style: const TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF374151)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(BuildContext context, RevisionState state) {
    final hasPrev = state.currentQuestionIndex > 0;
    final hasNext = state.currentQuestionIndex < state.currentQuestions.length - 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton.icon(
            onPressed: hasPrev ? () => context.read<RevisionBloc>().add(PreviousQuestionEvent()) : null,
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Précédente'),
          ),
          ElevatedButton.icon(
            onPressed: hasNext
                ? () => context.read<RevisionBloc>().add(NextQuestionEvent())
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Félicitations ! Vous avez terminé cette série de QCMs.')),
                    );
                    context.read<RevisionBloc>().add(ResetSessionEvent());
                    Navigator.of(context).pop();
                  },
            icon: Icon(hasNext ? Icons.arrow_forward_rounded : Icons.check_circle_rounded, size: 18),
            label: Text(hasNext ? 'Suivante' : 'Terminer'),
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
