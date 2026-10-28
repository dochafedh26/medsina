import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/national_exam_model.dart';
import '../services/national_exam_service.dart';
import 'national_exam_leaderboard_screen.dart';
import 'national_exam_room_screen.dart';

class NationalExamsListScreen extends StatefulWidget {
  const NationalExamsListScreen({super.key});

  @override
  State<NationalExamsListScreen> createState() => _NationalExamsListScreenState();
}

class _NationalExamsListScreenState extends State<NationalExamsListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<NationalExamModel> _exams = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadExams();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadExams() async {
    setState(() => _isLoading = true);
    final list = await NationalExamService.instance.getExams();
    if (mounted) {
      setState(() {
        _exams = list;
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year;
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y à ${h}h$min';
  }

  @override
  Widget build(BuildContext context) {
    final activeAndUpcoming = _exams.where((e) => !e.isClosed).toList();
    final closedExams = _exams.where((e) => e.isClosed).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Concours Blancs Nationaux', style: TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualiser',
            onPressed: _loadExams,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryTeal,
          indicatorColor: AppTheme.primaryTeal,
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(text: 'En Cours & À Venir (${activeAndUpcoming.length})'),
            Tab(text: 'Palmarès & Archives (${closedExams.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // 1. ACTIFS & À VENIR
                activeAndUpcoming.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.event_available_outlined, size: 56, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              const Text('Aucun concours blanc programmé', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 6),
                              Text(
                                'L\'administration Medsina diffuse régulièrement des concours blancs nationaux. Vous recevrez une notification d\'annonce dès l\'ouverture de la prochaine session.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: activeAndUpcoming.length,
                        itemBuilder: (ctx, idx) => _buildExamCard(activeAndUpcoming[idx]),
                      ),

                // 2. PALMARÈS & ARCHIVES
                closedExams.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history_edu_outlined, size: 56, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              const Text('Aucune épreuve archivée', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 6),
                              Text(
                                'Les résultats et classements des concours terminés apparaîtront dans cette section.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: closedExams.length,
                        itemBuilder: (ctx, idx) => _buildExamCard(closedExams[idx]),
                      ),
              ],
            ),
    );
  }

  Widget _buildExamCard(NationalExamModel exam) {
    final isClosed = exam.isClosed;
    final isActive = exam.isActive;

    Color statusColor = Colors.grey;
    String statusLabel = 'Programmé';
    if (isActive) {
      statusColor = Colors.green;
      statusLabel = 'Épreuve en Direct';
    } else if (isClosed) {
      statusColor = Colors.blueGrey;
      statusLabel = 'Épreuve Clôturée';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1.5,
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
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  '${exam.totalQuestions} QCMs • ${exam.durationMinutes} min',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              exam.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            if (exam.description != null) ...[
              const SizedBox(height: 4),
              Text(
                exam.description!,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  isClosed ? 'Terminé le ${_formatDate(exam.endTime)}' : 'Début : ${_formatDate(exam.startTime)}',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                ),
                const Spacer(),
                if (exam.participantsCount > 0)
                  Text(
                    '${exam.participantsCount} candidat${exam.participantsCount > 1 ? "s" : ""}',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                if (!isClosed)
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryTeal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.play_circle_fill_rounded, size: 18),
                      label: const Text('Rejoindre l\'épreuve', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => NationalExamRoomScreen(exam: exam)),
                        );
                      },
                    ),
                  ),
                if (!isClosed) const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.leaderboard_rounded, size: 18),
                    label: const Text('Classement', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => NationalExamLeaderboardScreen(exam: exam)),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

