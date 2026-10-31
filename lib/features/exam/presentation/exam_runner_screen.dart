import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../revision/models/qcm_model.dart';
import '../models/exam_session_model.dart';
import 'exam_result_screen.dart';

class ExamRunnerScreen extends StatefulWidget {
  final ExamSessionModel session;
  final String correctionStyle;

  const ExamRunnerScreen({
    super.key,
    required this.session,
    this.correctionStyle = 'allOrNothing',
  });

  @override
  State<ExamRunnerScreen> createState() => _ExamRunnerScreenState();
}

class _ExamRunnerScreenState extends State<ExamRunnerScreen> {
  late ExamSessionModel _session;
  int _currentIndex = 0;
  late int _remainingSeconds;
  Timer? _countdownTimer;
  DateTime _questionEnterTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _remainingSeconds = widget.session.durationMinutes * 60;
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        timer.cancel();
        _autoSubmitOnTimeUp();
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  void _recordCurrentQuestionTime() {
    final now = DateTime.now();
    final spent = now.difference(_questionEnterTime).inSeconds;
    final currentQ = _session.questions[_currentIndex];

    final updatedTimes = Map<String, int>.from(_session.timePerQuestionSeconds);
    updatedTimes[currentQ.id] = (updatedTimes[currentQ.id] ?? 0) + spent;
    _session = _session.copyWith(timePerQuestionSeconds: updatedTimes);
    _questionEnterTime = now;
  }

  void _goToQuestion(int index) {
    if (index < 0 || index >= _session.totalQuestions) return;
    _recordCurrentQuestionTime();
    setState(() => _currentIndex = index);
  }

  void _toggleOption(String optKey) {
    final currentQ = _session.questions[_currentIndex];
    final keyUpper = optKey.toUpperCase();
    final currentAnswers = Set<String>.from(_session.userAnswers[currentQ.id] ?? {});

    if (currentQ.type == QuestionType.qcs) {
      // Choix simple : remplace
      currentAnswers.clear();
      currentAnswers.add(keyUpper);
    } else {
      // Choix multiple : bascule
      if (currentAnswers.contains(keyUpper)) {
        currentAnswers.remove(keyUpper);
      } else {
        currentAnswers.add(keyUpper);
      }
    }

    final updatedAnswers = Map<String, Set<String>>.from(_session.userAnswers);
    updatedAnswers[currentQ.id] = currentAnswers;
    setState(() {
      _session = _session.copyWith(userAnswers: updatedAnswers);
    });
  }

  void _toggleFlagCurrent() {
    final currentQ = _session.questions[_currentIndex];
    final flags = Set<String>.from(_session.flaggedQuestionIds);
    if (flags.contains(currentQ.id)) {
      flags.remove(currentQ.id);
    } else {
      flags.add(currentQ.id);
    }
    setState(() {
      _session = _session.copyWith(flaggedQuestionIds: flags);
    });
  }

  void _autoSubmitOnTimeUp() {
    _recordCurrentQuestionTime();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('⏱️ Temps écoulé ! Soumission automatique de votre épreuve.'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
    _submitExam();
  }

  void _showSubmitConfirmationDialog() {
    _recordCurrentQuestionTime();
    final answered = _session.answeredCount;
    final unanswered = _session.unansweredCount;
    final flagged = _session.flaggedCount;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.assignment_turned_in_rounded, color: AppTheme.primaryTeal),
              SizedBox(width: 8),
              Text('Terminer l\'Épreuve ?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Récapitulatif de votre copie :'),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$answered / ${_session.totalQuestions} questions répondues',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (unanswered > 0)
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$unanswered question${unanswered > 1 ? "s" : ""} sans réponse',
                        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              if (flagged > 0) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.flag_rounded, color: Colors.amber, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$flagged question${flagged > 1 ? "s" : ""} marquée${flagged > 1 ? "s" : ""} à revoir',
                        style: const TextStyle(color: Colors.amber),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              const Text('Voulez-vous valider et calculer votre score officiel ?', style: TextStyle(fontSize: 12.5)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Continuer l\'épreuve'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryTeal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                _submitExam();
              },
              child: const Text('Soumettre ma copie'),
            ),
          ],
        );
      },
    );
  }

  void _submitExam() {
    _countdownTimer?.cancel();
    final finalized = _session.copyWith(
      submittedAt: DateTime.now(),
      isSubmitted: true,
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ExamResultScreen(
          session: finalized,
          correctionStyle: widget.correctionStyle,
        ),
      ),
    );
  }

  void _showQuestionPalette() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.70,
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Palette des Questions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('${_session.answeredCount} / ${_session.totalQuestions} répondues', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
                const SizedBox(height: 12),
                // Légende
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _buildLegendItem(AppTheme.primaryTeal, 'Répondue'),
                    _buildLegendItem(Colors.amber, 'À revoir'),
                    _buildLegendItem(Colors.grey.shade300, 'Non répondue'),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 6,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: _session.totalQuestions,
                    itemBuilder: (_, idx) {
                      final q = _session.questions[idx];
                      final isAnswered = (_session.userAnswers[q.id] ?? {}).isNotEmpty;
                      final isFlagged = _session.flaggedQuestionIds.contains(q.id);
                      final isCurrent = idx == _currentIndex;

                      Color bg = Colors.grey.shade200;
                      Color textCol = Colors.black87;
                      if (isAnswered) {
                        bg = AppTheme.primaryTeal;
                        textCol = Colors.white;
                      }

                      return InkWell(
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _goToQuestion(idx);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isCurrent ? Colors.black : (isFlagged ? Colors.amber : Colors.transparent),
                              width: isCurrent ? 2.5 : (isFlagged ? 2 : 1),
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Text(
                                '${idx + 1}',
                                style: TextStyle(fontWeight: FontWeight.bold, color: textCol, fontSize: 13),
                              ),
                              if (isFlagged)
                                const Positioned(
                                  top: 2,
                                  right: 2,
                                  child: Icon(Icons.flag_rounded, size: 10, color: Colors.amber),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  String _formatTimerString() {
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Color _getTimerColor() {
    if (_remainingSeconds > 600) return Colors.green.shade700;
    if (_remainingSeconds > 120) return Colors.orange.shade800;
    return Colors.red.shade700;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentQ = _session.questions[_currentIndex];
    final selectedKeys = _session.userAnswers[currentQ.id] ?? {};
    final isFlagged = _session.flaggedQuestionIds.contains(currentQ.id);
    final timerColor = _getTimerColor();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _showSubmitConfirmationDialog();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_session.title, style: const TextStyle(fontSize: 15)),
          actions: [
            // Chronomètre Dégressif
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: timerColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: timerColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer_outlined, size: 16, color: timerColor),
                  const SizedBox(width: 6),
                  Text(
                    _formatTimerString(),
                    style: TextStyle(color: timerColor, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.grid_view_rounded),
              tooltip: 'Palette des questions',
              onPressed: _showQuestionPalette,
            ),
            TextButton(
              onPressed: _showSubmitConfirmationDialog,
              child: const Text('Terminer', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryTeal)),
            ),
          ],
        ),
        body: Column(
          children: [
            // Barre de progression
            LinearProgressIndicator(
              value: (_currentIndex + 1) / _session.totalQuestions,
              backgroundColor: Colors.grey.shade200,
              color: AppTheme.primaryTeal,
              minHeight: 4,
            ),

            // Contenu de la question
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge Question & Statut
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryTeal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Question ${_currentIndex + 1} / ${_session.totalQuestions}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryTeal),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            currentQ.courseName,
                            textAlign: TextAlign.end,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Énoncé
                    Text(
                      currentQ.questionText,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.4),
                    ),
                    const SizedBox(height: 18),

                    // Options ou avertissement question ouverte
                    if (currentQ.options.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.edit_note_rounded, color: Colors.amber.shade900, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Question à réponse ouverte (QROC). Les propositions ne s\'appliquent pas. Veuillez poursuivre votre examen.',
                                style: TextStyle(fontSize: 12.5, color: Colors.amber.shade900, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),

                    ...currentQ.options.map((opt) {
                      final optKey = opt.key.toUpperCase();
                      final isSelected = selectedKeys.contains(optKey);

                      return InkWell(
                        onTap: () => _toggleOption(optKey),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primaryTeal.withValues(alpha: 0.1) : theme.cardColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? AppTheme.primaryTeal : Colors.grey.shade300,
                              width: isSelected ? 1.8 : 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 26,
                                height: 26,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected ? AppTheme.primaryTeal : Colors.grey.shade200,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  optKey,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: isSelected ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  opt.text,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // Barre de Navigation Inférieure
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.cardColor,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2)),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: const Text('Précédent'),
                      onPressed: _currentIndex > 0 ? () => _goToQuestion(_currentIndex - 1) : null,
                    ),
                    IconButton(
                      icon: Icon(isFlagged ? Icons.flag_rounded : Icons.flag_outlined),
                      color: isFlagged ? Colors.amber : Colors.grey,
                      tooltip: 'Marquer pour révision',
                      onPressed: _toggleFlagCurrent,
                    ),
                    _currentIndex < _session.totalQuestions - 1
                        ? ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryTeal,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            label: const Text('Suivant'),
                            icon: const Icon(Icons.arrow_forward, size: 16),
                            onPressed: () => _goToQuestion(_currentIndex + 1),
                          )
                        : ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            label: const Text('Soumettre'),
                            icon: const Icon(Icons.check, size: 16),
                            onPressed: _showSubmitConfirmationDialog,
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
