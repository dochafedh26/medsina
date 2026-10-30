import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../revision/models/module_model.dart';
import '../../revision/models/qcm_model.dart';
import '../data/models/externat_module_info.dart';
import '../data/models/externat_pedagogical_models.dart';
import '../services/externat_pedagogy_service.dart';

class ExternatEmdSimulationScreen extends StatefulWidget {
  final String moduleName;
  final int studyYear;
  final List<MedicalModuleModel> allModules;
  final int? questionCount;
  final int? durationMinutes;

  const ExternatEmdSimulationScreen({
    super.key,
    required this.moduleName,
    required this.studyYear,
    required this.allModules,
    this.questionCount,
    this.durationMinutes,
  });

  @override
  State<ExternatEmdSimulationScreen> createState() => _ExternatEmdSimulationScreenState();
}

class _ExternatEmdSimulationScreenState extends State<ExternatEmdSimulationScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  List<QcmQuestion> _questions = [];
  int _currentQuestionIndex = 0;

  // Question index -> Set of selected keys ('A', 'B', etc.)
  final Map<int, Set<String>> _userAnswers = {};

  // Flagged questions for review
  final Set<int> _flaggedQuestions = {};

  // Exam timer
  Timer? _timer;
  late int _remainingSeconds;
  late int _totalDurationSeconds;
  bool _isSubmitted = false;
  EmdSimulationResult? _result;

  @override
  void initState() {
    super.initState();
    final moduleInfo = ExternatCurriculumMatrix.findModuleInfo(widget.moduleName, widget.studyYear);
    final count = widget.questionCount ?? moduleInfo?.defaultEmdQuestions ?? 20;
    final minutes = widget.durationMinutes ?? moduleInfo?.emdDurationMinutes ?? 30;

    _totalDurationSeconds = minutes * 60;
    _remainingSeconds = _totalDurationSeconds;

    _loadExamQuestions(count);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadExamQuestions(int count) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final qs = await ExternatPedagogyService.buildEmdExamQuestions(
        moduleName: widget.moduleName,
        year: widget.studyYear,
        allModules: widget.allModules,
        questionCount: count,
      );

      if (mounted) {
        setState(() {
          _questions = qs;
          _isLoading = false;
        });
        _startTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erreur de chargement de l\'examen EMD : $e';
        });
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 1) {
        timer.cancel();
        _submitExam(autoSubmit: true);
      } else {
        setState(() {
          _remainingSeconds--;
        });
      }
    });
  }

  String _formatTimer(int seconds) {
    final m = (seconds / 60).floor().toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _toggleOption(int questionIndex, String optionKey, bool isMultipleChoice) {
    if (_isSubmitted) return;
    setState(() {
      final current = _userAnswers[questionIndex] ?? <String>{};
      if (isMultipleChoice) {
        if (current.contains(optionKey)) {
          current.remove(optionKey);
        } else {
          current.add(optionKey);
        }
      } else {
        current.clear();
        current.add(optionKey);
      }
      _userAnswers[questionIndex] = current;
    });
  }

  void _submitExam({bool autoSubmit = false}) async {
    _timer?.cancel();

    int correct = 0;
    final Map<String, int> performanceByTopic = {};

    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      final userSelected = _userAnswers[i] ?? <String>{};
      final correctSet = q.correctAnswers.toSet();

      // Check if user set matches correct set exactly
      final isCorrect = userSelected.isNotEmpty &&
          userSelected.length == correctSet.length &&
          userSelected.every((e) => correctSet.contains(e));

      if (isCorrect) {
        correct++;
        performanceByTopic[q.courseName] = (performanceByTopic[q.courseName] ?? 0) + 1;
      }
    }

    final total = _questions.isEmpty ? 1 : _questions.length;
    final scoreOn20 = (correct / total) * 20.0;
    final isPassed = scoreOn20 >= 10.0;

    final result = EmdSimulationResult(
      examId: 'emd_${DateTime.now().millisecondsSinceEpoch}',
      moduleName: widget.moduleName,
      studyYear: widget.studyYear,
      totalQuestions: _questions.length,
      correctAnswers: correct,
      scoreOn20: double.parse(scoreOn20.toStringAsFixed(2)),
      isPassed: isPassed,
      durationSeconds: _totalDurationSeconds - _remainingSeconds,
      completedAt: DateTime.now(),
      performanceByTopic: performanceByTopic,
    );

    await ExternatPedagogyService.saveEmdResult(result);

    if (mounted) {
      setState(() {
        _isSubmitted = true;
        _result = result;
      });
    }
  }

  void _confirmSubmit() {
    final answered = _userAnswers.values.where((s) => s.isNotEmpty).length;
    final total = _questions.length;
    final unanswered = total - answered;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la remise de l\'EMD', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          unanswered > 0
              ? 'Attention, vous avez $unanswered question(s) sans réponse sur $total.\nVoulez-vous vraiment clore l\'épreuve et obtenir votre note sur 20 ?'
              : 'Vous avez répondu à l\'ensemble des $total questions.\nVoulez-vous valider votre épreuve officielle ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Continuer l\'épreuve'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _submitExam();
            },
            child: const Text('Valider & Corriger (/20)'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: _isSubmitted,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _isSubmitted) return;
        _showExitConfirmation();
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EMD Blanc • ${widget.moduleName}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Text(
                '${widget.studyYear}e Année • Barème /20 officiel',
                style: const TextStyle(fontSize: 11, color: AppTheme.primaryTeal, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          actions: [
            if (!_isSubmitted && !_isLoading) ...[
              // Timer Display
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _remainingSeconds < 300
                      ? Colors.red.withValues(alpha: 0.15)
                      : AppTheme.primaryTeal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _remainingSeconds < 300 ? Colors.red : AppTheme.primaryTeal,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.timer_rounded,
                      size: 16,
                      color: _remainingSeconds < 300 ? Colors.red : AppTheme.primaryTeal,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatTimer(_remainingSeconds),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _remainingSeconds < 300 ? Colors.red : AppTheme.primaryTeal,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.grid_view_rounded),
                tooltip: 'Palette des questions',
                onPressed: _showQuestionPalette,
              ),
            ],
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal))
            : _errorMessage != null
                ? _buildErrorView()
                : _isSubmitted
                    ? _buildResultReportView(isDark)
                    : _buildExamQuestionView(isDark),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage ?? 'Erreur inconnue', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadExamQuestions(widget.questionCount ?? 20),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  // --- ACTIVE EXAM QUESTION VIEW ---
  Widget _buildExamQuestionView(bool isDark) {
    if (_questions.isEmpty) {
      return const Center(child: Text('Aucune question disponible.'));
    }

    final q = _questions[_currentQuestionIndex];
    final isMultipleChoice = q.correctAnswers.length > 1;
    final selectedOptions = _userAnswers[_currentQuestionIndex] ?? <String>{};
    final isFlagged = _flaggedQuestions.contains(_currentQuestionIndex);

    return Column(
      children: [
        // Top status bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          child: Row(
            children: [
              Text(
                'Question ${_currentQuestionIndex + 1} / ${_questions.length}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isMultipleChoice
                      ? const Color(0xFF0284C7).withValues(alpha: 0.15)
                      : const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isMultipleChoice ? 'QCM (Choix multiple)' : 'QCS (Choix simple)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isMultipleChoice ? const Color(0xFF0284C7) : const Color(0xFF10B981),
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  isFlagged ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  color: isFlagged ? const Color(0xFFF59E0B) : Colors.grey,
                  size: 22,
                ),
                tooltip: 'Marquer pour relecture',
                onPressed: () {
                  setState(() {
                    if (isFlagged) {
                      _flaggedQuestions.remove(_currentQuestionIndex);
                    } else {
                      _flaggedQuestions.add(_currentQuestionIndex);
                    }
                  });
                },
              ),
            ],
          ),
        ),

        // Scrollable Question Body
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (q.clinicalCaseText != null && q.clinicalCaseText!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    q.clinicalCaseText!,
                    style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                ),
              ],

              // Question Statement
              Text(
                q.questionText,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.4),
              ),

              const SizedBox(height: 18),

              // Options A to E
              ...q.options.map((opt) {
                final isSelected = selectedOptions.contains(opt.key);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _toggleOption(_currentQuestionIndex, opt.key, isMultipleChoice),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryTeal.withValues(alpha: 0.12)
                            : (isDark ? const Color(0xFF1E293B) : Colors.white),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppTheme.primaryTeal : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: isMultipleChoice ? BoxShape.rectangle : BoxShape.circle,
                              borderRadius: isMultipleChoice ? BorderRadius.circular(6) : null,
                              color: isSelected ? AppTheme.primaryTeal : (isDark ? Colors.white10 : Colors.grey.shade100),
                            ),
                            child: Text(
                              opt.key,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              opt.text,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),

        // Bottom Navigation Bar
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, -3)),
            ],
          ),
          child: Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: const Text('Précédent'),
                onPressed: _currentQuestionIndex > 0
                    ? () => setState(() => _currentQuestionIndex--)
                    : null,
              ),
              const Spacer(),
              if (_currentQuestionIndex < _questions.length - 1)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryTeal,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('Suivant'),
                  onPressed: () => setState(() => _currentQuestionIndex++),
                )
              else
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  ),
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  label: const Text('Terminer l\'EMD'),
                  onPressed: _confirmSubmit,
                ),
            ],
          ),
        ),
      ],
    );
  }

  // --- PALETTE DRAWER FOR QUICK JUMP ---
  void _showQuestionPalette() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Palette des Questions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _confirmSubmit();
                    },
                    child: const Text('Valider l\'EMD'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: _questions.length,
                  itemBuilder: (_, index) {
                    final hasAnswer = _userAnswers[index]?.isNotEmpty == true;
                    final isCurrent = index == _currentQuestionIndex;
                    final isFlagged = _flaggedQuestions.contains(index);

                    Color bg = Colors.transparent;
                    if (isCurrent) {
                      bg = AppTheme.primaryTeal;
                    } else if (hasAnswer) {
                      bg = const Color(0xFF10B981).withValues(alpha: 0.2);
                    }

                    return InkWell(
                      onTap: () {
                        setState(() => _currentQuestionIndex = index);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isCurrent
                                ? AppTheme.primaryTeal
                                : (hasAnswer ? const Color(0xFF10B981) : Colors.grey.shade400),
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isCurrent ? Colors.white : null,
                              ),
                            ),
                            if (isFlagged)
                              const Positioned(
                                top: 2,
                                right: 2,
                                child: Icon(Icons.bookmark_rounded, size: 10, color: Color(0xFFF59E0B)),
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
        );
      },
    );
  }

  // --- RESULT REPORT VIEW ---
  Widget _buildResultReportView(bool isDark) {
    final res = _result!;
    final isPassed = res.isPassed;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Score Summary Card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isPassed ? const Color(0xFF10B981) : Colors.red,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: (isPassed ? const Color(0xFF10B981) : Colors.red).withValues(alpha: 0.1),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(
                isPassed ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded,
                size: 56,
                color: isPassed ? const Color(0xFF10B981) : Colors.red,
              ),
              const SizedBox(height: 12),
              Text(
                isPassed ? 'EMD VALIDÉ ! 🏆' : 'EMD NON VALIDÉ',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: isPassed ? const Color(0xFF10B981) : Colors.red,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Note officielle obtenue sur le barème faculté :',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              Text(
                '${res.scoreOn20} / 20',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: isPassed ? const Color(0xFF10B981) : Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${res.correctAnswers} bonnes réponses sur ${res.totalQuestions} questions (${((res.correctAnswers / res.totalQuestions) * 100).toStringAsFixed(1)}%)',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Refaire une Simulation'),
                onPressed: () {
                  setState(() {
                    _isSubmitted = false;
                    _userAnswers.clear();
                    _flaggedQuestions.clear();
                    _currentQuestionIndex = 0;
                    _remainingSeconds = _totalDurationSeconds;
                  });
                  _loadExamQuestions(widget.questionCount ?? 20);
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Correction Review Header
        const Text(
          'Revue Détaillée & Justifications d\'Examen',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),

        ...List.generate(_questions.length, (i) {
          final q = _questions[i];
          final userSelected = _userAnswers[i] ?? <String>{};
          final correctSet = q.correctAnswers.toSet();
          final isQCorrect = userSelected.isNotEmpty &&
              userSelected.length == correctSet.length &&
              userSelected.every((e) => correctSet.contains(e));

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isQCorrect ? const Color(0xFF10B981).withValues(alpha: 0.4) : Colors.red.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isQCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      color: isQCorrect ? const Color(0xFF10B981) : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Question ${i + 1} (${q.courseName})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(q.questionText, style: const TextStyle(fontSize: 13.5)),
                const SizedBox(height: 10),
                Text(
                  'Vos réponses : ${userSelected.isEmpty ? "Aucune" : userSelected.join(", ")}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isQCorrect ? const Color(0xFF10B981) : Colors.red,
                  ),
                ),
                Text(
                  'Bonne(s) réponse(s) : ${q.correctAnswers.join(", ")}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF10B981),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    q.explanation,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? Colors.white70 : const Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitter l\'épreuve en cours ?'),
        content: const Text('Votre progression sera perdue et l\'examen ne sera pas noté.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Abandonner l\'EMD'),
          ),
        ],
      ),
    );
  }
}
