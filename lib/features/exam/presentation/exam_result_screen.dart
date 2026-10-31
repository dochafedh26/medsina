import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../core/network/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../revision/models/flashcard_fsrs_model.dart';
import '../models/exam_session_model.dart';

class ExamResultScreen extends StatefulWidget {
  final ExamSessionModel session;
  final String correctionStyle;

  const ExamResultScreen({
    super.key,
    required this.session,
    this.correctionStyle = 'allOrNothing',
  });

  @override
  State<ExamResultScreen> createState() => _ExamResultScreenState();
}

class _ExamResultScreenState extends State<ExamResultScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<ExamQuestionResult> _allResults;
  late List<ExamQuestionResult> _falseResults;
  late double _accuracyPercentage;
  late double _scoreOutOf20;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _allResults = widget.session.evaluateResults(correctionStyle: widget.correctionStyle);
    _falseResults = widget.session.getFalseAndMissedQuestions(correctionStyle: widget.correctionStyle);
    _accuracyPercentage = widget.session.calculateAccuracyPercentage(correctionStyle: widget.correctionStyle);
    _scoreOutOf20 = widget.session.calculateScoreOutOf20(correctionStyle: widget.correctionStyle);
    _syncToCloud();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _syncToCloud() async {
    final user = context.read<AuthBloc>().state.user;
    if (user == null) return;

    try {
      final client = SupabaseService.client;
      final correctCount = _allResults.where((r) => r.isCorrect).length;

      await client.from('user_exam_records').insert({
        'user_id': user.id,
        'title': widget.session.title,
        'total_questions': widget.session.totalQuestions,
        'correct_count': correctCount,
        'score_out_of_20': _scoreOutOf20,
        'time_spent_seconds': widget.session.totalTimeSpentSeconds,
        'duration_minutes': widget.session.durationMinutes,
        'average_seconds_per_question': widget.session.averageSecondsPerQuestion,
      });
    } catch (e) {
      debugPrint('Sync user_exam_records error: $e');
    }
  }

  String _formatTime(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    if (m > 0) {
      return '${m}m ${s.toString().padLeft(2, '0')}s';
    }
    return '${s}s';
  }

  Color _getScoreColor(double score) {
    if (score >= 14.0) return Colors.green.shade700;
    if (score >= 10.0) return Colors.amber.shade800;
    return Colors.red.shade700;
  }

  Future<void> _createFlashcardFromQuestion(ExamQuestionResult res) async {
    await FlashcardFsrsService.instance.createFromQuestion(res.question);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Flashcard FSRS créée avec succès pour la révision espacée !'),
          backgroundColor: AppTheme.primaryTeal,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scoreColor = _getScoreColor(_scoreOutOf20);
    final correctCount = _allResults.where((r) => r.isCorrect).length;
    final totalQuestions = widget.session.totalQuestions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bilan de l\'Examen', style: TextStyle(fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Carte Principale de Score & Rapidité
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.session.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Épreuve terminée • Barème officiel',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    // Note / 20
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: scoreColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${_scoreOutOf20.toStringAsFixed(1)} / 20',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: scoreColor),
                          ),
                          Text(
                            '${_accuracyPercentage.toStringAsFixed(1)}% justes',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scoreColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Ligne de statistiques de performance & chrono
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: IntrinsicHeight(
                      child: Row(
                        children: [
                          _buildStatItem(
                            icon: Icons.check_circle_outline,
                            color: Colors.green,
                            label: 'Bonnes réponses',
                            value: '$correctCount / $totalQuestions',
                          ),
                          _buildDivider(),
                          _buildStatItem(
                            icon: Icons.cancel_outlined,
                            color: Colors.red,
                            label: 'Erreurs / Omissions',
                            value: '${_falseResults.length} QCMs',
                          ),
                          _buildDivider(),
                          _buildStatItem(
                            icon: Icons.timer_outlined,
                            color: AppTheme.primaryTeal,
                            label: 'Temps total',
                            value: _formatTime(widget.session.totalTimeSpentSeconds),
                          ),
                          _buildDivider(),
                          _buildStatItem(
                            icon: Icons.speed_rounded,
                            color: Colors.orange.shade800,
                            label: 'Moyenne / QCM',
                            value: '${widget.session.averageSecondsPerQuestion.toStringAsFixed(0)}s',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Onglets
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppTheme.primaryTeal,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppTheme.primaryTeal,
            tabs: [
              Tab(
                icon: const Icon(Icons.assignment_late_rounded, size: 18),
                text: 'Fiche Synthèse Erreurs (${_falseResults.length})',
              ),
              Tab(
                icon: const Icon(Icons.list_alt_rounded, size: 18),
                text: 'Revue Complète ($totalQuestions)',
              ),
            ],
          ),

          // Contenu
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. FICHE DE SYNTHÈSE DES ERREURS & RÉPONSES FAUSSES
                _falseResults.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.emoji_events_rounded, size: 64, color: Colors.amber),
                              const SizedBox(height: 12),
                              const Text(
                                'Félicitations ! Un score sans faute !',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Vous avez répondu correctement à 100% des questions de cette épreuve.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _falseResults.length + 1,
                        itemBuilder: (ctx, idx) {
                          if (idx == 0) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.lightbulb_outline, color: Colors.red, size: 22),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Voici la fiche de synthèse de vos ${_falseResults.length} erreurs. Comparez vos choix avec la réponse juste et étudiez la justification médicale.',
                                      style: TextStyle(fontSize: 12, color: Colors.red.shade900),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          final res = _falseResults[idx - 1];
                          return _buildQuestionCorrectionCard(res, idx);
                        },
                      ),

                // 2. REVUE COMPLÈTE DE TOUTES LES QUESTIONS
                ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _allResults.length,
                  itemBuilder: (ctx, idx) {
                    final res = _allResults[idx];
                    return _buildQuestionCorrectionCard(res, idx + 1);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        Text(label, style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 28, color: Colors.grey.shade300);
  }

  Widget _buildQuestionCorrectionCard(ExamQuestionResult res, int displayNumber) {
    final theme = Theme.of(context);
    final q = res.question;
    final isCorrect = res.isCorrect;
    final isUnanswered = res.isUnanswered;

    Color badgeColor = Colors.red;
    String badgeText = 'Erreur';
    IconData badgeIcon = Icons.cancel;

    if (isCorrect) {
      badgeColor = Colors.green;
      badgeText = 'Bonne réponse';
      badgeIcon = Icons.check_circle;
    } else if (isUnanswered) {
      badgeColor = Colors.grey.shade600;
      badgeText = 'Non répondue';
      badgeIcon = Icons.help_outline;
    } else if (res.isPartiallyCorrect) {
      badgeColor = Colors.orange;
      badgeText = 'Partielle';
      badgeIcon = Icons.remove_circle_outline;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: badgeColor.withValues(alpha: 0.3), width: 1.2),
      ),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête de la question
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon, size: 14, color: badgeColor),
                      const SizedBox(width: 4),
                      Text(
                        badgeText,
                        style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Q$displayNumber • ${q.courseName}',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.bookmark_add_outlined, size: 20),
                  tooltip: 'Créer une Flashcard FSRS',
                  onPressed: () => _createFlashcardFromQuestion(res),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Énoncé de la question
            Text(
              q.questionText,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, height: 1.35),
            ),
            const SizedBox(height: 12),

            // Liste des options avec comparaison (Votre choix vs Bonne réponse)
            ...q.options.map((opt) {
              final optKey = opt.key.toUpperCase();
              final wasChosenByUser = res.userSelectedKeys.contains(optKey);
              final isOfficialCorrect = res.correctKeys.contains(optKey);

              Color optBg = Colors.transparent;
              Color optBorder = Colors.grey.shade200;
              Widget? indicator;

              if (isOfficialCorrect) {
                optBg = Colors.green.withValues(alpha: 0.1);
                optBorder = Colors.green.shade400;
                indicator = const Icon(Icons.check_circle, color: Colors.green, size: 18);
              } else if (wasChosenByUser && !isOfficialCorrect) {
                optBg = Colors.red.withValues(alpha: 0.1);
                optBorder = Colors.red.shade400;
                indicator = const Icon(Icons.cancel, color: Colors.red, size: 18);
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: optBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: optBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: wasChosenByUser
                            ? (isOfficialCorrect ? Colors.green : Colors.red)
                            : Colors.grey.shade300,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        optKey,
                        style: TextStyle(
                          color: wasChosenByUser ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        opt.text,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isOfficialCorrect ? FontWeight.bold : FontWeight.normal,
                          color: isOfficialCorrect
                              ? Colors.green.shade900
                              : (wasChosenByUser ? Colors.red.shade900 : Colors.black87),
                        ),
                      ),
                    ),
                    ?indicator,
                  ],
                ),
              );
            }),

            // Boîte d'explication médicale & justification
            if (q.explanation.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primaryTeal.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.menu_book_rounded, color: AppTheme.primaryTeal, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Justification Médicale Officielle :',
                          style: TextStyle(color: AppTheme.primaryTeal, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    MarkdownBody(
                      data: q.explanation,
                      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                        p: TextStyle(fontSize: 12, color: Colors.grey.shade800, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
