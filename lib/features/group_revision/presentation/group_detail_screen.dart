import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../revision/bloc/revision_bloc.dart';
import '../../revision/bloc/revision_event.dart';
import '../../revision/data/residency_repository.dart';
import '../../revision/models/module_model.dart';
import '../../revision/models/revision_session_model.dart';
import '../../revision/presentation/qcm_study_screen.dart';
import '../models/study_group_model.dart';
import '../services/group_revision_service.dart';

class GroupDetailScreen extends StatefulWidget {
  final StudyGroupModel group;

  const GroupDetailScreen({super.key, required this.group});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late StudyGroupModel _group;
  List<StudyGroupMemberModel> _members = [];
  List<StudyGroupChallengeModel> _challenges = [];
  bool _isLoadingMembers = true;
  bool _isLoadingChallenges = true;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AppTheme.primaryTeal;
    }
  }

  Future<void> _loadData() async {
    final user = context.read<AuthBloc>().state.user;
    if (user != null) {
      GroupRevisionService.instance.pingActivity(_group.id, user.id);
    }

    setState(() {
      _isLoadingMembers = true;
      _isLoadingChallenges = true;
    });

    final members = await GroupRevisionService.instance.getGroupMembers(_group.id);
    final challenges = await GroupRevisionService.instance.getGroupChallenges(_group.id);

    if (mounted) {
      setState(() {
        _members = members;
        _challenges = challenges;
        _isLoadingMembers = false;
        _isLoadingChallenges = false;
      });
    }
  }

  void _copyInviteCode() {
    Clipboard.setData(ClipboardData(text: _group.inviteCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Code copié : ${_group.inviteCode} (Partagez-le avec vos collègues)'),
        backgroundColor: AppTheme.primaryTeal,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showInviteDialog() async {
    final user = context.read<AuthBloc>().state.user;
    if (user == null) return;

    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];
    bool isSearching = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.primaryTeal),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Inviter un Étudiant',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Recherchez par nom ou email pour lui envoyer une notification d\'invitation directe :',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'ex: Mohamed, amina@gmail.com...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.arrow_forward),
                          onPressed: () async {
                            final q = searchCtrl.text.trim();
                            if (q.length < 2) return;
                            setDlgState(() => isSearching = true);
                            final res = await GroupRevisionService.instance.searchUsersToInvite(q, user.id);
                            setDlgState(() {
                              searchResults = res;
                              isSearching = false;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (isSearching)
                      const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                    else if (searchResults.isNotEmpty)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: searchResults.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (_, idx) {
                            final u = searchResults[idx];
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor: AppTheme.primaryTeal.withValues(alpha: 0.15),
                                child: Text(
                                  (u['full_name']?.toString() ?? 'U')[0].toUpperCase(),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryTeal),
                                ),
                              ),
                              title: Text(u['full_name']?.toString() ?? 'Médecin', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              subtitle: Text(u['faculty']?.toString() ?? u['email']?.toString() ?? '', style: const TextStyle(fontSize: 11)),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryTeal,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  minimumSize: const Size(60, 28),
                                ),
                                child: const Text('Inviter', style: TextStyle(fontSize: 11)),
                                onPressed: () async {
                                  Navigator.of(ctx).pop();
                                  final ok = await GroupRevisionService.instance.inviteUserToGroup(
                                    groupId: _group.id,
                                    groupName: _group.name,
                                    inviteCode: _group.inviteCode,
                                    targetUserId: u['id'].toString(),
                                    senderName: user.fullName.isNotEmpty ? user.fullName : 'Un confrère',
                                  );
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(ok ? 'Invitation envoyée avec succès à ${u['full_name']} !' : 'Erreur lors de l\'envoi de l\'invitation.'),
                                        backgroundColor: ok ? AppTheme.primaryTeal : Colors.red,
                                      ),
                                    );
                                    _loadData();
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Ou partagez directement le code "${_group.inviteCode}" sur WhatsApp ou Telegram.',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Fermer'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showCreateChallengeDialog() async {
    final user = context.read<AuthBloc>().state.user;
    if (user == null) return;

    final titleCtrl = TextEditingController(text: 'Série Défi ${_group.name}');
    int questionCount = 20;
    int durationMinutes = 20;

    // Load available modules
    final allModules = await ResidencyRepository.loadModulesAsync();
    String? selectedModuleId = allModules.isNotEmpty ? allModules.first.id : null;

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.bolt_rounded, color: Colors.amber, size: 26),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Lancer un Défi de Groupe',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: titleCtrl,
                        decoration: InputDecoration(
                          labelText: 'Titre du défi *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedModuleId,
                        decoration: InputDecoration(
                          labelText: 'Module cible',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: allModules.map((m) {
                          return DropdownMenuItem(value: m.id, child: Text(m.name, overflow: TextOverflow.ellipsis));
                        }).toList(),
                        onChanged: (v) => setDlgState(() => selectedModuleId = v),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: questionCount,
                              decoration: InputDecoration(
                                labelText: 'QCMs',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              items: [10, 20, 30, 40, 50].map((c) => DropdownMenuItem(value: c, child: Text('$c QCMs'))).toList(),
                              onChanged: (v) => setDlgState(() => questionCount = v ?? 20),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: durationMinutes,
                              decoration: InputDecoration(
                                labelText: 'Durée',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              items: [10, 15, 20, 30, 45, 60].map((d) => DropdownMenuItem(value: d, child: Text('$d min'))).toList(),
                              onChanged: (v) => setDlgState(() => durationMinutes = v ?? 20),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryTeal,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Publier le Défi'),
                            onPressed: () async {
                              Navigator.of(ctx).pop();
                              final ch = await GroupRevisionService.instance.createChallenge(
                                groupId: _group.id,
                                createdBy: user.id,
                                title: titleCtrl.text.trim(),
                                moduleId: selectedModuleId,
                                questionCount: questionCount,
                                durationMinutes: durationMinutes,
                              );
                              if (mounted && ch != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Défi publié avec succès dans le groupe !'), backgroundColor: AppTheme.primaryTeal),
                                );
                                _loadData();
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _playChallenge(StudyGroupChallengeModel ch) async {
    final allModules = await ResidencyRepository.loadModulesAsync();
    final mod = allModules.firstWhere(
      (m) => m.id == ch.moduleId,
      orElse: () => allModules.isNotEmpty
          ? allModules.first
          : const MedicalModuleModel(
              id: 'MOD',
              name: 'Module',
              category: 'Général',
              courses: [],
              totalCourses: 0,
              totalQuestions: 0,
            ),
    );

    final session = CustomRevisionSession(
      id: 'group_challenge_${ch.id}_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Défi Groupe : ${ch.title}',
      moduleIds: [mod.id],
      moduleNames: [mod.name],
      courseIds: mod.courses.map((c) => c.id).toList(),
      courseNames: mod.courses.map((c) => c.name).toList(),
      questionLimit: ch.questionCount,
      shuffleQuestions: true,
      sessionMode: ch.durationMinutes != null ? 'exam' : 'revision',
      durationMinutes: ch.durationMinutes,
      totalQuestions: 0,
      createdAt: DateTime.now(),
      lastActiveAt: DateTime.now(),
    );

    if (!mounted) return;
    context.read<RevisionBloc>().add(StartCustomSessionEvent(session, resume: false));
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const QcmStudyScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupColor = _parseColor(_group.avatarColor);

    return Scaffold(
      appBar: AppBar(
        title: Text(_group.name, style: const TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Partager le code',
            onPressed: _copyInviteCode,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualiser',
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          // En-tête Groupe
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: groupColor.withValues(alpha: 0.08),
              border: Border(bottom: BorderSide(color: groupColor.withValues(alpha: 0.2))),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: groupColor,
                  child: Text(
                    _group.name.isNotEmpty ? _group.name[0].toUpperCase() : 'G',
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _group.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      if (_group.targetSpecialty != null)
                        Text(
                          _group.targetSpecialty!,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Code : ${_group.inviteCode}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: _copyInviteCode,
                                  child: const Icon(Icons.copy, size: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('${_members.length} membres', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Onglets
          TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryTeal,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppTheme.primaryTeal,
            tabs: const [
              Tab(icon: Icon(Icons.bolt_rounded), text: 'Défis & Séries'),
              Tab(icon: Icon(Icons.people_alt_rounded), text: 'Membres'),
            ],
          ),

          // Contenu des onglets
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Onglet 1 : Défis
                _isLoadingChallenges
                    ? const Center(child: CircularProgressIndicator())
                    : _challenges.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.flag_outlined, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  const Text('Aucun défi lancé pour l\'instant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Lancez une série de QCMs collective pour que les membres puissent réviser ensemble !',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal, foregroundColor: Colors.white),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Lancer le premier défi'),
                                    onPressed: _showCreateChallengeDialog,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _challenges.length,
                            itemBuilder: (_, idx) {
                              final ch = _challenges[idx];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.flash_on_rounded, color: Colors.amber, size: 22),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(ch.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                            Text(
                                              '${ch.questionCount} QCMs ${ch.durationMinutes != null ? "• ${ch.durationMinutes} min" : ""}',
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                            ),
                                          ],
                                        ),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.primaryTeal,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        child: const Text('Jouer'),
                                        onPressed: () => _playChallenge(ch),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                // Onglet 2 : Membres
                _isLoadingMembers
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _members.length + 1,
                        itemBuilder: (_, idx) {
                          if (idx == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${_members.length} membres actifs', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryTeal,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.person_add_rounded, size: 16),
                                    label: const Text('Inviter', style: TextStyle(fontSize: 12)),
                                    onPressed: _showInviteDialog,
                                  ),
                                ],
                              ),
                            );
                          }
                          final m = _members[idx - 1];
                          final isOnline = m.isOnline;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: AppTheme.primaryTeal.withValues(alpha: 0.15),
                                  child: Text(
                                    m.fullName.isNotEmpty ? m.fullName[0].toUpperCase() : 'U',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryTeal),
                                  ),
                                ),
                                PositionPositive(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: isOnline ? Colors.green : Colors.grey,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 1.5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            title: Row(
                              children: [
                                Expanded(child: Text(m.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5))),
                                if (m.role == 'admin')
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('Admin', style: TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              m.faculty ?? (isOnline ? 'En ligne' : 'Vu récemment'),
                              style: TextStyle(fontSize: 11, color: isOnline ? Colors.green : Colors.grey),
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.primaryTeal,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Nouveau défi'),
              onPressed: _showCreateChallengeDialog,
            )
          : null,
    );
  }
}

class PositionPositive extends StatelessWidget {
  final double? right;
  final double? bottom;
  final Widget child;
  const PositionPositive({super.key, this.right, this.bottom, required this.child});

  @override
  Widget build(BuildContext context) {
    return Positioned(right: right, bottom: bottom, child: child);
  }
}

