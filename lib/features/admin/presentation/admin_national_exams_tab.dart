import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../national_exam/models/national_exam_model.dart';
import '../../national_exam/presentation/national_exam_leaderboard_screen.dart';
import '../../national_exam/services/national_exam_service.dart';
import '../../revision/data/residency_repository.dart';

class AdminNationalExamsTab extends StatefulWidget {
  final bool isDark;

  const AdminNationalExamsTab({super.key, required this.isDark});

  @override
  State<AdminNationalExamsTab> createState() => _AdminNationalExamsTabState();
}

class _AdminNationalExamsTabState extends State<AdminNationalExamsTab> {
  List<NationalExamModel> _exams = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  Future<void> _loadExams() async {
    setState(() => _isLoading = true);
    final exams = await NationalExamService.instance.getExams();
    if (mounted) {
      setState(() {
        _exams = exams;
        _isLoading = false;
      });
    }
  }

  Future<void> _openCreateExamDialog() async {
    final user = context.read<AuthBloc>().state.user;
    if (user == null) return;

    final titleCtrl = TextEditingController(text: 'Concours Blanc National Résidanat 2027');
    final descCtrl = TextEditingController(text: 'Épreuve officielle nationale simulant le concours de résidanat. Classement par note et rapidité.');
    int questionCount = 60;
    int durationMinutes = 60;
    String targetType = 'residency';
    String? selectedModuleId;
    String? selectedModuleName;
    bool sendBroadcast = true;
    bool isSynchronous = false;

    final allModules = await ResidencyRepository.loadModulesAsync();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 550),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 26),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Créer un Concours Blanc National',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: titleCtrl,
                          decoration: InputDecoration(
                            labelText: 'Titre de l\'épreuve *',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: descCtrl,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Consignes & Description',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: targetType,
                                decoration: InputDecoration(
                                  labelText: 'Portée de l\'examen',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'residency', child: Text('Résidanat Complet (Tous modules)')),
                                  DropdownMenuItem(value: 'module', child: Text('Module Spécifique')),
                                ],
                                onChanged: (v) => setDlgState(() => targetType = v ?? 'residency'),
                              ),
                            ),
                          ],
                        ),
                        if (targetType == 'module') ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: selectedModuleId,
                            decoration: InputDecoration(
                              labelText: 'Sélectionner le Module Cible',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            items: allModules.map((m) {
                              return DropdownMenuItem(value: m.id, child: Text(m.name, overflow: TextOverflow.ellipsis));
                            }).toList(),
                            onChanged: (v) {
                              setDlgState(() {
                                selectedModuleId = v;
                                selectedModuleName = allModules.firstWhere((m) => m.id == v).name;
                              });
                            },
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                initialValue: questionCount,
                                decoration: InputDecoration(
                                  labelText: 'Nombre de QCMs',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                items: [20, 30, 40, 60, 100, 120].map((c) => DropdownMenuItem(value: c, child: Text('$c QCMs'))).toList(),
                                onChanged: (v) => setDlgState(() => questionCount = v ?? 60),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                initialValue: durationMinutes,
                                decoration: InputDecoration(
                                  labelText: 'Durée Chrono',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                items: [30, 45, 60, 90, 120, 180].map((d) => DropdownMenuItem(value: d, child: Text('$d min'))).toList(),
                                onChanged: (v) => setDlgState(() => durationMinutes = v ?? 60),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          activeColor: AppTheme.primaryTeal,
                          value: sendBroadcast,
                          onChanged: (v) => setDlgState(() => sendBroadcast = v == true),
                          title: const Text(
                            '📢 Diffuser l\'invitation à tous les utilisateurs',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          subtitle: const Text(
                            'Envoie une notification in-app/push immédiate pour inviter tous les candidats.',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          activeColor: AppTheme.primaryTeal,
                          value: isSynchronous,
                          onChanged: (v) => setDlgState(() => isSynchronous = v == true),
                          title: const Text(
                            'Épreuve Synchrone Directe',
                            style: TextStyle(fontSize: 13),
                          ),
                          subtitle: const Text(
                            'Si décoché, les candidats peuvent composer librement dans une fenêtre de 48 heures.',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryTeal,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.campaign_rounded, size: 18),
                              label: const Text('Créer & Diffuser l\'Épreuve'),
                              onPressed: () async {
                                Navigator.of(ctx).pop();
                                // Charger les IDs de questions depuis le pool
                                List<String> qIds = [];
                                if (targetType == 'module' && selectedModuleId != null) {
                                  final mod = allModules.firstWhere((m) => m.id == selectedModuleId);
                                  final qs = await ResidencyRepository.getQuestionsForMultipleCoursesAsync(
                                    courseIds: mod.courses.map((c) => c.id).toList(),
                                    moduleIds: [mod.id],
                                    limit: questionCount,
                                    shuffle: true,
                                  );
                                  qIds = qs.map((q) => q.id).toList();
                                } else {
                                  final allC = allModules.expand((m) => m.courses.map((c) => c.id)).toList();
                                  final qs = await ResidencyRepository.getQuestionsForMultipleCoursesAsync(
                                    courseIds: allC,
                                    moduleIds: allModules.map((m) => m.id).toList(),
                                    limit: questionCount,
                                    shuffle: true,
                                  );
                                  qIds = qs.map((q) => q.id).toList();
                                }

                                if (qIds.isEmpty) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Erreur : aucune question trouvée dans la banque.')),
                                    );
                                  }
                                  return;
                                }

                                final exam = await NationalExamService.instance.createNationalExam(
                                  adminUserId: user.id,
                                  title: titleCtrl.text.trim(),
                                  description: descCtrl.text.trim(),
                                  targetType: targetType,
                                  targetModuleId: selectedModuleId,
                                  targetModuleName: selectedModuleName,
                                  questionIds: qIds,
                                  durationMinutes: durationMinutes,
                                  startTime: DateTime.now(),
                                  endTime: DateTime.now().add(const Duration(hours: 48)),
                                  isLiveSynchronous: isSynchronous,
                                  sendBroadcast: sendBroadcast,
                                );

                                if (mounted && exam != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('🎉 Concours Blanc "${exam.title}" créé et diffusé avec succès !'),
                                      backgroundColor: AppTheme.primaryTeal,
                                    ),
                                  );
                                  _loadExams();
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _closeAndRankExam(NationalExamModel exam) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clôturer le Concours Blanc ?'),
        content: Text('Voulez-vous clôturer définitivement "${exam.title}" et calculer le classement national officiel pour tous les participants ?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clôturer & Calculer le Classement'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ok = await NationalExamService.instance.closeExamAndCalculateOfficialRanks(exam.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'Le classement officiel a été calculé et diffusé à tous les candidats !' : 'Erreur lors de la clôture.'),
            backgroundColor: ok ? AppTheme.primaryTeal : Colors.red,
          ),
        );
        _loadExams();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Bannière Admin Concours Blancs
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primaryTeal.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryTeal,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Gestion des Concours Blancs Nationaux',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Créez des épreuves officielles, diffusez les invitations à toute la communauté Medsina et générez les classements officiels nationaux.',
                            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Créer un Concours', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _openCreateExamDialog,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Épreuves Officielles (${_exams.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: _loadExams,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (_exams.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.quiz_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text('Aucun concours blanc créé pour le moment', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        const Text('Cliquez sur "Créer un Concours" pour programmer votre première épreuve nationale.'),
                      ],
                    ),
                  ),
                )
              else
                ..._exams.map((exam) {
                  final isClosed = exam.isClosed;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isClosed ? Colors.grey.shade200 : Colors.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  exam.status.label,
                                  style: TextStyle(
                                    color: isClosed ? Colors.grey.shade700 : Colors.green.shade800,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text('${exam.totalQuestions} Questions • ${exam.durationMinutes} min', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                              const Spacer(),
                              Text(
                                '${exam.participantsCount} participant${exam.participantsCount > 1 ? "s" : ""}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryTeal),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(exam.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          if (exam.description != null)
                            Text(exam.description!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.campaign_outlined, size: 16),
                                label: const Text('Rediffuser annonce'),
                                onPressed: () async {
                                  await NationalExamService.instance.broadcastExamAnnouncement(exam);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Annonce rediffusée avec succès !'), backgroundColor: AppTheme.primaryTeal),
                                    );
                                  }
                                },
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.leaderboard_rounded, size: 16),
                                label: const Text('Classement'),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => NationalExamLeaderboardScreen(exam: exam)),
                                  );
                                },
                              ),
                              if (!isClosed) ...[
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber.shade800,
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.lock_clock_rounded, size: 16),
                                  label: const Text('Clôturer & Classer'),
                                  onPressed: () => _closeAndRankExam(exam),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          );
  }
}
