import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../models/national_exam_model.dart';
import '../services/national_exam_service.dart';

class NationalExamLeaderboardScreen extends StatefulWidget {
  final NationalExamModel exam;

  const NationalExamLeaderboardScreen({super.key, required this.exam});

  @override
  State<NationalExamLeaderboardScreen> createState() => _NationalExamLeaderboardScreenState();
}

class _NationalExamLeaderboardScreenState extends State<NationalExamLeaderboardScreen> {
  List<ExamLeaderboardEntry> _leaderboard = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLeaderboard() async {
    final user = context.read<AuthBloc>().state.user;
    setState(() => _isLoading = true);

    final entries = await NationalExamService.instance.getExamLeaderboard(
      widget.exam.id,
      currentUserId: user?.id,
    );

    if (mounted) {
      setState(() {
        _leaderboard = entries;
        _isLoading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final myEntry = _leaderboard.where((e) => e.isCurrentUser).firstOrNull;

    final filtered = _searchQuery.isEmpty
        ? _leaderboard
        : _leaderboard.where((e) {
            final q = _searchQuery.toLowerCase();
            return e.displayName.toLowerCase().contains(q) ||
                e.displayFaculty.toLowerCase().contains(q);
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Classement : ${widget.exam.title}', style: const TextStyle(fontSize: 15)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualiser',
            onPressed: _loadLeaderboard,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _leaderboard.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.emoji_events_outlined, size: 56, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'Aucune copie soumise pour le moment',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Les notes et le classement s\'afficheront ici dès les premières soumissions de copies.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Podium des 3 Majors Nationaux
                    if (_leaderboard.isNotEmpty && _searchQuery.isEmpty)
                      _buildPodiumSection(_leaderboard.take(3).toList()),

                    // Barre de recherche
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Rechercher un candidat ou une faculté...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v.trim()),
                      ),
                    ),

                    // Liste complète des rangs
                    Expanded(
                      child: ListView.separated(
                        padding: EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 4,
                          bottom: myEntry != null ? 90 : 16,
                        ),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (ctx, idx) {
                          final item = filtered[idx];
                          return _buildLeaderboardTile(item);
                        },
                      ),
                    ),
                  ],
                ),

      // Bannière Flottante Personnelle épinglée en bas
      bottomSheet: myEntry != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.cardColor,
                border: Border(top: BorderSide(color: AppTheme.primaryTeal.withValues(alpha: 0.3))),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, -3)),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryTeal,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Rang ${myEntry.rank}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Votre Position Officielle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(
                            '${myEntry.scoreOutOf20.toStringAsFixed(1)} / 20 (${myEntry.accuracyPercentage.toStringAsFixed(1)}%) • ${_formatTime(myEntry.timeSpentSeconds)}',
                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildPodiumSection(List<ExamLeaderboardEntry> topThree) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.primaryTeal.withValues(alpha: 0.06),
        border: Border(bottom: BorderSide(color: AppTheme.primaryTeal.withValues(alpha: 0.15))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2ème place
          if (topThree.length >= 2)
            _buildPodiumStep(topThree[1], '🥈 2e', Colors.grey.shade400, 75)
          else
            const SizedBox(width: 80),

          // 1ère place (Major)
          if (topThree.isNotEmpty)
            _buildPodiumStep(topThree[0], '🥇 1er', Colors.amber, 95)
          else
            const SizedBox(width: 80),

          // 3ème place
          if (topThree.length >= 3)
            _buildPodiumStep(topThree[2], '🥉 3e', const Color(0xFFCD7F32), 65)
          else
            const SizedBox(width: 80),
        ],
      ),
    );
  }

  Widget _buildPodiumStep(ExamLeaderboardEntry entry, String label, Color medalColor, double height) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: medalColor.withValues(alpha: 0.2),
          child: Text(
            entry.displayName.isNotEmpty ? entry.displayName[0].toUpperCase() : 'C',
            style: TextStyle(fontWeight: FontWeight.bold, color: medalColor),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 85,
          child: Text(
            entry.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
          ),
        ),
        Text(
          '${entry.scoreOutOf20.toStringAsFixed(1)}/20',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: medalColor),
        ),
        const SizedBox(height: 4),
        Container(
          width: 80,
          height: height,
          decoration: BoxDecoration(
            color: medalColor.withValues(alpha: 0.18),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: medalColor.withValues(alpha: 0.4)),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: medalColor),
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardTile(ExamLeaderboardEntry item) {
    final isMe = item.isCurrentUser;
    return Container(
      color: isMe ? AppTheme.primaryTeal.withValues(alpha: 0.08) : Colors.transparent,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Row(
        children: [
          // Badge Rang
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: item.rank <= 3 ? Colors.amber.withValues(alpha: 0.15) : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${item.rank}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: item.rank <= 3 ? Colors.amber.shade900 : Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Nom et Faculté
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.displayName,
                        style: TextStyle(
                          fontWeight: isMe ? FontWeight.bold : FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isMe)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryTeal,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Vous', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                Text(
                  item.displayFaculty,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Note & Vitesse
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item.scoreOutOf20.toStringAsFixed(1)} / 20',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryTeal),
              ),
              Text(
                '${item.accuracyPercentage.toStringAsFixed(0)}% • ${_formatTime(item.timeSpentSeconds)}',
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

