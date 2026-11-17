import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../models/mnemonic_reflex_model.dart';

class MnemonicsReflexScreen extends StatefulWidget {
  final int initialTab;
  const MnemonicsReflexScreen({super.key, this.initialTab = 0});

  @override
  State<MnemonicsReflexScreen> createState() => _MnemonicsReflexScreenState();
}

class _MnemonicsReflexScreenState extends State<MnemonicsReflexScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  bool _flashQuizMode = false;
  final Set<String> _revealedIds = {};

  List<MedicalMnemonicItem> _mnemonics = MnemonicsReflexRepository.builtinMnemonics;
  List<ExamReflexAssociation> _reflexes = MnemonicsReflexRepository.builtinReflexes;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    _loadData();
  }

  Future<void> _loadData() async {
    final m = await MnemonicsReflexRepository.loadAllMnemonics();
    final r = await MnemonicsReflexRepository.loadAllReflexes();
    if (mounted) {
      setState(() {
        _mnemonics = m;
        _reflexes = r;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mnémotechniques & Réflexes QCM',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              'Acronymes Médicaux & Associations Mots-Clés Résidanat',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Ajouter un moyen mnémotechnique / réflexe',
            onPressed: _openAddDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryTeal,
          labelColor: AppTheme.primaryTeal,
          tabs: const [
            Tab(icon: Icon(Icons.abc_rounded, size: 20), text: 'Acronymes & Astuces'),
            Tab(icon: Icon(Icons.bolt_rounded, size: 18), text: 'Mots-Clés ➔ Réflexes'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher par module, acronyme ou mot-clé clinique...',
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMnemonicsTab(),
                _buildReflexesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMnemonicsTab() {
    final items = _mnemonics.where((m) {
      if (_searchQuery.isEmpty) return true;
      return m.acronym.toLowerCase().contains(_searchQuery) ||
          m.title.toLowerCase().contains(_searchQuery) ||
          m.moduleName.toLowerCase().contains(_searchQuery);
    }).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.bentoCardDecoration(context, radius: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryTeal,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      item.acronym,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.moduleName,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(item.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              const SizedBox(height: 8),
              ...item.letterBreakdown.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $line', style: const TextStyle(fontSize: 13, height: 1.35)),
                ),
              ),
              if (item.examTip.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '💡 ${item.examTip}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildReflexesTab() {
    final items = _reflexes.where((r) {
      if (_searchQuery.isEmpty) return true;
      return r.triggerKeyword.toLowerCase().contains(_searchQuery) ||
          r.reflexDiagnosis.toLowerCase().contains(_searchQuery) ||
          r.moduleName.toLowerCase().contains(_searchQuery);
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: AppTheme.bentoCardDecoration(context, radius: 14),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mode Quiz Flash (Masquer la réponse)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
            subtitle: const Text('Testez votre réflexe diagnostic à partir des mots-clés de l\'énoncé', style: TextStyle(fontSize: 11.5)),
            value: _flashQuizMode,
            activeTrackColor: AppTheme.primaryTeal,
            onChanged: (v) => setState(() {
              _flashQuizMode = v;
              _revealedIds.clear();
            }),
          ),
        ),
        const SizedBox(height: 12),
        ...items.map((item) {
          final isVisible = !_flashQuizMode || _revealedIds.contains(item.id);
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.bentoCardDecoration(context, radius: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.moduleName.toUpperCase(),
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: AppTheme.primaryTeal, letterSpacing: 0.6),
                ),
                const SizedBox(height: 6),
                Text(
                  '🔎 Énoncé QCM : ${item.triggerKeyword}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                const SizedBox(height: 10),
                if (isVisible) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('⚡ Réflexe : ${item.reflexDiagnosis}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: AppTheme.primaryTeal)),
                        if (item.classicTrap.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('⚠ Piège : ${item.classicTrap}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ],
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.visibility_rounded, size: 17),
                      label: const Text('Révéler le Diagnostic Réflexe'),
                      onPressed: () => setState(() => _revealedIds.add(item.id)),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Future<void> _openAddDialog() async {
    final moduleCtrl = TextEditingController(text: 'Cardiologie');
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    final trapCtrl = TextEditingController();
    bool isMnemonic = _tabController.index == 0;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(isMnemonic ? 'Nouvel Acronyme Mnémotechnique' : 'Nouvelle Association Réflexe'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Acronyme')),
                    ButtonSegment(value: false, label: Text('Mot-Clé Réflexe')),
                  ],
                  selected: {isMnemonic},
                  onSelectionChanged: (s) => setDlgState(() => isMnemonic = s.first),
                ),
                const SizedBox(height: 10),
                TextField(controller: moduleCtrl, decoration: const InputDecoration(labelText: 'Module / Spécialité')),
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: isMnemonic ? 'Acronyme (ex: CRAB)' : 'Mots-clés dans l\'énoncé',
                  ),
                ),
                TextField(
                  controller: contentCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: isMnemonic ? 'Décomposition (1 lettre par ligne)' : 'Diagnostic / Réponse réflexe',
                  ),
                ),
                TextField(
                  controller: trapCtrl,
                  decoration: const InputDecoration(labelText: 'Astuce ou Piège classique'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty || contentCtrl.text.trim().isEmpty) return;
                final author = context.read<AuthBloc>().state.user?.fullName ?? 'Confrère Medsina';
                await MnemonicsReflexRepository.saveCustomItem({
                  'id': 'mn_${DateTime.now().millisecondsSinceEpoch}',
                  'author_name': author,
                  'module_name': moduleCtrl.text.trim(),
                  'item_type': isMnemonic ? 'mnemonic' : 'reflex',
                  'title_or_keyword': titleCtrl.text.trim(),
                  'content_or_diagnosis': contentCtrl.text.trim(),
                  'explanation_or_trap': trapCtrl.text.trim(),
                  'is_shared': true,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                await _loadData();
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
