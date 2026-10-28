import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../models/study_group_model.dart';
import '../services/group_revision_service.dart';
import 'create_group_dialog.dart';
import 'group_detail_screen.dart';
import 'join_group_dialog.dart';

class GroupRevisionHubScreen extends StatefulWidget {
  const GroupRevisionHubScreen({super.key});

  @override
  State<GroupRevisionHubScreen> createState() => _GroupRevisionHubScreenState();
}

class _GroupRevisionHubScreenState extends State<GroupRevisionHubScreen> {
  List<StudyGroupModel> _groups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    final user = context.read<AuthBloc>().state.user;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);
    final groups = await GroupRevisionService.instance.getUserGroups(user.id);
    if (mounted) {
      setState(() {
        _groups = groups;
        _isLoading = false;
      });
    }
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AppTheme.primaryTeal;
    }
  }

  void _openCreateGroup() async {
    final newGroup = await CreateGroupDialog.show(context);
    if (newGroup != null && mounted) {
      _loadGroups();
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => GroupDetailScreen(group: newGroup)),
      );
    }
  }

  void _openJoinGroup() async {
    final joined = await JoinGroupDialog.show(context);
    if (joined != null && mounted) {
      _loadGroups();
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => GroupDetailScreen(group: joined)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groupes de Révision', style: TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualiser',
            onPressed: _loadGroups,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadGroups,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Bannière Explicative
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryTeal,
                          AppTheme.primaryTeal.withValues(alpha: 0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryTeal.withValues(alpha: 0.25),
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
                              child: const Icon(Icons.groups_rounded, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Révision Médicale Collaborative',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Créez un groupe avec vos collègues de promotion ou de faculté, lancez des séries de QCMs chronométrées et comparez vos progressions pour le Résidanat 2027.',
                          style: TextStyle(color: Colors.white, fontSize: 12.5, height: 1.35),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppTheme.primaryTeal,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('Créer un groupe', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                onPressed: _openCreateGroup,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white, width: 1.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                                icon: const Icon(Icons.vpn_key_rounded, size: 18),
                                label: const Text('Rejoindre', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                onPressed: _openJoinGroup,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Mes Groupes (${_groups.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      if (_groups.isNotEmpty)
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Nouveau'),
                          onPressed: _openCreateGroup,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (_groups.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.diversity_3_outlined, size: 56, color: Colors.grey.shade400),
                            const SizedBox(height: 14),
                            const Text(
                              'Vous ne faites partie d\'aucun groupe',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Créez votre propre groupe ou saisissez un code d\'invitation partagé par vos collègues.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 18),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryTeal,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text('Créer mon premier groupe'),
                              onPressed: _openCreateGroup,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._groups.map((g) {
                      final groupColor = _parseColor(g.avatarColor);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 1,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => GroupDetailScreen(group: g)),
                            ).then((_) => _loadGroups());
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: groupColor.withValues(alpha: 0.15),
                                  child: Text(
                                    g.name.isNotEmpty ? g.name[0].toUpperCase() : 'G',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: groupColor),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              g.name,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                                            ),
                                          ),
                                          if (g.isUserAdmin)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.amber.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text('Créateur', style: TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.bold)),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      if (g.targetSpecialty != null)
                                        Text(
                                          g.targetSpecialty!,
                                          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                                        ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(Icons.people_outline, size: 14, color: Colors.grey.shade500),
                                          const SizedBox(width: 4),
                                          Text('${g.memberCount} membre${g.memberCount > 1 ? "s" : ""}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                          const SizedBox(width: 12),
                                          Icon(Icons.vpn_key_outlined, size: 14, color: Colors.grey.shade500),
                                          const SizedBox(width: 4),
                                          Text(g.inviteCode, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

