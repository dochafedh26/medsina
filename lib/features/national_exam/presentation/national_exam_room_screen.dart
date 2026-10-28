import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../exam/models/exam_session_model.dart';
import '../../exam/presentation/exam_runner_screen.dart';
import '../../revision/data/residency_repository.dart';
import '../../revision/models/qcm_model.dart';
import '../models/national_exam_model.dart';
import '../services/national_exam_service.dart';

class NationalExamRoomScreen extends StatefulWidget {
  final NationalExamModel exam;

  const NationalExamRoomScreen({super.key, required this.exam});

  @override
  State<NationalExamRoomScreen> createState() => _NationalExamRoomScreenState();
}

class _NationalExamRoomScreenState extends State<NationalExamRoomScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<QcmQuestion> _questions = [];
  bool _isAnonymous = false;

  @override
  void initState() {
    super.initState();
    _prepareExam();
  }

  Future<void> _prepareExam() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = context.read<AuthBloc>().state.user;
      if (user == null) {
        throw Exception('Veuillez vous connecter pour participer à cette épreuve.');
      }

      // 1. Charger les questions de l'examen
      final allModules = await ResidencyRepository.loadModulesAsync();
      final pool = <QcmQuestion>[];

      if (widget.exam.targetModuleId != null) {
        // Module spécifique
        final mod = allModules.firstWhere(
          (m) => m.id == widget.exam.targetModuleId,
          orElse: () => allModules.first,
        );
        pool.addAll(await ResidencyRepository.getQuestionsForMultipleCoursesAsync(
          courseIds: mod.courses.map((c) => c.id).toList(),
          moduleIds: [mod.id],
          limit: widget.exam.totalQuestions,
          shuffle: true,
        ));
      } else {
        // Concours global Résidanat
        final allCourseIds = allModules.expand((m) => m.courses.map((c) => c.id)).toList();
        final allModIds = allModules.map((m) => m.id).toList();
        pool.addAll(await ResidencyRepository.getQuestionsForMultipleCoursesAsync(
          courseIds: allCourseIds,
          moduleIds: allModIds,
          limit: widget.exam.totalQuestions,
          shuffle: true,
        ));
      }

      if (pool.isEmpty) {
        throw Exception('Aucune question disponible pour cette épreuve.');
      }

      if (mounted) {
        setState(() {
          _questions = pool;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    }
  }

  void _startExamNow() async {
    final user = context.read<AuthBloc>().state.user;
    if (user == null || _questions.isEmpty) return;

    // Inscription / Enregistrement
    await NationalExamService.instance.registerForExam(
      examId: widget.exam.id,
      userId: user.id,
      isAnonymous: _isAnonymous,
    );

    final examSession = ExamSessionModel(
      id: 'nat_exam_${widget.exam.id}',
      title: widget.exam.title,
      questions: _questions,
      durationMinutes: widget.exam.durationMinutes,
      startedAt: DateTime.now(),
    );

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ExamRunnerScreen(
          session: examSession,
          correctionStyle: widget.exam.correctionStyle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exam.title, style: const TextStyle(fontSize: 15)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _prepareExam, child: const Text('Réessayer')),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Bannière Officielle
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryTeal,
                              AppTheme.primaryTeal.withValues(alpha: 0.85),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryTeal.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 26),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Concours Blanc National Officiel',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              widget.exam.title,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            if (widget.exam.description != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                widget.exam.description!,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Paramètres de l'épreuve
                      const Text('Règlement & Conditions de l\'Épreuve :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 12),
                      _buildConditionItem(Icons.quiz_outlined, '${widget.exam.totalQuestions} Questions QCMs réelles'),
                      _buildConditionItem(Icons.timer_outlined, '${widget.exam.durationMinutes} Minutes (Chronomètre dégressif strict)'),
                      _buildConditionItem(Icons.visibility_off_outlined, 'Zéro spoiler : Corrigé et explications affichés après soumission'),
                      _buildConditionItem(Icons.leaderboard_outlined, 'Classement national selon la Note et la Rapidité'),
                      _buildConditionItem(Icons.assignment_late_outlined, 'Fiche de synthèse interactive de toutes vos réponses fausses en fin d\'épreuve'),
                      const SizedBox(height: 18),

                      // Option d'anonymat
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppTheme.primaryTeal,
                        value: _isAnonymous,
                        onChanged: (v) => setState(() => _isAnonymous = v == true),
                        title: const Text('Participer de manière anonyme dans le classement public', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Votre score sera affiché comme "Candidat Anonyme" sans révéler votre nom.', style: TextStyle(fontSize: 11)),
                      ),
                      const SizedBox(height: 24),

                      // Bouton d'entrée
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryTeal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.play_arrow_rounded, size: 24),
                          label: const Text(
                            'Démarrer l\'Épreuve Maintenant',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          onPressed: _startExamNow,
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildConditionItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryTeal),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
